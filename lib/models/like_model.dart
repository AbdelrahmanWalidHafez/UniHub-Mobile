class LikeUser {
  final String id;
  final String name;
  final String? email;
  final String? avatarUrl;

  LikeUser({
    required this.id,
    required this.name,
    this.email,
    this.avatarUrl,
  });

  factory LikeUser.fromJson(Map<String, dynamic> json) {
    return LikeUser(
      id: json['user_id']?.toString() ??
          json['id']?.toString() ?? '',
      name: json['name'] ??
          json['fullName'] ??
          json['full_name'] ??
          json['username'] ??
          'User',
      email: json['email'],
      avatarUrl: json['avatar'] ?? json['avatar_url'],
    );
  }
}