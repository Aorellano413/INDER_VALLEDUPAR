// lib/models/bloqueo_modelo.dart
import 'package:cloud_firestore/cloud_firestore.dart';

enum TipoBloqueo { rangoHorario, rangoDias }

class BloqueoModel {
  final String? id;
  final String titulo;
  final String? descripcion;
  final List<String> canchaIds;
  final TipoBloqueo tipo;
  final DateTime? fechaBloqueo;
  final DateTime? fechaInicio;
  final DateTime? fechaFin;
  final List<String> horasEspecificas;
  final bool activo;
  final DateTime? creadoEn;

  BloqueoModel({
    this.id,
    required this.titulo,
    this.descripcion,
    required this.canchaIds,
    required this.tipo,
    this.fechaBloqueo,
    this.fechaInicio,
    this.fechaFin,
    required this.horasEspecificas,
    required this.activo,
    this.creadoEn,
  });

  Map<String, dynamic> toJson() {
    return {
      'titulo': titulo,
      'descripcion': descripcion,
      'canchaIds': canchaIds,
      'tipo': tipo.index,
      'fechaBloqueo': fechaBloqueo != null ? Timestamp.fromDate(fechaBloqueo!) : null,
      'fechaInicio': fechaInicio != null ? Timestamp.fromDate(fechaInicio!) : null,
      'fechaFin': fechaFin != null ? Timestamp.fromDate(fechaFin!) : null,
      'horasEspecificas': horasEspecificas,
      'activo': activo,
      'creadoEn': creadoEn ?? FieldValue.serverTimestamp(),
    };
  }

  factory BloqueoModel.fromJson(Map<String, dynamic> json) {
    TipoBloqueo tipoBloqueo = TipoBloqueo.rangoHorario;

    try {
      final val = json['tipo'];
      if (val is int && val < TipoBloqueo.values.length) {
        tipoBloqueo = TipoBloqueo.values[val];
      } else if (val is String) {
        if (val == 'rangoDias') tipoBloqueo = TipoBloqueo.rangoDias;
      }
    } catch (_) {
      tipoBloqueo = TipoBloqueo.rangoHorario;
    }

    return BloqueoModel(
      id: json['id'],
      titulo: json['titulo'] ?? '',
      descripcion: json['descripcion'],
      canchaIds: List<String>.from(json['canchaIds'] ?? []),
      tipo: tipoBloqueo,
      fechaBloqueo: (json['fechaBloqueo'] as Timestamp?)?.toDate(),
      fechaInicio: (json['fechaInicio'] as Timestamp?)?.toDate(),
      fechaFin: (json['fechaFin'] as Timestamp?)?.toDate(),
      horasEspecificas: List<String>.from(json['horasEspecificas'] ?? []),
      activo: json['activo'] ?? true,
      creadoEn: (json['creadoEn'] as Timestamp?)?.toDate(),
    );
  }
}