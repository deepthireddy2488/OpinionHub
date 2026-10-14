import '../models/group_message_model.dart';
import '../models/group_model.dart';
import '../models/question_model.dart';
import '../services/group_service.dart';

class GroupRepository {
  final GroupService _service;

  GroupRepository({GroupService? service})
    : _service = service ?? GroupService();

  Future<List<GroupModel>> getMyGroups({required String accessToken}) {
    return _service.getMyGroups(accessToken: accessToken);
  }

  Future<GroupModel> createGroup({
    required String groupName,
    required String accessToken,
  }) {
    return _service.createGroup(groupName: groupName, accessToken: accessToken);
  }

  Future<GroupModel> renameGroup({
    required int groupId,
    required String groupName,
    required String accessToken,
  }) {
    return _service.renameGroup(
      groupId: groupId,
      groupName: groupName,
      accessToken: accessToken,
    );
  }

  Future<List<GroupMemberModel>> getGroupMembers({
    required int groupId,
    required String accessToken,
  }) {
    return _service.getGroupMembers(groupId: groupId, accessToken: accessToken);
  }

  Future<GroupInvitationModel> inviteUser({
    required int groupId,
    required String publicCode,
    required String accessToken,
  }) {
    return _service.inviteUser(
      groupId: groupId,
      publicCode: publicCode,
      accessToken: accessToken,
    );
  }

  Future<List<GroupInvitationModel>> getReceivedInvitations({
    required String accessToken,
  }) {
    return _service.getReceivedInvitations(accessToken: accessToken);
  }

  Future<GroupInvitationModel> acceptInvitation({
    required int invitationId,
    required String accessToken,
  }) {
    return _service.acceptInvitation(
      invitationId: invitationId,
      accessToken: accessToken,
    );
  }

  Future<GroupInvitationModel> rejectInvitation({
    required int invitationId,
    required String accessToken,
  }) {
    return _service.rejectInvitation(
      invitationId: invitationId,
      accessToken: accessToken,
    );
  }

  Future<void> leaveGroup({required int groupId, required String accessToken}) {
    return _service.leaveGroup(groupId: groupId, accessToken: accessToken);
  }

  Future<void> removeMember({
    required int groupId,
    required int memberUserId,
    required String accessToken,
  }) {
    return _service.removeMember(
      groupId: groupId,
      memberUserId: memberUserId,
      accessToken: accessToken,
    );
  }

  Future<List<QuestionModel>> getGroupQuestions({
    required int groupId,
    required String accessToken,
  }) {
    return _service.getGroupQuestions(
      groupId: groupId,
      accessToken: accessToken,
    );
  }

  Future<QuestionModel> createGroupQuestion({
    required int groupId,
    required String title,
    required String accessToken,
  }) {
    return _service.createGroupQuestion(
      groupId: groupId,
      title: title,
      accessToken: accessToken,
    );
  }

  Future<List<GroupMessageModel>> getGroupMessages({
    required int groupId,
    required String accessToken,
  }) {
    return _service.getGroupMessages(
      groupId: groupId,
      accessToken: accessToken,
    );
  }

  Future<GroupMessageModel> sendGroupMessage({
    required int groupId,
    required String content,
    required String accessToken,
  }) {
    return _service.sendGroupMessage(
      groupId: groupId,
      content: content,
      accessToken: accessToken,
    );
  }

  Future<Map<String, dynamic>> sendGroupVoiceNote({
    required int groupId,
    required String filePath,
    required double durationSeconds,
    required String accessToken,
  }) {
    return _service.sendGroupVoiceNote(
      groupId: groupId,
      filePath: filePath,
      durationSeconds: durationSeconds,
      accessToken: accessToken,
    );
  }

  Future<void> clearGroupChat({
    required int groupId,
    required String accessToken,
  }) {
    return _service.clearGroupChat(groupId: groupId, accessToken: accessToken);
  }

  Future<void> deleteGroupMessage({
    required int groupId,
    required int messageId,
    required String accessToken,
  }) {
    return _service.deleteGroupMessage(
      groupId: groupId,
      messageId: messageId,
      accessToken: accessToken,
    );
  }
}
