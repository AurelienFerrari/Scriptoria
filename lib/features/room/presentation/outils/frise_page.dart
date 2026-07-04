import 'package:flutter/material.dart';

class FrisePage extends StatelessWidget {
  const FrisePage({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Frise'),
        backgroundColor: const Color(0xFF161622),
      ),
      backgroundColor: const Color(0xFF161622),
      body: const Center(
        child: Text('Fonctionnalité Frise à venir', style: TextStyle(color: Colors.white)),
      ),
    );
  }
}
