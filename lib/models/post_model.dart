import 'package:flutter/material.dart';

enum PostStatus {
  draft,
  pending,
  accepted,
  rejected,
}

extension PostStatusExtension on PostStatus {
  String get value {
    switch (this) {
      case PostStatus.draft:
        return 'DRAFT';
      case PostStatus.pending:
        return 'PENDING';
      case PostStatus.accepted:
        return 'ACCEPTED';
      case PostStatus.rejected:
        return 'REJECTED';
    }
  }

  String get display {
    switch (this) {
      case PostStatus.draft:
        return 'Draft';
      case PostStatus.pending:
        return 'Pending';
      case PostStatus.accepted:
        return 'Accepted';
      case PostStatus.rejected:
        return 'Rejected';
    }
  }

  Color get color {
    switch (this) {
      case PostStatus.draft:
        return Colors.grey;
      case PostStatus.pending:
        return Colors.orange;
      case PostStatus.accepted:
        return Colors.green;
      case PostStatus.rejected:
        return Colors.red;
    }
  }
}

class Post {
  final String id;
  final String title;
  final String? content;
  final String? mediaUrl;
  final DateTime createdAt;
  final DateTime? updatedAt;
  final String createdBy;
  final int likesCount;
  final int commentsCount;
  final bool likedByCurrentUser;
  final PostStatus status;
  final bool isEdited;
  final String displayName;

  Post({
    required this.id,
    required this.title,
    this.content,
    this.mediaUrl,
    required this.createdAt,
    this.updatedAt,
    required this.createdBy,
    required this.likesCount,
    required this.commentsCount,
    required this.likedByCurrentUser,
    required this.status,
    required this.isEdited,
    required this.displayName,
  });

