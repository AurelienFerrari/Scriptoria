import 'package:flutter/material.dart';

class RoomNavbar extends StatelessWidget {
  final int currentIndex;
  final ValueChanged<int> onTap;

  const RoomNavbar({
    Key? key,
    required this.currentIndex,
    required this.onTap,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Color(0xFF161622),
        border: Border(
          top: BorderSide(color: Color(0xFF232336), width: 1),
        ),
      ),
      padding: const EdgeInsets.only(top: 4, bottom: 8),
      child: BottomNavigationBar(
        type: BottomNavigationBarType.fixed,
        currentIndex: currentIndex,
        onTap: onTap,
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconSize: 28,
        selectedItemColor: Color(0xFF6FE3E1),
        unselectedItemColor: Color(0xCCFFFFFF),
        selectedLabelStyle: const TextStyle(
          fontWeight: FontWeight.bold,
          fontSize: 13,
        ),
        unselectedLabelStyle: const TextStyle(
          fontWeight: FontWeight.normal,
          fontSize: 13,
        ),
        showUnselectedLabels: true,
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.home),
            label: 'Accueil',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.folder),
            label: 'Contenus',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.handyman),
            label: 'Outils',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.chat),
            label: 'Chat',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.settings),
            label: 'Paramètres',
          ),
        ],
      ),
    );
  }
}
