// lib/main.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';
import 'controllers/tema_controlador.dart';
import 'controllers/sedes_controlador.dart';
import 'controllers/reserva_controlador.dart';
import 'controllers/canchas_controlador.dart';
import 'controllers/autenticacion_controlador..dart';
import 'theme/app_tema.dart';
import 'routes/app_rutas.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => ThemeController()),
        ChangeNotifierProvider(create: (_) => SedesController()),
        ChangeNotifierProvider(create: (_) => ReservaController()),
        ChangeNotifierProvider(create: (_) => CanchasController()),
        ChangeNotifierProvider(create: (_) => AuthController()),
      ],
      child: const InderApp(),
    ),
  );
}

class InderApp extends StatelessWidget {
  const InderApp({super.key});

  @override
  Widget build(BuildContext context) {
    final themeCtrl = context.watch<ThemeController>();

    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'INDER - Valledupar',
      theme: AppTheme.light(),
      darkTheme: AppTheme.dark(),
      themeMode: themeCtrl.mode,
      initialRoute: AppRoutes.adminDashboard,
      routes: AppRoutes.routes,
      onGenerateRoute: AppRoutes.onGenerateRoute,
    );
  }
}