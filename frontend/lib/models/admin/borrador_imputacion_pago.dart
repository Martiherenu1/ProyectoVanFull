/// Preparación local: estos datos contractuales aún no tienen persistencia.
/// No determina tipo, porcentajes, acuerdos ni habilita operaciones económicas.
enum TipoPagoBorrador {
  total('total', 'Total'),
  parcial('parcial', 'Parcial'),
  senia('senia', 'Seña');

  const TipoPagoBorrador(this.valorApi, this.etiqueta);
  final String valorApi;
  final String etiqueta;
}

final class BorradorImputacionPago {
  const BorradorImputacionPago({this.tipo, this.evidencia = ''});
  final TipoPagoBorrador? tipo;
  final String evidencia;
  bool get tieneDatos => tipo != null || evidencia.trim().isNotEmpty;
}
