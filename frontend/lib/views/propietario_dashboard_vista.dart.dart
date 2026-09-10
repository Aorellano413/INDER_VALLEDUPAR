// lib/views/propietario_dashboard_view.dart
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:fl_chart/fl_chart.dart';
import '../controllers/autenticacion_controlador..dart';
import '../controllers/canchas_controlador.dart';
import '../services/firestore_servicio.dart';
import '../routes/app_rutas.dart';
import '../widgets/reserva_detalle_hoja.dart';

class PropietarioDashboardView extends StatefulWidget {
  const PropietarioDashboardView({super.key});

  @override
  State<PropietarioDashboardView> createState() => _PropietarioDashboardViewState();
}

class _PropietarioDashboardViewState extends State<PropietarioDashboardView> {
  final FirestoreService _firestore = FirestoreService();
  final Stopwatch _stopwatch = Stopwatch();
  late Timer _timer;
  String _elapsedText = "00:00";

  String? _sedeId;
  String _sedeName = "Mi Sede";
  List<Map<String, dynamic>> _reservas = [];
  Map<String, dynamic>? _estadisticas;
  bool _loadingReservas = true;
  bool _loadingEstadisticas = true;

  String _filtroTiempo = 'hoy';

  @override
  void initState() {
    super.initState();
    _inicializarDatos();
    _iniciarCronometro();
  }

  Future<void> _inicializarDatos() async {
    final authController = Provider.of<AuthController>(context, listen: false);
    _sedeId = authController.currentUser?.sedeAsignada;

    if (_sedeId != null) {

      final sedes = await _firestore.getSedes();
      final sede = sedes.firstWhere((s) => s.id == _sedeId, orElse: () => sedes.first);
      setState(() => _sedeName = sede.title);

      final canchasController = Provider.of<CanchasController>(context, listen: false);
      await canchasController.cargarCanchasPorSede(_sedeId!);

      await _cargarDatos();
    }
  }

