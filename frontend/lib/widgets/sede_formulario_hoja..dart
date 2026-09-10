import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import '../controllers/sedes_controlador.dart';
import '../models/sede_modelo.dart';
import '../utils/formato_utilidades.dart';
import '../services/almacenamiento_servicio.dart';

class SedeFormSheet extends StatefulWidget {
  final SedeModel? sedeParaEditar;
  final int? editIndex;
  final Function(String mensaje) onGuardado;

  const SedeFormSheet({
    super.key,
    this.sedeParaEditar,
    this.editIndex,
    required this.onGuardado,
  });

  @override
  State<SedeFormSheet> createState() => _SedeFormSheetState();
}

class _SedeFormSheetState extends State<SedeFormSheet> {
  final _formKey = GlobalKey<FormState>();
  final _nombreCtrl = TextEditingController();
  final _direccionCtrl = TextEditingController();
  final _precioCtrl = TextEditingController();
  String _pickedPath = '';
  XFile? _pickedImage;
  bool _isUploading = false;

  bool get _esEdicion => widget.sedeParaEditar != null;

  @override
  void initState() {
    super.initState();
    if (_esEdicion) {
      _nombreCtrl.text = widget.sedeParaEditar!.title.replaceFirst('Sede - ', '');
      _direccionCtrl.text = widget.sedeParaEditar!.subtitle;
      _precioCtrl.text = widget.sedeParaEditar!.price.replaceAll(RegExp(r'[^0-9]'), '');
      _pickedPath = widget.sedeParaEditar!.imagePath;
    }
  }

  @override
  void dispose() {
    _nombreCtrl.dispose();
    _direccionCtrl.dispose();
    _precioCtrl.dispose();
    super.dispose();
  }

  Future<void> _seleccionarImagen() async {
    final imagen = await ImagePicker().pickImage(source: ImageSource.gallery, imageQuality: 85);
    if (imagen != null) {
      setState(() {
        _pickedPath = imagen.path;
        _pickedImage = imagen;
      });
    }
  }

