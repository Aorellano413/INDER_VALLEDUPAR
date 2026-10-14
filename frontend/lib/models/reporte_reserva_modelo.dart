// lib/models/reporte_reserva_modelo.dart
//
// Una fila del reporte de reservas. Se construye con la respuesta de
// GET /api/reportes/reservas (ver backend/controllers/reportes.controller.js).
//
// El estado reutiliza ReservaEstado / ReservaEstadoHelper (lib/utils/reserva_estado.dart),
// igual que el resto de la app: los únicos estados son pendiente, pagado y cancelado.
import '../utils/reserva_estado.dart';

class ReporteReservaModel {
  final String id;

  /// Día de la reserva en hora local del dispositivo (null si no vino o es inválida).
  final DateTime? fecha;

  /// Turno tal como se guarda, p. ej. "07:00 AM - 08:00 AM".
  final String hora;

  final String cliente;
  final String sede;
  final String cancha;
  final ReservaEstado estado;

  const ReporteReservaModel({
    required this.id,
    required this.fecha,
    required this.hora,
    required this.cliente,
    required this.sede,
    required this.cancha,
    required this.estado,
  });

  factory ReporteReservaModel.fromJson(Map<String, dynamic> json) {
    final fechaRaw = json['fechaReserva']?.toString();
    return ReporteReservaModel(
      id: json['id']?.toString() ?? '',
      // El backend envía ISO 8601 en UTC ("...Z"); se pasa a hora local para
      // mostrar el día correcto.
      fecha: fechaRaw == null ? null : DateTime.tryParse(fechaRaw)?.toLocal(),
      hora: json['horaReserva']?.toString() ?? '',
      cliente: json['nombreCompleto']?.toString() ?? 'Sin nombre',
      sede: json['sedeNombre']?.toString() ?? 'Sin sede',
      cancha: json['canchaNombre']?.toString() ?? 'Sin cancha',
      estado: ReservaEstadoHelper.desdeString(
        json['estado']?.toString() ?? 'pendiente',
      ),
    );
  }

  /// "Confirmada" en el reporte = estado pagado (no existe otro estado de confirmación).
  bool get estaConfirmada => estado == ReservaEstado.pagado;
  bool get estaPendiente => estado == ReservaEstado.pendiente;
  bool get estaCancelada => estado == ReservaEstado.cancelado;
}
