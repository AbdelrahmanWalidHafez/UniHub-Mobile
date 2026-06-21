import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import '../../../services/audio_player_service.dart';
import '../../../services/chat_service.dart';

class VoiceMessageWidget extends StatefulWidget {
  final String audioUrl;
  final String messageId;
  final int duration;
  final bool isMine;

  const VoiceMessageWidget({
    super.key,
    required this.audioUrl,
    required this.messageId,
    required this.duration,
    required this.isMine,
  });

  @override
  State<VoiceMessageWidget> createState() => _VoiceMessageWidgetState();
}

class _VoiceMessageWidgetState extends State<VoiceMessageWidget> {
  bool _isPlaying = false;
  double _progress = 0.0;
  Duration _currentPosition = Duration.zero;
  Duration _totalDuration = Duration.zero;
  bool _isLoading = true;
  bool _isDownloading = false;
  String? _localFilePath;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _totalDuration = Duration(seconds: widget.duration);
    _loadAudio();
    _setupListeners();
  }

  @override
  void dispose() {
    _isLoading = false;
    _isDownloading = false;
    super.dispose();
  }

  Future<void> _loadAudio() async {
    if (!mounted) return;

    setState(() {
      _isDownloading = true;
      _errorMessage = null;
    });

    try {
      final audioData = await ChatService.getVoiceMessage(widget.messageId);

      if (!mounted) return;

      if (audioData.isNotEmpty) {
        final tempDir = await getTemporaryDirectory();
        final filePath = '${tempDir.path}/voice_${widget.messageId}.ogg';
        final file = File(filePath);
        await file.writeAsBytes(audioData);

        if (!mounted) return;

        setState(() {
          _localFilePath = filePath;
          _isLoading = false;
          _isDownloading = false;
        });
      } else {
        if (!mounted) return;
        setState(() {
          _isLoading = false;
          _isDownloading = false;
          _errorMessage = 'No audio data received';
        });
      }
    } catch (e) {
      print('Error loading voice: $e');
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _isDownloading = false;
        _errorMessage = 'Failed to load voice message';
      });
    }
  }

  void _setupListeners() {
    AudioPlayerService.onPositionChanged = (position) {
      if (mounted) {
        setState(() {
          _currentPosition = position;
          if (_totalDuration.inMilliseconds > 0) {
            _progress = position.inMilliseconds / _totalDuration.inMilliseconds;
          }
        });
      }
    };

    AudioPlayerService.onComplete = () {
      if (mounted) {
        setState(() {
          _isPlaying = false;
          _progress = 0.0;
          _currentPosition = Duration.zero;
        });
      }
    };
  }

  Future<void> _togglePlay() async {
    if (_localFilePath == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Voice message not downloaded yet'),
          backgroundColor: Colors.orange,
          duration: Duration(seconds: 1),
        ),
      );
      return;
    }

    if (_isPlaying) {
      await AudioPlayerService.pause();
      if (mounted) setState(() => _isPlaying = false);
    } else {
      try {
        await AudioPlayerService.stop();
        await AudioPlayerService.play(_localFilePath!);
        if (mounted) setState(() => _isPlaying = true);
      } catch (e) {
        print('Error playing voice: $e');
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Error playing voice: $e'),
              backgroundColor: Colors.red,
              duration: const Duration(seconds: 1),
            ),
          );
        }
      }
    }
  }

  void _retryDownload() {
    _loadAudio();
  }

  String _formatDuration(Duration duration) {
    final minutes = duration.inMinutes;
    final seconds = (duration.inSeconds % 60).toString().padLeft(2, '0');
    return '$minutes:$seconds';
  }

  @override
  Widget build(BuildContext context) {
    if (_errorMessage != null) {
      return SizedBox(
        width: 200,
        child: Row(
          children: [
            GestureDetector(
              onTap: _retryDownload,
              child: Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: widget.isMine ? Colors.white24 : Colors.red.withOpacity(0.2),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.refresh,
                  size: 18,
                  color: widget.isMine ? Colors.white70 : Colors.red,
                ),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                _errorMessage!,
                style: TextStyle(
                  fontSize: 11,
                  color: widget.isMine ? Colors.white70 : Colors.red,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      );
    }

    if (_isLoading || _isDownloading) {
      return SizedBox(
        width: 200,
        child: Row(
          children: [
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: widget.isMine ? Colors.white24 : const Color(0xFF0077B3).withOpacity(0.2),
                shape: BoxShape.circle,
              ),
              child: const Center(
                child: SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                _isDownloading ? 'Downloading...' : 'Loading...',
                style: TextStyle(
                  fontSize: 11,
                  color: widget.isMine ? Colors.white70 : Colors.grey.shade600,
                ),
              ),
            ),
          ],
        ),
      );
    }

    return SizedBox(
      width: 200,
      child: Row(
        children: [
          GestureDetector(
            onTap: _togglePlay,
            child: Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: widget.isMine ? Colors.white24 : const Color(0xFF0077B3).withOpacity(0.2),
                shape: BoxShape.circle,
              ),
              child: Icon(
                _isPlaying ? Icons.pause : Icons.play_arrow,
                color: widget.isMine ? Colors.white : const Color(0xFF0077B3),
                size: 18,
              ),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              children: [
                LinearProgressIndicator(
                  value: _progress.clamp(0.0, 1.0),
                  backgroundColor: widget.isMine ? Colors.white30 : Colors.grey.shade200,
                  color: widget.isMine ? Colors.white : const Color(0xFF0077B3),
                ),
                const SizedBox(height: 4),
                Text(
                  '${_formatDuration(_currentPosition)} / ${_formatDuration(_totalDuration)}',
                  style: TextStyle(
                    fontSize: 10,
                    color: widget.isMine ? Colors.white70 : Colors.grey.shade600,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}