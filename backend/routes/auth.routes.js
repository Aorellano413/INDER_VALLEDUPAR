const { Router } = require('express');
const { manejar } = require('../middlewares/manejarErrores');
const controller = require('../controllers/auth.controller');

const router = Router();

router.post('/login', manejar(controller.login));

module.exports = router;