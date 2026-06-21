import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:file_picker/file_picker.dart';
import 'package:provider/provider.dart';
import '../../providers/announcement_provider.dart';
import '../../models/post_model.dart';
import 'widgets/emoji_picker_widget.dart';
import 'widgets/media_preview_widget.dart';

class CreatePostScreen extends StatefulWidget {
  final Post? postToEdit;

  const CreatePostScreen({super.key, this.postToEdit});

  @override
  State<CreatePostScreen> createState() => _CreatePostScreenState();
}

class _CreatePostScreenState extends State<CreatePostScreen> {
  final _titleController = TextEditingController();
  final _contentController = TextEditingController();
  File? _selectedImage;
  bool _isLoading = false;
  bool _removeMedia = false;
  bool _showEmojiPicker = false;

  bool get _isEditing => widget.postToEdit != null;

  static const Color _brand = Color(0xFF0077B3);
  static const Color _lime = Color(0xFFB9FF66);
  static const Color _lightBg = Color(0xFFF8FAFB);
  static const Color _cardBg = Colors.white;

  @override
  void initState() {
    super.initState();
    if (_isEditing) {
      _titleController.text = widget.postToEdit!.title;
      _contentController.text = widget.postToEdit!.content ?? '';
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _contentController.dispose();
    super.dispose();
  }

  void _toggleEmojiPicker() {
    setState(() {
      _showEmojiPicker = !_showEmojiPicker;
    });
  }

  void _onEmojiSelected(String emoji) {
    final text = _contentController.text;
    final selection = _contentController.selection;
    final newText = text.replaceRange(selection.start, selection.end, emoji);
    _contentController.text = newText;
    _contentController.selection = TextSelection.fromPosition(
      TextPosition(offset: selection.start + emoji.length),
    );
  }

  void _onBackspacePressed() {
    final text = _contentController.text;
    if (text.isNotEmpty) {
      final selection = _contentController.selection;
      if (selection.start > 0) {
        final newText = text.substring(0, selection.start - 1) + text.substring(selection.start);
        _contentController.text = newText;
        _contentController.selection = TextSelection.fromPosition(
          TextPosition(offset: selection.start - 1),
        );
      }
    }
  }

  Future<void> _pickMedia() async {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      backgroundColor: Colors.white,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40,
              height: 4,
              margin: const EdgeInsets.symmetric(vertical: 12),
              decoration: BoxDecoration(
                color: Colors.grey.shade300,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            ListTile(
              leading: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.05),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(Icons.image, color: Colors.black),
              ),
              title: Text(
                'Pick Image',
                style: TextStyle(
                  color: Colors.black87,
                  fontWeight: FontWeight.bold,
                ),
              ),
              onTap: () {
                Navigator.pop(context);
                _pickImageFromGallery();
              },
            ),
            ListTile(
              leading: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.05),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(Icons.video_library, color: Colors.black),
              ),
              title: Text(
                'Pick Video',
                style: TextStyle(
                  color: Colors.black87,
                  fontWeight: FontWeight.bold,
                ),
              ),
              onTap: () {
                Navigator.pop(context);
                _pickVideo();
              },
            ),
            ListTile(
              leading: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.05),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(Icons.picture_as_pdf, color: Colors.black),
              ),
              title: Text(
                'Pick PDF',
                style: TextStyle(
                  color: Colors.black87,
                  fontWeight: FontWeight.bold,
                ),
              ),
              onTap: () {
                Navigator.pop(context);
                _pickPDF();
              },
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _pickImageFromGallery() async {
    final picker = ImagePicker();
    final result = await picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 85,
    );
    if (result != null) {
      setState(() {
        _selectedImage = File(result.path);
        _removeMedia = false;
      });
    }
  }

  Future<void> _pickVideo() async {
    final picker = ImagePicker();
    final result = await picker.pickVideo(
      source: ImageSource.gallery,
    );
    if (result != null) {
      setState(() {
        _selectedImage = File(result.path);
        _removeMedia = false;
      });
    }
  }

  Future<void> _pickPDF() async {
    try {
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['pdf'],
      );

      if (result != null) {
        setState(() {
          _selectedImage = File(result.files.single.path!);
          _removeMedia = false;
        });
      }
    } catch (e) {
      print('Error picking PDF: $e');
    }
  }

  String? _validateTitle(String value) {
    final trimmed = value.trim();
    if (trimmed.isEmpty) return 'Title is required';
    if (trimmed.length < 3) return 'Title must be at least 3 characters';
    if (trimmed.length > 70) return 'Title cannot exceed 70 characters';
    if (RegExp(r'[<>]').hasMatch(trimmed)) {
      return 'Title contains invalid characters';
    }
    return null;
  }

  Widget _buildMediaPreview() {
    if (_selectedImage != null) {
      final extension = _selectedImage!.path.split('.').last.toLowerCase();
      final isVideo = extension == 'mp4' || extension == 'mov' || extension == 'avi';
      final isPdf = extension == 'pdf';

      if (isVideo || isPdf) {
        return Stack(
          children: [
            Container(
              height: 200,
              width: double.infinity,
              decoration: BoxDecoration(
                color: Colors.grey.shade100,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    isVideo ? Icons.play_circle_filled : Icons.picture_as_pdf,
                    size: 50,
                    color: isVideo ? _lime : Colors.red,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    isVideo ? 'Video' : 'PDF Document',
                    style: const TextStyle(color: Colors.grey),
                  ),
                ],
              ),
            ),
            Positioned(
              top: 8,
              right: 8,
              child: CircleAvatar(
                backgroundColor: Colors.black.withOpacity(0.5),
                child: IconButton(
                  icon: const Icon(Icons.close, color: Colors.white),
                  onPressed: _isLoading
                      ? null
                      : () {
                    setState(() {
                      _selectedImage = null;
                      if (_isEditing) _removeMedia = true;
                    });
                  },
                ),
              ),
            ),
          ],
        );
      }

      // For images
      return Stack(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(16),
            child: Image.file(
              _selectedImage!,
              height: 200,
              width: double.infinity,
              fit: BoxFit.cover,
            ),
          ),
          Positioned(
            top: 8,
            right: 8,
            child: CircleAvatar(
              backgroundColor: Colors.black.withOpacity(0.5),
              child: IconButton(
                icon: const Icon(Icons.close, color: Colors.white),
                onPressed: _isLoading
                    ? null
                    : () {
                  setState(() {
                    _selectedImage = null;
                    if (_isEditing) _removeMedia = true;
                  });
                },
              ),
            ),
          ),
        ],
      );
    }
    return const SizedBox.shrink();
  }

  Widget _buildExistingMediaPreview() {
    final mediaUrl = widget.postToEdit!.mediaUrl!;

    return Stack(
      children: [
        MediaPreviewWidget(
          url: mediaUrl,
          height: 200,
          showDownloadButton: true,
        ),
        Positioned(
          top: 8,
          right: 8,
          child: CircleAvatar(
            backgroundColor: Colors.black.withOpacity(0.5),
            child: IconButton(
              icon: const Icon(Icons.close, color: Colors.white),
              onPressed: _isLoading
                  ? null
                  : () => setState(() => _removeMedia = true),
            ),
          ),
        ),
      ],
    );
  }

  Future<void> _submit() async {
    final titleError = _validateTitle(_titleController.text);
    if (titleError != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(titleError), backgroundColor: Colors.red),
      );
      return;
    }

    setState(() => _isLoading = true);

    final provider = context.read<AnnouncementProvider>();
    Post? result;

    try {
      if (_isEditing) {
        result = await provider.editPost(
          postId: widget.postToEdit!.id,
          title: _titleController.text.trim(),
          content: _contentController.text.trim().isEmpty
              ? null
              : _contentController.text.trim(),
          media: _selectedImage,
          removeMedia: _removeMedia,
        );
      } else {
        result = await provider.createPost(
          title: _titleController.text.trim(),
          content: _contentController.text.trim().isEmpty
              ? null
              : _contentController.text.trim(),
          media: _selectedImage,
        );
      }

      if (result != null && mounted) {
        String message;
        if (_isEditing) {
          message = 'Post updated successfully!';
          if (result.status == PostStatus.pending) {
            message += ' It will be reviewed by a secretary.';
          }
        } else {
          message = 'Post created as draft. ';
          message += 'Go to "My Posts" and click Publish to submit for review.';
        }

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(message),
            backgroundColor: Colors.green,
            behavior: SnackBarBehavior.floating,
          ),
        );
        Navigator.pop(context, true);
      } else if (mounted && provider.error != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(provider.error!),
            backgroundColor: Colors.red,
          ),
        );
      }
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
          _isEditing ? 'Edit Post' : 'Create Post',
          style: const TextStyle(
            color: Colors.black87,
            fontWeight: FontWeight.bold,
          ),
        ),
        backgroundColor: Colors.white,
        elevation: 0,
        centerTitle: false,
        actions: [
          // Removed the Post/Save button from app bar
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (!_isEditing)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                      margin: const EdgeInsets.only(bottom: 16),
                      decoration: BoxDecoration(
                        color: Colors.grey.shade50,
                        borderRadius: BorderRadius.circular(12),
                        //border: Border.all(color: _lime, width: 1.5),
                      ),
                      child: const Row(
                        children: [
                          Icon(Icons.info_outline, size: 16, color: Colors.black87),
                          SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              'Posts are saved as drafts. Go to "My Posts" to publish.',
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.black87,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),

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
                    maxLength: 70,
                    enabled: !_isLoading,
                  ),
                  const SizedBox(height: 8),

                  // Content field with emoji button
                  Stack(
                    children: [
                      TextField(
                        controller: _contentController,
                        style: const TextStyle(color: Colors.black87),
                        decoration: InputDecoration(
                          hintText: "What's on your mind?",
                          border: InputBorder.none,
                          hintStyle: TextStyle(color: Colors.grey.shade500),
                          suffixIcon: IconButton(
                            icon: Icon(
                              Icons.emoji_emotions,
                              color: _showEmojiPicker ? Colors.black : Colors.grey.shade500,
                            ),
                            onPressed: _toggleEmojiPicker,
                          ),
                        ),
                        maxLines: null,
                        maxLength: 10000,
                        enabled: !_isLoading,
                      ),
                    ],
                  ),

                  // Emoji Picker
                  if (_showEmojiPicker)
                    EmojiPickerWidget(
                      onEmojiSelected: _onEmojiSelected,
                      onBackspacePressed: _onBackspacePressed,
                      showPicker: _showEmojiPicker,
                    ),

                  const SizedBox(height: 16),

                  if (_selectedImage != null) _buildMediaPreview(),

                  if (_isEditing &&
                      widget.postToEdit!.mediaUrl != null &&
                      _selectedImage == null &&
                      !_removeMedia)
                    _buildExistingMediaPreview(),

                  const SizedBox(height: 16),

                  if (_selectedImage == null &&
                      !(_isEditing &&
                          widget.postToEdit!.mediaUrl != null &&
                          !_removeMedia))
                    Row(
                      children: [
                        IconButton(
                          icon: Icon(Icons.attach_file, color: Colors.black),
                          onPressed: _isLoading ? null : _pickMedia,
                          tooltip: 'Add image, video, or PDF',
                        ),
                        Text(
                          'Add media (image, video, PDF)',
                          style: TextStyle(
                            color: Colors.grey.shade600,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),

                  const SizedBox(height: 24),

                  // Publish Button
                  SizedBox(
                    width: double.infinity,
                    height: 54,
                    child: ElevatedButton(
                      onPressed: _isLoading ? null : _submit,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _lime,
                        foregroundColor: Colors.black,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                        elevation: 0,
                      ),
                      child: _isLoading
                          ? const SizedBox(
                        width: 22,
                        height: 22,
                        child: CircularProgressIndicator(
                          color: Colors.black,
                          strokeWidth: 2,
                        ),
                      )
                          : const Text(
                        'Publish',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Colors.black,
                        ),
                      ),
                    ),
                  ),

                  if (_isLoading)
                    const Padding(
                      padding: EdgeInsets.only(top: 16),
                      child: Center(child: CircularProgressIndicator()),
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}