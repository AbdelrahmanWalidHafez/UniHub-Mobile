import 'package:flutter/material.dart';

enum TaskStatus {
  todo,
  inprogress,
  done,
}

enum TaskPriority {
  low,
  mid,
  high,
}

extension TaskStatusExtension on TaskStatus {
  String get value {
    switch (this) {
      case TaskStatus.todo:
        return 'TODO';
      case TaskStatus.inprogress:
        return 'INPROGRESS';
      case TaskStatus.done:
        return 'DONE';
    }
  }

  String get displayName {
    switch (this) {
      case TaskStatus.todo:
        return 'To Do';
      case TaskStatus.inprogress:
        return 'In Progress';
      case TaskStatus.done:
        return 'Done';
    }
  }

  Color get color {
    switch (this) {
      case TaskStatus.todo:
        return const Color(0xFF6B7280);
      case TaskStatus.inprogress:
        return const Color(0xFFF59E0B);
      case TaskStatus.done:
        return const Color(0xFF22C55E);
    }
  }

  IconData get icon {
    switch (this) {
      case TaskStatus.todo:
        return Icons.circle_outlined;
      case TaskStatus.inprogress:
        return Icons.play_circle_outline;
      case TaskStatus.done:
        return Icons.check_circle_outline;
    }
  }

  static TaskStatus fromString(String value) {
    switch (value.toUpperCase()) {
      case 'INPROGRESS':
        return TaskStatus.inprogress;
      case 'DONE':
        return TaskStatus.done;
      default:
        return TaskStatus.todo;
    }
  }
}

extension TaskPriorityExtension on TaskPriority {
  String get value {
    switch (this) {
      case TaskPriority.low:
        return 'LOW';
      case TaskPriority.mid:
        return 'MID';
      case TaskPriority.high:
        return 'HIGH';
    }
  }

  String get displayName {
    switch (this) {
      case TaskPriority.low:
        return 'Low';
      case TaskPriority.mid:
        return 'Medium';
      case TaskPriority.high:
        return 'High';
    }
  }

  Color get color {
    switch (this) {
      case TaskPriority.low:
        return const Color(0xFF22C55E);
      case TaskPriority.mid:
        return const Color(0xFFF59E0B);
      case TaskPriority.high:
        return const Color(0xFFEF4444);
    }
  }

  static TaskPriority fromString(String value) {
    switch (value.toUpperCase()) {
      case 'MID':
        return TaskPriority.mid;
      case 'HIGH':
        return TaskPriority.high;
      default:
        return TaskPriority.low;
    }
  }
}

class Task {
  final String id;
  final String title;
  final String? description;
  final TaskStatus status;
  final TaskPriority priority;
  final DateTime? dueDate;
  final DateTime? startedAt;
  final DateTime? finishedAt;
  final DateTime createdAt;
  final DateTime? updatedAt;
  final String createdBy;
  final String? updatedBy;

  Task({
    required this.id,
    required this.title,
    this.description,
    required this.status,
    required this.priority,
    this.dueDate,
    this.startedAt,
    this.finishedAt,
    required this.createdAt,
    this.updatedAt,
    required this.createdBy,
    this.updatedBy,
  });

  factory Task.fromJson(Map<String, dynamic> json) {
    return Task(
      id: json['id']?.toString() ?? '',
      title: json['title']?.toString() ?? '',
      description: json['description']?.toString(),
      status: TaskStatusExtension.fromString(json['status']?.toString() ?? 'TODO'),
      priority: TaskPriorityExtension.fromString(json['priority']?.toString() ?? 'LOW'),
      dueDate: json['due_date'] != null ? DateTime.tryParse(json['due_date'].toString()) : null,
      startedAt: json['started_at'] != null ? DateTime.tryParse(json['started_at'].toString()) : null,
      finishedAt: json['finished_at'] != null ? DateTime.tryParse(json['finished_at'].toString()) : null,
      createdAt: DateTime.tryParse(json['created_at']?.toString() ?? '') ?? DateTime.now(),
      updatedAt: json['updated_at'] != null ? DateTime.tryParse(json['updated_at'].toString()) : null,
      createdBy: json['created_by']?.toString() ?? '',
      updatedBy: json['updated_by']?.toString(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'description': description,
      'status': status.value,
      'priority': priority.value,
      'due_date': dueDate?.toIso8601String(),
      'started_at': startedAt?.toIso8601String(),
      'finished_at': finishedAt?.toIso8601String(),
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt?.toIso8601String(),
      'created_by': createdBy,
      'updated_by': updatedBy,
    };
  }

  bool get isOverdue {
    if (dueDate == null || status == TaskStatus.done) return false;
    return DateTime.now().isAfter(dueDate!);
  }

  Task copyWith({
    String? id,
    String? title,
    String? description,
    TaskStatus? status,
    TaskPriority? priority,
    DateTime? dueDate,
    DateTime? startedAt,
    DateTime? finishedAt,
    DateTime? createdAt,
    DateTime? updatedAt,
    String? createdBy,
    String? updatedBy,
  }) {
    return Task(
      id: id ?? this.id,
      title: title ?? this.title,
      description: description ?? this.description,
      status: status ?? this.status,
      priority: priority ?? this.priority,
      dueDate: dueDate ?? this.dueDate,
      startedAt: startedAt ?? this.startedAt,
      finishedAt: finishedAt ?? this.finishedAt,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      createdBy: createdBy ?? this.createdBy,
      updatedBy: updatedBy ?? this.updatedBy,
    );
  }
}

class CreateTaskRequest {
  final String title;
  final String? description;
  final TaskPriority priority;
  final DateTime dueDate;

  CreateTaskRequest({
    required this.title,
    this.description,
    required this.priority,
    required this.dueDate,
  });

  Map<String, dynamic> toJson() {
    return {
      'title': title,
      'description': description,
      'priority': priority.value,
      'due_date': dueDate.toIso8601String(),
    };
  }
}