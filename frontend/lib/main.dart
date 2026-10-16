
import 'package:flutter/material.dart';

import 'core/theme/app_theme.dart';

void main() {
  runApp(const VanFullApp());
}

class VanFullApp extends StatelessWidget {
  const VanFullApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'VanFull',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.admin,
      home: const ThemePreview(),
    );
  }
}

/// Vista temporal para comprobar el diseño visual.
/// No representa todavía el CU-018.
class ThemePreview extends StatelessWidget {
  const ThemePreview({super.key});

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('VanFull — Administración'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Viajes del día',
              style: textTheme.headlineLarge,
            ),
            const SizedBox(height: 16),
            Text(
              'Administración',
              style: textTheme.bodyMedium,
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: null,
              child: const Text('Nuevo viaje'),
            ),
          ],
        ),
      ),
    );
  }
}
