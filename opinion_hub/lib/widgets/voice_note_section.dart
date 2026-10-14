import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:just_audio/just_audio.dart';

import '../core/constants/api_constants.dart';
import '../services/token_storage_service.dart';
import '../services/voice_note_recorder_service.dart';

class VoiceNoteSection extends StatefulWidget {
  final String targetType;
  final int targetId;

  const VoiceNoteSection({
    super.key,
    required this.targetType,
    required this.targetId,
  });

  @override
  State<VoiceNoteSection> createState() => _VoiceNoteSectionState();
}

class _VoiceNoteSectionState extends State<VoiceNoteSection> {
  final TokenStorageService _tokenStorage = TokenStorageService();

  VoiceNoteRecorderService? _recorder;
  AudioPlayer? _player;
  StreamSubscription<PlayerState>? _playerSubscription;
  Timer? _timer;

  List<Map<String, dynamic>> _notes = [];

  bool _hasLoaded = false;
  bool _isLoading = false;
  bool _isRecording = false;
  bool _isBusy = false;
  bool _isPlaying = false;

  int? _playingNoteId;
  String? _recordingPath;
  String? _errorMessage;

  Duration _elapsed = Duration.zero;

  String get _baseUrl => ApiConstants.baseUrl;

  @override
  void dispose() {
    _timer?.cancel();
    _playerSubscription?.cancel();

    final recorder = _recorder;
    if (recorder != null) {
      unawaited(_disposeRecorder(recorder));
    }

    final player = _player;
    if (player != null) {
      unawaited(player.dispose());
    }

    super.dispose();
  }

  Future<void> _disposeRecorder(VoiceNoteRecorderService recorder) async {
    try {
      if (await recorder.isRecording) {
        await recorder.cancelRecording();
      }
    } catch (_) {
      // The recorder may already have stopped.
    }

    try {
      await recorder.dispose();
    } catch (_) {
      // Nothing else to do during widget disposal.
    }
  }

  String _formatDuration(Duration duration) {
    final minutes = duration.inMinutes.toString().padLeft(2, '0');
    final seconds = (duration.inSeconds % 60).toString().padLeft(2, '0');

    return '$minutes:$seconds';
  }

  String _formatNoteDuration(dynamic value) {
    final seconds = value is num
        ? value.round()
        : int.tryParse(value?.toString() ?? '') ?? 0;

    return _formatDuration(Duration(seconds: seconds));
  }

  Future<String?> _getToken() async {
    final token = await _tokenStorage.getAccessToken();

    if (token == null || token.isEmpty) {
      throw Exception('Please sign in to use voice notes.');
    }

    return token;
  }

  Future<void> _handleExpansionChanged(bool expanded) async {
    if (!mounted) return;

    setState(() {
      _errorMessage = null;
    });

    if (expanded) {
      if (!_hasLoaded) {
        await _loadNotes();
      }
      return;
    }

    _timer?.cancel();
    _timer = null;

    if (_isRecording && _recorder != null) {
      try {
        await _recorder!.cancelRecording();
      } catch (_) {
        // The recording may already have stopped.
      }

      if (mounted) {
        setState(() {
          _isRecording = false;
          _isBusy = false;
          _elapsed = Duration.zero;
        });
      }
    }

    final player = _player;
    if (player != null) {
      try {
        await player.stop();
      } catch (_) {
        // Ignore stop errors while collapsing.
      }
    }

    if (mounted) {
      setState(() {
        _isPlaying = false;
        _playingNoteId = null;
      });
    }
  }

