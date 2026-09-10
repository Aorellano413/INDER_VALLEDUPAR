// lib/views/activar_2fa_view.dart
import 'dart:math';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:otp/otp.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../controllers/autenticacion_controlador..dart';
import '../routes/app_rutas.dart';

class Activar2FAView extends StatefulWidget {
  const Activar2FAView({super.key});

  @override
  State<Activar2FAView> createState() => _Activar2FAViewState();
}

class _Activar2FAViewState extends State<Activar2FAView> {
  final _formKey = GlobalKey<FormState>();
  final _phoneController = TextEditingController();
  final _codeController = TextEditingController();

  String? _secretKey;
  String? _qrData;
  List<String> _generatedBackupCodes = [];
  bool _qrGenerado = false;
  bool _isLoading = false;

  int _intentosFallidos = 0;
  final int _maximoIntentos = 3;

  @override
  void initState() {
    super.initState();
    _generarSecretKey();
    _generarBackupCodes();
  }

  void _generarSecretKey() {
    _secretKey = OTP.randomSecret();
  }

  void _generarBackupCodes() {
    final rand = Random.secure();
    const chars = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';
    _generatedBackupCodes = List.generate(8, (_) {
      return List.generate(8, (index) {
        if (index == 4) return '-';
        return chars[rand.nextInt(chars.length)];
      }).join();
    });
  }

  void _generarQR() {
    if (!_formKey.currentState!.validate() || _secretKey == null) return;

    final authController = Provider.of<AuthController>(context, listen: false);
    final user = authController.currentUser;
    final email = user?.email ?? 'usuario@inder.com';

    _qrData =
        'otpauth://totp/InderApp:$email?secret=$_secretKey&issuer=InderApp';

    setState(() {
      _qrGenerado = true;
    });
  }

  Future<void> _activarYVerificar() async {
    if (_intentosFallidos >= _maximoIntentos) {
      _mostrarMensaje('Límite de intentos alcanzado. Bloqueado temporalmente.', esError: true);
      return;
    }

    if (_codeController.text.trim().length < 6) {
      _mostrarMensaje('Ingrese un código válido de 6 dígitos', esError: true);
      return;
    }

    setState(() => _isLoading = true);
    final authController = Provider.of<AuthController>(context, listen: false);
    final user = authController.currentUser;

    if (user == null || user.id == null) {
      _mostrarMensaje('Error de sesión. Intente nuevamente.', esError: true);
      setState(() => _isLoading = false);
      return;
    }

    final now = DateTime.now().millisecondsSinceEpoch;
    final isCodeValid = OTP.generateTOTPCodeString(
          _secretKey!,
          now,
          interval: 30,
          algorithm: Algorithm.SHA1,
          isGoogle: true,
        ) ==
        _codeController.text.trim().toUpperCase();

    if (isCodeValid) {
      _intentosFallidos = 0;
      try {
        await FirebaseFirestore.instance
            .collection('usuarios')
            .doc(user.id)
            .update({
          'telefono': _phoneController.text.trim(),
          'totpSecret': _secretKey,
          'is2FAEnabled': true,
          'backupCodes': _generatedBackupCodes,
        });

        await authController.reloadUserData();

        if (!mounted) return;

        final updatedUser = authController.currentUser;
        if (updatedUser?.isSuperAdmin ?? false) {
          Navigator.pushNamedAndRemoveUntil(
              context, AppRoutes.adminDashboard, (route) => false);
        } else {
          Navigator.pushNamedAndRemoveUntil(
              context, AppRoutes.propietarioDashboard, (route) => false);
        }
      } catch (e) {
        _mostrarMensaje('Error al guardar en base de datos: $e', esError: true);
      }
    } else {
      _intentosFallidos++;
      int restantes = _maximoIntentos - _intentosFallidos;
      if (restantes > 0) {
        _mostrarMensaje('Código incorrecto. Intentos restantes: $restantes', esError: true);
      } else {
        _mostrarMensaje('Límite de 3 intentos alcanzado. Bloqueado temporalmente.', esError: true);
      }
    }

    if (mounted) setState(() => _isLoading = false);
  }

  void _copiarBackupCodes() {
    final text = _generatedBackupCodes.join('\n');
    Clipboard.setData(ClipboardData(text: text));
    _mostrarMensaje('Códigos de respaldo copiados al portapapeles',
        esError: false);
  }

