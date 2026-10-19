import 'package:flutter/material.dart';

import 'core/theme/app_theme.dart';
import 'core/theme/app_spacing.dart';

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
      appBar: AppBar(title: const Text('VanFull — Administración')),
      body: ListView(
        padding: const EdgeInsets.all(AppSpacing.xl),
        children: [
          Text('Temas por rol', style: textTheme.headlineLarge),
          const SizedBox(height: AppSpacing.lg),
          _ThemeSample(label: 'Administración', theme: AppTheme.admin),
          const SizedBox(height: AppSpacing.lg),
          _ThemeSample(label: 'Pasajero', theme: AppTheme.passenger),
          const SizedBox(height: AppSpacing.lg),
          _ThemeSample(label: 'Chofer', theme: AppTheme.driver),
        ],
      ),
    );
  }
}

class _ThemeSample extends StatelessWidget {
  const _ThemeSample({required this.label, required this.theme});

  final String label;
  final ThemeData theme;

  @override
  Widget build(BuildContext context) {
    return Theme(
      data: theme,
      child: Builder(
        builder: (context) => ColoredBox(
          color: theme.scaffoldBackgroundColor,
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.lg),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label.toUpperCase(),
                  style: Theme.of(context).textTheme.labelSmall,
                ),
                const SizedBox(height: AppSpacing.sm),
                Text(
                  'Viajes del día',
                  style: Theme.of(context).textTheme.headlineLarge,
                ),
                const SizedBox(height: AppSpacing.lg),
                ElevatedButton(
                  onPressed: () {},
                  child: const Text('Nuevo viaje'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
