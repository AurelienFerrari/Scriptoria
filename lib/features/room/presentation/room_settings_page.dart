import 'package:flutter/material.dart';

class RoomSettingsPage extends StatelessWidget {
  const RoomSettingsPage({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Paramètres de la Room'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          ListTile(
            leading: const Icon(Icons.edit),
            title: const Text('Nom de la room'),
            subtitle: const Text('Modifier le nom de la room'),
            onTap: () {},
          ),
          SwitchListTile(
            title: const Text('Room privée'),
            value: false,
            onChanged: (val) {},
          ),
          ListTile(
            leading: const Icon(Icons.delete),
            title: const Text('Supprimer la room'),
            onTap: () {},
            textColor: Colors.red,
            iconColor: Colors.red,
          ),
        ],
      ),
    );
  }
}