  Future<void> _loadNotes({bool forceRefresh = false}) async {
    if (_isLoading || (_hasLoaded && !forceRefresh)) {
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final token = await _getToken();

      final response = await http.get(
        Uri.parse(
          '$_baseUrl/voice-notes/target/'
          '${widget.targetType}/${widget.targetId}',
        ),
        headers: {
          'Accept': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );

      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw Exception(_readServerError(response.body));
      }

      final decoded = jsonDecode(response.body);

      final List<dynamic> items;

      if (decoded is List) {
        items = decoded;
      } else if (decoded is Map<String, dynamic> && decoded['data'] is List) {
        items = decoded['data'] as List<dynamic>;
      } else {
        items = const [];
      }

      final parsed = items
          .whereType<Map>()
          .map((item) => Map<String, dynamic>.from(item))
          .toList();

      if (!mounted) return;

      setState(() {
        _notes = parsed;
        _hasLoaded = true;
      });
    } catch (error) {
      if (!mounted) return;

      setState(() {
        _errorMessage = error.toString().replaceFirst('Exception: ', '');
      });
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  String _readServerError(String body) {
    try {
      final decoded = jsonDecode(body);

      if (decoded is Map<String, dynamic>) {
        final detail = decoded['detail'];

        if (detail is String && detail.isNotEmpty) {
          return detail;
        }
      }
    } catch (_) {
      // Fall back to a general error.
    }

    return 'Unable to load voice notes. Please try again.';
  }

  Future<void> _ensurePlayer() async {
    if (_player != null) return;

    final player = AudioPlayer();

    _player = player;

    _playerSubscription = player.playerStateStream.listen((state) {
      if (!mounted) return;

      setState(() {
        _isPlaying = state.playing;

        if (state.processingState == ProcessingState.completed) {
          _playingNoteId = null;
        }
      });
    });
  }

  String _audioUrl(Map<String, dynamic> note) {
    final providedUrl = note['audio_url']?.toString();
    final noteId = note['voice_note_id'] ?? note['id'];

    if (providedUrl != null && providedUrl.isNotEmpty) {
      if (providedUrl.startsWith('http://') ||
          providedUrl.startsWith('https://')) {
        return providedUrl;
      }

      if (providedUrl.startsWith('/')) {
        return '$_baseUrl$providedUrl';
      }

      return '$_baseUrl/$providedUrl';
    }

    return '$_baseUrl/voice-notes/$noteId/audio';
  }

  Future<void> _togglePlayback(Map<String, dynamic> note) async {
    final dynamic rawId = note['voice_note_id'] ?? note['id'];
    final noteId = rawId is int ? rawId : int.tryParse(rawId?.toString() ?? '');

    if (noteId == null) {
      _showError('This voice note has an invalid ID.');
      return;
    }

    try {
      await _ensurePlayer();

      final player = _player!;

      if (_playingNoteId == noteId && player.playing) {
        await player.pause();
        return;
      }

      setState(() {
        _isBusy = true;
        _errorMessage = null;
      });

      final token = await _getToken();

      await player.stop();

      await player.setAudioSource(
        AudioSource.uri(
          Uri.parse(_audioUrl(note)),
          headers: {'Authorization': 'Bearer $token'},
        ),
      );

      if (!mounted) return;

      setState(() {
        _playingNoteId = noteId;
      });

      unawaited(player.play());
    } catch (error) {
      _showError(error.toString().replaceFirst('Exception: ', ''));
    } finally {
      if (mounted) {
        setState(() {
          _isBusy = false;
        });
      }
    }
  }

  Future<void> _startRecording() async {
    if (_isBusy || _isRecording) return;

    setState(() {
      _isBusy = true;
      _errorMessage = null;
      _recordingPath = null;
      _elapsed = Duration.zero;
    });

    try {
      final player = _player;

      if (player != null) {
        await player.stop();
      }

      _recorder ??= VoiceNoteRecorderService();

      await _recorder!.startRecording();

      if (!mounted) return;

      setState(() {
        _isRecording = true;
        _isPlaying = false;
        _playingNoteId = null;
      });

      _timer?.cancel();

      _timer = Timer.periodic(const Duration(seconds: 1), (_) {
        if (!mounted || !_isRecording) return;

        if (_elapsed.inSeconds >= 300) {
          unawaited(_stopAndUpload());
          return;
        }

        setState(() {
          _elapsed += const Duration(seconds: 1);
        });
      });
    } catch (error) {
      _showError(error.toString().replaceFirst('Exception: ', ''));
    } finally {
      if (mounted) {
        setState(() {
          _isBusy = false;
        });
      }
    }
  }

  Future<void> _stopAndUpload() async {
    if (_isBusy || !_isRecording || _recorder == null) {
      return;
    }

    _timer?.cancel();
    _timer = null;

    setState(() {
      _isBusy = true;
      _errorMessage = null;
    });

    try {
      final path = await _recorder!.stopRecording();

      if (path == null || path.trim().isEmpty) {
        throw Exception('No audio file was produced.');
      }

      if (!mounted) return;

      setState(() {
        _isRecording = false;
        _recordingPath = path;
      });

      await _uploadRecording(path);
    } catch (error) {
      _showError(error.toString().replaceFirst('Exception: ', ''));
    } finally {
      if (mounted) {
        setState(() {
          _isRecording = false;
          _isBusy = false;
        });
      }
    }
  }

  Future<void> _uploadRecording(String path) async {
    try {
      final token = await _getToken();

      final request = http.MultipartRequest(
        'POST',
        Uri.parse('$_baseUrl/voice-notes'),
      );

      request.headers['Authorization'] = 'Bearer $token';
      request.fields['target_type'] = widget.targetType;
      request.fields['target_id'] = widget.targetId.toString();

      final duration = _elapsed.inSeconds.clamp(1, 300);
      request.fields['duration_seconds'] = duration.toString();

      final filename = path.toLowerCase().endsWith('.wav')
          ? 'voice_note.wav'
          : 'voice_note.m4a';

      if (kIsWeb) {
        final audioResponse = await http.get(Uri.parse(path));

        if (audioResponse.statusCode < 200 || audioResponse.statusCode >= 300) {
          throw Exception('Could not read the recording.');
        }

        request.files.add(
          http.MultipartFile.fromBytes(
            'file',
            audioResponse.bodyBytes,
            filename: filename,
          ),
        );
      } else {
        request.files.add(
          await http.MultipartFile.fromPath('file', path, filename: filename),
        );
      }

      final streamedResponse = await request.send();
      final response = await http.Response.fromStream(streamedResponse);

      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw Exception(_readServerError(response.body));
      }

      if (!mounted) return;

      setState(() {
        _recordingPath = null;
      });

      await _loadNotes(forceRefresh: true);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Voice note uploaded successfully.')),
        );
      }
    } catch (error) {
      _showError(error.toString().replaceFirst('Exception: ', ''));
    }
  }

  void _showError(String message) {
    if (!mounted) return;

    setState(() {
      _errorMessage = message;
    });
  }

  Widget _buildRecorderControls() {
    if (_isRecording) {
      return Row(
        children: [
          const Icon(Icons.fiber_manual_record, color: Colors.red, size: 16),
          const SizedBox(width: 8),
          Text(
            'Recording ${_formatDuration(_elapsed)}',
            style: const TextStyle(fontWeight: FontWeight.w600),
          ),
          const Spacer(),
          FilledButton.icon(
            onPressed: _isBusy ? null : _stopAndUpload,
            icon: const Icon(Icons.stop_rounded),
            label: const Text('Stop & upload'),
          ),
        ],
      );
    }

    if (_recordingPath != null) {
      return SizedBox(
        width: double.infinity,
        child: FilledButton.icon(
          onPressed: _isBusy ? null : () => _uploadRecording(_recordingPath!),
          icon: const Icon(Icons.cloud_upload_outlined),
          label: const Text('Retry upload'),
        ),
      );
    }

    return SizedBox(
      width: double.infinity,
      child: OutlinedButton.icon(
        onPressed: _isBusy ? null : _startRecording,
        icon: const Icon(Icons.mic_none_rounded),
        label: const Text('Record a voice note'),
      ),
    );
  }

  Widget _buildNoteItem(Map<String, dynamic> note) {
    final noteId = note['voice_note_id'] ?? note['id'];
    final publicCode = note['public_code']?.toString() ?? '';
    final nickname = note['nickname']?.toString() ?? '';
    final duration = _formatNoteDuration(note['duration_seconds']);

    final selected = noteId != null && noteId == _playingNoteId;

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest
            .withValues(alpha: 0.45),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          IconButton.filledTonal(
            onPressed: _isBusy ? null : () => _togglePlayback(note),
            icon: Icon(
              selected && _isPlaying
                  ? Icons.pause_rounded
                  : Icons.play_arrow_rounded,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  nickname.isNotEmpty
                      ? nickname
                      : publicCode.isNotEmpty
                      ? publicCode
                      : 'Community member',
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 4),
                Text(duration, style: Theme.of(context).textTheme.bodySmall),
              ],
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(top: 8, bottom: 12),
      clipBehavior: Clip.antiAlias,
      child: ExpansionTile(
        initiallyExpanded: false,
        onExpansionChanged: _handleExpansionChanged,
        leading: const Icon(Icons.graphic_eq_rounded),
        title: const Text(
          'Voice notes',
          style: TextStyle(fontWeight: FontWeight.w600),
        ),
        subtitle: Text(
          _hasLoaded
              ? '${_notes.length} ${_notes.length == 1 ? 'recording' : 'recordings'}'
              : 'Listen or share an audio opinion',
        ),
        childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        children: [
          if (_isLoading)
            const Padding(
              padding: EdgeInsets.all(16),
              child: Center(child: CircularProgressIndicator()),
            )
          else ...[
            if (_errorMessage != null)
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Text(
                  _errorMessage!,
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
              ),
            if (_notes.isEmpty)
              const Padding(
                padding: EdgeInsets.only(bottom: 12),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Text('No voice notes yet. Share the first one.'),
                ),
              ),
            ..._notes.map(_buildNoteItem),
            const SizedBox(height: 8),
            _buildRecorderControls(),
          ],
          if (_hasLoaded && !_isLoading)
            Align(
              alignment: Alignment.centerRight,
              child: TextButton.icon(
                onPressed: _isBusy
                    ? null
                    : () => _loadNotes(forceRefresh: true),
                icon: const Icon(Icons.refresh_rounded),
                label: const Text('Refresh'),
              ),
            ),
        ],
      ),
    );
  }
}
