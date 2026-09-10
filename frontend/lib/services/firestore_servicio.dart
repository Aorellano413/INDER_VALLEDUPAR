// lib/services/firestore_servicio.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/sede_modelo.dart';
import '../models/cancha_modelo.dart';
import '../models/reserva_modelo.dart';
import '../models/bloqueo_modelo.dart';

class FirestoreService {
  static final FirestoreService _instance = FirestoreService._internal();
  factory FirestoreService() => _instance;
  FirestoreService._internal();

  final FirebaseFirestore _db = FirebaseFirestore.instance;

  List<T> _mapQuery<T>(QuerySnapshot<Map<String, dynamic>> snapshot, T Function(Map<String, dynamic>) mapper) {
    return snapshot.docs.map((doc) {
      final data = doc.data();
      data['id'] = doc.id;
      return mapper(data);
    }).toList();
  }

  List<Map<String, dynamic>> _mapQueryRaw(QuerySnapshot<Map<String, dynamic>> snapshot) {
    return snapshot.docs.map((doc) {
      final data = doc.data();
      data['id'] = doc.id;
      return data;
    }).toList();
  }

  Stream<List<SedeModel>> getSedesStream() {
    return _db.collection('sedes').snapshots().map((s) => _mapQuery(s, SedeModel.fromJson));
  }

  Future<List<SedeModel>> getSedes() async {
    final snapshot = await _db.collection('sedes').get();
    return _mapQuery(snapshot, SedeModel.fromJson);
  }

  Future<String> agregarSede(SedeModel sede) async {
    final docRef = await _db.collection('sedes').add(sede.toJson());
    return docRef.id;
  }

  Future<void> actualizarSede(String sedeId, SedeModel sede) async {
    await _db.collection('sedes').doc(sedeId).update(sede.toJson());
  }

  Future<void> eliminarSede(String sedeId) async {
    await _db.collection('sedes').doc(sedeId).delete();
  }

  Stream<List<CanchaModel>> getCanchasPorSedeStream(String sedeId) {
    return _db
        .collection('canchas')
        .where('sedeId', isEqualTo: sedeId)
        .snapshots()
        .map((s) => _mapQuery(s, CanchaModel.fromJson));
  }

  Future<List<CanchaModel>> getCanchasPorSede(String sedeId) async {
    final snapshot = await _db.collection('canchas').where('sedeId', isEqualTo: sedeId).get();
    return _mapQuery(snapshot, CanchaModel.fromJson);
  }

  Future<String> agregarCancha(CanchaModel cancha, String sedeId) async {
    final data = cancha.toJson()..['sedeId'] = sedeId;
    final docRef = await _db.collection('canchas').add(data);
    return docRef.id;
  }

  Future<void> actualizarCancha(String canchaId, CanchaModel cancha) async {
    await _db.collection('canchas').doc(canchaId).update(cancha.toJson());
  }

  Future<void> eliminarCancha(String canchaId) async {
    await _db.collection('canchas').doc(canchaId).delete();
  }

  Future<String> crearReserva(ReservaModel reserva, String canchaId, String sedeId) async {
    final data = reserva.toJson()
      ..['canchaId'] = canchaId
      ..['sedeId'] = sedeId
      ..['estado'] = 'pendiente'
      ..['createdAt'] = FieldValue.serverTimestamp();

    final docRef = await _db.collection('reservas').add(data);
    return docRef.id;
  }

  Stream<List<Map<String, dynamic>>> getReservasStream() {
    return _db
        .collection('reservas')
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map(_mapQueryRaw);
  }

  Stream<List<Map<String, dynamic>>> getReservasPorEstadoStream(String estado) {
    return _db
        .collection('reservas')
        .where('estado', isEqualTo: estado)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map(_mapQueryRaw);
  }

  Future<List<Map<String, dynamic>>> getReservasPorUsuario(String correo) async {
    final snapshot = await _db
        .collection('reservas')
        .where('correoElectronico', isEqualTo: correo)
        .orderBy('createdAt', descending: true)
        .get();

    return _mapQueryRaw(snapshot);
  }

