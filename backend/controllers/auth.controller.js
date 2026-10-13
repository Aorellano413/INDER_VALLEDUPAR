const { db } = require('../config/firebase');
const { serializar } = require('../utils/serializar');

const login = async (req, res) => {
  const { correo, password } = req.body;
  const snap = await db.collection('usuarios')
    .where('correo', '==', correo)
    .limit(1)
    .get();

  if (snap.empty) {
    return res.status(401).json({ error: 'Usuario no encontrado' });
  }

  const doc = snap.docs[0];
  const usuario = doc.data();

  if (usuario.password !== password) {
    return res.status(401).json({ error: 'Contraseña incorrecta' });
  }

  delete usuario.password;
  res.json({ id: doc.id, ...serializar(usuario) });
};

module.exports = { login };