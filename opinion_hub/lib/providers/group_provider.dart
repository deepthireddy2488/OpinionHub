import 'package:flutter/foundation.dart';

import '../models/group_message_model.dart';
import '../models/group_model.dart';
import '../models/question_model.dart';
import '../repositories/group_repository.dart';
import '../services/token_storage_service.dart';

class GroupProvider extends ChangeNotifier {
  final GroupRepository _repository;
  final TokenStorageService _tokenStorage;

  GroupProvider({
    GroupRepository? repository,
    TokenStorageService? tokenStorage,
  }) : _repository = repository ?? GroupRepository(),
       _tokenStorage = tokenStorage ?? TokenStorageService();

  List<GroupModel> _groups = [];
  List<GroupInvitationModel> _invitations = [];
  List<GroupMemberModel> _members = [];

  // Legacy latest-loaded lists for existing screens.
  List<QuestionModel> _groupQuestions = [];
  List<GroupMessageModel> _groupMessages = [];

  // Independent data for each group.
  final Map<int, List<QuestionModel>> _questionsByGroup = {};
  final Map<int, List<GroupMessageModel>> _messagesByGroup = {};
  final Map<int, String> _questionErrors = {};
  final Map<int, String> _messageErrors = {};

  final Set<int> _loadingQuestionGroups = {};
  final Set<int> _loadingMessageGroups = {};

  bool _isLoadingGroups = false;
  bool _isCreating = false;
  bool _isRenaming = false;
  bool _isLoadingInvitations = false;
  bool _isLoadingMembers = false;
  bool _isCreatingQuestion = false;
  bool _isInviting = false;
  bool _isResponding = false;
  bool _isLeaving = false;
  bool _isSendingMessage = false;
  bool _isDeletingMessage = false;
  bool _isClearingChat = false;

  String? _errorMessage;
  bool _disposed = false;

  List<GroupModel> get groups => List.unmodifiable(_groups);
  List<GroupInvitationModel> get invitations => List.unmodifiable(_invitations);
  List<GroupMemberModel> get members => List.unmodifiable(_members);

  // Backward-compatible getters.
  List<QuestionModel> get groupQuestions => List.unmodifiable(_groupQuestions);

  List<GroupMessageModel> get groupMessages =>
      List.unmodifiable(_groupMessages);

  // Group-specific getters: prefer these in group detail/chat screens.
  List<QuestionModel> groupQuestionsFor(int groupId) =>
      List.unmodifiable(_questionsByGroup[groupId] ?? const []);

  List<GroupMessageModel> groupMessagesFor(int groupId) =>
      List.unmodifiable(_messagesByGroup[groupId] ?? const []);

  bool isLoadingQuestionsFor(int groupId) =>
      _loadingQuestionGroups.contains(groupId);

  bool isLoadingMessagesFor(int groupId) =>
      _loadingMessageGroups.contains(groupId);

  String? questionErrorFor(int groupId) => _questionErrors[groupId];

  String? messageErrorFor(int groupId) => _messageErrors[groupId];

  bool get isLoadingGroups => _isLoadingGroups;
  bool get isCreating => _isCreating;
  bool get isRenaming => _isRenaming;
  bool get isLoadingInvitations => _isLoadingInvitations;
  bool get isLoadingMembers => _isLoadingMembers;

  bool get isLoadingQuestions => _loadingQuestionGroups.isNotEmpty;
  bool get isCreatingQuestion => _isCreatingQuestion;
  bool get isInviting => _isInviting;
  bool get isResponding => _isResponding;
  bool get isLeaving => _isLeaving;

  bool get isLoadingMessages => _loadingMessageGroups.isNotEmpty;
  bool get isSendingMessage => _isSendingMessage;
  bool get isDeletingMessage => _isDeletingMessage;
  bool get isClearingChat => _isClearingChat;

  String? get errorMessage => _errorMessage;

  void _notify() {
    if (!_disposed) {
      notifyListeners();
    }
  }

  Future<String?> _getToken() async {
    if (_disposed) return null;

    try {
      final token = await _tokenStorage.getAccessToken();

      if (_disposed) return null;

      if (token == null || token.isEmpty) {
        _errorMessage = 'Your session has expired. Please log in again.';
        _notify();
        return null;
      }

      return token;
    } catch (_) {
      if (!_disposed) {
        _errorMessage = 'Unable to access your session. Please log in again.';
        _notify();
      }
      return null;
    }
  }

  String _readableError(Object error, String fallback) {
    final message = error.toString().trim();

    final cleaned = message
        .replaceFirst(RegExp(r'^(ApiException|Exception)(\(\d+\))?:\s*'), '')
        .trim();

    if (cleaned.isEmpty ||
        cleaned == 'Exception' ||
        cleaned == 'ApiException') {
      return fallback;
    }

    return cleaned;
  }

