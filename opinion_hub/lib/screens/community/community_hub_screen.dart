import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/community_feature_models.dart';
import '../../providers/auth_provider.dart';
import '../../services/community_feature_service.dart';
import '../../widgets/profile_avatar.dart';
import '../questions/question_detail_screen.dart';
import 'public_profile_screen.dart';

class CommunityHubScreen extends StatelessWidget {
  const CommunityHubScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final isAdmin = context.watch<AuthProvider>().user?.isAdmin ?? false;

    final tabs = <Tab>[
      const Tab(icon: Icon(Icons.search_rounded), text: 'Find people'),
      const Tab(icon: Icon(Icons.bookmark_border_rounded), text: 'Saved'),
      const Tab(
        icon: Icon(Icons.notifications_none_rounded),
        text: 'Notifications',
      ),
      if (isAdmin)
        const Tab(icon: Icon(Icons.shield_outlined), text: 'Moderation'),
    ];

    final screens = <Widget>[
      const _SearchPeopleTab(),
      const _SavedQuestionsTab(),
      const _NotificationsTab(),
      if (isAdmin) const _ModerationTab(),
    ];

    return DefaultTabController(
      length: tabs.length,
      child: Scaffold(
        appBar: AppBar(
          title: const Text(
            'Community',
            style: TextStyle(fontWeight: FontWeight.w800),
          ),
          bottom: TabBar(isScrollable: true, tabs: tabs),
        ),
        body: TabBarView(children: screens),
      ),
    );
  }
}

class _SearchPeopleTab extends StatefulWidget {
  const _SearchPeopleTab();

  @override
  State<_SearchPeopleTab> createState() => _SearchPeopleTabState();
}

class _SearchPeopleTabState extends State<_SearchPeopleTab> {
  final TextEditingController _controller = TextEditingController();
  final CommunityFeatureService _service = CommunityFeatureService();

  bool _loading = false;
  String? _error;
  CommunityProfileModel? _result;

  @override
  void dispose() {
    _controller.dispose();
    _service.dispose();
    super.dispose();
  }

  Future<void> _search() async {
    final code = _controller.text.trim();

    if (code.isEmpty) {
      setState(() {
        _error = 'Enter the public code you want to find.';
        _result = null;
      });
      return;
    }

    setState(() {
      _loading = true;
      _error = null;
      _result = null;
    });

    try {
      final profile = await _service.searchByPublicCode(code);

      if (!mounted) return;

      setState(() => _result = profile);
    } catch (error) {
      if (!mounted) return;

      setState(() {
        _error = error.toString().replaceFirst(
          RegExp(r'^(ApiException|Exception)(\(\d+\))?:\s*'),
          '',
        );
      });
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    return ListView(
      padding: const EdgeInsets.all(18),
      children: [
        Text(
          'Find someone on OpinionHub',
          style: Theme.of(context).textTheme.headlineSmall
              ?.copyWith(fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: 8),
        Text(
          'Search using their unique public code.',
          style: TextStyle(color: colors.onSurfaceVariant),
        ),
        const SizedBox(height: 20),
        TextField(
          controller: _controller,
          textCapitalization: TextCapitalization.characters,
          textInputAction: TextInputAction.search,
          onSubmitted: (_) => _search(),
          decoration: InputDecoration(
            hintText: 'OP-123456',
            prefixIcon: const Icon(Icons.person_search_rounded),
            border: const OutlineInputBorder(),
            suffixIcon: IconButton(
              tooltip: 'Search',
              onPressed: _loading ? null : _search,
              icon: const Icon(Icons.search_rounded),
            ),
          ),
        ),
        const SizedBox(height: 12),
        FilledButton.icon(
          onPressed: _loading ? null : _search,
          icon: _loading
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.search_rounded),
          label: Text(_loading ? 'Searching...' : 'Find profile'),
        ),
        if (_error != null) ...[
          const SizedBox(height: 14),
          Text(_error!, style: TextStyle(color: colors.error)),
        ],
        if (_result != null) ...[
          const SizedBox(height: 20),
          Card(
            child: ListTile(
              contentPadding: const EdgeInsets.all(14),
              leading: ProfileAvatar(
                imageUrl: _result!.profilePictureUrl,
                size: 54,
                fallbackText: _result!.nickname,
              ),
              title: Text(
                _result!.nickname,
                style: const TextStyle(fontWeight: FontWeight.w800),
              ),
              subtitle: Text(_result!.publicCode),
              trailing: const Icon(Icons.arrow_forward_ios_rounded),
              onTap: () {
                Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) =>
                        PublicProfileScreen(publicCode: _result!.publicCode),
                  ),
                );
              },
            ),
          ),
        ],
      ],
    );
  }
}

class _SavedQuestionsTab extends StatefulWidget {
  const _SavedQuestionsTab();

