import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'activate_account_screen.dart';
import 'home_page.dart';
import '../providers/auth_provider.dart';
import '../services/token_service.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  bool _isPasswordVisible = false;
  bool _isLoading = false;
  String? _errorMessage;

  Future<void> _clearStaleTokens() async {
    await TokenService.clearTokens();
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _handleLogin() async {
    if (_formKey.currentState!.validate()) {
      setState(() {
        _isLoading = true;
        _errorMessage = null;
      });

      final authProvider = Provider.of<AuthProvider>(context, listen: false);

      final result = await authProvider.login(
        _emailController.text.trim(),
        _passwordController.text,
      );

      if (mounted) {
        setState(() => _isLoading = false);

        if (result != null && result['success'] == true) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Login successful!'), backgroundColor: Colors.green),
          );

          Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (_) => const HomePage()),
          );
        } else {
          setState(() => _errorMessage = result?['message'] ?? 'Login failed');
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          image: DecorationImage(
            image: AssetImage('assets/images/background2.jpeg'),
            fit: BoxFit.cover,
          ),
        ),
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 32.0),
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.95),
                  borderRadius: BorderRadius.circular(24),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black12,
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                padding: const EdgeInsets.all(24),
                child: Form(
                  key: _formKey,
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      // Logo
                      Container(
                        width: 100,
                        height: 100,
                        child: Image.asset('assets/images/logo.png', fit: BoxFit.contain,
                          errorBuilder: (_, __, ___) => Container(
                            color: Colors.grey.shade200,
                            child: const Icon(Icons.school, size: 50, color: Color(0xFF0077B3)),
                          ),
                        ),
                      ),
                      const SizedBox(height: 24),

                      const Text(
                        'UniHub',
                        style: TextStyle(
                          fontSize: 32,
                          fontWeight: FontWeight.bold,
                          color: Colors.black,
                          letterSpacing: -0.5,
                        ),
                      ),
                      const SizedBox(height: 8),

                      Column(children: [
                        Text(
                          'Connecting Knowledge',
                          style: TextStyle(fontSize: 16, color: Colors.grey.shade700),
                        ),
                        Text(
                          'Empowering Minds',
                          style: TextStyle(fontSize: 16, color: Colors.grey.shade700),
                        ),
                      ]),
                      const SizedBox(height: 48),

                      _buildEmailField(),
                      const SizedBox(height: 20),

                      _buildPasswordField(),

                      if (_errorMessage != null) _buildErrorMessage(),

                      const SizedBox(height: 16),

                      SizedBox(
                        width: 184,
                        height: 50,
                        child: ElevatedButton(
                          onPressed: _isLoading ? null : _handleLogin,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF080B0C),
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(15),
                            ),
                            elevation: 0,
                          ),
                          child: _isLoading
                              ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                              : const Text('Login', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
                        ),
                      ),

                      const SizedBox(height: 20),

                      _buildFooterLinks(),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildEmailField() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Email',
          style: TextStyle(
            fontSize: 14,
            color: Colors.grey.shade700,
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 8),
        Container(
          height: 50,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            color: Colors.grey.shade50,
            border: Border.all(color: Colors.grey.shade300, width: 1),
          ),
          child: TextFormField(
            controller: _emailController,
            keyboardType: TextInputType.emailAddress,
            enabled: !_isLoading,
            decoration: InputDecoration(
              hintText: 'Enter your email',
              hintStyle: TextStyle(color: Colors.grey.shade400, fontSize: 14),
              prefixIcon: Icon(Icons.email_outlined, color: Colors.grey.shade500, size: 20),
              border: InputBorder.none,
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            ),
            validator: (value) {
              if (value == null || value.isEmpty) return 'Email is required';
              if (!value.contains('@') || !value.contains('.')) return 'Enter a valid email';
              return null;
            },
          ),
        ),
      ],
    );
  }

  Widget _buildPasswordField() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Password',
          style: TextStyle(
            fontSize: 14,
            color: Colors.grey.shade700,
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 8),
        Container(
          height: 50,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            color: Colors.grey.shade50,
            border: Border.all(color: Colors.grey.shade300, width: 1),
          ),
          child: TextFormField(
            controller: _passwordController,
            obscureText: !_isPasswordVisible,
            enabled: !_isLoading,
            decoration: InputDecoration(
              hintText: 'Enter your password',
              hintStyle: TextStyle(color: Colors.grey.shade400, fontSize: 14),
              prefixIcon: Icon(Icons.lock_outline, color: Colors.grey.shade500, size: 20),
              suffixIcon: IconButton(
                icon: Icon(
                  _isPasswordVisible ? Icons.visibility : Icons.visibility_off,
                  color: Colors.grey.shade500,
                  size: 20,
                ),
                onPressed: () => setState(() => _isPasswordVisible = !_isPasswordVisible),
              ),
              border: InputBorder.none,
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            ),
            validator: (value) {
              if (value == null || value.isEmpty) return 'Password is required';
              if (value.length < 6) return 'Password must be at least 6 characters';
              return null;
            },
          ),
        ),
      ],
    );
  }

  Widget _buildErrorMessage() {
    return Padding(
      padding: const EdgeInsets.only(top: 12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: Colors.red.withOpacity(0.1),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          children: [
            const Icon(Icons.error_outline, color: Colors.red, size: 16),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                _errorMessage!,
                style: const TextStyle(color: Colors.red, fontSize: 12),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFooterLinks() {
    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              'Forgot your password?',
              style: TextStyle(color: Colors.grey.shade600, fontSize: 14),
            ),
            const SizedBox(width: 4),
            GestureDetector(
              onTap: () => ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Change password coming soon'), backgroundColor: Colors.orange),
              ),
              child: const Text(
                'Change Password',
                style: TextStyle(color: Color(0xFF0076B2), fontSize: 14, fontWeight: FontWeight.w600),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              'First time here?',
              style: TextStyle(color: Colors.grey.shade600, fontSize: 14),
            ),
            const SizedBox(width: 4),
            GestureDetector(
              onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const ActivateAccountScreen())),
              child: const Text(
                'Activate Account',
                style: TextStyle(color: Color(0xFF0076B2), fontSize: 14, fontWeight: FontWeight.w600),
              ),
            ),
          ],
        ),
      ],
    );
  }
}