import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/sede_modelo.dart';
import '../models/cancha_modelo.dart';
import '../models/reserva_modelo.dart';
import '../models/bloqueo_modelo.dart';
import 'sesion.dart';

class FirestoreService {
  static final FirestoreService _instance = FirestoreService._internal();
  factory FirestoreService() => _instance;
  FirestoreService._internal();

  static const String baseUrl = 'http://localhost:3000/api';
  static const Duration _intervaloStream = Duration(seconds: 5);

  Map<String, String> get _headers {
    final u = Sesion.usuario;
    return {
      'Content-Type': 'application/json',
      if (u != null) 'x-usuario-id': Uri.encodeComponent('${u['id'] ?? ''}'),
      if (u != null)
        'x-usuario-correo': Uri.encodeComponent('${u['correo'] ?? ''}'),
      if (u != null)
        'x-usuario-nombre': Uri.encodeComponent('${u['nombre'] ?? ''}'),
      if (u != null) 'x-usuario-rol': Uri.encodeComponent('${u['rol'] ?? ''}'),
    };
  }

  dynamic _procesar(http.Response r) {
    if (r.statusCode >= 200 && r.statusCode < 300) {
      return r.body.isEmpty ? null : jsonDecode(utf8.decode(r.bodyBytes));
    }
    throw Exception('Error ${r.statusCode}: ${r.body}');
  }

  String _json(Object? o) => jsonEncode(
        o,
        toEncodable: (x) {
          if (x is DateTime) return x.toIso8601String();
          try {
            final fecha = (x as dynamic).toDate();
            if (fecha is DateTime) return fecha.toIso8601String();
          } catch (_) {}
          return x.toString();
        },
      );

  Future<dynamic> _get(String ruta) async =>
      _procesar(await http.get(Uri.parse('$baseUrl$ruta'), headers: _headers));

  Future<dynamic> _post(String ruta, Object? body) async => _procesar(await http
      .post(Uri.parse('$baseUrl$ruta'), headers: _headers, body: _json(body)));

  Future<dynamic> _put(String ruta, Object? body) async => _procesar(await http
      .put(Uri.parse('$baseUrl$ruta'), headers: _headers, body: _json(body)));

  Future<dynamic> _patch(String ruta, Object? body) async =>
      _procesar(await http.patch(Uri.parse('$baseUrl$ruta'),
          headers: _headers, body: _json(body)));

  Future<dynamic> _delete(String ruta) async => _procesar(
      await http.delete(Uri.parse('$baseUrl$ruta'), headers: _headers));

  List<T> _mapList<T>(dynamic data, T Function(Map<String, dynamic>) mapper) {
    return (data as List)
        .map((e) => mapper(Map<String, dynamic>.from(e)))
        .toList();
  }

  List<Map<String, dynamic>> _mapRaw(dynamic data) {
    return (data as List).map((e) => Map<String, dynamic>.from(e)).toList();
  }

  Stream<List<T>> _poll<T>(Future<List<T>> Function() consulta) async* {
    while (true) {
      try {
        yield await consulta();
      } catch (e) {
        print('❌ Backend no disponible: $e');
        yield <T>[];
      }
      await Future.delayed(_intervaloStream);
    }
  }

  Future<Map<String, dynamic>> login(String correo, String password) async {
    final r = await _post('/login', {'correo': correo, 'password': password});
    return Map<String, dynamic>.from(r);
  }

  Stream<List<SedeModel>> getSedesStream() => _poll(getSedes);

  Future<List<SedeModel>> getSedes() async =>
      _mapList(await _get('/sedes'), SedeModel.fromJson);

  Future<String> agregarSede(SedeModel sede) async {
    final r = await _post('/sedes', sede.toJson());
    return r['id'];
  }

  Future<void> actualizarSede(String sedeId, SedeModel sede) async {
    await _put('/sedes/$sedeId', sede.toJson());
  }

  Future<void> eliminarSede(String sedeId) async {
    await _delete('/sedes/$sedeId');
  }

  Stream<List<CanchaModel>> getCanchasPorSedeStream(String sedeId) =>
      _poll(() => getCanchasPorSede(sedeId));

  Future<List<CanchaModel>> getCanchasPorSede(String sedeId) async =>
      _mapList(await _get('/canchas?sedeId=$sedeId'), CanchaModel.fromJson);

  Future<String> agregarCancha(CanchaModel cancha, String sedeId) async {
    final data = cancha.toJson()..['sedeId'] = sedeId;
    final r = await _post('/canchas', data);
    return r['id'];
  }

  Future<void> actualizarCancha(String canchaId, CanchaModel cancha) async {
    await _put('/canchas/$canchaId', cancha.toJson());
  }

  Future<void> eliminarCancha(String canchaId) async {
    await _delete('/canchas/$canchaId');
  }

