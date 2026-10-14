import 'dart:async';

import 'package:flutter/material.dart';
import 'package:just_audio/just_audio.dart';
import 'package:provider/provider.dart';

import '../../core/constants/api_constants.dart';
import '../../models/group_message_model.dart';
import '../../models/group_model.dart';
import '../../providers/group_provider.dart';
import '../../services/token_storage_service.dart';
import '../../services/voice_note_recorder_service.dart';

class GroupChatScreen extends StatelessWidget {
  final GroupModel group;

  const GroupChatScreen({super.key, required this.group});

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final name = group.groupName.trim();

    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            _GroupAvatar(name: name, size: 40),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    group.groupName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.titleMedium
                        ?.copyWith(fontWeight: FontWeight.w800),
                  ),
                  Text(
                    'Private group chat',
                    style: Theme.of(context).textTheme.labelSmall
                        ?.copyWith(color: colors.onSurfaceVariant),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
      body: GroupChatView(group: group),
    );
  }
}

class _GroupAvatar extends StatelessWidget {
  final String name;
  final double size;

  const _GroupAvatar({required this.name, this.size = 44});

  @override
  Widget build(BuildContext context) {
    final initial = name.isEmpty ? 'G' : name[0].toUpperCase();

    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF625BFF), Color(0xFF20BFA9)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(size * 0.32),
      ),
      alignment: Alignment.center,
      child: Text(
        initial,
        style: TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.w800,
          fontSize: size * 0.42,
        ),
      ),
    );
  }
}

class GroupChatView extends StatefulWidget {
  final GroupModel group;

  const GroupChatView({super.key, required this.group});

  @override
  State<GroupChatView> createState() => _GroupChatViewState();
}

class _GroupChatViewState extends State<GroupChatView> {
  final TextEditingController _messageController = TextEditingController();

  final ScrollController _scrollController = ScrollController();

  final VoiceNoteRecorderService _voiceRecorder = VoiceNoteRecorderService();

  Timer? _recordingTimer;

  bool _isRecording = false;
  bool _isStartingRecording = false;
  bool _isSendingVoice = false;
  bool _cancelRecording = false;
  bool _releaseRequested = false;
  bool _handlingRelease = false;

  DateTime? _recordingStartedAt;
  Duration _recordingElapsed = Duration.zero;

