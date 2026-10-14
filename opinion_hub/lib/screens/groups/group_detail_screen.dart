import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/group_model.dart';
import '../../models/question_model.dart';
import '../../providers/group_provider.dart';
import '../questions/question_detail_screen.dart';
import 'group_chat_screen.dart';
import 'group_info_screen.dart';
import '../../widgets/profile_avatar.dart';

class GroupDetailScreen extends StatefulWidget {
  final GroupModel group;

  const GroupDetailScreen({super.key, required this.group});

  @override
  State<GroupDetailScreen> createState() => _GroupDetailScreenState();
}

class _GroupDetailScreenState extends State<GroupDetailScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;
  late GroupModel _group;

  @override
  void initState() {
    super.initState();

    _group = widget.group;
    _tabController = TabController(length: 2, vsync: this);
    _tabController.addListener(_onTabChanged);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        context.read<GroupProvider>().loadGroupQuestions(_group.groupId);
      }
    });
  }

  void _onTabChanged() {
    if (_tabController.indexIsChanging || !mounted) return;
    setState(() {});
  }

  @override
  void dispose() {
    _tabController.removeListener(_onTabChanged);
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _openGroupInfo() async {
    final result = await Navigator.of(context).push<GroupInfoResult>(
      MaterialPageRoute(builder: (_) => GroupInfoScreen(group: _group)),
    );

    if (!mounted || result == null) return;

    if (result.left) {
      Navigator.of(context).pop(true);
      return;
    }

    if (result.group != null) {
      setState(() {
        _group = result.group!;
      });
    }
  }

  Future<void> _showAskGroupDialog() async {
    final controller = TextEditingController();

    try {
      await showDialog<void>(
        context: context,
        builder: (dialogContext) {
          bool submitting = false;
          String? validationError;

          return StatefulBuilder(
            builder: (context, setDialogState) {
              final provider = this.context.read<GroupProvider>();

              return AlertDialog(
                title: const Row(
                  children: [
                    Icon(Icons.forum_outlined),
                    SizedBox(width: 10),
                    Text('Ask the group'),
                  ],
                ),
                content: TextField(
                  controller: controller,
                  autofocus: true,
                  maxLines: 4,
                  maxLength: 200,
                  textCapitalization: TextCapitalization.sentences,
                  decoration: InputDecoration(
                    hintText: 'What would you like to ask?',
                    alignLabelWithHint: true,
                    errorText: validationError,
                  ),
                ),
                actions: [
                  TextButton(
                    onPressed: submitting
                        ? null
                        : () => Navigator.of(dialogContext).pop(),
                    child: const Text('Cancel'),
                  ),
                  FilledButton.icon(
                    onPressed: submitting
                        ? null
                        : () async {
                            final title = controller.text.trim();

                            if (title.length < 5) {
                              setDialogState(() {
                                validationError = 'Question must contain at least 5 characters.';
                              });
                              return;
                            }

                            setDialogState(() {
                              submitting = true;
                              validationError = null;
                            });

                            final success = await provider.createGroupQuestion(
                              groupId: _group.groupId,
                              title: title,
                            );

                            if (!mounted || !dialogContext.mounted) {
                              return;
                            }

                            if (success) {
                              // Pop the dialog's route, not the group screen.
                              Navigator.of(dialogContext).pop();
                              _tabController.animateTo(0);

                              ScaffoldMessenger.of(this.context)
                                ..hideCurrentSnackBar()
                                ..showSnackBar(
                                  const SnackBar(
                                    content: Text(
                                      'Question posted to the group.',
                                    ),
                                  ),
                                );
                            } else {
                              setDialogState(() {
                                submitting = false;
                                validationError =
                                    provider.errorMessage ??
                                    'Unable to post the question.';
                              });
                            }
                          },
                    icon: submitting
                        ? const SizedBox(
                            width: 17,
                            height: 17,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.send_rounded),
                    label: Text(submitting ? 'Posting…' : 'Post question'),
                  ),
                ],
              );
            },
          );
        },
      );
    } finally {
      controller.dispose();
    }
  }

  Future<void> _refreshQuestions() {
    return context.read<GroupProvider>().loadGroupQuestions(_group.groupId);
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final isQuestionsTab = _tabController.index == 0;

    final trimmedName = _group.groupName.trim();
    final initial = trimmedName.isEmpty ? '?' : trimmedName[0].toUpperCase();

    return Scaffold(
      appBar: AppBar(
        titleSpacing: 4,
        title: Row(
          children: [
            Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF625BFF), Color(0xFF20BFA9)],
                ),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Center(
                child: Text(
                  initial,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 11),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _group.groupName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.titleMedium
                        ?.copyWith(fontWeight: FontWeight.w800),
                  ),
                  const SizedBox(height: 3),
                  Row(
                    children: [
                      Icon(
                        Icons.lock_outline_rounded,
                        size: 12,
                        color: colors.onSurfaceVariant,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        'Private group',
                        style: Theme.of(context).textTheme.labelSmall
                            ?.copyWith(color: colors.onSurfaceVariant),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            tooltip: 'Group information',
            onPressed: _openGroupInfo,
            icon: const Icon(Icons.info_outline_rounded),
          ),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(62),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
            child: Container(
              decoration: BoxDecoration(
                color: colors.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(16),
              ),
              child: TabBar(
                controller: _tabController,
                indicatorSize: TabBarIndicatorSize.tab,
                indicator: BoxDecoration(
                  color: colors.primaryContainer,
                  borderRadius: BorderRadius.circular(13),
                ),
                tabs: const [
                  Tab(
                    icon: Icon(Icons.forum_outlined, size: 19),
                    text: 'Questions',
                  ),
                  Tab(
                    icon: Icon(Icons.chat_bubble_outline_rounded, size: 19),
                    text: 'Chat',
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _QuestionsTab(
            groupId: _group.groupId,
            onRefresh: _refreshQuestions,
            onAskQuestion: _showAskGroupDialog,
          ),
          GroupChatView(group: _group),
        ],
      ),
      floatingActionButton: isQuestionsTab
          ? FloatingActionButton.extended(
              onPressed: _showAskGroupDialog,
              icon: const Icon(Icons.add_rounded),
              label: const Text('Ask a question'),
            )
          : null,
    );
  }
}

class _QuestionsTab extends StatelessWidget {
  final int groupId;
  final Future<void> Function() onRefresh;
  final VoidCallback onAskQuestion;

  const _QuestionsTab({
    required this.groupId,
    required this.onRefresh,
    required this.onAskQuestion,
  });

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<GroupProvider>();
    final colors = Theme.of(context).colorScheme;

    final questions = provider.groupQuestionsFor(groupId);
    final isLoading = provider.isLoadingQuestionsFor(groupId);
    final error = provider.questionErrorFor(groupId);

    return RefreshIndicator(
      onRefresh: onRefresh,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(16, 18, 16, 110),
        children: [
          Text(
            'Group discussions',
            style: Theme.of(context).textTheme.headlineSmall
                ?.copyWith(fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 5),
          Text(
            'Share a question and hear different perspectives.',
            style: Theme.of(context).textTheme.bodyMedium
                ?.copyWith(color: colors.onSurfaceVariant),
          ),
          const SizedBox(height: 18),
          if (isLoading && questions.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 60),
              child: Center(child: CircularProgressIndicator()),
            )
          else if (error != null && questions.isEmpty)
            _QuestionState(
              icon: Icons.cloud_off_outlined,
              title: 'Couldn’t load questions',
              description: error,
              actionLabel: 'Try again',
              onAction: onRefresh,
            )
          else if (questions.isEmpty)
            _QuestionState(
              icon: Icons.forum_outlined,
              title: 'Start the conversation',
              description: 'Ask your first question and invite the group to share their opinions.',
              actionLabel: 'Ask the group',
              onAction: () async => onAskQuestion(),
            )
          else
            ...questions.map(
              (question) => Padding(
                key: ValueKey(question.questionId),
                padding: const EdgeInsets.only(bottom: 12),
                child: _GroupQuestionCard(question: question),
              ),
            ),
        ],
      ),
    );
  }
}

class _QuestionState extends StatelessWidget {
  final IconData icon;
  final String title;
  final String description;
  final String? actionLabel;
  final Future<void> Function()? onAction;

  const _QuestionState({
    required this.icon,
    required this.title,
    required this.description,
    this.actionLabel,
    this.onAction,
  });

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    return Card(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 30),
        child: Column(
          children: [
            Container(
              width: 70,
              height: 70,
              decoration: BoxDecoration(
                color: colors.primaryContainer,
                shape: BoxShape.circle,
              ),
              child: Icon(icon, size: 33, color: colors.onPrimaryContainer),
            ),
            const SizedBox(height: 16),
            Text(
              title,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.titleLarge
                  ?.copyWith(fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 8),
            Text(
              description,
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

class _GroupQuestionCard extends StatelessWidget {
  final QuestionModel question;

  const _GroupQuestionCard({required this.question});

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    return Card(
      child: InkWell(
        onTap: () {
          Navigator.of(context).push(
            MaterialPageRoute(
              builder: (_) => QuestionDetailScreen(question: question),
            ),
          );
        },
        borderRadius: BorderRadius.circular(20),
        child: Padding(
          padding: const EdgeInsets.all(17),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 42,
                    height: 42,
                    decoration: BoxDecoration(
                      color: colors.primaryContainer,
                      borderRadius: BorderRadius.circular(13),
                    ),
                    child: Icon(
                      question.pollId != null
                          ? Icons.poll_outlined
                          : Icons.forum_outlined,
                      color: colors.onPrimaryContainer,
                    ),
                  ),
                  const SizedBox(width: 11),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          question.publicCode,
                          style: Theme.of(context).textTheme.labelLarge
                              ?.copyWith(
                                color: colors.primary,
                                fontWeight: FontWeight.w800,
                              ),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          question.pollId != null
                              ? 'Poll discussion'
                              : 'Group question',
                          style: Theme.of(context).textTheme.labelSmall
                              ?.copyWith(color: colors.onSurfaceVariant),
                        ),
                      ],
                    ),
                  ),
                  Icon(
                    Icons.arrow_forward_ios_rounded,
                    size: 15,
                    color: colors.onSurfaceVariant,
                  ),
                ],
              ),
              const SizedBox(height: 15),
              Text(
                question.title,
                style: Theme.of(context).textTheme.titleMedium
                    ?.copyWith(fontWeight: FontWeight.w700, height: 1.4),
              ),
              const SizedBox(height: 15),
              Wrap(
                spacing: 15,
                runSpacing: 9,
                children: [
                  _QuestionMetric(
                    icon: Icons.thumb_up_outlined,
                    value: question.likeCount,
                  ),
                  _QuestionMetric(
                    icon: Icons.lightbulb_outline_rounded,
                    value: question.interestingCount,
                  ),
                  _QuestionMetric(
                    icon: Icons.handshake_outlined,
                    value: question.agreeCount,
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

class _QuestionMetric extends StatelessWidget {
  final IconData icon;
  final int value;

  const _QuestionMetric({required this.icon, required this.value});

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 16, color: colors.onSurfaceVariant),
        const SizedBox(width: 5),
        Text(
          '$value',
          style: Theme.of(context).textTheme.labelMedium
              ?.copyWith(fontWeight: FontWeight.w700),
        ),
      ],
    );
  }
}
