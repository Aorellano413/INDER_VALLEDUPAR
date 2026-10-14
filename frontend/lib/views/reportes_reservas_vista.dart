// lib/views/reportes_reservas_vista.dart
//
// Reportes de reservas del SuperAdmin.
//
//  - Datos: ReportesServicio → FirestoreService → GET /api/reportes/reservas
//    (backend). Esta pantalla NO consulta Firebase directamente.
//  - Diseño: lib/theme/inder_tema.dart y lib/widgets/inder_componentes.dart.
//  - Acceso: solo SuperAdmin autenticado (con 2FA verificado), según AuthController.
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../controllers/autenticacion_controlador.dart';
import '../models/reporte_reserva_modelo.dart';
import '../models/sede_modelo.dart';
import '../routes/app_rutas.dart';
import '../services/firestore_servicio.dart';
import '../services/reporte_pdf_servicio.dart';
import '../services/reportes_servicio.dart';
import '../theme/inder_tema.dart';
import '../utils/reporte_periodo.dart';
import '../utils/reserva_estado.dart';
import '../widgets/inder_componentes.dart';

class ReportesReservasView extends StatefulWidget {
  const ReportesReservasView({super.key});

  @override
  State<ReportesReservasView> createState() => _ReportesReservasViewState();
}

class _ReportesReservasViewState extends State<ReportesReservasView> {
  /// Valor interno del selector para "Todas las sedes" (en el servicio es null).
  static const String _todasLasSedes = '__todas__';

  /// A partir de este ancho de pantalla se usa la fila tipo tabla.
  static const double _anchoTabla = 720;

  final ReportesServicio _reportes = ReportesServicio();
  final FirestoreService _api = FirestoreService();
  final DateFormat _formatoFecha = DateFormat('dd/MM/yyyy');

  bool _verificandoAcceso = true;

  // Filtros
  List<SedeModel> _sedes = [];
  String? _sedeId; // null = todas las sedes
  RangoReporte _rango = RangoReporte.mes;
  DateTime? _personalizadoInicio;
  DateTime? _personalizadoFin;

  // Resultado mostrado (período y sede con los que se consultó, no los
  // filtros actuales: así tarjetas, tabla y PDF siempre coinciden).
  List<ReporteReservaModel> _reservas = [];
  PeriodoReporte? _periodoConsultado;
  String _sedeConsultada = 'Todas las sedes';

  bool _cargando = true;
  bool _error = false;
  bool _exportando = false;

