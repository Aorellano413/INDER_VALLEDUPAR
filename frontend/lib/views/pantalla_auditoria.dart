import 'package:flutter/material.dart';
import '../services/firestore_servicio.dart';

const _kPrimary = Color(0xFF101B2E);
const _kFondo = Color(0xFFF5F7FA);

class PantallaAuditoria extends StatefulWidget {
  const PantallaAuditoria({super.key});

  @override
  State<PantallaAuditoria> createState() => _PantallaAuditoriaState();
}

class _PantallaAuditoriaState extends State<PantallaAuditoria> {
  final _servicio = FirestoreService();
  final _busquedaController = TextEditingController();

  List<Map<String, dynamic>> _registros = [];
  bool _cargando = true;
  bool _error = false;
  String _entidad = '';
  String _accion = '';
  String _busqueda = '';

  static const _entidades = ['sede', 'cancha', 'reserva', 'bloqueo'];
  static const _acciones = ['CREAR', 'ACTUALIZAR', 'ELIMINAR'];

  @override
  void initState() {
    super.initState();
    _busquedaController.addListener(() {
      setState(() => _busqueda = _busquedaController.text.trim().toLowerCase());
    });
    _cargar();
  }

  @override
  void dispose() {
    _busquedaController.dispose();
    super.dispose();
  }

  Future<void> _cargar() async {
    setState(() {
      _cargando = true;
      _error = false;
    });
    try {
      final datos = await _servicio.getAuditoria();
      if (!mounted) return;
      setState(() {
        _registros = datos;
        _cargando = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _error = true;
        _cargando = false;
      });
    }
  }

  List<Map<String, dynamic>> get _filtrados {
    return _registros.where((r) {
      if (_entidad.isNotEmpty && r['entidad'] != _entidad) return false;
      if (_accion.isNotEmpty && r['accion'] != _accion) return false;
      if (_busqueda.isNotEmpty) {
        final Map u = r['usuario'] is Map ? r['usuario'] : {};
        final texto = '${u['correo'] ?? ''} ${u['nombre'] ?? ''}'.toLowerCase();
        if (!texto.contains(_busqueda)) return false;
      }
      return true;
    }).toList();
  }

  int _conteo(String accion) => _registros.where((r) => r['accion'] == accion).length;

  String _formatearFecha(dynamic valor) {
    if (valor == null) return '';
    final f = DateTime.tryParse(valor.toString())?.toLocal();
    if (f == null) return valor.toString();
    String d(int n) => n.toString().padLeft(2, '0');
    return '${d(f.day)}/${d(f.month)}/${f.year} ${d(f.hour)}:${d(f.minute)}';
  }

  String _tiempoRelativo(dynamic valor) {
    final f = DateTime.tryParse('$valor')?.toLocal();
    if (f == null) return '';
    final dif = DateTime.now().difference(f);
    if (dif.inMinutes < 1) return 'Justo ahora';
    if (dif.inMinutes < 60) return 'Hace ${dif.inMinutes} min';
    if (dif.inHours < 24) return 'Hace ${dif.inHours} h';
    if (dif.inDays < 7) return 'Hace ${dif.inDays} d';
    return _formatearFecha(valor);
  }

  Color _colorAccion(String accion) {
    switch (accion) {
      case 'CREAR':
        return const Color(0xFF2E7D32);
      case 'ACTUALIZAR':
        return const Color(0xFFEF6C00);
      case 'ELIMINAR':
        return const Color(0xFFC62828);
      default:
        return Colors.grey;
    }
  }

  String _etiquetaAccion(String accion) {
    switch (accion) {
      case 'CREAR':
        return 'Creación';
      case 'ACTUALIZAR':
        return 'Edición';
      case 'ELIMINAR':
        return 'Eliminación';
      default:
        return accion;
    }
  }

  IconData _iconoEntidad(String entidad) {
    switch (entidad) {
      case 'sede':
        return Icons.location_city;
      case 'cancha':
        return Icons.sports_soccer;
      case 'reserva':
        return Icons.event_available;
      case 'bloqueo':
        return Icons.block;
      default:
        return Icons.description_outlined;
    }
  }

  String _capitalizar(String texto) {
    if (texto.isEmpty) return texto;
    return texto[0].toUpperCase() + texto.substring(1);
  }

  String _inicial(Map u) {
    final nombre = '${u['nombre'] ?? ''}'.trim();
    final correo = '${u['correo'] ?? ''}'.trim();
    final base = nombre.isNotEmpty ? nombre : correo;
    return base.isEmpty ? '?' : base[0].toUpperCase();
  }

