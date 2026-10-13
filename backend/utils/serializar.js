const { Timestamp } = require('../config/firebase');

const CAMPOS_FECHA = ['fechaBloqueo', 'fechaInicio', 'fechaFin', 'fechaReserva', 'creadoEn'];

function serializar(valor) {
  if (valor instanceof Timestamp) return valor.toDate().toISOString();
  if (Array.isArray(valor)) return valor.map(serializar);
  if (valor && typeof valor === 'object') {
    return Object.fromEntries(Object.entries(valor).map(([k, v]) => [k, serializar(v)]));
  }
  return valor;
}

const docAJson = (doc) => ({ id: doc.id, ...serializar(doc.data()) });

function aFirestore(data) {
  const copia = { ...data };
  delete copia.id;
  for (const campo of CAMPOS_FECHA) {
    if (typeof copia[campo] === 'string' && copia[campo]) {
      copia[campo] = Timestamp.fromDate(new Date(copia[campo]));
    }
  }
  return copia;
}

module.exports = { serializar, docAJson, aFirestore };