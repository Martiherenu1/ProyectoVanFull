import '../../models/admin/reserva_admin.dart';

/// Puerto de lectura CU-027 para el contrato administrativo de GET /reservas.
abstract interface class ConsultaReservasAdmin {
  Future<List<ReservaAdmin>> listar();
}
