# Esquema de Base de Datos - INDER Valledupar (Firestore)

## 1. Colección: `usuarios`
Almacena los perfiles de usuario y sus roles de acceso.
* `uid` (String): ID único generado por Firebase Auth.
* `correo` (String): Correo electrónico del usuario.
* `rol` (String): Define permisos ('superAdmin', 'propietario', etc.).
* `sedeAsignada` (String): ID de la sede que administra (si aplica).

## 2. Colección: `sedes`
Almacena la información de los complejos deportivos.
* `id` (String): ID único de la sede.
* `nombre` (String): Nombre del escenario.
* `ubicacion` (String): Dirección o zona.

## 3. Colección: `canchas`
Almacena los detalles de cada campo deportivo disponible.
* `id` (String): ID único de la cancha.
* `nombre` (String): Nombre del campo.
* `sedeId` (String): Referencia a la sede a la que pertenece.

## 4. Colección: `reservas`
Almacena la información de las reservas de los ciudadanos.
* `id` (String): ID único de la reserva.
* `canchaId` (String): Cancha reservada.
* `estado` (String): Estado actual ('pendiente', 'confirmada').
* `nombre` (String): Nombre de quien reserva.
* `correo` (String): Correo de contacto.

## 5. Colección: `bloqueos`
Almacena los bloqueos temporales de las canchas por mantenimiento o eventos.
* `id` (String): ID del bloqueo.
* `canchaId` (String): Cancha afectada.

## 6. Colección: `auditoria`
Registra los movimientos y acciones importantes dentro del sistema por seguridad.
* `id` (String): ID del registro.
* `accion` (String): Detalle del evento realizado.