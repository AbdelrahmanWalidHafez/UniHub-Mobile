import 'dart:io';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:provider/provider.dart';
import '../../models/classroom/material_model.dart';
import '../../models/classroom/submission_model.dart';
import '../../services/classroom_service.dart';

class SubmissionScreen extends StatefulWidget {
  final ClassroomMaterial assignment;

  const SubmissionScreen({super.key, required this.assignment});

  @override
  State<SubmissionScreen> createState() => _SubmissionScreenState();
}

class _SubmissionScreenState extends State<SubmissionScreen> {
  Submission? _submission;
  List<File> _selectedFiles = [];
  List<String> _filesToDelete = [];
  bool _isLoading = true;
  bool _isSubmitting = false;
  String? _submissionError;

  static const Color _lime = Color(0xFFB9FF66);
  static const Color _lightBg = Color(0xFFF8FAFB);

  @override
  void initState() {
    super.initState();
    _loadSubmission();
  }

  Future<void> _loadSubmission() async {
    try {
      final submission = await ClassroomService.getStudentSubmission(widget.assignment.id);
      setState(() {
        _submission = submission;
        _isLoading = false;
      });
    } catch (e) {
      print('No existing submission: $e');
      setState(() {
        _submission = null;
        _isLoading = false;
      });
    }
  }

  Future<void> _pickFiles() async {
    FilePickerResult? result = await FilePicker.platform.pickFiles(
      allowMultiple: true,
    );
    if (result != null) {
      setState(() {
        _selectedFiles = result.paths.map((path) => File(path!)).toList();
        _submissionError = null;
      });
    }
  }

  void _removeSelectedFile(int index) {
    setState(() {
      _selectedFiles.removeAt(index);
    });
  }

  void _markFileForDeletion(String url) {
    setState(() {
      _filesToDelete.add(url);
    });
  }

  void _undoFileDeletion(String url) {
    setState(() {
      _filesToDelete.remove(url);
    });
  }

  Future<void> _submitWork() async {
    if (_selectedFiles.isEmpty && _submission == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select at least one file'), backgroundColor: Colors.orange),
      );
      return;
    }

    setState(() {
      _isSubmitting = true;
      _submissionError = null;
    });

