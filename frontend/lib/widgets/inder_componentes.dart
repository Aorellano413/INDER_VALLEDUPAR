// lib/widgets/inder_componentes.dart
//
// Componentes puramente visuales compartidos por las pantallas administrativas.
// No contienen lógica de negocio, no llaman a servicios ni a controladores.
import 'package:flutter/material.dart';
import '../models/user_modelo.dart';
import '../theme/inder_tema.dart';
import '../utils/reserva_estado.dart';

/// Aplica el tema institucional solo al subárbol administrativo.
class InderThemeScope extends StatelessWidget {
  final Widget child;
  const InderThemeScope({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    return Theme(data: InderTheme.light(), child: child);
  }
}

class InderLayout {
  InderLayout._();

  static const double maxContentWidth = 880;

  /// Margen horizontal: 16 en teléfonos; en tabletas centra el contenido.
  static double hPad(BuildContext context) {
    final w = MediaQuery.of(context).size.width;
    if (w > maxContentWidth + 32) return (w - maxContentWidth) / 2;
    return InderSpace.lg;
  }
}

String inderRolLabel(UserRole? rol) {
  switch (rol) {
    case UserRole.superAdmin:
      return 'Super administrador';
    case UserRole.propietario:
      return 'Administrador de sede';
    case null:
      return 'Administrador';
  }
}

/// AppBar institucional: fondo blanco, título con sobretítulo y línea dorada.
AppBar inderAppBar({
  required String title,
  String overline = 'INDER VALLEDUPAR',
  List<Widget>? actions,
  Widget? leading,
  bool automaticallyImplyLeading = true,
}) {
  return AppBar(
    automaticallyImplyLeading: automaticallyImplyLeading,
    leading: leading,
    actions: actions,
    titleSpacing: automaticallyImplyLeading || leading != null ? 0 : 16,
    title: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          overline,
          style: const TextStyle(
            fontSize: 10.5,
            fontWeight: FontWeight.w700,
            letterSpacing: 1.2,
            color: InderColors.goldDeep,
          ),
        ),
        Text(
          title,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w700,
            color: InderColors.ink,
            height: 1.2,
          ),
        ),
      ],
    ),
    bottom: const PreferredSize(
      preferredSize: Size.fromHeight(3),
      child: SizedBox(
        height: 3,
        width: double.infinity,
        child: ColoredBox(color: InderColors.gold),
      ),
    ),
  );
}

/// Tarjeta base: fondo blanco, borde fino y sombra muy sutil.
class InderCard extends StatelessWidget {
  final Widget child;
  final VoidCallback? onTap;
  final EdgeInsetsGeometry padding;

  const InderCard({
    super.key,
    required this.child,
    this.onTap,
    this.padding = const EdgeInsets.all(InderSpace.lg),
  });

  @override
  Widget build(BuildContext context) {
    final radius = BorderRadius.circular(InderRadius.card);
    return Container(
      decoration: BoxDecoration(
        color: InderColors.surface,
        borderRadius: radius,
        border: Border.all(color: InderColors.border),
        boxShadow: [
          BoxShadow(
            color: InderColors.ink.withOpacity(0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: radius,
          onTap: onTap,
          child: Padding(padding: padding, child: child),
        ),
      ),
    );
  }
}

/// Encabezado institucional: logotipo + nombre del panel + usuario conectado.
class InderHeaderBanner extends StatelessWidget {
  final String titulo;
  final String? subtitulo;
  final String? usuario;
  final String? detalleUsuario;

  const InderHeaderBanner({
    super.key,
    required this.titulo,
    this.subtitulo,
    this.usuario,
    this.detalleUsuario,
  });

  @override
  Widget build(BuildContext context) {
    final nombre = (usuario ?? '').trim();
    final inicial = nombre.isNotEmpty ? nombre[0].toUpperCase() : 'A';

    return InderCard(
      padding: EdgeInsets.zero,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 12),
            child: Row(
              children: [
                Image.asset(
                  'lib/images/inder.png',
                  height: 40,
                  fit: BoxFit.contain,
                  semanticLabel: 'Logotipo Alcaldía de Valledupar - INDER',
                  errorBuilder: (_, __, ___) => const SizedBox(height: 40),
                ),
              ],
            ),
          ),
          const Divider(),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                InderInitialAvatar(initial: inicial, size: 44),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        titulo,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          color: InderColors.ink,
                        ),
                      ),
                      if (subtitulo != null)
                        Text(
                          subtitulo!,
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
                if (detalleUsuario != null) ...[
                  const SizedBox(width: 8),
                  Flexible(
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 5),
                      decoration: BoxDecoration(
                        color: InderColors.goldTint,
                        borderRadius: BorderRadius.circular(InderRadius.pill),
                      ),
                      child: Text(
                        detalleUsuario!,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: InderColors.goldDeep,
                        ),
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class InderInitialAvatar extends StatelessWidget {
  final String initial;
  final double size;
  const InderInitialAvatar({super.key, required this.initial, this.size = 44});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: InderColors.inkSoft,
        borderRadius: BorderRadius.circular(size * 0.3),
      ),
      child: Text(
        initial,
        style: TextStyle(
          color: InderColors.gold,
          fontWeight: FontWeight.w700,
          fontSize: size * 0.4,
        ),
      ),
    );
  }
}

