import 'package:flutter/material.dart';
import '../../../models/comment_model.dart';
import '../../../services/announcement_service.dart';
import 'emoji_picker_widget.dart';

class CommentItem extends StatefulWidget {
  final Comment comment;
  final String postId;
  final bool isOwner;
  final VoidCallback onDelete;
  final Function(String) onReply;

  const CommentItem({
    super.key,
    required this.comment,
    required this.postId,
    required this.isOwner,
    required this.onDelete,
    required this.onReply,
  });

  @override
  State<CommentItem> createState() => _CommentItemState();
}

class _CommentItemState extends State<CommentItem> {
  bool _showReplyInput = false;
  final TextEditingController _replyController = TextEditingController();
  bool _showReplies = false;
  List<Comment> _replies = [];
  bool _isLoadingReplies = false;
  bool _isSubmittingReply = false;
  String? _replyError;
  int _repliesPage = 1;
  bool _hasMoreReplies = true;
  bool _showEmojiPicker = false;

  static const Color _lime = Color(0xFFB9FF66);
  static const Color _brand = Color(0xFF0077B3);
  static const Color _lightBg = Color(0xFFF8FAFB);

  String get _displayName {
    String name = widget.comment.createdBy;
    if (name.contains('@')) {
      return name.split('@').first;
    }
    return name;
  }

  @override
  void initState() {
    super.initState();
    if (widget.comment.replies.isNotEmpty) {
      _replies = List<Comment>.from(widget.comment.replies);
      _showReplies = widget.comment.showReplies;
    }
  }

  @override
  void dispose() {
    _replyController.dispose();
    super.dispose();
  }

  void _toggleReplyEmojiPicker() {
    setState(() {
      _showEmojiPicker = !_showEmojiPicker;
    });
  }

  void _onReplyEmojiSelected(String emoji) {
    final text = _replyController.text;
    final selection = _replyController.selection;
    final newText = text.replaceRange(selection.start, selection.end, emoji);
    _replyController.text = newText;
    _replyController.selection = TextSelection.fromPosition(
      TextPosition(offset: selection.start + emoji.length),
    );
  }

  void _onReplyBackspacePressed() {
    final text = _replyController.text;
    if (text.isNotEmpty) {
      final selection = _replyController.selection;
      if (selection.start > 0) {
        final newText = text.substring(0, selection.start - 1) + text.substring(selection.start);
        _replyController.text = newText;
        _replyController.selection = TextSelection.fromPosition(
          TextPosition(offset: selection.start - 1),
        );
      }
    }
  }

  Future<void> _loadReplies() async {
    if (_isLoadingReplies) return;
    setState(() {
      _isLoadingReplies = true;
      _repliesPage = 1;
      _hasMoreReplies = true;
    });

    try {
      final replies = await AnnouncementService.getReplies(
        widget.comment.id,
        pageNum: _repliesPage,
      );
      if (mounted) {
        setState(() {
          _replies = replies;
          _showReplies = true;
          _hasMoreReplies = replies.length >= 10;
          if (replies.isNotEmpty) {
            _repliesPage++;
          }
        });
      }
    } catch (e) {
      debugPrint('Error loading replies: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to load replies: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoadingReplies = false);
    }
  }

  Future<void> _loadMoreReplies() async {
    if (_isLoadingReplies || !_hasMoreReplies) return;

    setState(() => _isLoadingReplies = true);

    try {
      final replies = await AnnouncementService.getReplies(
        widget.comment.id,
        pageNum: _repliesPage,
      );
      if (mounted) {
        setState(() {
          _replies.addAll(replies);
          _hasMoreReplies = replies.length >= 10;
          if (replies.isNotEmpty) {
            _repliesPage++;
          }
        });
      }
    } catch (e) {
      debugPrint('Error loading more replies: $e');
    } finally {
      if (mounted) setState(() => _isLoadingReplies = false);
    }
  }

  Future<void> _submitReply() async {
    final content = _replyController.text.trim();
    if (content.isEmpty || _isSubmittingReply) return;

    if (content.length < 2) {
      setState(() => _replyError = 'Reply must be at least 2 characters');
      return;
    }

    setState(() {
      _isSubmittingReply = true;
      _replyError = null;
    });

    try {
      await widget.onReply(content);
      _replyController.clear();
      if (mounted) {
        setState(() => _showReplyInput = false);
        setState(() => _showEmojiPicker = false);
        await _loadReplies();
      }
    } catch (e) {
      if (mounted) {
        setState(() => _replyError = 'Failed to send reply');
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to post reply: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isSubmittingReply = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [_brand, _lime],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  shape: BoxShape.circle,
                ),
                child: Center(
                  child: Text(
                    _displayName.isNotEmpty ? _displayName[0].toUpperCase() : 'U',
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: Colors.black,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          _displayName,
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                            color: Colors.black87,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          _formatDate(widget.comment.createdAt),
                          style: TextStyle(
                            fontSize: 11,
                            color: Colors.grey.shade500,
                          ),
                        ),
                        if (widget.comment.isEdited)
                          Text(
                            ' (edited)',
                            style: TextStyle(
                              fontSize: 11,
                              color: Colors.grey.shade400,
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      widget.comment.content,
                      style: const TextStyle(fontSize: 14, color: Colors.black87),
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 16,
                      children: [
                        _actionButton(
                          label: 'Reply',
                          onPressed: () {
                            setState(() {
                              _showReplyInput = !_showReplyInput;
                              if (!_showReplyInput) {
                                _replyController.clear();
                                _replyError = null;
                                _showEmojiPicker = false;
                              }
                            });
                          },
                        ),
                        if (widget.comment.repliesCount > 0)
                          _actionButton(
                            label: _showReplies
                                ? 'Hide replies'
                                : 'View replies (${widget.comment.repliesCount})',
                            onPressed: () {
                              if (_showReplies) {
                                setState(() => _showReplies = false);
                              } else {
                                _loadReplies();
                              }
                            },
                          ),
                        if (widget.isOwner)
                          _actionButton(
                            label: 'Delete',
                            color: Colors.red,
                            onPressed: widget.onDelete,
                          ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),

          if (_showReplyInput)
            Padding(
              padding: const EdgeInsets.only(left: 44, top: 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _replyController,
                          style: const TextStyle(color: Colors.black87),
                          decoration: InputDecoration(
                            hintText: 'Write a reply...',
                            hintStyle: TextStyle(color: Colors.grey.shade500),
                            errorText: _replyError,
                            filled: true,
                            fillColor: _lightBg,
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(20),
                              borderSide: BorderSide.none,
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(20),
                              borderSide: BorderSide(color: _lime, width: 1.5),
                            ),
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 8,
                            ),
                            suffixIcon: IconButton(
                              icon: Icon(
                                Icons.emoji_emotions,
                                color: _showEmojiPicker ? _lime : Colors.grey.shade500,
                              ),
                              onPressed: _toggleReplyEmojiPicker,
                            ),
                          ),
                          maxLines: 2,
                          enabled: !_isSubmittingReply,
                        ),
                      ),
                      const SizedBox(width: 8),
                      _isSubmittingReply
                          ? const SizedBox(
                        width: 24,
                        height: 24,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                          : Container(
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            colors: [Color(0xFFB9FF66), Color(0xFF8FE3D3)],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          shape: BoxShape.circle,
                        ),
                        child: IconButton(
                          icon: const Icon(Icons.send, color: Colors.black),
                          onPressed: _submitReply,
                        ),
                      ),
                    ],
                  ),
                  if (_showEmojiPicker)
                    EmojiPickerWidget(
                      onEmojiSelected: _onReplyEmojiSelected,
                      onBackspacePressed: _onReplyBackspacePressed,
                      showPicker: _showEmojiPicker,
                    ),
                ],
              ),
            ),

