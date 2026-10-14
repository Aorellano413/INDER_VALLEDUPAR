// lib/views/propietario_dashboard_view.dart
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:fl_chart/fl_chart.dart';
import '../controllers/autenticacion_controlador.dart';
import '../controllers/canchas_controlador.dart';
import '../services/firestore_servicio.dart';
import '../routes/app_rutas.dart';
import '../theme/inder_tema.dart';
import '../utils/reserva_estado.dart';
import '../widgets/inder_componentes.dart';
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
      backgroundColor: Colors.transparent,
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

  // ───────────────────────── Estadísticas ─────────────────────────

  Widget _buildGraficaReservas() {
    if (_reservas.isEmpty) {
      return const InderCard(
        child: InderEmptyState(
          icon: Icons.bar_chart_rounded,
          title: 'No hay reservas en este período',
          message: 'Cambia el período para ver otras reservas.',
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

    const titleStyle = TextStyle(
      fontSize: 14,
      fontWeight: FontWeight.w700,
      color: Colors.white,
    );

    return InderCard(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const InderSectionTitle(
            title: 'Estado de reservas',
            subtitle: 'Resumen del período seleccionado',
          ),
          const SizedBox(height: 20),
          SizedBox(
            height: 200,
            child: Stack(
              alignment: Alignment.center,
              children: [
                PieChart(
                  PieChartData(
                    sectionsSpace: 2,
                    centerSpaceRadius: 54,
                    sections: [
                      PieChartSectionData(
                        value: pendientes.toDouble(),
                        title: '$pendientes',
                        showTitle: pendientes > 0,
                        color: InderColors.pendiente,
                        radius: 52,
                        titleStyle: titleStyle,
                      ),
                      PieChartSectionData(
                        value: pagadas.toDouble(),
                        title: '$pagadas',
                        showTitle: pagadas > 0,
                        color: InderColors.pagado,
                        radius: 52,
                        titleStyle: titleStyle,
                      ),
                      PieChartSectionData(
                        value: canceladas.toDouble(),
                        title: '$canceladas',
                        showTitle: canceladas > 0,
                        color: InderColors.cancelado,
                        radius: 52,
                        titleStyle: titleStyle,
                      ),
                    ],
                  ),
                ),
                Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      '${_reservas.length}',
                      style: const TextStyle(
                        fontSize: 26,
                        fontWeight: FontWeight.w700,
                        color: InderColors.ink,
                        height: 1.1,
                      ),
                    ),
                    const Text(
                      'Total',
                      style: TextStyle(
                        fontSize: 12,
                        color: InderColors.textMuted,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              Expanded(
                child: _LegendaItem(
                  estado: ReservaEstado.pendiente,
                  label: 'Pendientes',
                  value: pendientes,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _LegendaItem(
                  estado: ReservaEstado.pagado,
                  label: 'Pagadas',
                  value: pagadas,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _LegendaItem(
                  estado: ReservaEstado.cancelado,
                  label: 'Canceladas',
                  value: canceladas,
                ),
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
    final hPad = InderLayout.hPad(context);
    final user = authController.currentUser;

    return InderThemeScope(
      child: Scaffold(
        appBar: inderAppBar(
          title: _sedeName,
          automaticallyImplyLeading: false,
          actions: [
            IconButton(
              icon: const Icon(Icons.refresh_rounded),
              onPressed: _cargarDatos,
              tooltip: 'Actualizar',
            ),
            TextButton.icon(
              onPressed: _logout,
              icon: const Icon(Icons.logout_rounded, size: 20),
              label: const Text('Salir'),
            ),
            const SizedBox(width: 8),
          ],
        ),
        body: RefreshIndicator(
          onRefresh: _cargarDatos,
          child: ListView(
            padding: EdgeInsets.fromLTRB(hPad, 16, hPad, 96),
            children: [
              InderHeaderBanner(
                titulo: user?.nombre ?? 'Propietario',
                subtitulo: user?.email,
                usuario: user?.nombre,
                detalleUsuario: inderRolLabel(user?.rol),
              ),
              const SizedBox(height: 20),
              _buildFiltrosTiempo(),
              const SizedBox(height: 16),

              if (_loadingEstadisticas)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 48),
                  child: Center(child: CircularProgressIndicator()),
                )
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
        ),
      ),
    );
  }

  Widget _buildFiltrosTiempo() {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          InderFilterChip(
            label: 'Hoy',
            selected: _filtroTiempo == 'hoy',
            onTap: () {
              setState(() => _filtroTiempo = 'hoy');
              _cargarReservas();
            },
          ),
          const SizedBox(width: 8),
          InderFilterChip(
            label: 'Última semana',
            selected: _filtroTiempo == 'semana',
            onTap: () {
              setState(() => _filtroTiempo = 'semana');
              _cargarReservas();
            },
          ),
          const SizedBox(width: 8),
          InderFilterChip(
            label: 'Último mes',
            selected: _filtroTiempo == 'mes',
            onTap: () {
              setState(() => _filtroTiempo = 'mes');
              _cargarReservas();
            },
          ),
          const SizedBox(width: 8),
          InderFilterChip(
            label: 'Último año',
            selected: _filtroTiempo == 'año',
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
    final mostradas = _reservas.length > 10 ? 10 : _reservas.length;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        InderSectionTitle(
          title: 'Reservas',
          subtitle: (!_loadingReservas && _reservas.length > 10)
              ? 'Mostrando $mostradas de ${_reservas.length}'
              : null,
        ),
        const SizedBox(height: 12),
        if (_loadingReservas)
          const Center(
            child: Padding(
              padding: EdgeInsets.all(32),
              child: CircularProgressIndicator(),
            ),
          )
        else if (_reservas.isEmpty)
          const InderEmptyState(
            icon: Icons.event_busy_outlined,
            title: 'No hay reservas en este período',
          )
        else
          ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: mostradas,
            separatorBuilder: (_, __) => const SizedBox(height: 12),
            itemBuilder: (_, index) {
              final reserva = _reservas[index];
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
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: InderColors.border)),
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          child: Row(
            children: [
              const CircleAvatar(
                radius: 18,
                backgroundColor: InderColors.inkSoft,
                child: Icon(Icons.store_rounded,
                    color: InderColors.gold, size: 20),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  authController.currentUser?.nombre ?? 'Propietario',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: InderColors.ink,
                  ),
                ),
              ),
              const Icon(Icons.timer_outlined,
                  size: 18, color: InderColors.textMuted),
              const SizedBox(width: 6),
              Text(
                _elapsedText,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: InderColors.ink,
                  fontFeatures: [FontFeature.tabularFigures()],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ============ WIDGETS AUXILIARES ============

class _LegendaItem extends StatelessWidget {
  final ReservaEstado estado;
  final String label;
  final int value;

  const _LegendaItem({
    required this.estado,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    final style = InderEstadoStyle.of(estado);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
      decoration: BoxDecoration(
        color: style.soft,
        borderRadius: BorderRadius.circular(InderRadius.field),
      ),
      child: Column(
        children: [
          Icon(style.icon, size: 18, color: style.onSoft),
          const SizedBox(height: 4),
          Text(
            '$value',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w700,
              color: style.onSoft,
              height: 1.1,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 11.5,
              fontWeight: FontWeight.w600,
              color: style.onSoft,
            ),
          ),
        ],
      ),
    );
  }
}

class _ReservaCard extends StatelessWidget {
  final Map<String, dynamic> reserva;
  final VoidCallback onTap;

  const _ReservaCard({
    required this.reserva,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final nombre = reserva['nombreCompleto'] ?? 'Sin nombre';
    final inicial = (nombre.isNotEmpty ? nombre.trim()[0] : '?').toUpperCase();
    final hora = reserva['horaReserva'] ?? 'Sin hora';
    final cancha = reserva['cancha'] != null
        ? reserva['cancha']['title'] ?? 'Sin cancha'
        : 'Sin cancha';

    final estado = ReservaEstadoHelper.desdeString(
        (reserva['estado'] ?? 'pendiente').toString());

    return InderCard(
      onTap: onTap,
      child: Row(
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
                const SizedBox(height: 3),
                Row(
                  children: [
                    const Icon(Icons.sports_soccer_outlined,
                        size: 14, color: InderColors.textMuted),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Text(
                        '$cancha • $hora',
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
          const SizedBox(width: 8),
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
}