  /// Identifica la última consulta lanzada: si el usuario cambia de filtro
  /// mientras otra consulta sigue en curso, la respuesta vieja se descarta.
  int _solicitud = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _verificarAcceso());
  }

  // ───────────────────────── Acceso ─────────────────────────

  void _verificarAcceso() {
    if (!mounted) return;
    final auth = context.read<AuthController>();

    if (!auth.isAuthenticated) {
      Navigator.pushReplacementNamed(context, AppRoutes.loginAdmin);
      return;
    }
    if (!auth.isSuperAdmin) {
      Navigator.pushReplacementNamed(context, AppRoutes.propietarioDashboard);
      return;
    }

    setState(() => _verificandoAcceso = false);
    _cargarSedes();
    _cargarReporte();
  }

  // ───────────────────────── Datos ─────────────────────────

  Future<void> _cargarSedes() async {
    try {
      final sedes = await _api.getSedes();
      if (!mounted) return;
      final validas = sedes.where((s) => s.id != null).toList();
      setState(() {
        _sedes = validas;
        if (_sedeId != null && !validas.any((s) => s.id == _sedeId)) {
          _sedeId = null; // la sede seleccionada ya no existe
        }
      });
    } catch (_) {
      _mostrarMensaje(
        'No se pudieron cargar las sedes. El reporte de todas las sedes sigue disponible.',
      );
    }
  }

  Future<void> _cargarReporte() async {
    final solicitud = ++_solicitud;
    final periodo = PeriodoReporte.desde(
      _rango,
      personalizadoInicio: _personalizadoInicio,
      personalizadoFin: _personalizadoFin,
    );
    final sedeId = _sedeId;
    final sedeNombre = _nombreSede(sedeId);

    setState(() {
      _cargando = true;
      _error = false;
    });

    try {
      final reservas = await _reportes.obtenerReporte(
        periodo: periodo,
        sedeId: sedeId,
      );
      if (!mounted || solicitud != _solicitud) return;
      setState(() {
        _reservas = reservas;
        _periodoConsultado = periodo;
        _sedeConsultada = sedeNombre;
        _cargando = false;
      });
    } catch (_) {
      if (!mounted || solicitud != _solicitud) return;
      setState(() {
        _error = true;
        _cargando = false;
      });
    }
  }

  Future<void> _actualizar() async {
    await _cargarSedes();
    await _cargarReporte();
  }

  String _nombreSede(String? id) {
    if (id == null) return 'Todas las sedes';
    for (final sede in _sedes) {
      if (sede.id == id) return sede.title;
    }
    return 'Sede seleccionada';
  }

  // ───────────────────────── Filtros ─────────────────────────

  Future<void> _elegirSede(String? id) async {
    if (id == _sedeId) return;
    setState(() => _sedeId = id);
    await _cargarReporte();
  }

  Future<void> _elegirRango(RangoReporte nuevo) async {
    if (nuevo == RangoReporte.personalizado) {
      await _elegirFechas();
      return;
    }
    if (nuevo == _rango) return;
    setState(() => _rango = nuevo);
    await _cargarReporte();
  }

  Future<void> _elegirFechas() async {
    final hoy = DateTime.now();
    final inicioInicial =
        _personalizadoInicio ?? DateTime(hoy.year, hoy.month, hoy.day);
    final finInicial = _personalizadoFin ?? inicioInicial;

    final elegido = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: DateTime(hoy.year + 2, 12, 31),
      initialDateRange: DateTimeRange(start: inicioInicial, end: finInicial),
      helpText: 'Selecciona el período',
      cancelText: 'Cancelar',
      confirmText: 'Aplicar',
      saveText: 'Aplicar',
      builder: (ctx, child) =>
          InderThemeScope(child: child ?? const SizedBox.shrink()),
    );

    if (elegido == null || !mounted) return;
    setState(() {
      _rango = RangoReporte.personalizado;
      _personalizadoInicio = elegido.start;
      _personalizadoFin = elegido.end;
    });
    await _cargarReporte();
  }

  // ───────────────────────── Exportación ─────────────────────────

  bool get _puedeExportar =>
      !_cargando &&
      !_error &&
      !_exportando &&
      _reservas.isNotEmpty &&
      _periodoConsultado != null;

  Future<void> _exportarPdf() async {
    final periodo = _periodoConsultado;
    if (!_puedeExportar || periodo == null) return;

    setState(() => _exportando = true);
    try {
      await ReportePdfServicio.exportar(
        reservas: _reservas,
        sedeNombre: _sedeConsultada,
        periodo: periodo,
      );
    } catch (_) {
      _mostrarMensaje('No se pudo generar el PDF.');
    } finally {
      if (mounted) setState(() => _exportando = false);
    }
  }

  void _mostrarMensaje(String mensaje) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(mensaje), behavior: SnackBarBehavior.floating),
    );
  }

  // ───────────────────────── Presentación ─────────────────────────

  @override
  Widget build(BuildContext context) {
    if (_verificandoAcceso) {
      return const InderThemeScope(
        child: Scaffold(body: Center(child: CircularProgressIndicator())),
      );
    }

    final hPad = InderLayout.hPad(context);

    return InderThemeScope(
      child: Scaffold(
        appBar: inderAppBar(
          title: 'Reportes de reservas',
          actions: [
            IconButton(
              tooltip: 'Actualizar',
              icon: const Icon(Icons.refresh_rounded),
              onPressed: _cargando ? null : _actualizar,
            ),
            const SizedBox(width: 4),
          ],
        ),
        body: RefreshIndicator(
          onRefresh: _actualizar,
          child: CustomScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            slivers: [
              SliverToBoxAdapter(
                child: Padding(
                  padding: EdgeInsets.fromLTRB(hPad, 16, hPad, 0),
                  child: _buildFiltros(),
                ),
              ),
              ..._buildResultados(hPad),
              const SliverToBoxAdapter(child: SizedBox(height: 32)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFiltros() {
    return InderCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const InderSectionTitle(
            title: 'Filtros',
            subtitle: 'Los resultados se actualizan al cambiar cualquier filtro',
          ),
          const SizedBox(height: InderSpace.lg),
          _buildSelectorSede(),
          const SizedBox(height: InderSpace.lg),
          const Text(
            'Rango de fechas',
            style: TextStyle(
              fontSize: 12.5,
              fontWeight: FontWeight.w600,
              color: InderColors.textMuted,
            ),
          ),
          const SizedBox(height: InderSpace.sm),
          Wrap(
            spacing: InderSpace.sm,
            runSpacing: InderSpace.sm,
            children: [
              InderFilterChip(
                label: 'Hoy',
                selected: _rango == RangoReporte.hoy,
                onTap: () => _elegirRango(RangoReporte.hoy),
              ),
              InderFilterChip(
                label: 'Esta semana',
                selected: _rango == RangoReporte.semana,
                onTap: () => _elegirRango(RangoReporte.semana),
              ),
              InderFilterChip(
                label: 'Este mes',
                selected: _rango == RangoReporte.mes,
                onTap: () => _elegirRango(RangoReporte.mes),
              ),
              InderFilterChip(
                label: 'Personalizado',
                selected: _rango == RangoReporte.personalizado,
                onTap: () => _elegirRango(RangoReporte.personalizado),
              ),
            ],
          ),
          if (_rango == RangoReporte.personalizado) ...[
            const SizedBox(height: InderSpace.md),
            _buildSelectorFechas(),
          ],
        ],
      ),
    );
  }

  Widget _buildSelectorSede() {
    return InputDecorator(
      decoration: const InputDecoration(
        labelText: 'Sede',
        prefixIcon: Icon(Icons.location_city_outlined),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          isExpanded: true,
          isDense: true,
          value: _sedeId ?? _todasLasSedes,
          borderRadius: BorderRadius.circular(InderRadius.field),
          items: [
            const DropdownMenuItem<String>(
              value: _todasLasSedes,
              child: Text('Todas las sedes'),
            ),
            for (final sede in _sedes)
              DropdownMenuItem<String>(
                value: sede.id!,
                child: Text(sede.title, overflow: TextOverflow.ellipsis),
              ),
          ],
          onChanged: (valor) =>
              _elegirSede(valor == null || valor == _todasLasSedes ? null : valor),
        ),
      ),
    );
  }

  Widget _buildSelectorFechas() {
    final inicio = _personalizadoInicio;
    final fin = _personalizadoFin;
    final texto = (inicio != null && fin != null)
        ? 'Desde ${_formatoFecha.format(inicio)} hasta ${_formatoFecha.format(fin)}'
        : 'Selecciona fecha de inicio y fecha final';

    return SizedBox(
      width: double.infinity,
      child: OutlinedButton.icon(
        onPressed: _elegirFechas,
        icon: const Icon(Icons.date_range_rounded, size: 20),
        label: Text(texto),
      ),
    );
  }

  List<Widget> _buildResultados(double hPad) {
    EdgeInsets margen(double arriba, double abajo) =>
        EdgeInsets.fromLTRB(hPad, arriba, hPad, abajo);

    final periodo = _periodoConsultado;

    if (_error) {
      return [
        SliverToBoxAdapter(
          child: Padding(
            padding: margen(16, 0),
            child: InderErrorState(
              message:
                  'No se pudo cargar el reporte. Verifica que el backend esté encendido e intenta de nuevo.',
              onRetry: _cargarReporte,
            ),
          ),
        ),
      ];
    }

    if (_cargando || periodo == null) {
      return [
        SliverToBoxAdapter(
          child: Padding(
            padding: margen(48, 0),
            child: const Center(child: CircularProgressIndicator()),
          ),
        ),
      ];
    }

    final ancha = MediaQuery.of(context).size.width >= _anchoTabla;

    return [
      SliverToBoxAdapter(
        child: Padding(padding: margen(16, 0), child: _buildResumen(periodo)),
      ),
      SliverToBoxAdapter(
        child: Padding(
          padding: margen(24, InderSpace.md),
          child: InderSectionTitle(
            title: 'Reservas del período',
            subtitle: '${_reservas.length} en total',
            trailing: _buildBotonExportar(),
          ),
        ),
      ),
      if (_reservas.isEmpty)
        SliverToBoxAdapter(
          child: Padding(
            padding: margen(0, 0),
            child: const InderEmptyState(
              icon: Icons.event_busy_outlined,
              title: 'No hay reservas para los filtros seleccionados',
              message: 'Prueba con otro período u otra sede.',
            ),
          ),
        )
      else ...[
        if (ancha) SliverToBoxAdapter(child: _buildCabeceraTabla(hPad)),
        SliverPadding(
          padding: margen(0, 0),
          sliver: SliverList(
            delegate: SliverChildBuilderDelegate(
              (context, i) => Padding(
                padding: const EdgeInsets.only(bottom: InderSpace.md),
                child: _FilaReserva(
                  reserva: _reservas[i],
                  ancha: ancha,
                  formato: _formatoFecha,
                ),
              ),
              childCount: _reservas.length,
            ),
          ),
        ),
      ],
    ];
  }

  Widget _buildResumen(PeriodoReporte periodo) {
    final total = _reservas.length;
    final confirmadas = _reservas.where((r) => r.estaConfirmada).length;
    final pendientes = _reservas.where((r) => r.estaPendiente).length;
    final canceladas = _reservas.where((r) => r.estaCancelada).length;

    final pagado = InderEstadoStyle.of(ReservaEstado.pagado);
    final pendiente = InderEstadoStyle.of(ReservaEstado.pendiente);
    final cancelado = InderEstadoStyle.of(ReservaEstado.cancelado);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        LayoutBuilder(
          builder: (context, c) {
            final columnas = c.maxWidth >= 600 ? 4 : 2;
            const separacion = InderSpace.md;
            final ancho = (c.maxWidth - separacion * (columnas - 1)) / columnas;

            Widget tarjeta(_IndicadorTarjeta t) =>
                SizedBox(width: ancho, child: t);

            return Wrap(
              spacing: separacion,
              runSpacing: separacion,
              children: [
                tarjeta(_IndicadorTarjeta(
                  titulo: 'Total de reservas',
                  detalle: 'Todos los estados',
                  valor: total,
                  icono: Icons.event_note_rounded,
                  fondo: InderColors.goldTint,
                  color: InderColors.goldDeep,
                )),
                tarjeta(_IndicadorTarjeta(
                  titulo: 'Confirmadas',
                  detalle: 'Estado: ${ReservaEstado.pagado.label}',
                  valor: confirmadas,
                  icono: pagado.icon,
                  fondo: pagado.soft,
                  color: pagado.onSoft,
                )),
                tarjeta(_IndicadorTarjeta(
                  titulo: 'Pendientes',
                  detalle: 'Estado: ${ReservaEstado.pendiente.label}',
                  valor: pendientes,
                  icono: pendiente.icon,
                  fondo: pendiente.soft,
                  color: pendiente.onSoft,
                )),
                tarjeta(_IndicadorTarjeta(
                  titulo: 'Canceladas',
                  detalle: 'Estado: ${ReservaEstado.cancelado.label}',
                  valor: canceladas,
                  icono: cancelado.icon,
                  fondo: cancelado.soft,
                  color: cancelado.onSoft,
                )),
              ],
            );
          },
        ),
        const SizedBox(height: InderSpace.md),
        Text(
          'Mostrando: $_sedeConsultada  ·  ${periodo.texto}',
          style: const TextStyle(fontSize: 12.5, color: InderColors.textMuted),
        ),
      ],
    );
  }

  Widget _buildBotonExportar() {
    return ElevatedButton.icon(
      onPressed: _puedeExportar ? _exportarPdf : null,
      icon: _exportando
          ? const SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          : const Icon(Icons.picture_as_pdf_outlined, size: 20),
      label: Text(_exportando ? 'Generando...' : 'Exportar PDF'),
    );
  }

  /// Títulos de columna; solo en pantallas anchas. Deben coincidir con
  /// los flex de _FilaReserva._ancha.
  Widget _buildCabeceraTabla(double hPad) {
    const estilo = TextStyle(
      fontSize: 11.5,
      fontWeight: FontWeight.w700,
      letterSpacing: 0.6,
      color: InderColors.textMuted,
    );
    return Padding(
      // 1 px de borde + 16 px de relleno de cada fila
      padding: EdgeInsets.fromLTRB(hPad + 17, 0, hPad + 17, InderSpace.sm),
      child: Row(
        children: const [
          Expanded(flex: 3, child: Text('FECHA Y HORA', style: estilo)),
          Expanded(flex: 3, child: Text('CLIENTE', style: estilo)),
          Expanded(flex: 2, child: Text('SEDE', style: estilo)),
          Expanded(flex: 2, child: Text('CANCHA', style: estilo)),
          SizedBox(width: _FilaReserva.anchoEstado, child: Text('ESTADO', style: estilo)),
        ],
      ),
    );
  }
}

