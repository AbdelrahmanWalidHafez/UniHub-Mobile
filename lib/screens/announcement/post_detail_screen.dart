import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/announcement_provider.dart';
import '../../providers/auth_provider.dart';
import '../../models/post_model.dart';
import '../../models/comment_model.dart';
import 'widgets/comment_item.dart';
import 'widgets/media_preview_widget.dart';
import '../../services/announcement_service.dart';
import 'widgets/emoji_picker_widget.dart';

class PostDetailScreen extends StatefulWidget {
  final String postId;
  final Post? post;

  const PostDetailScreen({super.key, required this.postId, this.post});

  @override
  State<PostDetailScreen> createState() => _PostDetailScreenState();
}

class _PostDetailScreenState extends State<PostDetailScreen> {
  late Future<Post> _postFuture;
  final TextEditingController _commentController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  List<Comment> _comments = [];
  bool _isLoadingComments = false;
  bool _isSubmittingComment = false;
  bool _hasMoreComments = true;
  int _currentPage = 1;
  bool _showEmojiPicker = false;

  static const Color _brand = Color(0xFF0077B3);
  static const Color _lime = Color(0xFFB9FF66);
  static const Color _lightBg = Color(0xFFF8FAFB);
  static const Color _cardBg = Colors.white;

  @override
  void initState() {
    super.initState();
    _postFuture = _loadPost();
    _loadComments();
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _commentController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _toggleEmojiPicker() {
    setState(() {
      _showEmojiPicker = !_showEmojiPicker;
    });
  }

  void _onEmojiSelected(String emoji) {
    final text = _commentController.text;
    final selection = _commentController.selection;
    final newText = text.replaceRange(selection.start, selection.end, emoji);
    _commentController.text = newText;
    _commentController.selection = TextSelection.fromPosition(
      TextPosition(offset: selection.start + emoji.length),
    );
  }

  void _onBackspacePressed() {
    final text = _commentController.text;
    if (text.isNotEmpty) {
      final selection = _commentController.selection;
      if (selection.start > 0) {
        final newText = text.substring(0, selection.start - 1) + text.substring(selection.start);
        _commentController.text = newText;
        _commentController.selection = TextSelection.fromPosition(
          TextPosition(offset: selection.start - 1),
        );
      }
    }
  }

  Future<Post> _loadPost() async {
    if (widget.post != null) return widget.post!;
    return AnnouncementService.getPostById(widget.postId);
  }

  void _onScroll() {
    if (_scrollController.position.pixels >=
        _scrollController.position.maxScrollExtent - 200) {
      if (!_isLoadingComments && _hasMoreComments) {
        _loadComments();
      }
    }
  }

  Future<void> _loadComments() async {
    if (_isLoadingComments) return;
    setState(() => _isLoadingComments = true);
    try {
      final newComments = await AnnouncementService.getComments(
        widget.postId,
        pageNum: _currentPage,
      );
      if (mounted) {
        setState(() {
          if (newComments.isEmpty) {
            _hasMoreComments = false;
          } else {
            _comments.addAll(newComments);
            _currentPage++;
          }
        });
      }
    } catch (e) {
      debugPrint('Error loading comments: $e');
    } finally {
      if (mounted) setState(() => _isLoadingComments = false);
    }
  }

  Future<void> _reloadComments() async {
    _comments.clear();
    _currentPage = 1;
    _hasMoreComments = true;
    await _loadComments();
  }

  Future<void> _submitComment() async {
    final content = _commentController.text.trim();
    if (content.isEmpty || _isSubmittingComment) return;

    setState(() => _isSubmittingComment = true);
    _commentController.clear();

    try {
      await AnnouncementService.createComment(widget.postId, content);
      if (mounted) {
        await _reloadComments();
        _postFuture = _loadPost();
        context.read<AnnouncementProvider>().loadPosts(refresh: true);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to post comment: $e'),
            backgroundColor: Colors.red,
          ),
        );
        _commentController.text = content;
      }
    } finally {
      if (mounted) setState(() => _isSubmittingComment = false);
    }
  }

  Future<void> _toggleLike() async {
    final provider = context.read<AnnouncementProvider>();
    await provider.toggleLike(widget.postId);
    if (mounted) setState(() {});
  }

  Future<void> _deleteComment(Comment comment) async {
    final provider = context.read<AnnouncementProvider>();
    final isSecretary = provider.isSecretaryMode;

    try {
      if (isSecretary) {
        await AnnouncementService.deleteCommentSecretary(widget.postId, comment.id);
      } else {
        await AnnouncementService.deleteComment(comment.id);
      }
      if (mounted) {
        await _reloadComments();
        _postFuture = _loadPost();
        provider.loadPosts(refresh: true);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to delete comment: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  Future<void> _addReply(Comment comment, String replyContent) async {
    try {
      await AnnouncementService.createReply(comment.id, replyContent);
      if (mounted) {
        await _reloadComments();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to post reply: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final difference = now.difference(date);

    if (difference.inDays == 0) {
      int hour = date.hour;
      final minute = date.minute.toString().padLeft(2, '0');
      final amPm = hour >= 12 ? 'PM' : 'AM';
      hour = hour % 12;
      if (hour == 0) hour = 12;
      return '$hour:$minute $amPm';
    } else if (difference.inDays == 1) {
      return 'Yesterday';
    } else if (difference.inDays < 7) {
      const weekdays = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
      return weekdays[date.weekday - 1];
    } else {
      final day = date.day.toString().padLeft(2, '0');
      final month = date.month.toString().padLeft(2, '0');
      return '$day/$month';
    }
  }

  void _showImageFullScreen(BuildContext context, String url) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ImageViewer(imageUrl: url),
      ),
    );
  }

  Widget _buildPostCard(Post post) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: _cardBg,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.grey.shade200),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.1),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
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
                      post.displayName.isNotEmpty ? post.displayName[0].toUpperCase() : 'U',
                      style: const TextStyle(
                        fontSize: 18,
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
                      Text(
                        post.displayName,
                        style: const TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 15,
                          color: Colors.black87,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Text(
                            _formatDate(post.createdAt),
                            style: TextStyle(fontSize: 11, color: Colors.grey.shade500),
                          ),
                          if (post.isEdited && post.updatedAt != null) ...[
                            const SizedBox(width: 6),
                            Text(
                              'edited',
                              style: TextStyle(
                                fontSize: 10,
                                color: Colors.grey.shade400,
                                fontStyle: FontStyle.italic,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ],
                  ),
                ),
                if (post.status != PostStatus.accepted)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: post.statusColor.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: post.statusColor.withOpacity(0.3)),
                    ),
                    child: Text(
                      post.statusDisplay,
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: post.statusColor,
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 14),
            Text(
              post.title,
              style: const TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Colors.black87,
              ),
            ),
            if (post.content != null && post.content!.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 12),
                child: Text(
                  post.content!,
                  style: TextStyle(color: Colors.grey.shade700, height: 1.5),
                ),
              ),
            if (post.mediaUrl != null)
              Padding(
                padding: const EdgeInsets.only(top: 12),
                child: GestureDetector(
                  onTap: () {
                    if (post.mediaUrl!.toLowerCase().endsWith('.jpg') ||
                        post.mediaUrl!.toLowerCase().endsWith('.jpeg') ||
                        post.mediaUrl!.toLowerCase().endsWith('.png') ||
                        post.mediaUrl!.toLowerCase().endsWith('.gif')) {
                      _showImageFullScreen(context, post.mediaUrl!);
                    }
                  },
                  child: MediaPreviewWidget(
                    url: post.mediaUrl!,
                    height: 250,
                    showDownloadButton: true,
                  ),
                ),
              ),
            const SizedBox(height: 14),
            Row(
              children: [
                Material(
                  color: Colors.transparent,
                  child: InkWell(
                    onTap: _toggleLike,
                    borderRadius: BorderRadius.circular(30),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      child: Row(
                        children: [
                          Icon(
                            post.likedByCurrentUser ? Icons.favorite : Icons.favorite_border,
                            size: 18,
                            color: post.likedByCurrentUser ? Colors.red : Colors.grey.shade500,
                          ),
                          const SizedBox(width: 6),
                          Text(
                            post.likesCount.toString(),
                            style: TextStyle(
                              fontSize: 13,
                              color: post.likedByCurrentUser ? Colors.red : Colors.grey.shade500,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Material(
                  color: Colors.transparent,
                  child: InkWell(
                    onTap: () {},
                    borderRadius: BorderRadius.circular(30),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      child: Row(
                        children: [
                          const Icon(Icons.comment_outlined, size: 18, color: Colors.grey),
                          const SizedBox(width: 6),
                          Text(
                            post.commentsCount.toString(),
                            style: TextStyle(
                              fontSize: 13,
                              color: Colors.grey.shade500,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCommentInput() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.1),
            blurRadius: 10,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _commentController,
                  style: const TextStyle(color: Colors.black87),
                  decoration: InputDecoration(
                    hintText: 'Write a comment...',
                    hintStyle: TextStyle(color: Colors.grey.shade500),
                    filled: true,
                    fillColor: Colors.grey.shade50,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(24),
                      borderSide: BorderSide.none,
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(24),
                      borderSide: const BorderSide(color: _lime, width: 1.5),
                    ),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    suffixIcon: IconButton(
                      icon: Icon(
                        Icons.emoji_emotions,
                        color: _showEmojiPicker ? _lime : Colors.grey.shade500,
                      ),
                      onPressed: _toggleEmojiPicker,
                    ),
                  ),
                  maxLines: 3,
                  minLines: 1,
                  enabled: !_isSubmittingComment,
                ),
              ),
              const SizedBox(width: 8),
              _isSubmittingComment
                  ? const SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
                  : Container(
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [_brand, _lime],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  shape: BoxShape.circle,
                ),
                child: IconButton(
                  icon: const Icon(Icons.send, color: Colors.black),
                  onPressed: _submitComment,
                ),
              ),
            ],
          ),
          if (_showEmojiPicker)
            EmojiPickerWidget(
              onEmojiSelected: _onEmojiSelected,
              onBackspacePressed: _onBackspacePressed,
              showPicker: _showEmojiPicker,
            ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final authProvider = context.watch<AuthProvider>();
    final currentUserEmail = authProvider.userEmail;
    final currentUserName = authProvider.userName;

    return Scaffold(
      backgroundColor: _lightBg,
      appBar: AppBar(
        title: const Text('Post Details', style: TextStyle(color: Colors.black87)),
        backgroundColor: Colors.white,
        elevation: 0,
        foregroundColor: Colors.black87,
        centerTitle: false,
      ),
      body: FutureBuilder<Post>(
        future: _postFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.error_outline, size: 48, color: Colors.red),
                  const SizedBox(height: 16),
                  Text('Error: ${snapshot.error}', textAlign: TextAlign.center, style: const TextStyle(color: Colors.grey)),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: () {
                      setState(() {
                        _postFuture = _loadPost();
                        _reloadComments();
                      });
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _lime,
                      foregroundColor: Colors.black,
                    ),
                    child: const Text('Retry'),
                  ),
                ],
              ),
            );
          }

          final post = snapshot.data!;

          return Column(
            children: [
              Expanded(
                child: RefreshIndicator(
                  onRefresh: _reloadComments,
                  color: _lime,
                  backgroundColor: Colors.white,
                  child: ListView(
                    controller: _scrollController,
                    padding: const EdgeInsets.all(16),
                    children: [
                      _buildPostCard(post),
                      const SizedBox(height: 24),
                      Row(
                        children: [
                          Container(
                            width: 4,
                            height: 20,
                            decoration: BoxDecoration(
                              color: _lime,
                              borderRadius: BorderRadius.circular(2),
                            ),
                          ),
                          const SizedBox(width: 10),
                          const Text(
                            'Comments',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: Colors.black87,
                            ),
                          ),
                          const Spacer(),
                          Text(
                            '${_comments.length}',
                            style: TextStyle(color: Colors.grey.shade500),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      if (_comments.isEmpty && !_isLoadingComments)
                        Container(
                          padding: const EdgeInsets.all(32),
                          alignment: Alignment.center,
                          child: Column(
                            children: [
                              const Icon(Icons.chat_bubble_outline, size: 48, color: Colors.grey),
                              const SizedBox(height: 12),
                              Text(
                                'No comments yet',
                                style: TextStyle(color: Colors.grey.shade600),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                'Be the first to comment',
                                style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
                              ),
                            ],
                          ),
                        ),
                      ..._comments.map(
                            (comment) => CommentItem(
                          comment: comment,
                          postId: widget.postId,
                          isOwner: comment.createdBy == currentUserName ||
                              comment.createdBy == currentUserEmail,
                          onDelete: () => _deleteComment(comment),
                          onReply: (replyContent) => _addReply(comment, replyContent),
                        ),
                      ),
                      if (_isLoadingComments)
                        const Padding(
                          padding: EdgeInsets.all(16),
                          child: Center(
                            child: SizedBox(
                              width: 24,
                              height: 24,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            ),
                          ),
                        ),
                      const SizedBox(height: 80),
                    ],
                  ),
                ),
              ),
              _buildCommentInput(),
            ],
          );
        },
      ),
    );
  }
}