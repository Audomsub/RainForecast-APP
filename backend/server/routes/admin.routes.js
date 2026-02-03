const express = require("express");
const router = express.Router();
const admincontroller = require("../controller/admincontroller");

router.post("/login", admincontroller.loginAdmin);

module.exports = router;

