import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import '../services/ai_service.dart';

class AIChatScreen extends StatefulWidget {
  final String userName;
  final String? explainMaterialId;
  final String? explainMaterialTitle;

  const AIChatScreen({
    super.key,
    required this.userName,
    this.explainMaterialId,
    this.explainMaterialTitle,
  });

  @override
  State<AIChatScreen> createState() => _AIChatScreenState();
}

class _AIChatScreenState extends State<AIChatScreen> {
  final TextEditingController _inputController = TextEditingController();
  final ScrollController _scrollController = ScrollController();

  final List<Map<String, dynamic>> _messages = [];

  bool _isStreaming = false;
  bool _isExplainRequest = false;
  StreamSubscription? _streamSubscription;

  String _pendingText = '';
  String _displayedText = '';

  Timer? _typewriterTimer;
  Timer? _dotTimer;
  int _dotCount = 0;

  final List<Map<String, dynamic>> _capabilities = [
    {'text': 'Summarize material'},
    {'text': 'Create practice questions'},
    {'text': 'Explain topics'},
    {'text': 'Create roadmap'},
    {'text': 'Help with assignments'},
    {'text': 'Create test bank questions'},
  ];

  static const Color _lime = Color(0xFFB9FF66);
  static const Color _brand = Color(0xFF0077B3);
  static const Color _lightBg = Color(0xFFF8FAFB);
  static const Color _darkBlue = Color(0xFF1E3A5F);
  static const Color _sendButtonColor = Color(0xFFBFFF6B);

