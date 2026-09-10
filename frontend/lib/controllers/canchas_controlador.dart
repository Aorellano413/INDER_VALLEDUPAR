// lib/controllers/canchas_controller.dart
import 'package:flutter/material.dart';
import '../models/cancha_modelo.dart';
import '../services/firestore_servicio.dart';
import '../services/almacenamiento_servicio.dart';

class CanchasController extends ChangeNotifier {
  final FirestoreService _firestore = FirestoreService();
  final StorageService _storage = StorageService();

  List<CanchaModel> _canchas = [];
  bool _isLoading = false;
  String? _error;
  String? _sedeId;

  List<CanchaModel> get canchas => _canchas;
  bool get isLoading => _isLoading;
  String? get error => _error;

  Future<void> cargarCanchasPorSede(String sedeId) async {
    _sedeId = sedeId;
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      _canchas = await _firestore.getCanchasPorSede(sedeId);
      _isLoading = false;
      notifyListeners();
    } catch (e) {
      _error = 'Error al cargar canchas: $e';
      _isLoading = false;
      notifyListeners();
    }
  }

  void escucharCanchas(String sedeId) {
    _sedeId = sedeId;
    _firestore.getCanchasPorSedeStream(sedeId).listen(
      (canchas) {
        _canchas = canchas;
        notifyListeners();
      },
      onError: (error) {
        _error = 'Error al escuchar canchas: $error';
        notifyListeners();
      },
    );
  }

  CanchaModel? obtenerCanchaPorTipo(TipoCancha tipo) {
    try {
      return _canchas.firstWhere((cancha) => cancha.tipo == tipo);
    } catch (e) {
      return null;
    }
  }

  CanchaModel? obtenerCanchaPorId(String canchaId) {
    try {
      return _canchas.firstWhere((cancha) => cancha.id == canchaId);
    } catch (e) {
      return null;
    }
  }

  Future<void> agregarCancha(CanchaModel cancha) async {
    if (_sedeId == null) {
      throw Exception('No se ha especificado una sede');
    }

    try {
      final id = await _firestore.agregarCancha(cancha, _sedeId!);
      _canchas.add(cancha.copyWith(id: id, sedeId: _sedeId));
      notifyListeners();
    } catch (e) {
      _error = 'Error al agregar cancha: $e';
      notifyListeners();
      rethrow;
    }
  }

  Future<void> actualizarCancha(String canchaId, CanchaModel cancha) async {
    try {
      await _firestore.actualizarCancha(canchaId, cancha);

      final index = _canchas.indexWhere((c) => c.id == canchaId);
      if (index != -1) {
        _canchas[index] = cancha.copyWith(id: canchaId);
        notifyListeners();
      }
    } catch (e) {
      _error = 'Error al actualizar cancha: $e';
      notifyListeners();
      rethrow;
    }
  }

  Future<void> eliminarCancha(String canchaId) async {
    try {
      final cancha = _canchas.firstWhere((c) => c.id == canchaId);
      if (cancha.image.isNotEmpty && _storage.esUrlFirebase(cancha.image)) {
        await _storage.eliminarImagen(cancha.image);
      }

      await _firestore.eliminarCancha(canchaId);
      _canchas.removeWhere((c) => c.id == canchaId);
      notifyListeners();
    } catch (e) {
      _error = 'Error al eliminar cancha: $e';
      notifyListeners();
      rethrow;
    }
  }
}