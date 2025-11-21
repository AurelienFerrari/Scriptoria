import 'package:flutter/material.dart';
import 'dart:io';
import 'gallery_grid.dart';

import 'package:image_picker/image_picker.dart';

class RoomHomePage extends StatefulWidget {
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
  State<RoomHomePage> createState() => _RoomHomePageState();
}

class _RoomHomePageState extends State<RoomHomePage> {
  final List<GalleryImage> _galleryImages = [];
  final ImagePicker _picker = ImagePicker();

  Future<void> _addImage() async {
    final XFile? file = await _picker.pickImage(source: ImageSource.gallery);
    if (file != null) {
      setState(() {
        _galleryImages.add(GalleryImage.file(file.path));
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () {
            Navigator.of(context).pop(); // Retour à la home page
          },
        ),
        title: Text(widget.roomName),
        backgroundColor: const Color(0xFF161622),
      ),
      backgroundColor: const Color(0xFF161622),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(32),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            if (widget.iconPath != null)
              Container(
                width: 96,
                height: 96,
                margin: const EdgeInsets.only(top: 32, bottom: 24), // baisse l'icône
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(24),
                  color: Colors.grey.shade900,
                ),
                child: widget.iconIsAsset
                    ? Image.asset(widget.iconPath!, fit: BoxFit.cover)
                    : Image.file(
                        File(widget.iconPath!),
                        fit: BoxFit.cover,
                      ),
              ),
            Text(
              widget.roomName,
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 28,
                color: Colors.white,
              ),
              textAlign: TextAlign.center,
            ),
            SizedBox(height: 12),
            Text(
              widget.description,
              style: TextStyle(fontSize: 16, color: Colors.white),
              textAlign: TextAlign.center,
            ),
            SizedBox(height: 32),
            // Galerie d'images (GridView)
            SizedBox(height: 24),
            GalleryGrid(
              images: _galleryImages,
              onAddImage: _addImage,
              onDeleteImage: (index) {
                setState(() {
                  _galleryImages.removeAt(index);
                });
              },
            ),
            SizedBox(height: 24),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.update, color: Colors.white, size: 20),
                SizedBox(width: 8),
                Text(
                  widget.lastUpdateText,
                  style: TextStyle(color: Colors.white, fontSize: 15),
                ),
                SizedBox(width: 8),
                Text(
                  widget.lastUpdate,
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

