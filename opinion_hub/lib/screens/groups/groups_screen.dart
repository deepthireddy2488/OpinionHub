import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/group_model.dart';
import '../../providers/group_provider.dart';
import 'group_detail_screen.dart';

class GroupsScreen extends StatefulWidget {
  const GroupsScreen({super.key});

  @override
  State<GroupsScreen> createState() => _GroupsScreenState();
}

class _GroupsScreenState extends State<GroupsScreen> {
  @override
  void initState() {
    super.initState();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;

      final provider = context.read<GroupProvider>();
      provider.loadGroups();
      provider.loadInvitations();
    });
  }

  Future<void> _refresh() async {
    final provider = context.read<GroupProvider>();

    await Future.wait([provider.loadGroups(), provider.loadInvitations()]);
  }

  Future<void> _createGroup() async {
    final controller = TextEditingController();
    final provider = context.read<GroupProvider>();

    try {
      final result = await showDialog<bool>(
        context: context,
        builder: (dialogContext) {
          bool submitting = false;
          String? validationError;

          return StatefulBuilder(
            builder: (dialogContext, setDialogState) {
              // Declare submit before using it in the buttons.
              Future<void> submit() async {
                if (submitting) return;

                final name = controller.text.trim();

                if (name.length < 2) {
                  setDialogState(() {
                    validationError =
                        'Group name must contain at least 2 characters.';
                  });
                  return;
                }

                if (name.length > 100) {
                  setDialogState(() {
                    validationError =
                        'Group name cannot exceed 100 characters.';
                  });
                  return;
                }

                setDialogState(() {
                  submitting = true;
                  validationError = null;
                });

                final success = await provider.createGroup(name);

                // The dialog might have been dismissed while awaiting.
                if (!dialogContext.mounted) return;

                if (success) {
                  Navigator.of(dialogContext).pop(true);
                } else {
                  setDialogState(() {
                    submitting = false;
                    validationError =
                        provider.errorMessage ??
                        'Unable to create group. Please try again.';
                  });
                }
              }

              return AlertDialog(
                title: const Row(
                  children: [
                    Icon(Icons.groups_2_outlined),
                    SizedBox(width: 10),
                    Flexible(child: Text('Create a group')),
                  ],
                ),
                content: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Create a private space to share ideas '
                      'with friends or people who share your interests.',
                    ),
                    const SizedBox(height: 18),
                    TextField(
                      controller: controller,
                      autofocus: true,
                      maxLength: 100,
                      textCapitalization: TextCapitalization.words,
                      textInputAction: TextInputAction.done,
                      onSubmitted: (_) => submit(),
                      decoration: InputDecoration(
                        labelText: 'Group name',
                        hintText: 'e.g. College Friends',
                        prefixIcon: const Icon(Icons.groups_outlined),
                        errorText: validationError,
                      ),
                    ),
                  ],
                ),
                actions: [
                  TextButton(
                    onPressed: submitting
                        ? null
                        : () => Navigator.of(dialogContext).pop(false),
                    child: const Text('Cancel'),
                  ),
                  FilledButton(
                    onPressed: submitting ? null : submit,
                    child: submitting
                        ? const SizedBox(
                            width: 19,
                            height: 19,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Text('Create group'),
                  ),
                ],
              );
            },
          );
        },
      );

      if (result == true && mounted) {
        ScaffoldMessenger.of(context)
          ..hideCurrentSnackBar()
          ..showSnackBar(
            const SnackBar(content: Text('Group created successfully.')),
          );
      }
    } finally {
      controller.dispose();
    }
  }

  void _showMessage(String message, {bool error = false}) {
    if (!mounted) return;

    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: error ? const Color(0xFFB42318) : null,
        ),
      );
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<GroupProvider>();
    final colors = Theme.of(context).colorScheme;

    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Your Groups'),
          actions: [
            IconButton(
              tooltip: 'Refresh',
              onPressed: _refresh,
              icon: const Icon(Icons.refresh_rounded),
            ),
            const SizedBox(width: 6),
          ],
          bottom: TabBar(
            tabs: [
              Tab(
                icon: const Icon(Icons.groups_2_outlined),
                text: 'My Groups (${provider.groups.length})',
              ),
              Tab(
                icon: const Icon(Icons.mail_outline_rounded),
                text: 'Invitations (${provider.invitations.length})',
              ),
            ],
          ),
        ),
        floatingActionButton: FloatingActionButton.extended(
          onPressed: provider.isCreating ? null : _createGroup,
          icon: const Icon(Icons.add_rounded),
          label: const Text('Create group'),
        ),
        body: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [colors.primary.withValues(alpha: 0.035), colors.surface],
              stops: const [0, 0.45],
            ),
          ),
          child: TabBarView(
            children: [
              _MyGroupsTab(
                onRefresh: _refresh,
                onOpenGroup: (group) async {
                  final result = await Navigator.of(context).push<bool>(
                    MaterialPageRoute(
                      builder: (_) => GroupDetailScreen(group: group),
                    ),
                  );

                  if (result == true && mounted) {
                    await _refresh();
                  }
                },
              ),
              _InvitationsTab(onRefresh: _refresh, onMessage: _showMessage),
            ],
          ),
        ),
      ),
    );
  }
}

class _MyGroupsTab extends StatelessWidget {
  final Future<void> Function() onRefresh;
  final ValueChanged<GroupModel> onOpenGroup;

  const _MyGroupsTab({required this.onRefresh, required this.onOpenGroup});

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<GroupProvider>();
    final colors = Theme.of(context).colorScheme;

