import 'package:flutter/material.dart';

class DePage extends StatelessWidget {
  const DePage({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Dé'),
        backgroundColor: const Color(0xFF161622),
      ),
      backgroundColor: const Color(0xFF161622),
      body: const Center(
        child: Text('Fonctionnalité Dé à venir', style: TextStyle(color: Colors.white)),
      ),
    );
  }
}
