import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:permission_handler/permission_handler.dart';
import 'package:provider/provider.dart';
import 'dart:math';
import 'dart:typed_data';
import 'dart:io';

import 'package:scriptoria/core/providers/auth_provider.dart';
import 'package:scriptoria/core/utils/friendly_auth_error.dart';
import 'package:scriptoria/features/room/presentation/shell/room_shell.dart';

/// Code d'invitation lisible (sans 0/O/1/I, souvent confondus).
String generateJoinCode() {
  const chars = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';
  final rand = Random();
  return List.generate(6, (_) => chars[rand.nextInt(chars.length)]).join();
}

class RoomCreatePage extends StatefulWidget {
  const RoomCreatePage({Key? key}) : super(key: key);

  @override
  State<RoomCreatePage> createState() => _RoomCreatePageState();
}

class _RoomCreatePageState extends State<RoomCreatePage> {
  final _formKey = GlobalKey<FormState>();
  final _roomNameController = TextEditingController();
  final _descriptionController = TextEditingController();
  int _nbPlayers = 4;
  String? _iconPath; // Chemin local de l'icône
  bool _iconIsAsset = true;
  bool _isSubmitting = false;

  XFile? _pickedFile;

  @override
  void dispose() {
    _roomNameController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  Future<void> _createRoom() async {
    if (!_formKey.currentState!.validate()) return;
    if (_iconPath == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Sélectionne une icône !')));
      return;
    }

    setState(() => _isSubmitting = true);
    try {
      final currentUser = context.read<AuthProvider>().currentUser;
      final campaign = await context.read<AuthProvider>().createCampaign(
            creatorId: currentUser!.id,
            title: _roomNameController.text.trim(),
            description: _descriptionController.text.trim(),
            iconUrl: _iconIsAsset ? _iconPath : null,
            maxPlayers: _nbPlayers,
            joinCode: generateJoinCode(),
          );

      if (!mounted) return;
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => RoomShell(roomId: campaign['id'] as String)),
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(friendlyAuthErrorMessage(e))),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isSubmitting = false);
      }
    }
  }

  Future<void> _pickIcon() async {
    final Map<String, String> demoIcons = {
      'assets/images/dragon.png': 'Icône Dragon',
      'assets/images/mystery.png': 'Icône Mystère',
    };
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
              ...demoIcons.entries.map((entry) => Semantics(
                button: true,
                label: entry.value,
                child: GestureDetector(
                  onTap: () {
                    setState(() {
                      _iconPath = entry.key;
                      _iconIsAsset = true;
                      _pickedFile = null;
                    });
                    Navigator.pop(context);
                  },
                  child: Image.asset(entry.key, width: 64, height: 64, excludeFromSemantics: true),
                ),
              )),
              Semantics(
                button: true,
                label: 'Importer une image depuis la galerie',
                child: GestureDetector(
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
                  Navigator.pop(context); // Ferme le dialog AVANT d'ouvrir la galerie
                  await Future.delayed(const Duration(milliseconds: 200));
                  FocusScope.of(context).unfocus();
                  await Future.delayed(const Duration(milliseconds: 100));
                  final ImagePicker picker = ImagePicker();
                  final XFile? file = await picker.pickImage(source: ImageSource.gallery);
                  if (file != null) {
                    if (mounted) {
                      setState(() {
                        _pickedFile = file;
                        _iconPath = file.path;
                        _iconIsAsset = false;
                      });
                    }
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
                controller: _roomNameController,
                decoration: const InputDecoration(
                  hintText: 'Ex: Mystères de l\'Ombre',
                  border: OutlineInputBorder(),
                ),
                validator: (value) => value == null || value.isEmpty ? 'Veuillez entrer un nom' : null,
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
                        : const Center(child: Icon(Icons.add_a_photo, size: 36, color: Colors.white54)),
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
                controller: _descriptionController,
                minLines: 2,
                maxLines: 4,
                decoration: const InputDecoration(
                  hintText: 'Décris le contexte ou l\'ambiance de la room...',
                  border: OutlineInputBorder(),
                ),
                validator: (value) => value == null || value.isEmpty ? 'Veuillez entrer une description' : null,
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
                      label: _nbPlayers == 10 ? 'illimité' : '$_nbPlayers',
                      onChanged: (v) => setState(() => _nbPlayers = v.round()),
                    ),
                  ),
                  SizedBox(width: 8),
                  Text(_nbPlayers == 10 ? 'illimité' : '$_nbPlayers', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                ],
              ),
              const SizedBox(height: 32),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _isSubmitting ? null : _createRoom,
                  child: _isSubmitting
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text('Créer'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
