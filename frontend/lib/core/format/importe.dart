/// "$ 11.600,00": punto de miles, coma decimal y dos decimales (brief §9).
/// Se redondea a centavos y se arma con enteros para no arrastrar error de
/// punto flotante al texto.
String importeLegible(double importe) {
  final centavos = (importe.abs() * 100).round();
  final enteros = (centavos ~/ 100).toString();
  final miles = enteros.replaceAllMapped(
    RegExp(r'\B(?=(\d{3})+(?!\d))'),
    (_) => '.',
  );
  final decimales = (centavos % 100).toString().padLeft(2, '0');
  final signo = importe < 0 && centavos != 0 ? '-' : '';
  return '$signo\$ $miles,$decimales';
}

/// Lee un importe escrito a mano: "11600", "11.600", "11.600,50" o "11600.5".
/// Con coma, los puntos son de miles; sin coma, un punto seguido de grupos de
/// tres cifras también. Devuelve `null` si no es un importe con hasta dos
/// decimales.
double? leerImporte(String texto) {
  var limpio = texto.replaceAll(RegExp(r'[\s$]'), '');
  if (limpio.contains(',')) {
    limpio = limpio.replaceAll('.', '').replaceAll(',', '.');
  } else if (RegExp(r'^\d{1,3}(\.\d{3})+$').hasMatch(limpio)) {
    limpio = limpio.replaceAll('.', '');
  }
  if (!RegExp(r'^\d+(\.\d{1,2})?$').hasMatch(limpio)) return null;
  return double.parse(limpio);
}

/// El importe como se escribe en un campo: sin miles y con coma decimal solo
/// si hay centavos ("11600", "11600,50").
String importeEditable(double importe) {
  final centavos = (importe.abs() * 100).round();
  final resto = centavos % 100;
  final enteros = centavos ~/ 100;
  return resto == 0
      ? '$enteros'
      : '$enteros,${resto.toString().padLeft(2, '0')}';
}
