const { db } = require('../config/firebase');
const { docAJson, aFirestore } = require('../utils/serializar');
const { registrar, obtenerDoc, calcularCambios } = require('../services/auditoria.service');

const listar = async (req, res) => {
  const snap = await db.collection('sedes').get();
  res.json(snap.docs.map(docAJson));
};

const crear = async (req, res) => {
  const datos = aFirestore(req.body);
  const ref = await db.collection('sedes').add(datos);
  await registrar(req, { accion: 'CREAR', entidad: 'sede', entidadId: ref.id, despues: datos });
  res.status(201).json({ id: ref.id });
};

const actualizar = async (req, res) => {
  const datos = aFirestore(req.body);
  const antes = await obtenerDoc('sedes', req.params.id);
  await db.collection('sedes').doc(req.params.id).update(datos);
  await registrar(req, {
    accion: 'ACTUALIZAR',
    entidad: 'sede',
    entidadId: req.params.id,
    cambios: calcularCambios(antes, datos),
  });
  res.json({ ok: true });
};

const eliminar = async (req, res) => {
  const antes = await obtenerDoc('sedes', req.params.id);
  await db.collection('sedes').doc(req.params.id).delete();
  await registrar(req, { accion: 'ELIMINAR', entidad: 'sede', entidadId: req.params.id, antes });
  res.json({ ok: true });
};

module.exports = { listar, crear, actualizar, eliminar };