  String _valor(dynamic v) {
    if (v == null) return '—';
    if (v is bool) return v ? 'Sí' : 'No';
    if (v is List) return v.isEmpty ? '[]' : v.join(', ');
    if (v is String && v.contains('T') && DateTime.tryParse(v) != null) {
      return _formatearFecha(v);
    }
    return '$v';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _kFondo,
      appBar: AppBar(
        backgroundColor: _kPrimary,
        elevation: 0,
        centerTitle: true,
        iconTheme: const IconThemeData(color: Colors.white),
        title: const Text(
          'Auditoría',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _cargar,
          ),
        ],
      ),
      body: _cuerpo(),
    );
  }

  Widget _cuerpo() {
    if (_cargando) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_error) {
      return _estadoVacio(
        Icons.cloud_off_outlined,
        'No se pudo conectar con el servidor',
        'Verifica que el backend esté encendido e intenta de nuevo.',
        reintentar: true,
      );
    }

    final lista = _filtrados;

    return RefreshIndicator(
      onRefresh: _cargar,
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 900),
          child: ListView.builder(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
            itemCount: lista.isEmpty ? 2 : lista.length + 1,
            itemBuilder: (context, i) {
              if (i == 0) return _encabezado();
              if (lista.isEmpty) {
                return Padding(
                  padding: const EdgeInsets.only(top: 40),
                  child: _estadoVacio(
                    Icons.fact_check_outlined,
                    'Sin registros',
                    'No hay movimientos que coincidan con los filtros.',
                  ),
                );
              }
              return _tarjeta(lista[i - 1]);
            },
          ),
        ),
      ),
    );
  }

  Widget _encabezado() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            _tarjetaResumen('Total', _registros.length, Icons.history, _kPrimary),
            const SizedBox(width: 10),
            _tarjetaResumen('Creados', _conteo('CREAR'), Icons.add_circle_outline, _colorAccion('CREAR')),
            const SizedBox(width: 10),
            _tarjetaResumen('Editados', _conteo('ACTUALIZAR'), Icons.edit_outlined, _colorAccion('ACTUALIZAR')),
            const SizedBox(width: 10),
            _tarjetaResumen('Eliminados', _conteo('ELIMINAR'), Icons.delete_outline, _colorAccion('ELIMINAR')),
          ],
        ),
        const SizedBox(height: 16),
        TextField(
          controller: _busquedaController,
          decoration: InputDecoration(
            hintText: 'Buscar por usuario...',
            prefixIcon: const Icon(Icons.search, color: _kPrimary),
            suffixIcon: _busqueda.isNotEmpty
                ? IconButton(
                    icon: const Icon(Icons.clear),
                    onPressed: () => _busquedaController.clear(),
                  )
                : null,
            filled: true,
            fillColor: Colors.white,
            contentPadding: const EdgeInsets.symmetric(vertical: 0),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide.none,
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: Colors.grey.shade200),
            ),
          ),
        ),
        const SizedBox(height: 12),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: [
              _chipFiltro('Todos', _entidad.isEmpty, () => setState(() => _entidad = '')),
              ..._entidades.map(
                (e) => _chipFiltro(
                  _capitalizar(e),
                  _entidad == e,
                  () => setState(() => _entidad = e),
                  icono: _iconoEntidad(e),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 4),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: [
              _chipFiltro('Todas las acciones', _accion.isEmpty, () => setState(() => _accion = '')),
              ..._acciones.map(
                (a) => _chipFiltro(
                  _etiquetaAccion(a),
                  _accion == a,
                  () => setState(() => _accion = a),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
      ],
    );
  }

  Widget _tarjetaResumen(String titulo, int cantidad, IconData icono, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 10),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: Colors.grey.shade200),
        ),
        child: Column(
          children: [
            Icon(icono, color: color, size: 22),
            const SizedBox(height: 6),
            Text(
              '$cantidad',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: color),
            ),
            Text(
              titulo,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
            ),
          ],
        ),
      ),
    );
  }

  Widget _chipFiltro(String etiqueta, bool seleccionado, VoidCallback onTap, {IconData? icono}) {
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: ChoiceChip(
        showCheckmark: false,
        avatar: icono != null
            ? Icon(icono, size: 16, color: seleccionado ? Colors.white : _kPrimary)
            : null,
        label: Text(etiqueta),
        selected: seleccionado,
        onSelected: (_) => onTap(),
        selectedColor: _kPrimary,
        backgroundColor: Colors.white,
        side: BorderSide(color: seleccionado ? _kPrimary : Colors.grey.shade300),
        labelStyle: TextStyle(
          color: seleccionado ? Colors.white : Colors.black87,
          fontWeight: FontWeight.w500,
          fontSize: 13,
        ),
      ),
    );
  }

  Widget _tarjeta(Map<String, dynamic> r) {
    final accion = '${r['accion']}';
    final entidad = '${r['entidad']}';
    final color = _colorAccion(accion);
    final Map u = r['usuario'] is Map ? r['usuario'] : {};
    final correo = '${u['correo'] ?? 'desconocido'}';

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.grey.shade200),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(14),
        child: IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Container(width: 5, color: color),
              Expanded(
                child: Theme(
                  data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
                  child: ExpansionTile(
                    tilePadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
                    childrenPadding: const EdgeInsets.fromLTRB(14, 0, 14, 14),
                    expandedCrossAxisAlignment: CrossAxisAlignment.start,
                    leading: Container(
                      width: 42,
                      height: 42,
                      decoration: BoxDecoration(
                        color: color.withOpacity(0.12),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(_iconoEntidad(entidad), color: color, size: 22),
                    ),
                    title: Wrap(
                      crossAxisAlignment: WrapCrossAlignment.center,
                      spacing: 8,
                      runSpacing: 4,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: color.withOpacity(0.12),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(
                            _etiquetaAccion(accion),
                            style: TextStyle(
                              color: color,
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        Text(
                          _capitalizar(entidad),
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                        ),
                      ],
                    ),
                    subtitle: Padding(
                      padding: const EdgeInsets.only(top: 6),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              CircleAvatar(
                                radius: 9,
                                backgroundColor: _kPrimary,
                                child: Text(
                                  _inicial(u),
                                  style: const TextStyle(fontSize: 10, color: Colors.white),
                                ),
                              ),
                              const SizedBox(width: 6),
                              Expanded(
                                child: Text(
                                  correo,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(fontSize: 13, color: Colors.black87),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 3),
                          Text(
                            _tiempoRelativo(r['fecha']),
                            style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                          ),
                        ],
                      ),
                    ),
                    children: [_detalle(r, accion, u)],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _detalle(Map<String, dynamic> r, String accion, Map u) {
    final cambios = r['cambios'];
    final List<Widget> contenido = [];

    if (cambios is List && cambios.isNotEmpty) {
      contenido.add(_tituloSeccion('Cambios realizados'));
      for (final c in cambios) {
        contenido.add(_filaCambio(c));
      }
    } else {
      final datos = accion == 'ELIMINAR' ? r['antes'] : r['despues'];
      if (datos is Map && datos.isNotEmpty) {
        contenido.add(_tituloSeccion(accion == 'ELIMINAR' ? 'Datos eliminados' : 'Datos creados'));
        for (final e in datos.entries) {
          contenido.add(_filaDato('${e.key}', _valor(e.value)));
        }
      } else {
        contenido.add(Text('Sin detalle', style: TextStyle(color: Colors.grey.shade600)));
      }
    }

    contenido.add(const SizedBox(height: 10));
    contenido.add(
      Text(
        'Fecha: ${_formatearFecha(r['fecha'])}  ·  Rol: ${u['rol'] ?? '—'}  ·  ID: ${r['entidadId'] ?? '—'}',
        style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
      ),
    );

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: _kFondo,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: contenido,
      ),
    );
  }

  Widget _tituloSeccion(String texto) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(
        texto,
        style: const TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.bold,
          color: _kPrimary,
        ),
      ),
    );
  }

  Widget _filaCambio(dynamic c) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '${c['campo']}',
            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 4),
          Wrap(
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: 6,
            runSpacing: 4,
            children: [
              _chipValor(_valor(c['antes']), const Color(0xFFC62828)),
              Icon(Icons.arrow_forward, size: 16, color: Colors.grey.shade600),
              _chipValor(_valor(c['despues']), const Color(0xFF2E7D32)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _chipValor(String texto, Color color) {
    return Container(
      constraints: const BoxConstraints(maxWidth: 320),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        texto,
        style: TextStyle(fontSize: 12, color: color),
      ),
    );
  }

  Widget _filaDato(String clave, String valor) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(
              clave,
              style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
            ),
          ),
          Expanded(
            child: Text(
              valor,
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500),
            ),
          ),
        ],
      ),
    );
  }

  Widget _estadoVacio(IconData icono, String titulo, String detalle, {bool reintentar = false}) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icono, size: 56, color: Colors.grey.shade400),
            const SizedBox(height: 16),
            Text(
              titulo,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 6),
            Text(
              detalle,
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey.shade600),
            ),
            if (reintentar) ...[
              const SizedBox(height: 16),
              ElevatedButton.icon(
                onPressed: _cargar,
                icon: const Icon(Icons.refresh),
                label: const Text('Reintentar'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: _kPrimary,
                  foregroundColor: Colors.white,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}