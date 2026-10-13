const { Router } = require('express');
const { manejar } = require('../middlewares/manejarErrores');
const controller = require('../controllers/canchas.controller');

const router = Router();

router.get('/canchas', manejar(controller.listar));
router.post('/canchas', manejar(controller.crear));
router.put('/canchas/:id', manejar(controller.actualizar));
router.delete('/canchas/:id', manejar(controller.eliminar));

module.exports = router;