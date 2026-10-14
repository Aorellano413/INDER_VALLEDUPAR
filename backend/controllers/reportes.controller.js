const { db, Timestamp } = require('../config/firebase');

// Minutos desde medianoche del inicio del turno. Las horas se guardan como
// "07:00 AM - 08:00 AM" (ver generarSlots en reserva_controlador.dart).
// Si no se puede interpretar, devuelve -1 para que quede al final al ordenar
// de más reciente a más antiguo.
function minutosInicio(hora) {
  const m = String(hora || '').match(/(\d{1,2}):(\d{2})\s*([AaPp])\.?\s*[Mm]/);
  if (!m) return -1;
  let h = Number(m[1]) % 12;
  if (m[3].toLowerCase() === 'p') h += 12;
  return h * 60 + Number(m[2]);
}

function leerFecha(valor) {
  if (typeof valor !== 'string' || valor.trim() === '') return null;
  const fecha = new Date(valor.trim());
  return isNaN(fecha.getTime()) ? null : fecha;
}

// GET /api/reportes/reservas?desde=<ISO>&hasta=<ISO>[&sedeId=<id>]
//
//  - 'desde' es inclusivo y 'hasta' es exclusivo (intervalo [desde, hasta)).
//  - Las fechas deben enviarse en ISO 8601 con zona (p. ej. terminadas en 'Z').
//    Así los límites del período los define el cliente según su zona horaria
//    y el servidor no depende de la suya.
//  - El filtro por sede se aplica en memoria a propósito: combinar un rango
//    sobre 'fechaReserva' con una igualdad sobre 'sedeId' exigiría crear un
//    índice compuesto en Firestore.
//  - Sedes y canchas se leen una sola vez (no una consulta por reserva).
const reservas = async (req, res) => {
  const desde = leerFecha(req.query.desde);
  const hasta = leerFecha(req.query.hasta);
  const sedeId =
    typeof req.query.sedeId === 'string' && req.query.sedeId.trim() !== ''
      ? req.query.sedeId.trim()
      : null;

  if (!desde || !hasta) {
    return res.status(400).json({
      error: "Los parámetros 'desde' y 'hasta' son obligatorios y deben ser fechas ISO 8601.",
    });
  }
  if (desde.getTime() >= hasta.getTime()) {
    return res.status(400).json({ error: "'desde' debe ser anterior a 'hasta'." });
  }

  const [reservasSnap, sedesSnap, canchasSnap] = await Promise.all([
    db
      .collection('reservas')
      .where('fechaReserva', '>=', Timestamp.fromDate(desde))
      .where('fechaReserva', '<', Timestamp.fromDate(hasta))
      .get(),
    db.collection('sedes').get(),
    db.collection('canchas').get(),
  ]);

  const sedes = new Map(sedesSnap.docs.map((d) => [d.id, d.data()]));
  const canchas = new Map(canchasSnap.docs.map((d) => [d.id, d.data()]));

  const filas = [];
  for (const doc of reservasSnap.docs) {
    const r = doc.data();
    if (sedeId && r.sedeId !== sedeId) continue;

    const fecha = r.fechaReserva instanceof Timestamp ? r.fechaReserva.toDate() : null;

    let sedeNombre = 'Sin sede';
    if (r.sedeId) {
      const sede = sedes.get(r.sedeId);
      sedeNombre = sede ? sede.title || 'Sin nombre' : 'Sede no encontrada';
    }

    let canchaNombre = 'Sin cancha';
    if (r.canchaId) {
      const cancha = canchas.get(r.canchaId);
      canchaNombre = cancha ? cancha.title || 'Sin nombre' : 'Cancha no encontrada';
    }

    filas.push({
      id: doc.id,
      fechaReserva: fecha ? fecha.toISOString() : null,
      horaReserva: r.horaReserva || '',
      nombreCompleto: r.nombreCompleto || 'Sin nombre',
      sedeId: r.sedeId || null,
      sedeNombre,
      canchaId: r.canchaId || null,
      canchaNombre,
      estado: r.estado || 'pendiente',
    });
  }

  // Más recientes primero: fecha descendente y, dentro del mismo día, hora descendente.
  filas.sort((a, b) => {
    const porFecha = String(b.fechaReserva).localeCompare(String(a.fechaReserva));
    if (porFecha !== 0) return porFecha;
    return minutosInicio(b.horaReserva) - minutosInicio(a.horaReserva);
  });

  res.json(filas);
};

module.exports = { reservas };
