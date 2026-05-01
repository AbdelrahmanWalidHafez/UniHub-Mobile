import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../../providers/auth_provider.dart';
import 'verification_code_screen.dart';

class ActivateAccountScreen extends StatefulWidget {
  const ActivateAccountScreen({super.key});

  @override
  State<ActivateAccountScreen> createState() => _ActivateAccountScreenState();
}

class _ActivateAccountScreenState extends State<ActivateAccountScreen> {
  final TextEditingController _emailController = TextEditingController();
  final _formKey = GlobalKey<FormState>();

  @override
  void dispose() {
    _emailController.dispose();
    super.dispose();
  }

  Future<void> _handleActivation() async {
    if (!_formKey.currentState!.validate()) return;

    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final success = await authProvider.requestActivationCode(
      _emailController.text.trim(),
    );

    if (success && mounted) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => VerificationCodeScreen(
            email: _emailController.text.trim(),
          ),
        ),
      );
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
                child: Consumer<AuthProvider>(
                  builder: (context, authProvider, child) {
                    return Form(
                      key: _formKey,
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          // Logo
                          Container(
                            width: 80,
                            height: 80,
                            child: Image.asset(
                              'assets/images/logo.png',
                              fit: BoxFit.contain,
                              errorBuilder: (_, __, ___) => Container(
                                color: Colors.grey.shade200,
                                child: const Icon(Icons.school, size: 40, color: Color(0xFF0077B3)),
                              ),
                            ),
                          ),
                          const SizedBox(height: 24),

                          // Title
                          const Text(
                            'Activate Your Account',
                            style: TextStyle(
                              fontSize: 24,
                              fontWeight: FontWeight.bold,
                              color: Colors.black87,
                            ),
                          ),
                          const SizedBox(height: 12),

                          // Subtitle
                          Text(
                            'Enter your email to receive activation code',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 14,
                              color: Colors.grey.shade600,
                            ),
                          ),
                          const SizedBox(height: 32),

                          // Email Field
                          _buildEmailField(authProvider),

                          // Error Message
                          if (authProvider.activationError != null)
                            _buildErrorMessage(authProvider.activationError!),

                          const SizedBox(height: 24),

                          // Submit Button
                          _buildSubmitButton(authProvider),

                          const SizedBox(height: 20),

                          // Back to Login
                          _buildBackToLogin(),
                        ],
                      ),
                    );
                  },
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildEmailField(AuthProvider authProvider) {
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
            enabled: !authProvider.isLoading,
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

  Widget _buildSubmitButton(AuthProvider authProvider) {
    return SizedBox(
      width: double.infinity,
      height: 50,
      child: ElevatedButton(
        onPressed: authProvider.isLoading ? null : _handleActivation,
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFF080B0C),
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
        child: authProvider.isLoading
            ? const SizedBox(
          width: 20,
          height: 20,
          child: CircularProgressIndicator(
            color: Colors.white,
            strokeWidth: 2,
          ),
        )
            : const Text(
          'Send Activation Code',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }

  Widget _buildBackToLogin() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text(
          'Already have an account?',
          style: TextStyle(color: Colors.grey.shade600, fontSize: 14),
        ),
        const SizedBox(width: 4),
        GestureDetector(
          onTap: () => Navigator.pop(context),
          child: const Text(
            'Login',
            style: TextStyle(
              color: Color(0xFF0076B2),
              fontSize: 14,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildErrorMessage(String error) {
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
                error,
                style: const TextStyle(color: Colors.red, fontSize: 12),
              ),
            ),
          ],
        ),
      ),
    );
  }
}