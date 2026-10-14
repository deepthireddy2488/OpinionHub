import '../core/network/api_client.dart';
import '../models/community_feature_models.dart';

class CommunityFeatureService {
  final ApiClient _apiClient;

  CommunityFeatureService({ApiClient? apiClient})
    : _apiClient = apiClient ?? ApiClient();

  Future<CommunityProfileModel> searchByPublicCode(String publicCode) async {
    final code = Uri.encodeQueryComponent(publicCode.trim().toUpperCase());

    final response = await _apiClient.get(
      '/community/search?public_code=$code',
    );

    return CommunityProfileModel.fromJson(response);
  }

  Future<CommunityProfileModel> getPublicProfile(String publicCode) async {
    final response = await _apiClient.get(
      '/community/profiles/${Uri.encodeComponent(publicCode)}',
    );

    return CommunityProfileModel.fromJson(response);
  }

  Future<List<CommunityBookmarkModel>> getBookmarks() async {
    final response = await _apiClient.getList('/community/bookmarks/questions');

    return response
        .whereType<Map>()
        .map(
          (item) =>
              CommunityBookmarkModel.fromJson(Map<String, dynamic>.from(item)),
        )
        .toList();
  }

  Future<void> addBookmark(int questionId) async {
    await _apiClient.post('/community/bookmarks/questions/$questionId');
  }

  Future<void> removeBookmark(int questionId) async {
    await _apiClient.delete('/community/bookmarks/questions/$questionId');
  }

  Future<List<CommunityNotificationModel>> getNotifications({
    bool unreadOnly = false,
  }) async {
    final response = await _apiClient.getList(
      '/community/notifications?unread_only=$unreadOnly',
    );

    return response
        .whereType<Map>()
        .map(
          (item) => CommunityNotificationModel.fromJson(
            Map<String, dynamic>.from(item),
          ),
        )
        .toList();
  }

  Future<void> markNotificationRead(int notificationId) async {
    await _apiClient.post('/community/notifications/$notificationId/read');
  }

  Future<void> markAllNotificationsRead() async {
    await _apiClient.post('/community/notifications/read-all');
  }

  Future<CommunityAISummaryModel> summarizeQuestion(int questionId) async {
    final response = await _apiClient.post(
      '/community/questions/$questionId/ai-summary',
    );

    return CommunityAISummaryModel.fromJson(response);
  }

  Future<void> reportContent({
    required String targetType,
    required int targetId,
    required String reason,
    String? description,
  }) async {
    const supportedTypes = {'question', 'answer', 'reply'};

    if (!supportedTypes.contains(targetType)) {
      throw ArgumentError('Unsupported report target type.');
    }

    await _apiClient.post(
      '/reports/$targetType/$targetId',
      body: {
        'reason': reason.trim(),
        'description': description?.trim().isEmpty == true
            ? null
            : description?.trim(),
      },
    );
  }

  Future<List<CommunityAdminReportModel>> getAdminReports({
    String reportStatus = 'pending',
  }) async {
    final encodedStatus = Uri.encodeQueryComponent(reportStatus);

    final response = await _apiClient.getList(
      '/community/admin/reports?report_status=$encodedStatus',
    );

    return response
        .whereType<Map>()
        .map(
          (item) => CommunityAdminReportModel.fromJson(
            Map<String, dynamic>.from(item),
          ),
        )
        .toList();
  }

  Future<void> decideReport({
    required int reportId,
    required String action,
  }) async {
    await _apiClient.post(
      '/community/admin/reports/$reportId/decision',
      body: {'action': action},
    );
  }

  void dispose() {
    _apiClient.dispose();
  }
}
