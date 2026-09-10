// lib/controllers/auth_controller.dart
import 'package:flutter/material.dart';
import 'package:otp/otp.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/user_modelo.dart';
import '../services/autenticacion_servicio.dart';

class AuthController extends ChangeNotifier {
  final AuthService _authService = AuthService();

  UserModel? _currentUser;
  bool _isLoading = false;
  bool _is2FaVerified = false;
  String? _error;

  int _failed2FAAttempts = 0;
  DateTime? _lockoutEndTime;

  UserModel? get currentUser => _currentUser;
  bool get isLoading => _isLoading;
  String? get error => _error;

  int get remainingAttempts {
    int remaining = 3 - _failed2FAAttempts;
    return remaining < 0 ? 0 : remaining;
  }

  bool get isLockedOut {
    if (_lockoutEndTime != null) {
      if (DateTime.now().isBefore(_lockoutEndTime!)) {
        return true;
      } else {
        _lockoutEndTime = null;
        _failed2FAAttempts = 0;
      }
    }
    return false;
  }

  int get remainingLockoutSeconds {
    if (_lockoutEndTime == null) return 0;
    final diff = _lockoutEndTime!.difference(DateTime.now()).inSeconds;
    return diff > 0 ? diff : 0;
  }

  bool get isAuthenticated => _currentUser != null && _is2FaVerified;
  bool get isSuperAdmin =>
      isAuthenticated && (_currentUser?.isSuperAdmin ?? false);
  bool get isPropietario =>
      isAuthenticated && (_currentUser?.isPropietario ?? false);

  void _resetUser() {
    _currentUser = null;
    _is2FaVerified = false;
    _failed2FAAttempts = 0;
    _lockoutEndTime = null;
    notifyListeners();
  }

  void _setLoading(bool loading) {
    _isLoading = loading;
    notifyListeners();
  }

  Future<Map<String, dynamic>> login(
      {required String email, required String password}) async {
    _error = null;
    _is2FaVerified = false;
    _setLoading(true);

    try {
      final resultado =
          await _authService.login(email: email, password: password);
      if (resultado['success']) {
        _currentUser = resultado['user'];
        return {
          'success': true,
          'requires2FA': true,
        };
      }

      String mensajeOriginal = resultado['message'] ?? '';
      String mensajeAmigable = 'Correo o contraseña incorrectos.';

      if (mensajeOriginal.contains('user-not-found') || mensajeOriginal.contains('no user record')) {
        mensajeAmigable = 'Usuario no encontrado.';
      } else if (mensajeOriginal.contains('wrong-password') || mensajeOriginal.contains('credential is incorrect')) {
        mensajeAmigable = 'Contraseña incorrecta.';
      } else if (mensajeOriginal.contains('invalid-email')) {
        mensajeAmigable = 'El formato del correo es inválido.';
      } else if (mensajeOriginal.contains('user-disabled')) {
        mensajeAmigable = 'Esta cuenta ha sido deshabilitada.';
      }

      _error = mensajeAmigable;
      return {'success': false, 'message': _error};
    } catch (e) {
      _error = 'Usuario no encontrado o credenciales inválidas.';
      return {'success': false, 'message': _error};
    } finally {
      _setLoading(false);
    }
  }

  Future<Map<String, dynamic>> verify2FA({required String code}) async {
    if (_currentUser == null) {
      return {
        'success': false,
        'message': 'Sesión expirada. Inicie sesión nuevamente.'
      };
    }

    if (isLockedOut) {
      return {
        'success': false,
        'message':
            'Demasiados intentos fallidos. Intente de nuevo en ${remainingLockoutSeconds}s.'
      };
    }

    _setLoading(true);
    try {
      final inputCode = code.trim().toUpperCase();
      final String? secretKey2FA =
          _currentUser!.totpSecret ?? _currentUser!.twoFactorSecret;
      final List<String> backupCodes = _currentUser!.backupCodes;

      if (backupCodes.contains(inputCode)) {
        await _consumirBackupCode(inputCode);
        _is2FaVerified = true;
        _failed2FAAttempts = 0;
        notifyListeners();
        return {
          'success': true,
          'message': 'Autenticación exitosa mediante código de respaldo.'
        };
      }

      if (secretKey2FA == null || secretKey2FA.isEmpty) {
        return {
          'success': false,
          'message': 'El usuario no tiene configurado 2FA.'
        };
      }
      final now = DateTime.now().millisecondsSinceEpoch;

      final isCodeValid = OTP.generateTOTPCodeString(
            secretKey2FA,
            now,
            interval: 30,
            algorithm: Algorithm.SHA1,
            isGoogle: true,
          ) ==
          inputCode;

      if (isCodeValid) {
        _is2FaVerified = true;
        _failed2FAAttempts = 0;
        notifyListeners();
        return {'success': true, 'message': 'Autenticación exitosa'};
      } else {
        _failed2FAAttempts++;
        if (_failed2FAAttempts >= 3) {
          _lockoutEndTime = DateTime.now().add(const Duration(minutes: 5));
          notifyListeners();
          return {
            'success': false,
            'message':
                'Límite de 3 intentos alcanzado. Bloqueado temporalmente por 5 minutos.'
          };
        }
        return {
          'success': false,
          'message': 'Código incorrecto. Intentos restantes: $remainingAttempts'
        };
      }
    } catch (e) {
      return {'success': false, 'message': 'Error al procesar 2FA: $e'};
    } finally {
      _setLoading(false);
    }
  }

  Future<void> _consumirBackupCode(String code) async {
    if (_currentUser == null || _currentUser!.id == null) return;

    final updatedBackupCodes = List<String>.from(_currentUser!.backupCodes)
      ..remove(code);
    await FirebaseFirestore.instance
        .collection('usuarios')
        .doc(_currentUser!.id)
        .update({
      'backupCodes': updatedBackupCodes,
    });

    _currentUser = _currentUser!.copyWith(backupCodes: updatedBackupCodes);
  }

  Future<void> reloadUserData() async {
    if (_currentUser != null && _currentUser!.id != null) {
      try {
        final doc = await FirebaseFirestore.instance
            .collection('usuarios')
            .doc(_currentUser!.id)
            .get();
        if (doc.exists) {
          _currentUser = UserModel.fromFirestore(doc);
          _is2FaVerified = true;
          notifyListeners();
        }
      } catch (e) {
        debugPrint('Error al recargar datos del usuario: $e');
      }
    }
  }

  Future<void> logout() async {
    await _authService.logout();
    _resetUser();
  }
}