  @override
  void initState() {
    super.initState();

    if (widget.explainMaterialId != null) {
      _isExplainRequest = true;
      _messages.clear();
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _sendExplainRequest();
      });
    } else {
      _loadChatHistory();
    }

    _dotTimer = Timer.periodic(const Duration(milliseconds: 400), (timer) {
      if (mounted && _isStreaming && _displayedText.isEmpty) {
        setState(() {
          _dotCount = (_dotCount + 1) % 4;
        });
      }
    });
  }

  @override
  void dispose() {
    _inputController.dispose();
    _scrollController.dispose();
    _streamSubscription?.cancel();
    _typewriterTimer?.cancel();
    _dotTimer?.cancel();
    super.dispose();
  }

  Widget _buildLumosAvatar({double size = 40}) {
    return Container(
      width: size,
      height: size,
      decoration: const BoxDecoration(
        shape: BoxShape.circle,
      ),
      child: ClipOval(
        child: Image.asset(
          'assets/images/lumos_logo.png',
          fit: BoxFit.contain,
          errorBuilder: (_, __, ___) => Container(
            decoration: BoxDecoration(
              color: _darkBlue,
              shape: BoxShape.circle,
            ),
            child: Center(
              child: Text(
                'L',
                style: TextStyle(
                  fontSize: size * 0.5,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  void _scrollToBottom({bool animated = false}) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scrollController.hasClients) return;

      if (animated) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeOut,
        );
      } else {
        _scrollController.jumpTo(
          _scrollController.position.maxScrollExtent,
        );
      }
    });
  }

  void _appendChunk(String chunk) {
    if (_pendingText.isNotEmpty &&
        !RegExp(r'[\s\n]$').hasMatch(_pendingText) &&
        !RegExp(r'^[\s\n]').hasMatch(chunk)) {
      _pendingText += ' ';
    }

    _pendingText += chunk;
  }

  void _startTypewriter() {
    if (_typewriterTimer != null) return;

    _typewriterTimer = Timer.periodic(
      const Duration(milliseconds: 30),
          (timer) {
        if (_pendingText.isNotEmpty) {
          final nextSpace = _pendingText.indexOf(' ');
          final nextPeriod = _pendingText.indexOf('.');
          final nextNewLine = _pendingText.indexOf('\n');

          int chunkSize;
          if (nextSpace != -1 && nextSpace < 15) {
            chunkSize = nextSpace + 1;
          } else if (nextPeriod != -1 && nextPeriod < 20) {
            chunkSize = nextPeriod + 1;
          } else if (nextNewLine != -1 && nextNewLine < 10) {
            chunkSize = nextNewLine + 1;
          } else {
            chunkSize = math.min(8, _pendingText.length);
          }

          final chunk = _pendingText.substring(0, chunkSize);

          setState(() {
            _displayedText += chunk;
            _pendingText = _pendingText.substring(chunk.length);
          });

          _scrollToBottom();
        } else if (!_isStreaming) {
          _stopTypewriter();
        }
      },
    );
  }

  void _stopTypewriter() {
    _typewriterTimer?.cancel();
    _typewriterTimer = null;

    if (_pendingText.isNotEmpty && mounted) {
      setState(() {
        _displayedText += _pendingText;
        _pendingText = '';
      });
    }
  }

  Future<void> _loadChatHistory() async {
    final history = await AIService.getChatHistory();
    if (!mounted) return;

    setState(() {
      _messages.clear();
      _messages.addAll(history);
    });

    _scrollToBottom();
  }

  Future<void> _sendMessage() async {
    final message = _inputController.text.trim();
    if (message.isEmpty || _isStreaming) return;

    FocusScope.of(context).unfocus();

    setState(() {
      _messages.add({
        'from': 'user',
        'text': message,
      });

      _inputController.clear();
      _isStreaming = true;
      _pendingText = '';
      _displayedText = '';
    });

    _scrollToBottom(animated: true);

    await _streamSubscription?.cancel();

    _streamSubscription = AIService.sendMessage(message).listen(
          (chunk) {
        if (!mounted) return;

        setState(() {
          _appendChunk(chunk);
        });

        _startTypewriter();
        _scrollToBottom();
      },
      onDone: () {
        if (!mounted) return;

        _stopTypewriter();

        setState(() {
          if (_displayedText.trim().isNotEmpty) {
            _messages.add({
              'from': 'ai',
              'text': _displayedText.trim(),
            });
          }

          _isStreaming = false;
          _pendingText = '';
          _displayedText = '';
        });

        _scrollToBottom(animated: true);
      },
      onError: (error) {
        if (!mounted) return;

        _stopTypewriter();

        setState(() {
          _messages.add({
            'from': 'ai',
            'text': 'Sorry, I encountered an error. Please try again.',
          });

          _isStreaming = false;
          _pendingText = '';
          _displayedText = '';
        });
      },
    );
  }

  Future<void> _sendExplainRequest() async {
    setState(() {
      _messages.add({
        'from': 'user',
        'text': 'Explain this material: ${widget.explainMaterialTitle ?? "material"}',
      });
      _isStreaming = true;
      _pendingText = '';
      _displayedText = '';
    });

    _scrollToBottom(animated: true);

    await _streamSubscription?.cancel();

    _streamSubscription = AIService.explainMaterial(widget.explainMaterialId!).listen(
          (chunk) {
        if (!mounted) return;

        setState(() {
          _appendChunk(chunk);
        });

        _startTypewriter();
        _scrollToBottom();
      },
      onDone: () {
        if (!mounted) return;

        _stopTypewriter();

        setState(() {
          if (_displayedText.trim().isNotEmpty) {
            _messages.add({
              'from': 'ai',
              'text': _displayedText.trim(),
            });
          }
          _isStreaming = false;
          _pendingText = '';
          _displayedText = '';
        });

        _scrollToBottom(animated: true);
      },
      onError: (error) {
        if (!mounted) return;

        _stopTypewriter();

        setState(() {
          _messages.add({
            'from': 'ai',
            'text': 'Sorry, I encountered an error while explaining this material.',
          });
          _isStreaming = false;
          _pendingText = '';
          _displayedText = '';
        });
      },
    );
  }

  void _retryLastMessage() {
    if (_isStreaming) return;

    for (int i = _messages.length - 1; i >= 0; i--) {
      if (_messages[i]['from'] == 'user') {
        final message = _messages[i]['text'];

        if (i + 1 < _messages.length && _messages[i + 1]['from'] == 'ai') {
          setState(() {
            _messages.removeAt(i + 1);
          });
        }

        _sendMessageWithText(message);
        break;
      }
    }
  }

  Future<void> _sendMessageWithText(String message) async {
    if (_isStreaming) return;

    setState(() {
      _isStreaming = true;
      _pendingText = '';
      _displayedText = '';
    });

    await _streamSubscription?.cancel();

    _streamSubscription = AIService.sendMessage(message).listen(
          (chunk) {
        if (!mounted) return;

        setState(() {
          _appendChunk(chunk);
        });

        _startTypewriter();
        _scrollToBottom();
      },
      onDone: () {
        if (!mounted) return;

        _stopTypewriter();

        setState(() {
          if (_displayedText.trim().isNotEmpty) {
            _messages.add({
              'from': 'ai',
              'text': _displayedText.trim(),
            });
          }
          _isStreaming = false;
          _pendingText = '';
          _displayedText = '';
        });

        _scrollToBottom(animated: true);
      },
      onError: (error) {
        if (!mounted) return;

        _stopTypewriter();

        setState(() {
          _messages.add({
            'from': 'ai',
            'text': 'Sorry, I encountered an error. Please try again.',
          });
          _isStreaming = false;
          _pendingText = '';
          _displayedText = '';
        });
      },
    );
  }

  Future<void> _copyToClipboard(String text) async {
    await Clipboard.setData(ClipboardData(text: text));
    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Copied to clipboard'),
        duration: Duration(seconds: 1),
      ),
    );
  }

  Future<void> _newChat() async {
    await AIService.clearChatHistory();

    setState(() {
      _messages.clear();
      _inputController.clear();
      _isStreaming = false;
      _pendingText = '';
      _displayedText = '';
    });
  }

  void _stopStreaming() {
    _streamSubscription?.cancel();
    _stopTypewriter();

    final remaining = _displayedText + _pendingText;

    setState(() {
      _isStreaming = false;

      if (remaining.trim().isNotEmpty) {
        _messages.add({
          'from': 'ai',
          'text': remaining.trim(),
        });
      }

      _pendingText = '';
      _displayedText = '';
    });
  }

  @override
  Widget build(BuildContext context) {
    final hasMessages = _messages.isNotEmpty;
    final userInitial = widget.userName.isNotEmpty ? widget.userName[0].toUpperCase() : 'U';

    return Scaffold(
      backgroundColor: _lightBg,
      body: Column(
        children: [
          // ── Custom App Bar ──────────────────────────────────────────
          Container(
            color: Colors.white,
            child: SafeArea(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                child: Row(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.arrow_back_ios_new, color: Colors.black, size: 20),
                      onPressed: () => Navigator.of(context).pop(),
                    ),
                    _buildLumosAvatar(size: 36),
                    const SizedBox(width: 10),
                    const Text(
                      'Lumos AI',
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                        color: Colors.black87,
                      ),
                    ),
                    const Spacer(),
                    IconButton(
                      icon: const Icon(Icons.delete_outline, color: Colors.red),
                      onPressed: _messages.isEmpty ? null : _newChat,
                    ),
                  ],
                ),
              ),
            ),
          ),

          // ── Content ──────────────────────────────────────────────────
          Expanded(
            child: hasMessages
                ? ListView.builder(
              controller: _scrollController,
              padding: const EdgeInsets.all(16),
              itemCount: _messages.length + (_isStreaming ? 1 : 0),
              itemBuilder: (context, index) {
                if (index == _messages.length && _isStreaming) {
                  return _buildStreamingMessage();
                }
                final message = _messages[index];
                final isUser = message['from'] == 'user';
                return _buildMessageBubble(
                  text: message['text'],
                  isUser: isUser,
                  userInitial: userInitial,
                  onCopy: () => _copyToClipboard(message['text']),
                  onRetry: !isUser ? _retryLastMessage : null,
                );
              },
            )
                : _buildEmptyState(userInitial),
          ),
          _buildInputBar(),
        ],
      ),
    );
  }

  Widget _buildEmptyState(String userInitial) {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Lumos Logo without background
            Container(
              width: 120,
              height: 120,
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
              ),
              child: Image.asset(
                'assets/images/lumos_logo.png',
                fit: BoxFit.contain,
                errorBuilder: (_, __, ___) => Container(
                  decoration: BoxDecoration(
                    color: _darkBlue,
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: _darkBlue.withOpacity(0.3),
                        blurRadius: 20,
                        spreadRadius: 5,
                      ),
                    ],
                  ),
                  child: const Center(
                    child: Text(
                      'L',
                      style: TextStyle(
                        fontSize: 48,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 24),
            const Text(
              'Lumos AI',
              style: TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.bold,
                color: Colors.black87,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Connecting Knowledge, Empowering Minds.',
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey.shade600,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 32),
            // Capabilities grid - 2 columns with updated colors and no emojis
            GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                childAspectRatio: 3.2,
                crossAxisSpacing: 12,
                mainAxisSpacing: 12,
              ),
              itemCount: _capabilities.length,
              itemBuilder: (context, index) {
                final capability = _capabilities[index];
                return GestureDetector(
                  onTap: () {
                    _inputController.text = capability['text'];
                    _sendMessage();
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFFF7CC), // #FFF7CC background
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: Colors.grey.shade200,
                        width: 1,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.grey.withOpacity(0.05),
                          blurRadius: 4,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Center(
                      child: Text(
                        capability['text'],
                        style: const TextStyle(
                          fontSize: 13, // Reverted back to 13
                          fontWeight: FontWeight.w500,
                          color: Color(0xFF8A6A00), // #8A6A00 text color
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ),
                );
              },
            ),
            const SizedBox(height: 16),
            // "And more..." chip with updated colors
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: const Color(0xFFFFF7CC), // #FFF7CC background
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: Colors.grey.shade200,
                  width: 1,
                ),
              ),
              child: Text(
                'And more...',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                  color: const Color(0xFF8A6A00), // #8A6A00 text color
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMessageBubble({
    required String text,
    required bool isUser,
    required String userInitial,
    required VoidCallback onCopy,
    VoidCallback? onRetry,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(
        mainAxisAlignment: isUser ? MainAxisAlignment.end : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (!isUser) ...[
            _buildLumosAvatar(size: 40),
            const SizedBox(width: 10),
          ],
          Flexible(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: isUser ? _lime : Colors.white,
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  if (!isUser)
                    BoxShadow(
                      color: Colors.grey.withOpacity(0.1),
                      blurRadius: 4,
                      offset: const Offset(0, 2),
                    ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (isUser)
                    SelectableText(
                      text,
                      style: const TextStyle(color: Colors.black, fontSize: 15, height: 1.5),
                    )
                  else
                    MarkdownBody(
                      shrinkWrap: true,
                      selectable: true,
                      data: text,
                      styleSheet: MarkdownStyleSheet(
                        p: const TextStyle(fontSize: 15, color: Colors.black87, height: 1.6),
                        h1: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, height: 1.5),
                        h2: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, height: 1.5),
                        strong: const TextStyle(fontWeight: FontWeight.bold),
                        pPadding: const EdgeInsets.only(bottom: 10),
                        codeblockPadding: const EdgeInsets.all(12),
                        blockquotePadding: const EdgeInsets.all(12),
                      ),
                    ),
                  if (!isUser)
                    Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(
                            icon: Icon(Icons.copy, size: 18, color: Colors.grey.shade500),
                            onPressed: onCopy,
                            padding: EdgeInsets.zero,
                            constraints: const BoxConstraints(),
                          ),
                          if (onRetry != null)
                            IconButton(
                              icon: Icon(Icons.refresh, size: 18, color: Colors.grey.shade500),
                              onPressed: onRetry,
                              padding: EdgeInsets.zero,
                              constraints: const BoxConstraints(),
                            ),
                        ],
                      ),
                    ),
                ],
              ),
            ),
          ),
          if (isUser) ...[
            const SizedBox(width: 10),
            CircleAvatar(
              radius: 20,
              backgroundColor: _darkBlue,
              child: Text(
                userInitial,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildStreamingMessage() {
    final isThinking = _displayedText.isEmpty;

    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildLumosAvatar(size: 40),
          const SizedBox(width: 10),
          Flexible(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: Colors.grey.withOpacity(0.1),
                    blurRadius: 4,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: isThinking
                  ? Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text(
                    'Thinking',
                    style: TextStyle(
                      color: Colors.grey,
                      fontSize: 15,
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                  const SizedBox(width: 4),
                  Row(
                    children: List.generate(3, (index) {
                      return AnimatedOpacity(
                        opacity: _dotCount > index ? 1.0 : 0.2,
                        duration: const Duration(milliseconds: 200),
                        child: Container(
                          width: 6,
                          height: 6,
                          margin: const EdgeInsets.only(right: 2),
                          decoration: const BoxDecoration(
                            color: _lime,
                            shape: BoxShape.circle,
                          ),
                        ),
                      );
                    }),
                  ),
                ],
              )
                  : Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SingleChildScrollView(
                    physics: const NeverScrollableScrollPhysics(),
                    child: MarkdownBody(
                      shrinkWrap: true,
                      data: _displayedText,
                      styleSheet: MarkdownStyleSheet(
                        p: TextStyle(fontSize: 15, color: Colors.black87, height: 1.6),
                      ),
                    ),
                  ),
                  if (_isStreaming)
                    const Text(
                      '▋',
                      style: TextStyle(color: _lime, fontSize: 16),
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInputBar() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.1),
            blurRadius: 8,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              decoration: BoxDecoration(
                color: Colors.grey.shade100,
                borderRadius: BorderRadius.circular(30),
                border: Border.all(
                  color: _isStreaming ? _lime : Colors.transparent,
                  width: 1.5,
                ),
              ),
              child: TextField(
                controller: _inputController,
                enabled: !_isStreaming,
                maxLines: 4,
                minLines: 1,
                textInputAction: TextInputAction.send,
                onSubmitted: (_) => _sendMessage(),
                decoration: InputDecoration(
                  hintText: _isStreaming ? 'AI is thinking...' : 'Type a message...',
                  hintStyle: TextStyle(color: Colors.grey.shade500),
                  border: InputBorder.none,
                  contentPadding: const EdgeInsets.symmetric(vertical: 12),
                ),
                style: const TextStyle(color: Colors.black87),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Container(
            decoration: BoxDecoration(
              color: _sendButtonColor, // #BFFF6B
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: _sendButtonColor.withOpacity(0.3),
                  blurRadius: 8,
                ),
              ],
            ),
            child: IconButton(
              icon: Icon(
                _isStreaming ? Icons.stop : Icons.send,
                color: Colors.black87,
              ),
              onPressed: _isStreaming ? _stopStreaming : _sendMessage,
            ),
          ),
        ],
      ),
    );
  }
}