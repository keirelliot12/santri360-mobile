import 'package:flutter/material.dart';

/// Tema dari warna brand pesantren. Teks sedikit lebih besar: banyak wali usia 40+.
ThemeData buildTheme(Color seed, Brightness brightness) {
  final scheme = ColorScheme.fromSeed(seedColor: seed, brightness: brightness);
  final base = ThemeData(colorScheme: scheme, useMaterial3: true);
  return base.copyWith(
    textTheme: base.textTheme.apply(fontSizeFactor: 1.05),
    inputDecorationTheme: const InputDecorationTheme(
      border: OutlineInputBorder(),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(52)),
    ),
  );
}