  // ------------------------------------------------------------
  // GROUPS
  // ------------------------------------------------------------

  Future<void> loadGroups() async {
    if (_disposed || _isLoadingGroups) return;

    final token = await _getToken();
    if (token == null || _disposed) return;

    _isLoadingGroups = true;
    _errorMessage = null;
    _notify();

    try {
      _groups = await _repository.getMyGroups(accessToken: token);
    } catch (error) {
      _errorMessage = _readableError(error, 'Unable to load groups.');
    } finally {
      _isLoadingGroups = false;
      _notify();
    }
  }

  Future<void> loadInvitations() async {
    if (_disposed || _isLoadingInvitations) return;

    final token = await _getToken();
    if (token == null || _disposed) return;

    _isLoadingInvitations = true;
    _errorMessage = null;
    _notify();

    try {
      _invitations = await _repository.getReceivedInvitations(
        accessToken: token,
      );
    } catch (error) {
      _errorMessage = _readableError(error, 'Unable to load invitations.');
    } finally {
      _isLoadingInvitations = false;
      _notify();
    }
  }

  Future<bool> createGroup(String groupName) async {
    final name = groupName.trim();

    if (name.length < 2 || name.length > 100) {
      _errorMessage = name.length < 2
          ? 'Group name must contain at least 2 characters.'
          : 'Group name cannot exceed 100 characters.';
      _notify();
      return false;
    }

    if (_disposed || _isCreating) return false;

    final token = await _getToken();
    if (token == null || _disposed) return false;

    _isCreating = true;
    _errorMessage = null;
    _notify();

    try {
      final group = await _repository.createGroup(
        groupName: name,
        accessToken: token,
      );

      if (_disposed) return false;

      _groups.insert(0, group);
      return true;
    } catch (error) {
      _errorMessage = _readableError(error, 'Unable to create group.');
      return false;
    } finally {
      _isCreating = false;
      _notify();
    }
  }

  Future<bool> renameGroup({
    required int groupId,
    required String groupName,
  }) async {
    final name = groupName.trim();

    if (name.length < 2 || name.length > 100) {
      _errorMessage = name.length < 2
          ? 'Group name must contain at least 2 characters.'
          : 'Group name cannot exceed 100 characters.';
      _notify();
      return false;
    }

    if (_disposed || _isRenaming) return false;

    final token = await _getToken();
    if (token == null || _disposed) return false;

    _isRenaming = true;
    _errorMessage = null;
    _notify();

    try {
      final updated = await _repository.renameGroup(
        groupId: groupId,
        groupName: name,
        accessToken: token,
      );

      if (_disposed) return false;

      final index = _groups.indexWhere((group) => group.groupId == groupId);

      if (index != -1) {
        _groups[index] = updated;
      }

      return true;
    } catch (error) {
      _errorMessage = _readableError(error, 'Unable to rename group.');
      return false;
    } finally {
      _isRenaming = false;
      _notify();
    }
  }

  // ------------------------------------------------------------
  // MEMBERS
  // ------------------------------------------------------------

  Future<void> loadMembers(int groupId) async {
    if (_disposed || _isLoadingMembers) return;

    final token = await _getToken();
    if (token == null || _disposed) return;

    _isLoadingMembers = true;
    _errorMessage = null;
    _notify();

    try {
      _members = await _repository.getGroupMembers(
        groupId: groupId,
        accessToken: token,
      );
    } catch (error) {
      _errorMessage = _readableError(error, 'Unable to load group members.');
    } finally {
      _isLoadingMembers = false;
      _notify();
    }
  }

  // ------------------------------------------------------------
  // GROUP QUESTIONS — ISOLATED PER GROUP
  // ------------------------------------------------------------

  Future<void> loadGroupQuestions(int groupId) async {
    if (_disposed || _loadingQuestionGroups.contains(groupId)) return;

    final token = await _getToken();
    if (token == null || _disposed) return;

    _loadingQuestionGroups.add(groupId);
    _questionErrors.remove(groupId);
    _errorMessage = null;
    _notify();

    try {
      final questions = await _repository.getGroupQuestions(
        groupId: groupId,
        accessToken: token,
      );

      if (_disposed) return;

      _questionsByGroup[groupId] = questions;
      _groupQuestions = questions;
    } catch (error) {
      final message = _readableError(error, 'Unable to load group questions.');
      _questionErrors[groupId] = message;
      _errorMessage = message;
    } finally {
      _loadingQuestionGroups.remove(groupId);
      _notify();
    }
  }

