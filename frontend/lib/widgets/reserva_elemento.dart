// lib/widgets/reserva_item.dart
import 'package:flutter/material.dart';
import '../utils/reserva_estado.dart';

class ReservaItem extends StatelessWidget {
  final Map<String, dynamic> reserva;
  final VoidCallback onTap;

  const ReservaItem({
    super.key,
    required this.reserva,
    required this.onTap,
  });

  Color _avatarColor(String inicial) {
    final colors = [
      const Color(0xFF1A6B4A),
      const Color(0xFF0D5C8F),
      const Color(0xFF7B3FA0),
      const Color(0xFFC0392B),
      const Color(0xFF16A085),
      const Color(0xFF8E44AD),
      const Color(0xFF2980B9),
      const Color(0xFFD35400),
    ];
    return colors[inicial.codeUnitAt(0) % colors.length];
  }

  @override
  Widget build(BuildContext context) {
    final nombre = reserva['nombreCompleto'] ?? 'Sin nombre';
    final inicial = (nombre.isNotEmpty ? nombre.trim()[0] : '?').toUpperCase();
    final estado = ReservaEstadoHelper.desdeString(reserva['estado'] ?? 'pendiente');
    final sede = reserva['sede'] != null
        ? reserva['sede']['title'] ?? 'Sin sede'
        : 'Sin sede';
    final hora = reserva['horaReserva'] ?? 'Sin hora';
    final fecha = reserva['fechaReserva'] != null
        ? _formatFecha(reserva['fechaReserva'])
        : null;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 10,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Container(
                width: 46,
                height: 46,
                decoration: BoxDecoration(
                  color: _avatarColor(inicial),
                  borderRadius: BorderRadius.circular(14),
                ),
                alignment: Alignment.center,
                child: Text(
                  inicial,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 18,
                  ),
                ),
              ),
              const SizedBox(width: 14),

              // Info central
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      nombre,
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF101B2E),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        const Icon(Icons.location_on_outlined, size: 13, color: Color(0xFF888FAA)),
                        const SizedBox(width: 3),
                        Expanded(
                          child: Text(
                            sede,
                            style: const TextStyle(
                              fontSize: 12,
                              color: Color(0xFF888FAA),
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 2),
                    Row(
                      children: [
                        const Icon(Icons.access_time_rounded, size: 13, color: Color(0xFF888FAA)),
                        const SizedBox(width: 3),
                        Text(
                          fecha != null ? '$fecha  •  $hora' : hora,
                          style: const TextStyle(
                            fontSize: 12,
                            color: Color(0xFF888FAA),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 10),

              // Badge de estado
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(
                      color: estado.color.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      estado.label,
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: estado.color,
                        letterSpacing: 0.3,
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Icon(Icons.chevron_right_rounded, size: 18, color: Color(0xFFCCCFDA)),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _formatFecha(dynamic fechaRaw) {
    try {
      DateTime fecha;
      if (fechaRaw is DateTime) {
        fecha = fechaRaw;
      } else if (fechaRaw.runtimeType.toString().contains('Timestamp')) {
        fecha = fechaRaw.toDate();
      } else {
        return '';
      }
      return '${fecha.day.toString().padLeft(2, '0')}/${fecha.month.toString().padLeft(2, '0')}';
    } catch (_) {
      return '';
    }
  }
}