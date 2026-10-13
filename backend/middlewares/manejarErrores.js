const manejar = (fn) => async (req, res) => {
  try {
    await fn(req, res);
  } catch (error) {
    console.error(`Error en ${req.method} ${req.originalUrl}:`, error);
    res.status(500).json({ error: error.message });
  }
};

module.exports = { manejar };