  Future<bool> createGroupQuestion({
    required int groupId,
    required String title,
  }) async {
    final trimmed = title.trim();

    if (trimmed.length < 5 || trimmed.length > 200) {
      _errorMessage = trimmed.length < 5
          ? 'Question must contain at least 5 characters.'
          : 'Question cannot exceed 200 characters.';
      _notify();
      return false;
    }

    if (_disposed || _isCreatingQuestion) return false;

    final token = await _getToken();
    if (token == null || _disposed) return false;

    _isCreatingQuestion = true;
    _errorMessage = null;
    _notify();

    try {
      await _repository.createGroupQuestion(
        groupId: groupId,
        title: trimmed,
        accessToken: token,
      );

      if (_disposed) return false;

      // The creation request is the authoritative success result.
      // Refresh the list, but don't report creation as failed solely
      // because the follow-up refresh failed.
      await loadGroupQuestions(groupId);
      return true;
    } catch (error) {
      _errorMessage = _readableError(error, 'Unable to create group question.');
      return false;
    } finally {
      _isCreatingQuestion = false;
      _notify();
    }
  }

  // ------------------------------------------------------------
  // INVITATIONS
  // ------------------------------------------------------------

  Future<bool> inviteUser({
    required int groupId,
    required String publicCode,
  }) async {
    final code = publicCode.trim().toUpperCase();

    if (!RegExp(r'^OP-\d{6}$').hasMatch(code)) {
      _errorMessage = 'Enter a public code like OP-123456.';
      _notify();
      return false;
    }

    if (_disposed || _isInviting) return false;

    final token = await _getToken();
    if (token == null || _disposed) return false;

    _isInviting = true;
    _errorMessage = null;
    _notify();

    try {
      await _repository.inviteUser(
        groupId: groupId,
        publicCode: code,
        accessToken: token,
      );
      return true;
    } catch (error) {
      _errorMessage = _readableError(error, 'Unable to send invitation.');
      return false;
    } finally {
      _isInviting = false;
      _notify();
    }
  }

  Future<bool> acceptInvitation(int invitationId) async {
    if (_disposed || _isResponding) return false;

    final token = await _getToken();
    if (token == null || _disposed) return false;

    _isResponding = true;
    _errorMessage = null;
    _notify();

    try {
      await _repository.acceptInvitation(
        invitationId: invitationId,
        accessToken: token,
      );

      if (_disposed) return false;

      await Future.wait([loadGroups(), loadInvitations()]);
      return true;
    } catch (error) {
      _errorMessage = _readableError(error, 'Unable to accept invitation.');
      return false;
    } finally {
      _isResponding = false;
      _notify();
    }
  }

  Future<bool> rejectInvitation(int invitationId) async {
    if (_disposed || _isResponding) return false;

    final token = await _getToken();
    if (token == null || _disposed) return false;

    _isResponding = true;
    _errorMessage = null;
    _notify();

    try {
      await _repository.rejectInvitation(
        invitationId: invitationId,
        accessToken: token,
      );

      if (_disposed) return false;

      await loadInvitations();
      return true;
    } catch (error) {
      _errorMessage = _readableError(error, 'Unable to reject invitation.');
      return false;
    } finally {
      _isResponding = false;
      _notify();
    }
  }

  // ------------------------------------------------------------
  // LEAVE GROUP
  // ------------------------------------------------------------

  Future<bool> leaveGroup(int groupId) async {
    if (_disposed || _isLeaving) return false;

    final token = await _getToken();
    if (token == null || _disposed) return false;

    _isLeaving = true;
    _errorMessage = null;
    _notify();

    try {
      await _repository.leaveGroup(groupId: groupId, accessToken: token);

      if (_disposed) return false;

      _groups.removeWhere((group) => group.groupId == groupId);
      _questionsByGroup.remove(groupId);
      _messagesByGroup.remove(groupId);
      _questionErrors.remove(groupId);
      _messageErrors.remove(groupId);
      _loadingQuestionGroups.remove(groupId);
      _loadingMessageGroups.remove(groupId);
      _members.clear();

      _groupQuestions = [];
      _groupMessages = [];

      return true;
    } catch (error) {
      _errorMessage = _readableError(error, 'Unable to leave group.');
      return false;
    } finally {
      _isLeaving = false;
      _notify();
    }
  }

  // ------------------------------------------------------------
  // GROUP CHAT — ISOLATED PER GROUP
  // ------------------------------------------------------------

  Future<void> loadGroupMessages(int groupId) async {
    if (_disposed || _loadingMessageGroups.contains(groupId)) return;

    final token = await _getToken();
    if (token == null || _disposed) return;

    _loadingMessageGroups.add(groupId);
    _messageErrors.remove(groupId);
    _errorMessage = null;
    _notify();

    try {
      final messages = await _repository.getGroupMessages(
        groupId: groupId,
        accessToken: token,
      );

      if (_disposed) return;

      _messagesByGroup[groupId] = messages;
      _groupMessages = messages;
    } catch (error) {
      final message = _readableError(error, 'Unable to load group messages.');
      _messageErrors[groupId] = message;
      _errorMessage = message;
    } finally {
      _loadingMessageGroups.remove(groupId);
      _notify();
    }
  }