/// Tarjeta de un indicador estadístico.
class _IndicadorTarjeta extends StatelessWidget {
  final String titulo;
  final String detalle;
  final int valor;
  final IconData icono;
  final Color fondo;
  final Color color;

  const _IndicadorTarjeta({
    required this.titulo,
    required this.detalle,
    required this.valor,
    required this.icono,
    required this.fondo,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return MergeSemantics(
      child: InderCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: fondo,
                    borderRadius: BorderRadius.circular(InderRadius.field),
                  ),
                  child: Icon(icono, color: color, size: 22),
                ),
                const SizedBox(width: InderSpace.md),
                Expanded(
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: Alignment.centerLeft,
                    child: Text(
                      '$valor',
                      style: const TextStyle(
                        fontSize: 26,
                        fontWeight: FontWeight.w700,
                        color: InderColors.ink,
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Text(
              titulo,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: InderColors.ink,
              ),
            ),
            Text(
              detalle,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 11.5, color: InderColors.textMuted),
            ),
          ],
        ),
      ),
    );
  }
}

/// Una reserva del reporte. En pantallas anchas se dibuja como fila de tabla;
/// en teléfonos, como tarjeta compacta (mismo estilo que ReservaItem).
class _FilaReserva extends StatelessWidget {
  static const double anchoEstado = 108;