  Widget _buildImagePreview() {
    if (_pickedPath.isEmpty) {
      return Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              color: const Color(0xFF0083B0).withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.add_a_photo_outlined, size: 26, color: Color(0xFF0083B0)),
          ),
          const SizedBox(height: 10),
          const Text('Subir imagen de la sede', style: TextStyle(color: Color(0xFF64748B), fontSize: 13, fontWeight: FontWeight.w500)),
          const SizedBox(height: 4),
          const Text('Toca para seleccionar', style: TextStyle(color: Color(0xFF94A3B8), fontSize: 11)),
        ],
      );
    }

    Widget imageWidget;
    if (_pickedImage != null) {
      imageWidget = kIsWeb
          ? Image.network(_pickedPath, fit: BoxFit.cover)
          : Image.file(File(_pickedPath), fit: BoxFit.cover);
    } else if (_pickedPath.startsWith('http')) {
      imageWidget = Image.network(_pickedPath, fit: BoxFit.cover,
        loadingBuilder: (_, child, progress) =>
            progress == null ? child : const Center(child: CircularProgressIndicator()));
    } else {
      imageWidget = Image.asset(_pickedPath, fit: BoxFit.cover);
    }

    return Stack(
      fit: StackFit.expand,
      children: [
        imageWidget,
        Positioned(
          bottom: 10,
          right: 10,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: Colors.black.withOpacity(0.6),
              borderRadius: BorderRadius.circular(20),
            ),
            child: const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.edit_rounded, size: 12, color: Colors.white),
                SizedBox(width: 4),
                Text('Cambiar', style: TextStyle(color: Colors.white, fontSize: 11)),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Future<void> _guardarSede() async {
    if (!_formKey.currentState!.validate()) return;
    if (_pickedPath.isEmpty) {
      _mostrarError('Selecciona una imagen para la sede');
      return;
    }
    if (_pickedImage == null && !_esEdicion) {
      _mostrarError('Debe seleccionar una imagen nueva');
      return;
    }

    setState(() => _isUploading = true);

    final controller = Provider.of<SedesController>(context, listen: false);
    final storageService = StorageService();

    try {
      String imageUrl = _pickedPath;
      final necesitaSubir = _pickedImage != null || !storageService.esUrlFirebase(_pickedPath);

      if (necesitaSubir) {
        if (_pickedImage == null) {
          _mostrarError('Debe seleccionar una imagen válida');
          setState(() => _isUploading = false);
          return;
        }
        final sedeId = _esEdicion && widget.sedeParaEditar!.id != null
            ? widget.sedeParaEditar!.id!
            : DateTime.now().millisecondsSinceEpoch.toString();

        imageUrl = await storageService.subirImagenSede(sedeId: sedeId, imageFile: _pickedImage!);

        if (_esEdicion &&
            widget.sedeParaEditar!.imagePath.isNotEmpty &&
            storageService.esUrlFirebase(widget.sedeParaEditar!.imagePath)) {
          await storageService.eliminarImagen(widget.sedeParaEditar!.imagePath);
        }
      }

      final sedeModel = SedeModel(
        imagePath: imageUrl,
        title: "Sede - ${_nombreCtrl.text.trim()}",
        subtitle: _direccionCtrl.text.trim(),
        price: FormatoHelpers.formatearCOP(_precioCtrl.text),
        tag: 'Día - Noche',
        isCustom: true,
      );

      if (_esEdicion && widget.editIndex != null) {
        await controller.actualizarSedeCustom(widget.editIndex!, sedeModel);
      } else {
        await controller.agregarSede(sedeModel);
      }

      if (mounted) {
        Navigator.pop(context);
        widget.onGuardado(_esEdicion ? 'Sede actualizada exitosamente' : 'Sede creada exitosamente');
      }
    } catch (e) {
      _mostrarError('Error al guardar: $e');
    } finally {
      if (mounted) setState(() => _isUploading = false);
    }
  }

  void _mostrarError(String mensaje) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(mensaje), backgroundColor: Colors.redAccent, behavior: SnackBarBehavior.floating),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.only(
        left: 24, right: 24, top: 12,
        bottom: MediaQuery.of(context).viewInsets.bottom + 24,
      ),
      child: Form(
        key: _formKey,
        child: ListView(
          shrinkWrap: true,
          children: [
            Center(
              child: Container(
                width: 40, height: 5,
                decoration: BoxDecoration(color: Colors.grey.shade300, borderRadius: BorderRadius.circular(10)),
              ),
            ),
            const SizedBox(height: 20),
            Row(
              children: [
                Container(
                  width: 40, height: 40,
                  decoration: BoxDecoration(
                    color: const Color(0xFF0083B0).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.storefront_rounded, color: Color(0xFF0083B0), size: 20),
                ),
                const SizedBox(width: 12),
                Text(
                  _esEdicion ? 'Editar sede' : 'Nueva sede',
                  style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w900, color: Color(0xFF1E293B)),
                ),
              ],
            ),
            const SizedBox(height: 20),
            GestureDetector(
              onTap: _seleccionarImagen,
              child: Container(
                height: 180,
                width: double.infinity,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(16),
                  color: const Color(0xFFF8FAFC),
                  border: Border.all(
                    color: _pickedPath.isEmpty ? const Color(0xFF0083B0).withOpacity(0.3) : Colors.transparent,
                    width: _pickedPath.isEmpty ? 1.5 : 0,
                  ),
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(16),
                  child: _buildImagePreview(),
                ),
              ),
            ),
            const SizedBox(height: 20),
            _buildField(_nombreCtrl, 'Nombre de la sede', Icons.home_outlined),
            const SizedBox(height: 12),
            _buildField(_direccionCtrl, 'Dirección', Icons.place_outlined),
            const SizedBox(height: 12),
            _buildField(_precioCtrl, 'Precio desde (COP, ej: 90000)', Icons.attach_money_rounded, keyboardType: TextInputType.number),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                color: const Color(0xFFF1F5F9),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Row(
                children: [
                  const Icon(Icons.schedule_rounded, size: 16, color: Color(0xFF64748B)),
                  const SizedBox(width: 8),
                  const Text('Horario:', style: TextStyle(fontSize: 13, color: Color(0xFF64748B))),
                  const SizedBox(width: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                    decoration: BoxDecoration(
                      color: const Color(0xFF0083B0).withOpacity(0.1),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: const Text('Día - Noche', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF0083B0))),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            SizedBox(
              height: 52,
              child: ElevatedButton(
                onPressed: _isUploading ? null : _guardarSede,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF0F172A),
                  foregroundColor: Colors.white,
                  elevation: 0,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                ),
                child: _isUploading
                    ? const Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          SizedBox(width: 18, height: 18, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2)),
                          SizedBox(width: 10),
                          Text('Subiendo imagen...', style: TextStyle(fontWeight: FontWeight.bold)),
                        ],
                      )
                    : Text(
                        _esEdicion ? 'GUARDAR CAMBIOS' : 'CREAR SEDE',
                        style: const TextStyle(fontWeight: FontWeight.bold, letterSpacing: 1),
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildField(TextEditingController ctrl, String label, IconData icon, {TextInputType? keyboardType}) {
    return TextFormField(
      controller: ctrl,
      keyboardType: keyboardType,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon, size: 20),
        filled: true,
        fillColor: const Color(0xFFF8FAFC),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Colors.grey.shade200)),
        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFF0083B0), width: 2)),
      ),
      validator: (v) => (v == null || v.trim().isEmpty) ? 'Campo obligatorio' : null,
    );
  }
}