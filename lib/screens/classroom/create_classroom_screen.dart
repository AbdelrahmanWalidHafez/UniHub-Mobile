import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/classroom_provider.dart';

class CreateClassroomScreen extends StatefulWidget {
  const CreateClassroomScreen({super.key});

  @override
  State<CreateClassroomScreen> createState() => _CreateClassroomScreenState();
}

class _CreateClassroomScreenState extends State<CreateClassroomScreen> {
  final _titleController = TextEditingController();
  final _subtitleController = TextEditingController();
  final _titleFocus = FocusNode();
  final _subtitleFocus = FocusNode();
  final _formKey = GlobalKey<FormState>();

  bool _isLoading = false;

  static const Color _lime = Color(0xFFB9FF66);
  static const Color _lightBg = Color(0xFFF8FAFB);
  static const Color _darkBlue = Color(0xFF1E3A5F);
  static const Color _border = Color(0xFFE8EDF2);

  @override
  void dispose() {
    _titleController.dispose();
    _subtitleController.dispose();
    _titleFocus.dispose();
    _subtitleFocus.dispose();
    super.dispose();
  }

  String? _validateTitle(String? value) {
    if (value == null || value.trim().isEmpty) return 'Class title is required';
    if (value.trim().length < 2) return 'Must be at least 2 characters';
    if (value.trim().length > 50) return 'Must be at most 50 characters';
    final pattern = RegExp(r"^[\p{L}\p{N} .,'\-]+$", unicode: true);
    if (!pattern.hasMatch(value.trim())) {
      return "Only letters, numbers, spaces and . , ' -";
    }
    return null;
  }

