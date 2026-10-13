const { db } = require('../config/firebase');
const { docAJson, aFirestore } = require('../utils/serializar');

const listar = async (req, res) => {
  const { sedeId } = req.query;
  let consulta = db.collection('canchas');
  if (sedeId) consulta = consulta.where('sedeId', '==', sedeId);
  const snap = await consulta.get();
  res.json(snap.docs.map(docAJson));
};

const crear = async (req, res) => {
  const ref = await db.collection('canchas').add(aFirestore(req.body));
  res.status(201).json({ id: ref.id });
};

const actualizar = async (req, res) => {
  await db.collection('canchas').doc(req.params.id).update(aFirestore(req.body));
  res.json({ ok: true });
};

const eliminar = async (req, res) => {
  await db.collection('canchas').doc(req.params.id).delete();
  res.json({ ok: true });
};

module.exports = { listar, crear, actualizar, eliminar };