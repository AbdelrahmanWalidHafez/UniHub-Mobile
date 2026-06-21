import 'package:flutter/material.dart';

enum ClassroomMaterialType {
  material,
  announcement,
  assignment,
}

extension ClassroomMaterialTypeExtension on ClassroomMaterialType {
  String get value {
    switch (this) {
      case ClassroomMaterialType.material:
        return 'MATERIAL';
      case ClassroomMaterialType.announcement:
        return 'ANNOUNCEMENT';
      case ClassroomMaterialType.assignment:
        return 'ASSIGNMENT';
    }
  }

  String get displayName {
    switch (this) {
      case ClassroomMaterialType.material:
        return 'Material';
      case ClassroomMaterialType.announcement:
        return 'Announcement';
      case ClassroomMaterialType.assignment:
        return 'Assignment';
    }
  }

  IconData get icon {
    switch (this) {
      case ClassroomMaterialType.material:
        return Icons.description;
      case ClassroomMaterialType.announcement:
        return Icons.announcement;
      case ClassroomMaterialType.assignment:
        return Icons.assignment;
    }
  }

  static ClassroomMaterialType fromString(String value) {
    switch (value.toUpperCase()) {
      case 'MATERIAL':
        return ClassroomMaterialType.material;
      case 'ANNOUNCEMENT':
        return ClassroomMaterialType.announcement;
      case 'ASSIGNMENT':
        return ClassroomMaterialType.assignment;
      default:
        return ClassroomMaterialType.material;
    }
  }
}

class ClassroomMaterial {
  final String id;
  final String headLine;
  final String description;
  final ClassroomMaterialType materialType;
  final List<String> materialUrls;
  final int commentsCount;
  final DateTime createdAt;
  final DateTime? updatedAt;
  final String createdBy;
  final String? updatedBy;
  final DateTime? dueDate;  // ADDED for assignments

  ClassroomMaterial({
    required this.id,
    required this.headLine,
    required this.description,
    required this.materialType,
    required this.materialUrls,
    required this.commentsCount,
    required this.createdAt,
    this.updatedAt,
    required this.createdBy,
    this.updatedBy,
    this.dueDate,
  });

  factory ClassroomMaterial.fromJson(Map<String, dynamic> json) {
    return ClassroomMaterial(
      id: json['material_id']?.toString() ?? '',
      headLine: json['head_line']?.toString() ?? '',
      description: json['description']?.toString() ?? '',
      materialType: ClassroomMaterialTypeExtension.fromString(json['material_type']?.toString() ?? ''),
      materialUrls: (json['material_urls'] as List?)?.map((e) => e.toString()).toList() ?? [],
      commentsCount: json['comments_count'] ?? 0,
      createdAt: DateTime.tryParse(json['created_at']?.toString() ?? '') ?? DateTime.now(),
      updatedAt: json['updated_at'] != null ? DateTime.tryParse(json['updated_at']) : null,
      createdBy: json['created_by']?.toString() ?? '',
      updatedBy: json['updated_by']?.toString(),
      dueDate: json['due_date'] != null ? DateTime.tryParse(json['due_date']) : null,
    );
  }

  bool get isEdited {
    if (updatedAt == null) return false;
    return updatedAt != createdAt;
  }

  String get authorName {
    return createdBy.split('@').first;
  }
}

class ClassroomAssignment {
  final String id;
  final ClassroomMaterial material;
  final int points;
  final DateTime? dueDate;

  ClassroomAssignment({
    required this.id,
    required this.material,
    required this.points,
    this.dueDate,
  });

  factory ClassroomAssignment.fromJson(Map<String, dynamic> json, ClassroomMaterial material) {
    return ClassroomAssignment(
      id: json['assignment_id']?.toString() ?? '',
      material: material,
      points: json['points'] ?? 0,
      dueDate: json['due_date'] != null ? DateTime.tryParse(json['due_date']) : null,
    );
  }

  bool get isPastDue {
    if (dueDate == null) return false;
    return DateTime.now().isAfter(dueDate!);
  }
}