const { Router } = require('express');
const { manejar } = require('../middlewares/manejarErrores');
const controller = require('../controllers/estadisticas.controller');

const router = Router();

router.get('/estadisticas', manejar(controller.obtener));

module.exports = router;