  @override
  void initState() {
    super.initState();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _loadMessages();
      }
    });
  }

  @override
  void dispose() {
    _recordingTimer?.cancel();
    _messageController.dispose();
    _scrollController.dispose();
    unawaited(_voiceRecorder.dispose());

    super.dispose();
  }

  Future<void> _loadMessages() async {
    final provider = context.read<GroupProvider>();

    await provider.loadGroupMessages(widget.group.groupId);

    if (mounted) {
      _scheduleScrollToBottom();
    }
  }

  void _scheduleScrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_scrollController.hasClients) return;

      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeOut,
      );
    });
  }

  Future<void> _sendMessage() async {
    final text = _messageController.text.trim();

    if (text.isEmpty) return;

    FocusScope.of(context).unfocus();

    final provider = context.read<GroupProvider>();

    final success = await provider.sendGroupMessage(
      groupId: widget.group.groupId,
      content: text,
    );

    if (!mounted) return;

    if (success) {
      _messageController.clear();
      setState(() {});
      _scheduleScrollToBottom();
    } else {
      _showMessage(
        provider.errorMessage ?? 'Unable to send message.',
        error: true,
      );
    }
  }

  // ------------------------------------------------------------
  // RECORDING
  // ------------------------------------------------------------

  Future<void> _startVoiceRecording() async {
    if (_isRecording || _isStartingRecording || _isSendingVoice) {
      return;
    }

    if (_messageController.text.trim().isNotEmpty) {
      return;
    }

    setState(() {
      _isStartingRecording = true;
      _cancelRecording = false;
      _releaseRequested = false;
      _handlingRelease = false;
      _recordingElapsed = Duration.zero;
    });

    try {
      await _voiceRecorder.startRecording();

      if (!mounted) {
        await _voiceRecorder.cancelRecording();
        return;
      }

      _recordingStartedAt = DateTime.now();

      setState(() {
        _isStartingRecording = false;
        _isRecording = true;
      });

      _recordingTimer?.cancel();

      _recordingTimer = Timer.periodic(const Duration(milliseconds: 200), (_) {
        if (!mounted || !_isRecording) return;

        final startedAt = _recordingStartedAt;
        if (startedAt == null) return;

        final elapsed = DateTime.now().difference(startedAt);

        setState(() {
          _recordingElapsed = elapsed;
        });

        if (elapsed.inSeconds >= 300) {
          unawaited(_finishVoiceRecording());
        }
      });

      // The user may release before the recording permission/start
      // operation finishes.
      if (_releaseRequested) {
        await _finishVoiceRecording();
      }
    } catch (_) {
      if (!mounted) return;

      setState(() {
        _isStartingRecording = false;
        _isRecording = false;
      });

      _showMessage(
        'Could not start recording. Check microphone permission.',
        error: true,
      );
    }
  }

  void _onRecordingMove(LongPressMoveUpdateDetails details) {
    if (!_isRecording || _cancelRecording) return;

    if (details.offsetFromOrigin.dx < -85) {
      setState(() {
        _cancelRecording = true;
      });
    }
  }

  void _onRecordingReleased() {
    _releaseRequested = true;

    if (_isStartingRecording) return;
    if (!_isRecording || _handlingRelease) return;

    unawaited(_finishVoiceRecording());
  }

  void _onRecordingCancelled() {
    if (!_isRecording && !_isStartingRecording) return;

    _cancelRecording = true;
    _releaseRequested = true;

    if (_isRecording && !_handlingRelease) {
      unawaited(_finishVoiceRecording());
    }
  }

  Future<void> _finishVoiceRecording() async {
    if (_handlingRelease) return;

    if (_isStartingRecording) {
      _releaseRequested = true;
      return;
    }

    if (!_isRecording) return;

    _handlingRelease = true;

    final shouldCancel = _cancelRecording;
    final startedAt = _recordingStartedAt;

    _recordingTimer?.cancel();
    _recordingTimer = null;

    final elapsed = startedAt == null
        ? Duration.zero
        : DateTime.now().difference(startedAt);

    setState(() {
      _isRecording = false;
      _isStartingRecording = false;
      _isSendingVoice = !shouldCancel;
    });

    try {
      if (shouldCancel) {
        await _voiceRecorder.cancelRecording();

        if (mounted) {
          _showMessage('Recording cancelled.');
        }

        return;
      }

      if (elapsed.inMilliseconds < 800) {
        await _voiceRecorder.cancelRecording();

        if (mounted) {
          _showMessage('Hold the microphone a little longer to record.');
        }

        return;
      }

      final path = await _voiceRecorder.stopRecording();

      if (path == null || path.trim().isEmpty) {
        throw StateError('No recording file was created.');
      }

      if (!mounted) return;

      final provider = context.read<GroupProvider>();

      final success = await provider.sendGroupVoiceNote(
        groupId: widget.group.groupId,
        filePath: path,
        durationSeconds: elapsed.inMilliseconds / 1000.0,
      );

      if (!mounted) return;

      if (success) {
        _showMessage('Voice note sent.');
        _scheduleScrollToBottom();
      } else {
        _showMessage(
          provider.errorMessage ?? 'Unable to send voice note.',
          error: true,
        );
      }
    } catch (_) {
      // If recording was still active when an error occurred,
      // attempt to release the recorder cleanly.
      try {
        if (await _voiceRecorder.isRecording) {
          await _voiceRecorder.cancelRecording();
        }
      } catch (_) {
        // Keep the original user-facing failure message.
      }

      if (mounted) {
        _showMessage(
          'Unable to record or send voice note. Please try again.',
          error: true,
        );
      }
    } finally {
      _recordingTimer?.cancel();
      _recordingTimer = null;

      if (mounted) {
        setState(() {
          _isRecording = false;
          _isStartingRecording = false;
          _isSendingVoice = false;
          _cancelRecording = false;
          _releaseRequested = false;
          _handlingRelease = false;
          _recordingElapsed = Duration.zero;
          _recordingStartedAt = null;
        });
      }
    }
  }

  String _formatDuration(Duration duration) {
    final minutes = duration.inMinutes.toString().padLeft(2, '0');
    final seconds = (duration.inSeconds % 60).toString().padLeft(2, '0');

    return '$minutes:$seconds';
  }

  void _showMessage(String message, {bool error = false}) {
    if (!mounted) return;

    final messenger = ScaffoldMessenger.of(context);

    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: error ? const Color(0xFFB42318) : null,
        ),
      );
  }

  // ------------------------------------------------------------
  // DELETE MESSAGE
  // ------------------------------------------------------------

  Future<void> _deleteMessage(GroupMessageModel message) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Delete message?'),
          content: const Text(
            'This removes your message from the group chat for everyone.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(dialogContext).pop(true),
              child: const Text('Delete'),
            ),
          ],
        );
      },
    );

    if (confirmed != true || !mounted) return;

    final provider = context.read<GroupProvider>();

    final success = await provider.deleteGroupMessage(
      groupId: widget.group.groupId,
      messageId: message.messageId,
    );

    if (!mounted) return;

    _showMessage(
      success
          ? 'Message deleted.'
          : provider.errorMessage ?? 'Unable to delete message.',
      error: !success,
    );
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<GroupProvider>();

    final messages = provider.groupMessagesFor(widget.group.groupId);
    final isLoading = provider.isLoadingMessagesFor(widget.group.groupId);
    final error = provider.messageErrorFor(widget.group.groupId);

    return Column(
      children: [
        Expanded(
          child: _buildMessageArea(
            context,
            messages: messages,
            isLoading: isLoading,
            error: error,
          ),
        ),
        _buildComposer(context, provider),
      ],
    );
  }

  Widget _buildMessageArea(
    BuildContext context, {
    required List<GroupMessageModel> messages,
    required bool isLoading,
    required String? error,
  }) {
    final colors = Theme.of(context).colorScheme;

    if (isLoading && messages.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }

    if (error != null && messages.isEmpty) {
      return RefreshIndicator(
        onRefresh: _loadMessages,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          children: [
            SizedBox(
              height: MediaQuery.of(context).size.height * 0.6,
              child: Center(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.cloud_off_outlined,
                        size: 48,
                        color: colors.onSurfaceVariant,
                      ),
                      const SizedBox(height: 14),
                      Text(
                        'Couldn’t load chat',
                        style: Theme.of(context).textTheme.titleMedium
                            ?.copyWith(fontWeight: FontWeight.w800),
                      ),
                      const SizedBox(height: 8),
                      Text(error, textAlign: TextAlign.center),
                      const SizedBox(height: 18),
                      FilledButton.icon(
                        onPressed: _loadMessages,
                        icon: const Icon(Icons.refresh_rounded),
                        label: const Text('Try again'),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      );
    }

    if (messages.isEmpty) {
      return RefreshIndicator(
        onRefresh: _loadMessages,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          children: [
            SizedBox(
              height: MediaQuery.of(context).size.height * 0.6,
              child: Center(
                child: Padding(
                  padding: const EdgeInsets.all(28),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 78,
                        height: 78,
                        decoration: BoxDecoration(
                          color: colors.primaryContainer,
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          Icons.chat_bubble_outline_rounded,
                          size: 36,
                          color: colors.onPrimaryContainer,
                        ),
                      ),
                      const SizedBox(height: 18),
                      Text(
                        'Start the conversation',
                        textAlign: TextAlign.center,
                        style: Theme.of(context).textTheme.titleLarge
                            ?.copyWith(fontWeight: FontWeight.w800),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Ask something, share an opinion, or send a voice note.',
                        textAlign: TextAlign.center,
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          height: 1.45,
                          color: colors.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadMessages,
      child: ListView.builder(
        controller: _scrollController,
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(12, 16, 12, 18),
        itemCount: messages.length,
        itemBuilder: (context, index) {
          final message = messages[index];

          return _MessageBubble(
            key: ValueKey(message.messageId),
            message: message,
            onDelete: message.isMine ? () => _deleteMessage(message) : null,
          );
        },
      ),
    );
  }

  // ------------------------------------------------------------
  // MESSAGE COMPOSER
  // ------------------------------------------------------------

  Widget _buildComposer(BuildContext context, GroupProvider provider) {
    final colors = Theme.of(context).colorScheme;
    final isRecordingUI = _isRecording || _isStartingRecording;
    final showMicrophone =
        isRecordingUI ||
        _isSendingVoice ||
        _messageController.text.trim().isEmpty;

    return Container(
      padding: const EdgeInsets.fromLTRB(12, 9, 12, 10),
      decoration: BoxDecoration(
        color: colors.surface,
        border: Border(top: BorderSide(color: colors.outlineVariant)),
      ),
      child: SafeArea(
        top: false,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Expanded(
              child: isRecordingUI
                  ? Container(
                      constraints: const BoxConstraints(minHeight: 49),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 15,
                        vertical: 10,
                      ),
                      decoration: BoxDecoration(
                        color: colors.surfaceContainerHighest,
                        borderRadius: BorderRadius.circular(23),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            _cancelRecording
                                ? Icons.close_rounded
                                : Icons.mic_rounded,
                            color: _cancelRecording
                                ? colors.error
                                : colors.primary,
                          ),
                          const SizedBox(width: 10),
                          Text(
                            _cancelRecording
                                ? 'Cancel'
                                : _formatDuration(_recordingElapsed),
                            style: TextStyle(
                              fontWeight: FontWeight.w800,
                              color: _cancelRecording
                                  ? colors.error
                                  : colors.onSurface,
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              _cancelRecording
                                  ? 'Release to cancel'
                                  : 'Slide left to cancel',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                color: colors.onSurfaceVariant,
                                fontSize: 12,
                              ),
                            ),
                          ),
                        ],
                      ),
                    )
                  : TextField(
                      controller: _messageController,
                      minLines: 1,
                      maxLines: 5,
                      textCapitalization: TextCapitalization.sentences,
                      onChanged: (_) => setState(() {}),
                      onSubmitted: (_) => _sendMessage(),
                      decoration: InputDecoration(
                        hintText: 'Write a message...',
                        filled: true,
                        fillColor: colors.surfaceContainerHighest,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(23),
                          borderSide: BorderSide.none,
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(23),
                          borderSide: BorderSide.none,
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(23),
                          borderSide: BorderSide(color: colors.primary),
                        ),
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 18,
                          vertical: 13,
                        ),
                      ),
                    ),
            ),
            const SizedBox(width: 8),
            if (showMicrophone)
              _buildMicrophoneButton(colors, provider)
            else
              SizedBox(
                width: 49,
                height: 49,
                child: IconButton.filled(
                  onPressed: provider.isSendingMessage ? null : _sendMessage,
                  style: IconButton.styleFrom(shape: const CircleBorder()),
                  icon: provider.isSendingMessage
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            color: Colors.white,
                            strokeWidth: 2,
                          ),
                        )
                      : const Icon(Icons.send_rounded),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildMicrophoneButton(ColorScheme colors, GroupProvider provider) {
    final busy = _isSendingVoice || provider.isSendingMessage;

    final color = _cancelRecording || _isRecording
        ? colors.error
        : colors.primary;

    return Tooltip(
      message: busy ? 'Sending...' : 'Press and hold to record',
      child: GestureDetector(
        onLongPressStart: busy
            ? null
            : (_) => unawaited(_startVoiceRecording()),
        onLongPressMoveUpdate: _onRecordingMove,
        onLongPressEnd: (_) => _onRecordingReleased(),
        onLongPressCancel: _onRecordingCancelled,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 140),
          width: 50,
          height: 50,
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
            boxShadow: _isRecording
                ? [
                    BoxShadow(
                      color: color.withValues(alpha: 0.25),
                      blurRadius: 12,
                      spreadRadius: 2,
                    ),
                  ]
                : null,
          ),
          child: Center(
            child: busy
                ? const SizedBox(
                    width: 21,
                    height: 21,
                    child: CircularProgressIndicator(
                      color: Colors.white,
                      strokeWidth: 2,
                    ),
                  )
                : Icon(
                    _cancelRecording ? Icons.close_rounded : Icons.mic_rounded,
                    color: Colors.white,
                    size: 25,
                  ),
          ),
        ),
      ),
    );
  }
}

// ============================================================
// MESSAGE BUBBLE
// ============================================================

class _MessageBubble extends StatelessWidget {
  final GroupMessageModel message;
  final VoidCallback? onDelete;

  const _MessageBubble({
    super.key,
    required this.message,
    required this.onDelete,
  });

  String _formatTime(DateTime value) {
    final time = value.toLocal();

    final hour = time.hour == 0
        ? 12
        : time.hour > 12
        ? time.hour - 12
        : time.hour;

    final minute = time.minute.toString().padLeft(2, '0');
    final suffix = time.hour >= 12 ? 'PM' : 'AM';

    return '$hour:$minute $suffix';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final mine = message.isMine;

    final bubbleColor = mine
        ? colors.primaryContainer
        : colors.surfaceContainerHighest;

    final contentColor = mine ? colors.onPrimaryContainer : colors.onSurface;

    return Align(
      alignment: mine ? Alignment.centerRight : Alignment.centerLeft,
      child: Padding(
        padding: const EdgeInsets.only(bottom: 11),
        child: Row(
          mainAxisAlignment: mine
              ? MainAxisAlignment.end
              : MainAxisAlignment.start,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            if (!mine) ...[
              CircleAvatar(
                radius: 16,
                backgroundColor: colors.secondaryContainer,
                foregroundColor: colors.onSecondaryContainer,
                child: Text(
                  message.nickname.isEmpty
                      ? '?'
                      : message.nickname[0].toUpperCase(),
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              const SizedBox(width: 8),
            ],
            Flexible(
              child: Container(
                constraints: const BoxConstraints(maxWidth: 520),
                padding: const EdgeInsets.fromLTRB(14, 10, 10, 8),
                decoration: BoxDecoration(
                  color: bubbleColor,
                  borderRadius: BorderRadius.only(
                    topLeft: const Radius.circular(18),
                    topRight: const Radius.circular(18),
                    bottomLeft: Radius.circular(mine ? 18 : 4),
                    bottomRight: Radius.circular(mine ? 4 : 18),
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            mine ? 'You' : message.nickname,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: theme.textTheme.labelMedium?.copyWith(
                              color: contentColor,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                        if (mine && onDelete != null)
                          PopupMenuButton<String>(
                            tooltip: 'Message options',
                            padding: EdgeInsets.zero,
                            onSelected: (value) {
                              if (value == 'delete') onDelete!();
                            },
                            itemBuilder: (_) => const [
                              PopupMenuItem(
                                value: 'delete',
                                child: Row(
                                  children: [
                                    Icon(Icons.delete_outline_rounded),
                                    SizedBox(width: 10),
                                    Text('Delete message'),
                                  ],
                                ),
                              ),
                            ],
                            child: Icon(
                              Icons.more_vert_rounded,
                              size: 18,
                              color: contentColor.withValues(alpha: 0.7),
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    if (message.hasVoiceNote)
                      _VoiceNotePlayer(
                        key: ValueKey('voice_${message.voiceNoteId}'),
                        voiceNoteId: message.voiceNoteId!,
                        durationSeconds: message.durationSeconds ?? 0,
                        foregroundColor: contentColor,
                      )
                    else
                      Text(
                        message.content,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: contentColor,
                          height: 1.4,
                        ),
                      ),
                    const SizedBox(height: 5),
                    Align(
                      alignment: Alignment.centerRight,
                      child: Text(
                        _formatTime(message.createdAt),
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: contentColor.withValues(alpha: 0.68),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ============================================================
// LAZY VOICE-NOTE PLAYER
// AudioPlayer is allocated only after the user taps Play.
// ============================================================

class _VoiceNotePlayer extends StatefulWidget {
  final int voiceNoteId;
  final double durationSeconds;
  final Color foregroundColor;

  const _VoiceNotePlayer({
    super.key,
    required this.voiceNoteId,
    required this.durationSeconds,
    required this.foregroundColor,
  });

  @override
  State<_VoiceNotePlayer> createState() => _VoiceNotePlayerState();
}

class _VoiceNotePlayerState extends State<_VoiceNotePlayer> {
  AudioPlayer? _player;

  StreamSubscription<PlayerState>? _stateSubscription;
  StreamSubscription<Duration>? _positionSubscription;
  StreamSubscription<Duration?>? _durationSubscription;

  bool _busy = false;
  bool _playing = false;
  String? _error;

  Duration _position = Duration.zero;
  Duration? _actualDuration;

  Duration get _totalDuration {
    return _actualDuration ??
        Duration(milliseconds: (widget.durationSeconds * 1000).round());
  }

  AudioPlayer _ensurePlayer() {
    final existing = _player;
    if (existing != null) return existing;

    final player = AudioPlayer();
    _player = player;

    _stateSubscription = player.playerStateStream.listen((state) {
      if (!mounted) return;
      setState(() {
        _playing = state.playing;
      });
    });

    _positionSubscription = player.positionStream.listen((position) {
      if (!mounted) return;
      setState(() {
        _position = position;
      });
    });

    _durationSubscription = player.durationStream.listen((duration) {
      if (!mounted) return;
      setState(() {
        _actualDuration = duration;
      });
    });

    return player;
  }

  String _formatDuration(Duration duration) {
    final minutes = duration.inMinutes.toString().padLeft(2, '0');
    final seconds = (duration.inSeconds % 60).toString().padLeft(2, '0');

    return '$minutes:$seconds';
  }

  Future<void> _togglePlayback() async {
    if (_busy) return;

    setState(() {
      _busy = true;
      _error = null;
    });

    try {
      final player = _ensurePlayer();

      if (player.playing) {
        await player.pause();
        return;
      }

      if (player.processingState == ProcessingState.completed) {
        await player.seek(Duration.zero);
      }

      if (player.processingState == ProcessingState.idle) {
        final token = await TokenStorageService().getAccessToken();

        if (token == null || token.isEmpty) {
          throw StateError('Your session has expired. Please log in again.');
        }

        final url =
            '${ApiConstants.baseUrl}/voice-notes/'
            '${widget.voiceNoteId}/audio';

        await player.setUrl(url, headers: {'Authorization': 'Bearer $token'});
      }

      // play() completes when playback finishes or pauses. It should
      // not be awaited here, otherwise the button stays busy throughout
      // the entire recording.
      unawaited(player.play());
    } catch (_) {
      if (mounted) {
        setState(() {
          _error = 'Unable to play this voice note.';
        });
      }
    } finally {
      if (mounted) {
        setState(() {
          _busy = false;
        });
      }
    }
  }

  Future<void> _seek(double value) async {
    final total = _totalDuration;

    if (total.inMilliseconds <= 0) return;

    final position = Duration(
      milliseconds: (total.inMilliseconds * value).round(),
    );

    try {
      await _player?.seek(position);
    } catch (_) {
      // Seeking is optional; keep playback available if it fails.
    }
  }

  @override
  void dispose() {
    _stateSubscription?.cancel();
    _positionSubscription?.cancel();
    _durationSubscription?.cancel();

    final player = _player;
    if (player != null) {
      unawaited(player.dispose());
    }

    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final total = _totalDuration;

    final progress = total.inMilliseconds <= 0
        ? 0.0
        : (_position.inMilliseconds / total.inMilliseconds)
              .clamp(0.0, 1.0)
              .toDouble();

    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 280),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              SizedBox(
                width: 42,
                height: 42,
                child: IconButton.filledTonal(
                  tooltip: _playing ? 'Pause voice note' : 'Play voice note',
                  onPressed: _busy ? null : _togglePlayback,
                  style: IconButton.styleFrom(shape: const CircleBorder()),
                  icon: _busy
                      ? const SizedBox(
                          width: 19,
                          height: 19,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : Icon(
                          _playing
                              ? Icons.pause_rounded
                              : Icons.play_arrow_rounded,
                        ),
                ),
              ),
              const SizedBox(width: 9),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Voice note',
                      style: TextStyle(
                        color: widget.foregroundColor,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    SliderTheme(
                      data: SliderTheme.of(context).copyWith(
                        trackHeight: 3,
                        thumbShape: const RoundSliderThumbShape(
                          enabledThumbRadius: 5,
                        ),
                        overlayShape: const RoundSliderOverlayShape(
                          overlayRadius: 11,
                        ),
                      ),
                      child: Slider(
                        value: progress,
                        onChanged: _totalDuration.inMilliseconds <= 0
                            ? null
                            : _seek,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          Padding(
            padding: const EdgeInsets.only(left: 51),
            child: Text(
              '${_formatDuration(_position)} / '
              '${_formatDuration(total)}',
              style: TextStyle(
                fontSize: 11,
                color: widget.foregroundColor.withValues(alpha: 0.72),
              ),
            ),
          ),
          if (_error != null)
            Padding(
              padding: const EdgeInsets.only(top: 5, left: 8),
              child: Text(
                _error!,
                style: TextStyle(fontSize: 12, color: colors.error),
              ),
            ),
        ],
      ),
    );
  }
}
