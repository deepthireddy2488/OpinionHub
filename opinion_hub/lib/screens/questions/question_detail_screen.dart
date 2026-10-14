import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/constants/api_constants.dart';
import '../../core/network/api_client.dart';
import '../../models/answer_model.dart';
import '../../models/poll_model.dart';
import '../../models/question_model.dart';
import '../../models/reply_model.dart';
import '../../providers/answer_provider.dart';
import '../../providers/poll_provider.dart';
import '../../providers/question_provider.dart';
import '../../providers/reaction_provider.dart';
import '../../providers/reply_provider.dart';
import '../../services/community_feature_service.dart';
import '../../widgets/profile_avatar.dart';
import '../../widgets/report_content_dialog.dart';
import '../community/ai_summary_screen.dart';

class QuestionDetailScreen extends StatefulWidget {
  final QuestionModel question;

  const QuestionDetailScreen({super.key, required this.question});

  @override
  State<QuestionDetailScreen> createState() => _QuestionDetailScreenState();
}

class _QuestionDetailScreenState extends State<QuestionDetailScreen> {
  late QuestionModel _question;

  final TextEditingController _answerController = TextEditingController();

  final ApiClient _apiClient = ApiClient();

  final CommunityFeatureService _featureService = CommunityFeatureService();

  bool _savingBookmark = false;

