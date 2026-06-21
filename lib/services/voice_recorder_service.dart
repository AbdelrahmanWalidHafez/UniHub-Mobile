import 'dart:io';
import 'package:record/record.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as path;

class VoiceRecorderService {
  static final AudioRecorder _recorder = AudioRecorder();
  static String? _currentRecordingPath;

  static Future<bool> get isRecording async {
    return await _recorder.isRecording();
  }

  static Future<bool> startRecording() async {
    try {
      if (await _recorder.hasPermission()) {
        final directory = await getTemporaryDirectory();
        final timestamp = DateTime.now().millisecondsSinceEpoch;
        _currentRecordingPath = path.join(directory.path, 'voice_$timestamp.m4a');

        await _recorder.start(
          const RecordConfig(
            encoder: AudioEncoder.aacLc,
            sampleRate: 44100,
            bitRate: 64000,
          ),
          path: _currentRecordingPath!,
        );
        return true;
      }
      return false;
    } catch (e) {
      print('Start recording error: $e');
      return false;
    }
  }

  static Future<File?> stopRecording() async {
    try {
      final path = await _recorder.stop();
      if (path != null && _currentRecordingPath != null) {
        return File(_currentRecordingPath!);
      }
      return null;
    } catch (e) {
      print('Stop recording error: $e');
      return null;
    } finally {
      _currentRecordingPath = null;
    }
  }

  static Future<void> cancelRecording() async {
    try {
      await _recorder.cancel();
      if (_currentRecordingPath != null) {
        final file = File(_currentRecordingPath!);
        if (await file.exists()) {
          await file.delete();
        }
      }
    } catch (e) {
      print('Cancel recording error: $e');
    } finally {
      _currentRecordingPath = null;
    }
  }

  static Future<int> getAmplitude() async {
    try {
      final amplitude = await _recorder.getAmplitude();
      return amplitude.current.toInt();
    } catch (e) {
      return 0;
    }
  }
}