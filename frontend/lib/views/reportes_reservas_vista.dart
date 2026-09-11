import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../models/reporte_reserva_modelo.dart';
import '../models/sede_modelo.dart';
import '../services/firestore_servicio.dart';
import '../services/reportes_servicio.dart';
import '../services/reporte_pdf_servicio.dart';

const Color _primaryColor = Color(0xFF101B2E);

enum RangoReporte {
  hoy,
  semana,
  mes,
  personalizado,
}

class ReportesReservasView extends StatefulWidget {
  const ReportesReservasView({super.key});

  @override
  State<ReportesReservasView> createState() =>
      _ReportesReservasViewState();
}

class _ReportesReservasViewState
    extends State<ReportesReservasView> {
  final ReportesServicio _reportesServicio =
      ReportesServicio();

  final FirestoreService _firestore =
      FirestoreService();

  final DateFormat _formatoFecha =
      DateFormat('dd/MM/yyyy');

  List<SedeModel> _sedes = [];
  List<ReporteReservaModel> _reservas = [];

  String? _sedeSeleccionada;

  RangoReporte _rangoSeleccionado =
      RangoReporte.mes;

  DateTime? _fechaPersonalizadaInicio;
  DateTime? _fechaPersonalizadaFin;

  bool _cargando = true;
  bool _exportando = false;

  @override
  void initState() {
    super.initState();
    _cargarSedes();
  }

  Future<void> _cargarSedes() async {
    try {
      final sedes = await _firestore.getSedes();

      if (!mounted) return;

      setState(() {
        _sedes = sedes;
      });

      await _cargarReporte();
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _cargando = false;
      });

      _mostrarMensaje(
        'No se pudieron cargar las sedes.',
      );
    }
  }

  Future<void> _cargarReporte() async {
    setState(() {
      _cargando = true;
    });

    try {
      final rango = _obtenerRango();

      final reservas =
          await _reportesServicio.obtenerReporte(
        fechaInicio: rango.$1,
        fechaFin: rango.$2,
        sedeId: _sedeSeleccionada,
      );

      if (!mounted) return;

      setState(() {
        _reservas = reservas;
        _cargando = false;
      });
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _cargando = false;
      });

      _mostrarMensaje(
        'Error al cargar el reporte.',
      );
    }
  }

  (DateTime, DateTime) _obtenerRango() {
    final ahora = DateTime.now();

    switch (_rangoSeleccionado) {
      case RangoReporte.hoy:
        final inicio = DateTime(
          ahora.year,
          ahora.month,
          ahora.day,
        );

        final fin = inicio.add(
          const Duration(days: 1),
        );

        return (inicio, fin);

      case RangoReporte.semana:
        final inicio = DateTime(
          ahora.year,
          ahora.month,
          ahora.day,
        ).subtract(
          Duration(
            days: ahora.weekday - 1,
          ),
        );

        final fin = inicio.add(
          const Duration(days: 7),
        );

        return (inicio, fin);

      case RangoReporte.mes:
        final inicio = DateTime(
          ahora.year,
          ahora.month,
          1,
        );

        final fin = ahora.month == 12
            ? DateTime(
                ahora.year + 1,
                1,
                1,
              )
            : DateTime(
                ahora.year,
                ahora.month + 1,
                1,
              );

        return (inicio, fin);

      case RangoReporte.personalizado:
        final inicio =
            _fechaPersonalizadaInicio ??
                DateTime(
                  ahora.year,
                  ahora.month,
                  ahora.day,
                );

        final fin =
            _fechaPersonalizadaFin ??
                inicio;

        return (
          DateTime(
            inicio.year,
            inicio.month,
            inicio.day,
          ),
          DateTime(
            fin.year,
            fin.month,
            fin.day,
          ).add(
            const Duration(days: 1),
          ),
        );
    }
  }

  int get _total => _reservas.length;

  int get _confirmadas =>
      _reservas
          .where((r) => r.estaConfirmada)
          .length;

  int get _pendientes =>
      _reservas
          .where((r) => r.estaPendiente)
          .length;

  int get _canceladas =>
      _reservas
          .where((r) => r.estaCancelada)
          .length;

  String get _nombreSedeSeleccionada {
    if (_sedeSeleccionada == null) {
      return 'Todas las sedes';
    }

    final sede = _sedes.firstWhere(
      (s) => s.id == _sedeSeleccionada,
      orElse: () => SedeModel(
        imagePath: '',
        title: 'Sede',
        subtitle: '',
        price: '',
        tag: '',
      ),
    );

    return sede.title;
  }

  Future<void> _seleccionarFechas() async {
    final ahora = DateTime.now();

    final rango = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: DateTime(
        ahora.year + 2,
        12,
        31,
      ),
      initialDateRange:
          _fechaPersonalizadaInicio != null &&
                  _fechaPersonalizadaFin != null
              ? DateTimeRange(
                  start: _fechaPersonalizadaInicio!,
                  end: _fechaPersonalizadaFin!,
                )
              : DateTimeRange(
                  start: DateTime(
                    ahora.year,
                    ahora.month,
                    ahora.day,
                  ),
                  end: DateTime(
                    ahora.year,
                    ahora.month,
                    ahora.day,
                  ),
                ),
    );

    if (rango == null) return;

    setState(() {
      _rangoSeleccionado =
          RangoReporte.personalizado;

      _fechaPersonalizadaInicio =
          rango.start;

      _fechaPersonalizadaFin =
          rango.end;
    });

    await _cargarReporte();
  }

  Future<void> _exportarPDF() async {
    if (_reservas.isEmpty) {
      _mostrarMensaje(
        'No hay reservas para exportar.',
      );
      return;
    }

    setState(() {
      _exportando = true;
    });

    try {
      final rango = _obtenerRango();

      await ReportePdfServicio.exportar(
        reservas: _reservas,
        sedeNombre: _nombreSedeSeleccionada,
        fechaInicio: rango.$1,
        fechaFin: rango.$2,
      );
    } catch (e) {
      _mostrarMensaje(
        'No se pudo generar el PDF.',
      );
    } finally {
      if (mounted) {
        setState(() {
          _exportando = false;
        });
      }
    }
  }

  String _textoRango() {
    switch (_rangoSeleccionado) {
      case RangoReporte.hoy:
        return 'Hoy';

      case RangoReporte.semana:
        return 'Esta semana';

      case RangoReporte.mes:
        return 'Este mes';

      case RangoReporte.personalizado:
        if (_fechaPersonalizadaInicio != null &&
            _fechaPersonalizadaFin != null) {
          return '${_formatoFecha.format(_fechaPersonalizadaInicio!)} - ${_formatoFecha.format(_fechaPersonalizadaFin!)}';
        }

        return 'Personalizado';
    }
  }

  Widget _buildIndicador({
    required String titulo,
    required int valor,
    required IconData icono,
  }) {
    return Expanded(
      child: Card(
        elevation: 0,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Container(
                width: 45,
                height: 45,
                decoration: BoxDecoration(
                  color:
                      _primaryColor.withOpacity(0.08),
                  borderRadius:
                      BorderRadius.circular(12),
                ),
                child: Icon(
                  icono,
                  color: _primaryColor,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment:
                      CrossAxisAlignment.start,
                  children: [
                    Text(
                      titulo,
                      style: const TextStyle(
                        fontSize: 13,
                        color: Colors.grey,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      valor.toString(),
                      style: const TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFiltros() {
    return Card(
      elevation: 0,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment:
              CrossAxisAlignment.start,
          children: [
            const Text(
              'Filtros del reporte',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            Wrap(
              spacing: 16,
              runSpacing: 16,
              children: [
                SizedBox(
                  width: 280,
                  child: DropdownButtonFormField<String?>(
                    value: _sedeSeleccionada,
                    decoration:
                        const InputDecoration(
                      labelText: 'Sede',
                      border: OutlineInputBorder(),
                      prefixIcon:
                          Icon(Icons.location_city),
                    ),
                    items: [
                      const DropdownMenuItem<String?>(
                        value: null,
                        child: Text(
                          'Todas las sedes',
                        ),
                      ),
                      ..._sedes.map(
                        (sede) =>
                            DropdownMenuItem<String?>(
                          value: sede.id,
                          child: Text(
                            sede.title,
                            overflow:
                                TextOverflow.ellipsis,
                          ),
                        ),
                      ),
                    ],
                    onChanged: (value) async {
                      setState(() {
                        _sedeSeleccionada =
                            value;
                      });

                      await _cargarReporte();
                    },
                  ),
                ),
                SizedBox(
                  width: 280,
                  child:
                      DropdownButtonFormField<RangoReporte>(
                    value: _rangoSeleccionado,
                    decoration:
                        const InputDecoration(
                      labelText: 'Rango de fechas',
                      border: OutlineInputBorder(),
                      prefixIcon:
                          Icon(Icons.date_range),
                    ),
                    items: const [
                      DropdownMenuItem(
                        value: RangoReporte.hoy,
                        child: Text('Hoy'),
                      ),
                      DropdownMenuItem(
                        value: RangoReporte.semana,
                        child:
                            Text('Esta semana'),
                      ),
                      DropdownMenuItem(
                        value: RangoReporte.mes,
                        child: Text('Este mes'),
                      ),
                      DropdownMenuItem(
                        value:
                            RangoReporte.personalizado,
                        child:
                            Text('Personalizado'),
                      ),
                    ],
                    onChanged: (value) async {
                      if (value == null) return;

                      if (value ==
                          RangoReporte.personalizado) {
                        await _seleccionarFechas();
                        return;
                      }

                      setState(() {
                        _rangoSeleccionado =
                            value;
                      });

                      await _cargarReporte();
                    },
                  ),
                ),
                if (_rangoSeleccionado ==
                    RangoReporte.personalizado)
                  OutlinedButton.icon(
                    onPressed:
                        _seleccionarFechas,
                    icon: const Icon(
                      Icons.calendar_month,
                    ),
                    label: Text(
                      _textoRango(),
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTabla() {
    if (_reservas.isEmpty) {
      return const Card(
        elevation: 0,
        child: Padding(
          padding: EdgeInsets.all(40),
          child: Center(
            child: Column(
              children: [
                Icon(
                  Icons.event_busy,
                  size: 50,
                  color: Colors.grey,
                ),
                SizedBox(height: 12),
                Text(
                  'No hay reservas para los filtros seleccionados.',
                ),
              ],
            ),
          ),
        ),
      );
    }

    return Card(
      elevation: 0,
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: DataTable(
          headingRowColor:
              WidgetStateProperty.all(
            _primaryColor.withOpacity(0.06),
          ),
          columns: const [
            DataColumn(
              label: Text('Fecha'),
            ),
            DataColumn(
              label: Text('Hora'),
            ),
            DataColumn(
              label: Text('Cliente'),
            ),
            DataColumn(
              label: Text('Sede'),
            ),
            DataColumn(
              label: Text('Cancha'),
            ),
            DataColumn(
              label: Text('Estado'),
            ),
          ],
          rows: _reservas.map((reserva) {
            return DataRow(
              cells: [
                DataCell(
                  Text(
                    reserva.fecha != null
                        ? _formatoFecha.format(
                            reserva.fecha!,
                          )
                        : '--',
                  ),
                ),
                DataCell(
                  Text(reserva.hora),
                ),
                DataCell(
                  Text(reserva.cliente),
                ),
                DataCell(
                  Text(reserva.sede),
                ),
                DataCell(
                  Text(reserva.cancha),
                ),
                DataCell(
                  _buildEstado(reserva),
                ),
              ],
            );
          }).toList(),
        ),
      ),
    );
  }

  Widget _buildEstado(
    ReporteReservaModel reserva,
  ) {
    Color color;
    String texto;

    if (reserva.estaConfirmada) {
      color = Colors.green;
      texto = 'Confirmada';
    } else if (reserva.estaPendiente) {
      color = Colors.orange;
      texto = 'Pendiente';
    } else if (reserva.estaCancelada) {
      color = Colors.red;
      texto = 'Cancelada';
    } else {
      color = Colors.grey;
      texto = reserva.estadoVisual;
    }

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: 10,
        vertical: 6,
      ),
      decoration: BoxDecoration(
        color: color.withOpacity(0.10),
        borderRadius:
            BorderRadius.circular(20),
      ),
      child: Text(
        texto,
        style: TextStyle(
          color: color,
          fontWeight: FontWeight.bold,
          fontSize: 12,
        ),
      ),
    );
  }

  void _mostrarMensaje(String mensaje) {
    if (!mounted) return;

    ScaffoldMessenger.of(context)
        .showSnackBar(
      SnackBar(
        content: Text(mensaje),
        behavior:
            SnackBarBehavior.floating,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor:
          const Color(0xFFF5F7FA),
      appBar: AppBar(
        backgroundColor: _primaryColor,
        foregroundColor: Colors.white,
        title: const Text(
          'Reportes de reservas',
        ),
        actions: [
          IconButton(
            tooltip: 'Actualizar',
            onPressed:
                _cargando ? null : _cargarReporte,
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: _cargando
          ? const Center(
              child:
                  CircularProgressIndicator(),
            )
          : RefreshIndicator(
              onRefresh: _cargarReporte,
              child: ListView(
                padding:
                    const EdgeInsets.all(16),
                children: [
                  _buildFiltros(),
                  const SizedBox(height: 16),

                  Row(
                    children: [
                      _buildIndicador(
                        titulo: 'Total reservas',
                        valor: _total,
                        icono:
                            Icons.event_available,
                      ),
                      const SizedBox(width: 12),
                      _buildIndicador(
                        titulo: 'Confirmadas',
                        valor: _confirmadas,
                        icono:
                            Icons.check_circle,
                      ),
                      const SizedBox(width: 12),
                      _buildIndicador(
                        titulo: 'Pendientes',
                        valor: _pendientes,
                        icono:
                            Icons.pending_actions,
                      ),
                      const SizedBox(width: 12),
                      _buildIndicador(
                        titulo: 'Canceladas',
                        valor: _canceladas,
                        icono:
                            Icons.cancel,
                      ),
                    ],
                  ),

                  const SizedBox(height: 16),

                  Row(
                    mainAxisAlignment:
                        MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Resumen de reservas',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight:
                              FontWeight.bold,
                        ),
                      ),
                      ElevatedButton.icon(
                        onPressed: _exportando
                            ? null
                            : _exportarPDF,
                        style:
                            ElevatedButton.styleFrom(
                          backgroundColor:
                              _primaryColor,
                          foregroundColor:
                              Colors.white,
                        ),
                        icon: _exportando
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child:
                                    CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color:
                                      Colors.white,
                                ),
                              )
                            : const Icon(
                                Icons.picture_as_pdf,
                              ),
                        label: Text(
                          _exportando
                              ? 'Generando...'
                              : 'Exportar PDF',
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 12),

                  _buildTabla(),
                ],
              ),
            ),
    );
  }
}