/// Insignia del estado de la reserva (color + ícono + texto, nunca solo color).
class InderEstadoBadge extends StatelessWidget {
  final ReservaEstado estado;
  final bool compact;

  const InderEstadoBadge({super.key, required this.estado, this.compact = false});

  @override
  Widget build(BuildContext context) {
    final style = InderEstadoStyle.of(estado);
    return Container(
      padding: EdgeInsets.symmetric(
          horizontal: compact ? 8 : 10, vertical: compact ? 4 : 5),
      decoration: BoxDecoration(
        color: style.soft,
        borderRadius: BorderRadius.circular(InderRadius.pill),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(style.icon, size: compact ? 12 : 14, color: style.onSoft),
          const SizedBox(width: 4),
          Text(
            estado.label,
            style: TextStyle(
              fontSize: compact ? 11 : 12,
              fontWeight: FontWeight.w700,
              color: style.onSoft,
            ),
          ),
        ],
      ),
    );
  }
}

class InderSectionTitle extends StatelessWidget {
  final String title;
  final String? subtitle;
  final Widget? trailing;

  const InderSectionTitle({
    super.key,
    required this.title,
    this.subtitle,
    this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: InderColors.ink,
                ),
              ),
              if (subtitle != null)
                Text(
                  subtitle!,
                  style: const TextStyle(
                    fontSize: 13,
                    color: InderColors.textMuted,
                  ),
                ),
            ],
          ),
        ),
        if (trailing != null) trailing!,
      ],
    );
  }
}

class InderEmptyState extends StatelessWidget {
  final IconData icon;
  final String title;
  final String? message;

  const InderEmptyState({
    super.key,
    required this.icon,
    required this.title,
    this.message,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 40),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 72,
              height: 72,
              decoration: const BoxDecoration(
                color: InderColors.goldTint,
                shape: BoxShape.circle,
              ),
              child: Icon(icon, size: 34, color: InderColors.goldDeep),
            ),
            const SizedBox(height: 16),
            Text(
              title,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: InderColors.ink,
              ),
            ),
            if (message != null) ...[
              const SizedBox(height: 6),
              Text(
                message!,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 13,
                  height: 1.4,
                  color: InderColors.textMuted,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class InderErrorState extends StatelessWidget {
  final String message;
  final VoidCallback? onRetry;

  const InderErrorState({super.key, required this.message, this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 72,
              height: 72,
              decoration: const BoxDecoration(
                color: InderColors.canceladoSoft,
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.cloud_off_rounded,
                  size: 34, color: InderColors.canceladoOnSoft),
            ),
            const SizedBox(height: 16),
            Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 14,
                height: 1.4,
                color: InderColors.textMuted,
              ),
            ),
            if (onRetry != null) ...[
              const SizedBox(height: 16),
              ElevatedButton.icon(
                onPressed: onRetry,
                icon: const Icon(Icons.refresh_rounded, size: 18),
                label: const Text('Reintentar'),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// Barra superior de las hojas inferiores (tirador + ícono + título).
class InderSheetHeader extends StatelessWidget {
  final IconData icon;
  final String title;
  final String? subtitle;

  const InderSheetHeader({
    super.key,
    required this.icon,
    required this.title,
    this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Center(
          child: Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: InderColors.border,
              borderRadius: BorderRadius.circular(InderRadius.pill),
            ),
          ),
        ),
        const SizedBox(height: 20),
        Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: InderColors.goldTint,
                borderRadius: BorderRadius.circular(InderRadius.field),
              ),
              child: Icon(icon, color: InderColors.goldDeep, size: 22),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      color: InderColors.ink,
                    ),
                  ),
                  if (subtitle != null)
                    Text(
                      subtitle!,
                      style: const TextStyle(
                        fontSize: 13,
                        color: InderColors.textMuted,
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ],
    );
  }
}

