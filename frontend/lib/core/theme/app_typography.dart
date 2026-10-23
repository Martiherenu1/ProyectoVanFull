
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Tipografía compartida de VanFull.
/// Fuente: 08-Brief-de-Diseno-UI.md, sección 5.2.
/// Fuentes propuestas, pendientes de confirmación.
abstract final class AppTypography {
  // Dato dominante: ETA, cupo, horario, saldo.
  static TextStyle get display => GoogleFonts.ibmPlexMono(
    fontSize: 44,
    height: 48 / 44,
    fontWeight: FontWeight.w500,
  );

  // Títulos.
  static TextStyle get h1 => GoogleFonts.archivo(
    fontSize: 28,
    height: 34 / 28,
    fontWeight: FontWeight.w600,
  );

  static TextStyle get h2 => GoogleFonts.archivo(
    fontSize: 20,
    height: 26 / 20,
    fontWeight: FontWeight.w600,
  );

  static TextStyle get h3 => GoogleFonts.archivo(
    fontSize: 16,
    height: 22 / 16,
    fontWeight: FontWeight.w600,
  );

  // Texto normal.
  static TextStyle get body => GoogleFonts.archivo(
    fontSize: 15,
    height: 22 / 15,
    fontWeight: FontWeight.w400,
  );

  static TextStyle get small => GoogleFonts.archivo(
    fontSize: 13,
    height: 18 / 13,
    fontWeight: FontWeight.w400,
  );

  // Etiquetas operativas en mayúsculas.
  static TextStyle get micro => GoogleFonts.archivo(
    fontSize: 11,
    height: 14 / 11,
    fontWeight: FontWeight.w600,
    letterSpacing: 0.88,
  );

  // Números alineados en listas y tablas.
  static TextStyle get data => GoogleFonts.ibmPlexMono(
    fontSize: 15,
    height: 20 / 15,
    fontWeight: FontWeight.w400,
  );
}
