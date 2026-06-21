import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:path/path.dart' as path;
import 'token_service.dart';

class AIService {
  static const String _baseUrl = 'http://34.58.11.82:8082';
  static const bool enableLogging = true;

  static Future<Map<String, String>> _authHeaders() async {
    final accessToken = await TokenService.getAccessToken();
    final userData = await TokenService.getUserData();

    final headers = {
      'Content-Type': 'application/json',
      if (accessToken != null) 'Authorization': 'Bearer $accessToken',
    };

    if (userData != null && userData['email'] != null) {
      headers['X-User-Email'] = userData['email'].toString();
    }

    return headers;
  }


  static String _normalizeChunk(String text) {

    var cleaned = text.replaceAll(RegExp(r'^data:'), '');


    cleaned = cleaned.trim();


    cleaned = cleaned.replaceAll(RegExp(r'\s+'), ' ');

    return cleaned;
  }

  static Stream<String> _processStream(http.StreamedResponse response) async* {
    final stream = response.stream.transform(utf8.decoder);
    String buffer = '';

    await for (var chunk in stream) {
      buffer += chunk;

      while (buffer.contains('\n')) {
        final index = buffer.indexOf('\n');
        var line = buffer.substring(0, index).trim();
        buffer = buffer.substring(index + 1);

        if (line.startsWith('data:')) {
          line = line.substring(5).trim();
        }

        if (line.isNotEmpty && line != '[DONE]') {
          final cleaned = _normalizeChunk(line);
          if (cleaned.isNotEmpty) {
            yield cleaned;
          }
        }
      }
    }


    if (buffer.trim().isNotEmpty) {
      var line = buffer.trim();
      if (line.startsWith('data:')) {
        line = line.substring(5).trim();
      }
      if (line.isNotEmpty && line != '[DONE]') {
        final cleaned = _normalizeChunk(line);
        if (cleaned.isNotEmpty) {
          yield cleaned;
        }
      }
    }
  }

  static Stream<String> sendMessage(String message) async* {
    try {
      final headers = await _authHeaders();

      final url = Uri.parse(
        '$_baseUrl/unihub/ai/api/v1/chat/message?message=${Uri.encodeComponent(message)}',
      );

      final request = http.Request('POST', url);
      request.headers.addAll(headers);

      final response = await request.send();

      if (response.statusCode == 200) {
        yield* _processStream(response);
      } else {
        final body = await response.stream.bytesToString();
        throw Exception(
          'Failed to send message: ${response.statusCode} - $body',
        );
      }
    } catch (e) {
      if (enableLogging) {
        print('AI message error: $e');
      }
      yield 'Sorry, I encountered an error. Please try again.';
    }
  }

  static Stream<String> explainMaterial(String materialId) async* {
    try {
      final headers = await _authHeaders();

      final url = Uri.parse(
        '$_baseUrl/unihub/ai/api/v1/chat/explain/$materialId',
      );

      final request = http.Request('POST', url);
      request.headers.addAll(headers);

      final response = await request.send();

      if (response.statusCode == 200) {
        yield* _processStream(response);
      } else {
        final body = await response.stream.bytesToString();
        throw Exception(
          'Failed to explain material: ${response.statusCode} - $body',
        );
      }
    } catch (e) {
      if (enableLogging) {
        print('Explain material error: $e');
      }
      yield 'Sorry, I encountered an error while explaining this material.';
    }
  }

  static Stream<String> sendVoiceMessage(File audioFile) async* {
    try {
      final token = await TokenService.getAccessToken();
      final userData = await TokenService.getUserData();
      final email = userData?['email']?.toString() ?? '';

      final request = http.MultipartRequest(
        'POST',
        Uri.parse('$_baseUrl/unihub/ai/api/v1/chat/voice'),
      );

      request.headers['Authorization'] = 'Bearer $token';
      request.headers['X-User-Email'] = email;

      request.files.add(
        await http.MultipartFile.fromPath(
          'message',
          audioFile.path,
          filename: path.basename(audioFile.path),
        ),
      );

      final response = await request.send();

      if (response.statusCode == 200) {
        yield* _processStream(response);
      } else {
        final body = await response.stream.bytesToString();
        throw Exception(
          'Failed to send voice message: ${response.statusCode} - $body',
        );
      }
    } catch (e) {
      if (enableLogging) {
        print('Voice message error: $e');
      }
      yield 'Sorry, I encountered an error with your voice message.';
    }
  }

  static Future<List<Map<String, dynamic>>> getChatHistory() async {
    try {
      final headers = await _authHeaders();

      final response = await http.get(
        Uri.parse('$_baseUrl/unihub/ai/api/v1/chat/history'),
        headers: headers,
      );

      if (response.statusCode == 200) {
        final List<dynamic> data = json.decode(response.body);
        return data
            .map(
              (item) => {
            'from': item['messageType'] == 'USER' ? 'user' : 'ai',
            'text': item['text']?.toString() ?? item['content']?.toString() ?? '',
          },
        )
            .toList();
      }
      return [];
    } catch (e) {
      if (enableLogging) {
        print('Get history error: $e');
      }
      return [];
    }
  }

  static Future<bool> clearChatHistory() async {
    try {
      final headers = await _authHeaders();

      final response = await http.delete(
        Uri.parse('$_baseUrl/unihub/ai/api/v1/chat/history'),
        headers: headers,
      );

      return response.statusCode == 204;
    } catch (e) {
      if (enableLogging) {
        print('Clear history error: $e');
      }
      return false;
    }
  }
}