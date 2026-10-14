import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../controllers/autenticacion_controlador.dart';
import '../controllers/sedes_controlador.dart';
import '../routes/app_rutas.dart';
import '../services/firestore_servicio.dart';
import '../services/sesion.dart';
import '../theme/inder_tema.dart';
import '../widgets/inder_componentes.dart';
import '../widgets/sede_tarjeta..dart';
import '../widgets/reserva_elemento.dart';
import '../widgets/reserva_detalle_hoja.dart';
import '../widgets/sede_formulario_hoja..dart';
import 'pantalla_auditoria.dart';

// Se conserva por compatibilidad (era pública). Ya no se usa en esta pantalla:
// los colores ahora vienen de InderColors (lib/theme/inder_tema.dart).
const kPrimaryColor = Color(0xFF101B2E);

enum _Seccion { sedes, reservas, usuarios, bloqueos }

class AdminDashboardView extends StatefulWidget {
  const AdminDashboardView({super.key});

  @override
  State<AdminDashboardView> createState() => _AdminDashboardViewState();
}

class _AdminDashboardViewState extends State<AdminDashboardView> {
  final FirestoreService _firestore = FirestoreService();
  final TextEditingController _searchController = TextEditingController();
  _Seccion _seccionActual = _Seccion.sedes;
  List<Map<String, dynamic>> reservasRecientes = [];
  bool _loadingReservas = true;
  String _searchQuery = "";

  bool _verificandoSesion = true;

  @override
  void initState() {
    super.initState();
    _searchController.addListener(() {
      setState(() {
        _searchQuery = _searchController.text.toLowerCase();
      });
    });
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await _verificarAccesoAdmin();
      if (!mounted) return;
      final auth = Provider.of<AuthController>(context, listen: false);
      if (auth.isAuthenticated) {
        _cargarReservas();
        Provider.of<SedesController>(context, listen: false).escucharSedes();
      }
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _verificarAccesoAdmin() async {
    if (!mounted) return;

    final auth = Provider.of<AuthController>(context, listen: false);

    if (!auth.isAuthenticated) {
      Navigator.pushReplacementNamed(context, AppRoutes.loginAdmin);
    } else {
      setState(() {
        _verificandoSesion = false;
      });
    }
  }

  Future<void> _cargarReservas() async {
    setState(() => _loadingReservas = true);
    try {
      final reservas = await _firestore.getReservasCompletas();
      if (mounted) {
        setState(() {
          reservasRecientes = reservas;
          _loadingReservas = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _loadingReservas = false);
    }
  }

  // ───────────────────────── Presentación ─────────────────────────

  Widget _buildEncabezado() {
    final user = Provider.of<AuthController>(context, listen: false).currentUser;
    return InderHeaderBanner(
      titulo: user?.nombre ?? 'Administrador',
      subtitulo: user?.email,
      usuario: user?.nombre,
      detalleUsuario: inderRolLabel(user?.rol),
    );
  }

  Widget _buildSearchBar(String hint) {
    return TextField(
      controller: _searchController,
      textInputAction: TextInputAction.search,
      decoration: InputDecoration(
        hintText: hint,
        prefixIcon: const Icon(Icons.search_rounded),
        suffixIcon: _searchQuery.isNotEmpty
            ? IconButton(
                tooltip: 'Limpiar búsqueda',
                icon: const Icon(Icons.close_rounded),
                onPressed: () => _searchController.clear(),
              )
            : null,
      ),
    );
  }

  Widget _buildCargando() {
    return const Padding(
      padding: EdgeInsets.symmetric(vertical: 48),
      child: Center(child: CircularProgressIndicator()),
    );
  }

  Widget _buildSedesSection(SedesController controller) {
    final filteredSedes = controller.customSedes
        .where((s) => s.title.toLowerCase().contains(_searchQuery))
        .toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSearchBar('Buscar sede...'),
        const SizedBox(height: 20),
        InderSectionTitle(
          title: 'Sedes registradas',
          subtitle: _searchQuery.isEmpty
              ? '${filteredSedes.length} en total'
              : '${filteredSedes.length} resultado(s)',
        ),
        const SizedBox(height: 12),
        if (filteredSedes.isEmpty)
          InderEmptyState(
            icon: Icons.location_city_outlined,
            title: 'No se encontraron sedes',
            message: _searchQuery.isEmpty
                ? 'Cuando registres una sede aparecerá en este listado.'
                : 'Prueba con otro término de búsqueda.',
          )
        else
          ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: filteredSedes.length,
            separatorBuilder: (_, __) => const SizedBox(height: 12),
            itemBuilder: (_, index) {
              final sede = filteredSedes[index];
              return SedeCard(
                sede: sede,
                onEditar: () => _mostrarFormularioSede(
                    editIndex: controller.customSedes.indexOf(sede)),
                onEliminar: () => _confirmarEliminarSede(
                    controller.customSedes.indexOf(sede)),
              );
            },
          ),
      ],
    );
  }

