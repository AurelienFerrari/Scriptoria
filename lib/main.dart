import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:scriptoria/core/services/supabase_service.dart';
import 'core/navigation/route_observer.dart';
import 'core/providers/auth_provider.dart';
import 'features/home/presentation/pages/home_page.dart';
import 'features/room/presentation/home/room_create_page.dart';
import 'features/room/presentation/home/room_join_page.dart';
import 'features/profile/presentation/pages/profile_page.dart';
import 'features/settings/presentation/pages/settings_page.dart';
import 'features/auth/presentation/pages/login_page.dart';
import 'features/auth/presentation/pages/register_page.dart';
import 'features/auth/presentation/pages/forgot_password_page.dart';
import 'features/auth/presentation/pages/reset_password_page.dart';

/// Permet de naviguer (ex: après le deep link de réinitialisation de mot de
/// passe) depuis en dehors du BuildContext d'un widget, dans le listener
/// onAuthStateChange de MyApp.
final navigatorKey = GlobalKey<NavigatorState>();

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  Object? initError;
  try {
    await SupabaseService().initialize();
  } catch (e) {
    initError = e;
  }

  runApp(
    initError == null
        ? ChangeNotifierProvider(
            create: (_) => AuthProvider(),
            child: const MyApp(),
          )
        : SupabaseInitErrorApp(error: initError),
  );
}

class SupabaseInitErrorApp extends StatelessWidget {
  final Object error;
  const SupabaseInitErrorApp({super.key, required this.error});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Scriptoria',
      theme: ThemeData.dark(),
      home: Scaffold(
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.error_outline, color: Colors.red, size: 48),
                const SizedBox(height: 16),
                const Text(
                  "Impossible d'initialiser Supabase",
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 12),
                Text('$error', textAlign: TextAlign.center),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class MyApp extends StatefulWidget {
  const MyApp({Key? key}) : super(key: key);

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  StreamSubscription<AuthState>? _authStateSubscription;

  @override
  void initState() {
    super.initState();
    // Le deep link de réinitialisation de mot de passe (voir
    // SupabaseService.authCallbackUrl) établit une session puis déclenche
    // cet événement : on redirige alors vers l'écran "nouveau mot de passe".
    _authStateSubscription = context.read<AuthProvider>().onAuthStateChange.listen((data) {
      if (data.event == AuthChangeEvent.passwordRecovery) {
        navigatorKey.currentState?.push(
          MaterialPageRoute(builder: (_) => const ResetPasswordPage()),
        );
      }
    });
  }

  @override
  void dispose() {
    _authStateSubscription?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isLoggedIn = context.watch<AuthProvider>().isLoggedIn;

    return MaterialApp(
      navigatorKey: navigatorKey,
      navigatorObservers: [routeObserver],
      title: 'Scriptoria',
      theme: ThemeData.dark(),
      home: isLoggedIn ? const HomePage() : const LoginPage(),
      routes: {
        '/home': (context) => const HomePage(),
        '/login': (context) => const LoginPage(),
        '/register': (context) => const RegisterPage(),
        '/forgot-password': (context) => const ForgotPasswordPage(),
        '/CreationRoom': (context) => const RoomCreatePage(),
        '/JoinRoom': (context) => const RoomJoinPage(),
        '/profile': (context) => const ProfilePage(),
        '/settings': (context) => const SettingsPage(),
      },
    );
  }
}
