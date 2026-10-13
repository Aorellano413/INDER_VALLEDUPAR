const { db } = require('../config/firebase');
const { docAJson, aFirestore } = require('../utils/serializar');
const { registrar, obtenerDoc, calcularCambios } = require('../services/auditoria.service');

const listar = async (req, res) => {
  const { sedeId } = req.query;
  let consulta = db.collection('canchas');
  if (sedeId) consulta = consulta.where('sedeId', '==', sedeId);
  const snap = await consulta.get();
  res.json(snap.docs.map(docAJson));
};

const crear = async (req, res) => {
  const datos = aFirestore(req.body);
  const ref = await db.collection('canchas').add(datos);
  await registrar(req, { accion: 'CREAR', entidad: 'cancha', entidadId: ref.id, despues: datos });
  res.status(201).json({ id: ref.id });
};

const actualizar = async (req, res) => {
  const datos = aFirestore(req.body);
  const antes = await obtenerDoc('canchas', req.params.id);
  await db.collection('canchas').doc(req.params.id).update(datos);
  await registrar(req, {
    accion: 'ACTUALIZAR',
    entidad: 'cancha',
    entidadId: req.params.id,
    cambios: calcularCambios(antes, datos),
  });
  res.json({ ok: true });
};

const eliminar = async (req, res) => {
  const antes = await obtenerDoc('canchas', req.params.id);
  await db.collection('canchas').doc(req.params.id).delete();
  await registrar(req, { accion: 'ELIMINAR', entidad: 'cancha', entidadId: req.params.id, antes });
  res.json({ ok: true });
};

module.exports = { listar, crear, actualizar, eliminar };