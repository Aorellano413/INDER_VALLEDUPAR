// lib/views/login_view.dart
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../controllers/tema_controlador.dart';
import '../routes/app_rutas.dart';

class LoginView extends StatelessWidget {
  const LoginView({super.key});

  @override
  Widget build(BuildContext context) {
    final isDark = context.watch<ThemeController>().isDark;
    final textStyle = GoogleFonts.poppins(color: Colors.white);

    return Scaffold(
      body: SafeArea(
        child: Stack(
          children: [
            Positioned.fill(child: Image.asset("lib/images/fondo.jpg", fit: BoxFit.cover)),
            Positioned.fill(
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 6, sigmaY: 6),
                child: Container(color: Colors.black.withOpacity(0.45)),
              ),
            ),
            Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(24),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 420),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Image.asset("lib/images/inder.png", height: 160, fit: BoxFit.contain),
                      const SizedBox(height: 20),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(36),
                        child: BackdropFilter(
                          filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                          child: Container(
                            padding: EdgeInsets.fromLTRB(30, 30, 30, 16 + MediaQuery.of(context).viewPadding.bottom),
                            decoration: BoxDecoration(
                              color: isDark ? Colors.black.withOpacity(0.3) : Colors.white.withOpacity(0.2),
                              borderRadius: BorderRadius.circular(36),
                              border: Border.all(color: Colors.white.withOpacity(0.2), width: 1.5),
                              boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.3), blurRadius: 30, offset: const Offset(0, 15))],
                            ),
                            child: Column(
                              children: [
                                Text("Bienvenido a", style: textStyle.copyWith(fontSize: 18, fontWeight: FontWeight.w500)),
                                Text("INDER VALLEDUPAR", textAlign: TextAlign.center, style: textStyle.copyWith(fontSize: 26, fontWeight: FontWeight.bold, letterSpacing: 1.2)),
                                const SizedBox(height: 10),
                                Text("Tu mejor aliado para reservar en los mejores escenarios deportivos de Valledupar", textAlign: TextAlign.center, style: textStyle.copyWith(fontSize: 14, height: 1.4)),
                                const SizedBox(height: 24),
                                SizedBox(
                                  width: double.infinity,
                                  height: 50,
                                  child: ElevatedButton(
                                    style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF3546F0), elevation: 4, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30))),
                                    onPressed: () => Navigator.pushNamed(context, AppRoutes.sedes),
                                    child: Text("Reservar Cancha", style: textStyle.copyWith(fontWeight: FontWeight.w600, fontSize: 15)),
                                  ),
                                ),
                                const SizedBox(height: 30),
                                Text("© 2025 ReservaSports. Todos los derechos reservados.", textAlign: TextAlign.center, style: textStyle.copyWith(fontSize: 12, color: Colors.white70)),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}