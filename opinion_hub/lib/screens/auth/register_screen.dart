import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../providers/auth_provider.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  static const Color _primary = Color(0xFF625BFF);
  static const Color _teal = Color(0xFF20BFA9);

  final _formKey = GlobalKey<FormState>();

  final _nicknameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();

  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;
  bool _submitting = false;

  @override
  void dispose() {
    _nicknameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  Future<void> _register() async {
    if (_submitting) {
      return;
    }

    final form = _formKey.currentState;
    if (form == null || !form.validate()) {
      return;
    }

    FocusScope.of(context).unfocus();

    final nickname = _nicknameController.text.trim();
    final email = _emailController.text.trim();
    final password = _passwordController.text;

    final authProvider = context.read<AuthProvider>();

    setState(() => _submitting = true);

    try {
      await authProvider.register(
        email: email,
        password: password,
        nickname: nickname,
      );
    } finally {
      if (mounted) {
        setState(() => _submitting = false);
      }
    }

    if (!mounted) {
      return;
    }

    // Successful registration also automatically signs in the user.
    // Remove the registration route so it cannot cover the home screen.
    if (authProvider.isAuthenticated) {
      Navigator.of(context).popUntil((route) => route.isFirst);
      return;
    }

    final message = authProvider.errorMessage;

    if (message == null) {
      return;
    }

    if (authProvider.registrationCompleted) {
      // Account creation succeeded, but automatic login failed.
      // Return to login instead of leaving the user on the
      // registration screen where another registration may fail.
      final messenger = ScaffoldMessenger.of(context);

      authProvider.clearError();

      Navigator.of(context).popUntil((route) => route.isFirst);

      messenger
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(
            content: Text(message),
            behavior: SnackBarBehavior.floating,
            backgroundColor: const Color(0xFF8A5A00),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
            ),
            margin: const EdgeInsets.all(16),
          ),
        );

      return;
    }

    _showError(message);
    authProvider.clearError();
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
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        foregroundColor: headingColor,
        title: Text(
          'Create account',
          style: Theme.of(context).textTheme.titleLarge
              ?.copyWith(fontWeight: FontWeight.w700),
        ),
      ),
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
          top: false,
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(22, 12, 22, 30),
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 460),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Center(
                      child: Container(
                        width: 68,
                        height: 68,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(22),
                          gradient: const LinearGradient(
                            colors: [_primary, _teal],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: _primary.withValues(alpha: 0.22),
                              blurRadius: 22,
                              offset: const Offset(0, 9),
                            ),
                          ],
                        ),
                        child: const Icon(
                          Icons.person_add_alt_1_rounded,
                          color: Colors.white,
                          size: 32,
                        ),
                      ),
                    ),
                    const SizedBox(height: 17),
                    Text(
                      'Join OpinionHub',
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.headlineSmall
                          ?.copyWith(
                            fontWeight: FontWeight.w800,
                            letterSpacing: -0.6,
                            color: headingColor,
                          ),
                    ),
                    const SizedBox(height: 7),
                    Text(
                      'Your perspective belongs here.',
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: isDark
                            ? Colors.white70
                            : const Color(0xFF69738A),
                      ),
                    ),
                    const SizedBox(height: 26),
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
                                'Create your account',
                                style: Theme.of(context).textTheme.titleLarge
                                    ?.copyWith(
                                      fontWeight: FontWeight.w800,
                                      letterSpacing: -0.4,
                                      color: headingColor,
                                    ),
                              ),
                              const SizedBox(height: 7),
                              Text(
                                'A few details to get you started.',
                                style: Theme.of(context).textTheme.bodyMedium
                                    ?.copyWith(
                                      color: isDark
                                          ? Colors.white60
                                          : const Color(0xFF778198),
                                    ),
                              ),
                              const SizedBox(height: 24),
                              TextFormField(
                                controller: _nicknameController,
                                textCapitalization: TextCapitalization.words,
                                textInputAction: TextInputAction.next,
                                autofillHints: const [AutofillHints.nickname],
                                decoration: _fieldDecoration(
                                  label: 'Nickname',
                                  icon: Icons.person_outline_rounded,
                                  fillColor: fieldColor,
                                  isDark: isDark,
                                ),
                                validator: (value) {
                                  final nickname = value?.trim() ?? '';

                                  if (nickname.isEmpty) {
                                    return 'Enter a nickname';
                                  }

                                  if (nickname.length < 2) {
                                    return 'Use at least 2 characters';
                                  }

                                  return null;
                                },
                              ),
                              const SizedBox(height: 16),
                              TextFormField(
                                controller: _emailController,
                                keyboardType: TextInputType.emailAddress,
                                textInputAction: TextInputAction.next,
                                autofillHints: const [AutofillHints.email],
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
                              const SizedBox(height: 16),
                              TextFormField(
                                controller: _passwordController,
                                obscureText: _obscurePassword,
                                textInputAction: TextInputAction.next,
                                autofillHints: const [
                                  AutofillHints.newPassword,
                                ],
                                enableSuggestions: false,
                                autocorrect: false,
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
                                    return 'Create a password';
                                  }

                                  if (value.length < 6) {
                                    return 'Use at least 6 characters';
                                  }

                                  return null;
                                },
                              ),
                              const SizedBox(height: 16),
                              TextFormField(
                                controller: _confirmPasswordController,
                                obscureText: _obscureConfirmPassword,
                                textInputAction: TextInputAction.done,
                                enableSuggestions: false,
                                autocorrect: false,
                                onFieldSubmitted: (_) {
                                  if (!isBusy) {
                                    _register();
                                  }
                                },
                                decoration: _fieldDecoration(
                                  label: 'Confirm password',
                                  icon: Icons.verified_user_outlined,
                                  fillColor: fieldColor,
                                  isDark: isDark,
                                  suffixIcon: IconButton(
                                    tooltip: _obscureConfirmPassword
                                        ? 'Show password'
                                        : 'Hide password',
                                    onPressed: () {
                                      setState(() {
                                        _obscureConfirmPassword =
                                            !_obscureConfirmPassword;
                                      });
                                    },
                                    icon: Icon(
                                      _obscureConfirmPassword
                                          ? Icons.visibility_outlined
                                          : Icons.visibility_off_outlined,
                                    ),
                                  ),
                                ),
                                validator: (value) {
                                  if (value == null || value.isEmpty) {
                                    return 'Confirm your password';
                                  }

                                  if (value != _passwordController.text) {
                                    return 'Passwords do not match';
                                  }

                                  return null;
                                },
                              ),
                              const SizedBox(height: 25),
                              SizedBox(
                                height: 54,
                                child: FilledButton(
                                  onPressed: isBusy ? null : _register,
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
                                            Text('Create account'),
                                            SizedBox(width: 8),
                                            Icon(
                                              Icons.arrow_forward_rounded,
                                              size: 19,
                                            ),
                                          ],
                                        ),
                                ),
                              ),
                              const SizedBox(height: 19),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Flexible(
                                    child: Text(
                                      'Already have an account?',
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
                                            Navigator.of(context).pop();
                                          },
                                    style: TextButton.styleFrom(
                                      foregroundColor: _primary,
                                      textStyle: const TextStyle(
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                    child: const Text('Sign in'),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
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
