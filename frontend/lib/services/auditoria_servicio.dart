import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class AuditoriaService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  Future<void> registrarAccion({
    required String accion,
    required String detalles,
  }) async {
    try {
      final user = _auth.currentUser;
      if (user == null) return;

      await _db.collection('auditoria').add({
        'uidAdmin': user.uid,
        'correoAdmin': user.email ?? 'Desconocido',
        'accion': accion,
        'detalles': detalles,
        'fecha': FieldValue.serverTimestamp(),
        'ip': 'Cliente Flutter Monolito',
      });
    } catch (e) {
      print('Error al registrar auditoría: $e');
    }
  }
}