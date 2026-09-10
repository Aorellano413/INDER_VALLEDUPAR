import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../controllers/autenticacion_controlador..dart';
import '../routes/app_rutas.dart';

class LoginAdminView extends StatefulWidget {
  const LoginAdminView({super.key});

  @override
  State<LoginAdminView> createState() => _LoginAdminViewState();
}

class _LoginAdminViewState extends State<LoginAdminView> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passController = TextEditingController();
  final _2faController = TextEditingController();

  bool _showPassword = false;
  bool _isLoading = false;
  bool _requires2FA = false;

  @override
  void dispose() {
    _emailController.dispose();
    _passController.dispose();
    _2faController.dispose();
    super.dispose();
  }

  Future<void> _handleLogin() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isLoading = true);

    final authController = Provider.of<AuthController>(context, listen: false);

    if (!_requires2FA) {
      final resultado = await authController.login(
        email: _emailController.text.trim(),
        password: _passController.text.trim(),
      );

      if (!mounted) return;
      setState(() => _isLoading = false);

      if (resultado['success']) {
        final user = authController.currentUser;

        if (user != null && !user.is2FAEnabled) {
          Navigator.pushNamed(context, AppRoutes.activar2FA);
        } else {
          setState(() => _requires2FA = true);
        }
      } else {
        _mostrarError(resultado['message'] ?? 'Error al iniciar sesión');
      }
    } else {
      final resultado2FA = await authController.verify2FA(
        code: _2faController.text.trim(),
      );

      if (!mounted) return;
      setState(() => _isLoading = false);

      if (resultado2FA['success']) {
        _redireccionarUsuario(authController);
      } else {
        _mostrarError(resultado2FA['message'] ?? 'Código 2FA incorrecto');
      }
    }
  }

  void _redireccionarUsuario(AuthController auth) {
    final user = auth.currentUser;
    if (user == null) {
      _mostrarError('Error al obtener datos del usuario');
      return;
    }

    String ruta;
    if (user.isSuperAdmin) {
      ruta = AppRoutes.adminDashboard;
    } else if (user.isPropietario) {
      ruta = AppRoutes.propietarioDashboard;
    } else {
      _mostrarError('Rol de usuario no reconocido');
      return;
    }

    Navigator.pushReplacementNamed(context, ruta);
  }

  void _mostrarError(String mensaje) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(mensaje),
        backgroundColor: Colors.redAccent,
        behavior: SnackBarBehavior.floating,
      ),
    );
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
            Positioned(
              top: 16,
              left: 16,
              child: InkWell(
                onTap: () {
                  if (_requires2FA) {
                    setState(() => _requires2FA = false);
                  } else {
                    Navigator.pop(context);
                  }
                },
                borderRadius: BorderRadius.circular(40),
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.black.withOpacity(0.4),
                    border: Border.all(color: Colors.white.withOpacity(0.3), width: 1.5),
                  ),
                  child: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white, size: 20),
                ),
              ),
            ),
            Center(
              child: SingleChildScrollView(
                padding: EdgeInsets.symmetric(
                  horizontal: isMobile ? 24 : 50,
                  vertical: isMobile ? 40 : 60,
                ),
                child: ConstrainedBox(
                  constraints: BoxConstraints(maxWidth: isMobile ? 420 : 850),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(36),
                    child: BackdropFilter(
                      filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                      child: Container(
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(36),
                          border: Border.all(color: Colors.white.withOpacity(0.2), width: 1.5),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.3),
                              blurRadius: 30,
                              offset: const Offset(0, 15),
                            ),
                          ],
                        ),
                        child: isMobile
                            ? Padding(
                                padding: const EdgeInsets.all(30),
                                child: Column(
                                  children: [
                                    Image.asset('lib/images/inder.png', height: size.height * 0.22, fit: BoxFit.contain),
                                    const SizedBox(height: 20),
                                    _buildLoginForm(),
                                  ],
                                ),
                              )
                            : IntrinsicHeight(
                                child: Row(
                                  children: [
                                    Expanded(
                                      child: Padding(
                                        padding: const EdgeInsets.all(40),
                                        child: Image.asset('lib/images/inder.png', height: size.height * 0.45, fit: BoxFit.contain),
                                      ),
                                    ),
                                    Container(width: 1.5, color: Colors.white.withOpacity(0.2)),
                                    Expanded(
                                      child: Padding(
                                        padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 50),
                                        child: _buildLoginForm(),
                                      ),
                                    ),
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

  Widget _buildLoginForm() {
    return Form(
      key: _formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            _requires2FA ? "Verificación en dos pasos" : "Inicio de Sesión",
            style: GoogleFonts.poppins(fontSize: 26, fontWeight: FontWeight.bold, color: Colors.white),
          ),
          const SizedBox(height: 8),
          Text(
            _requires2FA
                ? "Ingrese el código de seguridad de 6 dígitos de su aplicación autenticadora."
                : "Ingrese su correo y contraseña de administrador",
            style: GoogleFonts.poppins(color: Colors.white.withOpacity(0.9), fontSize: 13),
          ),
          const SizedBox(height: 24),

          if (!_requires2FA) ...[
            _buildTextField(
              controller: _emailController,
              label: "Correo electrónico",
              icon: Icons.email_outlined,
              type: TextInputType.emailAddress,
              validator: (v) => (v == null || !v.contains('@')) ? 'Correo inválido' : null,
            ),
            const SizedBox(height: 16),
            _buildTextField(
              controller: _passController,
              label: "Contraseña",
              icon: Icons.lock_outline,
              isPassword: true,
              validator: (v) => (v == null || v.length < 6) ? 'Mínimo 6 caracteres' : null,
            ),
          ] else ...[
            _buildTextField(
              controller: _2faController,
              label: "Código de 6 dígitos",
              icon: Icons.security_rounded,
              type: TextInputType.number,
              validator: (v) => (v == null || v.trim().length < 6) ? 'Ingrese un código válido' : null,
            ),
          ],

          const SizedBox(height: 28),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF3546F0),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
                elevation: 8,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
              ),
              onPressed: _isLoading ? null : _handleLogin,
              child: _isLoading
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                    )
                  : Text(
                      _requires2FA ? "VERIFICAR CÓDIGO" : "CONTINUAR",
                      style: GoogleFonts.poppins(fontSize: 15, fontWeight: FontWeight.bold),
                    ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    TextInputType type = TextInputType.text,
    bool isPassword = false,
    String? Function(String?)? validator,
  }) {
    return TextFormField(
      controller: controller,
      keyboardType: type,
      obscureText: isPassword && !_showPassword,
      style: const TextStyle(color: Colors.white),
      decoration: InputDecoration(
        prefixIcon: Icon(icon, color: Colors.white70),
        labelText: label,
        labelStyle: TextStyle(color: Colors.white.withOpacity(0.8)),
        filled: true,
        fillColor: Colors.white.withOpacity(0.1),
        suffixIcon: isPassword
            ? IconButton(
                icon: Icon(_showPassword ? Icons.visibility_off_outlined : Icons.visibility_outlined, color: Colors.white70),
                onPressed: () => setState(() => _showPassword = !_showPassword),
              )
            : null,
        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Colors.white.withOpacity(0.3), width: 1.5)),
        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Colors.white, width: 2)),
        errorBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Colors.redAccent, width: 1.5)),
        focusedErrorBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Colors.redAccent, width: 2)),
      ),
      validator: validator,
    );
  }
}