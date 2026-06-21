import 'dart:convert';

enum ChatType {
  direct,
  group,
}

enum ParticipantRole {
  admin,
  member,
}

enum MessageType {
  text,
  image,
  voice,
  system,
}

// ==================== CHAT ROOM LAST MESSAGE ====================
class ChatRoomLastMessage {
  final String messageId;
  final String contentPreview;
  final String senderEmail;
  final String type;
  final DateTime sentAt;

  ChatRoomLastMessage({
    required this.messageId,
    required this.contentPreview,
    required this.senderEmail,
    required this.type,
    required this.sentAt,
  });

  factory ChatRoomLastMessage.fromJson(Map<String, dynamic> json) {
    // Handle content preview with emojis
    String contentPreview = json['content_preview']?.toString() ?? json['contentPreview']?.toString() ?? '';
    // Decode Unicode escape sequences if present
    if (contentPreview.contains(r'\u')) {
      try {
        contentPreview = contentPreview.replaceAllMapped(
          RegExp(r'\\u([0-9a-fA-F]{4})'),
              (match) => String.fromCharCode(int.parse(match.group(1)!, radix: 16)),
        );
      } catch (e) {
        // Keep original if decoding fails
      }
    }

    return ChatRoomLastMessage(
      messageId: json['message_id']?.toString() ?? json['messageId']?.toString() ?? '',
      contentPreview: contentPreview,
      senderEmail: json['sender_email']?.toString() ?? json['senderEmail']?.toString() ?? '',
      type: json['type']?.toString() ?? 'TEXT',
      sentAt: DateTime.tryParse(json['sent_at']?.toString() ?? json['sentAt']?.toString() ?? '') ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'message_id': messageId,
      'content_preview': contentPreview,
      'sender_email': senderEmail,
      'type': type,
      'sent_at': sentAt.toIso8601String(),
    };
  }
}

// ==================== PARTICIPANT ====================
class Participant {
  final String email;
  final String displayName;
  final ParticipantRole role;
  final DateTime? lastSeenAt;
  final bool? isOnline;

  Participant({
    required this.email,
    required this.displayName,
    required this.role,
    this.lastSeenAt,
    this.isOnline,
  });

  factory Participant.fromJson(Map<String, dynamic> json) {
    return Participant(
      email: json['email']?.toString() ?? '',
      displayName: json['display_name']?.toString() ?? json['displayName']?.toString() ?? '',
      role: json['role']?.toString() == 'ADMIN' ? ParticipantRole.admin : ParticipantRole.member,
      lastSeenAt: json['last_seen_at'] != null ? DateTime.tryParse(json['last_seen_at'].toString()) : null,
      isOnline: json['is_online'] ?? json['isOnline'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'email': email,
      'display_name': displayName,
      'role': role == ParticipantRole.admin ? 'ADMIN' : 'MEMBER',
      'last_seen_at': lastSeenAt?.toIso8601String(),
      'is_online': isOnline,
    };
  }
}

// ==================== CHAT ROOM ====================
class ChatRoom {
  final String id;
  final ChatType type;
  final String? name;
  final List<Participant> participants;
  final ChatRoomLastMessage? lastMessage;
  final int unreadCount;
  final DateTime createdAt;
  final DateTime updatedAt;

  ChatRoom({
    required this.id,
    required this.type,
    this.name,
    required this.participants,
    this.lastMessage,
    this.unreadCount = 0,
    required this.createdAt,
    required this.updatedAt,
  });

  factory ChatRoom.fromJson(Map<String, dynamic> json) {
    return ChatRoom(
      id: json['id']?.toString() ?? '',
      type: json['type']?.toString() == 'GROUP' ? ChatType.group : ChatType.direct,
      name: json['name']?.toString(),
      participants: (json['participants'] as List?)
          ?.map((p) => Participant.fromJson(p))
          .toList() ?? [],
      lastMessage: json['last_message'] != null || json['lastMessage'] != null
          ? ChatRoomLastMessage.fromJson(json['last_message'] ?? json['lastMessage'])
          : null,
      unreadCount: (json['unread_count'] ?? json['unreadCount'] ?? 0) as int,
      createdAt: DateTime.tryParse(json['created_at']?.toString() ?? json['createdAt']?.toString() ?? '') ?? DateTime.now(),
      updatedAt: DateTime.tryParse(json['updated_at']?.toString() ?? json['updatedAt']?.toString() ?? '') ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'type': type == ChatType.group ? 'GROUP' : 'DIRECT',
      'name': name,
      'participants': participants.map((p) => p.toJson()).toList(),
      'last_message': lastMessage?.toJson(),
      'unread_count': unreadCount,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }

  ChatRoom copyWith({
    String? id,
    ChatType? type,
    String? name,
    List<Participant>? participants,
    ChatRoomLastMessage? lastMessage,
    int? unreadCount,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return ChatRoom(
      id: id ?? this.id,
      type: type ?? this.type,
      name: name ?? this.name,
      participants: participants ?? this.participants,
      lastMessage: lastMessage ?? this.lastMessage,
      unreadCount: unreadCount ?? this.unreadCount,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  bool get isGroup => type == ChatType.group;

  String getDisplayName(String currentUserEmail) {
    if (isGroup) {
      return name ?? 'Group Chat';
    }
    final otherParticipant = participants.firstWhere(
          (p) => p.email != currentUserEmail,
      orElse: () => participants.first,
    );
    return otherParticipant.displayName;
  }

  Participant? getOtherParticipant(String currentUserEmail) {
    if (isGroup) return null;
    try {
      return participants.firstWhere(
            (p) => p.email != currentUserEmail,
      );
    } catch (e) {
      return null;
    }
  }

  bool isAdmin(String email) {
    final participant = participants.firstWhere(
          (p) => p.email == email,
      orElse: () => Participant(
        email: email,
        displayName: '',
        role: ParticipantRole.member,
      ),
    );
    return participant.role == ParticipantRole.admin;
  }
}

// ==================== CHAT USER ====================
class ChatUser {
  final String email;
  final String displayName;
  final bool isOnline;
  final DateTime? lastSeenAt;

  ChatUser({
    required this.email,
    required this.displayName,
    this.isOnline = false,
    this.lastSeenAt,
  });

  factory ChatUser.fromJson(Map<String, dynamic> json) {
    return ChatUser(
      email: json['email']?.toString() ?? '',
      displayName: json['display_name']?.toString() ?? json['displayName']?.toString() ?? '',
      isOnline: json['is_online'] ?? json['isOnline'] ?? false,
      lastSeenAt: json['last_seen_at'] != null
          ? DateTime.tryParse(json['last_seen_at'].toString())
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'email': email,
      'display_name': displayName,
      'is_online': isOnline,
      'last_seen_at': lastSeenAt?.toIso8601String(),
    };
  }
}