import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:permission_handler/permission_handler.dart';
import 'token_service.dart';

class MeetingService {
  static const String _baseUrl = 'http://34.58.11.82:8082/unihub/meeting/api/v1';
  static const bool enableLogging = true;

  static Future<Map<String, String>> _authHeaders() async {
    final accessToken = await TokenService.getAccessToken();
    final userData = await TokenService.getUserData();

    final headers = <String, String>{};

    if (accessToken != null) {
      headers['Authorization'] = 'Bearer $accessToken';
    }
    headers['Content-Type'] = 'application/json';

    if (userData != null) {
      if (userData['email'] != null) {
        headers['X-User-Email'] = userData['email'].toString();
      }
    }

    return headers;
  }

  static Future<bool> requestPermissions() async {
    try {
      final cameraStatus = await Permission.camera.request();
      final micStatus = await Permission.microphone.request();
      return cameraStatus.isGranted && micStatus.isGranted;
    } catch (e) {
      print('Permission request error: $e');
      return false;
    }
  }

  static Future<bool> checkPermissions() async {
    try {
      final cameraStatus = await Permission.camera.status;
      final micStatus = await Permission.microphone.status;
      return cameraStatus.isGranted && micStatus.isGranted;
    } catch (e) {
      print('Permission check error: $e');
      return false;
    }
  }

  static Future<Map<String, dynamic>> createMeeting({
    required String roomName,
    required String createdBy,
    String? chatId,
  }) async {
    try {
      final headers = await _authHeaders();

      final response = await http.post(
        Uri.parse('$_baseUrl/rooms/create'),
        headers: headers,
        body: json.encode({
          'room_name': roomName,
          'created_by': createdBy,
          'chat_id': chatId,
        }),
      ).timeout(const Duration(seconds: 30));

      if (response.statusCode == 200 || response.statusCode == 201) {
        return json.decode(response.body);
      }
      throw Exception('Failed to create meeting: ${response.statusCode}');
    } catch (e) {
      if (enableLogging) print('Create meeting error: $e');
      rethrow;
    }
  }

  static String generateRoomId() {
    return 'unihub-' + DateTime.now().millisecondsSinceEpoch.toString();
  }

  static String slugify(String str) {
    return str.trim().toLowerCase()
        .replaceAll(RegExp(r'\s+'), '-')
        .replaceAll(RegExp(r'[^a-z0-9-]'), '');
  }
}