// lib/widgets/reserva_detalle_sheet.dart
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../services/firestore_servicio.dart';
import '../theme/inder_tema.dart';
import '../utils/reserva_estado.dart';
import 'inder_componentes.dart';

class ReservaDetalleSheet extends StatelessWidget {
  final Map<String, dynamic> reserva;
  final VoidCallback onEstadoActualizado;

  const ReservaDetalleSheet({
    super.key,
    required this.reserva,
    required this.onEstadoActualizado,
  });

  Future<void> _actualizarEstado(
    BuildContext context,
    String nuevoEstado,
    String mensaje,
  ) async {
    final reservaId = reserva['id'];
    if (reservaId == null) return;

    try {
      await FirestoreService().actualizarEstadoReserva(reservaId, nuevoEstado);
      onEstadoActualizado();
      if (context.mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(mensaje), behavior: SnackBarBehavior.floating),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $e'),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  String _formatFecha(dynamic raw) {
    if (raw == null) return 'Sin fecha';
    DateTime fecha;
    if (raw is Timestamp) {
      fecha = raw.toDate();
    } else if (raw is DateTime) {
      fecha = raw;
    } else if (raw is String) {
      fecha = DateTime.tryParse(raw) ?? DateTime.now();
    } else {
      return 'Sin fecha';
    }
    return DateFormat('dd/MM/yyyy').format(fecha);
  }

  @override
  Widget build(BuildContext context) {
    final estado = ReservaEstadoHelper.desdeString(reserva['estado'] ?? 'pendiente');
    final sede = reserva['sede']?['title'] ?? 'Sin sede';
    final cancha = reserva['cancha']?['title'] ?? 'Sin cancha';
    final precio = reserva['cancha']?['price'] ?? '\$0';
    final nombre = reserva['nombreCompleto'] ?? 'Sin nombre';
    final inicial = (nombre.isNotEmpty ? nombre.trim()[0] : '?').toUpperCase();
    final fechaTexto = _formatFecha(reserva['fechaReserva']);

    return InderThemeScope(
      child: Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius:
              BorderRadius.vertical(top: Radius.circular(InderRadius.sheet)),
        ),
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom,
        ),
        child: SafeArea(
          top: false,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Tirador
                const SizedBox(height: 12),
                Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: InderColors.border,
                    borderRadius: BorderRadius.circular(InderRadius.pill),
                  ),
                ),
                const SizedBox(height: 20),

                // Cabecera: avatar, nombre, correo y estado
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Row(
                    children: [
                      InderInitialAvatar(initial: inicial, size: 52),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              nombre,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.w700,
                                color: InderColors.ink,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              reserva['correoElectronico'] ?? 'Sin correo',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontSize: 13,
                                color: InderColors.textMuted,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      InderEstadoBadge(estado: estado),
                    ],
                  ),
                ),

                const SizedBox(height: 20),
                const Divider(height: 1, indent: 20, endIndent: 20),
                const SizedBox(height: 16),

                // Datos de la reserva
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Column(
                    children: [
                      _infoRow(
                        _infoCard(Icons.phone_android_outlined, 'Teléfono',
                            reserva['numeroCelular'] ?? 'Sin teléfono'),
                        _infoCard(Icons.location_on_outlined, 'Sede', sede),
                      ),
                      const SizedBox(height: 10),
                      _infoRow(
                        _infoCard(
                            Icons.calendar_today_outlined, 'Fecha', fechaTexto),
                        _infoCard(Icons.access_time_rounded, 'Hora',
                            reserva['horaReserva'] ?? 'Sin hora'),
                      ),
                      const SizedBox(height: 10),
                      _infoRow(
                        _infoCard(
                            Icons.sports_soccer_outlined, 'Cancha', cancha),
                        _infoCard(Icons.payments_outlined, 'Monto', precio),
                      ),
                    ],
                  ),
                ),

                // Acciones
                const SizedBox(height: 24),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Row(
                    children: [
                      Expanded(
                        child: ElevatedButton.icon(
                          icon: const Icon(Icons.check_circle_outline,
                              size: 18),
                          label: const Text('Marcar Pagado'),
                          onPressed: () => _actualizarEstado(
                              context, 'pagado', 'Reserva marcada como PAGADO'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: InderColors.pagado,
                            foregroundColor: Colors.white,
                            minimumSize: const Size(64, 52),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: OutlinedButton.icon(
                          icon: const Icon(Icons.cancel_outlined, size: 18),
                          label: const Text('Cancelar'),
                          onPressed: () => _actualizarEstado(
                              context, 'cancelado', 'Reserva CANCELADA'),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: InderColors.canceladoOnSoft,
                            side: const BorderSide(
                                color: InderColors.cancelado, width: 1.2),
                            minimumSize: const Size(64, 52),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 8),
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Cerrar',
                      style: TextStyle(color: InderColors.textMuted)),
                ),
                const SizedBox(height: 12),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // IntrinsicHeight: iguala la altura de las dos tarjetas sin exigir altura acotada.
  Widget _infoRow(Widget izquierda, Widget derecha) {
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [izquierda, const SizedBox(width: 10), derecha],
      ),
    );
  }

  Widget _infoCard(IconData icon, String label, String value) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: InderColors.background,
          borderRadius: BorderRadius.circular(InderRadius.field),
        ),
        child: Row(
          children: [
            Icon(icon, size: 18, color: InderColors.goldDeep),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: const TextStyle(
                      fontSize: 11.5,
                      color: InderColors.textMuted,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    value,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: InderColors.ink,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