  void _iniciarCronometro() {
    _stopwatch.start();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      final d = _stopwatch.elapsed;
      final mm = d.inMinutes.remainder(60).toString().padLeft(2, '0');
      final ss = d.inSeconds.remainder(60).toString().padLeft(2, '0');
      setState(() => _elapsedText = "$mm:$ss");
    });
  }

  Future<void> _cargarDatos() async {
    await Future.wait([
      _cargarReservas(),
      _cargarEstadisticas(),
    ]);
  }

  Future<void> _cargarReservas() async {
    if (_sedeId == null) return;

    setState(() => _loadingReservas = true);
    try {
      final todasReservas = await _firestore.getReservasCompletasPorSede(_sedeId!);


      final reservasFiltradas = todasReservas.where((reserva) {
        final fechaReserva = reserva['fechaReserva'];
        if (fechaReserva == null) return false;

        DateTime fecha;
        if (fechaReserva is DateTime) {
          fecha = fechaReserva;
        } else {
          fecha = (fechaReserva as dynamic).toDate();
        }

        final ahora = DateTime.now();

        switch (_filtroTiempo) {
          case 'hoy':

            return fecha.year == ahora.year &&
                   fecha.month == ahora.month &&
                   fecha.day == ahora.day;
          case 'semana':

            final inicioSemana = DateTime(ahora.year, ahora.month, ahora.day).subtract(Duration(days: 7));
            final fechaSolo = DateTime(fecha.year, fecha.month, fecha.day);
            return fechaSolo.isAfter(inicioSemana) || fechaSolo.isAtSameMomentAs(inicioSemana);
          case 'mes':

            return fecha.year == ahora.year && fecha.month == ahora.month;
          case 'año':

            return fecha.year == ahora.year;
          default:
            return true;
        }
      }).toList();

      if (mounted) {
        setState(() {
          _reservas = reservasFiltradas;
          _loadingReservas = false;
        });
      }
    } catch (e) {
      debugPrint('Error al cargar reservas: $e');
      if (mounted) setState(() => _loadingReservas = false);
    }
  }

  Future<void> _cargarEstadisticas() async {
    if (_sedeId == null) return;

    setState(() => _loadingEstadisticas = true);
    try {
      final stats = await _firestore.getEstadisticasPorSede(_sedeId!);

      if (mounted) {
        setState(() {
          _estadisticas = stats;
          _loadingEstadisticas = false;
        });
      }
    } catch (e) {
      debugPrint('Error al cargar estadísticas: $e');
      if (mounted) setState(() => _loadingEstadisticas = false);
    }
  }

  @override
  void dispose() {
    _timer.cancel();
    _stopwatch.stop();
    super.dispose();
  }

  void _logout() {
    Provider.of<AuthController>(context, listen: false).logout();
    Navigator.pushNamedAndRemoveUntil(context, AppRoutes.login, (route) => false);
  }

  void _mostrarSnackbar(String mensaje) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(mensaje), behavior: SnackBarBehavior.floating),
    );
  }

  Future<void> _mostrarDetalleReserva(Map<String, dynamic> reserva) async {
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: const Color(0xFFEAEFF3),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
      ),
      builder: (ctx) => ReservaDetalleSheet(
        reserva: reserva,
        onEstadoActualizado: () async {
          await _cargarReservas();
          await _cargarEstadisticas();
          _mostrarSnackbar('Estado de reserva actualizado');
        },
      ),
    );
  }

  Widget _buildGraficaReservas() {
    if (_reservas.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(32),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              const Color(0xFF0083B0).withOpacity(0.1),
              const Color(0xFF00BCD4).withOpacity(0.05),
            ],
          ),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Column(
          children: [
            Icon(Icons.bar_chart, size: 64, color: Colors.grey.shade300),
            const SizedBox(height: 16),
            Text(
              'No hay reservas en este período',
              style: TextStyle(fontSize: 16, color: Colors.grey.shade600),
            ),
          ],
        ),
      );
    }

    int pendientes = 0;
    int pagadas = 0;
    int canceladas = 0;

    for (var reserva in _reservas) {
      final estado = reserva['estado'] ?? 'pendiente';
      if (estado == 'pendiente') pendientes++;
      if (estado == 'pagado') pagadas++;
      if (estado == 'cancelado') canceladas++;
    }

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.08),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Estado de Reservas',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 20),
          SizedBox(
            height: 200,
            child: PieChart(
              PieChartData(
                sectionsSpace: 2,
                centerSpaceRadius: 50,
                sections: [
                  PieChartSectionData(
                    value: pendientes.toDouble(),
                    title: '$pendientes',
                    color: const Color(0xFFFFA000),
                    radius: 60,
                    titleStyle: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  PieChartSectionData(
                    value: pagadas.toDouble(),
                    title: '$pagadas',
                    color: const Color(0xFF43A047),
                    radius: 60,
                    titleStyle: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  PieChartSectionData(
                    value: canceladas.toDouble(),
                    title: '$canceladas',
                    color: const Color(0xFFC62828),
                    radius: 60,
                    titleStyle: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _LegendaItem(
                color: const Color(0xFFFFA000),
                label: 'Pendientes',
                value: pendientes,
              ),
              _LegendaItem(
                color: const Color(0xFF43A047),
                label: 'Pagadas',
                value: pagadas,
              ),
              _LegendaItem(
                color: const Color(0xFFC62828),
                label: 'Canceladas',
                value: canceladas,
              ),
            ],
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final authController = context.watch<AuthController>();

    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      appBar: AppBar(
        automaticallyImplyLeading: false,
        backgroundColor: const Color(0xFF0083B0),
        title: Text(
          _sedeName,
          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, color: Colors.white),
            onPressed: _cargarDatos,
            tooltip: 'Actualizar',
          ),
          TextButton.icon(
            onPressed: _logout,
            icon: const Icon(Icons.logout, color: Colors.white),
            label: const Text('Salir', style: TextStyle(color: Colors.white)),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _cargarDatos,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            _buildFiltrosTiempo(),
            const SizedBox(height: 20),

            if (_loadingEstadisticas)
              const Center(child: CircularProgressIndicator())
            else


            _buildGraficaReservas(),

            const SizedBox(height: 24),
            _buildReservasSection(),
          ],
        ),
      ),
      bottomNavigationBar: _buildBottomBar(authController),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          Navigator.pushNamed(context, AppRoutes.propietarioCanchas);
        },
        icon: const Icon(Icons.sports_soccer),
        label: const Text('Mis Canchas'),
        backgroundColor: const Color(0xFF0083B0),
      ),
    );
  }

  Widget _buildFiltrosTiempo() {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          _FiltroChip(
            label: 'Hoy',
            isSelected: _filtroTiempo == 'hoy',
            onTap: () {
              setState(() => _filtroTiempo = 'hoy');
              _cargarReservas();
            },
          ),
          const SizedBox(width: 8),
          _FiltroChip(
            label: 'Última semana',
            isSelected: _filtroTiempo == 'semana',
            onTap: () {
              setState(() => _filtroTiempo = 'semana');
              _cargarReservas();
            },
          ),
          const SizedBox(width: 8),
          _FiltroChip(
            label: 'Último mes',
            isSelected: _filtroTiempo == 'mes',
            onTap: () {
              setState(() => _filtroTiempo = 'mes');
              _cargarReservas();
            },
          ),
          const SizedBox(width: 8),
          _FiltroChip(
            label: 'Último año',
            isSelected: _filtroTiempo == 'año',
            onTap: () {
              setState(() => _filtroTiempo = 'año');
              _cargarReservas();
            },
          ),
        ],
      ),
    );
  }


  Widget _buildReservasSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          "Reservas",
          style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: Colors.black87),
        ),
        const SizedBox(height: 10),
        if (_loadingReservas)
          const Center(
            child: Padding(
              padding: EdgeInsets.all(32),
              child: CircularProgressIndicator(),
            ),
          )
        else if (_reservas.isEmpty)
          Center(
            child: Padding(
              padding: const EdgeInsets.all(32),
              child: Column(
                children: [
                  Icon(Icons.event_busy, size: 64, color: Colors.grey.shade400),
                  const SizedBox(height: 16),
                  Text(
                    'No hay reservas en este período',
                    style: TextStyle(fontSize: 16, color: Colors.grey.shade600),
                  ),
                ],
              ),
            ),
          )
        else
          ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: _reservas.length > 10 ? 10 : _reservas.length,
            separatorBuilder: (_, __) => const SizedBox(height: 6),
            itemBuilder: (_, index) {
              final reserva = _reservas[index];
              // ✅ AGREGADO: onTap para mostrar detalle
              return _ReservaCard(
                reserva: reserva,
                onTap: () => _mostrarDetalleReserva(reserva),
              );
            },
          ),
      ],
    );
  }

  Widget _buildBottomBar(AuthController authController) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: const BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(color: Color(0x1A000000), blurRadius: 10, offset: Offset(0, -2)),
        ],
      ),
      child: Row(
        children: [
          const CircleAvatar(
            radius: 18,
            backgroundColor: Color(0xFF0083B0),
            child: Icon(Icons.store, color: Colors.white, size: 20),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              authController.currentUser?.nombre ?? 'Propietario',
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
          ),
          const Icon(Icons.timer_outlined, size: 18, color: Colors.black54),
          const SizedBox(width: 6),
          Text(
            _elapsedText,
            style: const TextStyle(color: Colors.black87, fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
  }
}

// ============ WIDGETS AUXILIARES ============

class _FiltroChip extends StatelessWidget {
  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  const _FiltroChip({
    required this.label,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFF0083B0) : Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected ? const Color(0xFF0083B0) : Colors.grey.shade300,
          ),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: const Color(0xFF0083B0).withOpacity(0.3),
                    blurRadius: 8,
                    offset: const Offset(0, 4),
                  ),
                ]
              : null,
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isSelected ? Colors.white : Colors.black87,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
          ),
        ),
      ),
    );
  }
}

