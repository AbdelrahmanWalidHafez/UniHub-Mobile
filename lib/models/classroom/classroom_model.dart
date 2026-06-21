class Classroom {
  final String id;
  final String code;
  final String classTitle;
  final String classSubTitle;
  final int imageNum;
  final bool isArchived;
  final String? universityId;
  final String? collegeId;
  final DateTime createdAt;
  final DateTime? updatedAt;
  final String createdBy;
  final String? updatedBy;
  final String? createdByName;

  Classroom({
    required this.id,
    required this.code,
    required this.classTitle,
    required this.classSubTitle,
    required this.imageNum,
    required this.isArchived,
    this.universityId,
    this.collegeId,
    required this.createdAt,
    this.updatedAt,
    required this.createdBy,
    this.updatedBy,
    this.createdByName,
  });

  factory Classroom.fromJson(Map<String, dynamic> json) {

    String creatorName = '';

    // Check if there's a user object with name
    if (json['created_by_user'] != null && json['created_by_user'] is Map) {
      final user = json['created_by_user'];
      if (user['first_name'] != null && user['last_name'] != null) {
        creatorName = '${user['first_name']} ${user['last_name']}';
      } else if (user['first_name'] != null) {
        creatorName = user['first_name'];
      } else if (user['email'] != null) {
        creatorName = user['email'].split('@').first;
      }
    }
    int imageNum = 1;
    if (json['image_num'] != null) {
      if (json['image_num'] is int) {
        imageNum = json['image_num'];
      } else if (json['image_num'] is String) {
        imageNum = int.tryParse(json['image_num']) ?? 1;
      }
    }


    if (creatorName.isEmpty) {
      final email = json['created_by']?.toString() ?? '';
      creatorName = email.split('@').first;
      if (creatorName.isNotEmpty) {
        creatorName = creatorName[0].toUpperCase() + creatorName.substring(1);
      }
    }

    return Classroom(
      id: json['class_id']?.toString() ?? '',
      code: json['entry_code']?.toString() ?? '',
      classTitle: json['class_title']?.toString() ?? '',
      classSubTitle: json['class_sub_title']?.toString() ?? '',
      imageNum: imageNum.clamp(1, 9),
      isArchived: json['is_archived'] ?? false,
      universityId: json['university_id']?.toString(),
      collegeId: json['college_id']?.toString(),
      createdAt: DateTime.tryParse(json['created_at']?.toString() ?? '') ?? DateTime.now(),
      updatedAt: json['updated_at'] != null ? DateTime.tryParse(json['updated_at']) : null,
      createdBy: json['created_by']?.toString() ?? '',
      updatedBy: json['updated_by']?.toString(),
      createdByName: creatorName,
    );
  }

  String get displayName => createdByName ?? createdBy.split('@').first;
}

class Member {
  final String? rid;
  final String email;
  final String? classroomId;
  final DateTime? createdAt;
  final DateTime? updatedAt;
  final String? createdBy;
  final String? updatedBy;
  final String? displayName;

  Member({
    this.rid,
    required this.email,
    this.classroomId,
    this.createdAt,
    this.updatedAt,
    this.createdBy,
    this.updatedBy,
    this.displayName,
  });

  factory Member.fromJson(Map<String, dynamic> json) {
    String name = '';
    if (json['member_name'] != null) {
      name = json['member_name'].toString();
    } else {
      name = json['member_email']?.toString().split('@').first ?? '';
      if (name.isNotEmpty) {
        name = name[0].toUpperCase() + name.substring(1);
      }
    }

    return Member(
      rid: json['record_id']?.toString(),
      email: json['member_email']?.toString() ?? '',
      classroomId: json['classroom_id']?.toString(),
      createdAt: json['created_at'] != null ? DateTime.tryParse(json['created_at']) : null,
      updatedAt: json['updated_at'] != null ? DateTime.tryParse(json['updated_at']) : null,
      createdBy: json['created_by']?.toString(),
      updatedBy: json['updated_by']?.toString(),
      displayName: name,
    );
  }

  String getDisplayName() {
    return displayName ?? email.split('@').first;
  }
}

class Owner {
  final String email;
  final String? name;

  Owner({required this.email, this.name});

  factory Owner.fromJson(Map<String, dynamic> json) {
    return Owner(
      email: json['owner_email']?.toString() ?? '',
      name: json['owner_name']?.toString(),
    );
  }

  String getDisplayName() {
    if (name != null && name!.isNotEmpty) return name!;
    return email.split('@').first;
  }
}