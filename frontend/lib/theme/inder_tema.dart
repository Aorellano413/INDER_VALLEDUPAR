// lib/theme/inder_tema.dart
//
// Tema visual del panel administrativo (SuperAdmin y administradores de sede).
//
// IMPORTANTE SOBRE LOS COLORES
// Los colores de marca (ink, gold, crimson) se midieron sobre los píxeles del
// logotipo que ya existe en lib/images/inder.png (escudo amarillo, corona roja,
// texto casi negro). NO provienen de un manual de identidad oficial: no se
// encontró uno público de INDER Valledupar. Son una propuesta provisional;
// si el INDER entrega su manual, basta con cambiar los valores de esta clase.
//
// Este tema NO reemplaza a AppTheme (lib/theme/app_tema.dart). Se aplica de
// forma local con InderThemeScope únicamente en las pantallas administrativas,
// por lo que las pantallas del cliente (login, sedes, reserva, pagos) no cambian.
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import '../utils/reserva_estado.dart';

class InderColors {
  InderColors._();

  // Marca (medidos sobre el logo del repositorio)
  static const Color ink = Color(0xFF0A1219);
  static const Color inkSoft = Color(0xFF1B2733);
  static const Color gold = Color(0xFFF9CB07);
  static const Color crimson = Color(0xFFCD0B08);

  // Variantes para texto/íconos dorados sobre fondo claro (contraste 6.2:1)
  static const Color goldDeep = Color(0xFF7A5C00);
  static const Color goldTint = Color(0xFFFFF6D6);

  // Neutros
  static const Color background = Color(0xFFF4F5F7);
  static const Color surface = Colors.white;
  static const Color border = Color(0xFFE3E6EB);
  static const Color borderStrong = Color(0xFF8A93A0); // bordes de campos (3:1)
  static const Color textPrimary = ink;
  static const Color textMuted = Color(0xFF5B6572); // 5.9:1 sobre blanco
  static const Color decor = Color(0xFF8A93A0); // solo decorativo, no texto

  // Estados de reserva: pendiente / pagado / cancelado
  // (son los únicos estados que existen hoy en ReservaEstado)
  static const Color pendiente = Color(0xFFB45309);
  static const Color pendienteSoft = Color(0xFFFEF3C7);
  static const Color pendienteOnSoft = Color(0xFF92400E);

  static const Color pagado = Color(0xFF15803D);
  static const Color pagadoSoft = Color(0xFFDCFCE7);
  static const Color pagadoOnSoft = Color(0xFF166534);

  static const Color cancelado = Color(0xFFB91C1C);
  static const Color canceladoSoft = Color(0xFFFEE2E2);
  static const Color canceladoOnSoft = Color(0xFF991B1B);
}

class InderSpace {
  InderSpace._();
  static const double xs = 4;
  static const double sm = 8;
  static const double md = 12;
  static const double lg = 16;
  static const double xl = 24;
  static const double xxl = 32;
}

class InderRadius {
  InderRadius._();
  static const double field = 12;
  static const double card = 16;
  static const double sheet = 24;
  static const double pill = 999;
}

/// Estilo visual de cada estado de reserva (solo presentación).
class InderEstadoStyle {
  final Color solid;
  final Color soft;
  final Color onSoft;
  final IconData icon;

  const InderEstadoStyle({
    required this.solid,
    required this.soft,
    required this.onSoft,
    required this.icon,
  });

  static InderEstadoStyle of(ReservaEstado estado) {
    switch (estado) {
      case ReservaEstado.pendiente:
        return const InderEstadoStyle(
          solid: InderColors.pendiente,
          soft: InderColors.pendienteSoft,
          onSoft: InderColors.pendienteOnSoft,
          icon: Icons.schedule_rounded,
        );
      case ReservaEstado.pagado:
        return const InderEstadoStyle(
          solid: InderColors.pagado,
          soft: InderColors.pagadoSoft,
          onSoft: InderColors.pagadoOnSoft,
          icon: Icons.check_circle_rounded,
        );
      case ReservaEstado.cancelado:
        return const InderEstadoStyle(
          solid: InderColors.cancelado,
          soft: InderColors.canceladoSoft,
          onSoft: InderColors.canceladoOnSoft,
          icon: Icons.cancel_rounded,
        );
    }
  }
}

class InderTheme {
  InderTheme._();

  static ThemeData? _cache;

  /// Se construye una sola vez: InderThemeScope se reconstruye con cada frame
  /// de las pantallas que se redibujan (p. ej. el cronómetro del dashboard).
  static ThemeData light() => _cache ??= _construir();

