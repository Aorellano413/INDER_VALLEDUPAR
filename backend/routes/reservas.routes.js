const { Router } = require('express');
const { manejar } = require('../middlewares/manejarErrores');
const controller = require('../controllers/reservas.controller');

const router = Router();

router.post('/reservas', manejar(controller.crear));
router.get('/reservas', manejar(controller.listar));
router.get('/reservas-completas', manejar(controller.listarCompletas));
router.patch('/reservas/:id/estado', manejar(controller.actualizarEstado));
router.delete('/reservas/:id', manejar(controller.eliminar));
router.get('/disponibilidad', manejar(controller.disponibilidad));

module.exports = router;