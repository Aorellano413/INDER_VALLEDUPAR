class ReporteReservaModel {
  final String id;
  final DateTime? fecha;
  final String hora;
  final String cliente;
  final String correo;
  final String telefono;
  final String sede;
  final String cancha;
  final String estado;

  ReporteReservaModel({
    required this.id,
    required this.fecha,
    required this.hora,
    required this.cliente,
    required this.correo,
    required this.telefono,
    required this.sede,
    required this.cancha,
    required this.estado,
  });

  bool get estaConfirmada =>
      estado.toLowerCase() == 'pagado' ||
      estado.toLowerCase() == 'confirmada' ||
      estado.toLowerCase() == 'confirmado';

  bool get estaPendiente => estado.toLowerCase() == 'pendiente';

  bool get estaCancelada =>
      estado.toLowerCase() == 'cancelado' ||
      estado.toLowerCase() == 'cancelada';

  String get estadoVisual {
    if (estaConfirmada) return 'Confirmada';
    if (estaPendiente) return 'Pendiente';
    if (estaCancelada) return 'Cancelada';

    return estado;
  }
}