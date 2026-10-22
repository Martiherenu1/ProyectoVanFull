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
