import 'dart:convert';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../../core/providers/auth_provider.dart';
import '../../../../core/providers/room_provider.dart';
import '../../../../core/utils/format_last_update.dart';
import '../../../../core/utils/friendly_error.dart';
import '../room_route.dart';
import 'room_note_editor_page.dart';

/// Notes du MJ, listées dans l'onglet Contenus.
///
/// Ce widget n'est monté que pour le MJ. La base ne renverrait de toute façon
/// rien à un joueur : la policy `room_notes_select_mj` réserve la lecture au
/// meneur.
class RoomNotesSection extends StatefulWidget {
  const RoomNotesSection({Key? key}) : super(key: key);

  @override
  State<RoomNotesSection> createState() => _RoomNotesSectionState();
}

class _RoomNotesSectionState extends State<RoomNotesSection> {
  late Future<List<Map<String, dynamic>>> _notesFuture;

  @override
  void initState() {
    super.initState();
    _notesFuture = _loadNotes();
  }

  Future<List<Map<String, dynamic>>> _loadNotes() {
    final room = context.read<RoomProvider>();
    return context.read<AuthProvider>().getRoomNotes(room.roomId);
  }

  void _reload() {
    // Corps en bloc : `setState(() => x = future)` renverrait le Future, que
    // setState refuse.
    setState(() {
      _notesFuture = _loadNotes();
    });
  }

  Future<void> _openEditor({Map<String, dynamic>? note, String? title, String? content}) async {
    final saved = await pushRoomRoute<bool>(
      context,
      RoomNoteEditorPage(
        note: note,
        initialTitle: title,
        initialContent: content,
      ),
    );
    if (saved == true && mounted) _reload();
  }

  /// Importe un fichier Markdown et ouvre l'éditeur pré-rempli.
  ///
  /// Le contenu est lu et repris dans une note ordinaire plutôt que déposé
  /// dans Storage : une note importée et une note écrite ici deviennent alors
  /// le même objet, éditable de la même façon.
  Future<void> _importMarkdown() async {
    // `withData` : sur le web il n'y a pas de chemin de fichier, seuls les
    // octets remontent. Le demander explicitement rend l'import identique sur
    // toutes les plateformes.
    final result = await FilePicker.pickFiles(
      type: FileType.custom,
      allowedExtensions: const ['md', 'markdown'],
      withData: true,
    );

    final file = result?.files.singleOrNull;
    if (file == null || !mounted) return;

    final bytes = file.bytes;
    if (bytes == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Fichier illisible.')),
      );
      return;
    }

    String content;
    try {
      // `allowMalformed` : un fichier écrit dans un autre encodage doit
      // arriver abîmé mais lisible, plutôt que de faire échouer l'import.
      content = utf8.decode(bytes, allowMalformed: true);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(friendlyErrorMessage(e))),
        );
      }
      return;
    }

    // Le nom du fichier fait un titre par défaut acceptable ; le MJ le change
    // dans l'éditeur si besoin.
    final title = file.name.replaceAll(RegExp(r'\.(md|markdown)$'), '');

    await _openEditor(title: title, content: content);
  }

  Future<void> _confirmAndDelete(Map<String, dynamic> note) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Supprimer « ${note['title']} » ?'),
        content: const Text('Cette action est irréversible.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Annuler'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Supprimer', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;

    try {
      await context.read<AuthProvider>().deleteRoomNote(note['id'] as String);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(friendlyErrorMessage(e))),
        );
      }
      return;
    }

    if (mounted) _reload();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Notes',
          style: TextStyle(
            color: Colors.white,
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 4),
        const Text(
          'Visibles de vous seul. Les joueurs n\'y ont aucun accès.',
          style: TextStyle(color: Colors.white54, fontSize: 13),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                icon: const Icon(Icons.note_add_outlined, size: 20),
                label: const Text('Nouvelle note'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: const Color(0xFF6FE3E1),
                  side: const BorderSide(color: Color(0xFF6FE3E1)),
                ),
                onPressed: () => _openEditor(),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: OutlinedButton.icon(
                icon: const Icon(Icons.upload_file_outlined, size: 20),
                label: const Text('Importer un .md'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.white70,
                  side: const BorderSide(color: Colors.white24),
                ),
                onPressed: _importMarkdown,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        FutureBuilder<List<Map<String, dynamic>>>(
          future: _notesFuture,
          builder: (context, snapshot) {
            if (snapshot.connectionState != ConnectionState.done) {
              return const Padding(
                padding: EdgeInsets.symmetric(vertical: 24),
                child: Center(child: CircularProgressIndicator()),
              );
            }

            final notes = snapshot.data ?? const [];
            if (notes.isEmpty) {
              return const Padding(
                padding: EdgeInsets.symmetric(vertical: 24),
                child: Text(
                  'Aucune note pour l\'instant.',
                  style: TextStyle(color: Colors.white38),
                ),
              );
            }

            return Column(children: notes.map(_buildNoteTile).toList());
          },
        ),
      ],
    );
  }

  Widget _buildNoteTile(Map<String, dynamic> note) {
    return Card(
      color: const Color(0xFF232336),
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: const Icon(Icons.description_outlined, color: Colors.white70),
        title: Text(
          note['title'] as String? ?? 'Sans titre',
          style: const TextStyle(color: Colors.white),
        ),
        subtitle: Text(
          'Modifiée le ${formatLastUpdate(note['updated_at'] as String?)}',
          style: const TextStyle(color: Colors.white54, fontSize: 12),
        ),
        onTap: () => _openEditor(note: note),
        trailing: IconButton(
          icon: const Icon(Icons.delete_outline, color: Colors.red),
          tooltip: 'Supprimer « ${note['title']} »',
          onPressed: () => _confirmAndDelete(note),
        ),
      ),
    );
  }
}