  static ThemeData _construir() {
    final scheme = ColorScheme.fromSeed(
      seedColor: InderColors.gold,
      brightness: Brightness.light,
    ).copyWith(
      primary: InderColors.ink,
      onPrimary: Colors.white,
      secondary: InderColors.gold,
      onSecondary: InderColors.ink,
      error: InderColors.crimson,
      onError: Colors.white,
      surface: InderColors.surface,
      onSurface: InderColors.ink,
      outline: InderColors.borderStrong,
      outlineVariant: InderColors.border,
    );

    final base = ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      scaffoldBackgroundColor: InderColors.background,
    );

    final text = GoogleFonts.poppinsTextTheme(base.textTheme).apply(
      bodyColor: InderColors.textPrimary,
      displayColor: InderColors.textPrimary,
    );

    final fieldBorder = OutlineInputBorder(
      borderRadius: BorderRadius.circular(InderRadius.field),
      borderSide: const BorderSide(color: InderColors.borderStrong),
    );

    return base.copyWith(
      textTheme: text,
      appBarTheme: AppBarTheme(
        backgroundColor: Colors.white,
        foregroundColor: InderColors.ink,
        elevation: 0,
        scrolledUnderElevation: 0,
        surfaceTintColor: Colors.transparent,
        centerTitle: false,
        iconTheme: const IconThemeData(color: InderColors.ink),
        actionsIconTheme: const IconThemeData(color: InderColors.ink),
        systemOverlayStyle: SystemUiOverlayStyle.dark,
        titleTextStyle: GoogleFonts.poppins(
          fontSize: 18,
          fontWeight: FontWeight.w700,
          color: InderColors.ink,
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: InderColors.ink,
          foregroundColor: Colors.white,
          disabledBackgroundColor: const Color(0xFFD5D9DF),
          disabledForegroundColor: InderColors.textMuted,
          elevation: 0,
          minimumSize: const Size(64, 48),
          padding: const EdgeInsets.symmetric(horizontal: 20),
          textStyle:
              GoogleFonts.poppins(fontSize: 14, fontWeight: FontWeight.w600),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(InderRadius.field),
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: InderColors.ink,
          minimumSize: const Size(64, 48),
          padding: const EdgeInsets.symmetric(horizontal: 20),
          side: const BorderSide(color: InderColors.borderStrong),
          textStyle:
              GoogleFonts.poppins(fontSize: 14, fontWeight: FontWeight.w600),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(InderRadius.field),
          ),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: InderColors.ink,
          minimumSize: const Size(48, 48),
          textStyle:
              GoogleFonts.poppins(fontSize: 14, fontWeight: FontWeight.w600),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(InderRadius.field),
          ),
        ),
      ),
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: InderColors.gold,
        foregroundColor: InderColors.ink,
        elevation: 2,
        highlightElevation: 4,
        extendedTextStyle:
            GoogleFonts.poppins(fontSize: 14, fontWeight: FontWeight.w700),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(InderRadius.card),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: Colors.white,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        labelStyle: GoogleFonts.poppins(
            fontSize: 14, color: InderColors.textMuted),
        hintStyle: GoogleFonts.poppins(
            fontSize: 14, color: InderColors.textMuted),
        helperStyle: GoogleFonts.poppins(
            fontSize: 12, color: InderColors.textMuted),
        errorStyle:
            GoogleFonts.poppins(fontSize: 12, color: InderColors.cancelado),
        prefixIconColor: InderColors.textMuted,
        suffixIconColor: InderColors.textMuted,
        border: fieldBorder,
        enabledBorder: fieldBorder,
        focusedBorder: fieldBorder.copyWith(
          borderSide: const BorderSide(color: InderColors.ink, width: 2),
        ),
        errorBorder: fieldBorder.copyWith(
          borderSide: const BorderSide(color: InderColors.cancelado),
        ),
        focusedErrorBorder: fieldBorder.copyWith(
          borderSide: const BorderSide(color: InderColors.cancelado, width: 2),
        ),
      ),
      dividerTheme: const DividerThemeData(
        color: InderColors.border,
        thickness: 1,
        space: 1,
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: InderColors.ink,
        contentTextStyle:
            GoogleFonts.poppins(fontSize: 14, color: Colors.white),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(InderRadius.field),
        ),
      ),
      bottomSheetTheme: const BottomSheetThemeData(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius:
              BorderRadius.vertical(top: Radius.circular(InderRadius.sheet)),
        ),
      ),
      progressIndicatorTheme: const ProgressIndicatorThemeData(
        color: InderColors.ink,
      ),
      drawerTheme: const DrawerThemeData(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.transparent,
      ),
    );
  }
}
