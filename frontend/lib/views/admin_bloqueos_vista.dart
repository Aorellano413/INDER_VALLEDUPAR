// lib/views/admin_bloqueos_vista.dart
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/bloqueo_modelo.dart';
import '../models/cancha_modelo.dart';
import '../services/firestore_servicio.dart';
import '../routes/app_rutas.dart';

const Color kDashboardDark = Color(0xFF0F172A);

class AdminBloqueosVista extends StatefulWidget {
  const AdminBloqueosVista({super.key});

  @override
  State<AdminBloqueosVista> createState() => _AdminBloqueosVistaState();
}

class _AdminBloqueosVistaState extends State<AdminBloqueosVista> {
  final FirestoreService _firestore = FirestoreService();
  List<BloqueoModel> _bloqueos = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _cargarBloqueos();
  }

  Future<void> _cargarBloqueos() async {
    if (!mounted) return;
    setState(() => _isLoading = true);

    try {
      _bloqueos = await _firestore.getBloqueos();
    } catch (e) {
      print('❌ ERROR AL CARGAR BLOQUEOS: $e');
      _bloqueos = [];
    }

    if (mounted) {
      setState(() => _isLoading = false);
    }
  }

  void _volverASedes() {
    Navigator.pushNamedAndRemoveUntil(
      context,
      AppRoutes.adminDashboard,
      (route) => false,
    );
  }

  void _mostrarFormulario({BloqueoModel? bloqueo}) async {
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _BloqueoFormSheet(
        bloqueoParaEditar: bloqueo,
        onGuardado: () => _cargarBloqueos(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;
        _volverASedes();
      },
      child: Scaffold(
        backgroundColor: const Color(0xFFF8FAFC),
        appBar: AppBar(
          elevation: 0,
          title: const Text('Bloqueos por Evento',
              style: TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: 18,
                  color: Colors.white)),
          backgroundColor: kDashboardDark,
          foregroundColor: Colors.white,
          centerTitle: true,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: _volverASedes,
          ),
        ),
        body: _isLoading
            ? const Center(
                child: CircularProgressIndicator(color: kDashboardDark))
            : RefreshIndicator(
                onRefresh: _cargarBloqueos,
                child: _bloqueos.isEmpty ? _buildEmpty() : _buildList(),
              ),
        floatingActionButton: FloatingActionButton.extended(
          heroTag: 'btn_admin_bloqueos_unico',
          onPressed: () => _mostrarFormulario(),
          icon: const Icon(Icons.add, color: Colors.white),
          label:
              const Text('NUEVO EVENTO', style: TextStyle(color: Colors.white)),
          backgroundColor: kDashboardDark,
        ),
      ),
    );
  }

  Widget _buildList() {
    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: _bloqueos.length,
      separatorBuilder: (_, __) => const SizedBox(height: 12),
      itemBuilder: (_, i) => _BloqueoCard(
        bloqueo: _bloqueos[i],
        onEditar: () => _mostrarFormulario(bloqueo: _bloqueos[i]),
        onEliminar: () => _confirmarEliminar(_bloqueos[i]),
        onToggle: (activo) async {
          await _firestore.toggleBloqueo(_bloqueos[i].id!, activo);
          _cargarBloqueos();
        },
      ),
    );
  }

  Widget _buildEmpty() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.event_available_outlined,
              size: 80, color: Colors.grey.shade300),
          const SizedBox(height: 16),
          Text('No hay bloqueos activos',
              style: TextStyle(
                  fontSize: 16,
                  color: Colors.grey.shade600,
                  fontWeight: FontWeight.w500)),
        ],
      ),
    );
  }

  Future<void> _confirmarEliminar(BloqueoModel bloqueo) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('¿Eliminar Bloqueo?'),
        content: Text(
            'Se habilitarán las canchas para el evento "${bloqueo.titulo}".'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('CANCELAR')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
                backgroundColor: kDashboardDark, foregroundColor: Colors.white),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('ELIMINAR'),
          ),
        ],
      ),
    );
    if (ok == true) {
      await _firestore.eliminarBloqueo(bloqueo.id!);
      _cargarBloqueos();
    }
  }
}

class _BloqueoFormSheet extends StatefulWidget {
  final BloqueoModel? bloqueoParaEditar;
  final VoidCallback onGuardado;
  const _BloqueoFormSheet({this.bloqueoParaEditar, required this.onGuardado});

  @override
  State<_BloqueoFormSheet> createState() => _BloqueoFormSheetState();
}

class _BloqueoFormSheetState extends State<_BloqueoFormSheet> {
  final _formKey = GlobalKey<FormState>();
  final _tituloCtrl = TextEditingController();
  final _descCtrl = TextEditingController();
  final FirestoreService _firestore = FirestoreService();

