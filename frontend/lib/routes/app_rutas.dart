// lib/routes/app_rutas.dart
import 'package:flutter/material.dart';
import '../views/login_vista.dart';
import '../views/sedes_vista.dart';
import '../views/reserva_vista.dart';
import '../views/pagos_vista.dart';
import '../views/login_admin_vista.dart';
import '../views/admin_dashboard_vista.dart';
import '../views/super_admin_usuarios_vista.dart';
import '../views/propietario_dashboard_vista.dart.dart';
import '../views/propietario_canchas_vista.dart';
import '../views/admin_bloqueos_vista.dart';
import '../views/activar_2fa_vista.dart';
import '../views/reportes_reservas_vista.dart';

class AppRoutes {

  static const String login = '/';
  static const String sedes = '/sedes';
  static const String reserva = '/reserva';
  static const String pagos = '/pagos';

  static const String loginAdmin = '/admin/login';
  static const String activar2FA = '/admin/activar-2fa';

  static const String adminDashboard = '/admin/dashboard';
  static const String superAdminUsuarios = '/admin/usuarios';
  static const String adminBloqueos = '/admin/bloqueos';
  static const String adminReportes = '/admin/reportes';
  static const String configJefeInder = '/admin/config-jefe';


  static const String propietarioDashboard = '/propietario/dashboard';
  static const String propietarioCanchas = '/propietario/canchas';

  static Map<String, WidgetBuilder> routes = {
    login: (context) => const LoginView(),
    sedes: (context) => const SedesView(),
    reserva: (context) => const ReservaView(),
    pagos: (context) => const PagosView(),
    loginAdmin: (context) => const LoginAdminView(),
    activar2FA: (context) => const Activar2FAView(),
    adminDashboard: (context) => const AdminDashboardView(),
    superAdminUsuarios: (context) => const SuperAdminUsuariosView(),
    adminBloqueos: (context) => const AdminBloqueosVista(),
    propietarioDashboard: (context) => const PropietarioDashboardView(),
    propietarioCanchas: (context) => const PropietarioCanchasView(),
    adminReportes: (context) => const ReportesReservasView(),
  };

  static Route<dynamic>? onGenerateRoute(RouteSettings settings) {
    final builder = routes[settings.name];
    if (builder != null) {
      return MaterialPageRoute(builder: builder, settings: settings);
    }
    return null;
  }
}