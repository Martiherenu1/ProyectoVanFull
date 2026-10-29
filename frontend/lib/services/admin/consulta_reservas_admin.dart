import '../../models/pasajero/reserva.dart';

/// Puerto local de lectura CU-027. No prescribe ruta, filtros ni permisos HTTP.
/// El adaptador real queda pendiente del contrato acordado con Martiniano.
abstract interface class ConsultaReservasAdmin {
  Future<List<Reserva>> listar();
}
