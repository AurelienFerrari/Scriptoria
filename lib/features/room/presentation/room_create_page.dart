import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:permission_handler/permission_handler.dart';
import 'dart:typed_data';
import 'dart:io';

class RoomCreatePage extends StatefulWidget {
  const RoomCreatePage({Key? key}) : super(key: key);

  @override
  State<RoomCreatePage> createState() => _RoomCreatePageState();
}

class _RoomCreatePageState extends State<RoomCreatePage> {
  final _formKey = GlobalKey<FormState>();
  String _roomName = '';
  String _description = '';
  int _nbPlayers = 4;
  String? _iconPath; // Chemin local de l'icône
  bool _iconIsAsset = true;

  XFile? _pickedFile;

  Future<void> _pickIcon() async {
    final List<String> demoIcons = [
      'assets/images/dragon.png',
      'assets/images/mystery.png',
    ];
    await showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Choisir une icône (PNG carré 96x96)'),
        content: SizedBox(
          width: 260,
          child: Wrap(
            spacing: 16,
            runSpacing: 16,
            children: [
              ...demoIcons.map((icon) => GestureDetector(
                onTap: () {
                  setState(() {
                    _iconPath = icon;
                    _iconIsAsset = true;
                    _pickedFile = null;
                  });
                  Navigator.pop(context);
                },
                child: Image.asset(icon, width: 64, height: 64),
              )),
              GestureDetector(
                onTap: () async {
                  bool granted = false;
                  if (kIsWeb) {
                    granted = true;
                  } else if (Platform.isAndroid) {
                    // Android 13+ (API 33)
                    if (await Permission.photos.request().isGranted) {
                      granted = true;
                    } else if (await Permission.storage.request().isGranted) {
                      granted = true;
                    }
                  } else if (Platform.isIOS) {
                    if (await Permission.photos.request().isGranted) {
                      granted = true;
                    }
                  } else {
                    granted = true; // desktop, etc.
                  }
                  if (!granted) {
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text("Permission refusée, impossible d'accéder à la galerie.")),
                      );
                    }
                    return;
                  }
                  final ImagePicker picker = ImagePicker();
                  final XFile? file = await picker.pickImage(source: ImageSource.gallery);
                  if (file != null) {
                    setState(() {
                      _pickedFile = file;
                      _iconPath = file.path;
                      _iconIsAsset = false;
                    });
                    Navigator.pop(context);
                  }
                },
                child: Container(
                  width: 64,
                  height: 64,
                  decoration: BoxDecoration(
                    color: Colors.grey[800],
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.grey),
                  ),
                  child: const Icon(Icons.upload_file, color: Colors.white70, size: 32),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Créer une room')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Nom de la room
              const Text('Nom de la room', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
              const SizedBox(height: 10),
              TextFormField(
                decoration: const InputDecoration(
                  hintText: 'Ex: Mystères de l\'Ombre',
                  border: OutlineInputBorder(),
                ),
                validator: (value) => value == null || value.isEmpty ? 'Veuillez entrer un nom' : null,
                onSaved: (value) => _roomName = value ?? '',
              ),
              const SizedBox(height: 24),
              // Icône du RP
              const Text('Icône du RP (PNG carré 96x96)', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
              const SizedBox(height: 8),
              Row(
                children: [
                  GestureDetector(
                    onTap: _pickIcon,
                    child: Container(
                      width: 96,
                      height: 96,
                      decoration: BoxDecoration(
                        color: Colors.grey[900],
                        border: Border.all(color: Colors.grey),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: _iconPath != null
                        ? ClipRRect(
                            borderRadius: BorderRadius.circular(12),
                            child: _iconIsAsset
                                ? Image.asset(_iconPath!, fit: BoxFit.cover)
                                : (kIsWeb && _pickedFile != null)
                                    ? FutureBuilder<Uint8List>(
                                        future: _pickedFile!.readAsBytes(),
                                        builder: (context, snapshot) {
                                          if (snapshot.connectionState == ConnectionState.done && snapshot.hasData) {
                                            return Image.memory(snapshot.data!, fit: BoxFit.cover);
                                          } else {
                                            return const Center(child: CircularProgressIndicator());
                                          }
                                        },
                                      )
                                    : Image.file(
                                        File(_iconPath!),
                                        fit: BoxFit.cover,
                                        errorBuilder: (context, error, stackTrace) => const Icon(Icons.broken_image, color: Colors.red),
                                      ),
                          )
                        : const Center(child: Icon(Icons.add_a_photo, size: 36, color: Colors.white38)),
                    ),
                  ),
                  const SizedBox(width: 16),
                  const Expanded(
                    child: Text('Format recommandé : PNG carré, 96x96px. Exemple : dragon.png', style: TextStyle(fontSize: 13)),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              // Description
              const Text('Description', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
              const SizedBox(height: 10),
              TextFormField(
                minLines: 2,
                maxLines: 4,
                decoration: const InputDecoration(
                  hintText: 'Décris le contexte ou l\'ambiance de la room...',
                  border: OutlineInputBorder(),
                ),
                validator: (value) => value == null || value.isEmpty ? 'Veuillez entrer une description' : null,
                onSaved: (value) => _description = value ?? '',
              ),
              const SizedBox(height: 24),
              // Nombre de joueurs
              const Text('Nombre de joueurs', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: Slider(
                      value: _nbPlayers.toDouble(),
                      min: 2,
                      max: 10,
                      divisions: 8,
                      label: '$_nbPlayers',
                      onChanged: (v) => setState(() => _nbPlayers = v.round()),
                    ),
                  ),
                  SizedBox(width: 8),
                  Text('$_nbPlayers', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                ],
              ),
              const SizedBox(height: 32),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () {
                    if (_formKey.currentState!.validate() && _iconPath != null) {
                      _formKey.currentState!.save();
                      // Ici tu peux traiter la création de la room avec _roomName, _iconPath, _description, _nbPlayers
                      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Room créée !')));
                      Navigator.pop(context);
                    } else if (_iconPath == null) {
                      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Sélectionne une icône !')));
                    }
                  },
                  child: const Text('Créer'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
