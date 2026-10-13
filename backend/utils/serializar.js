const { Timestamp, FieldValue } = require('../config/firebase');

const CAMPOS_FECHA = ['fechaBloqueo', 'fechaInicio', 'fechaFin', 'fechaReserva', 'creadoEn'];

function serializar(valor) {
  if (valor instanceof Timestamp) return valor.toDate().toISOString();
  if (valor instanceof FieldValue) return null;
  if (Array.isArray(valor)) return valor.map(serializar);
  if (valor && typeof valor === 'object') {
    return Object.fromEntries(Object.entries(valor).map(([k, v]) => [k, serializar(v)]));
  }
  return valor;
}

const docAJson = (doc) => ({ id: doc.id, ...serializar(doc.data()) });

function parsearFecha(valor) {
  if (valor instanceof Date) return valor;

  if (typeof valor === 'number') return new Date(valor);

  if (valor && typeof valor === 'object') {
    const segundos = valor.seconds ?? valor._seconds;
    const nanos = valor.nanoseconds ?? valor._nanoseconds ?? 0;
    if (segundos !== undefined) return new Date(segundos * 1000 + Math.floor(nanos / 1e6));
    return new Date(NaN);
  }

  if (typeof valor === 'string') {
    const coincidencia = valor.match(/Timestamp\(seconds=(\d+),\s*nanoseconds=(\d+)\)/);
    if (coincidencia) {
      const segundos = Number(coincidencia[1]);
      const nanos = Number(coincidencia[2]);
      return new Date(segundos * 1000 + Math.floor(nanos / 1e6));
    }
    return new Date(valor);
  }

  return new Date(NaN);
}

function aFirestore(data) {
  const copia = { ...data };
  delete copia.id;

  for (const campo of CAMPOS_FECHA) {
    const valor = copia[campo];
    if (valor === undefined || valor === null || valor === '') continue;

    const fecha = parsearFecha(valor);
    if (isNaN(fecha.getTime())) {
      if (campo === 'creadoEn') {
        copia[campo] = FieldValue.serverTimestamp();
      } else {
        throw new Error(`Fecha inválida en el campo '${campo}': ${JSON.stringify(valor)}`);
      }
    } else {
      copia[campo] = Timestamp.fromDate(fecha);
    }
  }
  return copia;
}

module.exports = { serializar, docAJson, aFirestore };