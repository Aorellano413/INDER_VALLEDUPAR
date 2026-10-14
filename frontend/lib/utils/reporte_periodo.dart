// lib/utils/reporte_periodo.dart
//
// Períodos de tiempo del reporte de reservas.
//
// Un período es el intervalo [inicio, finExclusivo): "inicio" es la
// medianoche (hora local del dispositivo) del primer día y "finExclusivo" es
// la medianoche del día SIGUIENTE al último día. Así no se pierden las reservas
// del último día ni hace falta restar milisegundos.
//
// Los días se calculan con el constructor DateTime(año, mes, día + n) y no
// sumando Duration(days: n): el constructor normaliza meses, años y cambios de
// horario de verano; Duration solo suma 24 horas exactas.
import 'package:intl/intl.dart';

enum RangoReporte { hoy, semana, mes, personalizado }

class PeriodoReporte {
  /// Medianoche local del primer día (inclusive).
  final DateTime inicio;

  /// Medianoche local del día siguiente al último día (exclusive).
  final DateTime finExclusivo;

  const PeriodoReporte(this.inicio, this.finExclusivo);

  static final DateFormat _formato = DateFormat('dd/MM/yyyy');

  static DateTime _soloDia(DateTime f) => DateTime(f.year, f.month, f.day);

  /// Hoy.
  factory PeriodoReporte.hoy(DateTime ahora) {
    final d = _soloDia(ahora);
    return PeriodoReporte(d, DateTime(d.year, d.month, d.day + 1));
  }

  /// Semana en curso, de lunes a domingo.
  factory PeriodoReporte.semana(DateTime ahora) {
    final d = _soloDia(ahora);
    final lunes = DateTime(d.year, d.month, d.day - (d.weekday - DateTime.monday));
    return PeriodoReporte(lunes, DateTime(lunes.year, lunes.month, lunes.day + 7));
  }

  /// Mes calendario en curso.
  factory PeriodoReporte.mes(DateTime ahora) {
    return PeriodoReporte(
      DateTime(ahora.year, ahora.month, 1),
      DateTime(ahora.year, ahora.month + 1, 1), // diciembre → enero del año siguiente
    );
  }

  /// Rango elegido por el usuario; ambos días son inclusivos.
  /// Si llegan invertidos se ordenan.
  factory PeriodoReporte.personalizado(DateTime primerDia, DateTime ultimoDia) {
    var a = _soloDia(primerDia);
    var b = _soloDia(ultimoDia);
    if (b.isBefore(a)) {
      final t = a;
      a = b;
      b = t;
    }
    return PeriodoReporte(a, DateTime(b.year, b.month, b.day + 1));
  }

  /// Construye el período correspondiente al filtro seleccionado.
  /// Para [RangoReporte.personalizado] hay que indicar ambos días.
  factory PeriodoReporte.desde(
    RangoReporte rango, {
    DateTime? ahora,
    DateTime? personalizadoInicio,
    DateTime? personalizadoFin,
  }) {
    final ref = ahora ?? DateTime.now();
    switch (rango) {
      case RangoReporte.hoy:
        return PeriodoReporte.hoy(ref);
      case RangoReporte.semana:
        return PeriodoReporte.semana(ref);
      case RangoReporte.mes:
        return PeriodoReporte.mes(ref);
      case RangoReporte.personalizado:
        final i = personalizadoInicio ?? ref;
        return PeriodoReporte.personalizado(i, personalizadoFin ?? i);
    }
  }

  /// Último día incluido en el período.
  DateTime get ultimoDia =>
      DateTime(finExclusivo.year, finExclusivo.month, finExclusivo.day - 1);

  /// "dd/MM/yyyy" si es un solo día; "dd/MM/yyyy - dd/MM/yyyy" en otro caso.
  String get texto {
    final a = _formato.format(inicio);
    final b = _formato.format(ultimoDia);
    return a == b ? a : '$a - $b';
  }
}
