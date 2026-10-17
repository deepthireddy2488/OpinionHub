import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/constants/api_constants.dart';
import '../../core/network/api_client.dart';
import '../../models/question_model.dart';
import '../../providers/auth_provider.dart';
import '../../providers/question_provider.dart';
import '../../widgets/profile_avatar.dart';
import '../community/community_hub_screen.dart';
import '../groups/groups_screen.dart';
import '../profile/profile_settings_screen.dart';
import '../questions/question_detail_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final ApiClient _apiClient = ApiClient();

  @override
  void initState() {
    super.initState();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        context.read<QuestionProvider>().loadQuestions();
      }
    });
  }

  @override
  void dispose() {
    _apiClient.dispose();
    super.dispose();
  }

  void _showMessage(String message, {bool isError = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: isError
              ? Theme.of(context).colorScheme.error
              : null,
        ),
      );
  }

  String _friendlyError(Object error) {
    if (error is ApiException) return error.message;
    return error.toString().replaceFirst('Exception: ', '');
  }

  Future<void> _createQuestion() async {
    final controller = TextEditingController();

    try {
      final title = await showDialog<String>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: const Text('Ask the community'),
          content: TextField(
            controller: controller,
            autofocus: true,
            minLines: 2,
            maxLines: 4,
            maxLength: 200,
            decoration: const InputDecoration(
              hintText: 'What would you like to ask?',
              border: OutlineInputBorder(),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () {
                final value = controller.text.trim();
                if (value.length < 5) {
                  ScaffoldMessenger.of(dialogContext).showSnackBar(
                    const SnackBar(
                      content: Text('Enter at least 5 characters.'),
                    ),
                  );
                  return;
                }
                Navigator.pop(dialogContext, value);
              },
              child: const Text('Publish'),
            ),
          ],
        ),
      );

      if (title == null || title.isEmpty) return;

      await _apiClient.post(
        ApiConstants.publicQuestions,
        body: {'title': title},
      );
      await context.read<QuestionProvider>().refreshQuestions();
      _showMessage('Your question was published.');
    } catch (error) {
      _showMessage(
        'Could not publish question: ${_friendlyError(error)}',
        isError: true,
      );
    } finally {
      controller.dispose();
    }
  }

  Future<void> _createStandalonePoll() async {
    final titleController = TextEditingController();
    final optionControllers = <TextEditingController>[
      TextEditingController(),
      TextEditingController(),
    ];

    try {
      final poll = await showDialog<Map<String, dynamic>>(
        context: context,
        builder: (dialogContext) => StatefulBuilder(
          builder: (dialogContext, setDialogState) => AlertDialog(
            title: const Text('Create a community poll'),
            content: ConstrainedBox(
              constraints: BoxConstraints(
                maxHeight: MediaQuery.sizeOf(dialogContext).height * 0.62,
              ),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextField(
                      controller: titleController,
                      autofocus: true,
                      minLines: 2,
                      maxLines: 3,
                      maxLength: 200,
                      decoration: const InputDecoration(
                        labelText: 'Poll question',
                        hintText: 'What should the community decide?',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 12),
                    for (var i = 0; i < optionControllers.length; i++)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: Row(
                          children: [
                            Expanded(
                              child: TextField(
                                controller: optionControllers[i],
                                maxLength: 200,
                                decoration: InputDecoration(
                                  labelText: 'Option ${i + 1}',
                                  counterText: '',
                                  border: const OutlineInputBorder(),
                                ),
                              ),
                            ),
                            if (optionControllers.length > 2)
                              IconButton(
                                tooltip: 'Remove option',
                                onPressed: () {
                                  setDialogState(() {
                                    optionControllers.removeAt(i).dispose();
                                  });
                                },
                                icon: const Icon(Icons.remove_circle_outline),
                              ),
                          ],
                        ),
                      ),
                    if (optionControllers.length < 6)
                      Align(
                        alignment: Alignment.centerLeft,
                        child: TextButton.icon(
                          onPressed: () {
                            setDialogState(() {
                              optionControllers.add(TextEditingController());
                            });
                          },
                          icon: const Icon(Icons.add),
                          label: const Text('Add option'),
                        ),
                      ),
                    const SizedBox(height: 4),
                    const Text(
                      'Choose between 2 and 6 options. You can change your vote later.',
                      style: TextStyle(fontSize: 12),
                    ),
                  ],
                ),
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogContext),
                child: const Text('Cancel'),
              ),
              FilledButton(
                onPressed: () {
                  final title = titleController.text.trim();
                  final options = optionControllers
                      .map((controller) => controller.text.trim())
                      .where((option) => option.isNotEmpty)
                      .toList();

                  if (title.length < 5) {
                    ScaffoldMessenger.of(dialogContext).showSnackBar(
                      const SnackBar(
                        content: Text(
                          'The poll question must be at least 5 characters.',
                        ),
                      ),
                    );
                    return;
                  }

                  if (options.length < 2) {
                    ScaffoldMessenger.of(dialogContext).showSnackBar(
                      const SnackBar(
                        content: Text('Enter at least 2 non-empty options.'),
                      ),
                    );
                    return;
                  }

                  Navigator.pop(dialogContext, {
                    'title': title,
                    'options': options,
                  });
                },
                child: const Text('Publish poll'),
              ),
            ],
          ),
        ),
      );

      if (poll == null) return;

      final title = poll['title'] as String;
      final options = List<String>.from(poll['options'] as List);

      await _apiClient.post(
        '${ApiConstants.polls}/standalone',
        body: {
          'title': title,
          'options': options
              .map((option) => {'option_text': option})
              .toList(),
        },
      );

      await context.read<QuestionProvider>().refreshQuestions();
      _showMessage('Your poll was published to the community.');
    } catch (error) {
      _showMessage(
        'Could not publish poll: ${_friendlyError(error)}',
        isError: true,
      );
    } finally {
      titleController.dispose();
      for (final controller in optionControllers) {
        controller.dispose();
      }
    }
  }

  Future<void> _refresh() {
    return context.read<QuestionProvider>().refreshQuestions();
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final questions = context.watch<QuestionProvider>();

    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            Container(
              width: 37,
              height: 37,
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF625BFF), Color(0xFF20BFA9)],
                ),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(
                Icons.forum_rounded,
                color: Colors.white,
                size: 21,
              ),
            ),
            const SizedBox(width: 10),
            const Text('OpinionHub'),
          ],
        ),
        actions: [
          IconButton(
            tooltip: 'Community features',
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => const CommunityHubScreen(),
                ),
              );
            },
            icon: const Icon(Icons.explore_outlined),
          ),
          IconButton(
            tooltip: 'Groups',
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute<void>(builder: (_) => const GroupsScreen()),
              );
            },
            icon: const Icon(Icons.groups_2_outlined),
          ),
          Padding(
            padding: const EdgeInsets.only(right: 10),
            child: IconButton(
              tooltip: 'Profile settings',
              onPressed: () {
                Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => const ProfileSettingsScreen(),
                  ),
                );
              },
              icon: ProfileAvatar(
                imageUrl: auth.user?.profilePictureUrl,
                size: 36,
                fallbackText: auth.user?.nickname ?? 'O',
              ),
            ),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _refresh,
        child: _buildFeed(context, questions, auth.user?.nickname),
      ),
    );
  }

  Widget _buildFeed(
    BuildContext context,
    QuestionProvider provider,
    String? nickname,
  ) {
    final colors = Theme.of(context).colorScheme;

    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(16, 15, 16, 30),
      children: [
        Container(
          padding: const EdgeInsets.all(21),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFF625BFF), Color(0xFF4942D6)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(24),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.auto_awesome_rounded,
                    color: Colors.white,
                    size: 15,
                  ),
                  SizedBox(width: 6),
                  Text(
                    'COMMUNITY PERSPECTIVES',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0.7,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 17),
              Text(
                'Hello, ${nickname?.trim().isNotEmpty == true ? nickname!.trim() : 'there'}!',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  color: Colors.white.withValues(alpha: 0.9),
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 5),
              Text(
                'Every question has more than one perspective.',
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.w800,
                  height: 1.15,
                  letterSpacing: -0.4,
                ),
              ),
              const SizedBox(height: 9),
              Text(
                'Explore opinions and discover how others think.',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Colors.white.withValues(alpha: 0.83),
                  height: 1.4,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 24),
        Row(
          children: [
            Expanded(
              child: Text(
                'Explore questions',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.3,
                ),
              ),
            ),
            Icon(Icons.explore_outlined, color: colors.primary),
          ],
        ),
        const SizedBox(height: 5),
        Text(
          'See what the community is talking about.',
          style: Theme.of(context).textTheme.bodyMedium
              ?.copyWith(color: colors.onSurfaceVariant),
        ),
        const SizedBox(height: 16),
        Wrap(
          spacing: 10,
          runSpacing: 10,
          children: [
            OutlinedButton.icon(
              onPressed: _createQuestion,
              icon: const Icon(Icons.add_comment_outlined),
              label: const Text('Ask question'),
            ),
            FilledButton.icon(
              onPressed: _createStandalonePoll,
              icon: const Icon(Icons.poll_outlined),
              label: const Text('Create poll'),
            ),
          ],
        ),
        const SizedBox(height: 15),
        if (provider.isLoading && provider.questions.isEmpty)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 55),
            child: Center(child: CircularProgressIndicator()),
          )
        else if (provider.errorMessage != null && provider.questions.isEmpty)
          _FeedStatusCard(
            icon: Icons.cloud_off_outlined,
            title: 'Could not load questions',
            message: provider.errorMessage!,
            actionLabel: 'Try again',
            onAction: _refresh,
          )
        else if (provider.questions.isEmpty)
          const _FeedStatusCard(
            icon: Icons.forum_outlined,
            title: 'No public questions yet',
            message:
                'When community members share public questions, '
                'they will appear here.',
          )
        else
          ...provider.questions.map(
            (question) => Padding(
              key: ValueKey(question.questionId),
              padding: const EdgeInsets.only(bottom: 13),
              child: _QuestionCard(
                question: question,
                onTap: () {
                  Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) => QuestionDetailScreen(question: question),
                    ),
                  );
                },
              ),
            ),
          ),
        if (provider.isLoading && provider.questions.isNotEmpty)
          const Padding(
            padding: EdgeInsets.all(12),
            child: Center(
              child: SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            ),
          ),
      ],
    );
  }
}

