import 'package:flutter/material.dart';

/// Colores compartidos de VanFull.
/// Fuente: 08-Brief-de-Diseno-UI.md, sección 5.1.
abstract final class AppColors {
  // Marca
  static const Color gold = Color(0xFFD9A521);
  static const Color goldPressed = Color(0xFFB3891C);
  static const Color goldText = Color(0xFF8C6A15);

  // Neutros
  static const Color ink950 = Color(0xFF0E0E10);
  static const Color ink900 = Color(0xFF17171A);
  static const Color ink800 = Color(0xFF1F1F22);
  static const Color ink700 = Color(0xFF2B2B2E);
  static const Color ink600 = Color(0xFF414143);
  static const Color ink500 = Color(0xFF5F5F61);
  static const Color ink400 = Color(0xFF8A8A8D);
  static const Color ink300 = Color(0xFFB4B4B7);
  static const Color ink200 = Color(0xFFD5D6D8);
  static const Color ink100 = Color(0xFFEAEBED);
  static const Color ink050 = Color(0xFFF5F6F7);
  static const Color paper = Color(0xFFFFFFFF);

  // Estados sobre fondo oscuro
  static const Color okDark = Color(0xFF358C5A);
  static const Color alertDark = Color(0xFFD64F40);
  static const Color waitDark = Color(0xFF5C809E);
  static const Color staleDark = Color(0xFF947A4D);

  // Estados sobre fondo claro
  static const Color okLight = Color(0xFF2F7D50);
  static const Color alertLight = Color(0xFFBF4739);
  static const Color waitLight = Color(0xFF51728C);
  static const Color staleLight = Color(0xFF826B44);
}
