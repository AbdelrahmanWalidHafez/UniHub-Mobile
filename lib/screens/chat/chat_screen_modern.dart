import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:file_picker/file_picker.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../providers/chat_provider.dart';
import '../../providers/auth_provider.dart';
import '../../models/chat/chat_model.dart';
import '../../models/chat/chat_message_model.dart';
import '../../services/chat_service.dart';
import '../../services/voice_recorder_service.dart';
import '../../services/audio_player_service.dart';
import 'group_info_screen.dart';
import 'voice_message_widget.dart';

class ChatScreenModern extends StatefulWidget {
  final ChatRoom room;

  const ChatScreenModern({super.key, required this.room});

  @override
  State<ChatScreenModern> createState() => _ChatScreenModernState();
}

class _ChatScreenModernState extends State<ChatScreenModern>
    with WidgetsBindingObserver {
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final FocusNode _focusNode = FocusNode();

  bool _isTyping = false;
  bool _isRecordingVoice = false;
  Timer? _recordingTimer;
  Timer? _typingDebounceTimer;
  Timer? _wsCheckTimer;
  int _recordingDuration = 0;
  bool _isSending = false;
  bool _wsConnected = false;

  ChatMessage? _replyingTo;

  static const Color _lime = Color(0xFFB9FF66);
  static const Color _brand = Color(0xFF0077B3);
  static const bool enableLogging = true;

  final List<Color> _avatarColors = [
    Colors.red,
    Colors.pink,
    Colors.purple,
    Colors.deepPurple,
    Colors.indigo,
    Colors.blue,
    Colors.lightBlue,
    Colors.cyan,
    Colors.teal,
    Colors.green,
    Colors.lightGreen,
    Colors.lime,
    Colors.yellow,
    Colors.amber,
    Colors.orange,
    Colors.deepOrange,
    Colors.brown,
    Colors.grey,
    Colors.blueGrey,
  ];

  Color _getAvatarColor(String name) {
    final hash = name.hashCode.abs();
    return _avatarColors[hash % _avatarColors.length];
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    AudioPlayerService.init();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _setupListeners();
      _loadMessages();
      _startWsCheck();
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _recordingTimer?.cancel();
    _typingDebounceTimer?.cancel();
    _wsCheckTimer?.cancel();
    ChatService.removeMessageListener(widget.room.id);
    ChatService.removeTypingListener(widget.room.id);
    _messageController.dispose();
    _scrollController.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _startWsCheck() {
    _wsCheckTimer = Timer.periodic(const Duration(seconds: 2), (_) {
      if (!mounted) return;
      final connected = ChatService.isConnected;
      if (connected != _wsConnected) {
        setState(() => _wsConnected = connected);
      }
      if (connected) _wsCheckTimer?.cancel();
    });
  }

  void _setupListeners() {
    ChatService.addMessageListener(widget.room.id, (data) {
      if (!mounted) return;
      try {
        final message = ChatMessage.fromJson(data);
        context.read<ChatProvider>().addNewMessage(message);
        _scrollToBottom();
      } catch (e) {
        debugPrint('Error parsing message: $e');
      }
    });

    ChatService.addTypingListener(widget.room.id, (data) {
      if (!mounted) return;
      setState(() => _isTyping = true);
      Future.delayed(const Duration(seconds: 3), () {
        if (mounted) setState(() => _isTyping = false);
      });
    });
  }

  void _loadMessages() {
    final provider = context.read<ChatProvider>();

    if (provider.messages.isNotEmpty && provider.currentRoom?.id == widget.room.id) {
      _scrollToBottom();
      return;
    }

    provider.loadMessages(widget.room.id, refresh: true).then((_) {
      provider.setCurrentRoom(widget.room);
      _scrollToBottom();
    });
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          0,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  void _sendTyping(bool typing) {
    if (!_wsConnected) return;
    _typingDebounceTimer?.cancel();
    if (typing) {
      ChatService.sendTyping(widget.room.id, true);
      _typingDebounceTimer = Timer(const Duration(seconds: 2), () {
        ChatService.sendTyping(widget.room.id, false);
      });
    } else {
      ChatService.sendTyping(widget.room.id, false);
    }
  }

  Future<void> _sendTextMessage() async {
    final text = _messageController.text.trim();
    if (text.isEmpty || _isSending) return;

    _messageController.clear();
    _sendTyping(false);
    setState(() => _isSending = true);

    final authProvider = context.read<AuthProvider>();
    final provider = context.read<ChatProvider>();

    try {
      final tempMessage = ChatMessage(
        id: 'temp-${DateTime.now().millisecondsSinceEpoch}',
        roomId: widget.room.id,
        senderEmail: authProvider.userEmail ?? '',
        senderDisplayName: authProvider.userName,
        type: MessageType.text,
        content: text,
        replyTo: _replyingTo != null
            ? ReplyToDto(
          messageId: _replyingTo!.id,
          senderDisplayName: _replyingTo!.senderDisplayName,
          contentPreview: _replyingTo!.contentPreview,
        )
            : null,
        readBy: [],
        createdAt: DateTime.now(),
      );

      provider.addNewMessage(tempMessage);

      if (_wsConnected) {
        ChatService.sendTextMessage(
          roomId: widget.room.id,
          content: text,
          replyToMessageId: _replyingTo?.id,
        );
      } else {
        _showError('Not connected. Retrying connection…');
        final auth = context.read<AuthProvider>();
        ChatService.initWebSocket(
          auth.userEmail ?? '',
          auth.accessToken ?? '',
          tid: auth.tid,
          cid: auth.cid,
        );
      }

      setState(() => _replyingTo = null);
      _scrollToBottom();
    } catch (e) {
      _showError('Failed to send: $e');
    } finally {
      setState(() => _isSending = false);
    }
  }

  Future<void> _pickImage() async {
    try {
      final picker = ImagePicker();
      final result = await picker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 80,
      );
      if (result != null && mounted) {
        setState(() => _isSending = true);
        await context.read<ChatProvider>().sendImageMessage(
          roomId: widget.room.id,
          image: File(result.path),
          replyToMessageId: _replyingTo?.id,
        );
        if (mounted) setState(() => _replyingTo = null);
        _scrollToBottom();
      }
    } catch (e) {
      _showError('Failed to send image: $e');
    } finally {
      if (mounted) setState(() => _isSending = false);
    }
  }

  Future<void> _pickFile() async {
    try {
      final result = await FilePicker.platform.pickFiles();
      if (result != null && result.files.isNotEmpty) {
        final file = result.files.first;
        if (file.path != null) {
          setState(() => _isSending = true);
          final authProvider = context.read<AuthProvider>();
          final provider = context.read<ChatProvider>();

          final fileName = file.name;
          final fileSize = file.size;
          final fileSizeStr = fileSize > 1024 * 1024
              ? '${(fileSize / (1024 * 1024)).toStringAsFixed(1)} MB'
              : '${(fileSize / 1024).toStringAsFixed(1)} KB';

          final messageText = '📎 $fileName ($fileSizeStr)';

          final tempMessage = ChatMessage(
            id: 'temp-${DateTime.now().millisecondsSinceEpoch}',
            roomId: widget.room.id,
            senderEmail: authProvider.userEmail ?? '',
            senderDisplayName: authProvider.userName,
            type: MessageType.text,
            content: messageText,
            replyTo: _replyingTo != null
                ? ReplyToDto(
              messageId: _replyingTo!.id,
              senderDisplayName: _replyingTo!.senderDisplayName,
              contentPreview: _replyingTo!.contentPreview,
            )
                : null,
            readBy: [],
            createdAt: DateTime.now(),
          );

          provider.addNewMessage(tempMessage);

          if (_wsConnected) {
            ChatService.sendTextMessage(
              roomId: widget.room.id,
              content: messageText,
              replyToMessageId: _replyingTo?.id,
            );
          }

          if (mounted) setState(() => _replyingTo = null);
          _scrollToBottom();
        }
      }
    } catch (e) {
      _showError('Failed to send file: $e');
    } finally {
      if (mounted) setState(() => _isSending = false);
    }
  }

  Future<void> _openFile(String url) async {
    String fullUrl = url;

    if (!url.startsWith('http')) {
      const baseUrl = 'http://34.58.11.82:8082';
      fullUrl = url.startsWith('/') ? '$baseUrl$url' : '$baseUrl/$url';
    }

    final Uri uri = Uri.parse(fullUrl);

    try {
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      } else {
        _showFileOptions(fullUrl);
      }
    } catch (e) {
      _showFileOptions(fullUrl);
    }
  }

  void _showFileOptions(String url) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40,
              height: 4,
              margin: const EdgeInsets.symmetric(vertical: 12),
              decoration: BoxDecoration(
                color: Colors.grey.shade300,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Text(
                'Cannot open file automatically',
                style: TextStyle(color: Colors.grey.shade600),
              ),
            ),
            ListTile(
              leading: const Icon(Icons.copy, color: Colors.black),
              title: const Text('Copy URL', style: TextStyle(color: Colors.black87)),
              onTap: () {
                Navigator.pop(context);
                Clipboard.setData(ClipboardData(text: url));
                _showSuccess('URL copied to clipboard');
              },
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  String _getFileName(String url) {
    try {
      final cleanUrl = url.split('?').first;
      final parts = cleanUrl.split('/');
      final fileName = parts.last;
      if (fileName.isEmpty || fileName.length < 3) {
        return 'File';
      }
      return fileName;
    } catch (e) {
      return 'File';
    }
  }

  String _getFileType(String fileName) {
    final ext = fileName.split('.').last.toLowerCase();
    switch (ext) {
      case 'pdf': return '📄 PDF Document';
      case 'doc': return '📄 Word Document';
      case 'docx': return '📄 Word Document';
      case 'xls': return '📊 Excel Spreadsheet';
      case 'xlsx': return '📊 Excel Spreadsheet';
      case 'ppt': return '📊 PowerPoint Presentation';
      case 'pptx': return '📊 PowerPoint Presentation';
      case 'txt': return '📝 Text File';
      case 'zip': return '📦 ZIP Archive';
      case 'rar': return '📦 RAR Archive';
      case '7z': return '📦 7-Zip Archive';
      case 'jpg': return '🖼️ JPEG Image';
      case 'jpeg': return '🖼️ JPEG Image';
      case 'png': return '🖼️ PNG Image';
      case 'gif': return '🖼️ GIF Image';
      case 'webp': return '🖼️ WebP Image';
      case 'mp4': return '🎬 MP4 Video';
      case 'mov': return '🎬 MOV Video';
      case 'avi': return '🎬 AVI Video';
      case 'mkv': return '🎬 MKV Video';
      default: return '📎 File';
    }
  }

  IconData _getFileIcon(String fileName) {
    final ext = fileName.split('.').last.toLowerCase();
    switch (ext) {
      case 'pdf': return Icons.picture_as_pdf;
      case 'doc': return Icons.description;
      case 'docx': return Icons.description;
      case 'xls': return Icons.table_chart;
      case 'xlsx': return Icons.table_chart;
      case 'ppt': return Icons.slideshow;
      case 'pptx': return Icons.slideshow;
      case 'txt': return Icons.text_snippet;
      case 'zip': return Icons.folder_zip;
      case 'rar': return Icons.folder_zip;
      case '7z': return Icons.folder_zip;
      case 'jpg': return Icons.image;
      case 'jpeg': return Icons.image;
      case 'png': return Icons.image;
      case 'gif': return Icons.image;
      case 'webp': return Icons.image;
      case 'mp4': return Icons.video_library;
      case 'mov': return Icons.video_library;
      case 'avi': return Icons.video_library;
      case 'mkv': return Icons.video_library;
      default: return Icons.insert_drive_file;
    }
  }

  void _startVoiceRecording() async {
    try {
      final ok = await VoiceRecorderService.startRecording();
      if (ok) {
        setState(() {
          _isRecordingVoice = true;
          _recordingDuration = 0;
        });
        _recordingTimer = Timer.periodic(const Duration(seconds: 1), (_) {
          if (mounted) setState(() => _recordingDuration++);
        });
      } else {
        _showError('Microphone permission denied');
      }
    } catch (e) {
      _showError('Could not start recording: $e');
    }
  }

  Future<void> _stopVoiceRecording() async {
    _recordingTimer?.cancel();
    _recordingTimer = null;
    if (!mounted) return;

    final audioFile = await VoiceRecorderService.stopRecording();
    setState(() => _isRecordingVoice = false);

    if (audioFile != null && _recordingDuration > 1) {
      setState(() => _isSending = true);
      try {
        await context.read<ChatProvider>().sendVoiceMessage(
          roomId: widget.room.id,
          voice: audioFile,
          durationSecs: _recordingDuration,
          replyToMessageId: _replyingTo?.id,
        );
        if (mounted) setState(() => _replyingTo = null);
        _scrollToBottom();
      } catch (e) {
        _showError('Failed to send voice message: $e');
      } finally {
        if (mounted) setState(() => _isSending = false);
      }
    } else if (_recordingDuration <= 1) {
      _showError('Hold longer to record a voice message.');
    }
  }

  void _cancelVoiceRecording() async {
    _recordingTimer?.cancel();
    _recordingTimer = null;
    await VoiceRecorderService.cancelRecording();
    if (mounted) setState(() => _isRecordingVoice = false);
  }

  void _showAttachmentMenu() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      backgroundColor: Colors.white,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40,
              height: 4,
              margin: const EdgeInsets.symmetric(vertical: 12),
              decoration: BoxDecoration(
                color: Colors.grey.shade300,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            ListTile(
              leading: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.grey.shade100,
                  borderRadius: BorderRadius.circular(30),
                ),
                child: const Icon(Icons.image, color: Colors.black, size: 24),
              ),
              title: const Text('Photo', style: TextStyle(color: Colors.black87)),
              onTap: () {
                Navigator.pop(context);
                _pickImage();
              },
            ),
            ListTile(
              leading: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.grey.shade100,
                  borderRadius: BorderRadius.circular(30),
                ),
                child: const Icon(Icons.insert_drive_file, color: Colors.black, size: 24),
              ),
              title: const Text('Document', style: TextStyle(color: Colors.black87)),
              onTap: () {
                Navigator.pop(context);
                _pickFile();
              },
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  void _showMessageOptions(ChatMessage message) {
    final isMine = message.senderEmail == context.read<AuthProvider>().userEmail;

    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      backgroundColor: Colors.white,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40,
              height: 4,
              margin: const EdgeInsets.symmetric(vertical: 12),
              decoration: BoxDecoration(
                color: Colors.grey.shade300,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            if (!message.isSystem)
              ListTile(
                leading: const Icon(Icons.reply, color: Colors.black),
                title: const Text('Reply', style: TextStyle(color: Colors.black87)),
                onTap: () {
                  Navigator.pop(context);
                  setState(() => _replyingTo = message);
                  _focusNode.requestFocus();
                },
              ),
            if (isMine && !message.isSystem && message.isText)
              ListTile(
                leading: const Icon(Icons.edit, color: Colors.orange),
                title: const Text('Edit', style: TextStyle(color: Colors.black87)),
                onTap: () {
                  Navigator.pop(context);
                  _showEditDialog(message);
                },
              ),
            if (isMine && !message.isSystem)
              ListTile(
                leading: const Icon(Icons.delete_outline, color: Colors.red),
                title: const Text('Delete', style: TextStyle(color: Colors.red)),
                onTap: () {
                  Navigator.pop(context);
                  _showDeleteConfirmation(message);
                },
              ),
            if (message.isText && !message.isSystem)
              ListTile(
                leading: const Icon(Icons.copy, color: Colors.grey),
                title: const Text('Copy', style: TextStyle(color: Colors.black87)),
                onTap: () {
                  Navigator.pop(context);
                  Clipboard.setData(ClipboardData(text: message.content ?? ''));
                  _showSuccess('Copied to clipboard');
                },
              ),
          ],
        ),
      ),
    );
  }

  void _showEditDialog(ChatMessage message) {
    final controller = TextEditingController(text: message.content);
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Edit message', style: TextStyle(color: Colors.black87)),
        content: TextField(
          controller: controller,
          maxLines: 3,
          decoration: const InputDecoration(
            hintText: 'Edit your message…',
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel', style: TextStyle(color: Colors.grey)),
          ),
          TextButton(
            onPressed: () async {
              if (controller.text.trim().isNotEmpty) {
                try {
                  await context
                      .read<ChatProvider>()
                      .editMessage(message.id, controller.text.trim());
                  if (mounted) Navigator.pop(context);
                } catch (e) {
                  _showError('Failed to edit: $e');
                }
              }
            },
            child: const Text('Save', style: TextStyle(color: Colors.black)),
          ),
        ],
      ),
    );
  }

  void _showDeleteConfirmation(ChatMessage message) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Delete message', style: TextStyle(color: Colors.black87)),
        content: const Text('Are you sure you want to delete this message?', style: TextStyle(color: Colors.grey)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel', style: TextStyle(color: Colors.grey)),
          ),
          TextButton(
            onPressed: () async {
              try {
                await context.read<ChatProvider>().deleteMessage(message.id);
                if (mounted) Navigator.pop(context);
              } catch (e) {
                _showError('Failed to delete: $e');
              }
            },
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  void _showError(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg),
      backgroundColor: Colors.red.shade600,
      duration: const Duration(seconds: 2),
    ));
  }

  void _showSuccess(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg),
      backgroundColor: Colors.green,
      duration: const Duration(seconds: 1),
    ));
  }

  String _formatTime(DateTime t) {
    final hour = t.hour > 12 ? t.hour - 12 : t.hour;
    final minute = t.minute.toString().padLeft(2, '0');
    final ampm = t.hour >= 12 ? 'PM' : 'AM';
    return '$hour:$minute $ampm';
  }

  String _formatDate(DateTime d) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final msgDay = DateTime(d.year, d.month, d.day);
    if (msgDay == today) return 'Today';
    if (msgDay == today.subtract(const Duration(days: 1))) return 'Yesterday';
    return '${d.day}/${d.month}/${d.year}';
  }

  bool _shouldShowDate(ChatMessage cur, ChatMessage? prev) {
    if (prev == null) return true;
    return DateTime(cur.createdAt.year, cur.createdAt.month, cur.createdAt.day) !=
        DateTime(prev.createdAt.year, prev.createdAt.month, prev.createdAt.day);
  }

  bool _shouldGroupWithNext(ChatMessage current, ChatMessage? next) {
    if (next == null) return false;
    if (current.senderEmail != next.senderEmail) return false;
    if (next.createdAt.difference(current.createdAt).inMinutes > 5) return false;
    return true;
  }

  String _getDisplayName() {
    final email = context.read<AuthProvider>().userEmail;
    if (widget.room.isGroup) return widget.room.name ?? 'Group Chat';
    return widget.room.participants
        .firstWhere((p) => p.email != email,
        orElse: () => widget.room.participants.first)
        .displayName;
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<ChatProvider>();
    final currentEmail = context.watch<AuthProvider>().userEmail ?? '';
    final messages = provider.messages;

    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          image: DecorationImage(
            image: AssetImage('assets/images/chat_background.png'),
            fit: BoxFit.cover,
          ),
        ),
        child: Column(
          children: [
            Container(
              color: Colors.white.withOpacity(0.95),
              child: _buildAppBar(),
            ),
            Expanded(
              child: provider.isLoading && messages.isEmpty
                  ? Center(
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.9),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const CircularProgressIndicator(),
                ),
              )
                  : messages.isEmpty
                  ? Center(
                child: Container(
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.9),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 80,
                        height: 80,
                        decoration: BoxDecoration(
                          color: Colors.grey.shade100,
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          Icons.chat_bubble_outline,
                          size: 40,
                          color: Colors.grey.shade400,
                        ),
                      ),
                      const SizedBox(height: 20),
                      const Text(
                        'No messages yet',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w500,
                          color: Colors.black87,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Start a conversation with ${_getDisplayName()}',
                        style: const TextStyle(
                          fontSize: 14,
                          color: Colors.grey,
                        ),
                      ),
                    ],
                  ),
                ),
              )
                  : _buildMessageList(messages, currentEmail),
            ),
            if (_replyingTo != null) _buildReplyPreview(),
            if (_isRecordingVoice) _buildVoiceRecordingUI(),
            _buildMessageInput(),
          ],
        ),
      ),
    );
  }

  PreferredSizeWidget _buildAppBar() {
    final name = _getDisplayName();

    return AppBar(
      backgroundColor: Colors.transparent,
      elevation: 0.5,
      foregroundColor: Colors.black87,
      titleSpacing: 0,
      leading: IconButton(
        icon: const Icon(Icons.arrow_back, color: Colors.black87),
        onPressed: () => Navigator.pop(context),
      ),
      title: Row(
        children: [
          CircleAvatar(
            radius: 22,
            backgroundColor: _getAvatarColor(name),
            child: Text(
              name.isNotEmpty ? name[0].toUpperCase() : '?',
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 16,
                color: Colors.white,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  name,
                  style: const TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w600,
                    color: Colors.black87,
                  ),
                ),
                if (_isTyping)
                  const Text(
                    'Typing...',
                    style: TextStyle(
                      fontSize: 13,
                      color: Color(0xFF0077B3),
                      fontStyle: FontStyle.italic,
                    ),
                  )
                else if (widget.room.isGroup)
                  Text(
                    '${widget.room.participants.length} members',
                    style: const TextStyle(fontSize: 13, color: Colors.grey),
                  ),
              ],
            ),
          ),
        ],
      ),
      actions: [
        if (widget.room.isGroup)
          IconButton(
            icon: const Icon(Icons.info_outline, color: Colors.black87),
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => GroupInfoScreen(room: widget.room),
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildMessageList(List<ChatMessage> messages, String currentEmail) {
    return ListView.builder(
      controller: _scrollController,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      reverse: true,
      itemCount: messages.length,
      itemBuilder: (context, index) {
        final i = messages.length - 1 - index;
        if (i < 0 || i >= messages.length) return const SizedBox.shrink();

        final message = messages[i];
        final isMine = message.senderEmail == currentEmail;
        final prev = i > 0 ? messages[i - 1] : null;
        final next = i < messages.length - 1 ? messages[i + 1] : null;

        final isGroupedWithNext = _shouldGroupWithNext(message, next);

        return Column(
          children: [
            if (_shouldShowDate(message, prev)) _buildDateSeparator(message),
            GestureDetector(
              onLongPress: () => _showMessageOptions(message),
              child: _buildMessageBubble(message, isMine, isGroupedWithNext),
            ),
          ],
        );
      },
    );
  }

  Widget _buildDateSeparator(ChatMessage message) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Center(
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
          decoration: BoxDecoration(
            color: Colors.grey.shade200.withOpacity(0.8),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Text(
            _formatDate(message.createdAt),
            style: TextStyle(
              fontSize: 13,
              color: Colors.grey.shade600,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildMessageBubble(ChatMessage message, bool isMine, bool isGrouped) {
    if (message.isSystem) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Center(
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            decoration: BoxDecoration(
              color: Colors.grey.shade200.withOpacity(0.8),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              message.content ?? '',
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey.shade700,
                fontStyle: FontStyle.italic,
              ),
            ),
          ),
        ),
      );
    }

    return Padding(
      padding: EdgeInsets.only(
        top: isGrouped ? 1 : 6,
        left: isMine ? 80 : 8,
        right: isMine ? 8 : 80,
        bottom: 1,
      ),
      child: Row(
        mainAxisAlignment: isMine ? MainAxisAlignment.end : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          if (!isMine && !isGrouped)
            Padding(
              padding: const EdgeInsets.only(right: 8, bottom: 4),
              child: CircleAvatar(
                radius: 18,
                backgroundColor: _getAvatarColor(message.senderDisplayName),
                child: Text(
                  message.senderDisplayName.isNotEmpty
                      ? message.senderDisplayName[0].toUpperCase()
                      : '?',
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
              ),
            ),
          if (!isMine && isGrouped) const SizedBox(width: 44),
          Flexible(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: isMine ? const Color(0xFFB9FF66) : Colors.white,
                borderRadius: BorderRadius.only(
                  topLeft: const Radius.circular(18),
                  topRight: const Radius.circular(18),
                  bottomLeft: isMine
                      ? const Radius.circular(18)
                      : const Radius.circular(4),
                  bottomRight: isMine
                      ? const Radius.circular(4)
                      : const Radius.circular(18),
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.04),
                    blurRadius: 4,
                    offset: const Offset(0, 1),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (!isMine && widget.room.isGroup && !isGrouped)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 4),
                      child: Text(
                        message.senderDisplayName,
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF0077B3),
                        ),
                      ),
                    ),
                  if (message.replyTo != null)
                    _buildReplyQuote(message.replyTo!, isMine),
                  _buildMessageContent(message, isMine),
                  const SizedBox(height: 4),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        _formatTime(message.createdAt),
                        style: TextStyle(
                          fontSize: 11,
                          color: isMine ? Colors.black54 : Colors.grey.shade500,
                        ),
                      ),
                      if (message.isEdited && !message.isDeleted) ...[
                        const SizedBox(width: 4),
                        Text(
                          'edited',
                          style: TextStyle(
                            fontSize: 10,
                            color: isMine ? Colors.black45 : Colors.grey.shade400,
                          ),
                        ),
                      ],
                      if (isMine && message.readBy.isNotEmpty) ...[
                        const SizedBox(width: 4),
                        const Icon(Icons.done_all, size: 14, color: Colors.blue),
                      ] else if (isMine && message.readBy.isEmpty) ...[
                        const SizedBox(width: 4),
                        const Icon(Icons.done, size: 14, color: Colors.grey),
                      ],
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildReplyQuote(ReplyToDto replyTo, bool isMine) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      margin: const EdgeInsets.only(bottom: 6),
      decoration: BoxDecoration(
        border: Border(
          left: BorderSide(
            color: isMine ? Colors.black38 : Colors.grey.shade400,
            width: 3,
          ),
        ),
        color: isMine
            ? Colors.black.withOpacity(0.05)
            : Colors.grey.shade100,
        borderRadius: const BorderRadius.only(
          topRight: Radius.circular(6),
          bottomRight: Radius.circular(6),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            replyTo.senderDisplayName,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: isMine ? Colors.black54 : Colors.black87,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            replyTo.contentPreview,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 12,
              color: isMine ? Colors.black45 : Colors.grey.shade600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMessageContent(ChatMessage message, bool isMine) {
    if (message.isDeleted) {
      return Text(
        'This message was deleted',
        style: TextStyle(
          fontSize: 13,
          fontStyle: FontStyle.italic,
          color: isMine ? Colors.black45 : Colors.grey.shade500,
        ),
      );
    }

    switch (message.type) {
      case MessageType.image:
        if (message.imageUrl != null && message.imageUrl!.isNotEmpty) {
          return GestureDetector(
            onTap: () => _showImagePreview(message.imageUrl!),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: Image.network(
                message.imageUrl!,
                width: 200,
                height: 200,
                fit: BoxFit.cover,
                loadingBuilder: (_, child, progress) => progress == null
                    ? child
                    : Container(
                  width: 200,
                  height: 200,
                  color: Colors.grey.shade200,
                  child: const Center(
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                ),
                errorBuilder: (_, __, ___) => Container(
                  width: 200,
                  height: 200,
                  color: Colors.grey.shade200,
                  child: const Center(child: Icon(Icons.broken_image, color: Colors.grey)),
                ),
              ),
            ),
          );
        }
        return SelectableText(
          message.content ?? '',
          style: TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.bold,
            color: isMine ? Colors.black : Colors.black87,
          ),
        );

      case MessageType.voice:
        return VoiceMessageWidget(
          audioUrl: '${ChatService.baseUrl}/messages/${message.id}/voice',
          messageId: message.id,
          duration: message.voiceDurationSecs ?? 0,
          isMine: isMine,
        );

      case MessageType.system:
      case MessageType.text:
      default:
        final content = message.content ?? '';

        final isFileUrl = RegExp(r'\.(pdf|doc|docx|xls|xlsx|ppt|pptx|txt|zip|rar|7z|mp4|mov|avi|mkv)(\?|$)', caseSensitive: false).hasMatch(content) ||
            content.contains('s3.amazonaws.com') && !RegExp(r'\.(jpg|jpeg|png|gif|webp)(\?|$)', caseSensitive: false).hasMatch(content);

        final isImageUrl = RegExp(r'\.(jpg|jpeg|png|gif|webp)(\?|$)', caseSensitive: false).hasMatch(content);

        if (isImageUrl) {
          return GestureDetector(
            onTap: () => _showImagePreview(content),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: Image.network(
                content,
                width: 200,
                height: 200,
                fit: BoxFit.cover,
                loadingBuilder: (_, child, progress) => progress == null
                    ? child
                    : Container(
                  width: 200,
                  height: 200,
                  color: Colors.grey.shade200,
                  child: const Center(
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                ),
                errorBuilder: (_, __, ___) => Container(
                  width: 200,
                  height: 200,
                  color: Colors.grey.shade200,
                  child: const Center(child: Icon(Icons.broken_image, color: Colors.grey)),
                ),
              ),
            ),
          );
        } else if (isFileUrl) {
          final fileName = _getFileName(content);
          final fileType = _getFileType(fileName);

          return GestureDetector(
            onTap: () => _openFile(content),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                color: isMine ? Colors.black12 : Colors.grey.shade100,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: isMine ? Colors.black26 : Colors.grey.shade300,
                  width: 1,
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    _getFileIcon(fileName),
                    size: 24,
                    color: isMine ? Colors.black54 : Colors.black87,
                  ),
                  const SizedBox(width: 10),
                  Flexible(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          fileName,
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                            color: isMine ? Colors.black87 : Colors.black87,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        Text(
                          fileType,
                          style: TextStyle(
                            fontSize: 11,
                            color: Colors.grey.shade500,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  Icon(
                    Icons.open_in_new,
                    size: 18,
                    color: isMine ? Colors.black54 : Colors.black87,
                  ),
                ],
              ),
            ),
          );
        }

        return SelectableText.rich(
          TextSpan(
            text: content,
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.bold, // ← BOLD TEXT HERE
              color: isMine ? Colors.black : Colors.black87,
            ),
          ),
        );
    }
  }

  void _showImagePreview(String url) {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        backgroundColor: Colors.transparent,
        child: GestureDetector(
          onTap: () => Navigator.pop(context),
          child: InteractiveViewer(
            child: Image.network(url),
          ),
        ),
      ),
    );
  }

  Widget _buildReplyPreview() {
    if (_replyingTo == null) return const SizedBox.shrink();
    return Container(
      color: Colors.white.withOpacity(0.95),
      padding: const EdgeInsets.fromLTRB(12, 8, 8, 8),
      child: Row(
        children: [
          Container(
            width: 3,
            height: 40,
            color: Colors.grey.shade400,
            margin: const EdgeInsets.only(right: 8),
          ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _replyingTo!.senderDisplayName,
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: Colors.black87,
                  ),
                ),
                Text(
                  _replyingTo!.contentPreview,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 13,
                    color: Colors.grey,
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.close, size: 20, color: Colors.black),
            onPressed: () => setState(() => _replyingTo = null),
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(),
          ),
        ],
      ),
    );
  }

  Widget _buildVoiceRecordingUI() {
    return Container(
      color: Colors.white.withOpacity(0.95),
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
      child: Row(
        children: [
          const Icon(Icons.mic, color: Colors.red),
          const SizedBox(width: 12),
          Text(
            '${_recordingDuration}s',
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w500,
              color: Colors.red,
            ),
          ),
          const Spacer(),
          GestureDetector(
            onTap: _cancelVoiceRecording,
            child: Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.red.shade50,
              ),
              child: const Icon(Icons.close, color: Colors.red),
            ),
          ),
          const SizedBox(width: 8),
          GestureDetector(
            onTap: _stopVoiceRecording,
            child: Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.black,
              ),
              child: const Icon(Icons.check, color: Colors.white),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMessageInput() {
    return Container(
      color: Colors.white.withOpacity(0.95),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: SafeArea(
        top: false,
        child: Row(
          children: [
            if (!_isRecordingVoice)
              IconButton(
                icon: const Icon(Icons.attach_file, color: Colors.black54),
                onPressed: _showAttachmentMenu,
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
              ),
            const SizedBox(width: 8),
            Expanded(
              child: Container(
                decoration: BoxDecoration(
                  color: const Color(0xFFF0F0F0),
                  borderRadius: BorderRadius.circular(24),
                ),
                child: TextField(
                  controller: _messageController,
                  focusNode: _focusNode,
                  onChanged: (text) {
                    _sendTyping(text.isNotEmpty);
                    setState(() {});
                  },
                  decoration: InputDecoration(
                    hintText: 'Type a message…',
                    hintStyle: TextStyle(color: Colors.grey.shade500, fontSize: 15),
                    border: InputBorder.none,
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 10,
                    ),
                  ),
                  maxLines: null,
                  minLines: 1,
                  style: const TextStyle(color: Colors.black87, fontSize: 15),
                ),
              ),
            ),
            const SizedBox(width: 8),
            if (_messageController.text.isEmpty && !_isRecordingVoice)
              IconButton(
                icon: const Icon(Icons.mic, color: Colors.black54),
                onPressed: _startVoiceRecording,
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
              )
            else if (!_isRecordingVoice)
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: _isSending ? Colors.grey.shade400 : Colors.black,
                  shape: BoxShape.circle,
                ),
                child: IconButton(
                  icon: _isSending
                      ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                      : const Icon(Icons.send, color: Colors.white, size: 20),
                  onPressed: _isSending ? null : _sendTextMessage,
                  padding: EdgeInsets.zero,
                ),
              ),
          ],
        ),
      ),
    );
  }
}