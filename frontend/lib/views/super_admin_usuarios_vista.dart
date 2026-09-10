import 'package:flutter/material.dart';
import '../models/user_modelo.dart';
import '../services/autenticacion_servicio.dart';
import '../services/firestore_servicio.dart';
import '../models/sede_modelo.dart';

class SuperAdminUsuariosView extends StatefulWidget {
  const SuperAdminUsuariosView({super.key});

  @override
  State<SuperAdminUsuariosView> createState() => _SuperAdminUsuariosViewState();
}

class _SuperAdminUsuariosViewState extends State<SuperAdminUsuariosView> {
  final AuthService _authService = AuthService();
  List<UserModel> _usuarios = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _cargarUsuarios();
  }

  Future<void> _cargarUsuarios() async {
    setState(() => _isLoading = true);
    _usuarios = await _authService.getAllUsers();
    setState(() => _isLoading = false);
  }

  void _mostrarFormulario({UserModel? usuario}) async {
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(25)),
      ),
      builder: (ctx) => _FormularioUsuario(
        usuario: usuario,
        onGuardado: () {
          _cargarUsuarios();
          Navigator.pop(ctx);
          _mostrarSnackbar(
            usuario == null ? 'Usuario creado correctamente' : 'Usuario actualizado',
          );
        },
      ),
    );
  }

  Future<void> _confirmarEliminar(UserModel usuario) async {
    final confirmar = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Confirmar acción'),
        content: Text('¿Deseas desactivar el acceso para ${usuario.nombre}?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancelar', style: TextStyle(color: Colors.grey)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.redAccent,
              elevation: 0,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            child: const Text('Desactivar', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (confirmar == true && usuario.id != null) {
      final resultado = await _authService.eliminarUsuario(usuario.id!);
      if (mounted) {
        _mostrarSnackbar(resultado['message'], isError: !resultado['success']);
        if (resultado['success']) _cargarUsuarios();
      }
    }
  }

  Future<void> _confirmarEliminarPermanente(UserModel usuario) async {
    final confirmar = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Eliminar permanentemente'),
        content: Text('Esta acción no se puede deshacer. ¿Eliminar a ${usuario.nombre}?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancelar', style: TextStyle(color: Colors.grey)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red.shade900,
              elevation: 0,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            child: const Text('Eliminar', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (confirmar == true && usuario.id != null) {
      final resultado = await _authService.eliminarUsuarioPermanente(usuario.id!);
      if (mounted) {
        _mostrarSnackbar(resultado['message'], isError: !resultado['success']);
        if (resultado['success']) _cargarUsuarios();
      }
    }
  }

  void _mostrarSnackbar(String mensaje, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(mensaje),
        backgroundColor: isError ? Colors.redAccent : const Color(0xFF1E293B),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        margin: const EdgeInsets.all(20),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        elevation: 0,
        centerTitle: true,
        title: const Text(
          'Control de Usuarios',
          style: TextStyle(fontWeight: FontWeight.w800, letterSpacing: 0.5),
        ),
        flexibleSpace: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [Color(0xFF0F172A), Color(0xFF1E293B)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
        ),
        foregroundColor: Colors.white,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: Color.fromARGB(255, 0, 255, 55)))
          : RefreshIndicator(
              color: const Color.fromARGB(255, 0, 255, 55),
              onRefresh: _cargarUsuarios,
              child: _usuarios.isEmpty ? _buildEmptyState() : _buildUserList(),
            ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _mostrarFormulario(),
        icon: const Icon(Icons.person_add_rounded, color: Colors.white),
        label: const Text('NUEVO USUARIO', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
        backgroundColor: const Color.fromARGB(255, 0, 255, 128),
        elevation: 4,
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.group_off_rounded, size: 80, color: Colors.blueGrey.shade100),
          const SizedBox(height: 16),
          const Text(
            'No hay usuarios registrados',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF475569)),
          ),
        ],
      ),
    );
  }

  Widget _buildUserList() {
    final superAdmins = _usuarios.where((u) => u.isSuperAdmin).toList();
    final propietarios = _usuarios.where((u) => !u.isSuperAdmin).toList();

    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
      children: [
        _GrupoUsuarios(
          titulo: 'Super Administradores',
          icono: Icons.shield_rounded,
          color: const Color(0xFF6366F1),
          usuarios: superAdmins,
          onEditar: (u) => _mostrarFormulario(usuario: u),
          onEliminar: _confirmarEliminar,
          onEliminarPermanente: _confirmarEliminarPermanente,
        ),
        const SizedBox(height: 12),
        _GrupoUsuarios(
          titulo: 'Propietarios',
          icono: Icons.storefront_rounded,
          color: const Color(0xFF0EA5E9),
          usuarios: propietarios,
          onEditar: (u) => _mostrarFormulario(usuario: u),
          onEliminar: _confirmarEliminar,
          onEliminarPermanente: _confirmarEliminarPermanente,
        ),
      ],
    );
  }
}

