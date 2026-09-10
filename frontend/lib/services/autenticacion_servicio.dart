// lib/services/auth_service.dart
import 'dart:math';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:otp/otp.dart';
import '../models/user_modelo.dart';

class AuthService {
  static final AuthService _instance = AuthService._internal();
  factory AuthService() => _instance;
  AuthService._internal();

  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  Stream<User?> get authStateChanges => _auth.authStateChanges();
  User? get currentUser => _auth.currentUser;
  bool get isAuthenticated => currentUser != null;

  static String _mapAuthError(String code, String defaultMsg) {
    switch (code) {
      case 'user-not-found':
        return 'Usuario no encontrado';
      case 'wrong-password':
        return 'Contraseña incorrecta';
      case 'invalid-email':
        return 'Email inválido';
      case 'user-disabled':
        return 'Usuario deshabilitado';
      case 'too-many-requests':
        return 'Demasiados intentos. Intente más tarde';
      case 'email-already-in-use':
        return 'Este email ya está registrado';
      case 'weak-password':
        return 'La contraseña debe tener al menos 6 caracteres';
      default:
        return defaultMsg;
    }
  }

  String generarSecretoBase32() {
    const chars = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ234567';
    final rand = Random.secure();
    return List.generate(16, (index) => chars[rand.nextInt(chars.length)]).join();
  }

  Future<Map<String, dynamic>> activar2FA(String uid, String secreto) async {
    try {
      await _firestore.collection('usuarios').doc(uid).update({
        'totpSecret': secreto,
        'is2FAEnabled': true,
      });
      return {'success': true, 'message': '2FA activado correctamente'};
    } catch (e) {
      return {'success': false, 'message': 'Error al activar 2FA: $e'};
    }
  }

  Future<Map<String, dynamic>> desactivar2FA(String uid) async {
    try {
      await _firestore.collection('usuarios').doc(uid).update({
        'totpSecret': FieldValue.delete(),
        'is2FAEnabled': false,
      });
      return {'success': true, 'message': '2FA desactivado correctamente'};
    } catch (e) {
      return {'success': false, 'message': 'Error al desactivar 2FA: $e'};
    }
  }

  bool verificarCodigo2FA({required String codigoIngresado, required String secreto}) {
    try {
      final now = DateTime.now().millisecondsSinceEpoch;
      final codigoCorrecto = OTP.generateTOTPCodeString(
        secreto,
        now,
        interval: 30,
        length: 6,
        algorithm: Algorithm.SHA1,
      );
      return codigoIngresado.trim() == codigoCorrecto;
    } catch (e) {
      print('Error al verificar código 2FA: $e');
      return false;
    }
  }

  Future<Map<String, dynamic>> login({
    required String email,
    required String password,
  }) async {
    try {
      final credential = await _auth.signInWithEmailAndPassword(
        email: email.trim(),
        password: password,
      );

      if (credential.user == null) {
        return {'success': false, 'message': 'Error al iniciar sesión'};
      }

      final userData = await getUserData(credential.user!.uid);

      if (userData == null) {
        await logout();
        return {'success': false, 'message': 'Usuario no encontrado en la base de datos'};
      }

      if (!userData.activo) {
        await logout();
        return {'success': false, 'message': 'Usuario inactivo. Contacte al administrador'};
      }

      return {
        'success': true,
        'message': 'Bienvenido ${userData.nombre}',
        'user': userData,
      };
    } on FirebaseAuthException catch (e) {
      return {'success': false, 'message': _mapAuthError(e.code, 'Error: ${e.message}')};
    } catch (e) {
      return {'success': false, 'message': 'Error inesperado: $e'};
    }
  }

  Future<void> logout() async => await _auth.signOut();

  Future<UserModel?> getUserData(String uid) async {
    try {
      final doc = await _firestore.collection('usuarios').doc(uid).get();
      if (!doc.exists) return null;

      final data = doc.data()!;
      data['id'] = doc.id;
      return UserModel.fromJson(data);
    } catch (e) {
      print('Error al obtener datos del usuario: $e');
      return null;
    }
  }

  Future<List<UserModel>> getAllUsers() async {
    try {
      final snapshot = await _firestore.collection('usuarios').get();
      return snapshot.docs.map((doc) {
        final data = doc.data();
        data['id'] = doc.id;
        return UserModel.fromJson(data);
      }).toList();
    } catch (e) {
      print('Error al obtener usuarios: $e');
      return [];
    }
  }

