// lib/models/reserva_model.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'cancha_modelo.dart';

class ReservaModel {
  final String? id;
  final String nombreCompleto;
  final String correoElectronico;
  final String numeroCelular;
  final DateTime? fechaReserva;
  final String? horaReserva;
  final TipoCancha tipoCancha;
  final String? canchaId;
  final String? sedeId;
  final String? estado;

  ReservaModel({
    this.id,
    required this.nombreCompleto,
    required this.correoElectronico,
    required this.numeroCelular,
    this.fechaReserva,
    this.horaReserva,
    required this.tipoCancha,
    this.canchaId,
    this.sedeId,
    this.estado = 'pendiente',
  });

  factory ReservaModel.fromJson(Map<String, dynamic> json) {
    return ReservaModel(
      id: json['id'],
      nombreCompleto: json['nombreCompleto'] ?? '',
      correoElectronico: json['correoElectronico'] ?? '',
      numeroCelular: json['numeroCelular'] ?? '',
      fechaReserva: _parseFecha(json['fechaReserva']),
      horaReserva: json['horaReserva'],
      tipoCancha: _parseTipoCancha(json['tipoCancha']),
      canchaId: json['canchaId'],
      sedeId: json['sedeId'],
      estado: json['estado'] ?? 'pendiente',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      if (id != null) 'id': id,
      'nombreCompleto': nombreCompleto,
      'correoElectronico': correoElectronico,
      'numeroCelular': numeroCelular,
      if (fechaReserva != null) 'fechaReserva': Timestamp.fromDate(fechaReserva!),
      'horaReserva': horaReserva,
      'tipoCancha': tipoCancha.name,
      if (canchaId != null) 'canchaId': canchaId,
      if (sedeId != null) 'sedeId': sedeId,
      'estado': estado,
    };
  }

  static DateTime? _parseFecha(dynamic val) {
    if (val is Timestamp) return val.toDate();
    if (val is String) return DateTime.tryParse(val);
    return null;
  }

  static TipoCancha _parseTipoCancha(String? tipoStr) {
    if (tipoStr == null) return TipoCancha.abierta;
    return TipoCancha.values.firstWhere(
      (e) => tipoStr.contains(e.name),
      orElse: () => TipoCancha.abierta,
    );
  }

  bool get isValid =>
      nombreCompleto.isNotEmpty &&
      correoElectronico.isNotEmpty &&
      numeroCelular.isNotEmpty &&
      fechaReserva != null &&
      horaReserva != null;

  ReservaModel copyWith({
    String? id,
    String? nombreCompleto,
    String? correoElectronico,
    String? numeroCelular,
    DateTime? fechaReserva,
    String? horaReserva,
    TipoCancha? tipoCancha,
    String? canchaId,
    String? sedeId,
    String? estado,
  }) {
    return ReservaModel(
      id: id ?? this.id,
      nombreCompleto: nombreCompleto ?? this.nombreCompleto,
      correoElectronico: correoElectronico ?? this.correoElectronico,
      numeroCelular: numeroCelular ?? this.numeroCelular,
      fechaReserva: fechaReserva ?? this.fechaReserva,
      horaReserva: horaReserva ?? this.horaReserva,
      tipoCancha: tipoCancha ?? this.tipoCancha,
      canchaId: canchaId ?? this.canchaId,
      sedeId: sedeId ?? this.sedeId,
      estado: estado ?? this.estado,
    );
  }
}