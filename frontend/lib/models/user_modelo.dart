// lib/models/user_model.dart
import 'package:cloud_firestore/cloud_firestore.dart';

enum UserRole {
  superAdmin,
  propietario,
}

class UserModel {
  final String? id;
  final String nombre;
  final String email;
  final UserRole rol;
  final String? sedeAsignada;
  final String? telefono;
  final DateTime? createdAt;
  final bool activo;
  final bool is2FAEnabled;
  final String? totpSecret;
  final List<String> backupCodes;

  UserModel({
    this.id,
    required this.nombre,
    required this.email,
    required this.rol,
    this.sedeAsignada,
    this.telefono,
    this.createdAt,
    this.activo = true,
    this.is2FAEnabled = false,
    this.totpSecret,
    this.backupCodes = const [],
  });

  factory UserModel.fromJson(Map<String, dynamic> json) {
    return UserModel(
      id: json['id'],
      nombre: json['nombre'] ?? '',
      email: json['email'] ?? '',
      rol: _parseRole(json['rol']),
      sedeAsignada: json['sedeAsignada'],
      telefono: json['telefono'],
      createdAt: json['createdAt'] != null
          ? (json['createdAt'] as Timestamp).toDate()
          : null,
      activo: json['activo'] ?? true,
      is2FAEnabled: json['is2FAEnabled'] ?? false,
      totpSecret: json['totpSecret'] ?? json['twoFactorSecret'],
      backupCodes: List<String>.from(json['backupCodes'] ?? []),
    );
  }

  factory UserModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>? ?? {};
    return UserModel.fromJson({...data, 'id': doc.id});
  }

  Map<String, dynamic> toJson() {
    return {
      if (id != null) 'id': id,
      'nombre': nombre,
      'email': email,
      'rol': rol.name,
      if (sedeAsignada != null) 'sedeAsignada': sedeAsignada,
      if (telefono != null) 'telefono': telefono,
      'createdAt': createdAt != null
          ? Timestamp.fromDate(createdAt!)
          : FieldValue.serverTimestamp(),
      'activo': activo,
      'is2FAEnabled': is2FAEnabled,
      if (totpSecret != null) 'totpSecret': totpSecret,
      'backupCodes': backupCodes,
    };
  }

  static UserRole _parseRole(String? roleStr) {
    switch (roleStr?.toLowerCase()) {
      case 'superadmin':
      case 'super_admin':
        return UserRole.superAdmin;
      case 'propietario':
        return UserRole.propietario;
      default:
        return UserRole.propietario;
    }
  }

  bool get isSuperAdmin => rol == UserRole.superAdmin;
  bool get isPropietario => rol == UserRole.propietario;
  String? get twoFactorSecret => totpSecret;

  UserModel copyWith({
    String? id,
    String? nombre,
    String? email,
    UserRole? rol,
    String? sedeAsignada,
    String? telefono,
    DateTime? createdAt,
    bool? activo,
    bool? is2FAEnabled,
    String? totpSecret,
    List<String>? backupCodes,
  }) {
    return UserModel(
      id: id ?? this.id,
      nombre: nombre ?? this.nombre,
      email: email ?? this.email,
      rol: rol ?? this.rol,
      sedeAsignada: sedeAsignada ?? this.sedeAsignada,
      telefono: telefono ?? this.telefono,
      createdAt: createdAt ?? this.createdAt,
      activo: activo ?? this.activo,
      is2FAEnabled: is2FAEnabled ?? this.is2FAEnabled,
      totpSecret: totpSecret ?? this.totpSecret,
      backupCodes: backupCodes ?? this.backupCodes,
    );
  }
}
