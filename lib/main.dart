import 'package:flutter/material.dart';
import 'package:scriptoria/core/services/supabase_service.dart';
import 'core/theme/app_theme.dart';
import 'features/home/presentation/pages/home_page.dart';
import 'features/room/presentation/shell/room_shell.dart';
import 'features/room/presentation/home/room_create_page.dart';
import 'features/room/presentation/home/room_join_page.dart';
import 'features/profile/presentation/pages/profile_page.dart';
import 'features/auth/presentation/pages/login_page.dart';
import 'features/auth/presentation/pages/register_page.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Initialiser Supabase
  final supabaseService = SupabaseService();
  await supabaseService.initialize();
  
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final supabaseService = SupabaseService();
    final isLoggedIn = supabaseService.isUserLoggedIn();

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