  void _mostrarMensaje(String mensaje, {required bool esError}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(mensaje),
        backgroundColor: esError ? Colors.redAccent : Colors.green,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  void dispose() {
    _phoneController.dispose();
    _codeController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final bool isMobile = size.width < 700;

    return Scaffold(
      body: SafeArea(
        child: Stack(
          children: [
            Positioned.fill(
              child: Image.asset("lib/images/fondo.jpg", fit: BoxFit.cover),
            ),
            Positioned.fill(
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 6, sigmaY: 6),
                child: Container(color: Colors.black.withOpacity(0.45)),
              ),
            ),
            Center(
              child: SingleChildScrollView(
                padding:
                    const EdgeInsets.symmetric(horizontal: 24, vertical: 30),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 500),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(36),
                    child: BackdropFilter(
                      filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                      child: Container(
                        padding: EdgeInsets.all(isMobile ? 24 : 36),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(36),
                          border: Border.all(
                              color: Colors.white.withOpacity(0.2), width: 1.5),
                        ),
                        child: Form(
                          key: _formKey,
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                "Configurar 2FA",
                                style: GoogleFonts.poppins(
                                    fontSize: 24,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.white),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                !_qrGenerado
                                    ? "Ingrese su número telefónico para vincular la seguridad de su cuenta."
                                    : "Escanee el QR en Google Authenticator e ingrese el código de 6 dígitos.",
                                textAlign: TextAlign.center,
                                style: GoogleFonts.poppins(
                                    color: Colors.white.withOpacity(0.9),
                                    fontSize: 13),
                              ),
                              const SizedBox(height: 20),
                              if (!_qrGenerado) ...[
                                TextFormField(
                                  controller: _phoneController,
                                  keyboardType: TextInputType.phone,
                                  style: const TextStyle(color: Colors.white),
                                  decoration: InputDecoration(
                                    prefixIcon: const Icon(Icons.phone_android,
                                        color: Colors.white70),
                                    labelText: "Número telefónico",
                                    labelStyle: TextStyle(
                                        color: Colors.white.withOpacity(0.8)),
                                    filled: true,
                                    fillColor: Colors.white.withOpacity(0.1),
                                    enabledBorder: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(12),
                                        borderSide: BorderSide(
                                            color:
                                                Colors.white.withOpacity(0.3))),
                                    focusedBorder: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(12),
                                        borderSide: const BorderSide(
                                            color: Colors.white)),
                                  ),
                                  validator: (v) =>
                                      (v == null || v.trim().length < 7)
                                          ? 'Número no válido'
                                          : null,
                                ),
                                const SizedBox(height: 24),
                                SizedBox(
                                  width: double.infinity,
                                  child: ElevatedButton(
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: const Color(0xFF3546F0),
                                      foregroundColor: Colors.white,
                                      padding: const EdgeInsets.symmetric(
                                          vertical: 16),
                                      shape: RoundedRectangleBorder(
                                          borderRadius:
                                              BorderRadius.circular(30)),
                                    ),
                                    onPressed: _generarQR,
                                    child: Text("GENERAR CÓDIGO QR",
                                        style: GoogleFonts.poppins(
                                            fontWeight: FontWeight.bold)),
                                  ),
                                ),
                              ] else ...[
                                Container(
                                  padding: const EdgeInsets.all(12),
                                  decoration: BoxDecoration(
                                    color: Colors.white,
                                    borderRadius: BorderRadius.circular(16),
                                  ),
                                  child: QrImageView(
                                    data: _qrData!,
                                    version: QrVersions.auto,
                                    size: 180.0,
                                  ),
                                ),
                                const SizedBox(height: 16),
                                Container(
                                  padding: const EdgeInsets.all(12),
                                  decoration: BoxDecoration(
                                    color: Colors.black.withOpacity(0.3),
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(
                                        color: Colors.white.withOpacity(0.2)),
                                  ),
                                  child: Column(
                                    children: [
                                      Row(
                                        mainAxisAlignment:
                                            MainAxisAlignment.spaceBetween,
                                        children: [
                                          Text(
                                            "Códigos de respaldo (8 usos)",
                                            style: GoogleFonts.poppins(
                                                color: Colors.white,
                                                fontSize: 12,
                                                fontWeight: FontWeight.bold),
                                          ),
                                          IconButton(
                                            icon: const Icon(Icons.copy,
                                                color: Colors.white, size: 18),
                                            onPressed: _copiarBackupCodes,
                                            tooltip: "Copiar códigos",
                                          ),
                                        ],
                                      ),
                                      Wrap(
                                        spacing: 12,
                                        runSpacing: 4,
                                        children:
                                            _generatedBackupCodes.map((code) {
                                          return Text(
                                            code,
                                            style: GoogleFonts.robotoMono(
                                              color: Colors.amberAccent,
                                              fontSize: 11,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          );
                                        }).toList(),
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(height: 16),
                                TextFormField(
                                  controller: _codeController,
                                  keyboardType: TextInputType.text,
                                  textCapitalization:
                                      TextCapitalization.characters,
                                  style: const TextStyle(color: Colors.white),
                                  decoration: InputDecoration(
                                    prefixIcon: const Icon(Icons.security,
                                        color: Colors.white70),
                                    labelText:
                                        "Código de 6 dígitos del Authenticator",
                                    labelStyle: TextStyle(
                                        color: Colors.white.withOpacity(0.8)),
                                    filled: true,
                                    fillColor: Colors.white.withOpacity(0.1),
                                    enabledBorder: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(12),
                                        borderSide: BorderSide(
                                            color:
                                                Colors.white.withOpacity(0.3))),
                                    focusedBorder: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(12),
                                        borderSide: const BorderSide(
                                            color: Colors.white)),
                                  ),
                                ),
                                const SizedBox(height: 20),
                                SizedBox(
                                  width: double.infinity,
                                  child: ElevatedButton(
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: const Color(0xFF3546F0),
                                      foregroundColor: Colors.white,
                                      padding: const EdgeInsets.symmetric(
                                          vertical: 16),
                                      shape: RoundedRectangleBorder(
                                          borderRadius:
                                              BorderRadius.circular(30)),
                                    ),
                                    onPressed:
                                        (_isLoading || _intentosFallidos >= _maximoIntentos) ? null : _activarYVerificar,
                                    child: _isLoading
                                        ? const SizedBox(
                                            height: 20,
                                            width: 20,
                                            child: CircularProgressIndicator(
                                                color: Colors.white,
                                                strokeWidth: 2))
                                        : Text("ACTIVAR E INGRESAR",
                                            style: GoogleFonts.poppins(
                                                fontWeight: FontWeight.bold)),
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                      ),
                    ),
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