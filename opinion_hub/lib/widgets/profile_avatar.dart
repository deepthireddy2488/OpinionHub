import 'package:flutter/material.dart';

import '../core/constants/api_constants.dart';

class ProfileAvatar extends StatelessWidget {
  final String? imageUrl;
  final double size;
  final String fallbackText;

  const ProfileAvatar({
    super.key,
    required this.imageUrl,
    this.size = 44,
    this.fallbackText = 'O',
  });

  String? _resolvedImageUrl() {
    final value = imageUrl?.trim();

    if (value == null || value.isEmpty) return null;

    if (value.startsWith('https://') || value.startsWith('http://')) {
      return value;
    }

    final path = value.startsWith('/') ? value : '/$value';
    return '${ApiConstants.baseUrl}$path';
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final url = _resolvedImageUrl();

    Widget fallback() {
      return CircleAvatar(
        radius: size / 2,
        backgroundColor: colors.primaryContainer,
        foregroundColor: colors.onPrimaryContainer,
        child: Text(
          fallbackText.isEmpty ? 'O' : fallbackText[0].toUpperCase(),
          style: TextStyle(fontSize: size * 0.36, fontWeight: FontWeight.w800),
        ),
      );
    }

    if (url == null) return fallback();

    return ClipOval(
      child: Image.network(
        url,
        width: size,
        height: size,
        fit: BoxFit.cover,
        errorBuilder: (context, error, stackTrace) => fallback(),
        loadingBuilder: (context, child, progress) {
          if (progress == null) return child;
          return fallback();
        },
      ),
    );
  }
}
