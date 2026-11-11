import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import 'firebase_options.dart';
import 'screens/home_screen.dart';
import 'screens/login_screen.dart';
import 'services/api.dart';
import 'services/prefs.dart';

/// Yerel emülatörle çalıştırmak için:
///   flutter run -d chrome --dart-define=USE_EMULATOR=true
const useEmulator = bool.fromEnvironment('USE_EMULATOR');
const emulatorHostOverride = String.fromEnvironment('EMULATOR_HOST');

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  if (useEmulator) {
    // Web'de sayfanın açıldığı bilgisayar, Android emülatöründe 10.0.2.2.
    final host = emulatorHostOverride.isNotEmpty
        ? emulatorHostOverride
        : kIsWeb
            // "localhost" bazı bilgisayarlarda emülatörün dinlemediği IPv6
            // adresine gider; bu yüzden 127.0.0.1 kullanılır.
            ? (Uri.base.host.isEmpty || Uri.base.host == 'localhost'
                ? '127.0.0.1'
                : Uri.base.host)
            : '10.0.2.2';
    await FirebaseAuth.instance.useAuthEmulator(host, 9099);
    FirebaseFirestore.instance.useFirestoreEmulator(host, 8080);
    FirebaseFunctions.instanceFor(region: 'europe-west1')
        .useFunctionsEmulator(host, 5001);
  }
  await Prefs.load();
  runApp(const MatDuellosuApp());
}

class MatDuellosuApp extends StatelessWidget {
  const MatDuellosuApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Mat Düellosu',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFFE0B341),
          brightness: Brightness.dark,
          surface: const Color(0xFF14181F),
        ),
        useMaterial3: true,
      ),
      home: const AuthGate(),
    );
  }
}

/// Giriş yapılmadıysa giriş ekranı, profil yoksa profil kurulumu, yoksa ana menü.
class AuthGate extends StatelessWidget {
  const AuthGate({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.userChanges(),
      builder: (context, auth) {
        if (auth.connectionState == ConnectionState.waiting) {
          return const _Loading();
        }
        final user = auth.data;
        if (user == null) return const LoginScreen();
        return StreamBuilder<Map<String, dynamic>?>(
          key: ValueKey(user.uid),
          stream: Api.userStream(user.uid),
          builder: (context, profile) {
            if (profile.hasError) {
              return Scaffold(
                  body: Center(
                      child: Text('Profil okunamadı: ${profile.error}')));
            }
            if (profile.connectionState == ConnectionState.waiting) {
              return const _Loading();
            }
            if (profile.data == null) return const ProfileSetupScreen();
            return HomeScreen(user: user, profile: profile.data!);
          },
        );
      },
    );
  }
}

class _Loading extends StatelessWidget {
  const _Loading();
  @override
  Widget build(BuildContext context) =>
      const Scaffold(body: Center(child: CircularProgressIndicator()));
}
