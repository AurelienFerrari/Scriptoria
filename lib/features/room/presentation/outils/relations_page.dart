import 'package:flutter/material.dart';

class RelationsPage extends StatelessWidget {
  const RelationsPage({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Relations'),
        backgroundColor: const Color(0xFF161622),
      ),
      backgroundColor: const Color(0xFF161622),
      body: const Center(
        child: Text('Fonctionnalité Relations à venir', style: TextStyle(color: Colors.white)),
      ),
    );
  }
}
