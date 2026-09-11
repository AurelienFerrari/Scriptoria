import 'package:flutter/material.dart';
import 'outils/de_page.dart';
import 'outils/frise_page.dart';
import 'outils/relations_page.dart';
import '../../../ui/window_size.dart';
import 'room_route.dart';

const Color _bgColor = Color(0xFF161622);
const Color _tileColor = Color(0xFF232336);

/// Un outil de la room : ce qu'on affiche, et l'écran qu'il ouvre.
class _Tool {
  final IconData icon;
  final String label;
  final Widget page;

  const _Tool({required this.icon, required this.label, required this.page});
}

class RoomToolsPage extends StatelessWidget {
  const RoomToolsPage({Key? key}) : super(key: key);

  static const List<_Tool> _tools = [
    _Tool(icon: Icons.casino, label: 'Dé', page: DePage()),
    _Tool(icon: Icons.timeline, label: 'Frise', page: FrisePage()),
    _Tool(icon: Icons.people, label: 'Relations', page: RelationsPage()),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Outils'),
        backgroundColor: _bgColor,
      ),
      backgroundColor: _bgColor,
      body: SafeArea(
        // Couché, trois boutons empilés ne tiennent pas entre l'AppBar et la
        // barre de navigation : il reste à peine 270 dp de haut sur un S24+.
        // Ils se rangent alors côte à côte, là où la largeur abonde.
        child: isCompactLandscape(context)
            ? _buildRow(context)
            : _buildColumn(context),
      ),
    );
  }

  Widget _buildColumn(BuildContext context) {
    // `Center` autour du défilement : centré tant que tout tient, défilant
    // sinon — un petit écran ne doit jamais couper le dernier outil.
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (var i = 0; i < _tools.length; i++) ...[
              if (i > 0) const SizedBox(height: 24),
              ElevatedButton.icon(
                icon: Icon(_tools[i].icon),
                label: Text(_tools[i].label),
                style: _style(const Size(double.infinity, 56)),
                onPressed: () => pushRoomRoute(context, _tools[i].page),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildRow(BuildContext context) {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Row(
          children: [
            for (var i = 0; i < _tools.length; i++) ...[
              if (i > 0) const SizedBox(width: 16),
              Expanded(
                child: ElevatedButton(
                  style: _style(const Size(0, 120)),
                  onPressed: () => pushRoomRoute(context, _tools[i].page),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(_tools[i].icon, size: 36),
                      const SizedBox(height: 12),
                      Text(_tools[i].label),
                    ],
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  ButtonStyle _style(Size minimumSize) {
    return ElevatedButton.styleFrom(
      minimumSize: minimumSize,
      backgroundColor: _tileColor,
      foregroundColor: Colors.white,
      textStyle: const TextStyle(fontSize: 18, fontWeight: FontWeight.w500),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
    );
  }
}
