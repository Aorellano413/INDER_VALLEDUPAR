const { Router } = require('express');
const { manejar } = require('../middlewares/manejarErrores');
const controller = require('../controllers/bloqueos.controller');

const router = Router();

router.get('/bloqueos', manejar(controller.listar));
router.post('/bloqueos', manejar(controller.crear));
router.put('/bloqueos/:id', manejar(controller.actualizar));
router.patch('/bloqueos/:id/activo', manejar(controller.cambiarActivo));
router.delete('/bloqueos/:id', manejar(controller.eliminar));

module.exports = router;