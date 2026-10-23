/// Espaciados y dimensiones compartidas de VanFull.
/// Fuente: 08-Brief-de-Diseno-UI.md, sección 5.3.
abstract final class AppSpacing {
  // Escala de espaciado: múltiplos de 4 px.
  static const double xs = 4;
  static const double sm = 8;
  static const double md = 12;
  static const double lg = 16;
  static const double xl = 24;
  static const double xxl = 32;
  static const double xxxl = 48;

  // Bordes y formas.
  static const double borderRadius = 2;
  static const double borderWidth = 1;

  // Altura de filas por tipo de usuario.
  static const double passengerRowHeight = 48;
  static const double driverRowHeight = 64;
  static const double adminRowHeight = 36;

  // Tamaños mínimos de interacción táctil.
  static const double touchTarget = 48;
  static const double driverTouchTarget = 64;
}
