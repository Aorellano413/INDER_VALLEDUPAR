const { db } = require('../config/firebase');
const { docAJson, aFirestore } = require('../utils/serializar');

const listar = async (req, res) => {
  const snap = await db.collection('sedes').get();
  res.json(snap.docs.map(docAJson));
};

const crear = async (req, res) => {
  const ref = await db.collection('sedes').add(aFirestore(req.body));
  res.status(201).json({ id: ref.id });
};

const actualizar = async (req, res) => {
  await db.collection('sedes').doc(req.params.id).update(aFirestore(req.body));
  res.json({ ok: true });
};

const eliminar = async (req, res) => {
  await db.collection('sedes').doc(req.params.id).delete();
  res.json({ ok: true });
};

module.exports = { listar, crear, actualizar, eliminar };