  Future<void> actualizarEstadoReserva(String reservaId, String nuevoEstado) async {
    await _db.collection('reservas').doc(reservaId).update({
      'estado': nuevoEstado,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> eliminarReserva(String reservaId) async {
    await _db.collection('reservas').doc(reservaId).delete();
  }

  Future<bool> verificarDisponibilidad({
    required String canchaId,
    required DateTime fecha,
    required String horaReserva,
  }) async {
    try {
      final bloqueada = await estaBloqueada(
        canchaId: canchaId,
        fecha: fecha,
        horaReserva: horaReserva,
      );
      if (bloqueada) return false;

      final snapshot = await _db
          .collection('reservas')
          .where('canchaId', isEqualTo: canchaId)
          .get();

      final fechaBuscadaStr = "${fecha.year}-${fecha.month}-${fecha.day}";

      for (var doc in snapshot.docs) {
        final data = doc.data();
        final String? horaDoc = data['horaReserva'];
        final String? estadoDoc = data['estado'] ?? 'pendiente';

        if (horaDoc == null) continue;

        String fechaDocStr = "";
        final dynamic rawFecha = data['fechaReserva'];

        if (rawFecha is Timestamp) {
          final dt = rawFecha.toDate();
          fechaDocStr = "${dt.year}-${dt.month}-${dt.day}";
        } else if (rawFecha is DateTime) {
          fechaDocStr = "${rawFecha.year}-${rawFecha.month}-${rawFecha.day}";
        } else if (rawFecha is String) {
          fechaDocStr = rawFecha.split('T')[0];
        }

        if (fechaDocStr == fechaBuscadaStr &&
            horaDoc.trim().toLowerCase() == horaReserva.trim().toLowerCase() &&
            (estadoDoc == 'pendiente' || estadoDoc == 'confirmada' || estadoDoc == 'pagado')) {
          return false;
        }
      }

      return true;
    } catch (e) {
      print('❌ Error al verificar disponibilidad: $e');
      return false;
    }
  }

  Future<Map<String, dynamic>> getEstadisticasDashboard() async {
    final reservasSnapshot = await _db.collection('reservas').get();
    final sedesSnapshot = await _db.collection('sedes').get();
    final canchasSnapshot = await _db.collection('canchas').get();

    int pendientes = 0, pagadas = 0, canceladas = 0;

    for (var doc in reservasSnapshot.docs) {
      final estado = doc.data()['estado'] ?? 'pendiente';
      if (estado == 'pendiente') pendientes++;
      if (estado == 'pagado') pagadas++;
      if (estado == 'cancelado') canceladas++;
    }

    return {
      'totalReservas': reservasSnapshot.docs.length,
      'totalSedes': sedesSnapshot.docs.length,
      'totalCanchas': canchasSnapshot.docs.length,
      'reservasPendientes': pendientes,
      'reservasPagadas': pagadas,
      'reservasCanceladas': canceladas,
    };
  }

  Future<Map<String, dynamic>> getEstadisticasPorSede(String sedeId) async {
    try {
      final reservasSnapshot = await _db.collection('reservas').where('sedeId', isEqualTo: sedeId).get();
      final canchasSnapshot = await _db.collection('canchas').where('sedeId', isEqualTo: sedeId).get();

      int pendientes = 0, pagadas = 0, canceladas = 0;

      for (var doc in reservasSnapshot.docs) {
        final estado = doc.data()['estado'] ?? 'pendiente';
        if (estado == 'pendiente') pendientes++;
        if (estado == 'pagado') pagadas++;
        if (estado == 'cancelado') canceladas++;
      }

      return {
        'totalReservas': reservasSnapshot.docs.length,
        'totalCanchas': canchasSnapshot.docs.length,
        'totalSedes': 1,
        'reservasPendientes': pendientes,
        'reservasPagadas': pagadas,
        'reservasCanceladas': canceladas,
      };
    } catch (e) {
      print('Error en getEstadisticasPorSede: $e');
      rethrow;
    }
  }

  Future<List<Map<String, dynamic>>> getReservasCompletas() async {
    try {
      final reservasSnapshot = await _db
          .collection('reservas')
          .orderBy('createdAt', descending: true)
          .get();

      List<Map<String, dynamic>> reservasCompletas = [];

      for (var doc in reservasSnapshot.docs) {
        final reservaData = doc.data()..['id'] = doc.id;

        if (reservaData['sedeId'] != null) {
          try {
            final sedeDoc = await _db.collection('sedes').doc(reservaData['sedeId']).get();
            reservaData['sede'] = sedeDoc.exists
                ? sedeDoc.data()
                : {'title': 'Sede no encontrada', 'subtitle': ''};
          } catch (_) {
            reservaData['sede'] = {'title': 'Sin acceso', 'subtitle': ''};
          }
        }

        if (reservaData['canchaId'] != null) {
          try {
            final canchaDoc = await _db.collection('canchas').doc(reservaData['canchaId']).get();
            reservaData['cancha'] = canchaDoc.exists
                ? canchaDoc.data()
                : {'title': 'Cancha no encontrada', 'price': '\$0'};
          } catch (_) {
            reservaData['cancha'] = {'title': 'Sin acceso', 'price': '\$0'};
          }
        }

        reservasCompletas.add(reservaData);
      }

      return reservasCompletas;
    } catch (e) {
      print('Error en getReservasCompletas: $e');
      rethrow;
    }
  }

  Future<List<Map<String, dynamic>>> getReservasCompletasPorSede(String sedeId) async {
    try {
      final reservasSnapshot = await _db
          .collection('reservas')
          .where('sedeId', isEqualTo: sedeId)
          .orderBy('createdAt', descending: true)
          .get();

      List<Map<String, dynamic>> reservasCompletas = [];

      for (var doc in reservasSnapshot.docs) {
        final reservaData = doc.data()..['id'] = doc.id;

        if (reservaData['sedeId'] != null) {
          try {
            final sedeDoc = await _db.collection('sedes').doc(reservaData['sedeId']).get();
            if (sedeDoc.exists) reservaData['sede'] = sedeDoc.data();
          } catch (_) {}
        }

        if (reservaData['canchaId'] != null) {
          try {
            final canchaDoc = await _db.collection('canchas').doc(reservaData['canchaId']).get();
            if (canchaDoc.exists) reservaData['cancha'] = canchaDoc.data();
          } catch (_) {}
        }

        reservasCompletas.add(reservaData);
      }

      return reservasCompletas;
    } catch (e) {
      print('Error en getReservasCompletasPorSede: $e');
      rethrow;
    }
  }

  Future<String> crearBloqueo(BloqueoModel bloqueo) async {
    final docRef = await _db.collection('bloqueos').add(bloqueo.toJson());
    return docRef.id;
  }

  Future<List<BloqueoModel>> getBloqueos() async {
    final snapshot = await _db.collection('bloqueos').orderBy('creadoEn', descending: true).get();
    return _mapQuery(snapshot, BloqueoModel.fromJson);
  }

  Stream<List<BloqueoModel>> getBloqueoStream() {
    return _db
        .collection('bloqueos')
        .orderBy('creadoEn', descending: true)
        .snapshots()
        .map((s) => _mapQuery(s, BloqueoModel.fromJson));
  }

  Future<void> actualizarBloqueo(String id, BloqueoModel bloqueo) async {
    await _db.collection('bloqueos').doc(id).update(bloqueo.toJson());
  }

  Future<void> eliminarBloqueo(String id) async {
    await _db.collection('bloqueos').doc(id).delete();
  }

  Future<void> toggleBloqueo(String id, bool activo) async {
    await _db.collection('bloqueos').doc(id).update({'activo': activo});
  }

  Future<bool> estaBloqueada({
    required String canchaId,
    required DateTime fecha,
    required String horaReserva,
  }) async {
    try {
      final snapshot = await _db
          .collection('bloqueos')
          .where('activo', isEqualTo: true)
          .where('canchaIds', arrayContains: canchaId)
          .get();

      final horaReservaLimpia = horaReserva
          .replaceAll('–', '-')
          .replaceAll('—', '-')
          .replaceAll(RegExp(r'\s+'), ' ')
          .trim()
          .toUpperCase();

      for (var doc in snapshot.docs) {
        final data = doc.data()..['id'] = doc.id;
        final bloqueo = BloqueoModel.fromJson(data);

        bool enFecha = false;
        if (bloqueo.tipo == TipoBloqueo.rangoHorario && bloqueo.fechaBloqueo != null) {
          enFecha = bloqueo.fechaBloqueo!.year == fecha.year &&
              bloqueo.fechaBloqueo!.month == fecha.month &&
              bloqueo.fechaBloqueo!.day == fecha.day;
        } else if (bloqueo.tipo == TipoBloqueo.rangoDias && bloqueo.fechaInicio != null && bloqueo.fechaFin != null) {
          final fechaSolo = DateTime(fecha.year, fecha.month, fecha.day);
          final inicio = DateTime(bloqueo.fechaInicio!.year, bloqueo.fechaInicio!.month, bloqueo.fechaInicio!.day);
          final fin = DateTime(bloqueo.fechaFin!.year, bloqueo.fechaFin!.month, bloqueo.fechaFin!.day);
          enFecha = (fechaSolo.isAtSameMomentAs(inicio) || fechaSolo.isAfter(inicio)) &&
              (fechaSolo.isAtSameMomentAs(fin) || fechaSolo.isBefore(fin));
        }

        if (!enFecha) continue;

        if (bloqueo.horasEspecificas.isEmpty) return true;

        for (var franjaBloqueada in bloqueo.horasEspecificas) {
          final franjaLimpia = franjaBloqueada
              .replaceAll('–', '-')
              .replaceAll('—', '-')
              .replaceAll(RegExp(r'\s+'), ' ')
              .trim()
              .toUpperCase();

          if (franjaLimpia == horaReservaLimpia) {
            return true;
          }
        }
      }

      return false;
    } catch (e) {
      print('Error al verificar bloqueo: $e');
      return false;
    }
  }
}