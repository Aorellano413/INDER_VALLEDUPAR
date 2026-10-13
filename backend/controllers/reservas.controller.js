const { db, FieldValue } = require('../config/firebase');
const { serializar, docAJson, aFirestore } = require('../utils/serializar');
const { verificarDisponibilidad } = require('../services/disponibilidad.service');
const { registrar, obtenerDoc } = require('../services/auditoria.service');

const crear = async (req, res) => {
  const datos = { ...aFirestore(req.body), estado: 'pendiente' };
  const ref = await db.collection('reservas').add({
    ...datos,
    createdAt: FieldValue.serverTimestamp(),
  });
  await registrar(req, { accion: 'CREAR', entidad: 'reserva', entidadId: ref.id, despues: datos });
  res.status(201).json({ id: ref.id });
};

const listar = async (req, res) => {
  const { estado, correo, sedeId } = req.query;
  let consulta = db.collection('reservas');
  if (estado) consulta = consulta.where('estado', '==', estado);
  if (correo) consulta = consulta.where('correoElectronico', '==', correo);
  if (sedeId) consulta = consulta.where('sedeId', '==', sedeId);
  const snap = await consulta.orderBy('createdAt', 'desc').get();
  res.json(snap.docs.map(docAJson));
};

const listarCompletas = async (req, res) => {
  const { sedeId } = req.query;
  let consulta = db.collection('reservas');
  if (sedeId) consulta = consulta.where('sedeId', '==', sedeId);
  const snap = await consulta.orderBy('createdAt', 'desc').get();

  const resultado = [];
  for (const doc of snap.docs) {
    const reserva = docAJson(doc);
    if (reserva.sedeId) {
      const sede = await db.collection('sedes').doc(reserva.sedeId).get();
      reserva.sede = sede.exists
        ? serializar(sede.data())
        : { title: 'Sede no encontrada', subtitle: '' };
    }
    if (reserva.canchaId) {
      const cancha = await db.collection('canchas').doc(reserva.canchaId).get();
      reserva.cancha = cancha.exists
        ? serializar(cancha.data())
        : { title: 'Cancha no encontrada', price: '$0' };
    }
    resultado.push(reserva);
  }
  res.json(resultado);
};

const actualizarEstado = async (req, res) => {
  const antes = await obtenerDoc('reservas', req.params.id);
  await db.collection('reservas').doc(req.params.id).update({
    estado: req.body.estado,
    updatedAt: FieldValue.serverTimestamp(),
  });
  await registrar(req, {
    accion: 'ACTUALIZAR',
    entidad: 'reserva',
    entidadId: req.params.id,
    cambios: [{ campo: 'estado', antes: antes ? antes.estado : null, despues: req.body.estado }],
  });
  res.json({ ok: true });
};

const eliminar = async (req, res) => {
  const antes = await obtenerDoc('reservas', req.params.id);
  await db.collection('reservas').doc(req.params.id).delete();
  await registrar(req, { accion: 'ELIMINAR', entidad: 'reserva', entidadId: req.params.id, antes });
  res.json({ ok: true });
};

const disponibilidad = async (req, res) => {
  const { canchaId, fecha, hora } = req.query;
  const disponible = await verificarDisponibilidad(canchaId, fecha, hora);
  res.json({ disponible });
};

module.exports = {
  crear,
  listar,
  listarCompletas,
  actualizarEstado,
  eliminar,
  disponibilidad,
};