  Future<String> crearReserva(
      ReservaModel reserva, String canchaId, String sedeId) async {
    final data = reserva.toJson()
      ..['canchaId'] = canchaId
      ..['sedeId'] = sedeId;
    final r = await _post('/reservas', data);
    return r['id'];
  }

  Stream<List<Map<String, dynamic>>> getReservasStream() =>
      _poll(() async => _mapRaw(await _get('/reservas')));

  Stream<List<Map<String, dynamic>>> getReservasPorEstadoStream(
          String estado) =>
      _poll(() async => _mapRaw(await _get('/reservas?estado=$estado')));

  Future<List<Map<String, dynamic>>> getReservasPorUsuario(
          String correo) async =>
      _mapRaw(
          await _get('/reservas?correo=${Uri.encodeQueryComponent(correo)}'));

  Future<void> actualizarEstadoReserva(
      String reservaId, String nuevoEstado) async {
    await _patch('/reservas/$reservaId/estado', {'estado': nuevoEstado});
  }

  Future<void> eliminarReserva(String reservaId) async {
    await _delete('/reservas/$reservaId');
  }

  Future<List<Map<String, dynamic>>> getReservasCompletas() async =>
      _mapRaw(await _get('/reservas-completas'));

  Future<List<Map<String, dynamic>>> getReservasCompletasPorSede(
          String sedeId) async =>
      _mapRaw(await _get('/reservas-completas?sedeId=$sedeId'));

  Future<bool> verificarDisponibilidad({
    required String canchaId,
    required DateTime fecha,
    required String horaReserva,
  }) async {
    try {
      final f =
          '${fecha.year}-${fecha.month.toString().padLeft(2, '0')}-${fecha.day.toString().padLeft(2, '0')}';
      final r = await _get(
          '/disponibilidad?canchaId=$canchaId&fecha=$f&hora=${Uri.encodeQueryComponent(horaReserva)}');
      return r['disponible'] == true;
    } catch (e) {
      print('❌ Error al verificar disponibilidad: $e');
      return false;
    }
  }

  Future<Map<String, dynamic>> getEstadisticasDashboard() async =>
      Map<String, dynamic>.from(await _get('/estadisticas'));

  Future<Map<String, dynamic>> getEstadisticasPorSede(String sedeId) async =>
      Map<String, dynamic>.from(await _get('/estadisticas?sedeId=$sedeId'));

  Future<String> crearBloqueo(BloqueoModel bloqueo) async {
    final r = await _post('/bloqueos', bloqueo.toJson());
    return r['id'];
  }

  Future<List<BloqueoModel>> getBloqueos() async =>
      _mapList(await _get('/bloqueos'), BloqueoModel.fromJson);

  Stream<List<BloqueoModel>> getBloqueoStream() => _poll(getBloqueos);

  Future<void> actualizarBloqueo(String id, BloqueoModel bloqueo) async {
    await _put('/bloqueos/$id', bloqueo.toJson());
  }

  Future<void> eliminarBloqueo(String id) async {
    await _delete('/bloqueos/$id');
  }

  Future<void> toggleBloqueo(String id, bool activo) async {
    await _patch('/bloqueos/$id/activo', {'activo': activo});
  }

  Future<bool> estaBloqueada({
    required String canchaId,
    required DateTime fecha,
    required String horaReserva,
  }) async {
    return !(await verificarDisponibilidad(
        canchaId: canchaId, fecha: fecha, horaReserva: horaReserva));
  }

  /// Reservas del período [desde, hasta) para el reporte del SuperAdmin.
  /// 'desde' es inclusivo y 'hasta' exclusivo. Se envían en UTC (ISO 8601 con
  /// 'Z') para que el backend no dependa de su propia zona horaria.
  Future<List<Map<String, dynamic>>> getReporteReservas({
    required DateTime desde,
    required DateTime hasta,
    String? sedeId,
  }) async {
    final params = <String, String>{
      'desde': desde.toUtc().toIso8601String(),
      'hasta': hasta.toUtc().toIso8601String(),
      if (sedeId != null && sedeId.isNotEmpty) 'sedeId': sedeId,
    };
    return _mapRaw(
        await _get('/reportes/reservas?${Uri(queryParameters: params).query}'));
  }

  Future<List<Map<String, dynamic>>> getAuditoria(
      {String? entidad, String? usuario}) async {
    final params = <String, String>{};
    if (entidad != null && entidad.isNotEmpty) params['entidad'] = entidad;
    if (usuario != null && usuario.isNotEmpty) params['usuario'] = usuario;
    final query =
        params.isEmpty ? '' : '?${Uri(queryParameters: params).query}';
    return _mapRaw(await _get('/auditoria$query'));
  }
}