class _GrupoUsuarios extends StatefulWidget {
  final String titulo;
  final IconData icono;
  final Color color;
  final List<UserModel> usuarios;
  final void Function(UserModel) onEditar;
  final void Function(UserModel) onEliminar;
  final void Function(UserModel) onEliminarPermanente;

  const _GrupoUsuarios({
    required this.titulo,
    required this.icono,
    required this.color,
    required this.usuarios,
    required this.onEditar,
    required this.onEliminar,
    required this.onEliminarPermanente,
  });

  @override
  State<_GrupoUsuarios> createState() => _GrupoUsuariosState();
}

class _GrupoUsuariosState extends State<_GrupoUsuarios> {
  bool _expandido = true;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        GestureDetector(
          onTap: () => setState(() => _expandido = !_expandido),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: widget.color.withOpacity(0.08),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: widget.color.withOpacity(0.2)),
            ),
            child: Row(
              children: [
                Icon(widget.icono, color: widget.color, size: 20),
                const SizedBox(width: 10),
                Text(
                  widget.titulo,
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    color: widget.color,
                    fontSize: 14,
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: widget.color.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    '${widget.usuarios.length}',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: widget.color,
                    ),
                  ),
                ),
                const Spacer(),
                AnimatedRotation(
                  turns: _expandido ? 0 : -0.25,
                  duration: const Duration(milliseconds: 200),
                  child: Icon(Icons.keyboard_arrow_down_rounded, color: widget.color),
                ),
              ],
            ),
          ),
        ),
        AnimatedSwitcher(
          duration: const Duration(milliseconds: 250),
          child: _expandido
              ? Column(
                  key: const ValueKey('expanded'),
                  children: [
                    const SizedBox(height: 10),
                    ...widget.usuarios.map(
                      (u) => Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: _UsuarioCard(
                          usuario: u,
                          onEditar: () => widget.onEditar(u),
                          onEliminar: () => widget.onEliminar(u),
                          onEliminarPermanente: () => widget.onEliminarPermanente(u),
                        ),
                      ),
                    ),
                  ],
                )
              : const SizedBox(key: ValueKey('collapsed')),
        ),
      ],
    );
  }
}

class _UsuarioCard extends StatelessWidget {
  final UserModel usuario;
  final VoidCallback onEditar;
  final VoidCallback onEliminar;
  final VoidCallback onEliminarPermanente;

  const _UsuarioCard({
    required this.usuario,
    required this.onEditar,
    required this.onEliminar,
    required this.onEliminarPermanente,
  });