  Future<Map<String, dynamic>> crearUsuario({
    required String nombre,
    required String email,
    required String password,
    required UserRole rol,
    String? sedeAsignada,
    String? telefono,
  }) async {
    final adminActual = currentUser;
    if (adminActual == null || adminActual.email == null) {
      return {'success': false, 'message': 'No hay sesión de administrador activa'};
    }

    try {
      final currentUserData = await getUserData(adminActual.uid);
      if (currentUserData == null || !currentUserData.isSuperAdmin) {
        return {'success': false, 'message': 'No tiene permisos para crear usuarios'};
      }

      if (rol == UserRole.propietario && sedeAsignada == null) {
        return {'success': false, 'message': 'Los propietarios deben tener una sede asignada'};
      }

      final secondaryApp = await Firebase.initializeApp(
        name: 'SecondaryApp-${DateTime.now().millisecondsSinceEpoch}',
        options: Firebase.app().options,
      );

      final secondaryAuth = FirebaseAuth.instanceFor(app: secondaryApp);

      try {
        final credential = await secondaryAuth.createUserWithEmailAndPassword(
          email: email.trim(),
          password: password,
        );

        if (credential.user == null) {
          await secondaryApp.delete();
          return {'success': false, 'message': 'Error al crear usuario en Firebase Auth'};
        }

        final uid = credential.user!.uid;

        final nuevoUsuario = UserModel(
          id: uid,
          nombre: nombre.trim(),
          email: email.trim(),
          rol: rol,
          sedeAsignada: rol == UserRole.propietario ? sedeAsignada : null,
          telefono: telefono?.trim(),
          createdAt: DateTime.now(),
          activo: true,
        );

        await _firestore.collection('usuarios').doc(uid).set(nuevoUsuario.toJson());

        if (rol == UserRole.propietario && sedeAsignada != null) {
          await _firestore.collection('sedes').doc(sedeAsignada).update({
            'propietarioId': uid,
            'contactoPropietario': telefono ?? '',
          });
        }

        await secondaryAuth.signOut();
        await secondaryApp.delete();

        return {
          'success': true,
          'message': 'Usuario creado exitosamente',
          'uid': uid,
        };
      } catch (e) {
        await secondaryApp.delete();
        rethrow;
      }
    } on FirebaseAuthException catch (e) {
      return {'success': false, 'message': _mapAuthError(e.code, 'Error: ${e.message}')};
    } catch (e) {
      return {'success': false, 'message': 'Error inesperado: $e'};
    }
  }

  Future<Map<String, dynamic>> actualizarUsuario({
    required String uid,
    required UserModel userData,
  }) async {
    try {
      final currentUserData = await getUserData(currentUser?.uid ?? '');
      if (currentUserData == null || !currentUserData.isSuperAdmin) {
        return {'success': false, 'message': 'No tiene permisos para actualizar usuarios'};
      }

      await _firestore.collection('usuarios').doc(uid).update(userData.toJson());

      if (userData.isPropietario && userData.sedeAsignada != null) {
        await _firestore.collection('sedes').doc(userData.sedeAsignada!).update({
          'propietarioId': uid,
          'contactoPropietario': userData.telefono ?? '',
        });
      }

      return {'success': true, 'message': 'Usuario actualizado exitosamente'};
    } catch (e) {
      return {'success': false, 'message': 'Error al actualizar usuario: $e'};
    }
  }

  Future<Map<String, dynamic>> eliminarUsuario(String uid) async {
    try {
      final currentUserData = await getUserData(currentUser?.uid ?? '');
      if (currentUserData == null || !currentUserData.isSuperAdmin) {
        return {'success': false, 'message': 'No tiene permisos para eliminar usuarios'};
      }
      if (uid == currentUser?.uid) {
        return {'success': false, 'message': 'No puede eliminarse a sí mismo'};
      }

      await _firestore.collection('usuarios').doc(uid).update({'activo': false});

      return {'success': true, 'message': 'Usuario desactivado exitosamente'};
    } catch (e) {
      return {'success': false, 'message': 'Error al eliminar usuario: $e'};
    }
  }

  Future<Map<String, dynamic>> cambiarPassword({
    required String oldPassword,
    required String newPassword,
  }) async {
    try {
      final user = currentUser;
      if (user == null) {
        return {'success': false, 'message': 'No hay usuario autenticado'};
      }

      final credential = EmailAuthProvider.credential(
        email: user.email!,
        password: oldPassword,
      );

      await user.reauthenticateWithCredential(credential);
      await user.updatePassword(newPassword);

      return {'success': true, 'message': 'Contraseña actualizada exitosamente'};
    } on FirebaseAuthException catch (e) {
      final msg = e.code == 'wrong-password' ? 'Contraseña actual incorrecta' : _mapAuthError(e.code, 'Error: ${e.message}');
      return {'success': false, 'message': msg};
    } catch (e) {
      return {'success': false, 'message': 'Error inesperado: $e'};
    }
  }

  Future<Map<String, dynamic>> recuperarPassword(String email) async {
    try {
      await _auth.sendPasswordResetEmail(email: email.trim());
      return {
        'success': true,
        'message': 'Se ha enviado un correo para restablecer tu contraseña',
      };
    } on FirebaseAuthException catch (e) {
      final msg = e.code == 'user-not-found' ? 'No existe un usuario con ese email' : _mapAuthError(e.code, 'Error: ${e.message}');
      return {'success': false, 'message': msg};
    } catch (e) {
      return {'success': false, 'message': 'Error inesperado: $e'};
    }
  }

  Future<Map<String, dynamic>> eliminarUsuarioPermanente(String uid) async {
    try {
      final currentUserData = await getUserData(currentUser?.uid ?? '');
      if (currentUserData == null || !currentUserData.isSuperAdmin) {
        return {'success': false, 'message': 'No tiene permisos para eliminar usuarios'};
      }

      if (uid == currentUser?.uid) {
        return {'success': false, 'message': 'No puede eliminarse a sí mismo'};
      }

      final usuarioData = await getUserData(uid);

      if (usuarioData != null && usuarioData.isPropietario && usuarioData.sedeAsignada != null) {
        final sedeDoc = await _firestore.collection('sedes').doc(usuarioData.sedeAsignada!).get();
        if (sedeDoc.exists) {
          await _firestore.collection('sedes').doc(usuarioData.sedeAsignada!).update({
            'propietarioId': null,
            'contactoPropietario': '',
          });
        }
      }

      await _firestore.collection('usuarios').doc(uid).delete();

      return {'success': true, 'message': 'Usuario eliminado permanentemente'};
    } catch (e) {
      return {'success': false, 'message': 'Error al eliminar usuario: $e'};
    }
  }
}