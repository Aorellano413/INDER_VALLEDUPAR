// lib/views/reserva_view.dart
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../controllers/reserva_controlador.dart';
import '../services/firestore_servicio.dart';
import '../routes/app_rutas.dart';

class ReservaView extends StatefulWidget {
  const ReservaView({super.key});

  @override
  State<ReservaView> createState() => _ReservaViewState();
}

class _ReservaViewState extends State<ReservaView> {
  bool _processing = false;
  bool _aceptoPoliticas = false;

  void _mostrarDialogoProcesando(String mensaje) {
    showDialog(
      context: context,
      barrierDismissible: false,
      useRootNavigator: true,
      builder: (_) => Dialog(
        backgroundColor: Colors.white,
        elevation: 0,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(width: 28, height: 28, child: CircularProgressIndicator(strokeWidth: 3)),
              const SizedBox(width: 16),
              Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Un momento…', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
                  const SizedBox(height: 4),
                  Text(mensaje, style: const TextStyle(fontSize: 13, color: Colors.black54)),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _procesarReserva(ReservaController controller) async {
    FocusScope.of(context).unfocus();

    if (!controller.formKey.currentState!.validate()) return;

    if (controller.fechaReserva == null) {
      _mostrarAlerta('Por favor seleccione una fecha', Colors.orange);
      return;
    }

    setState(() => _processing = true);
    _mostrarDialogoProcesando('Validando disponibilidad...');

    final resultado = await controller.confirmarReserva();

    if (mounted) Navigator.of(context, rootNavigator: true).pop();

    if (!resultado['success']) {
      if (mounted) {
        setState(() => _processing = false);
        _mostrarAlerta(resultado['message'], Colors.red);
      }
      return;
    }

    try {
      final firestore = FirestoreService();
      String canchaNombre = 'Sin cancha';
      String precio = '0';

      if (controller.canchaIdSeleccionada != null) {
        final canchas = await firestore.getCanchasPorSede(controller.sedeIdSeleccionada ?? '');
        final cancha = canchas.firstWhere((c) => c.id == controller.canchaIdSeleccionada, orElse: () => canchas.first);
        canchaNombre = cancha.title;
        precio = cancha.price.replaceAll(RegExp(r'[^0-9]'), '');
      }

      String sedeNombre = 'Sin sede';
      if (controller.sedeIdSeleccionada != null) {
        final sedes = await firestore.getSedes();
        final sede = sedes.firstWhere((s) => s.id == controller.sedeIdSeleccionada, orElse: () => sedes.first);
        sedeNombre = sede.title;
      }

      if (!mounted) return;
      _mostrarAlerta(resultado['message'], Colors.green);

      final sedeDoc = await FirebaseFirestore.instance.collection('sedes').doc(controller.sedeIdSeleccionada).get();
      final telefonoPropietario = sedeDoc.data()?['contactoPropietario'] ?? '';

      final datosReserva = {
        'nombreCompleto': controller.nombreController.text.trim(),
        'correoElectronico': controller.correoController.text.trim(),
        'numeroCelular': controller.celularController.text.trim(),
        'fechaReserva': controller.fechaReserva,
        'horaReserva': controller.horaSeleccionada,
        'sedeNombre': sedeNombre,
        'canchaNombre': canchaNombre,
        'precio': precio,
        'whatsappPropietario': telefonoPropietario,
        'aceptoPoliticas': true,
      };

      setState(() => _processing = false);
      if (mounted) {
        Navigator.pushNamed(context, AppRoutes.pagos, arguments: datosReserva)
            .then((_) => controller.limpiarCamposFormulario());
      }
    } catch (e) {
      if (mounted) {
        setState(() => _processing = false);
        _mostrarAlerta('Error al cargar detalles: $e', Colors.orange);
      }
    }
  }

  void _mostrarPoliticasPrivacidad() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(
          'Política de Tratamiento de Datos - INDER Valledupar',
          style: GoogleFonts.poppins(fontWeight: FontWeight.bold, fontSize: 18),
        ),
        content: SizedBox(
          width: MediaQuery.of(context).size.width * 0.8,
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildSectionTitle('1. Datos que recolectamos'),
                const SizedBox(height: 4),
                Text('Para brindarle una gestión segura y transparente en la reserva de escenarios deportivos, recolectamos:', style: GoogleFonts.poppins(fontSize: 12.5, color: Colors.black87)),
                const SizedBox(height: 4),
                _buildBulletPoint('Datos de identificación: ', 'nombre completo y número de cédula/documento de identidad.'),
                _buildBulletPoint('Datos de contacto: ', 'correo electrónico y número de teléfono celular.'),
                _buildBulletPoint('Datos de reserva: ', 'fecha, hora, sede y escenario deportivo seleccionado.'),
                _buildBulletPoint('Datos técnicos: ', 'dirección IP, tipo de dispositivo y navegador al interactuar con la plataforma.'),
                const SizedBox(height: 12),

                _buildSectionTitle('2. Cómo usamos sus datos'),
                const SizedBox(height: 4),
                Text('Tratamos sus datos personales con las siguientes finalidades institucionales:', style: GoogleFonts.poppins(fontSize: 12.5, color: Colors.black87)),
                const SizedBox(height: 4),
                _buildBulletPoint('', 'Procesar, confirmar y administrar las reservas de los escenarios deportivos del municipio.'),
                _buildBulletPoint('', 'Coordinar la logística, control de accesos y seguridad con los administradores de cada sede.'),
                _buildBulletPoint('', 'Enviarle comunicaciones operativas sobre el estado de su reserva (confirmaciones, modificaciones o cancelaciones).'),
                _buildBulletPoint('', 'Cumplir con obligaciones legales, contables y de control fiscal en Colombia.'),
                _buildBulletPoint('', 'Prevenir fraudes y garantizar el uso adecuado de los bienes públicos.'),
                const SizedBox(height: 12),

                _buildSectionTitle('3. Con quién compartimos sus datos'),
                const SizedBox(height: 4),
                Text('El INDER Valledupar no comercializa datos personales. La información solo podrá ser compartida, bajo estrictos fines legítimos, con:', style: GoogleFonts.poppins(fontSize: 12.5, color: Colors.black87)),
                const SizedBox(height: 4),
                _buildBulletPoint('Administradores y gestores de sedes: ', 'únicamente los datos mínimos necesarios para validar su ingreso al escenario.'),
                _buildBulletPoint('Proveedores tecnológicos: ', 'servicios de alojamiento en la nube (hosting y bases de datos) bajo contratos de confidencialidad y seguridad.'),
                _buildBulletPoint('Autoridades competentes: ', 'cuando exista un requerimiento legal, judicial o administrativo.'),
                const SizedBox(height: 12),

                _buildSectionTitle('4. Seguridad de la información'),
                const SizedBox(height: 4),
                Text('Implementamos medidas técnicas y organizativas para proteger su información:', style: GoogleFonts.poppins(fontSize: 12.5, color: Colors.black87)),
                const SizedBox(height: 4),
                _buildBulletPoint('Cifrado en tránsito: ', '(HTTPS/TLS) y en reposo en las bases de datos.'),
                _buildBulletPoint('Control de acceso: ', 'estricto para funcionarios bajo el principio de mínimo privilegio.'),
                _buildBulletPoint('Auditoría y respaldos: ', 'registros de auditoría y copias de seguridad periódicas.'),
                const SizedBox(height: 12),

                _buildSectionTitle('5. Sus derechos (Ley 1581 de 2012)'),
                const SizedBox(height: 4),
                Text('Como ciudadano, usted tiene derecho a:', style: GoogleFonts.poppins(fontSize: 12.5, color: Colors.black87)),
                const SizedBox(height: 4),
                _buildBulletPoint('', 'Conocer, actualizar y rectificar sus datos personales.'),
                _buildBulletPoint('', 'Solicitar prueba de la autorización otorgada.'),
                _buildBulletPoint('', 'Revocar la autorización y/o solicitar la supresión de sus datos.'),
                _buildBulletPoint('', 'Presentar quejas ante la Superintendencia de Industria y Comercio (SIC).'),
                const SizedBox(height: 12),

                _buildSectionTitle('6. Cómo ejercer sus derechos'),
                _buildSectionBody(
                  'Para peticiones, consultas o reclamos, puede escribirnos al correo oficial del INDER Valledupar indicando su nombre, documento y solicitud. Las consultas se atienden en un plazo máximo de diez (10) días hábiles y los reclamos en máximo quince (15) días hábiles conforme a la ley.',
                ),
                const SizedBox(height: 12),

                _buildSectionTitle('7. Responsable del tratamiento'),
                _buildSectionBody(
                  'INSTITUTO MUNICIPAL DE DEPORTE Y RECREACIÓN — INDER VALLEDUPAR.\n'
                  'Dirección: Cl. 28 #13-28, Valledupar, Cesar, Colombia.\n'
                  'Correo institucional: sistemas@indervalledupar.gov.co',
                ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Entendido', style: GoogleFonts.poppins(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Text(
      title,
      style: GoogleFonts.poppins(fontWeight: FontWeight.bold, fontSize: 14, color: Colors.blueAccent),
    );
  }

  Widget _buildSectionBody(String body) {
    return Text(
      body,
      style: GoogleFonts.poppins(fontSize: 12.5, color: Colors.black87),
    );
  }

  Widget _buildBulletPoint(String boldPrefix, String text) {
    return Padding(
      padding: const EdgeInsets.only(left: 8, bottom: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('• ', style: GoogleFonts.poppins(fontSize: 12.5, color: Colors.black87, fontWeight: FontWeight.bold)),
          Expanded(
            child: RichText(
              text: TextSpan(
                style: GoogleFonts.poppins(fontSize: 12.5, color: Colors.black87),
                children: [
                  if (boldPrefix.isNotEmpty)
                    TextSpan(
                      text: boldPrefix,
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                  TextSpan(text: text),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _mostrarAlerta(String mensaje, Color color) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(mensaje, style: GoogleFonts.poppins()),
        backgroundColor: color,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  Future<List<Map<String, dynamic>>> _obtenerHorasConEstado(ReservaController controller) async {
    List<String> slots = [];
    if (controller.canchaIdSeleccionada != null && controller.sedeIdSeleccionada != null) {
      final canchas = await FirestoreService().getCanchasPorSede(controller.sedeIdSeleccionada!);
      final cancha = canchas.firstWhere((c) => c.id == controller.canchaIdSeleccionada, orElse: () => canchas.first);
      slots = controller.generarSlots(cancha.horario);
    }

    if (slots.isEmpty || controller.fechaReserva == null) {
      return slots.map((h) => {'hora': h, 'ocupada': false}).toList();
    }

    List<Map<String, dynamic>> resultado = [];
    for (var hora in slots) {
      final disponible = await FirestoreService().verificarDisponibilidad(
        canchaId: controller.canchaIdSeleccionada!,
        fecha: controller.fechaReserva!,
        horaReserva: hora,
      );
      resultado.add({'hora': hora, 'ocupada': !disponible});
    }
    return resultado;
  }

  @override
  Widget build(BuildContext context) {
    final controller = Provider.of<ReservaController>(context);

    return Scaffold(
      body: Stack(
        children: [
          Positioned.fill(child: Image.asset("lib/images/fondo.jpg", fit: BoxFit.cover)),
          Positioned.fill(child: BackdropFilter(filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8), child: Container(color: Colors.black.withOpacity(0.5)))),
          SafeArea(
            child: CustomScrollView(
              slivers: [
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Row(
                      children: [
                        IconButton(onPressed: () => Navigator.pop(context), icon: const Icon(Icons.arrow_back_ios_new, color: Colors.white)),
                        const SizedBox(width: 8),
                        Text('Reserva de Cancha', style: GoogleFonts.poppins(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.white)),
                        const Spacer(),
                        IconButton(
                          icon: const Icon(Icons.refresh, color: Colors.white),
                          onPressed: () {
                            controller.limpiarCamposFormulario();
                            _mostrarAlerta('Campos limpiados', Colors.white24);
                          },
                        ),
                      ],
                    ),
                  ),
                ),
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(24),
                      child: BackdropFilter(
                        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                        child: Container(
                          padding: const EdgeInsets.all(24),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.15),
                            borderRadius: BorderRadius.circular(24),
                            border: Border.all(color: Colors.white.withOpacity(0.2), width: 1.5),
                          ),
                          child: Form(
                            key: controller.formKey,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                _buildTextField(controller.nombreController, 'Nombre completo', Icons.person, 20, validator: (v) {
                                  if (v == null || v.trim().isEmpty) return 'Ingrese su nombre';
                                  if (v.trim().length < 2) return 'Mínimo 2 caracteres';
                                  return null;
                                }),
                                const SizedBox(height: 16),
                                _buildTextField(controller.correoController, 'Correo electrónico', Icons.email, null, keyboardType: TextInputType.emailAddress, validator: (v) {
                                  if (v == null || !v.contains('@')) return 'Ingrese un correo válido';
                                  return null;
                                }),
                                const SizedBox(height: 16),
                                _buildTextField(controller.celularController, 'Número de celular', Icons.phone, 10, keyboardType: TextInputType.phone, inputFormatters: [FilteringTextInputFormatter.digitsOnly], validator: (v) {
                                  if (v == null || v.length != 10) return 'Debe tener 10 dígitos';
                                  return null;
                                }),
                                const SizedBox(height: 16),
                                InkWell(
                                  onTap: () async {
                                    final fecha = await showDatePicker(
                                      context: context,
                                      initialDate: DateTime.now(),
                                      firstDate: DateTime.now(),
                                      lastDate: DateTime.now().add(const Duration(days: 365)),
                                    );
                                    if (fecha != null) controller.setFechaReserva(fecha);
                                  },
                                  child: Container(
                                    padding: const EdgeInsets.all(16),
                                    decoration: BoxDecoration(
                                      color: Colors.white.withOpacity(0.15),
                                      borderRadius: BorderRadius.circular(16),
                                      border: Border.all(color: Colors.white.withOpacity(0.3)),
                                    ),
                                    child: Row(
                                      children: [
                                        const Icon(Icons.calendar_today, color: Colors.white70),
                                        const SizedBox(width: 12),
                                        Text(
                                          controller.fechaReserva == null
                                              ? "Seleccione una fecha"
                                              : "Fecha: ${controller.fechaReserva!.day}/${controller.fechaReserva!.month}/${controller.fechaReserva!.year}",
                                          style: GoogleFonts.poppins(color: Colors.white, fontSize: 15),
                                        ),
                                        const Spacer(),
                                        const Icon(Icons.arrow_forward_ios, size: 16, color: Colors.white70),
                                      ],
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 16),
                                FutureBuilder<List<Map<String, dynamic>>>(
                                  future: _obtenerHorasConEstado(controller),
                                  builder: (context, snapshot) {
                                    if (snapshot.connectionState == ConnectionState.waiting) {
                                      return const Center(child: CircularProgressIndicator(color: Colors.white70));
                                    }
                                    final horasConEstado = snapshot.data ?? [];
                                    return DropdownButtonFormField<String>(
                                      value: controller.horaSeleccionada,
                                      dropdownColor: const Color(0xFF1A1A2E),
                                      style: GoogleFonts.poppins(color: Colors.white, fontSize: 15),
                                      decoration: _inputDecoration("Hora de reserva", Icons.access_time),
                                      items: horasConEstado.map((h) {
                                        final hora = h['hora'] as String;
                                        final ocupada = h['ocupada'] as bool;
                                        return DropdownMenuItem<String>(
                                          value: hora,
                                          enabled: !ocupada,
                                          child: Text(
                                            hora,
                                            style: GoogleFonts.poppins(
                                              color: ocupada ? Colors.red : Colors.white,
                                              fontWeight: ocupada ? FontWeight.bold : FontWeight.normal,
                                              decoration: ocupada ? TextDecoration.lineThrough : null,
                                            ),
                                          ),
                                        );
                                      }).toList(),
                                      onChanged: (val) => controller.setHoraSeleccionada(val),
                                      validator: (val) => val == null ? 'Seleccione una hora' : null,
                                    );
                                  },
                                ),
                                const SizedBox(height: 20),

                                Theme(
                                  data: ThemeData(unselectedWidgetColor: Colors.white70),
                                  child: CheckboxListTile(
                                    title: Wrap(
                                      crossAxisAlignment: WrapCrossAlignment.center,
                                      children: [
                                        Text('He leído y autorizo el tratamiento de mis datos personales conforme a la ',
                                            style: GoogleFonts.poppins(color: Colors.white70, fontSize: 13)),
                                        InkWell(
                                          onTap: _mostrarPoliticasPrivacidad,
                                          child: Text(
                                            'Política de Privacidad',
                                            style: GoogleFonts.poppins(
                                              color: Colors.cyanAccent,
                                              fontSize: 13,
                                              decoration: TextDecoration.underline,
                                              fontWeight: FontWeight.w600,
                                            ),
                                          ),
                                        ),
                                        Text('.', style: GoogleFonts.poppins(color: Colors.white70, fontSize: 13)),
                                      ],
                                    ),
                                    value: _aceptoPoliticas,
                                    onChanged: (valor) {
                                      setState(() {
                                        _aceptoPoliticas = valor ?? false;
                                      });
                                    },
                                    controlAffinity: ListTileControlAffinity.leading,
                                    contentPadding: EdgeInsets.zero,
                                    activeColor: Colors.cyanAccent,
                                    checkColor: Colors.black,
                                  ),
                                ),
                                const SizedBox(height: 16),

                                SizedBox(
                                  height: 54,
                                  child: ElevatedButton(
                                    onPressed: (_processing || !_aceptoPoliticas) ? null : () => _procesarReserva(controller),
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: const Color.fromARGB(204, 12, 15, 172),
                                      disabledBackgroundColor: Colors.grey.withOpacity(0.3),
                                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                                    ),
                                    child: _processing
                                        ? const CircularProgressIndicator(color: Colors.white)
                                        : Text("Confirmar reserva", style: GoogleFonts.poppins(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white)),
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
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTextField(TextEditingController ctrl, String label, IconData icon, int? maxLength, {TextInputType? keyboardType, List<TextInputFormatter>? inputFormatters, String? Function(String?)? validator}) {
    return TextFormField(
      controller: ctrl,
      maxLength: maxLength,
      keyboardType: keyboardType,
      inputFormatters: inputFormatters,
      validator: validator,
      style: GoogleFonts.poppins(color: Colors.white, fontSize: 15),
      decoration: _inputDecoration(label, icon),
    );
  }

  InputDecoration _inputDecoration(String label, IconData icon) {
    return InputDecoration(
      labelText: label,
      labelStyle: GoogleFonts.poppins(color: Colors.white70),
      filled: true,
      fillColor: Colors.white.withOpacity(0.15),
      prefixIcon: Icon(icon, color: Colors.white70),
      counterText: '',
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide(color: Colors.white.withOpacity(0.3))),
      focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide(color: Colors.white.withOpacity(0.5))),
    );
  }
}