    return RefreshIndicator(
      onRefresh: onRefresh,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(18, 20, 18, 110),
        children: [
          Text(
            'Private spaces, better conversations.',
            style: Theme.of(context).textTheme.bodyLarge
                ?.copyWith(color: colors.onSurfaceVariant),
          ),
          const SizedBox(height: 20),
          if (provider.isLoadingGroups && provider.groups.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 70),
              child: Center(child: CircularProgressIndicator()),
            )
          else if (provider.errorMessage != null && provider.groups.isEmpty)
            _StatusCard(
              icon: Icons.cloud_off_outlined,
              title: 'Couldn’t load your groups',
              message: provider.errorMessage!,
              actionLabel: 'Try again',
              onAction: onRefresh,
            )
          else if (provider.groups.isEmpty)
            const _StatusCard(
              icon: Icons.forum_outlined,
              title: 'Your first group starts here',
              message:
                  'Create a space for friends, classmates, '
                  'or people who share your interests.',
            )
          else
            ...provider.groups.map(
              (group) => Padding(
                key: ValueKey(group.groupId),
                padding: const EdgeInsets.only(bottom: 12),
                child: _GroupCard(
                  group: group,
                  onTap: () => onOpenGroup(group),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _GroupCard extends StatelessWidget {
  final GroupModel group;
  final VoidCallback onTap;

  const _GroupCard({required this.group, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final name = group.groupName.trim();
    final initial = name.isEmpty ? 'G' : name[0].toUpperCase();

    return Material(
      color: colors.surface,
      borderRadius: BorderRadius.circular(20),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: colors.outlineVariant),
          ),
          child: Row(
            children: [
              Container(
                width: 54,
                height: 54,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF625BFF), Color(0xFF20BFA9)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(17),
                ),
                child: Center(
                  child: Text(
                    initial,
                    style: const TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w800,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      group.groupName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.titleMedium
                          ?.copyWith(fontWeight: FontWeight.w800),
                    ),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        Icon(
                          Icons.lock_outline_rounded,
                          size: 15,
                          color: colors.onSurfaceVariant,
                        ),
                        const SizedBox(width: 5),
                        Text(
                          'Private group',
                          style: Theme.of(context).textTheme.bodySmall
                              ?.copyWith(color: colors.onSurfaceVariant),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 5),
              Icon(
                Icons.arrow_forward_ios_rounded,
                size: 16,
                color: colors.onSurfaceVariant,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _InvitationsTab extends StatelessWidget {
  final Future<void> Function() onRefresh;
  final void Function(String message, {bool error}) onMessage;

  const _InvitationsTab({required this.onRefresh, required this.onMessage});

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<GroupProvider>();

    return RefreshIndicator(
      onRefresh: onRefresh,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(18, 20, 18, 110),
        children: [
          Text(
            'Invitations',
            style: Theme.of(context).textTheme.headlineSmall
                ?.copyWith(fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 6),
          Text(
            'Choose which groups you want to join.',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 18),
          if (provider.isLoadingInvitations && provider.invitations.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 70),
              child: Center(child: CircularProgressIndicator()),
            )
          else if (provider.invitations.isEmpty)
            const _StatusCard(
              icon: Icons.mark_email_read_outlined,
              title: 'No pending invitations',
              message:
                  'When someone invites you to a private group, '
                  'the invitation will appear here.',
            )
          else
            ...provider.invitations.map(
              (invitation) => Padding(
                key: ValueKey(invitation.invitationId),
                padding: const EdgeInsets.only(bottom: 12),
                child: Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            CircleAvatar(
                              backgroundColor: Theme.of(context)
                                  .colorScheme
                                  .primaryContainer,
                              child: const Icon(Icons.groups_2_outlined),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                invitation.groupName,
                                style: Theme.of(context).textTheme.titleMedium
                                    ?.copyWith(fontWeight: FontWeight.w800),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Text(
                          'Invited by ${invitation.invitedByUserPublicCode}',
                          style: Theme.of(context).textTheme.bodyMedium,
                        ),
                        const SizedBox(height: 16),
                        Row(
                          children: [
                            Expanded(
                              child: OutlinedButton(
                                onPressed: provider.isResponding
                                    ? null
                                    : () async {
                                        final success = await provider
                                            .rejectInvitation(
                                              invitation.invitationId,
                                            );

                                        if (!context.mounted) return;

                                        if (success) {
                                          onMessage('Invitation rejected.');
                                        } else {
                                          onMessage(
                                            provider.errorMessage ??
                                                'Unable to reject invitation.',
                                            error: true,
                                          );
                                        }
                                      },
                                child: const Text('Decline'),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: FilledButton(
                                onPressed: provider.isResponding
                                    ? null
                                    : () async {
                                        final success = await provider
                                            .acceptInvitation(
                                              invitation.invitationId,
                                            );

                                        if (!context.mounted) return;

                                        if (success) {
                                          onMessage(
                                            'You joined ${invitation.groupName}.',
                                          );
                                        } else {
                                          onMessage(
                                            provider.errorMessage ??
                                                'Unable to accept invitation.',
                                            error: true,
                                          );
                                        }
                                      },
                                child: const Text('Accept'),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _StatusCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String message;
  final String? actionLabel;
  final Future<void> Function()? onAction;

  const _StatusCard({
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
              child: Icon(icon, size: 34, color: colors.onPrimaryContainer),
            ),
            const SizedBox(height: 18),
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
