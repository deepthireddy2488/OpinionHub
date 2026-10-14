import 'package:flutter/material.dart';

import '../services/community_feature_service.dart';

class ReportContentDialog extends StatefulWidget {
  final String targetType;
  final int targetId;

  const ReportContentDialog({
    super.key,
    required this.targetType,
    required this.targetId,
  });

  static Future<void> show(
    BuildContext context, {
    required String targetType,
    required int targetId,
  }) async {
    await showDialog<void>(
      context: context,
      builder: (_) =>
          ReportContentDialog(targetType: targetType, targetId: targetId),
    );
  }

  @override
  State<ReportContentDialog> createState() => _ReportContentDialogState();
}

class _ReportContentDialogState extends State<ReportContentDialog> {
  final TextEditingController _descriptionController = TextEditingController();

  final CommunityFeatureService _service = CommunityFeatureService();

  static const List<String> _reasons = [
    'Spam',
    'Harassment',
    'Hate or abuse',
    'Privacy violation',
    'Misinformation',
    'Other',
  ];

  String _reason = 'Spam';
  bool _sending = false;

  @override
  void dispose() {
    _descriptionController.dispose();
    _service.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_sending) return;

    setState(() => _sending = true);

    try {
      await _service.reportContent(
        targetType: widget.targetType,
        targetId: widget.targetId,
        reason: _reason,
        description: _descriptionController.text,
      );

      if (!mounted) return;

      Navigator.of(context).pop();

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Report submitted. Thank you for helping the community.',
          ),
        ),
      );
    } catch (error) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not submit report: $error')),
      );
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Report content'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Choose the reason that best describes the concern.'),
            const SizedBox(height: 14),
            DropdownButtonFormField<String>(
              initialValue: _reason,
              decoration: const InputDecoration(
                labelText: 'Reason',
                border: OutlineInputBorder(),
              ),
              items: _reasons
                  .map(
                    (reason) =>
                        DropdownMenuItem(value: reason, child: Text(reason)),
                  )
                  .toList(),
              onChanged: _sending
                  ? null
                  : (value) {
                      if (value != null) {
                        setState(() => _reason = value);
                      }
                    },
            ),
            const SizedBox(height: 14),
            TextField(
              controller: _descriptionController,
              minLines: 2,
              maxLines: 4,
              maxLength: 1000,
              decoration: const InputDecoration(
                labelText: 'Additional details (optional)',
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: _sending ? null : () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: _sending ? null : _submit,
          child: _sending
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Text('Submit report'),
        ),
      ],
    );
  }
}
