import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../controllers/sedes_controlador.dart';
import '../routes/app_rutas.dart';
import '../services/firestore_servicio.dart';
import '../widgets/sede_tarjeta..dart';
import '../widgets/reserva_elemento.dart';
import '../widgets/reserva_detalle_hoja.dart';
import '../widgets/sede_formulario_hoja..dart';
import '../routes/app_rutas.dart';

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

  @override
  void initState() {
    super.initState();
    _cargarReservas();
    _searchController.addListener(() {
      setState(() {
        _searchQuery = _searchController.text.toLowerCase();
      });
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Provider.of<SedesController>(context, listen: false).escucharSedes();
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
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

  Widget _buildSearchBar(String hint) {
    return TextField(
      controller: _searchController,
      decoration: InputDecoration(
        hintText: hint,
        prefixIcon: const Icon(Icons.search, color: kPrimaryColor),
        suffixIcon: _searchQuery.isNotEmpty
            ? IconButton(
                icon: const Icon(Icons.clear),
                onPressed: () => _searchController.clear(),
              )
            : null,
        filled: true,
        fillColor: Colors.white,
        contentPadding: const EdgeInsets.symmetric(vertical: 0),
        border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide.none),
        enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: Colors.grey.shade200)),
      ),
    );
  }

  Widget _buildSedesSection(SedesController controller) {
    final filteredSedes = controller.customSedes
        .where((s) => s.title.toLowerCase().contains(_searchQuery))
        .toList();

    return Column(
      children: [
        _buildSearchBar('Buscar sede...'),
        const SizedBox(height: 16),
        if (filteredSedes.isEmpty)
          const Padding(
              padding: EdgeInsets.all(32),
              child: Text('No se encontraron sedes.'))
        else
          ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: filteredSedes.length,
            separatorBuilder: (_, __) => const SizedBox(height: 8),
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
    if (_loadingReservas)
      return const Center(child: CircularProgressIndicator());

    final filtered = reservasRecientes.where((r) {
      final nombre = r['nombreCompleto']?.toString().toLowerCase() ?? '';
      final correo = r['correoElectronico']?.toString().toLowerCase() ?? '';
      return nombre.contains(_searchQuery) || correo.contains(_searchQuery);
    }).toList();

    return Column(
      children: [
        _buildSearchBar('Buscar por cliente...'),
        const SizedBox(height: 16),
        if (filtered.isEmpty)
          const Padding(
              padding: EdgeInsets.all(32), child: Text('Sin resultados.'))
        else
          ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: filtered.length,
            separatorBuilder: (_, __) => const SizedBox(height: 10),
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
    final sedesController = context.watch<SedesController>();
    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      appBar: AppBar(
        backgroundColor: kPrimaryColor,
        elevation: 0,
        centerTitle: true,
        iconTheme: const IconThemeData(color: Colors.white),
        title: Text(_tituloSeccion,
            style: const TextStyle(
                color: Colors.white, fontWeight: FontWeight.bold)),
        actions: [
          IconButton(
              icon: const Icon(Icons.refresh),
              onPressed: () {
                _cargarReservas();
                sedesController.cargarSedes();
              }),
        ],
      ),
      drawer: _buildDrawer(),
      floatingActionButton: _seccionActual == _Seccion.sedes
          ? FloatingActionButton.extended(
              onPressed: () => _mostrarFormularioSede(),
              backgroundColor: kPrimaryColor,
              icon: const Icon(Icons.add, color: Colors.white),
              label: const Text('Crear sede',
                  style: TextStyle(color: Colors.white)),
            )
          : null,
      body: RefreshIndicator(
        onRefresh: () async {
          await _cargarReservas();
          await sedesController.cargarSedes();
        },
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 80),
          children: [
            if (_seccionActual == _Seccion.sedes)
              _buildSedesSection(sedesController),
            if (_seccionActual == _Seccion.reservas) _buildReservasSection(),
            if (_seccionActual == _Seccion.usuarios) _buildUsuariosLoading(),
            if (_seccionActual == _Seccion.bloqueos) _buildBloqueosLoading(),
          ],
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

  Widget _buildDrawer() {
    return Drawer(
      child: Column(
        children: [
          const UserAccountsDrawerHeader(
            decoration: BoxDecoration(color: kPrimaryColor),
            accountName: Text("Administrador"),
            accountEmail: null,
            currentAccountPicture: CircleAvatar(
                backgroundColor: Colors.white24,
                child: Icon(Icons.admin_panel_settings,
                    color: Colors.white, size: 32)),
          ),

          _drawerTile(
            Icons.location_city,
            'Sedes',
            _Seccion.sedes,
          ),

          _drawerTile(
            Icons.event_available,
            'Reservas',
            _Seccion.reservas,
          ),

          ListTile(
            leading: const Icon(
              Icons.analytics_outlined,
              color: kPrimaryColor,
            ),
            title: const Text(
              'Reportes',
              style: TextStyle(fontWeight: FontWeight.w500),
            ),
            onTap: () {
              Navigator.pop(context);
              Navigator.pushNamed(
                context,
                AppRoutes.adminReportes,
              );
            },
          ),

          const Divider(),
          _drawerTile(Icons.people, 'Usuarios', _Seccion.usuarios),
          _drawerTile(Icons.block, 'Bloqueos', _Seccion.bloqueos),
          const Spacer(),
          ListTile(
            leading: const Icon(Icons.logout, color: Colors.red),
            title: const Text('Cerrar sesión',
                style: TextStyle(color: Colors.red)),
            onTap: () => Navigator.pushNamedAndRemoveUntil(
              context,
              AppRoutes.login,
              (route) => false,
            ),
          ),
          const SizedBox(height: 20),
        ],
      ),
    );
  }

  Widget _drawerTile(IconData icon, String label, _Seccion seccion) {
    final active = _seccionActual == seccion;
    return ListTile(
      leading: Icon(icon, color: active ? kPrimaryColor : Colors.black54),
      title: Text(label,
          style: TextStyle(
              color: active ? kPrimaryColor : Colors.black87,
              fontWeight: active ? FontWeight.bold : FontWeight.normal)),
      tileColor: active ? kPrimaryColor.withOpacity(0.05) : null,
      onTap: () {
        setState(() {
          _seccionActual = seccion;
          _searchController.clear();
        });
        Navigator.pop(context);
      },
    );
  }

Widget _buildUsuariosLoading() {
  WidgetsBinding.instance.addPostFrameCallback((_) async {
    setState(() {
      _seccionActual = _Seccion.sedes;
    });
    await Navigator.pushNamed(context, AppRoutes.superAdminUsuarios);
  });
  return const Center(child: CircularProgressIndicator());
}

  Widget _buildBloqueosLoading() {
  WidgetsBinding.instance.addPostFrameCallback((_) async {
    setState(() {
      _seccionActual = _Seccion.sedes;
    });
    await Navigator.pushNamed(context, AppRoutes.adminBloqueos);
  });

  return const Center(child: CircularProgressIndicator());
}
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
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
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
      backgroundColor: const Color(0xFFEAEFF3),
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(18))),
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
      builder: (_) => AlertDialog(
        title: const Text('Eliminar sede'),
        content: const Text('¿Seguro que quieres eliminar esta sede?'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancelar')),
          ElevatedButton(
              onPressed: () => Navigator.pop(context, true),
              style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
              child: const Text('Eliminar')),
        ],
      ),
    );
    if (confirmar == true) {
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