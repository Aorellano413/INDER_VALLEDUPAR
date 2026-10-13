const { db } = require('../config/firebase');

async function calcularEstadisticas(sedeId) {
  let reservas = db.collection('reservas');
  let canchas = db.collection('canchas');
  if (sedeId) {
    reservas = reservas.where('sedeId', '==', sedeId);
    canchas = canchas.where('sedeId', '==', sedeId);
  }
  const [rs, cs, ss] = await Promise.all([
    reservas.get(),
    canchas.get(),
    sedeId ? null : db.collection('sedes').get(),
  ]);

  let pendientes = 0, pagadas = 0, canceladas = 0;
  rs.docs.forEach((doc) => {
    const estado = doc.data().estado || 'pendiente';
    if (estado === 'pendiente') pendientes++;
    if (estado === 'pagado') pagadas++;
    if (estado === 'cancelado') canceladas++;
  });

  return {
    totalReservas: rs.size,
    totalSedes: sedeId ? 1 : ss.size,
    totalCanchas: cs.size,
    reservasPendientes: pendientes,
    reservasPagadas: pagadas,
    reservasCanceladas: canceladas,
  };
}

const obtener = async (req, res) => {
  res.json(await calcularEstadisticas(req.query.sedeId));
};

module.exports = { obtener };