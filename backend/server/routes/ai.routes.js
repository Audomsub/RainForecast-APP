const router = require("express").Router();
const aiController = require("../controller/ai.controller");


router.post("/predict", aiController.predict);
router.get("/history", aiController.history);


module.exports = router;