/// Zona para subir una imagen (sin imagen seleccionada todavía).
class InderImagePlaceholder extends StatelessWidget {
  final String title;
  const InderImagePlaceholder({super.key, required this.title});

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Container(
          width: 56,
          height: 56,
          decoration: const BoxDecoration(
            color: InderColors.goldTint,
            shape: BoxShape.circle,
          ),
          child: const Icon(Icons.add_photo_alternate_outlined,
              size: 26, color: InderColors.goldDeep),
        ),
        const SizedBox(height: 10),
        Text(
          title,
          style: const TextStyle(
            color: InderColors.ink,
            fontSize: 13,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 2),
        const Text(
          'Toca para seleccionar',
          style: TextStyle(color: InderColors.textMuted, fontSize: 12),
        ),
      ],
    );
  }
}

/// Miniatura de imagen (red o asset) con respaldo si falla o está vacía.
class InderThumb extends StatelessWidget {
  final String path;
  final double size;
  final IconData fallbackIcon;

  const InderThumb({
    super.key,
    required this.path,
    this.size = 56,
    this.fallbackIcon = Icons.image_outlined,
  });

  Widget _fallback() => Container(
        width: size,
        height: size,
        color: InderColors.goldTint,
        child: Icon(fallbackIcon, color: InderColors.goldDeep),
      );

  @override
  Widget build(BuildContext context) {
    Widget image;
    if (path.isEmpty) {
      image = _fallback();
    } else if (path.startsWith('http')) {
      image = Image.network(path,
          width: size,
          height: size,
          fit: BoxFit.cover,
          errorBuilder: (_, __, ___) => _fallback());
    } else {
      image = Image.asset(path,
          width: size,
          height: size,
          fit: BoxFit.cover,
          errorBuilder: (_, __, ___) => _fallback());
    }
    return ClipRRect(
      borderRadius: BorderRadius.circular(InderRadius.field),
      child: image,
    );
  }
}

/// Chip de filtro con área táctil cómoda y estado seleccionado claro.
class InderFilterChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const InderFilterChip({
    super.key,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      selected: selected,
      label: label,
      child: Material(
        color: selected ? InderColors.ink : Colors.white,
        shape: StadiumBorder(
          side: BorderSide(
            color: selected ? InderColors.ink : InderColors.borderStrong,
          ),
        ),
        child: InkWell(
          customBorder: const StadiumBorder(),
          onTap: onTap,
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 44),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 18),
              child: Center(
                widthFactor: 1,
                child: Text(
                  label,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                    color: selected ? Colors.white : InderColors.ink,
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Diálogo de confirmación. Devuelve true (confirmar) o false (cancelar),
/// igual que los AlertDialog originales.
class InderConfirmDialog extends StatelessWidget {
  final String title;
  final String message;
  final String confirmLabel;
  final IconData icon;

  const InderConfirmDialog({
    super.key,
    required this.title,
    required this.message,
    required this.confirmLabel,
    this.icon = Icons.warning_amber_rounded,
  });

  @override
  Widget build(BuildContext context) {
    return InderThemeScope(
      child: AlertDialog(
      backgroundColor: Colors.white,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(InderRadius.sheet),
      ),
      icon: Container(
        width: 56,
        height: 56,
        decoration: const BoxDecoration(
          color: InderColors.canceladoSoft,
          shape: BoxShape.circle,
        ),
        child: Icon(icon, color: InderColors.canceladoOnSoft, size: 28),
      ),
      title: Text(
        title,
        textAlign: TextAlign.center,
        style: const TextStyle(
          fontSize: 18,
          fontWeight: FontWeight.w700,
          color: InderColors.ink,
        ),
      ),
      content: Text(
        message,
        textAlign: TextAlign.center,
        style: const TextStyle(
          fontSize: 14,
          height: 1.4,
          color: InderColors.textMuted,
        ),
      ),
      actionsAlignment: MainAxisAlignment.center,
      actionsOverflowAlignment: OverflowBarAlignment.center,
      actions: [
        OutlinedButton(
          onPressed: () => Navigator.pop(context, false),
          child: const Text('Cancelar'),
        ),
        ElevatedButton(
          onPressed: () => Navigator.pop(context, true),
          style: ElevatedButton.styleFrom(
            backgroundColor: InderColors.cancelado,
            foregroundColor: Colors.white,
          ),
          child: Text(confirmLabel),
        ),
      ],
      ),
    );
  }
}
