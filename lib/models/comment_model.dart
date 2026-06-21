import 'package:flutter/material.dart';

class Comment {
  final String id;
  final String content;
  final String createdBy;
  final DateTime createdAt;
  final DateTime? updatedAt;
  final int repliesCount;
  List<Comment> replies;
  final bool isEdited;
  bool showReplies;
  bool isLoadingReplies;
  bool hasMoreReplies;

  Comment({
    required this.id,
    required this.content,
    required this.createdBy,
    required this.createdAt,
    this.updatedAt,
    this.repliesCount = 0,
    this.replies = const [],
    this.isEdited = false,
    this.showReplies = false,
    this.isLoadingReplies = false,
    this.hasMoreReplies = true,
  });

  factory Comment.fromJson(Map<String, dynamic> json) {
    // Parse createdAt - handle different possible formats
    DateTime parseDate(dynamic dateStr) {
      if (dateStr == null) return DateTime.now();
      try {
        return DateTime.parse(dateStr.toString());
      } catch (e) {
        return DateTime.now();
      }
    }

    final createdAtStr = json['created_at'] ?? json['createdAt'];
    final updatedAtStr = json['updated_at'] ?? json['updatedAt'];

    // Get the createdBy name properly
    String createdByName = 'User';
    if (json['created_by'] != null) {
      createdByName = json['created_by'].toString();
    } else if (json['createdBy'] != null) {
      createdByName = json['createdBy'].toString();
    }

    // Clean up email addresses to show only name
    if (createdByName.contains('@')) {
      createdByName = createdByName.split('@').first;
    }

    return Comment(
      id: json['comment_id']?.toString() ?? json['cid']?.toString() ?? json['id']?.toString() ?? '',
      content: json['content'] ?? '',
      createdBy: createdByName,
      createdAt: parseDate(createdAtStr),
      updatedAt: updatedAtStr != null ? parseDate(updatedAtStr) : null,
      repliesCount: json['replies_count'] ?? json['repliesCount'] ?? 0,
      isEdited: json['is_edited'] ?? json['isEdited'] ?? (updatedAtStr != null),
      replies: [],
    );
  }

  Comment copyWith({
    String? id,
    String? content,
    String? createdBy,
    DateTime? createdAt,
    DateTime? updatedAt,
    int? repliesCount,
    List<Comment>? replies,
    bool? isEdited,
    bool? showReplies,
    bool? isLoadingReplies,
    bool? hasMoreReplies,
  }) {
    return Comment(
      id: id ?? this.id,
      content: content ?? this.content,
      createdBy: createdBy ?? this.createdBy,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      repliesCount: repliesCount ?? this.repliesCount,
      replies: replies ?? this.replies,
      isEdited: isEdited ?? this.isEdited,
      showReplies: showReplies ?? this.showReplies,
      isLoadingReplies: isLoadingReplies ?? this.isLoadingReplies,
      hasMoreReplies: hasMoreReplies ?? this.hasMoreReplies,
    );
  }

  Comment copyWithReply(Comment newReply) {
    final newReplies = List<Comment>.from(replies);
    newReplies.insert(0, newReply);
    return copyWith(
      replies: newReplies,
      repliesCount: repliesCount + 1,
    );
  }

  String get displayName {
    String name = createdBy;
    if (name.contains('@')) {
      name = name.split('@').first;
    }
    return name;
  }
}