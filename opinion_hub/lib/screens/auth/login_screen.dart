import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../providers/auth_provider.dart';
import 'register_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  static const Color _primary = Color(0xFF625BFF);
  static const Color _teal = Color(0xFF20BFA9);

  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();

  bool _obscurePassword = true;
  bool _submitting = false;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _login() async {
    if (_submitting) {
      return;
    }

    final form = _formKey.currentState;
    if (form == null || !form.validate()) {
      return;
    }

    FocusScope.of(context).unfocus();

    final email = _emailController.text.trim();
    final password = _passwordController.text;
    final authProvider = context.read<AuthProvider>();

    setState(() => _submitting = true);

    try {
      await authProvider.login(email: email, password: password);
    } finally {
      if (mounted) {
        setState(() => _submitting = false);
      }
    }

    if (!mounted) {
      return;
    }

    final message = authProvider.errorMessage;

    if (message != null) {
      _showError(message);
      authProvider.clearError();
    }
  }

  void _showError(String message) {
    final messenger = ScaffoldMessenger.of(context);

    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(message),
          behavior: SnackBarBehavior.floating,
          backgroundColor: const Color(0xFFB42318),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
          margin: const EdgeInsets.all(16),
        ),
      );
  }

  InputDecoration _fieldDecoration({
    required String label,
    required IconData icon,
    required Color fillColor,
    required bool isDark,
    Widget? suffixIcon,
  }) {
    final borderColor = isDark
        ? const Color(0xFF303A50)
        : const Color(0xFFE2E7F0);

    return InputDecoration(
      labelText: label,
      prefixIcon: Icon(icon, size: 21),
      suffixIcon: suffixIcon,
      filled: true,
      fillColor: fillColor,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(15),
        borderSide: BorderSide(color: borderColor),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(15),
        borderSide: BorderSide(color: borderColor),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(15),
        borderSide: const BorderSide(color: _primary, width: 1.6),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(15),
        borderSide: const BorderSide(color: Color(0xFFE5484D)),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(15),
        borderSide: const BorderSide(color: Color(0xFFE5484D), width: 1.5),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final authProvider = context.watch<AuthProvider>();
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final isBusy = _submitting || authProvider.isLoading;

    final backgroundColor = isDark
        ? const Color(0xFF0B1020)
        : const Color(0xFFF4F6FF);

    final cardColor = isDark ? const Color(0xFF141B2D) : Colors.white;

    final fieldColor = isDark
        ? const Color(0xFF101729)
        : const Color(0xFFF8F9FD);

    final headingColor = Theme.of(context).colorScheme.onSurface;

    return Scaffold(
      backgroundColor: backgroundColor,
      body: Container(
        width: double.infinity,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: isDark
                ? const [Color(0xFF0B1020), Color(0xFF151A32)]
                : const [Color(0xFFF7F8FF), Color(0xFFECF8F7)],
          ),
        ),
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 30),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 460),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Center(
                      child: Container(
                        width: 72,
                        height: 72,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(23),
                          gradient: const LinearGradient(
                            colors: [_primary, _teal],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: _primary.withValues(alpha: 0.23),
                              blurRadius: 24,
                              offset: const Offset(0, 10),
                            ),
                          ],
                        ),
                        child: const Icon(
                          Icons.forum_rounded,
                          color: Colors.white,
                          size: 36,
                        ),
                      ),
                    ),
                    const SizedBox(height: 17),
                    Text(
                      'OpinionHub',
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.headlineMedium
                          ?.copyWith(
                            fontWeight: FontWeight.w800,
                            letterSpacing: -0.8,
                            color: headingColor,
                          ),
                    ),
                    const SizedBox(height: 7),
                    Text(
                      'Different perspectives. Better decisions.',
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: isDark
                            ? Colors.white70
                            : const Color(0xFF69738A),
                      ),
                    ),
                    const SizedBox(height: 30),
                    Card(
                      color: cardColor,
                      elevation: isDark ? 0 : 5,
                      shadowColor: const Color(0xFF303D72)
                          .withValues(alpha: 0.09),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(26),
                        side: BorderSide(
                          color: isDark
                              ? const Color(0xFF242D42)
                              : const Color(0xFFEDF0F7),
                        ),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(24),
                        child: Form(
                          key: _formKey,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              Text(
                                'Welcome back',
                                style: Theme.of(context).textTheme.headlineSmall
                                    ?.copyWith(
                                      fontWeight: FontWeight.w800,
                                      letterSpacing: -0.5,
                                      color: headingColor,
                                    ),
                              ),
                              const SizedBox(height: 7),
                              Text(
                                'Sign in to continue the conversation.',
                                style: Theme.of(context).textTheme.bodyMedium
                                    ?.copyWith(
                                      color: isDark
                                          ? Colors.white60
                                          : const Color(0xFF778198),
                                    ),
                              ),
                              const SizedBox(height: 25),
                              TextFormField(
                                controller: _emailController,
                                keyboardType: TextInputType.emailAddress,
                                textInputAction: TextInputAction.next,
                                autofillHints: const [
                                  AutofillHints.username,
                                  AutofillHints.email,
                                ],
                                autocorrect: false,
                                decoration: _fieldDecoration(
                                  label: 'Email address',
                                  icon: Icons.mail_outline_rounded,
                                  fillColor: fieldColor,
                                  isDark: isDark,
                                ),
                                validator: (value) {
                                  final email = value?.trim() ?? '';

                                  if (email.isEmpty) {
                                    return 'Enter your email address';
                                  }

                                  final validEmail = RegExp(
                                    r'^[^@\s]+@[^@\s]+\.[^@\s]+$',
                                  ).hasMatch(email);

                                  if (!validEmail) {
                                    return 'Enter a valid email address';
                                  }

                                  return null;
                                },
                              ),
                              const SizedBox(height: 17),
                              TextFormField(
                                controller: _passwordController,
                                obscureText: _obscurePassword,
                                textInputAction: TextInputAction.done,
                                autofillHints: const [AutofillHints.password],
                                onFieldSubmitted: (_) {
                                  if (!isBusy) {
                                    _login();
                                  }
                                },
                                decoration: _fieldDecoration(
                                  label: 'Password',
                                  icon: Icons.lock_outline_rounded,
                                  fillColor: fieldColor,
                                  isDark: isDark,
                                  suffixIcon: IconButton(
                                    tooltip: _obscurePassword
                                        ? 'Show password'
                                        : 'Hide password',
                                    onPressed: () {
                                      setState(() {
                                        _obscurePassword = !_obscurePassword;
                                      });
                                    },
                                    icon: Icon(
                                      _obscurePassword
                                          ? Icons.visibility_outlined
                                          : Icons.visibility_off_outlined,
                                    ),
                                  ),
                                ),
                                validator: (value) {
                                  if (value == null || value.isEmpty) {
                                    return 'Enter your password';
                                  }

                                  return null;
                                },
                              ),
                              const SizedBox(height: 25),
                              SizedBox(
                                height: 54,
                                child: FilledButton(
                                  onPressed: isBusy ? null : _login,
                                  style: FilledButton.styleFrom(
                                    backgroundColor: _primary,
                                    foregroundColor: Colors.white,
                                    disabledBackgroundColor: _primary
                                        .withValues(alpha: 0.55),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(15),
                                    ),
                                    textStyle: const TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                  child: isBusy
                                      ? const SizedBox(
                                          width: 22,
                                          height: 22,
                                          child: CircularProgressIndicator(
                                            strokeWidth: 2.2,
                                            color: Colors.white,
                                          ),
                                        )
                                      : const Row(
                                          mainAxisAlignment:
                                              MainAxisAlignment.center,
                                          children: [
                                            Text('Sign in'),
                                            SizedBox(width: 8),
                                            Icon(
                                              Icons.arrow_forward_rounded,
                                              size: 19,
                                            ),
                                          ],
                                        ),
                                ),
                              ),
                              const SizedBox(height: 20),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Flexible(
                                    child: Text(
                                      "Don't have an account?",
                                      style: TextStyle(
                                        color: isDark
                                            ? Colors.white70
                                            : const Color(0xFF69738A),
                                      ),
                                    ),
                                  ),
                                  TextButton(
                                    onPressed: isBusy
                                        ? null
                                        : () {
                                            Navigator.of(context).push(
                                              MaterialPageRoute<void>(
                                                builder: (_) =>
                                                    const RegisterScreen(),
                                              ),
                                            );
                                          },
                                    style: TextButton.styleFrom(
                                      foregroundColor: _primary,
                                      textStyle: const TextStyle(
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                    child: const Text('Create account'),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 22),
                    Text(
                      'A space to share ideas, understand others, and think better.',
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        height: 1.5,
                        color: isDark
                            ? Colors.white54
                            : const Color(0xFF7D869B),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
