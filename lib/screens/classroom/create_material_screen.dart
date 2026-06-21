import 'package:flutter/material.dart';
import 'dart:io';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import '../../providers/classroom_provider.dart';
import '../../models/classroom/material_model.dart';

class CreateMaterialScreen extends StatefulWidget {
  final String classroomId;
  final ClassroomMaterialType materialType;

  const CreateMaterialScreen({
    super.key,
    required this.classroomId,
    required this.materialType,
  });

  @override
  State<CreateMaterialScreen> createState() => _CreateMaterialScreenState();
}

class _CreateMaterialScreenState extends State<CreateMaterialScreen> {
  final TextEditingController _titleController = TextEditingController();
  final TextEditingController _descriptionController = TextEditingController();
  List<File> _selectedFiles = [];
  bool _isLoading = false;

  static const Color _lime = Color(0xFFB9FF66);
  static const Color _lightBg = Color(0xFFF8FAFB);

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  Future<void> _pickFiles() async {
    final picker = ImagePicker();
    final result = await picker.pickMultiImage();
    if (result != null) {
      setState(() {
        _selectedFiles = result.map((x) => File(x.path)).toList();
      });
    }
  }

  void _removeFile(int index) {
    setState(() {
      _selectedFiles.removeAt(index);
    });
  }

  Future<void> _submit() async {
    final title = _titleController.text.trim();
    final description = _descriptionController.text.trim();

    if (title.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please enter a title'),
          backgroundColor: Colors.red,
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    if (description.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please enter a description'),
          backgroundColor: Colors.red,
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    setState(() => _isLoading = true);

    final provider = context.read<ClassroomProvider>();
    ClassroomMaterial? result;

    try {
      if (widget.materialType == ClassroomMaterialType.announcement) {
        result = await provider.createAnnouncement(
          widget.classroomId,
          title,
          description,
          _selectedFiles.isEmpty ? null : _selectedFiles,
        );
      } else {
        // For now, treat material same as announcement
        result = await provider.createAnnouncement(
          widget.classroomId,
          title,
          description,
          _selectedFiles.isEmpty ? null : _selectedFiles,
        );
      }

      if (result != null && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${widget.materialType.displayName} created successfully!'),
            backgroundColor: Colors.green,
            behavior: SnackBarBehavior.floating,
          ),
        );
        Navigator.pop(context, true);
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to create: $e'),
          backgroundColor: Colors.red,
          behavior: SnackBarBehavior.floating,
        ),
      );
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _lightBg,
      appBar: AppBar(
        title: Text(
          'Create ${widget.materialType.displayName}',
          style: const TextStyle(color: Colors.black87),
        ),
        backgroundColor: Colors.white,
        elevation: 0,
        foregroundColor: Colors.black87,
        centerTitle: false,
        actions: [
          TextButton(
            onPressed: _isLoading ? null : _submit,
            child: Text(
              'Post',
              style: TextStyle(
                color: _lime,
                fontWeight: FontWeight.w600,
                fontSize: 16,
              ),
            ),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TextField(
              controller: _titleController,
              style: const TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: Colors.black87,
              ),
              decoration: const InputDecoration(
                hintText: 'Title',
                border: InputBorder.none,
                contentPadding: EdgeInsets.zero,
                hintStyle: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: Colors.grey,
                ),
              ),
              maxLength: 100,
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _descriptionController,
              style: const TextStyle(color: Colors.black87),
              decoration: const InputDecoration(
                hintText: 'Description',
                border: InputBorder.none,
                hintStyle: TextStyle(color: Colors.grey),
              ),
              maxLines: 10,
              maxLength: 500,
            ),
            const SizedBox(height: 16),

            if (_selectedFiles.isNotEmpty) ...[
              const Text(
                'Attachments',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: Colors.black87,
                ),
              ),
              const SizedBox(height: 8),
              ..._selectedFiles.asMap().entries.map((entry) {
                final index = entry.key;
                final file = entry.value;
                return Container(
                  margin: const EdgeInsets.only(bottom: 8),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: _lime.withOpacity(0.08),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: _lime.withOpacity(0.3)),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.attach_file,
                        size: 20,
                        color: _lime,
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          file.path.split('/').last,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(color: Colors.black87),
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close, size: 20, color: Colors.grey),
                        onPressed: () => _removeFile(index),
                      ),
                    ],
                  ),
                );
              }),
              const SizedBox(height: 8),
            ],

            Row(
              children: [
                IconButton(
                  icon: Icon(Icons.attach_file, color: _lime),
                  onPressed: _pickFiles,
                  tooltip: 'Add attachments',
                ),
                Text(
                  'Add attachments',
                  style: TextStyle(color: Colors.grey.shade600),
                ),
              ],
            ),

            if (_isLoading)
              const Padding(
                padding: EdgeInsets.all(32),
                child: Center(
                  child: CircularProgressIndicator(),
                ),
              ),
          ],
        ),
      ),
    );
  }
}