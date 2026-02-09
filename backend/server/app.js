const dns = require('dns');
dns.setDefaultResultOrder('ipv4first');

require('dotenv').config();

const express = require("express");
const morgan = require("morgan");
const cors = require("cors");
const path = require('path');

const app = express();

/* ================= Middleware ================= */

app.use(morgan("dev"));
app.use(express.json());
app.use(express.urlencoded({ extended: true }));
app.use(cors());

app.use('/storage', express.static(path.join(__dirname, 'storage')));

/* ================= Scheduler ================= */
require('./scheduler');

/* ================= Routes ================= */

app.use("/api/radar", require("./routes/radar.routes"));
app.use("/api/ai", require("./routes/ai.routes"));
app.use("/api/map", require("./routes/map.routes"));
app.use("/api/admin", require("./routes/admin.routes"));

app.get('/', (req, res) => {
    res.json({
        status: "Online",
        service: "Rain Forecast API",
        message: "Server is running smoothly."
    });
});

/* ================= Health Check ================= */

app.get("/api/health", (req, res) => {
    res.json({ status: "OK", service: "RainForecast Backend MVC" });
});

/* ================= Server ================= */

const PORT = process.env.PORT || 3000;
app.listen(PORT, '0.0.0.0', () => {
    console.log(`🚀 API running on port: ${PORT}`);
});
