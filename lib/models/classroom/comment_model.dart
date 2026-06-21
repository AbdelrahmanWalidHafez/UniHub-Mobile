class ClassroomComment {
  final String id;
  final String content;
  final DateTime createdAt;
  final bool isEdited;
  final String createdBy;
  final DateTime? updatedAt;
  final String? updatedBy;

  ClassroomComment({
    required this.id,
    required this.content,
    required this.createdAt,
    required this.isEdited,
    required this.createdBy,
    this.updatedAt,
    this.updatedBy,
  });

  factory ClassroomComment.fromJson(Map<String, dynamic> json) {
    return ClassroomComment(
      id: json['comment_id']?.toString() ?? '',
      content: json['content']?.toString() ?? '',
      createdAt: DateTime.tryParse(json['created_at']?.toString() ?? '') ?? DateTime.now(),
      isEdited: json['is_edited'] ?? false,
      createdBy: json['created_by']?.toString() ?? '',
      updatedAt: json['updated_at'] != null ? DateTime.tryParse(json['updated_at']) : null,
      updatedBy: json['updated_by']?.toString(),
    );
  }

  String get authorName {
    return createdBy.split('@').first;
  }
}