  Widget _buildReservasSection() {
    if (_loadingReservas) {
      return _buildCargando();
    }

    final filtered = reservasRecientes.where((r) {
      final nombre = r['nombreCompleto']?.toString().toLowerCase() ?? '';
      final correo = r['correoElectronico']?.toString().toLowerCase() ?? '';
      return nombre.contains(_searchQuery) || correo.contains(_searchQuery);
    }).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSearchBar('Buscar por cliente...'),
        const SizedBox(height: 20),
        InderSectionTitle(
          title: 'Reservas recientes',
          subtitle: _searchQuery.isEmpty
              ? '${filtered.length} en total'
              : '${filtered.length} resultado(s)',
        ),
        const SizedBox(height: 12),
        if (filtered.isEmpty)
          InderEmptyState(
            icon: Icons.event_busy_outlined,
            title: 'Sin resultados',
            message: _searchQuery.isEmpty
                ? 'Todavía no hay reservas para mostrar.'
                : 'No hay reservas que coincidan con la búsqueda.',
          )
        else
          ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: filtered.length,
            separatorBuilder: (_, __) => const SizedBox(height: 12),
            itemBuilder: (_, index) {
              final reserva = filtered[index];
              return ReservaItem(
                reserva: reserva,
                onTap: () => _mostrarDetalleReserva(reserva, index),
              );
            },
          ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_verificandoSesion) {
      return const InderThemeScope(
        child: Scaffold(
          body: Center(child: CircularProgressIndicator()),
        ),
      );
    }

    final sedesController = context.watch<SedesController>();
    final hPad = InderLayout.hPad(context);

