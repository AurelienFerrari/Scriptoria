import 'package:flutter/material.dart';

/// Destinataires choisis par le MJ, pour une image comme pour une publication.
///
/// Porte la valeur à écrire dans une colonne `visible_to` : `null` pour tous
/// les membres, liste vide pour personne, sinon les joueurs cochés.
///
/// La boîte renvoie `null` quand le MJ ferme sans valider. C'est pour cela que
/// le choix est enveloppé dans un objet : un `null` de retour signifierait
/// « tous les joueurs », soit exactement le contraire de l'intention.
class AudienceChoice {
  final List<String>? visibleTo;

  const AudienceChoice(this.visibleTo);
}

/// [members] ne contient que les joueurs : le MJ reçoit toujours ce qu'il
/// publie, l'inscrire dans la liste laisserait croire qu'il peut s'en exclure.
///
/// [allowNobody] ouvre le choix « personne pour l'instant ». Il a du sens pour
/// une image préparée à l'avance, pas pour une annonce — on ne publie pas à
/// destination de personne.
Future<AudienceChoice?> showAudienceDialog({
  required BuildContext context,
  required List<Map<String, dynamic>> members,
  required List<String>? current,
  String title = 'Qui peut voir cette image ?',
  bool allowNobody = true,
}) {
  return showDialog<AudienceChoice>(
    context: context,
    builder: (context) => _AudienceDialog(
      members: members,
      current: current,
      title: title,
      allowNobody: allowNobody,
    ),
  );
}

enum _Mode { everyone, nobody, selection }

class _AudienceDialog extends StatefulWidget {
  final List<Map<String, dynamic>> members;
  final List<String>? current;
  final String title;
  final bool allowNobody;

  const _AudienceDialog({
    required this.members,
    required this.current,
    required this.title,
    required this.allowNobody,
  });

  @override
  State<_AudienceDialog> createState() => _AudienceDialogState();
}

class _AudienceDialogState extends State<_AudienceDialog> {
  late _Mode _mode;
  late Set<String> _selected;

  @override
  void initState() {
    super.initState();
    final current = widget.current;
    if (current == null) {
      _mode = _Mode.everyone;
    } else if (current.isEmpty) {
      // Une valeur « personne » déjà en base reste affichable même quand
      // l'option n'est pas proposée : mieux vaut montrer l'état réel que de
      // le réécrire silencieusement à l'ouverture de la boîte.
      _mode = widget.allowNobody ? _Mode.nobody : _Mode.selection;
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
        Navigator.pop(context, const AudienceChoice(null));
      case _Mode.nobody:
        Navigator.pop(context, const AudienceChoice([]));
      case _Mode.selection:
        Navigator.pop(context, AudienceChoice(_selected.toList()));
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.title),
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
            if (widget.allowNobody)
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
