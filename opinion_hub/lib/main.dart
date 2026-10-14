import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'core/theme/app_theme.dart';
import 'providers/answer_provider.dart';
import 'providers/auth_provider.dart';
import 'providers/group_provider.dart';
import 'providers/poll_provider.dart';
import 'providers/reaction_provider.dart';
import 'providers/reply_provider.dart';
import 'screens/auth/auth_gate.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const OpinionHubApp());
}

class OpinionHubApp extends StatelessWidget {
  const OpinionHubApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider<AuthProvider>(
          create: (_) => AuthProvider()..initialize(),
        ),
        ChangeNotifierProvider<AnswerProvider>(create: (_) => AnswerProvider()),
        ChangeNotifierProvider<ReplyProvider>(create: (_) => ReplyProvider()),
        ChangeNotifierProvider<ReactionProvider>(
          create: (_) => ReactionProvider(),
        ),
        ChangeNotifierProvider<PollProvider>(create: (_) => PollProvider()),
        ChangeNotifierProvider<GroupProvider>(create: (_) => GroupProvider()),
      ],
      child: MaterialApp(
        title: 'OpinionHub',
        debugShowCheckedModeBanner: false,
        theme: AppTheme.lightTheme,
        darkTheme: AppTheme.darkTheme,
        themeMode: ThemeMode.system,
        home: const AuthGate(),
      ),
    );
  }
}
