// YER TUTUCU DOSYA.
// Bu ayarlar yalnızca yerel emülatörle (hesap gerektirmeyen "demo" proje)
// çalışır. Gerçek Firebase projene bağlanmak için şu komutu çalıştır;
// bu dosyanın üzerine senin projenin ayarları yazılır:
//
//   flutterfire configure
//
import 'package:firebase_core/firebase_core.dart';

class DefaultFirebaseOptions {
  static FirebaseOptions get currentPlatform => const FirebaseOptions(
        apiKey: 'demo-api-key',
        appId: '1:000000000000:web:0000000000000000',
        messagingSenderId: '000000000000',
        projectId: 'demo-matduellosu',
        authDomain: 'demo-matduellosu.firebaseapp.com',
      );
}
