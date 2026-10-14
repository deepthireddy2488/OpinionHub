import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';

import '../../core/network/api_client.dart';
import '../../providers/auth_provider.dart';
import '../../services/profile_service.dart';
import '../../widgets/profile_avatar.dart';

class ProfileSettingsScreen extends StatefulWidget {
  const ProfileSettingsScreen({super.key});

  @override
  State<ProfileSettingsScreen> createState() => _ProfileSettingsScreenState();
}

class _ProfileSettingsScreenState extends State<ProfileSettingsScreen> {
  final ImagePicker _picker = ImagePicker();
  final ProfileService _profileService = ProfileService();

  bool _isBusy = false;

  @override
  void dispose() {
    _profileService.dispose();
    super.dispose();
  }

  Future<void> _pickPicture() async {
    if (_isBusy) return;

    try {
      final XFile? file = await _picker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 85,
        maxWidth: 1200,
        maxHeight: 1200,
      );

      if (file == null || !mounted) return;

      setState(() => _isBusy = true);

      final updatedUser = await _profileService.uploadProfilePicture(file.path);

      if (!mounted) return;

      context.read<AuthProvider>().updateUserProfile(updatedUser);

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Profile picture updated.')));
    } catch (error) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            error is ApiException
                ? error.message
                : 'Unable to upload the profile picture.',
          ),
        ),
      );
    } finally {
      if (mounted) setState(() => _isBusy = false);
    }
  }

  Future<void> _removePicture() async {
    if (_isBusy) return;

    setState(() => _isBusy = true);

    try {
      final updatedUser = await _profileService.removeProfilePicture();

      if (!mounted) return;

      context.read<AuthProvider>().updateUserProfile(updatedUser);

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Profile picture removed.')));
    } catch (error) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            error is ApiException
                ? error.message
                : 'Unable to remove the profile picture.',
          ),
        ),
      );
    } finally {
      if (mounted) setState(() => _isBusy = false);
    }
  }

  Future<void> _logout() async {
    if (_isBusy) return;

    final shouldLogout = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Log out?'),
        content: const Text(
          'You will need to log in again to access your account.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Log out'),
          ),
        ],
      ),
    );

    if (shouldLogout != true || !mounted) return;

    await context.read<AuthProvider>().logout();

    if (mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final user = auth.user;
    final colors = Theme.of(context).colorScheme;

    if (user == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Profile settings')),
        body: const Center(child: Text('Please log in to view your profile.')),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Profile settings',
          style: TextStyle(fontWeight: FontWeight.w800),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          const SizedBox(height: 18),
          Center(
            child: Stack(
              alignment: Alignment.bottomRight,
              children: [
                Container(
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(color: colors.primary, width: 2),
                  ),
                  child: ProfileAvatar(
                    imageUrl: user.profilePictureUrl,
                    size: 112,
                    fallbackText: user.nickname,
                  ),
                ),
                IconButton.filled(
                  tooltip: 'Change profile picture',
                  onPressed: _isBusy ? null : _pickPicture,
                  icon: const Icon(Icons.camera_alt_rounded),
                ),
              ],
            ),
          ),
          const SizedBox(height: 18),
          Center(
            child: Text(
              user.nickname,
              style: Theme.of(context).textTheme.headlineSmall
                  ?.copyWith(fontWeight: FontWeight.w800),
            ),
          ),
          const SizedBox(height: 6),
          Center(
            child: Text(
              'Your OpinionHub profile',
              style: TextStyle(color: colors.onSurfaceVariant),
            ),
          ),
          const SizedBox(height: 26),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Your public code',
                    style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
                  ),
                  const SizedBox(height: 6),
                  const Text(
                    'Share this code so other people can find your profile.',
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: SelectableText(
                          user.publicCode,
                          style: Theme.of(context).textTheme.titleLarge
                              ?.copyWith(
                                fontWeight: FontWeight.w800,
                                color: colors.primary,
                              ),
                        ),
                      ),
                      IconButton(
                        tooltip: 'Copy public code',
                        onPressed: () async {
                          await Clipboard.setData(
                            ClipboardData(text: user.publicCode),
                          );

                          if (!context.mounted) return;

                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Public code copied.'),
                            ),
                          );
                        },
                        icon: const Icon(Icons.copy_rounded),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 18),
          OutlinedButton.icon(
            onPressed: _isBusy ? null : _pickPicture,
            icon: const Icon(Icons.photo_library_outlined),
            label: const Text('Choose profile picture'),
          ),
          if (user.profilePictureUrl != null) ...[
            const SizedBox(height: 10),
            OutlinedButton.icon(
              onPressed: _isBusy ? null : _removePicture,
              icon: const Icon(Icons.delete_outline_rounded),
              label: const Text('Remove profile picture'),
            ),
          ],
          if (_isBusy) ...[
            const SizedBox(height: 18),
            const Center(child: CircularProgressIndicator()),
          ],
          const SizedBox(height: 28),
          const Divider(),
          const SizedBox(height: 12),
          ListTile(
            leading: const Icon(Icons.logout_rounded),
            title: const Text('Log out'),
            subtitle: const Text('Log out of your account'),
            onTap: _isBusy ? null : _logout,
          ),
        ],
      ),
    );
  }
}
