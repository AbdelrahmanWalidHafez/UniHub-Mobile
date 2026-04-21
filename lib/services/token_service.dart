import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'dart:convert';

class TokenService {
  static const FlutterSecureStorage _storage = FlutterSecureStorage();

  static const String _accessTokenKey = 'access_token';
  static const String _refreshTokenKey = 'refresh_token';
  static const String _userDataKey = 'user_data';
  static const bool enableLogging = true;

  static Future<String?> getAccessToken() async {
    return await _storage.read(key: _accessTokenKey);
  }

  static Future<void> setAccessToken(String? token) async {
    if (token != null) {
      await _storage.write(key: _accessTokenKey, value: token);
      if (enableLogging) print('Access token saved');
    } else {
      await _storage.delete(key: _accessTokenKey);
      if (enableLogging) print('Access token removed');
    }
  }

  static Future<String?> getRefreshToken() async {
    return await _storage.read(key: _refreshTokenKey);
  }

  static Future<void> setRefreshToken(String? token) async {
    if (token != null) {
      await _storage.write(key: _refreshTokenKey, value: token);
      if (enableLogging) print('Refresh token saved');
    } else {
      await _storage.delete(key: _refreshTokenKey);
      if (enableLogging) print('Refresh token removed');
    }
  }

  static Future<void> saveTokens(String accessToken, String refreshToken) async {
    await setAccessToken(accessToken);
    await setRefreshToken(refreshToken);
    if (enableLogging) print('Both tokens saved successfully');
  }

  // User data methods
  static Future<void> saveUserData(Map<String, dynamic> userData) async {
    final String jsonString = json.encode(userData);
    await _storage.write(key: _userDataKey, value: jsonString);
    if (enableLogging) print('User data saved');
  }

  static Future<Map<String, dynamic>?> getUserData() async {
    final String? jsonString = await _storage.read(key: _userDataKey);
    if (jsonString != null) {
      return json.decode(jsonString);
    }
    return null;
  }

  static Future<void> clearTokens() async {
    await setAccessToken(null);
    await setRefreshToken(null);
    await _storage.delete(key: _userDataKey);
    if (enableLogging) print('All tokens and user data cleared');
  }

  static Future<bool> hasRefreshToken() async {
    final refreshToken = await getRefreshToken();
    return refreshToken != null;
  }

  static Future<void> printTokenInfo() async {
    final accessToken = await getAccessToken();
    final refreshToken = await getRefreshToken();
    print('Access token exists: ${accessToken != null}');
    print('Refresh token exists: ${refreshToken != null}');
    if (accessToken != null) {
      print('Access token length: ${accessToken.length}');
    }
  }
}