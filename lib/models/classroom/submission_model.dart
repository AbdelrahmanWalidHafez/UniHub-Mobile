import 'package:flutter/material.dart';

class Submission {
  final String id;
  final String assignmentId;
  final List<String> submissionUrls;
  final int grade;
  final DateTime createdAt;
  final DateTime? updatedAt;
  final String createdBy;
  final String? updatedBy;
  final bool isGraded;

  Submission({
    required this.id,
    required this.assignmentId,
    required this.submissionUrls,
    required this.grade,
    required this.createdAt,
    this.updatedAt,
    required this.createdBy,
    this.updatedBy,
    required this.isGraded,
  });

  factory Submission.fromJson(Map<String, dynamic> json) {
    return Submission(
      id: json['sid']?.toString() ?? json['submission_id']?.toString() ?? '',
      assignmentId: json['assignment_id']?.toString() ?? '',
      submissionUrls: (json['submission_urls'] as List?)?.map((e) => e.toString()).toList() ?? [],
      grade: json['grade'] ?? -1,
      createdAt: DateTime.tryParse(json['created_at']?.toString() ?? '') ?? DateTime.now(),
      updatedAt: json['updated_at'] != null ? DateTime.tryParse(json['updated_at']) : null,
      createdBy: json['created_by']?.toString() ?? '',
      updatedBy: json['updated_by']?.toString(),
      isGraded: json['grade'] != null && json['grade'] != -1,
    );
  }

  String get gradeDisplay {
    if (grade == -1) return 'Not graded';
    return '$grade / 100';
  }

  Color get gradeColor {
    if (grade == -1) return Colors.grey;
    if (grade >= 90) return Colors.green;
    if (grade >= 70) return Colors.blue;
    if (grade >= 50) return Colors.orange;
    return Colors.red;
  }
}