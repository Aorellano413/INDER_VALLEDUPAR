// lib/widgets/reserva_item.dart
import 'package:flutter/material.dart';
import '../theme/inder_tema.dart';
import '../utils/reserva_estado.dart';
import 'inder_componentes.dart';

class ReservaItem extends StatelessWidget {
  final Map<String, dynamic> reserva;
  final VoidCallback onTap;

  const ReservaItem({
    super.key,
    required this.reserva,
    required this.onTap,
  });

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

    return InderCard(
      onTap: onTap,
      child: Row(
        children: [
          InderInitialAvatar(initial: inicial, size: 46),
          const SizedBox(width: 14),

          // Información central
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  nombre,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: InderColors.ink,
                  ),
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    const Icon(Icons.location_on_outlined,
                        size: 14, color: InderColors.textMuted),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Text(
                        sede,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 12.5,
                          color: InderColors.textMuted,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 2),
                Row(
                  children: [
                    const Icon(Icons.access_time_rounded,
                        size: 14, color: InderColors.textMuted),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Text(
                        fecha != null && fecha.isNotEmpty
                            ? '$fecha  •  $hora'
                            : '$hora',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 12.5,
                          color: InderColors.textMuted,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),

          // Estado + indicador de navegación
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              InderEstadoBadge(estado: estado, compact: true),
              const SizedBox(height: 8),
              const Icon(Icons.chevron_right_rounded,
                  size: 20, color: InderColors.decor),
            ],
          ),
        ],
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
