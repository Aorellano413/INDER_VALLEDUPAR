class Sesion {
  static Map<String, dynamic>? usuario;

  static void iniciar(Map<String, dynamic> datos) {
    usuario = datos;
  }

  static void cerrar() {
    usuario = null;
  }
}