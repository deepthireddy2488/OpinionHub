import 'package:flutter/material.dart';

import '../../models/community_feature_models.dart';
import '../../services/community_feature_service.dart';

class AISummaryScreen extends StatefulWidget {
  final int questionId;

  const AISummaryScreen({super.key, required this.questionId});

  @override
  State<AISummaryScreen> createState() => _AISummaryScreenState();
}

class _AISummaryScreenState extends State<AISummaryScreen> {
  final CommunityFeatureService _service = CommunityFeatureService();

  CommunityAISummaryModel? _summary;
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _generateSummary();
  }

  @override
  void dispose() {
    _service.dispose();
    super.dispose();
  }

  Future<void> _generateSummary() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final summary = await _service.summarizeQuestion(widget.questionId);

      if (!mounted) return;

      setState(() => _summary = summary);
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

  Widget _section(
    BuildContext context,
    String heading,
    IconData icon,
    List<String> items,
  ) {
    final colors = Theme.of(context).colorScheme;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, color: colors.primary),
                const SizedBox(width: 9),
                Expanded(
                  child: Text(
                    heading,
                    style: Theme.of(context).textTheme.titleMedium
                        ?.copyWith(fontWeight: FontWeight.w800),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            if (items.isEmpty)
              const Text('No points available.')
            else
              ...items.map(
                (item) => Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('•  '),
                      Expanded(child: Text(item)),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final summary = _summary;

    return Scaffold(
      appBar: AppBar(title: const Text('AI perspective summary')),
      body: _loading
          ? const Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  CircularProgressIndicator(),
                  SizedBox(height: 16),
                  Text('Summarizing community perspectives...'),
                ],
              ),
            )
          : _error != null
          ? Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.psychology_outlined, size: 46),
                    const SizedBox(height: 14),
                    Text(_error!, textAlign: TextAlign.center),
                    const SizedBox(height: 16),
                    FilledButton.icon(
                      onPressed: _generateSummary,
                      icon: const Icon(Icons.refresh_rounded),
                      label: const Text('Try again'),
                    ),
                  ],
                ),
              ),
            )
          : summary == null
          ? const Center(child: Text('Summary unavailable.'))
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Row(
                          children: [
                            Icon(Icons.auto_awesome_rounded),
                            SizedBox(width: 8),
                            Text(
                              'AI-GENERATED',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w900,
                                letterSpacing: 0.8,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 14),
                        Text(
                          summary.questionTitle,
                          style: Theme.of(context).textTheme.titleLarge
                              ?.copyWith(fontWeight: FontWeight.w800),
                        ),
                        const SizedBox(height: 12),
                        Text(
                          summary.summary,
                          style: Theme.of(context).textTheme.bodyLarge
                              ?.copyWith(height: 1.5),
                        ),
                      ],
                    ),
                  ),
                ),
                _section(
                  context,
                  'Common ground',
                  Icons.handshake_outlined,
                  summary.commonGround,
                ),
                _section(
                  context,
                  'Different viewpoints',
                  Icons.compare_arrows_rounded,
                  summary.differentViewpoints,
                ),
                _section(
                  context,
                  'Questions to consider',
                  Icons.lightbulb_outline_rounded,
                  summary.questionsToConsider,
                ),
                const Padding(
                  padding: EdgeInsets.all(8),
                  child: Text(
                    'AI summaries can miss context or make mistakes. '
                    'Read the original opinions before making a decision.',
                    textAlign: TextAlign.center,
                  ),
                ),
              ],
            ),
    );
  }
}
