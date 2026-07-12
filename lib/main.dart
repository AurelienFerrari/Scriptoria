import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:scriptoria/core/services/supabase_service.dart';
import 'core/providers/auth_provider.dart';
import 'features/home/presentation/pages/home_page.dart';
import 'features/room/presentation/shell/room_shell.dart';
import 'features/room/presentation/home/room_create_page.dart';
import 'features/room/presentation/home/room_join_page.dart';
import 'features/profile/presentation/pages/profile_page.dart';
import 'features/auth/presentation/pages/login_page.dart';
import 'features/auth/presentation/pages/register_page.dart';

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

class MyApp extends StatelessWidget {
  const MyApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final isLoggedIn = context.watch<AuthProvider>().isLoggedIn;

    return MaterialApp(
      title: 'Scriptoria',
      theme: ThemeData.dark(),
      home: isLoggedIn ? const HomePage() : const LoginPage(),
      routes: {
        '/home': (context) => const HomePage(),
        '/login': (context) => const LoginPage(),
        '/register': (context) => const RegisterPage(),
        '/room': (context) => const RoomShell(roomId: 'demo'),
        '/CreationRoom': (context) => const RoomCreatePage(),
        '/JoinRoom': (context) => const RoomJoinPage(),
        '/profile': (context) => const ProfilePage(),
      },
    );
  }
}
