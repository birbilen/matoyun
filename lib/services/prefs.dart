import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Cihazda saklanan ayarlar.
class Prefs {
  static bool sound = true;

  static Future<void> load() async {
    final p = await SharedPreferences.getInstance();
    sound = p.getBool('sound') ?? true;
  }

  static Future<void> setSound(bool v) async {
    sound = v;
    (await SharedPreferences.getInstance()).setBool('sound', v);
  }

  /// Şık seçildiğinde kısa tıklama sesi (Android'de çalışır).
  static void click() {
    if (sound) SystemSound.play(SystemSoundType.click);
  }
}
