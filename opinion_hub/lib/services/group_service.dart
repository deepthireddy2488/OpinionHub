import '../core/constants/api_constants.dart';
import '../core/network/api_client.dart';
import '../models/group_message_model.dart';
import '../models/group_model.dart';
import '../models/question_model.dart';

class GroupService {
  final ApiClient _apiClient;

  GroupService({ApiClient? apiClient}) : _apiClient = apiClient ?? ApiClient();

  String _groupPath(int groupId) => '${ApiConstants.groups}/$groupId';

  Future<List<GroupModel>> getMyGroups({required String accessToken}) async {
    final response = await _apiClient.getList(
      ApiConstants.groups,
      accessToken: accessToken,
    );

    return response
        .whereType<Map>()
        .map((item) => GroupModel.fromJson(Map<String, dynamic>.from(item)))
        .toList();
  }

  Future<GroupModel> createGroup({
    required String groupName,
    required String accessToken,
  }) async {
    final response = await _apiClient.post(
      ApiConstants.groups,
      body: {'group_name': groupName.trim()},
      accessToken: accessToken,
    );

    return GroupModel.fromJson(response);
  }

  Future<GroupModel> renameGroup({
    required int groupId,
    required String groupName,
    required String accessToken,
  }) async {
    final response = await _apiClient.post(
      '${_groupPath(groupId)}/rename',
      body: {'group_name': groupName.trim()},
      accessToken: accessToken,
    );

    return GroupModel.fromJson(response);
  }

  Future<List<GroupMemberModel>> getGroupMembers({
    required int groupId,
    required String accessToken,
  }) async {
    final response = await _apiClient.getList(
      '${_groupPath(groupId)}/members',
      accessToken: accessToken,
    );

    return response
        .whereType<Map>()
        .map(
          (item) => GroupMemberModel.fromJson(Map<String, dynamic>.from(item)),
        )
        .toList();
  }

  Future<GroupInvitationModel> inviteUser({
    required int groupId,
    required String publicCode,
    required String accessToken,
  }) async {
    final response = await _apiClient.post(
      '${_groupPath(groupId)}/invitations',
      body: {'public_code': publicCode.trim().toUpperCase()},
      accessToken: accessToken,
    );

    return GroupInvitationModel.fromJson(response);
  }

  Future<List<GroupInvitationModel>> getReceivedInvitations({
    required String accessToken,
  }) async {
    final response = await _apiClient.getList(
      '${ApiConstants.groups}/invitations/received',
      accessToken: accessToken,
    );

    return response
        .whereType<Map>()
        .map(
          (item) =>
              GroupInvitationModel.fromJson(Map<String, dynamic>.from(item)),
        )
        .toList();
  }

  Future<GroupInvitationModel> acceptInvitation({
    required int invitationId,
    required String accessToken,
  }) async {
    final response = await _apiClient.post(
      '${ApiConstants.groups}/invitations/$invitationId/accept',
      accessToken: accessToken,
    );

    return GroupInvitationModel.fromJson(response);
  }

  Future<GroupInvitationModel> rejectInvitation({
    required int invitationId,
    required String accessToken,
  }) async {
    final response = await _apiClient.post(
      '${ApiConstants.groups}/invitations/$invitationId/reject',
      accessToken: accessToken,
    );

    return GroupInvitationModel.fromJson(response);
  }

  Future<void> leaveGroup({
    required int groupId,
    required String accessToken,
  }) async {
    await _apiClient.post(
      '${_groupPath(groupId)}/leave',
      accessToken: accessToken,
    );
  }

  Future<void> removeMember({
    required int groupId,
    required int memberUserId,
    required String accessToken,
  }) async {
    await _apiClient.delete(
      '${_groupPath(groupId)}/members/$memberUserId',
      accessToken: accessToken,
    );
  }

  Future<List<QuestionModel>> getGroupQuestions({
    required int groupId,
    required String accessToken,
  }) async {
    final response = await _apiClient.getList(
      '${_groupPath(groupId)}/questions',
      accessToken: accessToken,
    );

    return response
        .whereType<Map>()
        .map((item) => QuestionModel.fromJson(Map<String, dynamic>.from(item)))
        .toList();
  }

  Future<QuestionModel> createGroupQuestion({
    required int groupId,
    required String title,
    required String accessToken,
  }) async {
    final response = await _apiClient.post(
      '${_groupPath(groupId)}/questions',
      body: {'title': title.trim()},
      accessToken: accessToken,
    );

    return QuestionModel.fromJson(response);
  }

  Future<List<GroupMessageModel>> getGroupMessages({
    required int groupId,
    required String accessToken,
  }) async {
    final response = await _apiClient.getList(
      '${_groupPath(groupId)}/messages',
      accessToken: accessToken,
    );

    return response
        .whereType<Map>()
        .map(
          (item) => GroupMessageModel.fromJson(Map<String, dynamic>.from(item)),
        )
        .toList();
  }

  Future<GroupMessageModel> sendGroupMessage({
    required int groupId,
    required String content,
    required String accessToken,
  }) async {
    final response = await _apiClient.post(
      '${_groupPath(groupId)}/messages',
      body: {'content': content.trim()},
      accessToken: accessToken,
    );

    return GroupMessageModel.fromJson(response);
  }

  Future<Map<String, dynamic>> sendGroupVoiceNote({
    required int groupId,
    required String filePath,
    required double durationSeconds,
    required String accessToken,
  }) {
    return _apiClient.postMultipart(
      '${_groupPath(groupId)}/voice-notes',
      filePath: filePath,
      fields: {'duration_seconds': durationSeconds.toString()},
      accessToken: accessToken,
    );
  }

  Future<void> clearGroupChat({
    required int groupId,
    required String accessToken,
  }) async {
    await _apiClient.post(
      '${_groupPath(groupId)}/messages/clear',
      accessToken: accessToken,
    );
  }

  Future<void> deleteGroupMessage({
    required int groupId,
    required int messageId,
    required String accessToken,
  }) async {
    await _apiClient.delete(
      '${_groupPath(groupId)}/messages/$messageId',
      accessToken: accessToken,
    );
  }
}