  @override
  void initState() {
    super.initState();
    _question = widget.question;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        context.read<AnswerProvider>().loadAnswers(_question.questionId);
      }
    });
  }

  @override
  void didUpdateWidget(covariant QuestionDetailScreen oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (oldWidget.question.questionId != widget.question.questionId) {
      _question = widget.question;

      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          context.read<AnswerProvider>().loadAnswers(_question.questionId);
        }
      });
    }
  }

  @override
  void dispose() {
    _answerController.dispose();
    _apiClient.dispose();
    _featureService.dispose();
    super.dispose();
  }

  Future<void> _refreshQuestionFromApi() async {
    final questionId = _question.questionId;

    try {
      final response = await _apiClient.get(
        '${ApiConstants.questions}/$questionId',
      );

      if (!mounted || _question.questionId != questionId) {
        return;
      }

      final updatedQuestion = QuestionModel.fromJson(response);

      setState(() {
        _question = updatedQuestion;
      });

      if (updatedQuestion.groupId == null) {
        await context.read<QuestionProvider>().refreshQuestions();
      }
    } catch (_) {
      // Retain the existing server-confirmed data if refreshing fails.
    }
  }

  Future<void> _refresh() async {
    final questionId = _question.questionId;

    await context.read<AnswerProvider>().loadAnswers(
      questionId,
      forceRefresh: true,
    );

    if (!mounted || _question.questionId != questionId) {
      return;
    }

    await _refreshQuestionFromApi();

    if (!mounted || _question.questionId != questionId) {
      return;
    }

    final pollId = _question.pollId;

    if (pollId != null) {
      await context.read<PollProvider>().loadPoll(pollId);
    }
  }

  Future<void> _saveBookmark() async {
    if (_savingBookmark) return;

    setState(() => _savingBookmark = true);

    try {
      await _featureService.addBookmark(_question.questionId);

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Question saved to your bookmarks.')),
      );
    } catch (error) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Unable to save question: $error')),
      );
    } finally {
      if (mounted) {
        setState(() => _savingBookmark = false);
      }
    }
  }

  Future<void> _submitAnswer() async {
    final questionId = _question.questionId;
    final provider = context.read<AnswerProvider>();

    final success = await provider.submitAnswer(
      questionId: questionId,
      content: _answerController.text,
    );

    if (!mounted || _question.questionId != questionId) {
      return;
    }

    if (success) {
      _answerController.clear();
      FocusScope.of(context).unfocus();

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Your opinion was added.')));
    } else {
      final message = provider.errorForQuestion(questionId);

      if (message != null) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(message)));
      }
    }
  }

  Future<void> _reactToQuestion(String reactionType) async {
    final questionId = _question.questionId;
    final provider = context.read<ReactionProvider>();

    final success = await provider.reactToQuestion(
      questionId: questionId,
      reactionType: reactionType,
    );

    if (!mounted || _question.questionId != questionId) {
      return;
    }

    if (!success) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(provider.errorMessage ?? 'Unable to save reaction.'),
        ),
      );
      return;
    }

    await _refreshQuestionFromApi();

    if (!mounted) return;

    ScaffoldMessenger.of(context)
        .showSnackBar(const SnackBar(content: Text('Reaction saved.')));
  }

  Future<void> _showQuestionReport() {
    return ReportContentDialog.show(
      context,
      targetType: 'question',
      targetId: _question.questionId,
    );
  }

  @override
  Widget build(BuildContext context) {
    final answerProvider = context.watch<AnswerProvider>();
    final questionId = _question.questionId;

    final answers = answerProvider.answersForQuestion(questionId);
    final isLoading = answerProvider.isLoadingForQuestion(questionId);
    final error = answerProvider.errorForQuestion(questionId);
    final isSubmitting = answerProvider.isSubmittingForQuestion(questionId);

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Discussion',
          style: TextStyle(fontWeight: FontWeight.w700),
        ),
        actions: [
          IconButton(
            tooltip: 'Save question',
            onPressed: _savingBookmark ? null : _saveBookmark,
            icon: _savingBookmark
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.bookmark_add_outlined),
          ),
          IconButton(
            tooltip: 'Summarize perspectives with AI',
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => AISummaryScreen(questionId: questionId),
                ),
              );
            },
            icon: const Icon(Icons.auto_awesome_rounded),
          ),
          PopupMenuButton<String>(
            tooltip: 'More options',
            onSelected: (value) {
              if (value == 'report') {
                _showQuestionReport();
              }
            },
            itemBuilder: (_) => const [
              PopupMenuItem(
                value: 'report',
                child: Row(
                  children: [
                    Icon(Icons.flag_outlined),
                    SizedBox(width: 10),
                    Text('Report question'),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _refresh,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 28),
          children: [
            _buildQuestionCard(context),
            if (_question.pollId != null) ...[
              const SizedBox(height: 12),
              _PollSection(pollId: _question.pollId!),
            ],
            const SizedBox(height: 22),
            Text(
              'Community opinions',
              style: Theme.of(context).textTheme.titleLarge
                  ?.copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 12),
            if (isLoading && answers.isEmpty)
              const Padding(
                padding: EdgeInsets.all(32),
                child: Center(child: CircularProgressIndicator()),
              )
            else if (error != null && answers.isEmpty)
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    children: [
                      const Icon(Icons.cloud_off_outlined, size: 36),
                      const SizedBox(height: 10),
                      Text(error, textAlign: TextAlign.center),
                      const SizedBox(height: 12),
                      OutlinedButton.icon(
                        onPressed: () {
                          context.read<AnswerProvider>().loadAnswers(
                            questionId,
                            forceRefresh: true,
                          );
                        },
                        icon: const Icon(Icons.refresh_rounded),
                        label: const Text('Try again'),
                      ),
                    ],
                  ),
                ),
              )
            else if (answers.isEmpty)
              const Card(
                child: Padding(
                  padding: EdgeInsets.all(22),
                  child: Text(
                    'No opinions yet. Be the first to share your perspective.',
                    textAlign: TextAlign.center,
                  ),
                ),
              )
            else
              ...answers.map(
                (answer) =>
                    _AnswerCard(key: ValueKey(answer.answerId), answer: answer),
              ),
          ],
        ),
      ),
      bottomNavigationBar: SafeArea(
        minimum: const EdgeInsets.fromLTRB(16, 8, 16, 12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Expanded(
              child: TextField(
                controller: _answerController,
                minLines: 1,
                maxLines: 4,
                textCapitalization: TextCapitalization.sentences,
                decoration: const InputDecoration(
                  hintText: 'Share your opinion...',
                ),
                onSubmitted: (_) {
                  if (!isSubmitting) {
                    _submitAnswer();
                  }
                },
              ),
            ),
            const SizedBox(width: 10),
            IconButton.filled(
              tooltip: 'Submit opinion',
              onPressed: isSubmitting ? null : _submitAnswer,
              icon: isSubmitting
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.send_rounded),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildQuestionCard(BuildContext context) {
    final code = _question.publicCode.trim();

    return Card(
      clipBehavior: Clip.antiAlias,
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                ProfileAvatar(
                  imageUrl: _question.profilePictureUrl,
                  size: 44,
                  fallbackText: code.isEmpty ? 'O' : code,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    code.isEmpty ? 'Community member' : code,
                    style: Theme.of(context).textTheme.titleMedium
                        ?.copyWith(fontWeight: FontWeight.w700),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 22),
            Text(
              _question.title,
              style: Theme.of(context).textTheme.headlineSmall
                  ?.copyWith(fontWeight: FontWeight.w700, height: 1.3),
            ),
            const SizedBox(height: 20),
            const Divider(),
            const SizedBox(height: 10),
            Wrap(
              spacing: 16,
              runSpacing: 8,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                _ReactionIconButton(
                  icon: Icons.favorite_border_rounded,
                  count: _question.likeCount,
                  tooltip: 'Like',
                  color: Colors.pink,
                  onPressed: () => _reactToQuestion('like'),
                ),
                _ReactionIconButton(
                  icon: Icons.lightbulb_outline_rounded,
                  count: _question.interestingCount,
                  tooltip: 'Interesting',
                  onPressed: () => _reactToQuestion('interesting'),
                ),
                _ReactionIconButton(
                  icon: Icons.handshake_outlined,
                  count: _question.agreeCount,
                  tooltip: 'Agree',
                  onPressed: () => _reactToQuestion('agree'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _ReactionIconButton extends StatelessWidget {
  final IconData icon;
  final int count;
  final String tooltip;
  final Color? color;
  final VoidCallback onPressed;

  const _ReactionIconButton({
    required this.icon,
    required this.count,
    required this.tooltip,
    required this.onPressed,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    return SizedBox(
      width: 48,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton(
            tooltip: tooltip,
            onPressed: onPressed,
            visualDensity: VisualDensity.compact,
            icon: Icon(icon, size: 24, color: color ?? colors.onSurfaceVariant),
          ),
          Text(
            '$count',
            style: Theme.of(context).textTheme.labelMedium
                ?.copyWith(fontWeight: FontWeight.w700),
          ),
        ],
      ),
    );
  }
}

class _AnswerCard extends StatefulWidget {
  final AnswerModel answer;

  const _AnswerCard({super.key, required this.answer});

  @override
  State<_AnswerCard> createState() => _AnswerCardState();
}

class _AnswerCardState extends State<_AnswerCard> {
  bool _showReplies = false;

  Future<void> _toggleReplies() async {
    final nextValue = !_showReplies;

    setState(() => _showReplies = nextValue);

    if (nextValue) {
      await context.read<ReplyProvider>().loadReplies(widget.answer.answerId);
    }
  }

  Future<void> _reactToAnswer(String reactionType) async {
    final answerId = widget.answer.answerId;
    final provider = context.read<ReactionProvider>();

    final success = await provider.reactToAnswer(
      answerId: answerId,
      reactionType: reactionType,
    );

    if (!mounted) return;

    if (!success) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(provider.errorMessage ?? 'Unable to save reaction.'),
        ),
      );
      return;
    }

    await context.read<AnswerProvider>().loadAnswers(
      widget.answer.questionId,
      forceRefresh: true,
    );

    if (!mounted) return;

    ScaffoldMessenger.of(context)
        .showSnackBar(const SnackBar(content: Text('Reaction saved.')));
  }

  @override
  Widget build(BuildContext context) {
    final answerProvider = context.watch<AnswerProvider>();

    final answer = answerProvider
        .answersForQuestion(widget.answer.questionId)
        .where((item) => item.answerId == widget.answer.answerId)
        .firstOrNullOr(widget.answer);

    final code = answer.publicCode.trim();

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                ProfileAvatar(
                  imageUrl: answer.profilePictureUrl,
                  size: 34,
                  fallbackText: code.isEmpty ? 'O' : code,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    code.isEmpty ? 'Community member' : code,
                    style: Theme.of(context).textTheme.labelLarge
                        ?.copyWith(fontWeight: FontWeight.w700),
                  ),
                ),
                IconButton(
                  tooltip: 'Report opinion',
                  onPressed: () => ReportContentDialog.show(
                    context,
                    targetType: 'answer',
                    targetId: answer.answerId,
                  ),
                  icon: const Icon(Icons.flag_outlined, size: 20),
                ),
              ],
            ),
            const SizedBox(height: 14),
            Text(
              answer.content,
              style: Theme.of(context).textTheme.bodyLarge
                  ?.copyWith(height: 1.5),
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 16,
              runSpacing: 8,
              children: [
                _ReactionIconButton(
                  icon: Icons.thumb_up_alt_outlined,
                  count: answer.helpfulCount,
                  tooltip: 'Helpful',
                  onPressed: () => _reactToAnswer('helpful'),
                ),
                _ReactionIconButton(
                  icon: Icons.handshake_outlined,
                  count: answer.agreeCount,
                  tooltip: 'Agree',
                  onPressed: () => _reactToAnswer('agree'),
                ),
                _ReactionIconButton(
                  icon: Icons.check_circle_outline_rounded,
                  count: answer.goodAnswerCount,
                  tooltip: 'Good answer',
                  onPressed: () => _reactToAnswer('good_answer'),
                ),
              ],
            ),
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton.icon(
                onPressed: _toggleReplies,
                icon: Icon(
                  _showReplies
                      ? Icons.keyboard_arrow_up_rounded
                      : Icons.reply_rounded,
                ),
                label: Text(_showReplies ? 'Hide replies' : 'View replies'),
              ),
            ),
            if (_showReplies) _RepliesSection(answerId: answer.answerId),
          ],
        ),
      ),
    );
  }
}

