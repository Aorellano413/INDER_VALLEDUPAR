const express = require('express');
const cors = require('cors');

const authRoutes = require('./routes/auth.routes');
const sedesRoutes = require('./routes/sedes.routes');
const canchasRoutes = require('./routes/canchas.routes');
const reservasRoutes = require('./routes/reservas.routes');
const bloqueosRoutes = require('./routes/bloqueos.routes');
const estadisticasRoutes = require('./routes/estadisticas.routes');

const app = express();
const PORT = 3000;

app.use(cors());
app.use(express.json());

app.get('/', (req, res) => {
  res.json({ mensaje: '¡El backend de INDER Valledupar está corriendo!' });
});

app.use('/api', authRoutes);
app.use('/api', sedesRoutes);
app.use('/api', canchasRoutes);
app.use('/api', reservasRoutes);
app.use('/api', bloqueosRoutes);
app.use('/api', estadisticasRoutes);

app.listen(PORT, () => {
  console.log(`Servidor corriendo en http://localhost:${PORT}`);
});