  String? _validateSubtitle(String? value) {
    if (value == null || value.trim().isEmpty) return 'Class subtitle is required';
    if (value.trim().length < 2) return 'Must be at least 2 characters';
    if (value.trim().length > 60) return 'Must be at most 60 characters';
    final pattern = RegExp(r"^[\p{L}\p{N} .,'\-]+$", unicode: true);
    if (!pattern.hasMatch(value.trim())) {
      return "Only letters, numbers, spaces and . , ' -";
    }
    return null;
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    FocusScope.of(context).unfocus();

    setState(() => _isLoading = true);

    final provider = context.read<ClassroomProvider>();
    final classroom = await provider.createClassroom(
      _titleController.text.trim(),
      _subtitleController.text.trim(),
    );

    if (!mounted) return;
    setState(() => _isLoading = false);

    if (classroom != null) {
      Navigator.pop(context, true); // signal success to parent
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(Icons.error_outline, color: Colors.white, size: 18),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  provider.error ?? 'Failed to create class. Please try again.',
                ),
              ),
            ],
          ),
          backgroundColor: Colors.red.shade700,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      );
      provider.clearError();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _lightBg,
      body: Column(
        children: [
          // ── App Bar ──────────────────────────────────────────────
          Container(
            color: Colors.white,
            child: SafeArea(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                child: Row(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.arrow_back_ios_new,
                          color: Colors.black87, size: 20),
                      onPressed: () => Navigator.pop(context),
                    ),
                    const Expanded(
                      child: Text(
                        'Create Class',
                        style: TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                          color: Colors.black87,
                          letterSpacing: -0.5,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),

          // ── Content ──────────────────────────────────────────────
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // ── Hero icon ─────────────────────────────────
                    Center(
                      child: Container(
                        width: 90,
                        height: 90,
                        decoration: BoxDecoration(
                          color: _lime,
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: _lime.withOpacity(0.4),
                              blurRadius: 20,
                              spreadRadius: 2,
                            ),
                          ],
                        ),
                        child: const Icon(Icons.class_rounded,
                            size: 44, color: Colors.black87),
                      ),
                    ),
                    const SizedBox(height: 12),
                    const Center(
                      child: Text(
                        'Set up your new class',
                        style: TextStyle(
                          fontSize: 16,
                          color: Colors.black54,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                    const SizedBox(height: 36),

                    // ── Card ──────────────────────────────────────
                    Container(
                      padding: const EdgeInsets.all(24),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: _border),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.grey.withOpacity(0.08),
                            blurRadius: 16,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Class Title
                          _fieldLabel('Class Title', required: true),
                          const SizedBox(height: 8),
                          TextFormField(
                            controller: _titleController,
                            focusNode: _titleFocus,
                            validator: _validateTitle,
                            textInputAction: TextInputAction.next,
                            onFieldSubmitted: (_) =>
                                FocusScope.of(context).requestFocus(_subtitleFocus),
                            style: const TextStyle(
                                color: Colors.black87, fontSize: 15),
                            decoration: _inputDecoration(
                              hint: 'e.g. Data Structures',
                              icon: Icons.title_rounded,
                            ),
                          ),
                          const SizedBox(height: 8),
                          _hint('2–50 characters. Letters, numbers, spaces, . , \' -'),

                          const SizedBox(height: 24),

                          // Class Subtitle
                          _fieldLabel('Class Subtitle', required: true),
                          const SizedBox(height: 8),
                          TextFormField(
                            controller: _subtitleController,
                            focusNode: _subtitleFocus,
                            validator: _validateSubtitle,
                            textInputAction: TextInputAction.done,
                            onFieldSubmitted: (_) => _submit(),
                            style: const TextStyle(
                                color: Colors.black87, fontSize: 15),
                            decoration: _inputDecoration(
                              hint: 'e.g. CS301 - Spring 2025',
                              icon: Icons.subtitles_rounded,
                            ),
                          ),
                          const SizedBox(height: 8),
                          _hint('2–60 characters. Letters, numbers, spaces, . , \' -'),
                        ],
                      ),
                    ),

                    const SizedBox(height: 32),

                    // ── Create button ─────────────────────────────
                    SizedBox(
                      width: double.infinity,
                      height: 54,
                      child: ElevatedButton(
                        onPressed: _isLoading ? null : _submit,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: _lime,
                          foregroundColor: Colors.black87,
                          disabledBackgroundColor: _lime.withOpacity(0.4),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14)),
                          elevation: 0,
                        ),
                        child: _isLoading
                            ? SizedBox(
                          width: 22,
                          height: 22,
                          child: CircularProgressIndicator(
                            strokeWidth: 2.5,
                            color: Colors.black.withOpacity(0.6),
                          ),
                        )
                            : const Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.add_circle_outline_rounded,
                                size: 20),
                            SizedBox(width: 8),
                            Text(
                              'Create Class',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),

                    const SizedBox(height: 16),

                    // ── Info note ─────────────────────────────────
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 12),
                      decoration: BoxDecoration(
                        color: _lime.withOpacity(0.08),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: _lime.withOpacity(0.25)),
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Icon(Icons.info_outline_rounded,
                              size: 16, color: Colors.grey.shade600),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              'After creating the class, you\'ll get an entry code to share with your students.',
                              style: TextStyle(
                                fontSize: 13,
                                color: Colors.grey.shade600,
                                height: 1.4,
                              ),
                            ),
                          ),
                        ],
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

  Widget _fieldLabel(String label, {bool required = false}) {
    return Row(
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: Colors.black87,
          ),
        ),
        if (required)
          const Text(
            ' *',
            style: TextStyle(color: Colors.red, fontSize: 14),
          ),
      ],
    );
  }

  Widget _hint(String text) {
    return Text(
      text,
      style: TextStyle(fontSize: 12, color: Colors.grey.shade500),
    );
  }

  InputDecoration _inputDecoration(
      {required String hint, required IconData icon}) {
    return InputDecoration(
      hintText: hint,
      hintStyle: TextStyle(color: Colors.grey.shade400, fontSize: 14),
      prefixIcon: Icon(icon, color: Colors.grey.shade400, size: 20),
      filled: true,
      fillColor: _lightBg,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide.none,
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: _border, width: 1),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Colors.black, width: 1.5),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: Colors.red.shade400, width: 1),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: Colors.red.shade400, width: 1.5),
      ),
      contentPadding:
      const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
    );
  }
}