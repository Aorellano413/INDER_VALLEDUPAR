// lib/controllers/sedes_controller.dart
import 'package:flutter/material.dart';
import '../models/sede_modelo.dart';
import '../services/firestore_servicio.dart';
import '../services/almacenamiento_servicio.dart';
import '../services/ubicacion_servicio.dart';

class SedesController extends ChangeNotifier {
  final FirestoreService _firestore = FirestoreService();
  final StorageService _storage = StorageService();
  final LocationService _location = LocationService();

  List<SedeModel> _todasLasSedes = [];
  String _searchText = "";
  bool _isLoading = false;
  String? _error;

  List<SedeModel> get sedes {
    if (_searchText.isEmpty) return List.unmodifiable(_todasLasSedes);
    return _todasLasSedes
        .where((s) =>
            s.title.toLowerCase().contains(_searchText) ||
            s.subtitle.toLowerCase().contains(_searchText))
        .toList();
  }

  List<SedeModel> get customSedes =>
      _todasLasSedes.where((s) => s.isCustom).toList(growable: false);

  bool get isLoading => _isLoading;
  String? get error => _error;

  SedesController() {
    cargarSedes();
  }

  Future<void> cargarSedes() async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      _todasLasSedes = await _firestore.getSedes();
    } catch (e) {
      _error = 'Error al cargar sedes: $e';
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  void escucharSedes() {
    _firestore.getSedesStream().listen(
      (sedes) {
        _todasLasSedes = sedes;
        notifyListeners();
      },
      onError: (error) {
        _error = 'Error al escuchar sedes: $error';
        notifyListeners();
      },
    );
  }

  void buscarSedes(String query) {
    _searchText = query.toLowerCase();
    notifyListeners();
  }

  Future<bool> abrirUbicacionEnMapas(String direccion) async {
    return await _location.abrirUbicacionEnMapas(direccion);
  }

  Future<void> agregarSede(SedeModel sede) async {
    try {
      final sedeConTag = sede.copyWith(isCustom: true, tag: "Día - Noche");
      final id = await _firestore.agregarSede(sedeConTag);
      _todasLasSedes.add(sedeConTag.copyWith(id: id));
      notifyListeners();
    } catch (e) {
      _error = 'Error al agregar sede: $e';
      notifyListeners();
      rethrow;
    }
  }

  int _obtenerIndiceRealSedeCustom(int customIndex) {
    int count = -1;
    for (int i = 0; i < _todasLasSedes.length; i++) {
      if (_todasLasSedes[i].isCustom && ++count == customIndex) return i;
    }
    return -1;
  }

  Future<void> actualizarSedeCustom(int customIndex, SedeModel updated) async {
    try {
      final realIndex = _obtenerIndiceRealSedeCustom(customIndex);
      if (realIndex == -1) return;

      final sedeId = _todasLasSedes[realIndex].id;
      if (sedeId == null) throw Exception('Sede sin ID');

      final sedeActualizada = updated.copyWith(
        id: sedeId,
        isCustom: true,
        tag: "Día - Noche",
      );

      await _firestore.actualizarSede(sedeId, sedeActualizada);
      _todasLasSedes[realIndex] = sedeActualizada;
      notifyListeners();
    } catch (e) {
      _error = 'Error al actualizar sede: $e';
      notifyListeners();
      rethrow;
    }
  }

  Future<void> eliminarSedeCustom(int customIndex) async {
    try {
      final realIndex = _obtenerIndiceRealSedeCustom(customIndex);
      if (realIndex == -1) return;

      final sedeId = _todasLasSedes[realIndex].id;
      if (sedeId == null) throw Exception('Sede sin ID');

      final imagePath = _todasLasSedes[realIndex].imagePath;
      if (imagePath.isNotEmpty && _storage.esUrlFirebase(imagePath)) {
        await _storage.eliminarImagen(imagePath);
      }

      await _firestore.eliminarSede(sedeId);
      _todasLasSedes.removeAt(realIndex);
      notifyListeners();
    } catch (e) {
      _error = 'Error al eliminar sede: $e';
      notifyListeners();
      rethrow;
    }
  }

  SedeModel? obtenerSedePorId(String sedeId) {
    try {
      return _todasLasSedes.firstWhere((s) => s.id == sedeId);
    } catch (_) {
      return null;
    }
  }
}