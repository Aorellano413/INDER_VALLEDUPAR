// lib/services/storage_service.dart
import 'dart:io';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/foundation.dart';
import 'package:image_picker/image_picker.dart';

class StorageService {
  static final StorageService _instance = StorageService._internal();
  factory StorageService() => _instance;
  StorageService._internal();

  final FirebaseStorage _storage = FirebaseStorage.instance;

  Future<String> _subirImagen({
    required String folder,
    required String prefix,
    required String entityId,
    required XFile imageFile,
  }) async {
    final fileName = '${prefix}_${entityId}_${DateTime.now().millisecondsSinceEpoch}.jpg';
    final ref = _storage.ref().child('$folder/$fileName');
    final metadata = SettableMetadata(contentType: 'image/jpeg');

    final uploadTask = kIsWeb
        ? ref.putData(await imageFile.readAsBytes(), metadata)
        : ref.putFile(File(imageFile.path), metadata);

    final snapshot = await uploadTask;
    return await snapshot.ref.getDownloadURL();
  }

  Future<String> subirImagenSede({
    required String sedeId,
    required XFile imageFile,
  }) => _subirImagen(folder: 'sedes', prefix: 'sede', entityId: sedeId, imageFile: imageFile);

  Future<String> subirImagenCancha({
    required String canchaId,
    required XFile imageFile,
  }) => _subirImagen(folder: 'canchas', prefix: 'cancha', entityId: canchaId, imageFile: imageFile);

  Future<void> eliminarImagen(String imageUrl) async {
    if (!esUrlFirebase(imageUrl)) return;
    try {
      await _storage.refFromURL(imageUrl).delete();
    } catch (_) {}
  }

  Future<void> _eliminarPorPrefijo(String folder, String pattern) async {
    try {
      final result = await _storage.ref().child(folder).listAll();
      final targets = result.items.where((item) => item.name.contains(pattern));
      await Future.wait(targets.map((item) => item.delete()));
    } catch (_) {}
  }

  Future<void> eliminarImagenesSede(String sedeId) =>
      _eliminarPorPrefijo('sedes', 'sede_$sedeId');

  Future<void> eliminarImagenesCancha(String canchaId) =>
      _eliminarPorPrefijo('canchas', 'cancha_$canchaId');

  bool esUrlFirebase(String url) =>
      url.contains('firebasestorage.googleapis.com');

  Future<int> obtenerTamanoImagen(String imageUrl) async {
    try {
      final metadata = await _storage.refFromURL(imageUrl).getMetadata();
      return metadata.size ?? 0;
    } catch (_) {
      return 0;
    }
  }
}