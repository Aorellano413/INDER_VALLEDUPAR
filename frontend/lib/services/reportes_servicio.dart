// lib/services/reportes_servicio.dart
//
// Obtiene el reporte de reservas. No consulta Firebase: la comunicación HTTP
// (URL base y encabezados de sesión) está centralizada en FirestoreService, que
// llama al endpoint GET /api/reportes/reservas del backend.
import '../models/reporte_reserva_modelo.dart';
import '../utils/reporte_periodo.dart';
import 'firestore_servicio.dart';

class ReportesServicio {
  final FirestoreService _api = FirestoreService();

  /// Reservas del [periodo], opcionalmente de una sola sede.
  /// El backend ya devuelve la lista ordenada (más recientes primero).
  Future<List<ReporteReservaModel>> obtenerReporte({
    required PeriodoReporte periodo,
    String? sedeId,
  }) async {
    final datos = await _api.getReporteReservas(
      desde: periodo.inicio,
      hasta: periodo.finExclusivo,
      sedeId: sedeId,
    );
    return datos.map(ReporteReservaModel.fromJson).toList();
  }
}
