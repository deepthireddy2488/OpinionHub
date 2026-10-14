import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/group_model.dart';
import '../../providers/auth_provider.dart';
import '../../providers/group_provider.dart';

class GroupInfoResult {
  final GroupModel? group;
  final bool left;

  const GroupInfoResult({this.group, this.left = false});
}

class GroupInfoScreen extends StatefulWidget {
  final GroupModel group;

  const GroupInfoScreen({super.key, required this.group});

  @override
  State<GroupInfoScreen> createState() => _GroupInfoScreenState();
}

class _GroupInfoScreenState extends State<GroupInfoScreen> {
  late GroupModel _group;

  @override
  void initState() {
    super.initState();
    _group = widget.group;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        context.read<GroupProvider>().loadMembers(_group.groupId);
      }
    });
  }

  Future<void> _refresh() async {
    await context.read<GroupProvider>().loadMembers(_group.groupId);
  }

  Future<void> _renameGroup() async {
    final controller = TextEditingController(text: _group.groupName);

    try {
      final name = await showDialog<String>(
        context: context,
        builder: (dialogContext) {
          String? error;

          return StatefulBuilder(
            builder: (context, setDialogState) {
              return AlertDialog(
                title: const Text('Rename group'),
                content: TextField(
                  controller: controller,
                  autofocus: true,
                  maxLength: 100,
                  textCapitalization: TextCapitalization.words,
                  textInputAction: TextInputAction.done,
                  onSubmitted: (value) {
                    final cleaned = value.trim();

                    if (cleaned.length < 2) {
                      setDialogState(() {
                        error = 'Use at least 2 characters.';
                      });
                      return;
                    }

                    Navigator.of(dialogContext).pop(cleaned);
                  },
                  decoration: InputDecoration(
                    labelText: 'Group name',
                    hintText: 'Enter a group name',
                    errorText: error,
                    prefixIcon: const Icon(Icons.edit_outlined),
                  ),
                ),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.of(dialogContext).pop(),
                    child: const Text('Cancel'),
                  ),
                  FilledButton(
                    onPressed: () {
                      final cleaned = controller.text.trim();

                      if (cleaned.length < 2) {
                        setDialogState(() {
                          error = 'Use at least 2 characters.';
                        });
                        return;
                      }

                      Navigator.of(dialogContext).pop(cleaned);
                    },
                    child: const Text('Save'),
                  ),
                ],
              );
            },
          );
        },
      );

      if (name == null || !mounted) return;

      final provider = context.read<GroupProvider>();
      final success = await provider.renameGroup(
        groupId: _group.groupId,
        groupName: name,
      );

      if (!mounted) return;

      if (!success) {
        _showMessage(
          provider.errorMessage ?? 'Unable to rename the group.',
          error: true,
        );
        return;
      }

      var updatedGroup = _group.copyWith(groupName: name);

      for (final group in provider.groups) {
        if (group.groupId == _group.groupId) {
          updatedGroup = group;
          break;
        }
      }

      // Return the updated group to GroupDetailScreen.
      Navigator.of(context).pop(GroupInfoResult(group: updatedGroup));
    } finally {
      controller.dispose();
    }
  }

  Future<void> _inviteMember() async {
    final controller = TextEditingController();

    try {
      final code = await showDialog<String>(
        context: context,
        builder: (dialogContext) {
          String? error;

          return StatefulBuilder(
            builder: (context, setDialogState) {
              return AlertDialog(
                title: const Text('Invite a member'),
                content: TextField(
                  controller: controller,
                  autofocus: true,
                  maxLength: 9,
                  textCapitalization: TextCapitalization.characters,
                  textInputAction: TextInputAction.done,
                  onSubmitted: (value) {
                    final cleaned = value.trim().toUpperCase();

                    if (!RegExp(r'^OP-\d{6}$').hasMatch(cleaned)) {
                      setDialogState(() {
                        error = 'Enter a code like OP-123456.';
                      });
                      return;
                    }

                    Navigator.of(dialogContext).pop(cleaned);
                  },
                  decoration: InputDecoration(
                    labelText: 'Public code',
                    hintText: 'OP-123456',
                    prefixIcon: const Icon(Icons.person_add_alt_1),
                    errorText: error,
                  ),
                ),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.of(dialogContext).pop(),
                    child: const Text('Cancel'),
                  ),
                  FilledButton.icon(
                    onPressed: () {
                      final cleaned = controller.text.trim().toUpperCase();

                      if (!RegExp(r'^OP-\d{6}$').hasMatch(cleaned)) {
                        setDialogState(() {
                          error = 'Enter a code like OP-123456.';
                        });
                        return;
                      }

                      Navigator.of(dialogContext).pop(cleaned);
                    },
                    icon: const Icon(Icons.send_rounded),
                    label: const Text('Continue'),
                  ),
                ],
              );
            },
          );
        },
      );

      if (code == null || !mounted) return;

      final provider = context.read<GroupProvider>();
      final success = await provider.inviteUser(
        groupId: _group.groupId,
        publicCode: code,
      );

      if (!mounted) return;

      _showMessage(
        success
            ? 'Invitation sent successfully.'
            : provider.errorMessage ?? 'Unable to send invitation.',
        error: !success,
      );
    } finally {
      controller.dispose();
    }
  }

  Future<bool> _confirmAction({
    required String title,
    required String message,
    required String confirmLabel,
  }) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        final colors = Theme.of(context).colorScheme;

        return AlertDialog(
          title: Text(title),
          content: Text(message),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              style: FilledButton.styleFrom(
                backgroundColor: colors.error,
                foregroundColor: colors.onError,
              ),
              onPressed: () => Navigator.of(dialogContext).pop(true),
              child: Text(confirmLabel),
            ),
          ],
        );
      },
    );

    return result == true;
  }

  Future<void> _clearChat() async {
    final confirmed = await _confirmAction(
      title: 'Clear chat?',
      message:
          'This hides the current group chat history from your account. '
          'Other members keep their chat history.',
      confirmLabel: 'Clear chat',
    );

    if (!confirmed || !mounted) return;

    final provider = context.read<GroupProvider>();
    final success = await provider.clearGroupChat(_group.groupId);

    if (!mounted) return;

    _showMessage(
      success
          ? 'Chat cleared from your account.'
          : provider.errorMessage ?? 'Unable to clear chat.',
      error: !success,
    );
  }

  Future<void> _leaveGroup() async {
    final confirmed = await _confirmAction(
      title: 'Leave group?',
      message:
          'You will leave "${_group.groupName}". '
          'You may need a new invitation to join again.',
      confirmLabel: 'Leave group',
    );

    if (!confirmed || !mounted) return;

    final provider = context.read<GroupProvider>();
    final success = await provider.leaveGroup(_group.groupId);

    if (!mounted) return;

    if (success) {
      Navigator.of(context).pop(const GroupInfoResult(left: true));
    } else {
      _showMessage(
        provider.errorMessage ?? 'Unable to leave group.',
        error: true,
      );
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
    final currentUser = context.watch<AuthProvider>().user;
    final colors = Theme.of(context).colorScheme;

    GroupMemberModel? currentMember;

    for (final member in provider.members) {
      if (member.userId == currentUser?.userId) {
        currentMember = member;
        break;
      }
    }

    final role = currentMember?.role.toLowerCase();
    final canManage = role == 'owner' || role == 'admin';

    final name = _group.groupName.trim();
    final initial = name.isEmpty ? 'G' : name[0].toUpperCase();

    return Scaffold(
      appBar: AppBar(title: const Text('Group information')),
      body: RefreshIndicator(
        onRefresh: _refresh,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 28),
          children: [
            Card(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  children: [
                    Container(
                      width: 76,
                      height: 76,
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [Color(0xFF625BFF), Color(0xFF20BFA9)],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(24),
                      ),
                      alignment: Alignment.center,
                      child: Text(
                        initial,
                        style: const TextStyle(
                          fontSize: 32,
                          fontWeight: FontWeight.w800,
                          color: Colors.white,
                        ),
                      ),
                    ),
                    const SizedBox(height: 15),
                    Text(
                      _group.groupName,
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.headlineSmall
                          ?.copyWith(fontWeight: FontWeight.w800),
                    ),
                    const SizedBox(height: 7),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
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
                    const SizedBox(height: 12),
                    if (currentMember != null)
                      Chip(
                        avatar: Icon(
                          role == 'owner'
                              ? Icons.verified_user_outlined
                              : Icons.person_outline_rounded,
                          size: 17,
                        ),
                        label: Text('Your role: ${currentMember.role}'),
                      ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 20),
            Text(
              'Group management',
              style: Theme.of(context).textTheme.titleLarge
                  ?.copyWith(fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 10),
            if (canManage) ...[
              _ActionTile(
                icon: Icons.edit_outlined,
                title: 'Rename group',
                subtitle: 'Change the name shown to members',
                onTap: _renameGroup,
              ),
              const SizedBox(height: 10),
              _ActionTile(
                icon: Icons.person_add_alt_1_rounded,
                title: 'Invite members',
                subtitle: 'Invite someone using their public code',
                onTap: _inviteMember,
              ),
              const SizedBox(height: 22),
            ],
            Row(
              children: [
                Expanded(
                  child: Text(
                    'Members',
                    style: Theme.of(context).textTheme.titleLarge
                        ?.copyWith(fontWeight: FontWeight.w800),
                  ),
                ),
                Text(
                  '${provider.members.length}',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    color: colors.primary,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Card(
              child: provider.isLoadingMembers && provider.members.isEmpty
                  ? const Padding(
                      padding: EdgeInsets.all(28),
                      child: Center(child: CircularProgressIndicator()),
                    )
                  : provider.errorMessage != null && provider.members.isEmpty
                  ? Padding(
                      padding: const EdgeInsets.all(22),
                      child: Column(
                        children: [
                          const Icon(Icons.cloud_off_outlined, size: 38),
                          const SizedBox(height: 10),
                          Text(
                            provider.errorMessage!,
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 12),
                          FilledButton.tonal(
                            onPressed: _refresh,
                            child: const Text('Try again'),
                          ),
                        ],
                      ),
                    )
                  : provider.members.isEmpty
                  ? const Padding(
                      padding: EdgeInsets.all(24),
                      child: Text(
                        'No active members found.',
                        textAlign: TextAlign.center,
                      ),
                    )
                  : Column(
                      children: provider.members.map((member) {
                        final isMe = member.userId == currentUser?.userId;
                        final memberName = member.nickname.trim();
                        final memberInitial = memberName.isEmpty
                            ? '?'
                            : memberName[0].toUpperCase();

                        return ListTile(
                          key: ValueKey(member.groupMemberId),
                          leading: CircleAvatar(
                            backgroundColor: colors.secondaryContainer,
                            foregroundColor: colors.onSecondaryContainer,
                            child: Text(memberInitial),
                          ),
                          title: Text(
                            isMe ? '${member.nickname} (You)' : member.nickname,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(fontWeight: FontWeight.w700),
                          ),
                          subtitle: Text(member.publicCode),
                          trailing: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 6,
                            ),
                            decoration: BoxDecoration(
                              color: member.role == 'owner'
                                  ? colors.primaryContainer
                                  : colors.surfaceContainerHighest,
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Text(
                              member.role,
                              style: Theme.of(context).textTheme.labelSmall,
                            ),
                          ),
                        );
                      }).toList(),
                    ),
            ),
            const SizedBox(height: 24),
            Card(
              color: colors.errorContainer,
              child: Column(
                children: [
                  ListTile(
                    leading: Icon(
                      Icons.cleaning_services_outlined,
                      color: colors.onErrorContainer,
                    ),
                    title: const Text(
                      'Clear my chat history',
                      style: TextStyle(fontWeight: FontWeight.w700),
                    ),
                    subtitle: const Text(
                      'Other members retain their messages.',
                    ),
                    trailing: provider.isClearingChat
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.chevron_right_rounded),
                    onTap: provider.isClearingChat ? null : _clearChat,
                  ),
                  Divider(
                    height: 1,
                    color: colors.onErrorContainer.withValues(alpha: 0.15),
                  ),
                  ListTile(
                    leading: Icon(
                      Icons.exit_to_app_rounded,
                      color: colors.onErrorContainer,
                    ),
                    title: const Text(
                      'Leave group',
                      style: TextStyle(fontWeight: FontWeight.w700),
                    ),
                    subtitle: const Text('Leave this private group.'),
                    trailing: provider.isLeaving
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.chevron_right_rounded),
                    onTap: provider.isLeaving ? null : _leaveGroup,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ActionTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  const _ActionTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    return Card(
      child: ListTile(
        onTap: onTap,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        leading: Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            color: colors.primaryContainer,
            borderRadius: BorderRadius.circular(13),
          ),
          child: Icon(icon, color: colors.onPrimaryContainer),
        ),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.w700)),
        subtitle: Text(subtitle),
        trailing: const Icon(Icons.chevron_right_rounded),
      ),
    );
  }
}