          if (_isLoadingReplies && _replies.isEmpty)
            const Padding(
              padding: EdgeInsets.only(left: 44, top: 8),
              child: SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            ),
          if (_showReplies && _replies.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(left: 44, top: 12),
              child: Column(
                children: [
                  ..._replies.map((reply) => _buildReplyItem(reply)),
                  if (_hasMoreReplies && !_isLoadingReplies)
                    Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: TextButton(
                        onPressed: _loadMoreReplies,
                        child: Text(
                          'Load more replies',
                          style: TextStyle(fontSize: 12, color: _lime),
                        ),
                      ),
                    ),
                  if (_isLoadingReplies && _replies.isNotEmpty)
                    const Padding(
                      padding: EdgeInsets.all(8),
                      child: SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                    ),
                ],
              ),
            ),
          if (_showReplies && _replies.isEmpty && !_isLoadingReplies)
            const Padding(
              padding: EdgeInsets.only(left: 44, top: 8),
              child: Text(
                'No replies yet',
                style: TextStyle(color: Colors.grey, fontSize: 12),
              ),
            ),
        ],
      ),
    );
  }

  Widget _actionButton({
    required String label,
    required VoidCallback onPressed,
    Color? color,
  }) {
    return TextButton(
      onPressed: onPressed,
      style: TextButton.styleFrom(
        padding: EdgeInsets.zero,
        minimumSize: const Size(0, 0),
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
        foregroundColor: color ?? _lime,
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 12,
          color: color ?? _lime,
        ),
      ),
    );
  }

  Widget _buildReplyItem(Comment reply) {
    String displayName = reply.createdBy;
    if (displayName.contains('@')) {
      displayName = displayName.split('@').first;
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 24,
            height: 24,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [_brand, _lime],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              shape: BoxShape.circle,
            ),
            child: Center(
              child: Text(
                displayName.isNotEmpty ? displayName[0].toUpperCase() : 'U',
                style: const TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                  color: Colors.black,
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      displayName,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                        color: Colors.black87,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      _formatDate(reply.createdAt),
                      style: TextStyle(
                        fontSize: 10,
                        color: Colors.grey.shade500,
                      ),
                    ),
                    if (reply.isEdited)
                      Text(
                        ' (edited)',
                        style: TextStyle(
                          fontSize: 10,
                          color: Colors.grey.shade400,
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  reply.content,
                  style: const TextStyle(fontSize: 13, color: Colors.black87),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final postDate = DateTime(date.year, date.month, date.day);
    final differenceInDays = today.difference(postDate).inDays;

    if (differenceInDays == 0) {
      int hour = date.hour;
      final minute = date.minute.toString().padLeft(2, '0');
      final amPm = hour >= 12 ? 'PM' : 'AM';
      hour = hour % 12;
      if (hour == 0) hour = 12;
      return '$hour:$minute $amPm';
    }

    if (differenceInDays == 1) {
      return 'Yesterday';
    }

    if (differenceInDays < 7) {
      const weekdays = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
      return weekdays[date.weekday - 1];
    }

    final day = date.day.toString().padLeft(2, '0');
    final month = date.month.toString().padLeft(2, '0');
    return '$day/$month';
  }
}