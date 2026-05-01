import 'dart:convert';
import 'package:http/http.dart' as http;
import 'token_service.dart';

class AuthService {
  static const String _baseUrl = 'http://34.136.140.99:8083/api/v1/auth';
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



  static Future<bool> requestActivationCode(String email) async {
    try {
      if (enableLogging) print('Requesting activation code for: $email');
      if (enableLogging) print('Using URL: $_baseUrl/activate-account');

      final response = await http.post(
        Uri.parse('$_baseUrl/activate-account'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({'email': email}),
      ).timeout(const Duration(seconds: 30));

      if (enableLogging) print('Activation request response status: ${response.statusCode}');

      if (response.statusCode == 204) {
        if (enableLogging) print('Activation code sent successfully');
        return true;
      } else if (response.statusCode == 400) {
        if (enableLogging) print('Invalid email format');
        return false;
      } else if (response.statusCode == 404) {
        if (enableLogging) print('Email not registered');
        return false;
      } else {
        if (enableLogging) print('Activation request failed: ${response.statusCode}');
        return false;
      }
    } catch (e) {
      if (enableLogging) print('Activation request error: $e');
      return false;
    }
  }

  static Future<String?> verifyActivationCode(String email, String activationCode) async {
    try {
      if (enableLogging) print('Verifying activation code for: $email');
      if (enableLogging) print('Using URL: $_baseUrl/verify-activation-code');

      final response = await http.post(
        Uri.parse('$_baseUrl/verify-activation-code'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({
          'email': email,
          'activation_code': activationCode,
        }),
      ).timeout(const Duration(seconds: 30));

      if (enableLogging) print('Verify code response status: ${response.statusCode}');
      if (enableLogging) print('Verify code response body: ${response.body}');

      if (response.statusCode == 200) {
        final Map<String, dynamic> data = json.decode(response.body);

        final tokenObj = data['verification-opaque-token'];

        String? verificationToken;
        if (tokenObj is Map) {
          verificationToken = tokenObj['token'];
        } else if (tokenObj is String) {
          verificationToken = tokenObj;
        }

        if (verificationToken != null) {
          if (enableLogging) print('Verification successful, token received');
          return verificationToken;
        } else {
          if (enableLogging) print('No token in response');
          return null;
        }
      } else if (response.statusCode == 400) {
        if (enableLogging) print('Invalid verification code');
        return null;
      } else if (response.statusCode == 401) {
        if (enableLogging) print('Code expired or incorrect');
        return null;
      } else {
        if (enableLogging) print('Verification failed: ${response.statusCode}');
        return null;
      }
    } catch (e) {
      if (enableLogging) print('Verification error: $e');
      return null;
    }
  }

  static Future<bool> setPassword(String password, String confirmPassword, String verificationToken) async {
    try {
      if (enableLogging) print('Setting password');
      if (enableLogging) print('Using URL: $_baseUrl/set-password');

      final response = await http.patch(
        Uri.parse('$_baseUrl/set-password'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({
          'password': password,
          'confirm_password': confirmPassword,
          'verification_token': verificationToken,
        }),
      ).timeout(const Duration(seconds: 30));

      if (enableLogging) print('Set password response status: ${response.statusCode}');

      if (response.statusCode == 200) {
        if (enableLogging) print('Password set successfully, account activated');
        return true;
      } else if (response.statusCode == 400) {
        if (enableLogging) print('Invalid password format');
        return false;
      } else if (response.statusCode == 401) {
        if (enableLogging) print('Verification token expired');
        return false;
      } else {
        if (enableLogging) print('Set password failed: ${response.statusCode}');
        return false;
      }
    } catch (e) {
      if (enableLogging) print('Set password error: $e');
      return false;
    }
  }

  static Future<bool> resendActivationCode(String email) async {
    return await requestActivationCode(email);
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



  static Future<void> forgotPassword(String email) async {
    try {
      if (enableLogging) print('Requesting password reset for: $email');
      if (enableLogging) print('Using URL: $_baseUrl/forgot-password');

      final response = await http.post(
        Uri.parse('$_baseUrl/forgot-password'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({'email': email}),
      ).timeout(const Duration(seconds: 30));

      if (enableLogging) print('Forgot password response status: ${response.statusCode}');

      if (response.statusCode == 204) {
        if (enableLogging) print('Reset code sent successfully');
        return;
      } else {
        String errorMessage = 'Failed to send reset code';
        try {
          final error = json.decode(response.body);
          errorMessage = error['message'] ?? error['error'] ?? errorMessage;
        } catch (_) {}
        throw Exception(errorMessage);
      }
    } catch (e) {
      if (enableLogging) print('Forgot password error: $e');
      rethrow;
    }
  }

  static Future<String> verifyForgotPasswordToken(String email, String verificationCode) async {
    try {
      if (enableLogging) print('Verifying reset code for: $email');
      if (enableLogging) print('Verification code: $verificationCode');
      if (enableLogging) print('Using URL: $_baseUrl/verify-forgot-password-token');

      final requestBody = json.encode({
        'email': email,
        'verification_code': verificationCode,
      });

      if (enableLogging) print('Request body: $requestBody');

      final response = await http.post(
        Uri.parse('$_baseUrl/verify-forgot-password-token'),
        headers: {'Content-Type': 'application/json'},
        body: requestBody,
      ).timeout(const Duration(seconds: 30));

      if (enableLogging) print('Verify token response status: ${response.statusCode}');
      if (enableLogging) print('Verify token response body: ${response.body}');

      if (response.statusCode == 200) {
        final Map<String, dynamic> data = json.decode(response.body);

        // Extract the opaque token - matches your backend DTO
        final opaqueTokenData = data['verification-opaque-token'];
        String? opaqueToken;

        if (opaqueTokenData is Map) {
          opaqueToken = opaqueTokenData['token'];
        } else if (opaqueTokenData is String) {
          opaqueToken = opaqueTokenData;
        }

        if (opaqueToken != null && opaqueToken.isNotEmpty) {
          if (enableLogging) print('Verification successful, opaque token received');
          return opaqueToken;
        } else {
          if (enableLogging) print('No token in response: $data');
          throw Exception('Invalid verification response: No token received');
        }
      } else {
        String errorMessage = 'Invalid verification code';
        try {
          final error = json.decode(response.body);
          errorMessage = error['message'] ?? error['error'] ?? errorMessage;
        } catch (_) {}
        if (enableLogging) print('Verification failed: $errorMessage');
        throw Exception(errorMessage);
      }
    } catch (e) {
      if (enableLogging) print('Verify token error: $e');
      rethrow;
    }
  }

  static Future<void> changeForgotPassword(String opaqueToken, String password, String confirmPassword) async {
    try {
      if (enableLogging) print('Changing password with opaque token');
      if (enableLogging) print('Using URL: $_baseUrl/change-forgot-password');

      final requestBody = json.encode({
        'password': password,
        'confirm_password': confirmPassword,
      });

      if (enableLogging) print('Request body: $requestBody');

      final response = await http.patch(
        Uri.parse('$_baseUrl/change-forgot-password'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $opaqueToken',
        },
        body: requestBody,
      ).timeout(const Duration(seconds: 30));

      if (enableLogging) print('Change password response status: ${response.statusCode}');
      if (enableLogging) print('Change password response body: ${response.body}');

      if (response.statusCode == 204) {
        if (enableLogging) print('Password changed successfully');
        return;
      } else {
        String errorMessage = 'Failed to change password';
        try {
          final error = json.decode(response.body);
          errorMessage = error['message'] ?? error['error'] ?? errorMessage;
        } catch (_) {}
        throw Exception(errorMessage);
      }
    } catch (e) {
      if (enableLogging) print('Change password error: $e');
      rethrow;
    }
  }
}