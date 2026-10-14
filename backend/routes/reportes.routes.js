const { Router } = require('express');
const { manejar } = require('../middlewares/manejarErrores');
const controller = require('../controllers/reportes.controller');

const router = Router();

router.get('/reportes/reservas', manejar(controller.reservas));

module.exports = router;
