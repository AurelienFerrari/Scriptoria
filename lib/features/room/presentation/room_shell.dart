import 'package:flutter/material.dart';
import '../../../ui/widgets/room_navbar.dart';
import 'room_chat_page.dart';
import 'room_map_page.dart';
import 'room_players_page.dart';

class RoomShell extends StatefulWidget {
  final String roomId;
  const RoomShell({Key? key, required this.roomId}) : super(key: key);

  @override
  State<RoomShell> createState() => _RoomShellState();
}

class _RoomShellState extends State<RoomShell> {
  int _tab = 0;
  final List<Widget> _roomPages = const [
    RoomChatPage(),
    RoomMapPage(),
    RoomPlayersPage(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _roomPages[_tab],
      bottomNavigationBar: RoomNavbar(
        currentIndex: _tab,
        onTap: (i) => setState(() => _tab = i),
      ),
    );
  }
}