  @override
  Widget build(BuildContext context) {
    final bool isSuperAdmin = usuario.isSuperAdmin;
    final Color accentColor = isSuperAdmin ? const Color(0xFF6366F1) : const Color(0xFF0EA5E9);

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        leading: Container(
          width: 50,
          height: 50,
          decoration: BoxDecoration(
            color: accentColor.withOpacity(0.1),
            shape: BoxShape.circle,
          ),
          child: Icon(
            isSuperAdmin ? Icons.shield_rounded : Icons.person_rounded,
            color: accentColor,
          ),
        ),
        title: Text(
          usuario.nombre,
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Color(0xFF1E293B)),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 4),
            Text(usuario.email, style: TextStyle(color: Colors.blueGrey.shade400, fontSize: 13)),
            if (!usuario.activo)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(
                  'CUENTA INACTIVA',
                  style: TextStyle(color: Colors.red.shade400, fontSize: 10, fontWeight: FontWeight.w900),
                ),
              ),
          ],
        ),
        trailing: PopupMenuButton(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          icon: const Icon(Icons.more_horiz_rounded, color: Color(0xFF94A3B8)),
          itemBuilder: (context) => [
            const PopupMenuItem(
              value: 'editar',
              child: Row(children: [Icon(Icons.edit_outlined, size: 18), SizedBox(width: 8), Text('Editar')]),
            ),
            PopupMenuItem(
              value: 'eliminar',
              child: Row(
                children: [
                  Icon(Icons.delete_outline_rounded, size: 18, color: Colors.red.shade400),
                  const SizedBox(width: 8),
                  Text('Desactivar', style: TextStyle(color: Colors.red.shade400)),
                ],
              ),
            ),
            if (!usuario.activo)
              PopupMenuItem(
                value: 'eliminar_permanente',
                child: Row(
                  children: [
                    Icon(Icons.delete_forever_rounded, size: 18, color: Colors.red.shade900),
                    const SizedBox(width: 8),
                    Text('Eliminar permanente', style: TextStyle(color: Colors.red.shade900)),
                  ],
                ),
              ),
          ],
          onSelected: (value) {
            if (value == 'editar') onEditar();
            if (value == 'eliminar') onEliminar();
            if (value == 'eliminar_permanente') onEliminarPermanente();
          },
        ),
      ),
    );
  }
}

class _FormularioUsuario extends StatefulWidget {
  final UserModel? usuario;
  final VoidCallback onGuardado;

  const _FormularioUsuario({this.usuario, required this.onGuardado});

  @override
  State<_FormularioUsuario> createState() => _FormularioUsuarioState();
}

class _FormularioUsuarioState extends State<_FormularioUsuario> {
  final _formKey = GlobalKey<FormState>();
  final _nombreCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();
  final _telefonoCtrl = TextEditingController();

  UserRole _rolSeleccionado = UserRole.propietario;
  String? _sedeSeleccionada;
  List<SedeModel> _sedes = [];
  bool _isLoading = false;
  bool _showPassword = false;

  bool get _esEdicion => widget.usuario != null;

  @override
  void initState() {
    super.initState();
    _cargarSedes();
    if (_esEdicion) {
      _nombreCtrl.text = widget.usuario!.nombre;
      _emailCtrl.text = widget.usuario!.email;
      _telefonoCtrl.text = widget.usuario!.telefono ?? '';
      _rolSeleccionado = widget.usuario!.rol;
      _sedeSeleccionada = widget.usuario!.sedeAsignada;
    }
  }

  Future<void> _cargarSedes() async {
    _sedes = await FirestoreService().getSedes();
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _nombreCtrl.dispose();
    _emailCtrl.dispose();
    _passwordCtrl.dispose();
    _telefonoCtrl.dispose();
    super.dispose();
  }