  TipoBloqueo _tipo = TipoBloqueo.rangoHorario;
  DateTime? _fechaBloqueo;
  DateTime? _fechaInicio;
  DateTime? _fechaFin;

  List<CanchaModel> _todasLasCanchas = [];
  Set<String> _canchasSeleccionadas = {};
  Set<String> _horasSeleccionadas = {};
  List<String> _horasDisponibles = [];

  bool _isLoading = false;
  bool _cargandoCanchas = true;

  @override
  void initState() {
    super.initState();
    _cargarCanchas();
    if (widget.bloqueoParaEditar != null) {
      final b = widget.bloqueoParaEditar!;
      _tituloCtrl.text = b.titulo;
      _descCtrl.text = b.descripcion ?? '';
      _tipo = b.tipo;
      _fechaBloqueo = b.fechaBloqueo;
      _fechaInicio = b.fechaInicio;
      _fechaFin = b.fechaFin;
      _canchasSeleccionadas = b.canchaIds.toSet();
      _horasSeleccionadas = b.horasEspecificas.toSet();
    } else {
      _horasSeleccionadas = {}; // Inicia completamente vacío para que no marque nada por defecto
    }
  }

  Future<void> _cargarCanchas() async {
    try {
      final sedes = await _firestore.getSedes();
      List<CanchaModel> canchas = [];
      for (var sede in sedes) {
        if (sede.id != null) {
          final c = await _firestore.getCanchasPorSede(sede.id!);
          canchas.addAll(c.map((cancha) =>
              cancha.copyWith(title: '${cancha.title} (${sede.title})')));
        }
      }
      if (mounted) {
        setState(() {
          _todasLasCanchas = canchas;
          _cargandoCanchas = false;
        });
        _generarHorasTotales();
      }
    } catch (e) {
      print('❌ Error al cargar canchas en formulario: $e');
      if (mounted) setState(() => _cargandoCanchas = false);
    }
  }

  int _parsearHora(String texto) {
    try {
      final t = texto.trim().toUpperCase();
      if (t.contains('AM') || t.contains('PM')) {
        final esPM = t.contains('PM');
        final esAM = t.contains('AM');
        final soloHora = t.replaceAll(RegExp(r'[APM\s]'), '').split(':')[0];
        int hora = int.parse(soloHora);
        if (esPM && hora != 12) hora += 12;
        if (esAM && hora == 12) hora = 0;
        return hora;
      }
      return int.parse(texto.trim().split(':')[0]);
    } catch (_) {
      return 8;
    }
  }

  void _generarHorasTotales() {
    if (_canchasSeleccionadas.isEmpty) {
      setState(() => _horasDisponibles = []);
      return;
    }

    int minInicio = 23;
    int maxFin = 0;

    for (final id in _canchasSeleccionadas) {
      try {
        final cancha = _todasLasCanchas.firstWhere((c) => c.id == id);
        final partes = cancha.horario.split(' - ');
        if (partes.length != 2) continue;
        final inicio = _parsearHora(partes[0]);
        final fin = _parsearHora(partes[1]);
        if (inicio < minInicio) minInicio = inicio;
        if (fin > maxFin) maxFin = fin;
      } catch (_) {
        continue;
      }
    }

    if (maxFin <= minInicio) {
      setState(() => _horasDisponibles = []);
      return;
    }

    List<String> listado = [];
    for (int i = 0; i < (maxFin - minInicio); i++) {
      int horaInicioVal = minInicio + i;
      int horaFinVal = horaInicioVal + 1;

      String formatear12H(int h) {
        String periodo = h >= 12 ? 'PM' : 'AM';
        int h12 = h % 12;
        if (h12 == 0) h12 = 12;
        return '${h12.toString().padLeft(2, '0')}:00 $periodo';
      }

      String hInicioStr = formatear12H(horaInicioVal);
      String hFinStr = formatear12H(horaFinVal);

      listado.add('$hInicioStr – $hFinStr');
    }

    setState(() {
      _horasDisponibles = listado;
    });
  }

