class EtaReserva {
  const EtaReserva({
    required this.ascenso,
    required this.destino,
    required this.ascensoPasado,
    required this.destinoPasado,
    required this.vigencia,
  });

  final int? ascenso, destino;
  final bool ascensoPasado, destinoPasado;
  final Duration vigencia;

  factory EtaReserva.fromJson(Object? value) {
    if (value is! Map) throw const FormatException('ETA inválido');
    final ascenso = value['ascenso_minutos'];
    final destino = value['destino_minutos'];
    final ascensoPasado = value['ascenso_pasado'];
    final destinoPasado = value['destino_pasado'];
    final segundos = value['vigencia_segundos'];
    if ((ascenso != null && (ascenso is! int || ascenso < 0)) ||
        (destino != null && (destino is! int || destino < 0)) ||
        ascensoPasado is! bool ||
        destinoPasado is! bool ||
        segundos is! int || segundos < 0) {
      throw const FormatException('ETA inválido');
    }
    return EtaReserva(
      ascenso: ascenso as int?,
      destino: destino as int?,
      ascensoPasado: ascensoPasado,
      destinoPasado: destinoPasado,
      vigencia: Duration(seconds: segundos),
    );
  }
}
