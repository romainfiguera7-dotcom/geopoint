import 'package:flutter/material.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title:
            const Text('Paramètres'),
      ),
      body: const Center(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: Text(
            'Les paramètres seront '
            'ajoutés prochainement.',
            textAlign:
                TextAlign.center,
            style: TextStyle(
              fontSize: 17,
            ),
          ),
        ),
      ),
    );
  }
}