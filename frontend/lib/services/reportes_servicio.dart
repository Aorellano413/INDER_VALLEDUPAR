import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/cancha_modelo.dart';
import '../models/reporte_reserva_modelo.dart';
import '../models/sede_modelo.dart';

class ReportesServicio {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  Future<List<ReporteReservaModel>> obtenerReporte({
    required DateTime fechaInicio,
    required DateTime fechaFin,
    String? sedeId,
  }) async {
    Query<Map<String, dynamic>> query = _db
        .collection('reservas')
        .where(
          'fechaReserva',
          isGreaterThanOrEqualTo: Timestamp.fromDate(fechaInicio),
        )
        .where(
          'fechaReserva',
          isLessThan: Timestamp.fromDate(fechaFin),
        );

    final snapshot = await query.get();

    final sedesSnapshot = await _db.collection('sedes').get();
    final canchasSnapshot = await _db.collection('canchas').get();

    final sedes = <String, SedeModel>{};
    final canchas = <String, CanchaModel>{};

    for (final doc in sedesSnapshot.docs) {
      final data = doc.data();
      data['id'] = doc.id;

      final sede = SedeModel.fromJson(data);

      if (sede.id != null) {
        sedes[sede.id!] = sede;
      }
    }

    for (final doc in canchasSnapshot.docs) {
      final data = doc.data();
      data['id'] = doc.id;

      final cancha = CanchaModel.fromJson(data);

      if (cancha.id != null) {
        canchas[cancha.id!] = cancha;
      }
    }

    final resultado = <ReporteReservaModel>[];

    for (final doc in snapshot.docs) {
      final data = doc.data();

      final reservaSedeId = data['sedeId']?.toString();

      if (sedeId != null && reservaSedeId != sedeId) {
        continue;
      }

      DateTime? fecha;

      final fechaRaw = data['fechaReserva'];

      if (fechaRaw is Timestamp) {
        fecha = fechaRaw.toDate();
      } else if (fechaRaw is String) {
        fecha = DateTime.tryParse(fechaRaw);
      }

      final canchaId = data['canchaId']?.toString();

      final sede = reservaSedeId != null
          ? sedes[reservaSedeId]
          : null;

      final cancha = canchaId != null
          ? canchas[canchaId]
          : null;

      resultado.add(
        ReporteReservaModel(
          id: doc.id,
          fecha: fecha,
          hora: data['horaReserva']?.toString() ?? '--',
          cliente: data['nombreCompleto']?.toString() ?? 'Sin nombre',
          correo: data['correoElectronico']?.toString() ?? '',
          telefono: data['numeroCelular']?.toString() ?? '',
          sede: sede?.title ?? 'Sede no encontrada',
          cancha: cancha?.title ?? 'Cancha no encontrada',
          estado: data['estado']?.toString() ?? 'pendiente',
        ),
      );
    }

    resultado.sort((a, b) {
      final fechaA = a.fecha ?? DateTime(1900);
      final fechaB = b.fecha ?? DateTime(1900);

      return fechaB.compareTo(fechaA);
    });

    return resultado;
  }
}