  @override
  State<_SavedQuestionsTab> createState() => _SavedQuestionsTabState();
}

class _SavedQuestionsTabState extends State<_SavedQuestionsTab> {
  final CommunityFeatureService _service = CommunityFeatureService();

  List<CommunityBookmarkModel> _bookmarks = [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _load();
    });
  }

  @override
  void dispose() {
    _service.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final bookmarks = await _service.getBookmarks();

      if (!mounted) return;

      setState(() => _bookmarks = bookmarks);
    } catch (error) {
      if (!mounted) return;

      setState(() => _error = error.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _remove(CommunityBookmarkModel bookmark) async {
    try {
      await _service.removeBookmark(bookmark.question.questionId);

      if (!mounted) return;

      setState(() {
        _bookmarks.removeWhere(
          (item) => item.bookmarkId == bookmark.bookmarkId,
        );
      });
    } catch (error) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Unable to remove saved question: $error')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading && _bookmarks.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_error != null && _bookmarks.isEmpty) {
      return _SimpleErrorView(message: _error!, onRetry: _load);
    }

    if (_bookmarks.isEmpty) {
      return RefreshIndicator(
        onRefresh: _load,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(30),
          children: const [
            SizedBox(height: 70),
            Icon(Icons.bookmark_border_rounded, size: 52),
            SizedBox(height: 14),
            Center(
              child: Text(
                'No saved questions yet.',
                style: TextStyle(fontWeight: FontWeight.w700),
              ),
            ),
            SizedBox(height: 8),
            Center(
              child: Text(
                'Save interesting questions to find them here.',
                textAlign: TextAlign.center,
              ),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _load,
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: _bookmarks.length,
        itemBuilder: (context, index) {
          final bookmark = _bookmarks[index];
          final question = bookmark.question;

          return Card(
            margin: const EdgeInsets.only(bottom: 12),
            child: ListTile(
              contentPadding: const EdgeInsets.fromLTRB(16, 8, 8, 8),
              title: Text(
                question.title,
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
              subtitle: Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(
                  '${question.publicCode}  ·  '
                  '❤️ ${question.likeCount}  ·  '
                  '💡 ${question.interestingCount}',
                ),
              ),
              onTap: () {
                Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => QuestionDetailScreen(question: question),
                  ),
                );
              },
              trailing: IconButton(
                tooltip: 'Remove saved question',
                onPressed: () => _remove(bookmark),
                icon: const Icon(Icons.bookmark_remove_outlined),
              ),
            ),
          );
        },
      ),
    );
  }
}

class _NotificationsTab extends StatefulWidget {
  const _NotificationsTab();

  @override
  State<_NotificationsTab> createState() => _NotificationsTabState();
}

class _NotificationsTabState extends State<_NotificationsTab> {
  final CommunityFeatureService _service = CommunityFeatureService();

  List<CommunityNotificationModel> _notifications = [];
  bool _loading = true;
  String? _error;
  bool _unreadOnly = false;

  @override
  void initState() {
    super.initState();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _load();
    });
  }

  @override
  void dispose() {
    _service.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final items = await _service.getNotifications(unreadOnly: _unreadOnly);

      if (!mounted) return;

      setState(() => _notifications = items);
    } catch (error) {
      if (!mounted) return;

      setState(() => _error = error.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _markRead(CommunityNotificationModel notification) async {
    if (notification.isRead) return;

    try {
      await _service.markNotificationRead(notification.notificationId);

      if (mounted) await _load();
    } catch (error) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Unable to mark notification as read: $error')),
      );
    }
  }

  Future<void> _markAllRead() async {
    try {
      await _service.markAllNotificationsRead();

      if (mounted) await _load();
    } catch (error) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Unable to update notifications: $error')),
      );
    }
  }

  IconData _notificationIcon(String type) {
    switch (type) {
      case 'answer':
      case 'reply':
        return Icons.chat_bubble_outline_rounded;
      case 'question_reaction':
      case 'answer_reaction':
        return Icons.favorite_border_rounded;
      case 'group_invitation':
        return Icons.groups_2_outlined;
      default:
        return Icons.notifications_none_rounded;
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  'Your activity',
                  style: Theme.of(context).textTheme.titleMedium
                      ?.copyWith(fontWeight: FontWeight.w800),
                ),
              ),
              TextButton(
                onPressed: _loading ? null : _markAllRead,
                child: const Text('Mark all read'),
              ),
              PopupMenuButton<bool>(
                tooltip: 'Filter notifications',
                onSelected: (value) {
                  setState(() => _unreadOnly = value);
                  _load();
                },
                itemBuilder: (_) => const [
                  PopupMenuItem(value: false, child: Text('All notifications')),
                  PopupMenuItem(value: true, child: Text('Unread only')),
                ],
                icon: const Icon(Icons.filter_list_rounded),
              ),
            ],
          ),
        ),
        Expanded(
          child: _loading && _notifications.isEmpty
              ? const Center(child: CircularProgressIndicator())
              : _error != null && _notifications.isEmpty
              ? _SimpleErrorView(message: _error!, onRetry: _load)
              : _notifications.isEmpty
              ? const Center(
                  child: Padding(
                    padding: EdgeInsets.all(28),
                    child: Text(
                      'You are all caught up. '
                      'New activity will appear here.',
                      textAlign: TextAlign.center,
                    ),
                  ),
                )
              : RefreshIndicator(
                  onRefresh: _load,
                  child: ListView.builder(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.fromLTRB(12, 4, 12, 20),
                    itemCount: _notifications.length,
                    itemBuilder: (context, index) {
                      final notification = _notifications[index];

                      return Card(
                        color: notification.isRead
                            ? null
                            : colors.primaryContainer.withValues(alpha: 0.3),
                        child: ListTile(
                          leading: ProfileAvatar(
                            imageUrl: notification.actorProfilePictureUrl,
                            size: 42,
                            fallbackText: notification.actorNickname ?? 'O',
                          ),
                          title: Text(
                            notification.title,
                            style: TextStyle(
                              fontWeight: notification.isRead
                                  ? FontWeight.w500
                                  : FontWeight.w800,
                            ),
                          ),
                          subtitle: Padding(
                            padding: const EdgeInsets.only(top: 4),
                            child: Text(notification.body),
                          ),
                          trailing: Icon(
                            _notificationIcon(notification.notificationType),
                          ),
                          onTap: () => _markRead(notification),
                        ),
                      );
                    },
                  ),
                ),
        ),
      ],
    );
  }
}

