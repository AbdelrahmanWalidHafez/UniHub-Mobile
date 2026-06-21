import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'screens/login_screen.dart';
import 'screens/home_page.dart';
import '../providers/auth_provider.dart';
import '../services/token_service.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  late Animation<double> _scaleAnimation;
  late Animation<double> _rotationAnimation;
  late Animation<Offset> _slideAnimation;
  late Animation<double> _pulseAnimation;

  static const Color _lime = Color(0xFFB9FF66);
  static const Color _brand = Color(0xFF0077B3);
  static const Color _lightBg = Color(0xFFF8FAFB);

  @override
  void initState() {
    super.initState();
    _setupAnimations();
    _navigateToNext();
  }

  void _setupAnimations() {
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 3000),
    );

    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeOut),
    );

    _scaleAnimation = Tween<double>(begin: 0.3, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.elasticOut),
    );

    _rotationAnimation = Tween<double>(begin: -0.3, end: 0.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeOut),
    );

    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 0.6),
      end: Offset.zero,
    ).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeOut),
    );

    _pulseAnimation = Tween<double>(begin: 1.0, end: 1.2).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeInOut),
    );

    _animationController.forward();
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  Future<void> _navigateToNext() async {
    // Force minimum 4 seconds splash display
    final startTime = DateTime.now();

    // Check tokens
    final hasValidTokens = await _hasValidTokens();

    // Ensure minimum display time
    final elapsed = DateTime.now().difference(startTime).inMilliseconds;
    final remaining = 4000 - elapsed;
    if (remaining > 0) {
      await Future.delayed(Duration(milliseconds: remaining));
    }

    if (mounted) {
      final authProvider = Provider.of<AuthProvider>(context, listen: false);

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
      backgroundColor: _lightBg,
      body: Stack(
        children: [
          // Animated background blobs - Light version
          _buildBackgroundBlobs(),

          SafeArea(
            child: FadeTransition(
              opacity: _fadeAnimation,
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    // Animated Logo with pulse - WITHOUT BACKGROUND
                    AnimatedBuilder(
                      animation: _pulseAnimation,
                      builder: (context, child) {
                        return Container(
                          decoration: BoxDecoration(
                            boxShadow: [
                              BoxShadow(
                                color: _lime.withOpacity(0.4 * _pulseAnimation.value),
                                blurRadius: 40 * _pulseAnimation.value,
                                spreadRadius: 10 * _pulseAnimation.value,
                              ),
                            ],
                          ),
                          child: Transform.rotate(
                            angle: _rotationAnimation.value,
                            child: ScaleTransition(
                              scale: _scaleAnimation,
                              child: Container(
                                width: 130,
                                height: 130,
                                // REMOVED: gradient background
                                // REMOVED: borderRadius
                                // REMOVED: boxShadow on container
                                child: Image.asset(
                                  'assets/images/logo.png',
                                  width: 130,
                                  height: 130,
                                  fit: BoxFit.contain,
                                  errorBuilder: (context, error, stackTrace) {
                                    return const Icon(
                                      Icons.school,
                                      size: 65,
                                      color: Color(0xFF1A1A1A),
                                    );
                                  },
                                ),
                              ),
                            ),
                          ),
                        );
                      },
                    ),

                    const SizedBox(height: 40),

                    // Animated Title - Light version
                    SlideTransition(
                      position: _slideAnimation,
                      child: Column(
                        children: [
                          RichText(
                            text: const TextSpan(
                              style: TextStyle(
                                fontSize: 44,
                                fontWeight: FontWeight.bold,
                                letterSpacing: -0.5,
                              ),
                              children: [
                                TextSpan(
                                  text: 'UniHub',
                                  style: TextStyle(color: Color(0xFF1A1A1A)),
                                ),
                                TextSpan(
                                  text: ' ',
                                  style: TextStyle(color: Color(0xFF1A1A1A)),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 12),
                          Column(
                            children: [
                              Text(
                                'Connecting Knowledge',
                                style: TextStyle(
                                  fontSize: 16,
                                  color: Colors.grey.shade600,
                                  letterSpacing: 0.3,
                                ),
                              ),
                              Text(
                                'Empowering Minds',
                                style: TextStyle(
                                  fontSize: 16,
                                  color: Colors.grey.shade600,
                                  letterSpacing: 0.3,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 60),

                    // Animated Loading with glow - Light version
                    _buildLoadingIndicator(),

                    const SizedBox(height: 32),

                    // Version
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
          ),
        ],
      ),
    );
  }

  Widget _buildBackgroundBlobs() {
    return Stack(
      children: [
        Positioned(
          top: -100,
          right: -50,
          child: Container(
            width: 250,
            height: 250,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: RadialGradient(
                colors: [
                  _lime.withOpacity(0.12),
                  _lime.withOpacity(0),
                ],
              ),
            ),
          ),
        ),
        Positioned(
          bottom: -80,
          left: -50,
          child: Container(
            width: 220,
            height: 220,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: RadialGradient(
                colors: [
                  _brand.withOpacity(0.08),
                  _brand.withOpacity(0),
                ],
              ),
            ),
          ),
        ),
        Positioned(
          top: 280,
          left: -40,
          child: Container(
            width: 180,
            height: 180,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: RadialGradient(
                colors: [
                  _lime.withOpacity(0.06),
                  _lime.withOpacity(0),
                ],
              ),
            ),
          ),
        ),
        Positioned(
          bottom: 180,
          right: -50,
          child: Container(
            width: 150,
            height: 150,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: RadialGradient(
                colors: [
                  _brand.withOpacity(0.06),
                  _brand.withOpacity(0),
                ],
              ),
            ),
          ),
        ),
        Positioned(
          top: 150,
          right: 50,
          child: Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: RadialGradient(
                colors: [
                  _lime.withOpacity(0.04),
                  _lime.withOpacity(0),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildLoadingIndicator() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        _buildAnimatedDot(0, _brand),
        const SizedBox(width: 8),
        _buildAnimatedDot(1, _lime),
        const SizedBox(width: 8),
        _buildAnimatedDot(2, _lime),
      ],
    );
  }

  Widget _buildAnimatedDot(int index, Color color) {
    return AnimatedBuilder(
      animation: _animationController,
      builder: (context, child) {
        final progress = _animationController.value;
        final delay = index * 0.15;
        final scaledProgress = ((progress - delay) / (1 - delay)).clamp(0.0, 1.0);
        final scale = 1.0 + 0.3 * (1 - scaledProgress);
        final opacity = 0.3 + 0.7 * (1 - scaledProgress);

        return Transform.scale(
          scale: scale,
          child: Container(
            width: 10,
            height: 10,
            decoration: BoxDecoration(
              color: color.withOpacity(opacity),
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: _lime.withOpacity(0.3 * opacity),
                  blurRadius: 15,
                  spreadRadius: 3,
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}