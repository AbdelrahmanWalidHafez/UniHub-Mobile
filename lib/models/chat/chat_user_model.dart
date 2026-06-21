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
    // Handle display name with potential emojis
    String displayName = json['display_name']?.toString() ??
        json['displayName']?.toString() ?? 'User';

    // Decode Unicode escape sequences if present
    if (displayName.contains(r'\u')) {
      try {
        displayName = displayName.replaceAllMapped(
          RegExp(r'\\u([0-9a-fA-F]{4})'),
              (match) => String.fromCharCode(int.parse(match.group(1)!, radix: 16)),
        );
      } catch (e) {
        // Keep original if decoding fails
      }
    }

    return ChatUser(
      email: json['email']?.toString() ?? '',
      displayName: displayName,
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