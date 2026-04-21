import 'dart:convert';
import 'package:http/http.dart' as http;
import 'token_service.dart';

class AuthService {
  static const String _baseUrl = 'http://34.162.70.217:8083/api/v1/auth';
  static const bool enableLogging = true;

  static Future<Map<String, dynamic>?> login(String email, String password) async {
    try {
      if (enableLogging) print('Attempting login for: $email');
      if (enableLogging) print('Using URL: $_baseUrl/login-mobile');

      final response = await http.post(
        Uri.parse('$_baseUrl/login-mobile'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({
          'email': email,
          'password': password,
        }),
      ).timeout(const Duration(seconds: 30));

      if (enableLogging) print('Login response status: ${response.statusCode}');
      if (enableLogging) print('Login response body: ${response.body}');

      if (response.statusCode == 200) {
        final Map<String, dynamic> data = json.decode(response.body);

        final accessTokenObj = data['access_token'];
        final refreshTokenObj = data['refresh_token'];

        String? accessToken;
        String? refreshToken;

        if (accessTokenObj is Map) {
          accessToken = accessTokenObj['access_token'];
        } else if (accessTokenObj is String) {
          accessToken = accessTokenObj;
        }

        if (refreshTokenObj is Map) {
          refreshToken = refreshTokenObj['refresh_token'];
        } else if (refreshTokenObj is String) {
          refreshToken = refreshTokenObj;
        }

        if (accessToken != null && refreshToken != null) {
          await TokenService.saveTokens(accessToken, refreshToken);
          if (enableLogging) print('Login successful, tokens saved');

          return {
            'success': true,
            'tokens': {
              'accessToken': accessToken,
              'refreshToken': refreshToken,
            },
            'user': data['user'],
          };
        } else {
          if (enableLogging) print('No tokens in response: $data');
          return {'success': false, 'message': 'No tokens received'};
        }
      } else {
        String errorMessage = 'Login failed';
        try {
          final Map<String, dynamic> error = json.decode(response.body);
          errorMessage = error['message'] ?? error['error'] ?? 'Login failed';
        } catch (_) {}
        if (enableLogging) print('Login failed: $errorMessage');
        return {'success': false, 'message': errorMessage};
      }
    } catch (e) {
      if (enableLogging) print('Login error: $e');
      return {'success': false, 'message': e.toString()};
    }
  }

  static Future<Map<String, dynamic>?> refreshTokens() async {
    try {
      final refreshToken = await TokenService.getRefreshToken();

      if (refreshToken == null) {
        if (enableLogging) print('No refresh token available');
        return null;
      }

      if (enableLogging) print('Attempting to refresh tokens');
      if (enableLogging) print('Using URL: $_baseUrl/refresh-mobile');

      final response = await http.post(
        Uri.parse('$_baseUrl/refresh-mobile'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({
          'refreshToken': refreshToken,
        }),
      ).timeout(const Duration(seconds: 30));

      if (enableLogging) print('Refresh response status: ${response.statusCode}');

      if (response.statusCode == 200) {
        final Map<String, dynamic> data = json.decode(response.body);

        final accessTokenObj = data['access_token'];
        final refreshTokenObj = data['refresh_token'];

        String? newAccessToken;
        String? newRefreshToken;

        if (accessTokenObj is Map) {
          newAccessToken = accessTokenObj['access_token'];
        } else if (accessTokenObj is String) {
          newAccessToken = accessTokenObj;
        }

        if (refreshTokenObj is Map) {
          newRefreshToken = refreshTokenObj['refresh_token'];
        } else if (refreshTokenObj is String) {
          newRefreshToken = refreshTokenObj;
        }

        if (newAccessToken != null) {
          if (newRefreshToken != null) {
            await TokenService.saveTokens(newAccessToken, newRefreshToken);
          } else {
            await TokenService.setAccessToken(newAccessToken);
          }

          if (enableLogging) print('Tokens refreshed successfully');

          return {
            'success': true,
            'tokens': {
              'accessToken': newAccessToken,
              'refreshToken': newRefreshToken ?? refreshToken,
            },
          };
        } else {
          if (enableLogging) print('No access token in refresh response');
          return null;
        }
      } else {
        if (enableLogging) print('Refresh failed with status: ${response.statusCode}');
        await TokenService.clearTokens();
        return null;
      }
    } catch (e) {
      if (enableLogging) print('Refresh error: $e');
      await TokenService.clearTokens();
      return null;
    }
  }


  static Future<void> logout() async {
    try {
      final refreshToken = await TokenService.getRefreshToken();
      final accessToken = await TokenService.getAccessToken();

      if (refreshToken != null) {
        if (enableLogging) print('Attempting logout');
        if (enableLogging) print('Using URL: $_baseUrl/logout-mobile');

        await http.post(
          Uri.parse('$_baseUrl/logout-mobile'),
          headers: {
            'Content-Type': 'application/json',
            if (accessToken != null) 'Authorization': 'Bearer $accessToken',
          },
          body: json.encode({
            'refreshToken': refreshToken,
          }),
        ).timeout(const Duration(seconds: 30));
      }
    } catch (e) {
      if (enableLogging) print('Logout error: $e');
    } finally {
      await TokenService.clearTokens();
      if (enableLogging) print('Logout completed, tokens cleared');
    }
  }


  static Future<Map<String, dynamic>?> getUserInfo() async {
    try {
      final accessToken = await TokenService.getAccessToken();

      if (accessToken == null) {
        if (enableLogging) print('No access token to fetch user');
        return null;
      }

      if (enableLogging) print('Fetching user info from: $_baseUrl/user-info');

      final response = await http.get(
        Uri.parse('$_baseUrl/user-info'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $accessToken',
        },
      ).timeout(const Duration(seconds: 30));

      if (response.statusCode == 200) {
        final Map<String, dynamic> userData = json.decode(response.body);
        if (enableLogging) print('User info fetched successfully');
        return userData;
      } else {
        if (enableLogging) print('Failed to fetch user info: ${response.statusCode}');
        return null;
      }
    } catch (e) {
      if (enableLogging) print('Error fetching user info: $e');
      return null;
    }
  }

  static Future<String?> getRefreshToken() async {
    return await TokenService.getRefreshToken();
  }
}