class _RepliesSection extends StatefulWidget {
  final int answerId;

  const _RepliesSection({required this.answerId});

  @override
  State<_RepliesSection> createState() => _RepliesSectionState();
}

class _RepliesSectionState extends State<_RepliesSection> {
  final TextEditingController _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _submitReply() async {
    final answerId = widget.answerId;
    final provider = context.read<ReplyProvider>();

    final success = await provider.submitReply(
      answerId: answerId,
      content: _controller.text,
    );

    if (!mounted || widget.answerId != answerId) return;

    if (success) {
      _controller.clear();
      FocusScope.of(context).unfocus();
    } else {
      final message = provider.errorForAnswer(answerId);

      if (message != null) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(message)));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<ReplyProvider>();

    final loading = provider.isLoading(widget.answerId);
    final submitting = provider.isSubmitting(widget.answerId);
    final error = provider.errorForAnswer(widget.answerId);
    final replies = provider.getRepliesForAnswer(widget.answerId);

    return Container(
      margin: const EdgeInsets.only(top: 4),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest
            .withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (loading && replies.isEmpty)
            const Center(child: CircularProgressIndicator())
          else if (error != null && replies.isEmpty)
            Text(error)
          else if (replies.isEmpty)
            const Text('No replies yet.')
          else
            ...replies.map(
              (reply) => _ReplyItem(key: ValueKey(reply.replyId), reply: reply),
            ),
          const SizedBox(height: 8),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Expanded(
                child: TextField(
                  controller: _controller,
                  minLines: 1,
                  maxLines: 3,
                  decoration: const InputDecoration(
                    hintText: 'Write a reply...',
                  ),
                ),
              ),
              const SizedBox(width: 8),
              IconButton.filledTonal(
                onPressed: submitting ? null : _submitReply,
                icon: submitting
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.send_rounded),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ReplyItem extends StatelessWidget {
  final ReplyModel reply;

  const _ReplyItem({super.key, required this.reply});

  @override
  Widget build(BuildContext context) {
    final code = reply.publicCode.trim();

    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              ProfileAvatar(
                imageUrl: reply.profilePictureUrl,
                size: 28,
                fallbackText: code.isEmpty ? 'O' : code,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  code.isEmpty ? 'Community member' : code,
                  style: Theme.of(context).textTheme.labelMedium
                      ?.copyWith(fontWeight: FontWeight.w700),
                ),
              ),
              IconButton(
                tooltip: 'Report reply',
                onPressed: () => ReportContentDialog.show(
                  context,
                  targetType: 'reply',
                  targetId: reply.replyId,
                ),
                icon: const Icon(Icons.flag_outlined, size: 18),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(reply.content),
          const Divider(height: 20),
        ],
      ),
    );
  }
}

