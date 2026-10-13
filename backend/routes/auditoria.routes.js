const { Router } = require('express');
const { manejar } = require('../middlewares/manejarErrores');
const controller = require('../controllers/auditoria.controller');

const router = Router();

router.get('/auditoria', manejar(controller.listar));

module.exports = router;