  void _mostrarError(String mensaje) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(mensaje), backgroundColor: Colors.redAccent, behavior: SnackBarBehavior.floating),
    );
  }

  Future<void> _guardar() async {
    if (!_formKey.currentState!.validate()) return;
    if (_rolSeleccionado == UserRole.propietario && _sedeSeleccionada == null) {
      _mostrarError('Seleccione una sede para el propietario');
      return;
    }

    setState(() => _isLoading = true);
    try {
      if (_esEdicion) {
        final usuarioActualizado = widget.usuario!.copyWith(
          nombre: _nombreCtrl.text.trim(),
          email: _emailCtrl.text.trim(),
          telefono: _telefonoCtrl.text.trim().isEmpty ? null : _telefonoCtrl.text.trim(),
          rol: _rolSeleccionado,
          sedeAsignada: _rolSeleccionado == UserRole.propietario ? _sedeSeleccionada : null,
        );
        final res = await AuthService().actualizarUsuario(uid: widget.usuario!.id!, userData: usuarioActualizado);
        if (res['success']) widget.onGuardado(); else _mostrarError(res['message']);
      } else {
        final res = await AuthService().crearUsuario(
          nombre: _nombreCtrl.text.trim(),
          email: _emailCtrl.text.trim(),
          password: _passwordCtrl.text.trim(),
          rol: _rolSeleccionado,
          sedeAsignada: _rolSeleccionado == UserRole.propietario ? _sedeSeleccionada : null,
          telefono: _telefonoCtrl.text.trim().isEmpty ? null : _telefonoCtrl.text.trim(),
        );
        if (res['success']) widget.onGuardado(); else _mostrarError(res['message']);
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
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
              child: Container(width: 40, height: 5, decoration: BoxDecoration(color: Colors.grey.shade300, borderRadius: BorderRadius.circular(10))),
            ),
            const SizedBox(height: 24),
            Text(
              _esEdicion ? 'Actualizar Usuario' : 'Nuevo Registro',
              style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w900, color: Color(0xFF1E293B)),
            ),
            const SizedBox(height: 24),
            _buildField(_nombreCtrl, 'Nombre completo', Icons.person_outline),
            const SizedBox(height: 16),
            _buildField(_emailCtrl, 'Email corporativo', Icons.alternate_email_rounded, enabled: !_esEdicion),
            const SizedBox(height: 16),
            if (!_esEdicion) ...[
              _buildField(_passwordCtrl, 'Contraseña', Icons.lock_open_rounded, isPassword: true),
              const SizedBox(height: 16),
            ],
            _buildField(_telefonoCtrl, 'Teléfono', Icons.phone_android_rounded),
            const SizedBox(height: 16),
            DropdownButtonFormField<UserRole>(
              value: _rolSeleccionado,
              decoration: _inputDecoration('Rol de usuario', Icons.admin_panel_settings_outlined),
              items: const [
                DropdownMenuItem(value: UserRole.superAdmin, child: Text('Super Administrador')),
                DropdownMenuItem(value: UserRole.propietario, child: Text('Propietario de Sede')),
              ],
              onChanged: (v) => setState(() {
                _rolSeleccionado = v!;
                if (_rolSeleccionado == UserRole.superAdmin) _sedeSeleccionada = null;
              }),
            ),
            const SizedBox(height: 16),
            if (_rolSeleccionado == UserRole.propietario)
              DropdownButtonFormField<String>(
                value: _sedeSeleccionada,
                decoration: _inputDecoration('Asignar Sede', Icons.storefront_rounded),
                items: _sedes.map((s) => DropdownMenuItem(value: s.id, child: Text(s.title))).toList(),
                onChanged: (v) => setState(() => _sedeSeleccionada = v),
                validator: (v) => v == null ? 'Requerido' : null,
              ),
            const SizedBox(height: 32),
            SizedBox(
              height: 55,
              child: ElevatedButton(
                onPressed: _isLoading ? null : _guardar,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF0F172A),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  elevation: 0,
                ),
                child: _isLoading
                    ? const CircularProgressIndicator(color: Colors.white)
                    : Text(_esEdicion ? 'GUARDAR CAMBIOS' : 'CREAR USUARIO', style: const TextStyle(fontWeight: FontWeight.bold, letterSpacing: 1, color: Colors.white)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildField(TextEditingController ctrl, String label, IconData icon, {bool enabled = true, bool isPassword = false}) {
    return TextFormField(
      controller: ctrl,
      enabled: enabled,
      obscureText: isPassword && !_showPassword,
      decoration: _inputDecoration(label, icon).copyWith(
        suffixIcon: isPassword ? IconButton(
          icon: Icon(_showPassword ? Icons.visibility_off : Icons.visibility),
          onPressed: () => setState(() => _showPassword = !_showPassword),
        ) : null,
      ),
      validator: (v) => (v == null || v.isEmpty) ? 'Campo obligatorio' : null,
    );
  }

  InputDecoration _inputDecoration(String label, IconData icon) {
    return InputDecoration(
      labelText: label,
      prefixIcon: Icon(icon, size: 20),
      filled: true,
      fillColor: const Color(0xFFF8FAFC),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Colors.grey.shade200)),
      focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color.fromARGB(255, 1, 235, 13), width: 2)),
    );
  }
}