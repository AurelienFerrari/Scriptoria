import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:scriptoria/core/providers/auth_provider.dart';
import 'package:scriptoria/core/utils/friendly_auth_error.dart';

class ForgotPasswordPage extends StatefulWidget {
  const ForgotPasswordPage({super.key});

  @override
  State<ForgotPasswordPage> createState() => _ForgotPasswordPageState();
}

class _ForgotPasswordPageState extends State<ForgotPasswordPage> {
  final _emailController = TextEditingController();
  bool _isLoading = false;
  String? _errorMessage;
  bool _emailSent = false;

  @override
  void dispose() {
    _emailController.dispose();
    super.dispose();
  }

  Future<void> _handleReset() async {
    if (_emailController.text.trim().isEmpty) {
      setState(() => _errorMessage = 'Veuillez entrer votre email');
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      await context.read<AuthProvider>().resetPassword(_emailController.text.trim());
      if (mounted) {
        setState(() => _emailSent = true);
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
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          tooltip: 'Retour',
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Mot de passe oublié',
                style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 28),
              ),
              const SizedBox(height: 8),
              Text(
                'Entrez votre email, vous recevrez un lien pour réinitialiser votre mot de passe.',
                style: TextStyle(color: Colors.white.withOpacity(0.6), fontSize: 14),
              ),
              const SizedBox(height: 32),
              if (_emailSent)
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: primaryColor.withOpacity(0.1),
                    border: Border.all(color: primaryColor.withOpacity(0.5)),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Text(
                    'Email envoyé ! Vérifiez votre boîte de réception.',
                    style: TextStyle(color: primaryColor, fontSize: 13),
                  ),
                )
              else ...[
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
                  controller: _emailController,
                  enabled: !_isLoading,
                  keyboardType: TextInputType.emailAddress,
                  style: const TextStyle(color: Colors.white),
                  decoration: InputDecoration(
                    labelText: 'Email',
                    labelStyle: TextStyle(color: Colors.white.withOpacity(0.6)),
                    prefixIcon: const Icon(Icons.email_outlined, color: primaryColor),
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
                    onPressed: _isLoading ? null : _handleReset,
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
                        : const Text('Envoyer le lien', style: TextStyle(fontWeight: FontWeight.bold)),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
