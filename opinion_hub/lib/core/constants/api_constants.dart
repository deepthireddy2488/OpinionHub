import 'package:flutter/foundation.dart';

class ApiConstants {
  ApiConstants._();

  static String get baseUrl {
    if (kIsWeb) {
      return 'http://127.0.0.1:8000';
    }

    // Laptop's Wi-Fi IP for physical Android phone
    return 'http://10.248.53.158:8000';
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
