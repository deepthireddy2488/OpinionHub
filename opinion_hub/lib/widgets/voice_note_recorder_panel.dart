import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:just_audio/just_audio.dart';

import '../services/voice_note_recorder_service.dart';

class VoiceNoteRecorderPanel extends StatefulWidget {
  final ValueChanged<String> onRecordingReady;

  const VoiceNoteRecorderPanel({super.key, required this.onRecordingReady});

  @override
  State<VoiceNoteRecorderPanel> createState() => _VoiceNoteRecorderPanelState();
}

class _VoiceNoteRecorderPanelState extends State<VoiceNoteRecorderPanel> {
  static const int _maxDurationSeconds = 300;

  final VoiceNoteRecorderService _recorder = VoiceNoteRecorderService();

  final AudioPlayer _player = AudioPlayer();

  StreamSubscription<PlayerState>? _playerSubscription;
  Timer? _timer;

  bool _isRecording = false;
  bool _isBusy = false;
  bool _isPlaying = false;

  String? _recordingPath;
  String? _errorMessage;

  Duration _elapsed = Duration.zero;

  @override
  void initState() {
    super.initState();

    _playerSubscription = _player.playerStateStream.listen((state) {
      if (!mounted) return;

      setState(() {
        _isPlaying = state.playing;
      });
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    _playerSubscription?.cancel();

    if (_isRecording) {
      unawaited(_cancelAndDisposeRecorder());
    } else {
      unawaited(_disposeRecorder());
    }

    unawaited(_player.dispose());

    super.dispose();
  }

  Future<void> _cancelAndDisposeRecorder() async {
    try {
      if (await _recorder.isRecording) {
        await _recorder.cancelRecording();
      }
    } catch (_) {
      // The recorder may already have stopped.
    }

    await _disposeRecorder();
  }

  Future<void> _disposeRecorder() async {
    try {
      await _recorder.dispose();
    } catch (_) {
      // Ignore errors while disposing resources.
    }
  }

  String _formatDuration(Duration duration) {
    final minutes = duration.inMinutes.toString().padLeft(2, '0');

    final seconds = (duration.inSeconds % 60).toString().padLeft(2, '0');

    return '$minutes:$seconds';
  }

  void _startTimer() {
    _timer?.cancel();

    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted || !_isRecording) return;

      if (_elapsed.inSeconds >= _maxDurationSeconds - 1) {
        setState(() {
          _elapsed = const Duration(seconds: _maxDurationSeconds);
        });

        unawaited(_stopRecording());
        return;
      }

      setState(() {
        _elapsed += const Duration(seconds: 1);
      });
    });
  }

  Future<void> _startRecording() async {
    if (_isBusy || _isRecording) return;

    _timer?.cancel();

    setState(() {
      _isBusy = true;
      _errorMessage = null;
      _recordingPath = null;
      _elapsed = Duration.zero;
    });

    try {
      await _player.stop();
      await _recorder.startRecording();

      if (!mounted) return;

      setState(() {
        _isRecording = true;
        _isPlaying = false;
      });

      _startTimer();
    } catch (_) {
      if (mounted) {
        setState(() {
          _errorMessage = 'Could not start recording. Check microphone permission and try again.';
        });
      }
    } finally {
      if (mounted) {
        setState(() {
          _isBusy = false;
        });
      }
    }
  }

  Future<void> _stopRecording() async {
    if (_isBusy || !_isRecording) return;

    _timer?.cancel();
    _timer = null;

    setState(() {
      _isBusy = true;
      _errorMessage = null;
    });

    try {
      final path = await _recorder.stopRecording();

      if (!mounted) return;

      setState(() {
        _isRecording = false;
      });

      if (path == null || path.trim().isEmpty) {
        throw StateError('No audio file was produced.');
      }

      if (kIsWeb) {
        await _player.setUrl(path);
      } else {
        await _player.setFilePath(path);
      }

      if (!mounted) return;

      setState(() {
        _recordingPath = path;
        _isPlaying = false;
      });
    } catch (_) {
      if (!mounted) return;

      setState(() {
        _isRecording = false;
        _errorMessage =
            'Could not finish or load the recording. Please try again.';
      });
    } finally {
      if (mounted) {
        setState(() {
          _isBusy = false;
        });
      }
    }
  }

  Future<void> _togglePlayback() async {
    if (_recordingPath == null || _isBusy) return;

    try {
      if (_player.playing) {
        await _player.pause();
      } else {
        if (_player.processingState == ProcessingState.completed) {
          await _player.seek(Duration.zero);
        }

        unawaited(_player.play());
      }
    } catch (_) {
      if (!mounted) return;

      setState(() {
        _errorMessage = 'Unable to play this recording.';
      });
    }
  }

  Future<void> _retakeRecording() async {
    if (_isBusy || _isRecording) return;

    setState(() {
      _isBusy = true;
      _errorMessage = null;
    });

    try {
      await _player.stop();

      if (!mounted) return;

      setState(() {
        _recordingPath = null;
        _isPlaying = false;
        _elapsed = Duration.zero;
      });
    } catch (_) {
      if (mounted) {
        setState(() {
          _errorMessage = 'Unable to reset the recording.';
        });
      }
    } finally {
      if (mounted) {
        setState(() {
          _isBusy = false;
        });
      }
    }
  }

  void _useRecording() {
    final path = _recordingPath;

    if (path == null || _isBusy || _isRecording) {
      return;
    }

    widget.onRecordingReady(path);
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    return Card(
      elevation: 0,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.mic_none_rounded, color: colors.primary, size: 26),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Voice Note',
                    style: Theme.of(context).textTheme.titleMedium
                        ?.copyWith(fontWeight: FontWeight.w700),
                  ),
                ),
                if (_isRecording)
                  Text(
                    _formatDuration(_elapsed),
                    style: TextStyle(
                      color: colors.error,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 14),
            if (_isRecording)
              FilledButton.icon(
                onPressed: _isBusy ? null : _stopRecording,
                icon: const Icon(Icons.stop_rounded),
                label: const Text('Stop Recording'),
              )
            else if (_recordingPath == null)
              FilledButton.icon(
                onPressed: _isBusy ? null : _startRecording,
                icon: const Icon(Icons.mic_rounded),
                label: const Text('Start Recording'),
              )
            else
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  OutlinedButton.icon(
                    onPressed: _isBusy ? null : _togglePlayback,
                    icon: Icon(
                      _isPlaying
                          ? Icons.pause_rounded
                          : Icons.play_arrow_rounded,
                    ),
                    label: Text(_isPlaying ? 'Pause' : 'Preview'),
                  ),
                  OutlinedButton.icon(
                    onPressed: _isBusy ? null : _retakeRecording,
                    icon: const Icon(Icons.refresh_rounded),
                    label: const Text('Retake'),
                  ),
                  FilledButton.icon(
                    onPressed: _isBusy ? null : _useRecording,
                    icon: const Icon(Icons.check_rounded),
                    label: const Text('Use Recording'),
                  ),
                ],
              ),
            if (_isBusy) ...[
              const SizedBox(height: 12),
              const LinearProgressIndicator(),
            ],
            if (_isRecording) ...[
              const SizedBox(height: 10),
              const Text(
                'Recording in progress. Tap Stop when finished. Maximum duration: 5 minutes.',
              ),
            ],
            if (_recordingPath != null && !_isRecording) ...[
              const SizedBox(height: 10),
              const Text('Recording ready. Preview it before using it.'),
            ],
            if (_errorMessage != null) ...[
              const SizedBox(height: 10),
              Text(_errorMessage!, style: TextStyle(color: colors.error)),
            ],
          ],
        ),
      ),
    );
  }
}
