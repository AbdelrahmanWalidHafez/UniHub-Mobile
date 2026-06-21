import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../models/post_model.dart';
import '../../../providers/auth_provider.dart';
import 'media_preview_widget.dart';

class PostCard extends StatelessWidget {
  final Post post;
  final bool isSecretary;
  final bool isOwner;
  final Color avatarColor; // Added this
  final VoidCallback onLike;
  final VoidCallback onComment;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  final VoidCallback? onPublish;
  final VoidCallback? onAccept;
  final VoidCallback? onReject;

  const PostCard({
    super.key,
    required this.post,
    required this.isSecretary,
    required this.isOwner,
    required this.avatarColor, // Added this
    required this.onLike,
    required this.onComment,
    required this.onEdit,
    required this.onDelete,
    this.onPublish,
    this.onAccept,
    this.onReject,
  });

  static const Color _brand = Color(0xFF0077B3);
  static const Color _lime = Color(0xFFB9FF66);

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

  void _showImageFullScreen(BuildContext context) {
    if (post.mediaUrl != null) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => ImageViewer(imageUrl: post.mediaUrl!),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final authProvider = context.watch<AuthProvider>();
    final currentUserEmail = authProvider.userEmail;
    final currentUserName = authProvider.userName;

    final isPostOwner = post.createdBy == currentUserEmail ||
        post.displayName == currentUserName ||
        post.createdBy.split('@').first == currentUserName;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 0,
      color: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: Colors.grey.shade200),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header with author info
            Row(
              children: [
                CircleAvatar(
                  backgroundColor: avatarColor, // Changed from _lime to avatarColor
                  child: Text(
                    post.displayName.isNotEmpty ? post.displayName[0].toUpperCase() : 'U',
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Colors.white, // Changed to white for better contrast
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
                          fontSize: 14,
                          color: Colors.black87,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Row(
                        children: [
                          Text(
                            _formatDate(post.createdAt),
                            style: TextStyle(
                              fontSize: 11,
                              color: Colors.grey.shade500,
                            ),
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
                // Status badge
                if (post.status != PostStatus.accepted)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: post.statusColor.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: post.statusColor.withOpacity(0.3)),
                    ),
                    child: Text(
                      post.statusDisplay,
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                        color: post.statusColor,
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 12),

            // Title
            Text(
              post.title,
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.black87,
              ),
            ),
            const SizedBox(height: 8),

            // Content
            if (post.content != null && post.content!.isNotEmpty)
              Text(
                post.content!,
                style: TextStyle(
                  color: Colors.grey.shade700,
                  height: 1.5,
                ),
              ),
            const SizedBox(height: 12),

            // Media preview with full-screen image support
            // The file name is now hidden - only shows the media preview
            if (post.mediaUrl != null)
              GestureDetector(
                onTap: () {
                  // If image, open full-screen viewer
                  if (post.mediaUrl!.toLowerCase().endsWith('.jpg') ||
                      post.mediaUrl!.toLowerCase().endsWith('.jpeg') ||
                      post.mediaUrl!.toLowerCase().endsWith('.png') ||
                      post.mediaUrl!.toLowerCase().endsWith('.gif')) {
                    _showImageFullScreen(context);
                  }
                },
                child: MediaPreviewWidget(
                  url: post.mediaUrl!,
                  height: 200,
                  showDownloadButton: false, // Changed to false to hide file name
                ),
              ),
            const SizedBox(height: 12),

            // Action buttons
            Row(
              children: [
                // Like button
                Material(
                  color: Colors.transparent,
                  child: InkWell(
                    onTap: onLike,
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

                // Comment button
                Material(
                  color: Colors.transparent,
                  child: InkWell(
                    onTap: onComment,
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
                const Spacer(),

                // Action menu
                if (isPostOwner || isSecretary)
                  PopupMenuButton<String>(
                    onSelected: (value) {
                      switch (value) {
                        case 'edit':
                          onEdit();
                          break;
                        case 'delete':
                          onDelete();
                          break;
                        case 'publish':
                          if (onPublish != null) onPublish!();
                          break;
                      }
                    },
                    itemBuilder: (context) {
                      final items = <PopupMenuEntry<String>>[];

                      if (isPostOwner && post.status == PostStatus.draft) {
                        items.add(
                          const PopupMenuItem(
                            value: 'publish',
                            child: Text('Publish'),
                          ),
                        );
                      }

                      if (isPostOwner || isSecretary) {
                        items.add(
                          const PopupMenuItem(
                            value: 'edit',
                            child: Text('Edit'),
                          ),
                        );
                      }

                      if (isPostOwner || isSecretary) {
                        items.add(
                          const PopupMenuItem(
                            value: 'delete',
                            child: Text('Delete', style: TextStyle(color: Colors.red)),
                          ),
                        );
                      }

                      return items;
                    },
                    child: const Icon(Icons.more_vert, color: Colors.grey),
                  ),
              ],
            ),

            // Secretary action buttons
            if (isSecretary && post.status == PostStatus.pending) ...[
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton(
                      onPressed: onAccept,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      child: const Text('Accept'),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: onReject,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.red,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      child: const Text('Reject'),
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}