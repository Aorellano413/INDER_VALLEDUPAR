const { db } = require('../config/firebase');
const { docAJson } = require('../utils/serializar');

const listar = async (req, res) => {
  const { entidad, usuario } = req.query;

  const snap = await db.collection('auditoria')
    .orderBy('fecha', 'desc')
    .limit(500)
    .get();

  let registros = snap.docs.map(docAJson);

  if (entidad) {
    registros = registros.filter((r) => r.entidad === entidad);
  }
  if (usuario) {
    registros = registros.filter((r) =>
      (r.usuario && r.usuario.correo || '').toLowerCase().includes(usuario.toLowerCase())
    );
  }

  res.json(registros);
};

module.exports = { listar };