    return InderThemeScope(
      child: Scaffold(
        appBar: inderAppBar(
          title: _tituloSeccion,
          actions: [
            IconButton(
              tooltip: 'Actualizar',
              icon: const Icon(Icons.refresh_rounded),
              onPressed: () {
                _cargarReservas();
                sedesController.cargarSedes();
              },
            ),
            const SizedBox(width: 4),
          ],
        ),
        drawer: _buildDrawer(),
        floatingActionButton: _seccionActual == _Seccion.sedes
            ? FloatingActionButton.extended(
                onPressed: () => _mostrarFormularioSede(),
                icon: const Icon(Icons.add_rounded),
                label: const Text('Crear sede'),
              )
            : null,
        body: RefreshIndicator(
          onRefresh: () async {
            await _cargarReservas();
            await sedesController.cargarSedes();
          },
          child: ListView(
            padding: EdgeInsets.fromLTRB(hPad, 16, hPad, 96),
            children: [
              _buildEncabezado(),
              const SizedBox(height: 20),
              if (_seccionActual == _Seccion.sedes)
                _buildSedesSection(sedesController),
              if (_seccionActual == _Seccion.reservas) _buildReservasSection(),
              if (_seccionActual == _Seccion.usuarios) _buildUsuariosLoading(),
              if (_seccionActual == _Seccion.bloqueos) _buildBloqueosLoading(),
            ],
          ),
        ),
      ),
    );
  }

  String get _tituloSeccion {
    switch (_seccionActual) {
      case _Seccion.sedes:
        return 'Sedes';
      case _Seccion.reservas:
        return 'Reservas recientes';
      case _Seccion.usuarios:
        return 'Control de Usuarios';
      case _Seccion.bloqueos:
        return 'Bloqueos por evento';
    }
  }

  // ───────────────────────── Menú lateral ─────────────────────────

  Widget _buildDrawerHeader() {
    final user = Provider.of<AuthController>(context, listen: false).currentUser;
    final nombre = (user?.nombre ?? 'Administrador').trim();
    final inicial = nombre.isNotEmpty ? nombre[0].toUpperCase() : 'A';

    return Container(
      width: double.infinity,
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(bottom: BorderSide(color: InderColors.gold, width: 3)),
      ),
      padding: EdgeInsets.fromLTRB(
          20, MediaQuery.of(context).padding.top + 20, 20, 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Image.asset(
            'lib/images/inder.png',
            height: 48,
            fit: BoxFit.contain,
            semanticLabel: 'Logotipo Alcaldía de Valledupar - INDER',
            errorBuilder: (_, __, ___) => const SizedBox(height: 48),
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              InderInitialAvatar(initial: inicial, size: 44),
              const SizedBox(width: 12),
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
                    Text(
                      inderRolLabel(user?.rol),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 12,
                        color: InderColors.textMuted,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _drawerLabel(String text) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 16, 24, 6),
      child: Text(
        text,
        style: const TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          letterSpacing: 1.1,
          color: InderColors.textMuted,
        ),
      ),
    );
  }

  Widget _drawerItem({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
    bool active = false,
    bool destructive = false,
  }) {
    final color = destructive ? InderColors.cancelado : InderColors.ink;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
      child: ListTile(
        minVerticalPadding: 12,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(InderRadius.field),
        ),
        selected: active,
        selectedTileColor: InderColors.goldTint,
        selectedColor: InderColors.ink,
        leading: Icon(
          icon,
          color: active ? InderColors.goldDeep : (destructive ? color : InderColors.textMuted),
        ),
        title: Text(
          label,
          style: TextStyle(
            fontSize: 14,
            color: color,
            fontWeight: active ? FontWeight.w700 : FontWeight.w500,
          ),
        ),
        onTap: onTap,
      ),
    );
  }

  Widget _buildDrawer() {
    return Drawer(
      child: Column(
        children: [
          _buildDrawerHeader(),
          Expanded(
            child: ListView(
              padding: EdgeInsets.zero,
              children: [
                _drawerLabel('GESTIÓN'),
                _drawerTile(Icons.location_city_outlined, 'Sedes', _Seccion.sedes),
                _drawerTile(Icons.event_available_outlined, 'Reservas', _Seccion.reservas),
                _drawerItem(
                  icon: Icons.analytics_outlined,
                  label: 'Reportes',
                  onTap: () {
                    Navigator.pop(context);
                    Navigator.pushNamed(context, AppRoutes.adminReportes);
                  },
                ),
                _drawerLabel('CONTROL'),
                _drawerTile(Icons.people_outline_rounded, 'Usuarios', _Seccion.usuarios),
                _drawerTile(Icons.block_outlined, 'Bloqueos', _Seccion.bloqueos),
                _drawerItem(
                  icon: Icons.fact_check_outlined,
                  label: 'Auditoría',
                  onTap: () {
                    Navigator.pop(context);
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const PantallaAuditoria()),
                    );
                  },
                ),
              ],
            ),
          ),
          const Divider(),
          _drawerItem(
            icon: Icons.logout_rounded,
            label: 'Cerrar sesión',
            destructive: true,
            onTap: () async {
              await Provider.of<AuthController>(context, listen: false)
                  .logout();
              Sesion.cerrar();
              if (!mounted) return;
              Navigator.pushNamedAndRemoveUntil(
                context,
                AppRoutes.loginAdmin,
                (route) => false,
              );
            },
          ),
          SizedBox(height: MediaQuery.of(context).padding.bottom + 12),
        ],
      ),
    );
  }

  Widget _drawerTile(IconData icon, String label, _Seccion seccion) {
    final active = _seccionActual == seccion;
    return _drawerItem(
      icon: icon,
      label: label,
      active: active,
      onTap: () {
        setState(() {
          _seccionActual = seccion;
          _searchController.clear();
        });
        Navigator.pop(context);
      },
    );
  }

  // ───────────────────────── Navegación a módulos (sin cambios) ─────────────────────────

  Widget _buildUsuariosLoading() {
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      setState(() {
        _seccionActual = _Seccion.sedes;
      });
      await Navigator.pushNamed(context, AppRoutes.superAdminUsuarios);
    });
    return _buildCargando();
  }

  Widget _buildBloqueosLoading() {
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      setState(() {
        _seccionActual = _Seccion.sedes;
      });
      await Navigator.pushNamed(context, AppRoutes.adminBloqueos);
    });

    return _buildCargando();
  }

  // ───────────────────────── Hojas y diálogos ─────────────────────────

  Future<void> _mostrarFormularioSede({int? editIndex}) async {
    final controller = Provider.of<SedesController>(context, listen: false);
    final sedeParaEditar =
        editIndex != null ? controller.customSedes[editIndex] : null;
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
          borderRadius:
              BorderRadius.vertical(top: Radius.circular(InderRadius.sheet))),
      builder: (ctx) => SedeFormSheet(
          sedeParaEditar: sedeParaEditar,
          editIndex: editIndex,
          onGuardado: (m) => _mostrarSnackbar(m)),
    );
  }

  Future<void> _mostrarDetalleReserva(
      Map<String, dynamic> reserva, int index) async {
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => ReservaDetalleSheet(
          reserva: reserva,
          onEstadoActualizado: () async {
            await _cargarReservas();
            _mostrarSnackbar('Estado actualizado');
          }),
    );
  }

  Future<void> _confirmarEliminarSede(int index) async {
    final confirmar = await showDialog<bool>(
      context: context,
      builder: (_) => const InderConfirmDialog(
        title: 'Eliminar sede',
        message: '¿Seguro que quieres eliminar esta sede?',
        confirmLabel: 'Eliminar',
      ),
    );
    if (confirmar == true) {
      if (!mounted) return;
      await Provider.of<SedesController>(context, listen: false)
          .eliminarSedeCustom(index);
      _mostrarSnackbar('Sede eliminada');
    }
  }

  void _mostrarSnackbar(String m) {
    ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(m), behavior: SnackBarBehavior.floating));
  }
}
