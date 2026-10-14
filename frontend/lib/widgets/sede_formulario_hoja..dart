import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import '../controllers/sedes_controlador.dart';
import '../models/sede_modelo.dart';
import '../theme/inder_tema.dart';
import '../utils/formato_utilidades.dart';
import '../services/almacenamiento_servicio.dart';
import 'inder_componentes.dart';

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
      return const InderImagePlaceholder(title: 'Subir imagen de la sede');
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
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
            decoration: BoxDecoration(
              color: InderColors.ink.withOpacity(0.78),
              borderRadius: BorderRadius.circular(InderRadius.pill),
            ),
            child: const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.edit_rounded, size: 14, color: Colors.white),
                SizedBox(width: 6),
                Text('Cambiar', style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w600)),
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
      SnackBar(content: Text(mensaje), backgroundColor: InderColors.cancelado, behavior: SnackBarBehavior.floating),
    );
  }

  @override
  Widget build(BuildContext context) {
    return InderThemeScope(
      child: Container(
        padding: EdgeInsets.only(
          left: 24, right: 24, top: 12,
          bottom: MediaQuery.of(context).viewInsets.bottom + 24,
        ),
        child: Form(
          key: _formKey,
          child: ListView(
            shrinkWrap: true,
            children: [
              InderSheetHeader(
                icon: Icons.storefront_rounded,
                title: _esEdicion ? 'Editar sede' : 'Nueva sede',
                subtitle: 'Datos que verán los clientes al reservar',
              ),
              const SizedBox(height: 20),
              GestureDetector(
                onTap: _seleccionarImagen,
                child: Container(
                  height: 180,
                  width: double.infinity,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(InderRadius.card),
                    color: InderColors.background,
                    border: Border.all(
                      color: _pickedPath.isEmpty ? InderColors.borderStrong : Colors.transparent,
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
              _buildField(_nombreCtrl, 'Nombre de la sede', Icons.home_outlined),
              const SizedBox(height: 12),
              _buildField(_direccionCtrl, 'Dirección', Icons.place_outlined),
              const SizedBox(height: 12),
              _buildField(_precioCtrl, 'Precio desde (COP, ej: 90000)', Icons.attach_money_rounded, keyboardType: TextInputType.number),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                decoration: BoxDecoration(
                  color: InderColors.background,
                  borderRadius: BorderRadius.circular(InderRadius.field),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.schedule_rounded, size: 18, color: InderColors.textMuted),
                    const SizedBox(width: 8),
                    const Text('Horario:', style: TextStyle(fontSize: 13, color: InderColors.textMuted)),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: InderColors.goldTint,
                        borderRadius: BorderRadius.circular(InderRadius.pill),
                      ),
                      child: const Text('Día - Noche', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: InderColors.goldDeep)),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              SizedBox(
                height: 52,
                child: ElevatedButton(
                  onPressed: _isUploading ? null : _guardarSede,
                  child: _isUploading
                      ? const Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            SizedBox(width: 18, height: 18, child: CircularProgressIndicator(color: InderColors.textMuted, strokeWidth: 2)),
                            SizedBox(width: 10),
                            Text('Subiendo imagen...'),
                          ],
                        )
                      : Text(_esEdicion ? 'GUARDAR CAMBIOS' : 'CREAR SEDE'),
                ),
              ),
            ],
          ),
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
      ),
      validator: (v) => (v == null || v.trim().isEmpty) ? 'Campo obligatorio' : null,
    );
  }
}
