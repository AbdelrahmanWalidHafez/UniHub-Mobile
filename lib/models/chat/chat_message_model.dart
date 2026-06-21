import 'chat_model.dart';

class ReplyToDto {
  final String messageId;
  final String senderDisplayName;
  final String contentPreview;

  ReplyToDto({
    required this.messageId,
    required this.senderDisplayName,
    required this.contentPreview,
  });

  factory ReplyToDto.fromJson(Map<String, dynamic> json) {
    return ReplyToDto(
      messageId: json['message_id']?.toString() ?? json['messageId']?.toString() ?? '',
      senderDisplayName: _decodeUnicode(json['sender_display_name']?.toString() ?? json['senderDisplayName']?.toString() ?? ''),
      contentPreview: _decodeUnicode(json['content_preview']?.toString() ?? json['contentPreview']?.toString() ?? ''),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'message_id': messageId,
      'sender_display_name': senderDisplayName,
      'content_preview': contentPreview,
    };
  }

  // Helper to decode Unicode escape sequences
  static String _decodeUnicode(String input) {
    if (input.isEmpty) return input;
    try {
      // Handle both \uXXXX and \u{XXXXX} formats
      return input.replaceAllMapped(
        RegExp(r'\\u([0-9a-fA-F]{4,6})'),
            (match) {
          final codePoint = int.parse(match.group(1)!, radix: 16);
          return String.fromCharCode(codePoint);
        },
      );
    } catch (e) {
      return input;
    }
  }
}

class ChatMessage {
  final String id;
  final String roomId;
  final String senderEmail;
  final String senderDisplayName;
  final MessageType type;
  final String? content;
  final String? imageUrl;
  final int? voiceDurationSecs;
  final ReplyToDto? replyTo;
  final List<String> readBy;
  final DateTime? editedAt;
  final DateTime? deletedAt;
  final DateTime createdAt;

  ChatMessage({
    required this.id,
    required this.roomId,
    required this.senderEmail,
    required this.senderDisplayName,
    required this.type,
    this.content,
    this.imageUrl,
    this.voiceDurationSecs,
    this.replyTo,
    this.readBy = const [],
    this.editedAt,
    this.deletedAt,
    required this.createdAt,
  });

  factory ChatMessage.fromJson(Map<String, dynamic> json) {
    // Parse message type
    String typeStr = json['type']?.toString() ?? 'TEXT';
    MessageType messageType;
    switch (typeStr.toUpperCase()) {
      case 'IMAGE':
        messageType = MessageType.image;
        break;
      case 'VOICE':
        messageType = MessageType.voice;
        break;
      case 'SYSTEM':
        messageType = MessageType.system;
        break;
      default:
        messageType = MessageType.text;
    }

    // Parse content with proper Unicode handling
    String? content = json['content']?.toString();
    if (content != null) {
      content = _decodeUnicode(content);
    }

    String senderDisplayName = json['sender_display_name']?.toString() ?? json['senderDisplayName']?.toString() ?? '';
    senderDisplayName = _decodeUnicode(senderDisplayName);

    return ChatMessage(
      id: json['id']?.toString() ?? '',
      roomId: json['room_id']?.toString() ?? json['roomId']?.toString() ?? '',
      senderEmail: json['sender_email']?.toString() ?? json['senderEmail']?.toString() ?? '',
      senderDisplayName: senderDisplayName,
      type: messageType,
      content: content,
      imageUrl: json['image_url']?.toString() ?? json['imageUrl']?.toString(),
      voiceDurationSecs: json['voice_duration_secs'] != null
          ? (json['voice_duration_secs'] as num).toInt()
          : json['voiceDurationSecs'] != null
          ? (json['voiceDurationSecs'] as num).toInt()
          : null,
      replyTo: json['reply_to'] != null
          ? ReplyToDto.fromJson(json['reply_to'] as Map<String, dynamic>)
          : json['replyTo'] != null
          ? ReplyToDto.fromJson(json['replyTo'] as Map<String, dynamic>)
          : null,
      readBy: (json['read_by'] as List?)?.map((e) => e.toString()).toList() ?? [],
      editedAt: json['edited_at'] != null
          ? DateTime.tryParse(json['edited_at'].toString())
          : json['editedAt'] != null
          ? DateTime.tryParse(json['editedAt'].toString())
          : null,
      deletedAt: json['deleted_at'] != null
          ? DateTime.tryParse(json['deleted_at'].toString())
          : json['deletedAt'] != null
          ? DateTime.tryParse(json['deletedAt'].toString())
          : null,
      createdAt: DateTime.tryParse(json['created_at']?.toString() ?? json['createdAt']?.toString() ?? '') ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() {
    String typeStr;
    switch (type) {
      case MessageType.image:
        typeStr = 'IMAGE';
        break;
      case MessageType.voice:
        typeStr = 'VOICE';
        break;
      case MessageType.system:
        typeStr = 'SYSTEM';
        break;
      default:
        typeStr = 'TEXT';
    }

    return {
      'id': id,
      'room_id': roomId,
      'sender_email': senderEmail,
      'sender_display_name': senderDisplayName,
      'type': typeStr,
      'content': content,
      'image_url': imageUrl,
      'voice_duration_secs': voiceDurationSecs,
      'reply_to': replyTo?.toJson(),
      'read_by': readBy,
      'edited_at': editedAt?.toIso8601String(),
      'deleted_at': deletedAt?.toIso8601String(),
      'created_at': createdAt.toIso8601String(),
    };
  }

  // Helper to decode Unicode escape sequences
  static String _decodeUnicode(String input) {
    if (input.isEmpty) return input;
    try {
      // Handle both \uXXXX and \u{XXXXX} formats
      String result = input;
      // First try to decode \uXXXX format
      result = result.replaceAllMapped(
        RegExp(r'\\u([0-9a-fA-F]{4})'),
            (match) {
          try {
            final codePoint = int.parse(match.group(1)!, radix: 16);
            return String.fromCharCode(codePoint);
          } catch (e) {
            return match.group(0)!;
          }
        },
      );
      // Then try \u{XXXXX} format
      result = result.replaceAllMapped(
        RegExp(r'\\u\{([0-9a-fA-F]+)\}'),
            (match) {
          try {
            final codePoint = int.parse(match.group(1)!, radix: 16);
            return String.fromCharCode(codePoint);
          } catch (e) {
            return match.group(0)!;
          }
        },
      );
      return result;
    } catch (e) {
      return input;
    }
  }

  bool get isText => type == MessageType.text;
  bool get isImage => type == MessageType.image;
  bool get isVoice => type == MessageType.voice;
  bool get isSystem => type == MessageType.system;
  bool get isDeleted => deletedAt != null;
  bool get isEdited => editedAt != null && deletedAt == null;

  String get contentPreview {
    if (isDeleted) return 'This message was deleted';
    if (isImage) return '📷 Photo';
    if (isVoice) return '🎤 Voice message';
    return content ?? '';
  }
}