import 'package:flutter/material.dart';
import '../screens/meeting/meeting_screen.dart';

class JitsiService {
  static Future<void> joinMeeting({
    required BuildContext context,
    required String roomName,
    required String displayName,
    String? email,
    bool audioMuted = true,
    bool videoMuted = false,
  }) async {
    // Clean room name
    final cleanRoom = roomName
        .trim()
        .toLowerCase()
        .replaceAll(RegExp(r'\s+'), '-')
        .replaceAll(RegExp(r'[^a-z0-9-]'), '');

    await Navigator.push(
      context,
      PageRouteBuilder(
        pageBuilder: (_, animation, __) => MeetingScreen(
          roomName: cleanRoom,
          displayName: displayName,
          email: email ?? '',
          audioMuted: audioMuted,
          videoMuted: videoMuted,
        ),
        transitionsBuilder: (_, animation, __, child) {
          return FadeTransition(opacity: animation, child: child);
        },
        transitionDuration: const Duration(milliseconds: 400),
      ),
    );
  }
}