  factory Post.fromJson(Map<String, dynamic> json) {
    print('=== PARSING POST JSON ===');
    print('Raw JSON: $json');

    // Get the ID - could be 'id' or 'post_id'
    final String id = (json['id'] ?? json['post_id']).toString();

    // Get title
    final String title = json['title']?.toString() ?? '';

    // Get content
    final String? content = json['content']?.toString();

    // Get media URL
    final String? mediaUrl = json['media_url']?.toString();

    // Get created_by email
    final String createdByEmail = json['created_by']?.toString() ?? 'unknown@email.com';

    // Extract name from email (before @)
    String displayName = createdByEmail.split('@').first;
    // Capitalize first letter
    if (displayName.isNotEmpty) {
      displayName = displayName[0].toUpperCase() + displayName.substring(1);
    }

    print('CreatedBy Email: $createdByEmail');
    print('DisplayName: $displayName');

    // Parse createdAt date correctly - FIXED
    DateTime createdAt;
    try {
      final createdAtStr = json['created_at']?.toString();
      if (createdAtStr != null && createdAtStr.isNotEmpty) {

        String cleanedDate = createdAtStr;
        if (cleanedDate.contains('.') && cleanedDate.length > 23) {

          cleanedDate = cleanedDate.substring(0, 23);
        }
        createdAt = DateTime.parse(cleanedDate);
        print('Parsed createdAt: $createdAt');
        print('Original string: $createdAtStr');
      } else {
        createdAt = DateTime.now();
        print('No created_at field, using now');
      }
    } catch (e) {
      print('Error parsing createdAt: $e');
      // Try alternative parsing
      try {
        final createdAtStr = json['created_at']?.toString();
        if (createdAtStr != null && createdAtStr.isNotEmpty) {

          createdAt = DateTime.parse(createdAtStr.split('.')[0]);
          print('Alternative parse succeeded: $createdAt');
        } else {
          createdAt = DateTime.now();
        }
      } catch (e2) {
        print('Alternative parse also failed: $e2');
        createdAt = DateTime.now();
      }
    }


    DateTime? updatedAt;
    try {
      final updatedAtStr = json['updated_at']?.toString();
      if (updatedAtStr != null && updatedAtStr.isNotEmpty) {
        String cleanedDate = updatedAtStr;
        if (cleanedDate.contains('.') && cleanedDate.length > 23) {
          cleanedDate = cleanedDate.substring(0, 23);
        }
        updatedAt = DateTime.parse(cleanedDate);
        print('Parsed updatedAt: $updatedAt');
      }
    } catch (e) {
      print('Error parsing updatedAt: $e');
      updatedAt = null;
    }


    PostStatus status = PostStatus.draft;
    final statusValue = json['status']?.toString().toUpperCase() ?? 'DRAFT';
    switch (statusValue) {
      case 'ACCEPTED':
        status = PostStatus.accepted;
        break;
      case 'PENDING':
        status = PostStatus.pending;
        break;
      case 'REJECTED':
        status = PostStatus.rejected;
        break;
      default:
        status = PostStatus.draft;
    }

    print('Status: $statusValue -> $status');


    int likesCount = 0;
    if (json['likes_count'] != null) {
      if (json['likes_count'] is int) {
        likesCount = json['likes_count'];
      } else if (json['likes_count'] is num) {
        likesCount = (json['likes_count'] as num).toInt();
      } else if (json['likes_count'] is String) {
        likesCount = int.tryParse(json['likes_count']) ?? 0;
      }
    }

    int commentsCount = 0;
    if (json['comments_count'] != null) {
      if (json['comments_count'] is int) {
        commentsCount = json['comments_count'];
      } else if (json['comments_count'] is num) {
        commentsCount = (json['comments_count'] as num).toInt();
      } else if (json['comments_count'] is String) {
        commentsCount = int.tryParse(json['comments_count']) ?? 0;
      }
    }


    bool likedByCurrentUser = json['liked_by_current_user'] == true;


    bool isEdited = false;
    if (updatedAt != null && createdAt != updatedAt) {
      // Check if the difference is more than 1 second
      final difference = updatedAt.difference(createdAt);
      if (difference.inSeconds.abs() > 1) {
        isEdited = true;
      }
    }

    print('Likes: $likesCount, Comments: $commentsCount, Liked: $likedByCurrentUser');
    print('Created: $createdAt, Updated: $updatedAt, IsEdited: $isEdited');

    return Post(
      id: id,
      title: title,
      content: content,
      mediaUrl: mediaUrl,
      createdAt: createdAt,
      updatedAt: updatedAt,
      createdBy: createdByEmail,
      likesCount: likesCount,
      commentsCount: commentsCount,
      likedByCurrentUser: likedByCurrentUser,
      status: status,
      isEdited: isEdited,
      displayName: displayName,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'content': content,
      'media_url': mediaUrl,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt?.toIso8601String(),
      'created_by': createdBy,
      'likes_count': likesCount,
      'comments_count': commentsCount,
      'liked_by_current_user': likedByCurrentUser,
      'status': status.value,
    };
  }

  Post copyWith({
    String? id,
    String? title,
    String? content,
    String? mediaUrl,
    DateTime? createdAt,
    DateTime? updatedAt,
    String? createdBy,
    int? likesCount,
    int? commentsCount,
    bool? likedByCurrentUser,
    PostStatus? status,
    bool? isEdited,
    String? displayName,
  }) {
    return Post(
      id: id ?? this.id,
      title: title ?? this.title,
      content: content ?? this.content,
      mediaUrl: mediaUrl ?? this.mediaUrl,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      createdBy: createdBy ?? this.createdBy,
      likesCount: likesCount ?? this.likesCount,
      commentsCount: commentsCount ?? this.commentsCount,
      likedByCurrentUser: likedByCurrentUser ?? this.likedByCurrentUser,
      status: status ?? this.status,
      isEdited: isEdited ?? this.isEdited,
      displayName: displayName ?? this.displayName,
    );
  }

  String get statusDisplay => status.display;
  Color get statusColor => status.color;
}