import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:scriptoria/core/providers/auth_provider.dart';
import 'package:scriptoria/core/utils/friendly_auth_error.dart';

/// Écran affiché quand l'utilisateur arrive via le deep link de
/// réinitialisation de mot de passe (voir main.dart : écoute de
/// AuthChangeEvent.passwordRecovery). Le lien a déjà établi une session
/// authentifiée ; il ne reste qu'à définir le nouveau mot de passe.
class ResetPasswordPage extends StatefulWidget {
  const ResetPasswordPage({super.key});

  @override
  State<ResetPasswordPage> createState() => _ResetPasswordPageState();
}

class _ResetPasswordPageState extends State<ResetPasswordPage> {
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  bool _isLoading = false;
  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;
  String? _errorMessage;

  @override
  void dispose() {
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  Future<void> _handleSubmit() async {
    if (_passwordController.text.isEmpty || _confirmPasswordController.text.isEmpty) {
      setState(() => _errorMessage = 'Veuillez remplir tous les champs');
      return;
    }

    if (_passwordController.text != _confirmPasswordController.text) {
      setState(() => _errorMessage = 'Les mots de passe ne correspondent pas');
      return;
    }

    if (_passwordController.text.length < 8) {
      setState(() => _errorMessage = 'Le mot de passe doit contenir au moins 8 caractères');
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      await context.read<AuthProvider>().updatePassword(_passwordController.text);
      if (mounted) {
        Navigator.of(context).pushNamedAndRemoveUntil('/home', (route) => false);
      }
    } catch (e) {
      setState(() => _errorMessage = friendlyAuthErrorMessage(e));
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    const Color primaryColor = Color(0xFF6FE3E1);
    const Color bgColor = Color(0xFF161622);
    const Color cardColor = Color(0xFF232336);

    return Scaffold(
      backgroundColor: bgColor,
      appBar: AppBar(
        backgroundColor: bgColor,
        elevation: 0,
        automaticallyImplyLeading: false,
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Nouveau mot de passe',
                style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 28),
              ),
              const SizedBox(height: 8),
              Text(
                'Choisissez un nouveau mot de passe pour votre compte.',
                style: TextStyle(color: Colors.white.withOpacity(0.6), fontSize: 14),
              ),
              const SizedBox(height: 32),
              if (_errorMessage != null)
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.red.withOpacity(0.1),
                    border: Border.all(color: Colors.red.withOpacity(0.5)),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    _errorMessage!,
                    style: const TextStyle(color: Colors.red, fontSize: 13),
                  ),
                ),
              if (_errorMessage != null) const SizedBox(height: 20),
              TextField(
                controller: _passwordController,
                enabled: !_isLoading,
                obscureText: _obscurePassword,
                style: const TextStyle(color: Colors.white),
                decoration: InputDecoration(
                  labelText: 'Nouveau mot de passe',
                  labelStyle: TextStyle(color: Colors.white.withOpacity(0.6)),
                  prefixIcon: const Icon(Icons.lock_outlined, color: primaryColor),
                  suffixIcon: IconButton(
                    icon: Icon(
                      _obscurePassword ? Icons.visibility_off : Icons.visibility,
                      color: primaryColor,
                    ),
                    tooltip: _obscurePassword ? 'Afficher le mot de passe' : 'Masquer le mot de passe',
                    onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
                  ),
                  filled: true,
                  fillColor: cardColor,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _confirmPasswordController,
                enabled: !_isLoading,
                obscureText: _obscureConfirmPassword,
                style: const TextStyle(color: Colors.white),
                decoration: InputDecoration(
                  labelText: 'Confirmer le mot de passe',
                  labelStyle: TextStyle(color: Colors.white.withOpacity(0.6)),
                  prefixIcon: const Icon(Icons.lock_outlined, color: primaryColor),
                  suffixIcon: IconButton(
                    icon: Icon(
                      _obscureConfirmPassword ? Icons.visibility_off : Icons.visibility,
                      color: primaryColor,
                    ),
                    tooltip: _obscureConfirmPassword ? 'Afficher le mot de passe' : 'Masquer le mot de passe',
                    onPressed: () => setState(() => _obscureConfirmPassword = !_obscureConfirmPassword),
                  ),
                  filled: true,
                  fillColor: cardColor,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _isLoading ? null : _handleSubmit,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: primaryColor,
                    foregroundColor: bgColor,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  child: _isLoading
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text('Valider', style: TextStyle(fontWeight: FontWeight.bold)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
