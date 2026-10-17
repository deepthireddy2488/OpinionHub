import 'package:flutter/foundation.dart';

class ApiConstants {
  ApiConstants._();

  // Override at build/run time with:
  // flutter run --dart-define=API_BASE_URL=http://<laptop-lan-ip>:8000
  // This avoids relying on a Wi-Fi IP that can change between sessions.
  static const String _configuredBaseUrl = String.fromEnvironment(
    'API_BASE_URL',
  );

  static String get baseUrl {
    if (_configuredBaseUrl.isNotEmpty) {
      return _configuredBaseUrl;
    }

    if (kIsWeb) {
      return 'http://127.0.0.1:8000';
    }

    // Fallback for the last LAN address verified during troubleshooting.
    // Prefer passing API_BASE_URL for physical Android devices.
    return 'http://10.197.17.158:8000';
  }

  // Authentication
  static const String register = '/auth/register';
  static const String login = '/auth/login';
  static const String currentUser = '/auth/me';
  static const String profilePicture = '/users/me/profile-picture';

  // Questions
  static const String publicQuestions = '/questions/public';
  static const String questions = '/questions';

  // Answers
  static const String answers = '/answers';

  // Replies
  static const String replies = '/replies';

  // Reactions
  static const String questionReactions = '/questions';
  static const String answerReactions = '/answers';

  // Polls
  static const String polls = '/polls';

  // Groups
  static const String groups = '/groups';

  // Reports
  static const String reports = '/reports';
}
