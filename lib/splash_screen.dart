import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'screens/login_screen.dart';
import 'screens/home_page.dart';
import 'providers/auth_provider.dart';
import 'services/token_service.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();
    _navigateToNext();
  }

  Future<void> _navigateToNext() async {

    await Future.delayed(const Duration(seconds: 2));

    if (mounted) {
      final authProvider = Provider.of<AuthProvider>(context, listen: false);

      // Check if user has valid tokens (not expired)
      final hasValidTokens = await _hasValidTokens();

      if (hasValidTokens) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => const HomePage()),
        );
      } else {
        await authProvider.logout();
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => const LoginScreen()),
        );
      }
    }
  }

  Future<bool> _hasValidTokens() async {
    try {
      final accessToken = await TokenService.getAccessToken();
      final refreshToken = await TokenService.getRefreshToken();
      return accessToken != null && refreshToken != null;
    } catch (e) {
      return false;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 120,
                height: 120,
                child: Image.asset(
                  'assets/images/logo.png',
                  fit: BoxFit.contain,
                  errorBuilder: (context, error, stackTrace) {
                    return Container(
                      color: const Color(0xFF0077B3).withOpacity(0.1),
                      child: const Icon(
                        Icons.school,
                        size: 60,
                        color: Color(0xFF0077B3),
                      ),
                    );
                  },
                ),
              ),
              const SizedBox(height: 32),
              const Text(
                'UniHub',
                style: TextStyle(
                  fontSize: 40,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF080B0C),
                  letterSpacing: -0.5,
                ),
              ),
              const SizedBox(height: 12),
              Column(
                children: [
                  Text(
                    'Connecting Knowledge',
                    style: TextStyle(
                      fontSize: 18,
                      color: Colors.grey.shade700,
                    ),
                  ),
                  Text(
                    'Empowering Minds',
                    style: TextStyle(
                      fontSize: 18,
                      color: Colors.grey.shade700,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 48),
              const CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF0077B3)),
              ),
              const SizedBox(height: 24),
              Text(
                'Version 1.0.0',
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey.shade400,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}