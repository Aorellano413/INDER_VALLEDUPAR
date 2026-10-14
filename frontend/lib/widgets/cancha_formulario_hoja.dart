// lib/widgets/cancha_form_sheet.dart
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import '../controllers/canchas_controlador.dart';
import '../models/cancha_modelo.dart';
import '../services/almacenamiento_servicio.dart';
import '../theme/inder_tema.dart';
import 'inder_componentes.dart';

class CanchaFormSheet extends StatefulWidget {
  final String sedeId;
  final CanchaModel? canchaParaEditar;
  final VoidCallback onGuardado;

  const CanchaFormSheet({
    super.key,
    required this.sedeId,
    this.canchaParaEditar,
    required this.onGuardado,
  });

  @override
  State<CanchaFormSheet> createState() => _CanchaFormSheetState();
}

class _CanchaFormSheetState extends State<CanchaFormSheet> {
  final _formKey = GlobalKey<FormState>();
  final _nombreCtrl = TextEditingController();
  final _precioCtrl = TextEditingController();
  final _horarioCtrl = TextEditingController();
  final _jugadoresCtrl = TextEditingController();

  TipoCancha _tipoSeleccionado = TipoCancha.abierta;
  String _pickedPath = '';
  XFile? _pickedImage;
  bool _isLoading = false;
  bool _isUploading = false;

  bool get _esEdicion => widget.canchaParaEditar != null;

  @override
  void initState() {
    super.initState();
    if (_esEdicion) {
      _nombreCtrl.text = widget.canchaParaEditar!.title;
      _precioCtrl.text = widget.canchaParaEditar!.price.replaceAll(RegExp(r'[^0-9]'), '');
      _horarioCtrl.text = widget.canchaParaEditar!.horario;
      _jugadoresCtrl.text = widget.canchaParaEditar!.jugadores;
      _tipoSeleccionado = widget.canchaParaEditar!.tipo;
      _pickedPath = widget.canchaParaEditar!.image;
    } else {
      _horarioCtrl.text = '7:00 AM - 11:00 PM';
      _jugadoresCtrl.text = '5 vs 5';
    }
  }

  @override
  void dispose() {
    _nombreCtrl.dispose();
    _precioCtrl.dispose();
    _horarioCtrl.dispose();
    _jugadoresCtrl.dispose();
    super.dispose();
  }

  Future<void> _seleccionarImagen() async {
    final imagen = await ImagePicker().pickImage(
      source: ImageSource.gallery,
      imageQuality: 85,
    );
    if (imagen != null) {
      setState(() {
        _pickedPath = imagen.path;
        _pickedImage = imagen;
      });
    }
  }

  Widget _errorImagen() => Container(
        color: InderColors.canceladoSoft,
        child: const Center(
          child: Icon(Icons.broken_image_outlined,
              size: 48, color: InderColors.canceladoOnSoft),
        ),
      );

  Widget _buildImagePreview() {
    if (_pickedPath.isEmpty) {
      return const InderImagePlaceholder(title: 'Subir imagen de la cancha');
    }

    if (_pickedImage != null) {
      if (kIsWeb) {
        return Image.network(
          _pickedPath,
          fit: BoxFit.cover,
          errorBuilder: (context, error, stackTrace) => _errorImagen(),
        );
      } else {
        return Image.file(
          File(_pickedPath),
          fit: BoxFit.cover,
          errorBuilder: (context, error, stackTrace) => _errorImagen(),
        );
      }
    }
    if (_pickedPath.startsWith('http://') || _pickedPath.startsWith('https://')) {
      return Image.network(
        _pickedPath,
        fit: BoxFit.cover,
        loadingBuilder: (context, child, loadingProgress) {
          if (loadingProgress == null) return child;
          return Container(
            color: InderColors.background,
            child: const Center(child: CircularProgressIndicator()),
          );
        },
        errorBuilder: (context, error, stackTrace) => _errorImagen(),
      );
    }

    return Image.asset(
      _pickedPath,
      fit: BoxFit.cover,
      errorBuilder: (context, error, stackTrace) => _errorImagen(),
    );
  }

