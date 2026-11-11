import 'package:flutter/material.dart';

/// Marka renkleri. Tek Hamlede Mat'ın renk kodlarını buraya yaz;
/// uygulamanın tamamı bu değerleri kullanır.
class Brand {
  static const primary = Color(0xFFE0B341); // ana vurgu (düğmeler, logo)
  static const backgroundTop = Color(0xFF232E42); // arka plan üst
  static const background = Color(0xFF12161D); // arka plan alt
  static const surface = Color(0xFF2A3345); // kart ve şık yüzeyi
  static const correct = Color(0xFF2E9E4F);
  static const wrong = Color(0xFFD64545);

  static ThemeData theme() => ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: primary,
          brightness: Brightness.dark,
          primary: primary,
          surface: background,
        ),
        scaffoldBackgroundColor: background,
        appBarTheme: const AppBarTheme(
            backgroundColor: Colors.transparent, elevation: 0),
        useMaterial3: true,
      );
}
