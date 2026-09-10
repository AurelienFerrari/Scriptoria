import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:scriptoria/core/providers/auth_provider.dart';
import 'package:scriptoria/core/utils/friendly_error.dart';

const Color _bgColor = Color(0xFF161622);
const Color _cardColor = Color(0xFF232336);
const Color _primaryColor = Color(0xFF6FE3E1);

/// Paramètres du compte.
///
/// L'écran n'affichait que le texte « Page Paramètres ». Il porte désormais
/// les deux seules actions de compte que l'application sait faire : changer
/// son mot de passe, et se déconnecter. Rien d'autre n'y figure — un réglage
/// qui ne règle rien vaut moins qu'une absence de réglage.
class SettingsPage extends StatefulWidget {
  const SettingsPage({Key? key}) : super(key: key);

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  bool _isBusy = false;

  Future<void> _changePassword() async {
    // La boîte possède ses propres champs de saisie. Les créer ici et les
    // libérer au retour de `showDialog` détruirait les contrôleurs alors que
    // la route de la boîte n'est pas encore démontée, ce qui fait échouer le
    // framework sur `_dependents.isEmpty`.
    final newPassword = await showDialog<String>(
      context: context,
      builder: (ctx) => const _PasswordDialog(),
    );

    if (newPassword == null || !mounted) return;

    setState(() => _isBusy = true);
    try {
      await context.read<AuthProvider>().updatePassword(newPassword);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(friendlyErrorMessage(e))),
        );
        setState(() => _isBusy = false);
      }
      return;
    }

    if (!mounted) return;
    setState(() => _isBusy = false);
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Mot de passe modifié')),
    );
  }

  Future<void> _confirmAndSignOut() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Se déconnecter ?'),
        content: const Text('Vous devrez saisir vos identifiants pour revenir.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Annuler'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Déconnexion', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;

    try {
      await context.read<AuthProvider>().signOut();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(friendlyErrorMessage(e))),
        );
      }
      return;
    }

    if (!mounted) return;
    Navigator.of(context).pushNamedAndRemoveUntil('/login', (route) => false);
  }

  @override
  Widget build(BuildContext context) {
    final email = context.read<AuthProvider>().currentUser?.email;

    return Scaffold(
      backgroundColor: _bgColor,
      appBar: AppBar(
        backgroundColor: _bgColor,
        title: const Text('Paramètres'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          if (email != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 8, left: 4),
              child: Text(
                'Connecté avec $email',
                style: const TextStyle(color: Colors.white54, fontSize: 13),
              ),
            ),
          Card(
            color: _cardColor,
            child: Column(
              children: [
                ListTile(
                  leading: _isBusy
                      ? const SizedBox(
                          width: 24,
                          height: 24,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.lock_outline, color: _primaryColor),
                  title: const Text(
                    'Changer le mot de passe',
                    style: TextStyle(color: Colors.white),
                  ),
                  onTap: _isBusy ? null : _changePassword,
                ),
                const Divider(height: 1, color: Colors.white12),
                ListTile(
                  leading: const Icon(Icons.logout, color: Colors.red),
                  title: const Text(
                    'Se déconnecter',
                    style: TextStyle(color: Colors.red),
                  ),
                  onTap: _confirmAndSignOut,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _PasswordDialog extends StatefulWidget {
  const _PasswordDialog();

  @override
  State<_PasswordDialog> createState() => _PasswordDialogState();
}

class _PasswordDialogState extends State<_PasswordDialog> {
  final TextEditingController _controller = TextEditingController();
  final TextEditingController _confirmController = TextEditingController();

  String? _error;

  @override
  void dispose() {
    _controller.dispose();
    _confirmController.dispose();
    super.dispose();
  }

  void _submit() {
    final password = _controller.text;

    // Même règle qu'à l'inscription : la contrainte doit être la même partout,
    // sans quoi un mot de passe accepté ici serait refusé là.
    if (password.length < 8) {
      setState(() => _error = 'Le mot de passe doit contenir au moins 8 caractères.');
      return;
    }
    if (password != _confirmController.text) {
      setState(() => _error = 'Les mots de passe ne correspondent pas.');
      return;
    }

    Navigator.pop(context, password);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Nouveau mot de passe'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            controller: _controller,
            obscureText: true,
            decoration: const InputDecoration(labelText: 'Nouveau mot de passe'),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _confirmController,
            obscureText: true,
            decoration: const InputDecoration(labelText: 'Confirmer'),
          ),
          if (_error != null) ...[
            const SizedBox(height: 12),
            Text(_error!, style: const TextStyle(color: Colors.red, fontSize: 13)),
          ],
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Annuler'),
        ),
        TextButton(onPressed: _submit, child: const Text('Enregistrer')),
      ],
    );
  }
}