  final ReporteReservaModel reserva;
  final bool ancha;
  final DateFormat formato;

  const _FilaReserva({
    required this.reserva,
    required this.ancha,
    required this.formato,
  });

  String get _fecha =>
      reserva.fecha != null ? formato.format(reserva.fecha!) : '--';
  String get _hora => reserva.hora.isEmpty ? '--' : reserva.hora;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      container: true,
      label: 'Reserva de ${reserva.cliente}. Sede ${reserva.sede}, '
          'cancha ${reserva.cancha}. $_fecha, $_hora. '
          'Estado ${reserva.estado.label}.',
      child: ExcludeSemantics(
        child: InderCard(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: ancha ? _construirAncha() : _construirAngosta(),
        ),
      ),
    );
  }

  Widget _construirAncha() {
    const normal = TextStyle(fontSize: 13, color: InderColors.ink);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Expanded(
          flex: 3,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(_fecha, style: normal.copyWith(fontWeight: FontWeight.w600)),
              Text(
                _hora,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 12.5, color: InderColors.textMuted),
              ),
            ],
          ),
        ),
        Expanded(
          flex: 3,
          child: Text(
            reserva.cliente,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: normal.copyWith(fontWeight: FontWeight.w700),
          ),
        ),
        Expanded(
          flex: 2,
          child: Text(reserva.sede,
              maxLines: 2, overflow: TextOverflow.ellipsis, style: normal),
        ),
        Expanded(
          flex: 2,
          child: Text(reserva.cancha,
              maxLines: 2, overflow: TextOverflow.ellipsis, style: normal),
        ),
        SizedBox(
          width: anchoEstado,
          child: Align(
            alignment: Alignment.centerLeft,
            child: InderEstadoBadge(estado: reserva.estado, compact: true),
          ),
        ),
      ],
    );
  }

  Widget _construirAngosta() {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                reserva.cliente,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: InderColors.ink,
                ),
              ),
              const SizedBox(height: 4),
              _dato(Icons.location_on_outlined, '${reserva.sede}  ·  ${reserva.cancha}'),
              const SizedBox(height: 2),
              _dato(Icons.access_time_rounded, '$_fecha  •  $_hora'),
            ],
          ),
        ),
        const SizedBox(width: InderSpace.sm),
        InderEstadoBadge(estado: reserva.estado, compact: true),
      ],
    );
  }

  Widget _dato(IconData icono, String texto) {
    return Row(
      children: [
        Icon(icono, size: 14, color: InderColors.textMuted),
        const SizedBox(width: 4),
        Expanded(
          child: Text(
            texto,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontSize: 12.5, color: InderColors.textMuted),
          ),
        ),
      ],
    );
  }
}