class _LegendaItem extends StatelessWidget {
  final Color color;
  final String label;
  final int value;

  const _LegendaItem({
    required this.color,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(
          width: 12,
          height: 12,
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: const TextStyle(fontSize: 12, color: Colors.black54),
        ),
        Text(
          '$value',
          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
        ),
      ],
    );
  }
}

// ✅ MODIFICADO: Agregado onTap
class _ReservaCard extends StatelessWidget {
  final Map<String, dynamic> reserva;
  final VoidCallback onTap; // ✅ AGREGADO

  const _ReservaCard({
    required this.reserva,
    required this.onTap, // ✅ AGREGADO
  });

  @override
  Widget build(BuildContext context) {
    final nombre = reserva['nombreCompleto'] ?? 'Sin nombre';
    final inicial = (nombre.isNotEmpty ? nombre.trim()[0] : '?').toUpperCase();
    final hora = reserva['horaReserva'] ?? 'Sin hora';
    final cancha = reserva['cancha'] != null
        ? reserva['cancha']['title'] ?? 'Sin cancha'
        : 'Sin cancha';

    final estado = reserva['estado'] ?? 'pendiente';
    Color estadoColor;
    switch (estado) {
      case 'pagado':
        estadoColor = const Color(0xFF43A047);
        break;
      case 'cancelado':
        estadoColor = const Color(0xFFC62828);
        break;
      default:
        estadoColor = const Color(0xFFFFA000);
    }

    // ✅ MODIFICADO: Envuelto en InkWell
    return InkWell(
      onTap: onTap, // ✅ AGREGADO
      borderRadius: BorderRadius.circular(12),
      child: Card(
        elevation: 0.8,
        color: const Color(0xFFF0F3F7),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        margin: const EdgeInsets.symmetric(vertical: 6),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          child: Row(
            children: [
              CircleAvatar(
                radius: 18,
                backgroundColor: const Color(0xFF0083B0),
                child: Text(
                  inicial,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            nombre,
                            style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: estadoColor.withOpacity(0.12),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(
                              color: estadoColor.withOpacity(0.5),
                            ),
                          ),
                          child: Text(
                            estado.toUpperCase(),
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w600,
                              color: estadoColor,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '$cancha • $hora',
                      style: const TextStyle(color: Colors.black54, fontSize: 12),
                    ),
                  ],
                ),
              ),
              const Icon(
                Icons.arrow_forward_ios,
                size: 14,
                color: Colors.black38,
              ),
            ],
          ),
        ),
      ),
    );
  }
}