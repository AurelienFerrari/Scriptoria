import 'package:flutter/material.dart';
import 'package:flutter_markdown_plus/flutter_markdown_plus.dart';
import 'package:provider/provider.dart';

import '../../../../core/providers/auth_provider.dart';
import '../../../../core/providers/room_provider.dart';
import '../../../../core/utils/friendly_error.dart';

const Color _bgColor = Color(0xFF161622);
const Color _cardColor = Color(0xFF232336);
const Color _primaryColor = Color(0xFF6FE3E1);

/// Édition d'une note du MJ, en Markdown.
///
/// Deux modes plutôt qu'un aperçu côte à côte : sur un téléphone, une colonne
/// de saisie et une colonne de rendu seraient toutes deux illisibles.
///
/// [note] vaut `null` pour une création. [initialContent] permet de démarrer
/// sur le contenu d'un fichier importé.
class RoomNoteEditorPage extends StatefulWidget {
  final Map<String, dynamic>? note;
  final String? initialTitle;
  final String? initialContent;

  const RoomNoteEditorPage({
    Key? key,
    this.note,
    this.initialTitle,
    this.initialContent,
  }) : super(key: key);

  @override
  State<RoomNoteEditorPage> createState() => _RoomNoteEditorPageState();
}

class _RoomNoteEditorPageState extends State<RoomNoteEditorPage> {
  late final TextEditingController _titleController;
  late final TextEditingController _contentController;

  bool _preview = false;
  bool _isSaving = false;

  bool get _isNew => widget.note == null;

  @override
  void initState() {
    super.initState();
    _titleController = TextEditingController(
      text: widget.note?['title'] as String? ?? widget.initialTitle ?? '',
    );
    _contentController = TextEditingController(
      text: widget.note?['content_md'] as String? ?? widget.initialContent ?? '',
    );
  }

  @override
  void dispose() {
    _titleController.dispose();
    _contentController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final title = _titleController.text.trim();
    if (title.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Donnez un titre à la note.')),
      );
      return;
    }

    final auth = context.read<AuthProvider>();
    final room = context.read<RoomProvider>();
    final authorId = auth.currentUser?.id;
    if (authorId == null) return;

    setState(() => _isSaving = true);
    try {
      if (_isNew) {
        await auth.createRoomNote(
          campaignId: room.roomId,
          authorId: authorId,
          title: title,
          contentMd: _contentController.text,
        );
      } else {
        await auth.updateRoomNote(
          noteId: widget.note!['id'] as String,
          title: title,
          contentMd: _contentController.text,
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(friendlyErrorMessage(e))),
        );
        setState(() => _isSaving = false);
      }
      return;
    }

    // `true` signale à la liste appelante qu'elle doit se recharger.
    if (mounted) Navigator.pop(context, true);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bgColor,
      appBar: AppBar(
        backgroundColor: _bgColor,
        title: Text(_isNew ? 'Nouvelle note' : 'Modifier la note'),
        actions: [
          IconButton(
            icon: Icon(_preview ? Icons.edit_outlined : Icons.visibility_outlined),
            tooltip: _preview ? 'Revenir à la saisie' : 'Aperçu',
            onPressed: () => setState(() => _preview = !_preview),
          ),
          IconButton(
            icon: _isSaving
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.check),
            tooltip: 'Enregistrer',
            onPressed: _isSaving ? null : _save,
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TextField(
              controller: _titleController,
              style: const TextStyle(color: Colors.white, fontSize: 18),
              decoration: InputDecoration(
                labelText: 'Titre',
                labelStyle: const TextStyle(color: Colors.white54),
                filled: true,
                fillColor: _cardColor,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
            const SizedBox(height: 16),
            Expanded(child: _preview ? _buildPreview() : _buildEditor()),
          ],
        ),
      ),
    );
  }

  Widget _buildEditor() {
    return TextField(
      controller: _contentController,
      maxLines: null,
      expands: true,
      textAlignVertical: TextAlignVertical.top,
      style: const TextStyle(color: Colors.white, height: 1.4),
      decoration: InputDecoration(
        hintText: 'Contenu de la note, en Markdown…',
        hintStyle: const TextStyle(color: Colors.white38),
        alignLabelWithHint: true,
        filled: true,
        fillColor: _cardColor,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
      ),
    );
  }

  Widget _buildPreview() {
    final content = _contentController.text;

    if (content.trim().isEmpty) {
      return const Center(
        child: Text(
          'Rien à afficher pour l\'instant.',
          style: TextStyle(color: Colors.white38),
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _cardColor,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Markdown(
        data: content,
        selectable: true,
        padding: EdgeInsets.zero,
        styleSheet: MarkdownStyleSheet(
          p: const TextStyle(color: Colors.white, height: 1.5),
          h1: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
          h2: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
          h3: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
          listBullet: const TextStyle(color: Colors.white),
          strong: const TextStyle(color: _primaryColor, fontWeight: FontWeight.bold),
          em: const TextStyle(color: Colors.white, fontStyle: FontStyle.italic),
          blockquote: const TextStyle(color: Colors.white70),
          code: const TextStyle(color: _primaryColor, backgroundColor: _bgColor),
          horizontalRuleDecoration: const BoxDecoration(
            border: Border(top: BorderSide(color: Colors.white24)),
          ),
        ),
      ),
    );
  }
}
