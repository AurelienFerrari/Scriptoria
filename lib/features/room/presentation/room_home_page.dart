import 'package:flutter/material.dart';

/// Accueil d'une room : son identité (icône, nom, description) et sa dernière
/// mise à jour.
///
/// La galerie vivait ici, en mémoire seulement. Elle est passée dans l'onglet
/// « Contenus », où elle est persistée et partagée — sa place logique, aux
/// côtés des notes du MJ.
class RoomHomePage extends StatelessWidget {
  final String roomName;
  final String? iconPath;
  final bool iconIsAsset;
  final String description;
  final String lastUpdate;
  final String lastUpdateText;

  const RoomHomePage({
    Key? key,
    required this.roomName,
    this.iconPath,
    this.iconIsAsset = true,
    required this.description,
    required this.lastUpdate,
    this.lastUpdateText = 'Dernière mise à jour',
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          tooltip: 'Retour',
          onPressed: () {
            Navigator.of(context).pop(); // Retour à la home page
          },
        ),
        title: Text(roomName),
        backgroundColor: const Color(0xFF161622),
      ),
      backgroundColor: const Color(0xFF161622),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(32),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            if (iconPath != null)
              Container(
                width: 96,
                height: 96,
                margin: const EdgeInsets.only(top: 32, bottom: 24), // baisse l'icône
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(24),
                  color: Colors.grey.shade900,
                ),
                // Décorative : le nom de la room est affiché juste en dessous.
                child: iconIsAsset
                    ? Image.asset(iconPath!, fit: BoxFit.cover, excludeFromSemantics: true)
                    : Image.network(
                        iconPath!,
                        fit: BoxFit.cover,
                        excludeFromSemantics: true,
                      ),
              ),
            Text(
              roomName,
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 28,
                color: Colors.white,
              ),
              textAlign: TextAlign.center,
            ),
            SizedBox(height: 12),
            Text(
              description,
              style: TextStyle(fontSize: 16, color: Colors.white),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 40),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.update, color: Colors.white, size: 20),
                SizedBox(width: 8),
                Text(
                  lastUpdateText,
                  style: TextStyle(color: Colors.white, fontSize: 15),
                ),
                SizedBox(width: 8),
                Text(
                  lastUpdate,
                  style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