  Future<void> _guardar() async {
    if (!_formKey.currentState!.validate()) return;

    if (_pickedPath.isEmpty) {
      _mostrarError('Seleccione una imagen para la cancha');
      return;
    }

    if (_pickedImage == null && !_esEdicion) {
      _mostrarError('Debe seleccionar una imagen nueva');
      return;
    }

    setState(() {
      _isLoading = true;
      _isUploading = true;
    });

    final controller = Provider.of<CanchasController>(context, listen: false);
    final storageService = StorageService();

    try {
      String imageUrl = _pickedPath;

      final necesitaSubir = _pickedImage != null ||
                            !storageService.esUrlFirebase(_pickedPath);

      if (necesitaSubir) {
        if (_pickedImage == null) {
          _mostrarError('Debe seleccionar una imagen válida');
          setState(() {
            _isLoading = false;
            _isUploading = false;
          });
          return;
        }

        final canchaId = _esEdicion && widget.canchaParaEditar!.id != null
            ? widget.canchaParaEditar!.id!
            : DateTime.now().millisecondsSinceEpoch.toString();

        print('📤 Subiendo imagen a Firebase Storage...');

        imageUrl = await storageService.subirImagenCancha(
          canchaId: canchaId,
          imageFile: _pickedImage!,
        );

        print('✅ Imagen subida exitosamente: $imageUrl');

        if (_esEdicion &&
            widget.canchaParaEditar!.image.isNotEmpty &&
            storageService.esUrlFirebase(widget.canchaParaEditar!.image)) {
          print('🗑️ Eliminando imagen anterior...');
          await storageService.eliminarImagen(widget.canchaParaEditar!.image);
        }
      }

      final precioFormateado = '\$${_precioCtrl.text.trim()} COP';

      final canchaModel = CanchaModel(
        id: _esEdicion ? widget.canchaParaEditar!.id : null,
        sedeId: widget.sedeId,
        image: imageUrl,
        title: _nombreCtrl.text.trim(),
        price: precioFormateado,
        horario: _horarioCtrl.text.trim(),
        tipo: _tipoSeleccionado,
        jugadores: _jugadoresCtrl.text.trim(),
      );

      print('💾 Guardando en Firestore: ${canchaModel.toJson()}');

      if (_esEdicion && widget.canchaParaEditar!.id != null) {
        await controller.actualizarCancha(
          widget.canchaParaEditar!.id!,
          canchaModel,
        );
      } else {
        await controller.agregarCancha(canchaModel);
      }

      if (mounted) {
        widget.onGuardado();
      }
    } catch (e) {
      print('❌ Error al guardar: $e');
      _mostrarError('Error al guardar: $e');
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _isUploading = false;
        });
      }
    }
  }

  void _mostrarError(String mensaje) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(mensaje),
        backgroundColor: InderColors.cancelado,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return InderThemeScope(
      child: Padding(
        padding: EdgeInsets.only(
          left: 24,
          right: 24,
          top: 12,
          bottom: MediaQuery.of(context).viewInsets.bottom + 24,
        ),
        child: Form(
          key: _formKey,
          child: ListView(
            shrinkWrap: true,
            children: [
              InderSheetHeader(
                icon: Icons.sports_soccer_rounded,
                title: _esEdicion ? 'Editar Cancha' : 'Crear Nueva Cancha',
                subtitle: 'Información que verán los clientes',
              ),
              const SizedBox(height: 20),

              // Imagen
              GestureDetector(
                onTap: _seleccionarImagen,
                child: Container(
                  height: 170,
                  width: double.infinity,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(InderRadius.card),
                    color: InderColors.background,
                    border: Border.all(
                      color: _pickedPath.isEmpty
                          ? InderColors.borderStrong
                          : Colors.transparent,
                      width: _pickedPath.isEmpty ? 1.2 : 0,
                    ),
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(InderRadius.card),
                    child: _buildImagePreview(),
                  ),
                ),
              ),
              const SizedBox(height: 20),

              // Nombre
              TextFormField(
                controller: _nombreCtrl,
                decoration: const InputDecoration(
                  labelText: 'Nombre de la cancha',
                  prefixIcon: Icon(Icons.sports_soccer),
                  hintText: 'Ej: Cancha Techada #1',
                ),
                validator: (v) =>
                    (v == null || v.trim().isEmpty) ? 'Ingrese el nombre' : null,
              ),
              const SizedBox(height: 12),

              // Tipo de cancha
              DropdownButtonFormField<TipoCancha>(
                value: _tipoSeleccionado,
                decoration: const InputDecoration(
                  labelText: 'Tipo de cancha',
                  prefixIcon: Icon(Icons.category),
                ),
                items: const [
                  DropdownMenuItem(
                    value: TipoCancha.abierta,
                    child: Text('Abierta'),
                  ),
                  DropdownMenuItem(
                    value: TipoCancha.cerrada,
                    child: Text('Cerrada'),
                  ),
                  DropdownMenuItem(
                    value: TipoCancha.techada,
                    child: Text('Techada'),
                  ),
                  DropdownMenuItem(
                    value: TipoCancha.natural,
                    child: Text('Natural'),
                  ),
                  DropdownMenuItem(
                    value: TipoCancha.sintetica,
                    child: Text('Sintética'),
                  ),
                ],
                onChanged: (value) {
                  if (value != null) {
                    setState(() => _tipoSeleccionado = value);
                  }
                },
              ),
              const SizedBox(height: 12),

              // Precio
              TextFormField(
                controller: _precioCtrl,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'Precio (COP)',
                  prefixIcon: Icon(Icons.attach_money),
                  hintText: 'Ej: 80000',
                  helperText: 'Solo números, sin puntos ni comas',
                ),
                validator: (v) {
                  if (v == null || v.trim().isEmpty) {
                    return 'Ingrese el precio';
                  }
                  if (int.tryParse(v.trim()) == null) {
                    return 'Ingrese solo números';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 12),

              // Horario
              TextFormField(
                controller: _horarioCtrl,
                decoration: const InputDecoration(
                  labelText: 'Horario',
                  prefixIcon: Icon(Icons.access_time),
                  hintText: 'Ej: 7:00 AM - 11:00 PM',
                ),
                validator: (v) =>
                    (v == null || v.trim().isEmpty) ? 'Ingrese el horario' : null,
              ),
              const SizedBox(height: 12),

              // Jugadores
              TextFormField(
                controller: _jugadoresCtrl,
                decoration: const InputDecoration(
                  labelText: 'Capacidad de jugadores',
                  prefixIcon: Icon(Icons.people),
                  hintText: 'Ej: 5 vs 5, 6 vs 6, 7 vs 7',
                ),
                validator: (v) => (v == null || v.trim().isEmpty)
                    ? 'Ingrese la capacidad'
                    : null,
              ),
              const SizedBox(height: 24),

              // Botón guardar
              SizedBox(
                height: 52,
                child: ElevatedButton.icon(
                  onPressed: _isLoading ? null : _guardar,
                  icon: _isLoading
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            color: InderColors.textMuted,
                            strokeWidth: 2,
                          ),
                        )
                      : Icon(_esEdicion ? Icons.save : Icons.check_circle),
                  label: Text(
                    _isUploading
                        ? 'Subiendo imagen...'
                        : (_esEdicion ? 'Guardar Cambios' : 'Crear Cancha'),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
