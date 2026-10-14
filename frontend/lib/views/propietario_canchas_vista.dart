// lib/views/propietario_canchas_view.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../controllers/autenticacion_controlador.dart';
import '../controllers/canchas_controlador.dart';
import '../models/cancha_modelo.dart';
import '../theme/inder_tema.dart';
import '../widgets/cancha_formulario_hoja.dart';
import '../widgets/inder_componentes.dart';

class PropietarioCanchasView extends StatefulWidget {
  const PropietarioCanchasView({super.key});

  @override
  State<PropietarioCanchasView> createState() => _PropietarioCanchasViewState();
}

class _PropietarioCanchasViewState extends State<PropietarioCanchasView> {
  late CanchasController _canchasController;
  String? _sedeId;

  @override
  void initState() {
    super.initState();
    _canchasController = CanchasController();
    _inicializarDatos();
  }

  Future<void> _inicializarDatos() async {
    final authController = Provider.of<AuthController>(context, listen: false);
    _sedeId = authController.currentUser?.sedeAsignada;
    if (_sedeId != null) await _canchasController.cargarCanchasPorSede(_sedeId!);
  }

  @override
  void dispose() {
    _canchasController.dispose();
    super.dispose();
  }

  void _mostrarFormulario({CanchaModel? cancha}) async {
    if (_sedeId == null) return _mostrarSnackbar('Error: Sede no encontrada', isError: true);

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(InderRadius.sheet))),
      builder: (ctx) => CanchaFormSheet(
        sedeId: _sedeId!,
        canchaParaEditar: cancha,
        onGuardado: () async {
          await _canchasController.cargarCanchasPorSede(_sedeId!);
          if (mounted) {
            Navigator.pop(ctx);
            _mostrarSnackbar(cancha == null ? 'Cancha creada' : 'Cancha actualizada');
          }
        },
      ),
    );
  }

  void _mostrarSnackbar(String mensaje, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(mensaje),
        backgroundColor: isError ? InderColors.cancelado : InderColors.ink,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(InderRadius.field)),
        margin: const EdgeInsets.all(20),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final hPad = InderLayout.hPad(context);

    return ChangeNotifierProvider.value(
      value: _canchasController,
      child: InderThemeScope(
        child: Scaffold(
          appBar: inderAppBar(
            title: 'Panel de Canchas',
            actions: [
              IconButton(
                tooltip: 'Actualizar',
                icon: const Icon(Icons.refresh_rounded),
                onPressed: () => _sedeId != null ? _canchasController.cargarCanchasPorSede(_sedeId!) : null,
              ),
              const SizedBox(width: 4),
            ],
          ),
          body: Consumer<CanchasController>(
            builder: (context, controller, _) {
              if (controller.isLoading) return const Center(child: CircularProgressIndicator());
              if (controller.error != null) return _buildErrorState(controller);
              if (controller.canchas.isEmpty) return _buildEmptyState();

              return RefreshIndicator(
                onRefresh: () async => controller.cargarCanchasPorSede(_sedeId!),
                child: ListView.separated(
                  padding: EdgeInsets.fromLTRB(hPad, 20, hPad, 96),
                  itemCount: controller.canchas.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 16),
                  itemBuilder: (_, i) => _CanchaCard(
                    cancha: controller.canchas[i],
                    onEditar: () => _mostrarFormulario(cancha: controller.canchas[i]),
                    onEliminar: () => _confirmarEliminar(controller.canchas[i]),
                  ),
                ),
              );
            },
          ),
          floatingActionButton: FloatingActionButton.extended(
            onPressed: () => _mostrarFormulario(),
            icon: const Icon(Icons.add_rounded),
            label: const Text('NUEVA CANCHA'),
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return const InderEmptyState(
      icon: Icons.sports_soccer_rounded,
      title: 'No hay canchas registradas',
      message: 'Usa el botón "Nueva cancha" para registrar la primera.',
    );
  }

  Widget _buildErrorState(CanchasController controller) {
    return InderErrorState(
      message: 'Error: ${controller.error}',
      onRetry: _inicializarDatos,
    );
  }

  Future<void> _confirmarEliminar(CanchaModel cancha) async {
    final confirmar = await showDialog<bool>(
      context: context,
      builder: (ctx) => InderConfirmDialog(
        title: '¿Eliminar cancha?',
        message: 'Vas a eliminar permanentemente "${cancha.title}".',
        confirmLabel: 'Eliminar',
      ),
    );
    if (confirmar == true) await _canchasController.eliminarCancha(cancha.id!);
  }
}

class _CanchaCard extends StatelessWidget {
  final CanchaModel cancha;
  final VoidCallback onEditar;
  final VoidCallback onEliminar;

  const _CanchaCard({required this.cancha, required this.onEditar, required this.onEliminar});

  @override
  Widget build(BuildContext context) {
    return InderCard(
      padding: EdgeInsets.zero,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Stack(
            children: [
              ClipRRect(
                borderRadius: const BorderRadius.vertical(top: Radius.circular(InderRadius.card)),
                child: _buildImage(cancha.image),
              ),
              Positioned(top: 12, right: 12, child: _buildBadge(cancha.tipo)),
            ],
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Text(
                        cancha.title,
                        style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700, color: InderColors.ink),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Text(
                      cancha.price,
                      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: InderColors.pagadoOnSoft),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 16,
                  runSpacing: 8,
                  children: [
                    _infoLabel(Icons.access_time_rounded, cancha.horario),
                    _infoLabel(Icons.people_outline_rounded, cancha.jugadores),
                  ],
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: onEditar,
                        icon: const Icon(Icons.edit_note_rounded),
                        label: const Text('EDITAR'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    IconButton(
                      tooltip: 'Eliminar cancha',
                      onPressed: onEliminar,
                      icon: const Icon(Icons.delete_outline_rounded, color: InderColors.canceladoOnSoft),
                      style: IconButton.styleFrom(
                        minimumSize: const Size(48, 48),
                        backgroundColor: InderColors.canceladoSoft,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(InderRadius.field)),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBadge(TipoCancha tipo) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: InderColors.ink.withOpacity(0.85),
        borderRadius: BorderRadius.circular(InderRadius.pill),
      ),
      child: Text(
        tipo.name.toUpperCase(),
        style: const TextStyle(color: InderColors.gold, fontSize: 10.5, fontWeight: FontWeight.w700, letterSpacing: 0.8),
      ),
    );
  }

  Widget _infoLabel(IconData icon, String text) {
    return Row(mainAxisSize: MainAxisSize.min, children: [
      Icon(icon, size: 16, color: InderColors.textMuted),
      const SizedBox(width: 6),
      Text(text, style: const TextStyle(color: InderColors.textMuted, fontSize: 13)),
    ]);
  }

  Widget _buildImage(String path) {
    return SizedBox(
      height: 160, width: double.infinity,
      child: path.startsWith('http')
        ? Image.network(path, fit: BoxFit.cover, errorBuilder: (_, __, ___) => _placeholder())
        : Image.asset(path, fit: BoxFit.cover, errorBuilder: (_, __, ___) => _placeholder()),
    );
  }

  Widget _placeholder() => Container(
        color: InderColors.goldTint,
        child: const Center(child: Icon(Icons.sports_soccer_outlined, size: 40, color: InderColors.goldDeep)),
      );
}
