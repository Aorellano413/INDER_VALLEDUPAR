// lib/views/propietario_canchas_view.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../controllers/autenticacion_controlador..dart';
import '../controllers/canchas_controlador.dart';
import '../models/cancha_modelo.dart';
import '../widgets/cancha_formulario_hoja.dart';

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
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(25))),
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
        backgroundColor: isError ? Colors.redAccent : const Color(0xFF1E293B),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        margin: const EdgeInsets.all(20),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider.value(
      value: _canchasController,
      child: Scaffold(
        backgroundColor: const Color(0xFFF8FAFC),
        appBar: AppBar(
          elevation: 0,
          centerTitle: true,
          title: const Text('Panel de Canchas', style: TextStyle(fontWeight: FontWeight.w800, letterSpacing: 0.5)),
          flexibleSpace: Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [Color(0xFF0F172A), Color(0xFF1E293B)],
                begin: Alignment.topLeft, end: Alignment.bottomRight,
              ),
            ),
          ),
          foregroundColor: Colors.white,
          actions: [
            IconButton(
              icon: const Icon(Icons.refresh_rounded),
              onPressed: () => _sedeId != null ? _canchasController.cargarCanchasPorSede(_sedeId!) : null,
            ),
            const SizedBox(width: 8),
          ],
        ),
        body: Consumer<CanchasController>(
          builder: (context, controller, _) {
            if (controller.isLoading) return const Center(child: CircularProgressIndicator(color: Color(0xFF0083B0)));
            if (controller.error != null) return _buildErrorState(controller);
            if (controller.canchas.isEmpty) return _buildEmptyState();

            return RefreshIndicator(
              color: const Color(0xFF0083B0),
              onRefresh: () async => controller.cargarCanchasPorSede(_sedeId!),
              child: ListView.separated(
                padding: const EdgeInsets.all(20),
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
          icon: const Icon(Icons.add_rounded, color: Colors.white),
          label: const Text('NUEVA CANCHA', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
          backgroundColor: const Color(0xFF0083B0),
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.sports_soccer_rounded, size: 80, color: Colors.blueGrey.shade100),
          const SizedBox(height: 16),
          const Text('No hay canchas registradas', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF475569))),
        ],
      ),
    );
  }

  Widget _buildErrorState(CanchasController controller) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.cloud_off_rounded, size: 60, color: Colors.redAccent),
          Text('Error: ${controller.error}'),
          ElevatedButton(onPressed: _inicializarDatos, child: const Text('Reintentar')),
        ],
      ),
    );
  }

  Future<void> _confirmarEliminar(CanchaModel cancha) async {
    final confirmar = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('¿Eliminar cancha?'),
        content: Text('Vas a eliminar permanentemente "${cancha.title}".'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancelar', style: TextStyle(color: Colors.grey))),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
            child: const Text('Eliminar', style: TextStyle(color: Colors.white)),
          ),
        ],
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
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 15, offset: const Offset(0, 5))],
      ),
      child: Column(
        children: [
          Stack(
            children: [
              ClipRRect(
                borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
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
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(child: Text(cancha.title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF1E293B)))),
                    Text(cancha.price, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: Color(0xFF10B981))),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    _infoLabel(Icons.access_time_rounded, cancha.horario),
                    const SizedBox(width: 16),
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
                        style: OutlinedButton.styleFrom(
                          foregroundColor: const Color(0xFF0083B0),
                          side: const BorderSide(color: Color(0xFF0083B0)),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    IconButton(
                      onPressed: onEliminar,
                      icon: const Icon(Icons.delete_outline_rounded, color: Colors.redAccent),
                      style: IconButton.styleFrom(backgroundColor: Colors.red.shade50, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
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
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(color: Colors.black87, borderRadius: BorderRadius.circular(8)),
      child: Text(tipo.name.toUpperCase(), style: const TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.w900, letterSpacing: 0.5)),
    );
  }

  Widget _infoLabel(IconData icon, String text) {
    return Row(children: [
      Icon(icon, size: 16, color: const Color(0xFF94A3B8)),
      const SizedBox(width: 4),
      Text(text, style: const TextStyle(color: Color(0xFF64748B), fontSize: 13)),
    ]);
  }

  Widget _buildImage(String path) {
    return SizedBox(
      height: 150, width: double.infinity,
      child: path.startsWith('http')
        ? Image.network(path, fit: BoxFit.cover, errorBuilder: (_, __, ___) => _placeholder())
        : Image.asset(path, fit: BoxFit.cover, errorBuilder: (_, __, ___) => _placeholder()),
    );
  }

  Widget _placeholder() => Container(color: const Color(0xFFF1F5F9), child: const Icon(Icons.broken_image_outlined, color: Colors.blueGrey));
}