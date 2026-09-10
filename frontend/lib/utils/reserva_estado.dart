// lib/utils/reserva_estado.dart
import 'package:flutter/material.dart';

enum ReservaEstado { pendiente, pagado, cancelado }

extension ReservaEstadoX on ReservaEstado {
  String get label {
    switch (this) {
      case ReservaEstado.pendiente:
        return 'Pendiente';
      case ReservaEstado.pagado:
        return 'Pagado';
      case ReservaEstado.cancelado:
        return 'Cancelado';
    }
  }

  Color get color {
    switch (this) {
      case ReservaEstado.pendiente:
        return const Color(0xFFFFA000);
      case ReservaEstado.pagado:
        return const Color(0xFF2E7D32);
      case ReservaEstado.cancelado:
        return const Color(0xFFC62828);
    }
  }
}

class ReservaEstadoHelper {
  static ReservaEstado desdeString(String estado) {
    switch (estado.toLowerCase()) {
      case 'pagado':
        return ReservaEstado.pagado;
      case 'cancelado':
        return ReservaEstado.cancelado;
      default:
        return ReservaEstado.pendiente;
    }
  }
}