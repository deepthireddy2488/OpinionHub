import 'package:flutter/material.dart';

class AppTheme {
  AppTheme._();

  static const Color primary = Color(0xFF625BFF);
  static const Color secondary = Color(0xFF20BFA9);

  static const Color lightBackground = Color(0xFFF6F7FC);
  static const Color darkBackground = Color(0xFF0B1020);

  static const Color lightCard = Colors.white;
  static const Color darkCard = Color(0xFF141B2D);

  static ThemeData get lightTheme => _buildTheme(
    brightness: Brightness.light,
    background: lightBackground,
    card: lightCard,
  );

  static ThemeData get darkTheme => _buildTheme(
    brightness: Brightness.dark,
    background: darkBackground,
    card: darkCard,
  );

  static ThemeData _buildTheme({
    required Brightness brightness,
    required Color background,
    required Color card,
  }) {
    final scheme =
        ColorScheme.fromSeed(
          seedColor: primary,
          brightness: brightness,
        ).copyWith(
          primary: primary,
          secondary: secondary,
          surface: card,
          error: const Color(0xFFE5484D),
        );

    final isDark = brightness == Brightness.dark;
    final border = isDark ? const Color(0xFF2B354A) : const Color(0xFFE6E9F2);

    final fieldFill = isDark
        ? const Color(0xFF101729)
        : const Color(0xFFF7F8FC);

    OutlineInputBorder inputBorder({Color? color, double width = 1}) {
      return OutlineInputBorder(
        borderRadius: BorderRadius.circular(15),
        borderSide: color == null
            ? BorderSide.none
            : BorderSide(color: color, width: width),
      );
    }

    final typography = Typography.material2021(colorScheme: scheme);

    return ThemeData(
      useMaterial3: true,
      brightness: brightness,
      colorScheme: scheme,
      scaffoldBackgroundColor: background,
      textTheme: isDark ? typography.white : typography.black,

      appBarTheme: AppBarTheme(
        backgroundColor: background,
        foregroundColor: scheme.onSurface,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        titleTextStyle: TextStyle(
          color: scheme.onSurface,
          fontSize: 21,
          fontWeight: FontWeight.w800,
          letterSpacing: -0.4,
        ),
      ),

      cardTheme: CardThemeData(
        color: card,
        elevation: isDark ? 0 : 1,
        shadowColor: const Color(0xFF303D72).withValues(alpha: 0.05),
        margin: EdgeInsets.zero,
        clipBehavior: Clip.antiAlias,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: BorderSide(color: border),
        ),
      ),

      dividerTheme: DividerThemeData(color: border, thickness: 1, space: 1),

      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: fieldFill,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 15,
        ),
        border: inputBorder(),
        enabledBorder: inputBorder(color: border),
        focusedBorder: inputBorder(color: primary, width: 1.6),
        errorBorder: inputBorder(color: scheme.error),
        focusedErrorBorder: inputBorder(color: scheme.error, width: 1.5),
        labelStyle: TextStyle(color: scheme.onSurfaceVariant),
        hintStyle: TextStyle(
          color: scheme.onSurfaceVariant.withValues(alpha: 0.75),
        ),
      ),

      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          minimumSize: const Size.fromHeight(50),
          backgroundColor: primary,
          foregroundColor: Colors.white,
          disabledBackgroundColor: primary.withValues(alpha: 0.45),
          disabledForegroundColor: Colors.white70,
          elevation: 0,
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 13),
          textStyle: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(15),
          ),
        ),
      ),

      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          minimumSize: const Size.fromHeight(50),
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(15),
          ),
        ),
      ),

      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          minimumSize: const Size.fromHeight(48),
          side: BorderSide(color: border),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(15),
          ),
        ),
      ),

      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: primary,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          textStyle: const TextStyle(fontWeight: FontWeight.w700),
        ),
      ),

      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: primary,
        foregroundColor: Colors.white,
        elevation: 2,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      ),

      chipTheme: ChipThemeData(
        backgroundColor: scheme.surfaceContainerHighest,
        selectedColor: scheme.primaryContainer,
        side: BorderSide.none,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        labelStyle: TextStyle(color: scheme.onSurface),
      ),

      bottomNavigationBarTheme: BottomNavigationBarThemeData(
        backgroundColor: card,
        selectedItemColor: primary,
        unselectedItemColor: scheme.onSurfaceVariant,
        type: BottomNavigationBarType.fixed,
        elevation: 0,
      ),

      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: isDark
            ? const Color(0xFF242D42)
            : const Color(0xFF20263A),
        contentTextStyle: const TextStyle(color: Colors.white),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        insetPadding: const EdgeInsets.all(16),
      ),

      progressIndicatorTheme: const ProgressIndicatorThemeData(color: primary),

      tabBarTheme: TabBarThemeData(
        labelColor: scheme.primary,
        unselectedLabelColor: scheme.onSurfaceVariant,
        indicatorSize: TabBarIndicatorSize.tab,
        dividerColor: Colors.transparent,
        labelStyle: const TextStyle(fontWeight: FontWeight.w700),
      ),
    );
  }
}
