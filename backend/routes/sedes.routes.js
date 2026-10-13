const { Router } = require('express');
const { manejar } = require('../middlewares/manejarErrores');
const controller = require('../controllers/sedes.controller');

const router = Router();

router.get('/sedes', manejar(controller.listar));
router.post('/sedes', manejar(controller.crear));
router.put('/sedes/:id', manejar(controller.actualizar));
router.delete('/sedes/:id', manejar(controller.eliminar));

module.exports = router;