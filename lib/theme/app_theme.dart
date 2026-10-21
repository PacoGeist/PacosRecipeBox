import 'package:flutter/material.dart';

import '../services/settings.dart';

/// Extra colors not covered by ColorScheme.
class AppPalette extends ThemeExtension<AppPalette> {
  final Color border;
  final Color card;
  final Color tomato;
  final Color basil;
  final Color saffron;
  final Color eggplant;
  final Color blueberry;

  const AppPalette({
    required this.border,
    required this.card,
    this.tomato = const Color(0xFFD84315),
    this.basil = const Color(0xFF558B2F),
    this.saffron = const Color(0xFFF9A825),
    this.eggplant = const Color(0xFF6A1B9A),
    this.blueberry = const Color(0xFF3949AB),
  });

  @override
  AppPalette copyWith({Color? border, Color? card}) =>
      AppPalette(border: border ?? this.border, card: card ?? this.card);

  @override
  AppPalette lerp(AppPalette? other, double t) => other == null
      ? this
      : AppPalette(border: Color.lerp(border, other.border, t)!, card: Color.lerp(card, other.card, t)!);
}

extension PaletteX on BuildContext {
  AppPalette get palette => Theme.of(this).extension<AppPalette>()!;
}

class AppTheme {
  // Food-inspired defaults: tomato, basil, saffron on warm parchment.
  static const tomato = Color(0xFFD84315);
  static const basil = Color(0xFF558B2F);
  static const saffron = Color(0xFFF9A825);

  static ThemeData build(AppSettings s, Brightness b) {
    final dark = b == Brightness.dark;
    final accent = s.accentColor ?? tomato;
    final bg = s.backgroundColor ?? (dark ? const Color(0xFF1E1612) : const Color(0xFFFFF6E9));
    final card = s.foregroundColor ?? (dark ? const Color(0xFF2E231C) : Colors.white);
    final border = s.borderColor ?? (dark ? const Color(0xFF6D4C41) : const Color(0xFFF0C9A4));
    final text = s.textColor ?? (dark ? const Color(0xFFFBEBD8) : const Color(0xFF3E2723));

    final scheme = ColorScheme.fromSeed(
      seedColor: accent,
      brightness: b,
      primary: dark ? Color.lerp(accent, Colors.white, 0.25) : accent,
      secondary: basil,
      tertiary: saffron,
      surface: card,
      onSurface: text,
    );

    final baseText = (dark ? Typography.material2021().white : Typography.material2021().black)
        .apply(fontFamily: s.fontFamily, bodyColor: text, displayColor: text);

    return ThemeData(
      useMaterial3: true,
      brightness: b,
      colorScheme: scheme,
      scaffoldBackgroundColor: bg,
      fontFamily: s.fontFamily,
      fontFamilyFallback: const ['NotoColorEmoji'],
      textTheme: baseText.copyWith(
        headlineLarge: baseText.headlineLarge?.copyWith(fontFamily: 'PlayfairDisplay', fontWeight: FontWeight.w700),
        headlineMedium: baseText.headlineMedium?.copyWith(fontFamily: 'PlayfairDisplay', fontWeight: FontWeight.w700),
        headlineSmall: baseText.headlineSmall?.copyWith(fontFamily: 'PlayfairDisplay', fontWeight: FontWeight.w700),
        titleLarge: baseText.titleLarge?.copyWith(fontWeight: FontWeight.w800),
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: bg,
        foregroundColor: text,
        elevation: 0,
        scrolledUnderElevation: 2,
        centerTitle: false,
        titleTextStyle: TextStyle(
            fontFamily: 'PlayfairDisplay', fontSize: 22, fontWeight: FontWeight.w700, color: text,
            fontFamilyFallback: const ['NotoColorEmoji']),
      ),
      cardTheme: CardThemeData(
        color: card,
        elevation: 1.5,
        shadowColor: Colors.brown.withValues(alpha: 0.25),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16), side: BorderSide(color: border, width: 1.2)),
        margin: EdgeInsets.zero,
      ),
      dividerColor: border,
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: card,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide(color: border)),
        enabledBorder:
            OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide(color: border)),
        focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14), borderSide: BorderSide(color: scheme.primary, width: 2)),
      ),
      chipTheme: ChipThemeData(
        side: BorderSide(color: border),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      ),
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: accent,
        foregroundColor: Colors.white,
      ),
      extensions: [AppPalette(border: border, card: card)],
    );
  }
}
