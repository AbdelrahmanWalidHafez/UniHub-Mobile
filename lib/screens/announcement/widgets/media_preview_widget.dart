import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

class MediaPreviewWidget extends StatelessWidget {
  final String url;
  final double? height;
  final bool showDownloadButton;
  final VoidCallback? onTap;

  const MediaPreviewWidget({
    super.key,
    required this.url,
    this.height,
    this.showDownloadButton = false,
    this.onTap,
  });

  String _getFileExtension(String url) {
    try {
      final parts = url.split('.');
      return parts.last.toLowerCase();
    } catch (e) {
      return '';
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
    final ext = _getFileExtension(url);
    switch (ext) {
      case 'pdf':
        return 'PDF Document';
      case 'jpg':
      case 'jpeg':
        return 'JPEG Image';
      case 'png':
        return 'PNG Image';
      case 'gif':
        return 'GIF Image';
      case 'mp4':
      case 'mov':
      case 'avi':
        return 'Video';
      case 'mp3':
      case 'wav':
        return 'Audio';
      default:
        return 'File';
    }
  }

  IconData _getFileIcon(String url) {
    final ext = _getFileExtension(url);
    switch (ext) {
      case 'pdf':
        return Icons.picture_as_pdf;
      case 'jpg':
      case 'jpeg':
      case 'png':
      case 'gif':
        return Icons.image;
      case 'mp4':
      case 'mov':
      case 'avi':
        return Icons.video_library;
      case 'mp3':
      case 'wav':
        return Icons.audio_file;
      default:
        return Icons.insert_drive_file;
    }
  }

  Color _getFileIconColor(String url) {
    final ext = _getFileExtension(url);
    switch (ext) {
      case 'pdf':
        return Colors.red;
      case 'jpg':
      case 'jpeg':
      case 'png':
      case 'gif':
        return Colors.green;
      case 'mp4':
      case 'mov':
      case 'avi':
        return Colors.blue;
      case 'mp3':
      case 'wav':
        return Colors.purple;
      default:
        return Colors.grey;
    }
  }

  bool _isImage(String url) {
    final ext = _getFileExtension(url);
    return ['jpg', 'jpeg', 'png', 'gif', 'webp', 'bmp'].contains(ext);
  }

  bool _isVideo(String url) {
    final ext = _getFileExtension(url);
    return ['mp4', 'mov', 'avi', 'mkv', 'webm'].contains(ext);
  }

  bool _isPdf(String url) {
    return _getFileExtension(url) == 'pdf';
  }

  Future<void> _openFile() async {
    String fullUrl = url;
    if (!url.startsWith('http')) {
      const baseUrl = 'http://34.58.11.82:8082';
      fullUrl = url.startsWith('/') ? '$baseUrl$url' : '$baseUrl/$url';
    }

    final uri = Uri.parse(fullUrl);

    try {
      if (await canLaunchUrl(uri)) {
        if (_isVideo(url)) {
          await launchUrl(
            uri,
            mode: LaunchMode.inAppWebView,
            webViewConfiguration: const WebViewConfiguration(
              enableJavaScript: true,
              enableDomStorage: true,
            ),
          );
        } else {
          await launchUrl(
            uri,
            mode: LaunchMode.platformDefault,
          );
        }
      }
    } catch (e) {
      debugPrint('Error opening file: $e');
      try {
        await launchUrl(
          uri,
          mode: LaunchMode.platformDefault,
        );
      } catch (_) {}
    }
  }

  void _showFullScreenImage(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ImageViewer(imageUrl: url),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isImage = _isImage(url);
    final isVideo = _isVideo(url);
    final isPdf = _isPdf(url);

    return GestureDetector(
      onTap: () {
        if (isImage) {
          _showFullScreenImage(context);
        } else if (onTap != null) {
          onTap!();
        } else {
          _openFile();
        }
      },
      child: Container(
        width: double.infinity,
        height: height ?? 250,
        decoration: BoxDecoration(
          color: Colors.grey.shade100,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.grey.shade200),
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: Stack(
            fit: StackFit.expand,
            children: [
              // Content based on file type
              if (isImage)
                Image.network(
                  url,
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => _buildFallbackContent(),
                )
              else if (isVideo)
                _buildVideoPlaceholder()
              else if (isPdf)
                  _buildPdfPlaceholder()
                else
                  _buildFallbackContent(),

              // REMOVED: Bottom bar with file info - completely removed

              // Tap overlay for non-images (videos, PDFs, etc.)
              if (!isImage)
                Positioned.fill(
                  child: Material(
                    color: Colors.transparent,
                    child: InkWell(
                      onTap: onTap ?? _openFile,
                      borderRadius: BorderRadius.circular(16),
                      child: Container(),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildVideoPlaceholder() {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Colors.grey.shade900,
            Colors.grey.shade700,
            Colors.blue.shade300,
          ],
        ),
      ),
      child: const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.play_circle_filled,
              size: 60,
              color: Colors.white,
            ),
            SizedBox(height: 8),
            Text(
              'Tap to play video',
              style: TextStyle(
                color: Colors.white70,
                fontSize: 14,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPdfPlaceholder() {
    return Container(
      color: Colors.grey.shade200,
      child: const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.picture_as_pdf,
              size: 60,
              color: Colors.red,
            ),
            SizedBox(height: 8),
            Text(
              'PDF Document',
              style: TextStyle(color: Colors.grey),
            ),
            SizedBox(height: 4),
            Text(
              'Tap to open',
              style: TextStyle(
                color: Colors.grey,
                fontSize: 12,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFallbackContent() {
    return Container(
      color: Colors.grey.shade100,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            _getFileIcon(url),
            size: 40,
            color: _getFileIconColor(url),
          ),
          const SizedBox(height: 8),
          Text(
            _getFileType(url),
            style: TextStyle(color: Colors.grey.shade600),
          ),
        ],
      ),
    );
  }
}

// Image Viewer for full-screen image preview with zoom
class ImageViewer extends StatelessWidget {
  final String imageUrl;

  const ImageViewer({super.key, required this.imageUrl});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          Center(
            child: InteractiveViewer(
              minScale: 0.5,
              maxScale: 3.0,
              child: Image.network(
                imageUrl,
                fit: BoxFit.contain,
                errorBuilder: (_, __, ___) => const Icon(
                  Icons.broken_image,
                  size: 80,
                  color: Colors.grey,
                ),
              ),
            ),
          ),
          Positioned(
            top: 40,
            right: 20,
            child: IconButton(
              icon: const Icon(Icons.close, color: Colors.white, size: 30),
              onPressed: () => Navigator.pop(context),
            ),
          ),
        ],
      ),
    );
  }
}