import '../pasajero/reserva.dart';

/// Lectura administrativa del schema Reserva: conserva la identidad del pasajero
/// sin alterar el modelo ni las consultas propias de CU-010.
final class ReservaAdmin {
  const ReservaAdmin({required this.reserva, required this.idPasajero});

  factory ReservaAdmin.fromJson(Map<String, dynamic> json) => ReservaAdmin(
    reserva: Reserva.fromJson(json),
    idPasajero: json['id_pasajero'] as int,
  );

  final Reserva reserva;
  final int idPasajero;
}
