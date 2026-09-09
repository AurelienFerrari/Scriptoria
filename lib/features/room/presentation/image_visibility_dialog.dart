import 'package:flutter/material.dart';

/// Choix des destinataires d'une image, côté MJ.
///
/// Renvoie la valeur à écrire dans `images.visible_to` : `null` pour tous les
/// membres, liste vide pour personne, sinon les joueurs cochés. Renvoie
/// `ImageVisibilityChoice.cancelled` si le MJ ferme sans valider — un `null`
/// de retour signifierait « tous les joueurs », ce qui serait exactement le
/// contraire de l'intention.
class ImageVisibilityChoice {
  final List<String>? visibleTo;

  const ImageVisibilityChoice(this.visibleTo);

  static const ImageVisibilityChoice? cancelled = null;
}

/// [members] ne contient que les joueurs : le MJ voit toujours ses propres
/// images, l'inscrire dans la liste laisserait croire qu'il peut s'en exclure.
Future<ImageVisibilityChoice?> showImageVisibilityDialog({
  required BuildContext context,
  required List<Map<String, dynamic>> members,
  required List<String>? current,
}) {
  return showDialog<ImageVisibilityChoice>(
    context: context,
    builder: (context) => _ImageVisibilityDialog(members: members, current: current),
  );
}

enum _Mode { everyone, nobody, selection }

class _ImageVisibilityDialog extends StatefulWidget {
  final List<Map<String, dynamic>> members;
  final List<String>? current;

  const _ImageVisibilityDialog({required this.members, required this.current});

  @override
  State<_ImageVisibilityDialog> createState() => _ImageVisibilityDialogState();
}

class _ImageVisibilityDialogState extends State<_ImageVisibilityDialog> {
  late _Mode _mode;
  late Set<String> _selected;

  @override
  void initState() {
    super.initState();
    final current = widget.current;
    if (current == null) {
      _mode = _Mode.everyone;
    } else if (current.isEmpty) {
      _mode = _Mode.nobody;
    } else {
      _mode = _Mode.selection;
    }
    _selected = {...?current};
  }

  String _nameOf(Map<String, dynamic> member) {
    final displayName = member['display_name'] as String?;
    if (displayName != null && displayName.trim().isNotEmpty) return displayName;

    final username = member['username'] as String?;
    if (username != null && username.trim().isNotEmpty) return username;

    return 'Utilisateur sans profil';
  }

  void _submit() {
    switch (_mode) {
      case _Mode.everyone:
        Navigator.pop(context, const ImageVisibilityChoice(null));
      case _Mode.nobody:
        Navigator.pop(context, const ImageVisibilityChoice([]));
      case _Mode.selection:
        Navigator.pop(context, ImageVisibilityChoice(_selected.toList()));
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Qui peut voir cette image ?'),
      content: SizedBox(
        width: double.maxFinite,
        child: ListView(
          shrinkWrap: true,
          children: [
            RadioListTile<_Mode>(
              value: _Mode.everyone,
              groupValue: _mode,
              title: const Text('Tous les joueurs'),
              onChanged: (value) => setState(() => _mode = value!),
            ),
            RadioListTile<_Mode>(
              value: _Mode.nobody,
              groupValue: _mode,
              title: const Text('Personne pour l\'instant'),
              subtitle: const Text('Vous seul la voyez'),
              onChanged: (value) => setState(() => _mode = value!),
            ),
            RadioListTile<_Mode>(
              value: _Mode.selection,
              groupValue: _mode,
              title: const Text('Joueurs choisis'),
              onChanged: (value) => setState(() => _mode = value!),
            ),
            if (_mode == _Mode.selection) ...[
              const Divider(),
              if (widget.members.isEmpty)
                const Padding(
                  padding: EdgeInsets.all(16),
                  child: Text('Aucun joueur n\'a encore rejoint cette room.'),
                )
              else
                ...widget.members.map((member) {
                  final id = member['user_id'] as String;
                  return CheckboxListTile(
                    value: _selected.contains(id),
                    title: Text(_nameOf(member)),
                    onChanged: (checked) => setState(() {
                      if (checked == true) {
                        _selected.add(id);
                      } else {
                        _selected.remove(id);
                      }
                    }),
                  );
                }),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Annuler'),
        ),
        TextButton(
          onPressed: _submit,
          child: const Text('Valider'),
        ),
      ],
    );
  }
}