    try {
      print('=== SUBMITTING WORK ===');
      print('Assignment ID: ${widget.assignment.id}');
      print('Files: ${_selectedFiles.length}');
      print('Has existing submission: ${_submission != null}');

      if (_submission != null) {
        await ClassroomService.editSubmission(
          _submission!.id,
          _selectedFiles,
          _filesToDelete,
        );
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Submission updated!'), backgroundColor: Colors.green),
          );
        }
      } else {
        await ClassroomService.submitAssignment(widget.assignment.id, _selectedFiles);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Assignment submitted!'), backgroundColor: Colors.green),
          );
        }
      }
      await _loadSubmission();
      setState(() {
        _selectedFiles = [];
        _filesToDelete = [];
      });
    } catch (e) {
      print('Submission error: $e');
      final errorMsg = e.toString();

      if (errorMsg.contains('409') || errorMsg.contains('deadline') || errorMsg.contains('passed')) {
        setState(() {
          _submissionError = 'This assignment deadline has passed. Submissions are no longer accepted.';
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Assignment deadline has passed. Cannot submit.'),
            backgroundColor: Colors.red,
          ),
        );
      } else {
        setState(() {
          _submissionError = 'Failed to submit: ${errorMsg.replaceFirst('Exception: ', '')}';
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to submit: ${errorMsg.replaceFirst('Exception: ', '')}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isSubmitting = false);
      }
    }
  }

  Future<void> _unsubmit() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Unsubmit Assignment', style: TextStyle(color: Colors.black87)),
        content: const Text('Are you sure you want to unsubmit? Your work will be removed.', style: TextStyle(color: Colors.grey)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel', style: TextStyle(color: Colors.grey)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Unsubmit'),
          ),
        ],
      ),
    );

    if (confirmed == true && _submission != null) {
      setState(() => _isSubmitting = true);
      try {
        await ClassroomService.deleteSubmission(_submission!.id);
        await _loadSubmission();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Submission removed'), backgroundColor: Colors.orange),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Failed to unsubmit: $e'), backgroundColor: Colors.red),
          );
        }
      } finally {
        if (mounted) {
          setState(() => _isSubmitting = false);
        }
      }
    }
  }

  bool get isPastDue {
    if (widget.assignment.dueDate == null) return false;
    return DateTime.now().isAfter(widget.assignment.dueDate!);
  }

  @override
  Widget build(BuildContext context) {
    final isPastDueDate = isPastDue;

    return Scaffold(
      backgroundColor: _lightBg,
      appBar: AppBar(
        title: const Text('Assignment Submission', style: TextStyle(color: Colors.black87)),
        backgroundColor: Colors.white,
        elevation: 0,
        foregroundColor: Colors.black87,
        centerTitle: false,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Assignment Info Card
            Card(
              elevation: 0,
              color: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
                side: BorderSide(color: _lime.withOpacity(0.3), width: 1.5),
              ),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.assignment.headLine,
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: Colors.black87,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      widget.assignment.description,
                      style: TextStyle(color: Colors.grey.shade700),
                    ),
                    const SizedBox(height: 12),
                    if (widget.assignment.dueDate != null)
                      Row(
                        children: [
                          Icon(Icons.calendar_today, size: 16, color: isPastDueDate ? Colors.red : _lime),
                          const SizedBox(width: 8),
                          Text(
                            'Due: ${_formatDate(widget.assignment.dueDate!)}',
                            style: TextStyle(
                              color: isPastDueDate ? Colors.red : _lime,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                  ],
                ),
              ),
            ),

            // Deadline Passed Warning
            if (isPastDueDate) ...[
              const SizedBox(height: 16),
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

            const SizedBox(height: 24),

            // Grade Display
            if (_submission != null && _submission!.grade != -1)
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: _submission!.gradeColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: _submission!.gradeColor.withOpacity(0.3)),
                ),
                child: Row(
                  children: [
                    Icon(Icons.grade, size: 32, color: _submission!.gradeColor),
                    const SizedBox(width: 16),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Your Grade', style: TextStyle(fontSize: 12, color: Colors.grey)),
                        Text(
                          _submission!.gradeDisplay,
                          style: TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                            color: _submission!.gradeColor,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),

            const SizedBox(height: 24),

            // Submitted Files
            if (_submission != null && _submission!.submissionUrls.isNotEmpty)
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Submitted Files',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.black87),
                  ),
                  const SizedBox(height: 12),
                  ..._submission!.submissionUrls
                      .where((url) => !_filesToDelete.contains(url))
                      .map((url) => _buildFileCard(url, isExisting: true, url: url)),
                  if (_filesToDelete.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: Text(
                        '${_filesToDelete.length} file(s) marked for removal',
                        style: TextStyle(color: Colors.red.shade400, fontSize: 12),
                      ),
                    ),
                ],
              ),

            const SizedBox(height: 24),

            // New Files to Submit
            if (_selectedFiles.isNotEmpty)
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'New Files',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.black87),
                  ),
                  const SizedBox(height: 12),
                  ..._selectedFiles.asMap().entries.map((entry) {
                    final index = entry.key;
                    final file = entry.value;
                    return _buildFileCard(file.path, onRemove: () => _removeSelectedFile(index));
                  }),
                ],
              ),

            const SizedBox(height: 24),

            // Error Message
            if (_submissionError != null)
              Container(
                margin: const EdgeInsets.only(bottom: 16),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.red.shade50,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    Icon(Icons.error_outline, color: Colors.red.shade700, size: 20),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        _submissionError!,
                        style: TextStyle(color: Colors.red.shade700, fontSize: 13),
                      ),
                    ),
                  ],
                ),
              ),

            // Add File Button - Lime Outlined Design
            if (!isPastDueDate)
              Center(
                child: OutlinedButton.icon(
                  onPressed: _pickFiles,
                  icon: Icon(Icons.attach_file, size: 20, color: _lime),
                  label: Text('Add Files', style: TextStyle(color: _lime)),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: _lime,
                    side: BorderSide(color: _lime, width: 1.5),
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(30),
                    ),
                  ),
                ),
              ),

            const SizedBox(height: 24),

            // Submit Button - Lime Gradient Design
            if (!isPastDueDate)
              Container(
                width: double.infinity,
                height: 55,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFFB9FF66), Color(0xFF8FE3D3)],
                    begin: Alignment.centerLeft,
                    end: Alignment.centerRight,
                  ),
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(
                      color: _lime.withOpacity(0.3),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: ElevatedButton(
                  onPressed: _isSubmitting ? null : _submitWork,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.transparent,
                    shadowColor: Colors.transparent,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: _isSubmitting
                      ? const SizedBox(
                    width: 24,
                    height: 24,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.black,
                    ),
                  )
                      : Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        _submission != null ? Icons.edit : Icons.upload_file,
                        color: Colors.black,
                        size: 22,
                      ),
                      const SizedBox(width: 12),
                      Text(
                        _submission != null ? 'Update Submission' : 'Submit Assignment',
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: Colors.black,
                        ),
                      ),
                    ],
                  ),
                ),
              ),

            if (!isPastDueDate && _submission != null)
              const SizedBox(height: 12),

            // Unsubmit Button - Red Outlined Design
            if (!isPastDueDate && _submission != null)
              SizedBox(
                width: double.infinity,
                height: 50,
                child: OutlinedButton.icon(
                  onPressed: _isSubmitting ? null : _unsubmit,
                  icon: const Icon(Icons.delete_outline, size: 20, color: Colors.red),
                  label: const Text('Unsubmit Assignment', style: TextStyle(color: Colors.red)),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.red,
                    side: const BorderSide(color: Colors.red),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildFileCard(String path, {bool isExisting = false, VoidCallback? onRemove, String? url}) {
    final fileName = path.split('/').last;
    final isPdf = path.toLowerCase().endsWith('.pdf');
    final isMarkedForDelete = url != null && _filesToDelete.contains(url);

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isMarkedForDelete ? Colors.red.shade50 : _lime.withOpacity(0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isMarkedForDelete ? Colors.red.shade300 : _lime.withOpacity(0.3),
          width: isMarkedForDelete ? 1.5 : 1,
        ),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: isPdf ? Colors.red.shade100 : _lime.withOpacity(0.15),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(
              isPdf ? Icons.picture_as_pdf : Icons.insert_drive_file,
              color: isPdf ? Colors.red : _lime,
              size: 20,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              fileName,
              style: const TextStyle(fontWeight: FontWeight.w500, color: Colors.black87),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          if (isExisting && url != null)
            if (isMarkedForDelete)
              TextButton.icon(
                onPressed: () => _undoFileDeletion(url),
                icon: const Icon(Icons.undo, size: 16, color: Colors.green),
                label: const Text('Undo', style: TextStyle(color: Colors.green)),
                style: TextButton.styleFrom(foregroundColor: Colors.green),
              )
            else
              IconButton(
                icon: const Icon(Icons.delete_outline, color: Colors.red, size: 20),
                onPressed: () => _markFileForDeletion(url),
              ),
          if (onRemove != null)
            IconButton(
              icon: const Icon(Icons.close, size: 20, color: Colors.grey),
              onPressed: onRemove,
            ),
        ],
      ),
    );
  }

  String _formatDate(DateTime date) {
    return '${date.day}/${date.month}/${date.year}';
  }
}