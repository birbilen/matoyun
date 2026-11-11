import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

class ApiError implements Exception {
  final String code;
  final String message;
  ApiError(this.code, this.message);
  @override
  String toString() => message;
}

/// Sunucu (Cloud Functions) çağrıları ve sunucu saati.
class Api {
  static final _functions =
      FirebaseFunctions.instanceFor(region: 'europe-west1');
  static int _offset = 0;
  static int _bestRtt = 1 << 30;

  /// Sunucu saatine göre şu an (ms). Geri sayımlar buna göre gösterilir.
  static int get serverNow => DateTime.now().millisecondsSinceEpoch + _offset;

  static Future<Map<String, dynamic>> call(String name,
      [Map<String, dynamic>? data]) async {
    final t0 = DateTime.now().millisecondsSinceEpoch;
    try {
      final res = await _functions.httpsCallable(name).call(data ?? {});
      final t1 = DateTime.now().millisecondsSinceEpoch;
      final map = _deep(res.data) as Map<String, dynamic>;
      final now = map['now'];
      // En hızlı yanıt, saat farkını en doğru veren ölçümdür.
      if (now is num && t1 - t0 <= _bestRtt + 50) {
        _bestRtt = t1 - t0;
        _offset = now.toInt() - (t0 + t1) ~/ 2;
      }
      return map;
    } on FirebaseFunctionsException catch (e) {
      final known = e.code != 'internal' && e.code != 'unknown';
      throw ApiError(
          e.code,
          known && (e.message ?? '').isNotEmpty
              ? e.message!
              : 'Sunucuya ulaşılamadı. Bağlantını kontrol edip tekrar dene.');
    }
  }

  static dynamic _deep(dynamic v) {
    if (v is Map) return v.map((k, x) => MapEntry(k.toString(), _deep(x)));
    if (v is List) return v.map(_deep).toList();
    return v;
  }

  static Stream<Map<String, dynamic>?> userStream(String uid) =>
      FirebaseFirestore.instance
          .doc('users/$uid')
          .snapshots()
          .map((s) => s.data());

  static Stream<DocumentSnapshot<Map<String, dynamic>>> roomStream(
          String code) =>
      FirebaseFirestore.instance.doc('rooms/$code').snapshots();
}

/// Giriş işlemleri: Google hesabı ya da misafir (anonim) hesap.
class AuthService {
  static final _auth = FirebaseAuth.instance;

  static Future<void> signInWithGoogle() async {
    final provider = GoogleAuthProvider();
    if (kIsWeb) {
      await _auth.signInWithPopup(provider);
    } else {
      await _auth.signInWithProvider(provider);
    }
  }

  static Future<void> signInAsGuest() => _auth.signInAnonymously();

  /// Misafir hesabı Google hesabına bağlar; ilerleme korunur.
  static Future<void> linkGoogle() async {
    final user = _auth.currentUser!;
    final provider = GoogleAuthProvider();
    if (kIsWeb) {
      await user.linkWithPopup(provider);
    } else {
      await user.linkWithProvider(provider);
    }
  }

  static Future<void> signOut() => _auth.signOut();

  static String errorText(Object e) {
    if (e is FirebaseAuthException) {
      switch (e.code) {
        case 'credential-already-in-use':
        case 'email-already-in-use':
          return 'Bu Google hesabı zaten kayıtlı. Çıkış yapıp o hesapla giriş '
              'yapabilirsin (misafir ilerlemesi aktarılmaz).';
        case 'popup-closed-by-user':
        case 'cancelled-popup-request':
        case 'web-context-cancelled':
          return 'Giriş iptal edildi.';
        case 'popup-blocked':
          return 'Tarayıcı açılır pencereyi engelledi. İzin verip tekrar dene.';
        case 'network-request-failed':
          return 'İnternet bağlantısı yok.';
      }
      return 'Giriş yapılamadı (${e.code}).';
    }
    return e.toString();
  }
}