class _PollSection extends StatefulWidget {
  final int pollId;

  const _PollSection({required this.pollId});

  @override
  State<_PollSection> createState() => _PollSectionState();
}

class _PollSectionState extends State<_PollSection> {
  int? _selectedOptionId;

  @override
  void initState() {
    super.initState();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        context.read<PollProvider>().loadPoll(widget.pollId);
      }
    });
  }

  @override
  void didUpdateWidget(covariant _PollSection oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (oldWidget.pollId != widget.pollId) {
      _selectedOptionId = null;

      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          context.read<PollProvider>().loadPoll(widget.pollId);
        }
      });
    }
  }

  Future<void> _vote(PollModel poll) async {
    final targetPollId = widget.pollId;

    if (poll.pollId != targetPollId) return;

    final optionId = _selectedOptionId;
    if (optionId == null) return;

    final provider = context.read<PollProvider>();
    final success = await provider.vote(
      pollId: targetPollId,
      optionId: optionId,
    );

    if (!mounted || widget.pollId != targetPollId) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          success
              ? 'Vote saved.'
              : provider.errorMessage ?? 'Unable to submit vote.',
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<PollProvider>();
    final poll = provider.poll;

    if (poll == null || poll.pollId != widget.pollId) {
      if (provider.isLoading || provider.errorMessage == null) {
        return const Card(
          child: Padding(
            padding: EdgeInsets.all(20),
            child: Center(child: CircularProgressIndicator()),
          ),
        );
      }

      return Card(
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Unable to load the poll for this question.',
                style: TextStyle(fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 8),
              Text(provider.errorMessage!),
              TextButton.icon(
                onPressed: provider.isLoading
                    ? null
                    : () => provider.loadPoll(widget.pollId),
                icon: const Icon(Icons.refresh_rounded),
                label: const Text('Try again'),
              ),
            ],
          ),
        ),
      );
    }

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.poll_outlined,
                  color: Theme.of(context).colorScheme.primary,
                ),
                const SizedBox(width: 8),
                Text(
                  'Community poll',
                  style: Theme.of(context).textTheme.titleMedium
                      ?.copyWith(fontWeight: FontWeight.w700),
                ),
                const Spacer(),
                Text('${poll.totalVotes} votes'),
              ],
            ),
            const SizedBox(height: 12),
            RadioGroup<int>(
              groupValue: _selectedOptionId,
              onChanged: (int? value) {
                if (provider.isVoting || !poll.isActive || value == null) {
                  return;
                }

                setState(() => _selectedOptionId = value);
              },
              child: Column(
                children: poll.options.map((option) {
                  final fraction = poll.totalVotes == 0
                      ? 0.0
                      : option.voteCount / poll.totalVotes;

                  final selected = _selectedOptionId == option.optionId;

                  return Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: InkWell(
                      borderRadius: BorderRadius.circular(12),
                      onTap: provider.isVoting || !poll.isActive
                          ? null
                          : () => setState(
                              () => _selectedOptionId = option.optionId,
                            ),
                      child: Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: selected
                                ? Theme.of(context).colorScheme.primary
                                : Theme.of(context).dividerColor,
                          ),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Radio<int>(value: option.optionId),
                                Expanded(
                                  child: Text(
                                    option.optionText,
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                                Text('${(fraction * 100).round()}%'),
                              ],
                            ),
                            LinearProgressIndicator(
                              value: fraction,
                              minHeight: 6,
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),
            ),
            if (!poll.isActive)
              const Padding(
                padding: EdgeInsets.only(bottom: 8),
                child: Text('This poll is closed.'),
              ),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed:
                    _selectedOptionId == null ||
                        provider.isVoting ||
                        !poll.isActive
                    ? null
                    : () => _vote(poll),
                icon: provider.isVoting
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.how_to_vote_outlined),
                label: Text(provider.isVoting ? 'Saving vote...' : 'Vote'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

extension _FirstOrNullOr<T> on Iterable<T> {
  T firstOrNullOr(T fallback) {
    final iterator = this.iterator;
    return iterator.moveNext() ? iterator.current : fallback;
  }
}
