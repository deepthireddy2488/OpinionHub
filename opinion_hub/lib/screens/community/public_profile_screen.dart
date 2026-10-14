import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../models/community_feature_models.dart';
import '../../services/community_feature_service.dart';
import '../../widgets/profile_avatar.dart';
import '../questions/question_detail_screen.dart';

class PublicProfileScreen extends StatefulWidget {
  final String publicCode;

  const PublicProfileScreen({super.key, required this.publicCode});

  @override
  State<PublicProfileScreen> createState() => _PublicProfileScreenState();
}

class _PublicProfileScreenState extends State<PublicProfileScreen> {
  final CommunityFeatureService _service = CommunityFeatureService();

  CommunityProfileModel? _profile;
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  @override
  void dispose() {
    _service.dispose();
    super.dispose();
  }

  Future<void> _loadProfile() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final profile = await _service.getPublicProfile(widget.publicCode);

      if (!mounted) return;

      setState(() => _profile = profile);
    } catch (error) {
      if (!mounted) return;

      setState(() => _error = error.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final profile = _profile;
    final colors = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(title: const Text('Public profile')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
          ? Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(_error!, textAlign: TextAlign.center),
                    const SizedBox(height: 12),
                    FilledButton(
                      onPressed: _loadProfile,
                      child: const Text('Try again'),
                    ),
                  ],
                ),
              ),
            )
          : profile == null
          ? const Center(child: Text('Profile not available.'))
          : RefreshIndicator(
              onRefresh: _loadProfile,
              child: ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.all(18),
                children: [
                  Center(
                    child: ProfileAvatar(
                      imageUrl: profile.profilePictureUrl,
                      size: 104,
                      fallbackText: profile.nickname,
                    ),
                  ),
                  const SizedBox(height: 14),
                  Center(
                    child: Text(
                      profile.nickname,
                      style: Theme.of(context).textTheme.headlineSmall
                          ?.copyWith(fontWeight: FontWeight.w800),
                    ),
                  ),
                  const SizedBox(height: 5),
                  Center(
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        SelectableText(
                          profile.publicCode,
                          style: TextStyle(
                            color: colors.primary,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        IconButton(
                          tooltip: 'Copy public code',
                          onPressed: () async {
                            await Clipboard.setData(
                              ClipboardData(text: profile.publicCode),
                            );

                            if (!context.mounted) return;

                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('Public code copied.'),
                              ),
                            );
                          },
                          icon: const Icon(Icons.copy_rounded, size: 18),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 18),
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Row(
                        children: [
                          _ProfileStatistic(
                            label: 'Questions',
                            value: profile.questionCount,
                          ),
                          _ProfileStatistic(
                            label: 'Opinions',
                            value: profile.answerCount,
                          ),
                          _ProfileStatistic(
                            label: 'Reactions',
                            value: profile.receivedReactions,
                          ),
                        ],
                      ),
                    ),
                  ),
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(18),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Reputation',
                            style: Theme.of(context).textTheme.titleLarge
                                ?.copyWith(fontWeight: FontWeight.w800),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            '${profile.reputationPoints} points',
                            style: TextStyle(
                              color: colors.primary,
                              fontSize: 24,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          const SizedBox(height: 14),
                          if (profile.badges.isEmpty)
                            const Text('Keep participating to earn badges.')
                          else
                            ...profile.badges.map(
                              (badge) => ListTile(
                                contentPadding: EdgeInsets.zero,
                                leading: CircleAvatar(
                                  backgroundColor: colors.primaryContainer,
                                  child: Icon(
                                    Icons.workspace_premium,
                                    color: colors.onPrimaryContainer,
                                  ),
                                ),
                                title: Text(
                                  badge.title,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                                subtitle: Text(badge.description),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    'Recent public questions',
                    style: Theme.of(context).textTheme.titleLarge
                        ?.copyWith(fontWeight: FontWeight.w800),
                  ),
                  const SizedBox(height: 10),
                  if (profile.recentQuestions.isEmpty)
                    const Card(
                      child: Padding(
                        padding: EdgeInsets.all(20),
                        child: Text('No public questions yet.'),
                      ),
                    )
                  else
                    ...profile.recentQuestions.map(
                      (question) => Card(
                        key: ValueKey(question.questionId),
                        child: ListTile(
                          title: Text(question.title),
                          subtitle: Text(
                            '❤️ ${question.likeCount}   '
                            '💡 ${question.interestingCount}   '
                            '🤝 ${question.agreeCount}',
                          ),
                          onTap: () {
                            Navigator.of(context).push(
                              MaterialPageRoute<void>(
                                builder: (_) =>
                                    QuestionDetailScreen(question: question),
                              ),
                            );
                          },
                        ),
                      ),
                    ),
                ],
              ),
            ),
    );
  }
}

class _ProfileStatistic extends StatelessWidget {
  final String label;
  final int value;

  const _ProfileStatistic({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Column(
        children: [
          Text(
            '$value',
            style: Theme.of(context).textTheme.titleLarge
                ?.copyWith(fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ],
      ),
    );
  }
}
