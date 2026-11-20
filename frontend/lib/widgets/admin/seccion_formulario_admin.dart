import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_typography.dart';

class SeccionFormularioAdmin extends StatelessWidget {
  const SeccionFormularioAdmin({
    required this.titulo,
    required this.campos,
    super.key,
  });

  final String titulo;
  final List<Widget> campos;

  @override
  Widget build(BuildContext context) => DecoratedBox(
    decoration: BoxDecoration(
      color: AppColors.paper,
      border: Border.all(color: AppColors.ink200),
      borderRadius: BorderRadius.circular(AppSpacing.borderRadius),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ColoredBox(
          color: AppColors.ink100,
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.md,
              vertical: AppSpacing.sm,
            ),
            child: Text(titulo, style: AppTypography.h3),
          ),
        ),
        Padding(
          padding: const EdgeInsets.all(AppSpacing.md),
          child: LayoutBuilder(
            builder: (context, constraints) {
              final columnas = constraints.maxWidth >= 640 ? campos.length : 1;
              final ancho =
                  (constraints.maxWidth - AppSpacing.md * (columnas - 1)) /
                  columnas;
              return Wrap(
                spacing: AppSpacing.md,
                runSpacing: AppSpacing.md,
                children: [
                  for (final campo in campos)
                    SizedBox(width: ancho, child: campo),
                ],
              );
            },
          ),
        ),
      ],
    ),
  );
}
