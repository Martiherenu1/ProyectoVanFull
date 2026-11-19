import '../../core/api/api_client.dart';
import '../../core/api/api_error.dart';
import '../../models/admin/vehiculo_admin.dart';

final class VehiculosAdminApi {
  const VehiculosAdminApi(this._client);

  final ApiClient _client;

  Future<List<VehiculoAdmin>> listar() async {
    final cuerpo = await _client.get('vehiculos');
    if (cuerpo is! List) {
      throw const ApiProtocolException(200, 'Respuesta de vehículos inválida.');
    }
    try {
      return List.unmodifiable(
        cuerpo.map(
          (item) => VehiculoAdmin.fromJson(item as Map<String, dynamic>),
        ),
      );
    } on FormatException {
      throw const ApiProtocolException(200, 'Respuesta de vehículos inválida.');
    } on TypeError {
      throw const ApiProtocolException(200, 'Respuesta de vehículos inválida.');
    }
  }

  Future<VehiculoAdmin> crear(VehiculoCreate solicitud) =>
      _vehiculo(() => _client.post('vehiculos', body: solicitud.toJson()));

  Future<VehiculoAdmin> actualizar(int idVehiculo, VehiculoUpdate solicitud) =>
      _vehiculo(
        () => _client.patch('vehiculos/$idVehiculo', body: solicitud.toJson()),
      );

  Future<VehiculoAdmin> _vehiculo(Future<Object?> Function() solicitud) async {
    final cuerpo = await solicitud();
    if (cuerpo is! Map<String, dynamic>) {
      throw const ApiProtocolException(200, 'Respuesta de vehículo inválida.');
    }
    try {
      return VehiculoAdmin.fromJson(cuerpo);
    } on FormatException {
      throw const ApiProtocolException(200, 'Respuesta de vehículo inválida.');
    } on TypeError {
      throw const ApiProtocolException(200, 'Respuesta de vehículo inválida.');
    }
  }
}