class _FeedStatusCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String message;
  final String? actionLabel;
  final Future<void> Function()? onAction;

  const _FeedStatusCard({
    required this.icon,
    required this.title,
    required this.message,
    this.actionLabel,
    this.onAction,
  });

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(27),
        child: Column(
          children: [
            Container(
              width: 68,
              height: 68,
              decoration: BoxDecoration(
                color: colors.primaryContainer,
                shape: BoxShape.circle,
              ),
              child: Icon(icon, size: 32, color: colors.onPrimaryContainer),
            ),
            const SizedBox(height: 17),
            Text(
              title,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.titleLarge
                  ?.copyWith(fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 8),
            Text(
              message,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium
                  ?.copyWith(color: colors.onSurfaceVariant, height: 1.45),
            ),
            if (actionLabel != null && onAction != null) ...[
              const SizedBox(height: 18),
              FilledButton.icon(
                onPressed: onAction,
                icon: const Icon(Icons.refresh_rounded),
                label: Text(actionLabel!),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _QuestionCard extends StatelessWidget {
  final QuestionModel question;
  final VoidCallback onTap;

  const _QuestionCard({required this.question, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final code = question.publicCode.trim();

    return Card(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Padding(
          padding: const EdgeInsets.all(17),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  ProfileAvatar(
                    imageUrl: question.profilePictureUrl,
                    size: 42,
                    fallbackText: code.isEmpty ? 'O' : code,
                  ),
                  const SizedBox(width: 11),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          code.isEmpty ? 'Community member' : code,
                          style: Theme.of(context).textTheme.labelLarge
                              ?.copyWith(fontWeight: FontWeight.w800),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          question.pollId != null
                              ? 'Poll question'
                              : 'Public question',
                          style: Theme.of(context).textTheme.labelSmall
                              ?.copyWith(color: colors.onSurfaceVariant),
                        ),
                      ],
                    ),
                  ),
                  Icon(
                    Icons.arrow_outward_rounded,
                    size: 19,
                    color: colors.onSurfaceVariant,
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Text(
                question.title,
                style: Theme.of(context).textTheme.titleMedium
                    ?.copyWith(fontWeight: FontWeight.w700, height: 1.4),
              ),
              const SizedBox(height: 17),
              Wrap(
                spacing: 17,
                runSpacing: 9,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  _ReactionMetric(
                    icon: Icons.favorite_border_rounded,
                    value: question.likeCount,
                    color: Colors.pink,
                  ),
                  _ReactionMetric(
                    icon: Icons.lightbulb_outline_rounded,
                    value: question.interestingCount,
                  ),
                  _ReactionMetric(
                    icon: Icons.handshake_outlined,
                    value: question.agreeCount,
                  ),
                  if (question.pollId != null)
                    const Chip(
                      avatar: Icon(Icons.poll_outlined, size: 16),
                      label: Text('Poll'),
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ReactionMetric extends StatelessWidget {
  final IconData icon;
  final int value;
  final Color? color;

  const _ReactionMetric({required this.icon, required this.value, this.color});

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    return SizedBox(
      width: 44,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 23, color: color ?? colors.onSurfaceVariant),
          const SizedBox(height: 4),
          Text(
            '$value',
            style: Theme.of(context).textTheme.labelMedium
                ?.copyWith(fontWeight: FontWeight.w700),
          ),
        ],
      ),
    );
  }
}