  void _toggleCancha(String id, bool seleccionada) {
    setState(() {
      if (seleccionada) {
        _canchasSeleccionadas.add(id);
      } else {
        _canchasSeleccionadas.remove(id);
      }
    });
    _generarHorasTotales();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      padding: EdgeInsets.only(
          left: 20,
          right: 20,
          top: 15,
          bottom: MediaQuery.of(context).viewInsets.bottom + 20),
      child: Form(
        key: _formKey,
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                  child: Container(
                      width: 45,
                      height: 5,
                      decoration: BoxDecoration(
                          color: Colors.grey[300],
                          borderRadius: BorderRadius.circular(10)))),
              const SizedBox(height: 20),
              const Text('Gestionar Bloqueo',
                  style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: kDashboardDark)),
              const SizedBox(height: 25),
              TextFormField(
                  controller: _tituloCtrl,
                  decoration: _inputStyle(
                      'Nombre del evento *', Icons.emoji_events_outlined),
                  validator: (v) =>
                      (v == null || v.isEmpty) ? 'Requerido' : null),
              const SizedBox(height: 15),
              TextFormField(
                  controller: _descCtrl,
                  maxLines: 2,
                  decoration:
                      _inputStyle('Descripción (opcional)', Icons.notes)),
              const SizedBox(height: 25),
              Row(
                children: [
                  Expanded(
                      child: _TipoChip(
                          label: 'Día único',
                          icon: Icons.calendar_today,
                          selected: _tipo == TipoBloqueo.rangoHorario,
                          onTap: () =>
                              setState(() => _tipo = TipoBloqueo.rangoHorario))),
                  const SizedBox(width: 12),
                  Expanded(
                      child: _TipoChip(
                          label: 'Rango días',
                          icon: Icons.date_range,
                          selected: _tipo == TipoBloqueo.rangoDias,
                          onTap: () =>
                              setState(() => _tipo = TipoBloqueo.rangoDias))),
                ],
              ),
              const SizedBox(height: 20),
              if (_tipo == TipoBloqueo.rangoHorario)
                _DateTile(
                  label: _fechaBloqueo == null
                      ? 'Seleccionar fecha'
                      : DateFormat('dd/MM/yyyy').format(_fechaBloqueo!),
                  icon: Icons.event,
                  onTap: () async {
                    final p = await showDatePicker(
                        context: context,
                        initialDate: DateTime.now(),
                        firstDate: DateTime.now(),
                        lastDate:
                            DateTime.now().add(const Duration(days: 365)));
                    if (p != null) setState(() => _fechaBloqueo = p);
                  },
                )
              else
                Row(children: [
                  Expanded(
                      child: _DateTile(
                          label: _fechaInicio == null
                              ? 'Inicio'
                              : DateFormat('dd/MM/yyyy').format(_fechaInicio!),
                          icon: Icons.login,
                          onTap: () async {
                            final p = await showDatePicker(
                                context: context,
                                initialDate: DateTime.now(),
                                firstDate: DateTime.now(),
                                lastDate: DateTime.now()
                                    .add(const Duration(days: 365)));
                            if (p != null) setState(() => _fechaInicio = p);
                          })),
                  const SizedBox(width: 10),
                  Expanded(
                      child: _DateTile(
                          label: _fechaFin == null
                              ? 'Fin'
                              : DateFormat('dd/MM/yyyy').format(_fechaFin!),
                          icon: Icons.logout,
                          onTap: () async {
                            final p = await showDatePicker(
                                context: context,
                                initialDate: _fechaInicio ?? DateTime.now(),
                                firstDate: _fechaInicio ?? DateTime.now(),
                                lastDate: DateTime.now()
                                    .add(const Duration(days: 365)));
                            if (p != null) setState(() => _fechaFin = p);
                          })),
                ]),
              const SizedBox(height: 20),
              const Text('Canchas a bloquear *',
                  style: TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(height: 5),
              _buildCanchasSelector(),
              const SizedBox(height: 15),
              const Text('Franjas horarias a bloquear',
                  style: TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(height: 4),
              const Text(
                'Selecciona las franjas exactas que deseas bloquear. Si no marcas ninguna, se bloqueará todo el día.',
                style: TextStyle(fontSize: 12, color: Colors.grey),
              ),
              const SizedBox(height: 10),
              _horasDisponibles.isEmpty
                  ? Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.grey.shade100,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Text(
                          'Selecciona al menos una cancha arriba para ver las horas disponibles',
                          style: TextStyle(fontSize: 13, color: Colors.grey)),
                    )
                  : Column(
                      children: _horasDisponibles.map((franja) {
                        final seleccionado = _horasSeleccionadas.contains(franja);
                        return CheckboxListTile(
                          title: Text(franja, style: const TextStyle(fontSize: 14)),
                          value: seleccionado,
                          activeColor: kDashboardDark,
                          dense: true,
                          onChanged: (bool? value) {
                            setState(() {
                              if (value == true) {
                                _horasSeleccionadas.add(franja);
                              } else {
                                _horasSeleccionadas.remove(franja);
                              }
                            });
                          },
                        );
                      }).toList(),
                    ),
              const SizedBox(height: 30),
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton(
                  onPressed: _isLoading ? null : _guardar,
                  style: ElevatedButton.styleFrom(
                      backgroundColor: kDashboardDark,
                      foregroundColor: Colors.white),
                  child: _isLoading
                      ? const CircularProgressIndicator(color: Colors.white)
                      : const Text('GUARDAR'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  InputDecoration _inputStyle(String label, IconData icon) => InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon),
        filled: true,
        fillColor: const Color(0xFFF1F5F9),
        border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: BorderSide.none),
      );

