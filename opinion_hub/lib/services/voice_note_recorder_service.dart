import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:record/record.dart';

class VoiceNoteRecorderService {
  final AudioRecorder _recorder = AudioRecorder();

  Future<bool> get isRecording => _recorder.isRecording();

  Future<void> startRecording() async {
    if (await _recorder.isRecording()) {
      throw StateError('A recording is already in progress.');
    }

    final hasPermission = await _recorder.hasPermission();

    if (!hasPermission) {
      throw StateError('Microphone permission was denied.');
    }

    final String path;
    final RecordConfig config;

    if (kIsWeb) {
      path = 'opinionhub_voice_${DateTime.now().millisecondsSinceEpoch}.wav';

      config = const RecordConfig(
        encoder: AudioEncoder.wav,
        sampleRate: 16000,
        numChannels: 1,
      );
    } else {
      final directory = await getTemporaryDirectory();

      path =
          '${directory.path}/opinionhub_voice_${DateTime.now().millisecondsSinceEpoch}.m4a';

      config = const RecordConfig(
        encoder: AudioEncoder.aacLc,
        bitRate: 64000,
        sampleRate: 44100,
        numChannels: 1,
      );
    }

    await _recorder.start(config, path: path);
  }

  Future<String?> stopRecording() async {
    return _recorder.stop();
  }

  Future<void> cancelRecording() async {
    await _recorder.cancel();
  }

  Future<void> dispose() async {
    await _recorder.dispose();
  }
}
