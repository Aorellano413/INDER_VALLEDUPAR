const { db, Timestamp } = require('../config/firebase');
const { claveFecha, soloFecha, limpiarHora } = require('../utils/fechas');

async function estaBloqueada(canchaId, fecha, hora) {
  const snap = await db.collection('bloqueos')
    .where('activo', '==', true)
    .where('canchaIds', 'array-contains', canchaId)
    .get();

  const horaLimpia = limpiarHora(hora);
  const claveBuscada = claveFecha(fecha);

  for (const doc of snap.docs) {
    const b = doc.data();
    let enFecha = false;

    if (b.tipo === 'rangoHorario' && b.fechaBloqueo) {
      enFecha = claveFecha(b.fechaBloqueo.toDate()) === claveBuscada;
    } else if (b.tipo === 'rangoDias' && b.fechaInicio && b.fechaFin) {
      const f = soloFecha(fecha);
      enFecha = f >= soloFecha(b.fechaInicio.toDate()) && f <= soloFecha(b.fechaFin.toDate());
    }
    if (!enFecha) continue;

    const horas = b.horasEspecificas || [];
    if (horas.length === 0) return true;
    if (horas.some((h) => limpiarHora(h) === horaLimpia)) return true;
  }
  return false;
}

async function verificarDisponibilidad(canchaId, fecha, hora) {
  const [y, m, d] = fecha.split('-').map(Number);
  const fechaBuscada = new Date(y, m - 1, d);

  if (await estaBloqueada(canchaId, fechaBuscada, hora)) return false;

  const snap = await db.collection('reservas').where('canchaId', '==', canchaId).get();
  const claveBuscada = claveFecha(fechaBuscada);

  for (const doc of snap.docs) {
    const r = doc.data();
    if (!r.horaReserva) continue;

    let claveDoc = '';
    if (r.fechaReserva instanceof Timestamp) {
      claveDoc = claveFecha(r.fechaReserva.toDate());
    } else if (typeof r.fechaReserva === 'string') {
      const [yy, mm, dd] = r.fechaReserva.split('T')[0].split('-').map(Number);
      claveDoc = `${yy}-${mm}-${dd}`;
    }

    const estado = r.estado || 'pendiente';
    if (
      claveDoc === claveBuscada &&
      r.horaReserva.trim().toLowerCase() === hora.trim().toLowerCase() &&
      ['pendiente', 'confirmada', 'pagado'].includes(estado)
    ) {
      return false;
    }
  }
  return true;
}

module.exports = { estaBloqueada, verificarDisponibilidad };