const { db, FieldValue } = require('../config/firebase');
const { serializar } = require('../utils/serializar');

function obtenerUsuario(req) {
  const leer = (nombre) => {
    const valor = req.headers[nombre];
    if (!valor) return null;
    try {
      return decodeURIComponent(valor);
    } catch {
      return valor;
    }
  };

  return {
    id: leer('x-usuario-id'),
    correo: leer('x-usuario-correo') || 'desconocido',
    nombre: leer('x-usuario-nombre'),
    rol: leer('x-usuario-rol'),
  };
}

async function obtenerDoc(coleccion, id) {
  const doc = await db.collection(coleccion).doc(id).get();
  return doc.exists ? doc.data() : null;
}

function calcularCambios(antes, despues) {
  const a = serializar(antes || {});
  const d = serializar(despues || {});
  const cambios = [];

  for (const campo of Object.keys(d)) {
    if (campo === 'id') continue;
    if (JSON.stringify(a[campo]) !== JSON.stringify(d[campo])) {
      cambios.push({
        campo,
        antes: a[campo] ?? null,
        despues: d[campo] ?? null,
      });
    }
  }
  return cambios;
}

async function registrar(req, { accion, entidad, entidadId, antes = null, despues = null, cambios = null }) {
  try {
    await db.collection('auditoria').add({
      accion,
      entidad,
      entidadId: entidadId || null,
      usuario: obtenerUsuario(req),
      antes: antes ? serializar(antes) : null,
      despues: despues ? serializar(despues) : null,
      cambios,
      fecha: FieldValue.serverTimestamp(),
    });
  } catch (error) {
    console.error('Error al registrar auditoría:', error.message);
  }
}

module.exports = { registrar, obtenerDoc, calcularCambios };