class _ModerationTab extends StatefulWidget {
  const _ModerationTab();

  @override
  State<_ModerationTab> createState() => _ModerationTabState();
}

class _ModerationTabState extends State<_ModerationTab> {
  final CommunityFeatureService _service = CommunityFeatureService();

  List<CommunityAdminReportModel> _reports = [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _load();
    });
  }

  @override
  void dispose() {
    _service.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final reports = await _service.getAdminReports();

      if (!mounted) return;

      setState(() => _reports = reports);
    } catch (error) {
      if (!mounted) return;

      setState(() => _error = error.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _decide(CommunityAdminReportModel report, String action) async {
    try {
      await _service.decideReport(reportId: report.reportId, action: action);

      if (mounted) await _load();
    } catch (error) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Unable to update report: $error')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading && _reports.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_error != null && _reports.isEmpty) {
      return _SimpleErrorView(message: _error!, onRetry: _load);
    }

    if (_reports.isEmpty) {
      return RefreshIndicator(
        onRefresh: _load,

        // ListView is not constructed with const here.
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(30),
          children: const [
            SizedBox(height: 60),
            Icon(Icons.verified_user_outlined, size: 50),
            SizedBox(height: 12),
            Center(child: Text('No pending reports.')),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _load,
      child: ListView.builder(
        padding: const EdgeInsets.all(14),
        itemCount: _reports.length,
        itemBuilder: (context, index) {
          final report = _reports[index];

          final target = report.questionId != null
              ? 'Question #${report.questionId}'
              : report.answerId != null
              ? 'Answer #${report.answerId}'
              : 'Reply #${report.replyId}';

          return Card(
            margin: const EdgeInsets.only(bottom: 12),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '$target · ${report.reason}',
                    style: const TextStyle(fontWeight: FontWeight.w800),
                  ),
                  const SizedBox(height: 8),
                  Text(report.description ?? 'No additional description.'),
                  const SizedBox(height: 8),
                  Text(
                    'AI status: ${report.aiStatus ?? 'not available'}'
                    ' · Flagged: '
                    '${report.aiFlagged?.toString() ?? 'unknown'}',
                  ),
                  const SizedBox(height: 14),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      OutlinedButton(
                        onPressed: () => _decide(report, 'reviewed'),
                        child: const Text('Mark reviewed'),
                      ),
                      FilledButton.tonal(
                        onPressed: () => _decide(report, 'rejected'),
                        child: const Text('Reject report'),
                      ),
                      FilledButton(
                        onPressed: () => _decide(report, 'hide'),
                        child: const Text('Hide content'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

class _SimpleErrorView extends StatelessWidget {
  final String message;
  final Future<void> Function() onRetry;

  const _SimpleErrorView({required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.cloud_off_outlined, size: 42),
            const SizedBox(height: 12),
            Text(message, textAlign: TextAlign.center),
            const SizedBox(height: 14),
            FilledButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh_rounded),
              label: const Text('Try again'),
            ),
          ],
        ),
      ),
    );
  }
}