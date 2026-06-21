import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../providers/classroom_provider.dart';
import '../../providers/auth_provider.dart';
import '../../models/classroom/material_model.dart';
import '../../models/classroom/comment_model.dart';
import '../../services/classroom_service.dart';
import '../ai_chat_screen.dart';
import 'submission_screen.dart';

class MaterialDetailScreen extends StatefulWidget {
  final String materialId;
  final ClassroomMaterial material;
  final bool isInstructor;

  const MaterialDetailScreen({
    super.key,
    required this.materialId,
    required this.material,
    required this.isInstructor,
  });

  @override
  State<MaterialDetailScreen> createState() => _MaterialDetailScreenState();
}

class _MaterialDetailScreenState extends State<MaterialDetailScreen> {
  final TextEditingController _commentController = TextEditingController();
  bool _isSubmitting = false;
  String? _assignmentId;
  bool _isLoadingAssignment = false;

  static const Color _lime = Color(0xFFB9FF66);
  static const Color _lightBg = Color(0xFFF8FAFB);

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadComments();
      if (widget.material.materialType == ClassroomMaterialType.assignment) {
        _fetchAssignmentId();
      }
    });
  }

  @override
  void dispose() {
    _commentController.dispose();
    super.dispose();
  }

  void _loadComments() {
    final provider = context.read<ClassroomProvider>();
    provider.loadComments(widget.materialId, refresh: true);
  }

  Future<void> _fetchAssignmentId() async {
    if (_isLoadingAssignment) return;
    setState(() => _isLoadingAssignment = true);

    try {
      final aid = await ClassroomService.getAssignmentIdFromMaterial(widget.materialId);
      setState(() => _assignmentId = aid);
      print('Fetched assignment ID: $_assignmentId');
    } catch (e) {
      print('Error fetching assignment ID: $e');
      setState(() => _assignmentId = null);
    } finally {
      setState(() => _isLoadingAssignment = false);
    }
  }

  Future<void> _submitComment() async {
    final content = _commentController.text.trim();
    if (content.isEmpty) return;

    setState(() => _isSubmitting = true);

    final provider = context.read<ClassroomProvider>();
    await provider.createComment(widget.materialId, content);

    if (mounted) {
      _commentController.clear();
      setState(() => _isSubmitting = false);
    }
  }

  Future<void> _openUrl(String url) async {
    String fullUrl = url;

    if (!url.startsWith('http')) {
      const baseUrl = 'http://34.58.11.82:8082';
      fullUrl = url.startsWith('/') ? '$baseUrl$url' : '$baseUrl/$url';
    }

    final Uri uri = Uri.parse(fullUrl);

    try {
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not open file'), backgroundColor: Colors.red),
        );
      }
    }
  }

  void _explainWithAI() {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final currentUserName = authProvider.userName;

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => AIChatScreen(
          userName: currentUserName,
          explainMaterialId: widget.material.id,
          explainMaterialTitle: widget.material.headLine,
        ),
      ),
    );
  }

  IconData _getFileIcon(String url) {
    final urlLower = url.toLowerCase();
    if (urlLower.endsWith('.pdf')) {
      return Icons.picture_as_pdf;
    } else if (urlLower.endsWith('.jpg') || urlLower.endsWith('.jpeg') || urlLower.endsWith('.png')) {
      return Icons.image;
    } else if (urlLower.endsWith('.mp4') || urlLower.endsWith('.mov')) {
      return Icons.video_library;
    } else {
      return Icons.insert_drive_file;
    }
  }

  Color _getFileIconColor(String url) {
    final urlLower = url.toLowerCase();
    if (urlLower.endsWith('.pdf')) {
      return Colors.red;
    } else if (urlLower.endsWith('.jpg') || urlLower.endsWith('.jpeg') || urlLower.endsWith('.png')) {
      return Colors.green;
    } else if (urlLower.endsWith('.mp4') || urlLower.endsWith('.mov')) {
      return Colors.blue;
    } else {
      return Colors.grey;
    }
  }

  String _getFileName(String url) {
    try {
      final parts = url.split('/');
      final fileName = parts.last;
      if (fileName.contains('?')) {
        return fileName.split('?').first;
      }
      return fileName;
    } catch (e) {
      return 'File';
    }
  }

  String _getFileType(String url) {
    final urlLower = url.toLowerCase();
    if (urlLower.endsWith('.pdf')) {
      return 'PDF Document';
    } else if (urlLower.endsWith('.jpg') || urlLower.endsWith('.jpeg')) {
      return 'JPEG Image';
    } else if (urlLower.endsWith('.png')) {
      return 'PNG Image';
    } else if (urlLower.endsWith('.mp4')) {
      return 'MP4 Video';
    } else {
      return 'File';
    }
  }

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final difference = now.difference(date);

    if (difference.inSeconds < 60) return 'Just now';
    if (difference.inMinutes < 60) return '${difference.inMinutes}m ago';
    if (difference.inHours < 24) return '${difference.inHours}h ago';
    if (difference.inDays < 7) return '${difference.inDays}d ago';

    final day = date.day.toString().padLeft(2, '0');
    final month = date.month.toString().padLeft(2, '0');
    return '$day/$month';
  }

  Future<void> _deleteComment(ClassroomComment comment) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Delete Comment', style: TextStyle(color: Colors.black87)),
        content: const Text('Are you sure you want to delete this comment?', style: TextStyle(color: Colors.grey)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel', style: TextStyle(color: Colors.grey)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      final provider = context.read<ClassroomProvider>();
      await provider.deleteComment(comment.id);
    }
  }

  Future<void> _editComment(ClassroomComment comment) async {
    final controller = TextEditingController(text: comment.content);
    final newContent = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Edit Comment', style: TextStyle(color: Colors.black87)),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(hintText: 'Enter your comment'),
          maxLines: 3,
          style: const TextStyle(color: Colors.black87),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel', style: TextStyle(color: Colors.grey)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, controller.text.trim()),
            child: Text('Save', style: TextStyle(color: Colors.black)),
          ),
        ],
      ),
    );

    if (newContent != null && newContent.isNotEmpty && newContent != comment.content) {
      final provider = context.read<ClassroomProvider>();
      await ClassroomService.editComment(comment.id, newContent);
      if (mounted) {
        await provider.loadComments(widget.materialId, refresh: true);
      }
    }
  }

  void _openSubmission() {
    if (_assignmentId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Loading assignment details...'), backgroundColor: Colors.orange),
      );
      return;
    }

    final assignmentMaterial = ClassroomMaterial(
      id: _assignmentId!,
      headLine: widget.material.headLine,
      description: widget.material.description,
      materialType: widget.material.materialType,
      materialUrls: widget.material.materialUrls,
      commentsCount: widget.material.commentsCount,
      createdAt: widget.material.createdAt,
      updatedAt: widget.material.updatedAt,
      createdBy: widget.material.createdBy,
      updatedBy: widget.material.updatedBy,
      dueDate: widget.material.dueDate,
    );

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => SubmissionScreen(assignment: assignmentMaterial),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final authProvider = context.watch<AuthProvider>();
    final provider = context.watch<ClassroomProvider>();
    final isOwner = widget.material.createdBy == authProvider.userEmail;
    final isAssignment = widget.material.materialType == ClassroomMaterialType.assignment;
    final isPastDue = widget.material.dueDate != null && DateTime.now().isAfter(widget.material.dueDate!);

    return Scaffold(
      backgroundColor: _lightBg,
      appBar: AppBar(
        title: Text(
          widget.material.headLine,
          style: const TextStyle(fontSize: 18, color: Colors.black87),
        ),
        backgroundColor: Colors.white,
        elevation: 0,
        foregroundColor: Colors.black87,
        centerTitle: false,
        actions: [
          if (widget.isInstructor || isOwner)
            PopupMenuButton<String>(
              onSelected: (value) {
                if (value == 'delete') {
                  _showDeleteDialog();
                }
              },
              itemBuilder: (context) => const [
                PopupMenuItem(
                  value: 'delete',
                  child: Text('Delete', style: TextStyle(color: Colors.red)),
                ),
              ],
            ),
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
                  // Header
                  Row(
                    children: [
                      CircleAvatar(
                        backgroundColor: _lime,
                        child: Text(
                          widget.material.authorName[0].toUpperCase(),
                          style: const TextStyle(color: Colors.black),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              widget.material.authorName,
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                color: Colors.black87,
                              ),
                            ),
                            Row(
                              children: [
                                Text(
                                  _formatDate(widget.material.createdAt),
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: Colors.grey.shade500,
                                  ),
                                ),
                                if (widget.material.isEdited)
                                  Text(
                                    ' (edited)',
                                    style: TextStyle(
                                      fontSize: 11,
                                      color: Colors.grey.shade400,
                                    ),
                                  ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: _lime.withOpacity(0.15),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          widget.material.materialType.displayName,
                          style: const TextStyle(
                            fontSize: 12,
                            color: Colors.black,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // Title
                  Text(
                    widget.material.headLine,
                    style: const TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      color: Colors.black87,
                    ),
                  ),
                  const SizedBox(height: 12),

                  // Due Date for Assignments
                  if (isAssignment && widget.material.dueDate != null)
                    Container(
                      margin: const EdgeInsets.only(bottom: 16),
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      decoration: BoxDecoration(
                        color: isPastDue ? Colors.red.shade50 : _lime.withOpacity(0.15),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: isPastDue ? Colors.red.shade200 : _lime.withOpacity(0.3),
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.calendar_today,
                            size: 16,
                            color: isPastDue ? Colors.red : Colors.black,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            'Due: ${_formatDate(widget.material.dueDate!)}',
                            style: TextStyle(
                              color: isPastDue ? Colors.red : Colors.black87,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          if (isPastDue) ...[
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: Colors.red,
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: const Text(
                                'Passed',
                                style: TextStyle(
                                  fontSize: 10,
                                  color: Colors.white,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),

                  // Description
                  Text(
                    widget.material.description,
                    style: const TextStyle(fontSize: 16, height: 1.5, color: Colors.black87),
                  ),
                  const SizedBox(height: 16),

                  // Attachments
                  if (widget.material.materialUrls.isNotEmpty) ...[
                    const Text(
                      'Attachments',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Colors.black87,
                      ),
                    ),
                    const SizedBox(height: 12),
                    ...widget.material.materialUrls.map((url) => GestureDetector(
                      onTap: () => _openUrl(url),
                      child: Container(
                        margin: const EdgeInsets.only(bottom: 12),
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: _lime.withOpacity(0.08),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: _lime.withOpacity(0.3)),
                        ),
                        child: Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: _getFileIconColor(url),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Icon(
                                _getFileIcon(url),
                                size: 20,
                                color: Colors.white,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    _getFileName(url),
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w600,
                                      fontSize: 14,
                                      color: Colors.black87,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    _getFileType(url),
                                    style: TextStyle(
                                      fontSize: 11,
                                      color: Colors.grey.shade500,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            Icon(
                              Icons.open_in_new,
                              size: 18,
                              color: Colors.black,
                            ),
                          ],
                        ),
                      ),
                    )),
                  ],

                  // EXPLAIN WITH LUMOS AI BUTTON - Lime not gradient
                  const SizedBox(height: 24),
                  SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: ElevatedButton(
                      onPressed: _explainWithAI,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _lime,
                        foregroundColor: Colors.black,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        elevation: 2,
                        shadowColor: _lime.withOpacity(0.3),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: const [
                          Icon(Icons.auto_awesome, color: Colors.black, size: 20),
                          SizedBox(width: 12),
                          Text(
                            'Explain with Lumos AI',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                              color: Colors.black,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                  // Submit Assignment Button - Lime not gradient
                  if (isAssignment && !widget.isInstructor && _assignmentId != null && !isPastDue) ...[
                    const SizedBox(height: 16),
                    SizedBox(
                      width: double.infinity,
                      height: 50,
                      child: ElevatedButton(
                        onPressed: _openSubmission,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: _lime,
                          foregroundColor: Colors.black,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          elevation: 2,
                          shadowColor: _lime.withOpacity(0.3),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: const [
                            Icon(Icons.upload_file, color: Colors.black, size: 20),
                            SizedBox(width: 12),
                            Text(
                              'Submit Assignment',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                                color: Colors.black,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],

                  // Past Due Message
                  if (isAssignment && !widget.isInstructor && isPastDue) ...[
                    const SizedBox(height: 24),
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.red.shade50,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.red.shade200),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.warning_amber_rounded, color: Colors.red.shade700, size: 24),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Assignment Deadline Passed',
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    color: Colors.red.shade700,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  'This assignment is no longer accepting submissions. Please contact your instructor for assistance.',
                                  style: TextStyle(
                                    fontSize: 13,
                                    color: Colors.red.shade700,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],

                  if (isAssignment && !widget.isInstructor && _isLoadingAssignment) ...[
                    const SizedBox(height: 24),
                    const Center(child: CircularProgressIndicator()),
                  ],

                  const Divider(height: 32, color: Colors.grey),

                  // Comments Section
                  Row(
                    children: [
                      Container(
                        width: 4,
                        height: 20,
                        decoration: BoxDecoration(
                          color: _lime,
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Text(
                        'Comments (${provider.comments.length})',
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Colors.black87,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  if (provider.isLoading && provider.comments.isEmpty)
                    const Center(child: CircularProgressIndicator()),
                  if (provider.comments.isEmpty && !provider.isLoading)
                    Center(
                      child: Padding(
                        padding: const EdgeInsets.all(32),
                        child: Column(
                          children: [
                            Icon(Icons.chat_bubble_outline, size: 48, color: Colors.black),
                            const SizedBox(height: 12),
                            Text(
                              'No comments yet. Be the first!',
                              style: TextStyle(color: Colors.grey.shade600),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ...provider.comments.map((comment) => _buildCommentCard(comment, authProvider)),
                  if (provider.isLoadingMore)
                    const Padding(
                      padding: EdgeInsets.all(16),
                      child: Center(child: CircularProgressIndicator()),
                    ),
                ],
              ),
            ),
          ),
          _buildCommentInput(),
        ],
      ),
    );
  }

  Widget _buildCommentCard(ClassroomComment comment, AuthProvider authProvider) {
    final isOwner = comment.createdBy == authProvider.userEmail;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 0,
      color: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: _lime.withOpacity(0.3)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            CircleAvatar(
              radius: 16,
              backgroundColor: _lime.withOpacity(0.2),
              child: Text(
                comment.authorName[0].toUpperCase(),
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: Colors.black,
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        comment.authorName,
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                          color: Colors.black87,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        _formatDate(comment.createdAt),
                        style: TextStyle(
                          fontSize: 11,
                          color: Colors.grey.shade500,
                        ),
                      ),
                      if (comment.isEdited)
                        Text(
                          ' • edited',
                          style: TextStyle(
                            fontSize: 11,
                            color: Colors.grey.shade400,
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    comment.content,
                    style: const TextStyle(fontSize: 14, color: Colors.black87),
                  ),
                  if (isOwner || widget.isInstructor)
                    Row(
                      children: [
                        if (isOwner)
                          TextButton(
                            onPressed: () => _editComment(comment),
                            child: Text('Edit', style: TextStyle(color: Colors.black)),
                          ),
                        TextButton(
                          onPressed: () => _deleteComment(comment),
                          child: const Text('Delete', style: TextStyle(color: Colors.red)),
                        ),
                      ],
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCommentInput() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.1),
            spreadRadius: 1,
            blurRadius: 8,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: _commentController,
              style: const TextStyle(color: Colors.black87),
              decoration: InputDecoration(
                hintText: 'Add class comment...',
                hintStyle: TextStyle(color: Colors.grey.shade500),
                filled: true,
                fillColor: _lightBg,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(24),
                  borderSide: BorderSide.none,
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(24),
                  borderSide: BorderSide(color: _lime, width: 1.5),
                ),
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              ),
              maxLines: 3,
              minLines: 1,
            ),
          ),
          const SizedBox(width: 8),
          _isSubmitting
              ? const SizedBox(
            width: 24,
            height: 24,
            child: CircularProgressIndicator(strokeWidth: 2),
          )
              : Container(
            decoration: BoxDecoration(
              color: _lime,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: _lime.withOpacity(0.3),
                  blurRadius: 4,
                ),
              ],
            ),
            child: IconButton(
              icon: const Icon(Icons.send, color: Colors.black),
              onPressed: _submitComment,
            ),
          ),
        ],
      ),
    );
  }

  void _showDeleteDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Delete Material', style: TextStyle(color: Colors.black87)),
        content: const Text(
          'Are you sure you want to delete this material? This action cannot be undone.',
          style: TextStyle(color: Colors.grey),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel', style: TextStyle(color: Colors.grey)),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Material deleted'), backgroundColor: Colors.red),
              );
            },
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }
}