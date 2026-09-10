// lib/widgets/reserva_detalle_sheet.dart
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../services/firestore_servicio.dart';
import '../utils/reserva_estado.dart';

const _kPrimary = Color(0xFF101B2E);

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

    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom + 24,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Handle
          const SizedBox(height: 12),
          Container(
            width: 40, height: 4,
            decoration: BoxDecoration(
              color: Colors.black12,
              borderRadius: BorderRadius.circular(8),
            ),
          ),
          const SizedBox(height: 20),

          // Header con avatar y nombre
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Row(
              children: [
                Container(
                  width: 52, height: 52,
                  decoration: BoxDecoration(
                    color: _kPrimary,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    inicial,
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 22,
                    ),
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        nombre,
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                          color: _kPrimary,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        reserva['correoElectronico'] ?? 'Sin correo',
                        style: TextStyle(fontSize: 13, color: Colors.grey.shade500),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: estado.color.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    estado.label,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: estado.color,
                    ),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 20),
          const Divider(height: 1, indent: 20, endIndent: 20),
          const SizedBox(height: 16),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Column(
              children: [
                Row(
                  children: [
                    _infoCard(Icons.phone_android_outlined, 'Teléfono',
                        reserva['numeroCelular'] ?? 'Sin teléfono'),
                    const SizedBox(width: 10),
                    _infoCard(Icons.location_on_outlined, 'Sede', sede),
                  ],
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    _infoCard(Icons.calendar_today_outlined, 'Fecha', fechaTexto),
                    const SizedBox(width: 10),
                    _infoCard(Icons.access_time_rounded, 'Hora',
                        reserva['horaReserva'] ?? 'Sin hora'),
                  ],
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    _infoCard(Icons.sports_soccer_outlined, 'Cancha', cancha),
                    const SizedBox(width: 10),
                    _infoCard(Icons.attach_money_rounded, 'Monto', precio),
                  ],
                ),
              ],
            ),
          ),

          const SizedBox(height: 24),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    icon: const Icon(Icons.check_circle_outline, size: 18),
                    label: const Text('Marcar Pagado',
                        style: TextStyle(fontWeight: FontWeight.w700)),
                    onPressed: () => _actualizarEstado(
                        context, 'pagado', 'Reserva marcada como PAGADO'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF1B5E20),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
                      elevation: 0,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: OutlinedButton.icon(
                    icon: const Icon(Icons.cancel_outlined, size: 18),
                    label: const Text('Cancelar',
                        style: TextStyle(fontWeight: FontWeight.w700)),
                    onPressed: () => _actualizarEstado(
                        context, 'cancelado', 'Reserva CANCELADA'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: const Color(0xFFC62828),
                      side: const BorderSide(color: Color(0xFFC62828)),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 8),
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Cerrar', style: TextStyle(color: Colors.grey.shade500)),
          ),
        ],
      ),
    );
  }

  Widget _infoCard(IconData icon, String label, String value) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: const Color(0xFFF5F7FA),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            Icon(icon, size: 18, color: _kPrimary),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(label,
                      style: TextStyle(
                          fontSize: 11,
                          color: Colors.grey.shade500,
                          fontWeight: FontWeight.w500)),
                  const SizedBox(height: 2),
                  Text(value,
                      style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: _kPrimary),
                      overflow: TextOverflow.ellipsis),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}