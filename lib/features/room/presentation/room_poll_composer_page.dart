import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../../core/providers/auth_provider.dart';
import '../../../core/providers/room_provider.dart';
import '../../../core/utils/friendly_error.dart';

const Color _bgColor = Color(0xFF161622);
const Color _cardColor = Color(0xFF232336);
const Color _primaryColor = Color(0xFF6FE3E1);

// Bornes alignées sur la fonction `create_room_poll` de la base.
const int _minOptions = 2;
const int _maxOptions = 10;
const int _questionMaxLength = 300;
const int _optionMaxLength = 100;

/// Lancement d'un sondage dans le chat, ouvert au MJ comme aux joueurs.
///
/// Les règles sont vérifiées ici pour répondre tout de suite, mais c'est la
/// fonction `create_room_poll` qui fait foi : elle les applique à nouveau, et
/// crée le message, le sondage et ses réponses d'un seul tenant.
///
/// Renvoie, en se refermant, le message du sondage créé.
class RoomPollComposerPage extends StatefulWidget {
  const RoomPollComposerPage({super.key});

  @override
  State<RoomPollComposerPage> createState() => _RoomPollComposerPageState();
}

class _RoomPollComposerPageState extends State<RoomPollComposerPage> {
  final TextEditingController _questionController = TextEditingController();
  final List<TextEditingController> _optionControllers = [
    TextEditingController(),
    TextEditingController(),
  ];
  bool _multiple = false;
  bool _isSaving = false;

  @override
  void dispose() {
    _questionController.dispose();
    for (final controller in _optionControllers) {
      controller.dispose();
    }
    super.dispose();
  }

  void _addOption() {
    if (_optionControllers.length >= _maxOptions) return;
    setState(() => _optionControllers.add(TextEditingController()));
  }

  void _removeOption(int index) {
    if (_optionControllers.length <= _minOptions) return;
    late final TextEditingController removed;
    setState(() => removed = _optionControllers.removeAt(index));
    // Libéré après le rebuild : le champ qui l'utilisait est encore dans
    // l'arbre pendant cette frame.
    WidgetsBinding.instance.addPostFrameCallback((_) => removed.dispose());
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  Future<void> _submit() async {
    final question = _questionController.text.trim();
    if (question.isEmpty) {
      _showError('Posez une question.');
      return;
    }

    // Une réponse laissée vide est ignorée, plutôt que de bloquer le
    // lancement pour un champ en trop.
    final options = [
      for (final controller in _optionControllers)
        if (controller.text.trim().isNotEmpty) controller.text.trim(),
    ];
    if (options.length < _minOptions) {
      _showError('Proposez au moins deux réponses.');
      return;
    }
    if (options.map((option) => option.toLowerCase()).toSet().length !=
        options.length) {
      _showError('Deux réponses sont identiques.');
      return;
    }

    final auth = context.read<AuthProvider>();
    final room = context.read<RoomProvider>();

    setState(() => _isSaving = true);
    try {
      final message = await auth.createRoomPoll(
        campaignId: room.roomId,
        question: question,
        options: options,
        multiple: _multiple,
      );
      if (mounted) Navigator.pop(context, message);
    } catch (e) {
      // La saisie reste en place : un échec ne doit rien faire perdre.
      if (!mounted) return;
      _showError(friendlyErrorMessage(e));
      setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bgColor,
      appBar: AppBar(
        backgroundColor: _bgColor,
        title: const Text('Nouveau sondage'),
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  _field(
                    controller: _questionController,
                    label: 'Question',
                    hint: 'Ex. : où allons-nous ce soir ?',
                    maxLength: _questionMaxLength,
                    maxLines: 3,
                  ),
                  const SizedBox(height: 20),
                  const Text(
                    'Réponses',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 8),
                  for (var i = 0; i < _optionControllers.length; i++)
                    Padding(
                      key: ObjectKey(_optionControllers[i]),
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Row(
                        children: [
                          Expanded(
                            child: _field(
                              controller: _optionControllers[i],
                              label: 'Réponse ${i + 1}',
                              maxLength: _optionMaxLength,
                            ),
                          ),
                          if (_optionControllers.length > _minOptions)
                            IconButton(
                              icon: const Icon(
                                Icons.close,
                                color: Colors.white54,
                              ),
                              tooltip: 'Retirer la réponse ${i + 1}',
                              onPressed: () => _removeOption(i),
                            ),
                        ],
                      ),
                    ),
                  if (_optionControllers.length < _maxOptions)
                    Align(
                      alignment: Alignment.centerLeft,
                      child: TextButton.icon(
                        icon: const Icon(Icons.add),
                        label: const Text('Ajouter une réponse'),
                        style: TextButton.styleFrom(
                          foregroundColor: _primaryColor,
                        ),
                        onPressed: _addOption,
                      ),
                    ),
                  const SizedBox(height: 8),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    value: _multiple,
                    activeColor: _primaryColor,
                    title: const Text(
                      'Plusieurs réponses possibles',
                      style: TextStyle(color: Colors.white),
                    ),
                    subtitle: const Text(
                      'Chacun pourra en cocher plusieurs.',
                      style: TextStyle(color: Colors.white54),
                    ),
                    onChanged: (value) => setState(() => _multiple = value),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Les votes sont anonymes. Chacun découvre les résultats '
                    'après avoir voté, ou quand le sondage est clos.',
                    style: TextStyle(color: Colors.white38, fontSize: 12),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
              child: ElevatedButton.icon(
                icon: _isSaving
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.poll_outlined),
                label: const Text('Lancer le sondage'),
                style: ElevatedButton.styleFrom(
                  minimumSize: const Size(double.infinity, 52),
                  backgroundColor: _primaryColor,
                  foregroundColor: _bgColor,
                  textStyle: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                onPressed: _isSaving ? null : _submit,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _field({
    required TextEditingController controller,
    required String label,
    String? hint,
    required int maxLength,
    int maxLines = 1,
  }) {
    return TextField(
      controller: controller,
      minLines: 1,
      maxLines: maxLines,
      inputFormatters: [LengthLimitingTextInputFormatter(maxLength)],
      style: const TextStyle(color: Colors.white),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: const TextStyle(color: Colors.white54),
        hintText: hint,
        hintStyle: const TextStyle(color: Colors.white38),
        filled: true,
        fillColor: _cardColor,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
      ),
    );
  }
}