  Future<bool> sendGroupMessage({
    required int groupId,
    required String content,
  }) async {
    final trimmed = content.trim();

    if (trimmed.isEmpty) {
      _errorMessage = 'Message cannot be empty.';
      _notify();
      return false;
    }

    if (trimmed.length > 2000) {
      _errorMessage = 'Message cannot exceed 2000 characters.';
      _notify();
      return false;
    }

    if (_disposed || _isSendingMessage) return false;

    final token = await _getToken();
    if (token == null || _disposed) return false;

    _isSendingMessage = true;
    _errorMessage = null;
    _notify();

    try {
      final message = await _repository.sendGroupMessage(
        groupId: groupId,
        content: trimmed,
        accessToken: token,
      );

      if (_disposed) return false;

      final updated = List<GroupMessageModel>.of(
        _messagesByGroup[groupId] ?? const [],
      );
      updated.removeWhere((item) => item.messageId == message.messageId);
      updated.add(message);

      _messagesByGroup[groupId] = updated;
      _groupMessages = updated;

      return true;
    } catch (error) {
      _errorMessage = _readableError(error, 'Unable to send message.');
      return false;
    } finally {
      _isSendingMessage = false;
      _notify();
    }
  }

  Future<bool> sendGroupVoiceNote({
    required int groupId,
    required String filePath,
    required double durationSeconds,
  }) async {
    if (durationSeconds <= 0 || durationSeconds > 300) {
      _errorMessage = 'Voice note must be between 1 second and 5 minutes.';
      _notify();
      return false;
    }

    if (filePath.trim().isEmpty) {
      _errorMessage = 'Recording file is missing.';
      _notify();
      return false;
    }

    if (_disposed || _isSendingMessage) return false;

    final token = await _getToken();
    if (token == null || _disposed) return false;

    _isSendingMessage = true;
    _errorMessage = null;
    _notify();

    try {
      await _repository.sendGroupVoiceNote(
        groupId: groupId,
        filePath: filePath,
        durationSeconds: durationSeconds,
        accessToken: token,
      );

      if (_disposed) return false;

      final messages = await _repository.getGroupMessages(
        groupId: groupId,
        accessToken: token,
      );

      if (_disposed) return false;

      _messagesByGroup[groupId] = messages;
      _groupMessages = messages;

      return true;
    } catch (error) {
      _errorMessage = _readableError(error, 'Unable to send voice note.');
      return false;
    } finally {
      _isSendingMessage = false;
      _notify();
    }
  }

  Future<bool> clearGroupChat(int groupId) async {
    if (_disposed || _isClearingChat) return false;

    final token = await _getToken();
    if (token == null || _disposed) return false;

    _isClearingChat = true;
    _errorMessage = null;
    _notify();

    try {
      await _repository.clearGroupChat(groupId: groupId, accessToken: token);

      if (_disposed) return false;

      // Backend clear is per-user, not a deletion for everyone.
      _messagesByGroup[groupId] = [];
      if (_messagesByGroup.length == 1 ||
          _groupMessages.any((m) => m.groupId == groupId)) {
        _groupMessages = [];
      }

      return true;
    } catch (error) {
      _errorMessage = _readableError(error, 'Unable to clear chat.');
      return false;
    } finally {
      _isClearingChat = false;
      _notify();
    }
  }

  Future<bool> deleteGroupMessage({
    required int groupId,
    required int messageId,
  }) async {
    if (_disposed || _isDeletingMessage) return false;

    final token = await _getToken();
    if (token == null || _disposed) return false;

    _isDeletingMessage = true;
    _errorMessage = null;
    _notify();

    try {
      await _repository.deleteGroupMessage(
        groupId: groupId,
        messageId: messageId,
        accessToken: token,
      );

      if (_disposed) return false;

      final updated = List<GroupMessageModel>.of(
        _messagesByGroup[groupId] ?? const [],
      );
      updated.removeWhere((m) => m.messageId == messageId);

      _messagesByGroup[groupId] = updated;
      if (_groupMessages.any((m) => m.groupId == groupId)) {
        _groupMessages = updated;
      }

      return true;
    } catch (error) {
      _errorMessage = _readableError(error, 'Unable to delete message.');
      return false;
    } finally {
      _isDeletingMessage = false;
      _notify();
    }
  }

  void clearError() {
    _errorMessage = null;
    _notify();
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}
