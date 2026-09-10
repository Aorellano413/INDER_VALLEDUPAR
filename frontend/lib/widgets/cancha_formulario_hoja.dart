// lib/widgets/cancha_form_sheet.dart
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import '../controllers/canchas_controlador.dart';
import '../models/cancha_modelo.dart';
import '../services/almacenamiento_servicio.dart';

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

  Widget _buildImagePreview() {
    if (_pickedPath.isEmpty) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.add_photo_alternate_outlined,
              size: 40,
              color: Colors.black54,
            ),
            SizedBox(height: 8),
            Text(
              'Subir imagen de la cancha',
              style: TextStyle(color: Colors.black54),
            ),
          ],
        ),
      );
    }

    if (_pickedImage != null) {
      if (kIsWeb) {
        return Image.network(
          _pickedPath,
          fit: BoxFit.cover,
          errorBuilder: (context, error, stackTrace) {
            return Container(
              color: Colors.grey.shade300,
              child: const Icon(Icons.error, size: 64, color: Colors.red),
            );
          },
        );
      } else {
        return Image.file(
          File(_pickedPath),
          fit: BoxFit.cover,
          errorBuilder: (context, error, stackTrace) {
            return Container(
              color: Colors.grey.shade300,
              child: const Icon(Icons.error, size: 64, color: Colors.red),
            );
          },
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
            color: Colors.grey.shade200,
            child: const Center(child: CircularProgressIndicator()),
          );
        },
        errorBuilder: (context, error, stackTrace) {
          return Container(
            color: Colors.grey.shade300,
            child: const Icon(Icons.error, size: 64, color: Colors.red),
          );
        },
      );
    }

    return Image.asset(
      _pickedPath,
      fit: BoxFit.cover,
      errorBuilder: (context, error, stackTrace) {
        return Container(
          color: Colors.grey.shade300,
          child: const Icon(Icons.error, size: 64, color: Colors.red),
        );
      },
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
        backgroundColor: Colors.red,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        left: 16,
        right: 16,
        top: 16,
        bottom: MediaQuery.of(context).viewInsets.bottom + 16,
      ),
      child: Form(
        key: _formKey,
        child: ListView(
          shrinkWrap: true,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 5,
                decoration: BoxDecoration(
                  color: Colors.black12,
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
            ),
            const SizedBox(height: 12),
            Text(
              _esEdicion ? 'Editar Cancha' : 'Crear Nueva Cancha',
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 12),

            // Imagen
            GestureDetector(
              onTap: _seleccionarImagen,
              child: Container(
                height: 170,
                width: double.infinity,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(16),
                  color: const Color(0xFFF2F4F7),
                  border: Border.all(color: const Color(0xFFE0E3E7)),
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(16),
                  child: _buildImagePreview(),
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Nombre
            TextFormField(
              controller: _nombreCtrl,
              decoration: const InputDecoration(
                labelText: 'Nombre de la cancha',
                prefixIcon: Icon(Icons.sports_soccer),
                border: OutlineInputBorder(),
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
                border: OutlineInputBorder(),
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
                border: OutlineInputBorder(),
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
                border: OutlineInputBorder(),
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
                border: OutlineInputBorder(),
                hintText: 'Ej: 5 vs 5, 6 vs 6, 7 vs 7',
              ),
              validator: (v) => (v == null || v.trim().isEmpty)
                  ? 'Ingrese la capacidad'
                  : null,
            ),
            const SizedBox(height: 20),

            // Botón guardar
            SizedBox(
              height: 50,
              child: ElevatedButton.icon(
                onPressed: _isLoading ? null : _guardar,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF0083B0),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                icon: _isLoading
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          color: Colors.white,
                          strokeWidth: 2,
                        ),
                      )
                    : Icon(_esEdicion ? Icons.save : Icons.check_circle),
                label: Text(
                  _isUploading
                      ? 'Subiendo imagen...'
                      : (_esEdicion ? 'Guardar Cambios' : 'Crear Cancha'),
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}