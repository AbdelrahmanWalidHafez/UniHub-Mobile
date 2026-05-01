import 'package:flutter/material.dart';
import '../services/auth_service.dart';
import '../services/token_service.dart';

class AuthProvider extends ChangeNotifier {
  String? _accessToken;
  bool _isLoading = true;
  Map<String, dynamic>? _currentUser;
  bool _isInitialized = false;
  String? _activationError;

  String? get accessToken => _accessToken;
  bool get isLoading => _isLoading;
  bool get isAuthenticated => _accessToken != null;
  Map<String, dynamic>? get currentUser => _currentUser;
  String? get activationError => _activationError;

  String get userName {
    if (_currentUser == null) return 'User';
    final firstName = _currentUser?['first_name'] ?? '';
    final lastName = _currentUser?['last_name'] ?? '';
    if (firstName.isNotEmpty && lastName.isNotEmpty) {
      return '$firstName $lastName';
    } else if (firstName.isNotEmpty) {
      return firstName;
    } else if (lastName.isNotEmpty) {
      return lastName;
    }
    return _currentUser?['email']?.split('@').first ?? 'User';
  }

  String get userEmail => _currentUser?['email'] ?? '';

  AuthProvider() {
    _initialize();
  }

  Future<void> _initialize() async {
    _isLoading = true;
    notifyListeners();

    try {
      final accessToken = await TokenService.getAccessToken();
      final refreshToken = await TokenService.getRefreshToken();

      if (accessToken != null && refreshToken != null) {
        _accessToken = accessToken;

        final storedUser = await TokenService.getUserData();
        if (storedUser != null) {
          _currentUser = storedUser;
          if (AuthService.enableLogging) print('User data loaded from storage: ${userName}');
        }

        _refreshTokenInBackground();
      }
    } catch (e) {
      if (AuthService.enableLogging) print('Init error: $e');
    } finally {
      _isLoading = false;
      _isInitialized = true;
      notifyListeners();
    }
  }

  Future<void> _refreshTokenInBackground() async {
    try {
      final refreshToken = await TokenService.getRefreshToken();
      if (refreshToken != null) {
        final result = await AuthService.refreshTokens();
        if (result != null && result['success'] == true) {
          final newAccessToken = result['tokens']['accessToken'];
          _accessToken = newAccessToken;
          await TokenService.setAccessToken(newAccessToken);
          if (AuthService.enableLogging) print('Background refresh successful');
        }
      }
    } catch (e) {
      if (AuthService.enableLogging) print('Background refresh failed: $e');
    }
    notifyListeners();
  }

  Future<void> setAccessToken(String? token) async {
    await TokenService.setAccessToken(token);
    _accessToken = token;
    notifyListeners();
  }

  Future<void> loadUserData() async {
    try {
      final userData = await AuthService.getUserInfo();
      if (userData != null) {
        _currentUser = userData;
        await TokenService.saveUserData(userData);
        if (AuthService.enableLogging) print('User data loaded: ${userName}');
        notifyListeners();
      }
    } catch (e) {
      if (AuthService.enableLogging) print('Error loading user data: $e');
    }
  }

  Future<Map<String, dynamic>?> login(String email, String password) async {
    _isLoading = true;
    notifyListeners();

    try {
      final result = await AuthService.login(email, password);

      if (result != null && result['success'] == true && result['tokens'] != null) {
        final accessToken = result['tokens']['accessToken'];
        _accessToken = accessToken;

        await loadUserData();

        if (AuthService.enableLogging) print('Login successful, user: ${userName}');
        return result;
      }

      return result;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }


  Future<bool> requestActivationCode(String email) async {
    _isLoading = true;
    _activationError = null;
    notifyListeners();

    try {
      final success = await AuthService.requestActivationCode(email);
      if (!success) {
        _activationError = 'Failed to send activation code. Email may not be registered.';
      }
      return success;
    } catch (e) {
      _activationError = e.toString();
      return false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }


  Future<String?> verifyActivationCode(String email, String code) async {
    _isLoading = true;
    _activationError = null;
    notifyListeners();

    try {
      final verificationToken = await AuthService.verifyActivationCode(email, code);
      if (verificationToken == null) {
        _activationError = 'Invalid or expired verification code.';
      }
      return verificationToken;
    } catch (e) {
      _activationError = e.toString();
      return null;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }


  Future<bool> setPassword(String password, String confirmPassword, String verificationToken) async {
    _isLoading = true;
    _activationError = null;
    notifyListeners();

    try {
      final success = await AuthService.setPassword(password, confirmPassword, verificationToken);
      if (!success) {
        _activationError = 'Failed to set password. Token may have expired.';
      }
      return success;
    } catch (e) {
      _activationError = e.toString();
      return false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }


  Future<bool> resendActivationCode(String email) async {
    _isLoading = true;
    _activationError = null;
    notifyListeners();

    try {
      final success = await AuthService.resendActivationCode(email);
      if (!success) {
        _activationError = 'Failed to resend activation code.';
      }
      return success;
    } catch (e) {
      _activationError = e.toString();
      return false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }


  void clearActivationError() {
    _activationError = null;
    notifyListeners();
  }



  Future<void> logout() async {
    _isLoading = true;
    notifyListeners();

    try {
      await AuthService.logout();
      _accessToken = null;
      _currentUser = null;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<bool> refreshToken() async {
    try {
      final result = await AuthService.refreshTokens();
      if (result != null && result['success'] == true) {
        final newAccessToken = result['tokens']['accessToken'];
        _accessToken = newAccessToken;
        await TokenService.setAccessToken(newAccessToken);
        notifyListeners();
        return true;
      }
      return false;
    } catch (e) {
      return false;
    }
  }
}