  Widget _buildCanchasSelector() {
    if (_cargandoCanchas) return const LinearProgressIndicator();
    return Column(
      children: _todasLasCanchas
          .map((c) => CheckboxListTile(
                title: Text(c.title, style: const TextStyle(fontSize: 14)),
                value: _canchasSeleccionadas.contains(c.id),
                activeColor: kDashboardDark,
                onChanged: (v) => _toggleCancha(c.id!, v!),
              ))
          .toList(),
    );
  }

  Future<void> _guardar() async {
    if (!_formKey.currentState!.validate() || _canchasSeleccionadas.isEmpty) {
      return;
    }
    setState(() => _isLoading = true);

    try {
      final b = BloqueoModel(
        id: widget.bloqueoParaEditar?.id,
        titulo: _tituloCtrl.text.trim(),
        descripcion: _descCtrl.text.trim(),
        canchaIds: _canchasSeleccionadas.toList(),
        tipo: _tipo,
        fechaBloqueo: _tipo == TipoBloqueo.rangoHorario ? _fechaBloqueo : null,
        fechaInicio: _tipo == TipoBloqueo.rangoDias ? _fechaInicio : null,
        fechaFin: _tipo == TipoBloqueo.rangoDias ? _fechaFin : null,
        horasEspecificas: _horasSeleccionadas.toList(),
        activo: true,
      );

      if (widget.bloqueoParaEditar != null) {
        await _firestore.actualizarBloqueo(b.id!, b);
      } else {
        await _firestore.crearBloqueo(b);
      }
      if (mounted) {
        Navigator.pop(context);
        widget.onGuardado();
      }
    } catch (e) {
      print('❌ Error al guardar bloqueo: $e');
      if (mounted) setState(() => _isLoading = false);
    }
  }
}

class _TipoChip extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;
  const _TipoChip(
      {required this.label,
      required this.icon,
      required this.selected,
      required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: selected ? const Color(0xFFFDF2F2) : const Color(0xFFF1F5F9),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: selected ? Colors.red : Colors.transparent),
        ),
        child: Column(children: [
          Icon(icon, color: selected ? Colors.red : Colors.grey),
          Text(label,
              style: TextStyle(
                  color: selected ? Colors.red : Colors.grey,
                  fontWeight: FontWeight.bold,
                  fontSize: 12)),
        ]),
      ),
    );
  }
}

class _DateTile extends StatelessWidget {
  final String label;
  final IconData icon;
  final VoidCallback onTap;
  const _DateTile(
      {required this.label, required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
            color: const Color(0xFFF1F5F9),
            borderRadius: BorderRadius.circular(10)),
        child: Row(children: [
          Icon(icon, color: kDashboardDark, size: 20),
          const SizedBox(width: 10),
          Text(label),
          const Spacer(),
          const Icon(Icons.chevron_right, size: 18)
        ]),
      ),
    );
  }
}

class _BloqueoCard extends StatelessWidget {
  final BloqueoModel bloqueo;
  final VoidCallback onEditar;
  final VoidCallback onEliminar;
  final ValueChanged<bool> onToggle;
  const _BloqueoCard(
      {required this.bloqueo,
      required this.onEditar,
      required this.onEliminar,
      required this.onToggle});

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(15),
          side: BorderSide(color: Colors.grey.shade200)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Row(children: [
              const CircleAvatar(
                  backgroundColor: Color(0xFFF1F5F9),
                  child: Icon(Icons.event_busy, color: kDashboardDark)),
              const SizedBox(width: 12),
              Expanded(
                  child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                    Text(bloqueo.titulo,
                        style: const TextStyle(fontWeight: FontWeight.bold)),
                    Text(
                      bloqueo.horasEspecificas.isEmpty
                          ? 'Bloqueado todo el día'
                          : '${bloqueo.horasEspecificas.length} franjas bloqueadas',
                      style: const TextStyle(fontSize: 12, color: Colors.grey),
                    ),
                  ])),
              Switch(
                  value: bloqueo.activo,
                  activeColor: kDashboardDark,
                  onChanged: onToggle),
            ]),
            Row(children: [
              IconButton(
                  icon: const Icon(Icons.edit, size: 20), onPressed: onEditar),
              IconButton(
                  icon: const Icon(Icons.delete, size: 20, color: Colors.red),
                  onPressed: onEliminar),
            ])
          ],
        ),
      ),
    );
  }
}