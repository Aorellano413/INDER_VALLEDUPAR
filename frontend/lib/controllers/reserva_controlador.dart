// lib/controllers/reserva_controller.dart
import 'package:flutter/material.dart';
import '../models/reserva_modelo.dart';
import '../models/cancha_modelo.dart';
import '../services/firestore_servicio.dart';

class ReservaController extends ChangeNotifier {
  final FirestoreService _firestore = FirestoreService();
  final formKey = GlobalKey<FormState>();

  final TextEditingController nombreController = TextEditingController();
  final TextEditingController correoController = TextEditingController();
  final TextEditingController celularController = TextEditingController();

  DateTime? _fechaReserva;
  String? _horaSeleccionada;
  TipoCancha? _tipoCanchaSeleccionada;
  String? _canchaIdSeleccionada;
  String? _sedeIdSeleccionada;

  DateTime? get fechaReserva => _fechaReserva;
  String? get horaSeleccionada => _horaSeleccionada;
  TipoCancha? get tipoCanchaSeleccionada => _tipoCanchaSeleccionada;
  String? get canchaIdSeleccionada => _canchaIdSeleccionada;
  String? get sedeIdSeleccionada => _sedeIdSeleccionada;

  String _formatearHora12(int hora) {
    final periodo = hora < 12 ? 'AM' : 'PM';
    final hora12 = hora == 0 ? 12 : (hora > 12 ? hora - 12 : hora);
    return '${hora12.toString().padLeft(2, '0')}:00 $periodo';
  }

  List<String> generarSlots(String horario) {
    try {
      final partes = horario.split(' - ');
      if (partes.length != 2) return [];

      int parsearHora(String texto) {
        final t = texto.trim().toUpperCase();
        int hora = int.parse(t.replaceAll(RegExp(r'[APM\s]'), '').split(':')[0]);
        if (t.contains('PM') && hora != 12) hora += 12;
        if (t.contains('AM') && hora == 12) hora = 0;
        return hora;
      }

      final inicio = parsearHora(partes[0]);
      final fin = parsearHora(partes[1]);

      if (fin <= inicio) return [];

      return List.generate(fin - inicio, (i) {
        final h = inicio + i;
        return '${_formatearHora12(h)} - ${_formatearHora12(h + 1)}';
      });
    } catch (_) {
      return [];
    }
  }

  void setFechaReserva(DateTime? fecha) { _fechaReserva = fecha; notifyListeners(); }
  void setHoraSeleccionada(String? hora) { _horaSeleccionada = hora; notifyListeners(); }
  void setTipoCancha(TipoCancha tipo) { _tipoCanchaSeleccionada = tipo; notifyListeners(); }
  void setCanchaId(String? canchaId) { _canchaIdSeleccionada = canchaId; notifyListeners(); }
  void setSedeId(String? sedeId) { _sedeIdSeleccionada = sedeId; notifyListeners(); }

  ReservaModel? crearReserva() {
    if (_tipoCanchaSeleccionada == null) return null;

    final reserva = ReservaModel(
      nombreCompleto: nombreController.text,
      correoElectronico: correoController.text,
      numeroCelular: celularController.text,
      fechaReserva: _fechaReserva,
      horaReserva: _horaSeleccionada,
      tipoCancha: _tipoCanchaSeleccionada!,
      canchaId: _canchaIdSeleccionada,
      sedeId: _sedeIdSeleccionada,
    );

    return reserva.isValid ? reserva : null;
  }

  Future<Map<String, dynamic>> confirmarReserva() async {
    final reserva = crearReserva();
    if (reserva == null) return {'success': false, 'message': 'Datos de reserva incompletos'};
    if (_canchaIdSeleccionada == null || _sedeIdSeleccionada == null) {
      return {'success': false, 'message': 'Debe seleccionar una cancha específica'};
    }

    try {
      final disponible = await _firestore.verificarDisponibilidad(
        canchaId: _canchaIdSeleccionada!,
        fecha: _fechaReserva!,
        horaReserva: _horaSeleccionada!,
      );

      if (!disponible) {
        return {'success': false, 'message': 'Esta cancha ya está reservada para esa fecha y hora'};
      }

      final reservaId = await _firestore.crearReserva(reserva, _canchaIdSeleccionada!, _sedeIdSeleccionada!);
      return {'success': true, 'message': 'Reserva creada exitosamente', 'reservaId': reservaId};
    } catch (e) {
      return {'success': false, 'message': 'Error al crear la reserva: $e'};
    }
  }

  void limpiarCamposFormulario() {
    nombreController.clear();
    correoController.clear();
    celularController.clear();
    _fechaReserva = null;
    _horaSeleccionada = null;
    notifyListeners();
  }

  void limpiarFormulario() {
    limpiarCamposFormulario();
    _tipoCanchaSeleccionada = null;
    _canchaIdSeleccionada = null;
    _sedeIdSeleccionada = null;
    notifyListeners();
  }

  @override
  void dispose() {
    nombreController.dispose();
    correoController.dispose();
    celularController.dispose();
    super.dispose();
  }
}