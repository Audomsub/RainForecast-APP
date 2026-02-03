const dns = require('dns');
try {
    dns.setDefaultResultOrder('ipv4first');
    console.log("🔒 Force IPv4 First: Enabled");
} catch (e) {
    console.log("⚠️ Node version < 17, cannot force IPv4 via code.");
}

require('dotenv').config(); // โหลด .env

const express = require("express");
const morgan = require("morgan");
const cors = require("cors");
const path = require('path');

const app = express();

/* ================= Middleware ================= */

// Logger
app.use(morgan("dev"));

// Body parser  ⭐ สำคัญมาก (แก้ req.body undefined)
app.use(express.json());
app.use(express.urlencoded({ extended: true }));

// CORS
app.use(cors());

// Static
app.use('/storage', express.static(path.join(__dirname, 'storage')));

/* ================= Scheduler ================= */
require('./scheduler');

/* ================= Routes ================= */

app.use("/api/radar", require("./routes/radar.routes"));
app.use("/api/ai", require("./routes/ai.routes"));
app.use("/api/map", require("./routes/map.routes"));
app.use("/api/admin", require("./routes/admin.routes"));

/* ================= Health Check ================= */

app.get("/api/health", (req, res) => {
    res.json({ status: "OK", service: "RainForecast Backend MVC" });
});

/* ================= Server ================= */

// Render จะ inject PORT มาให้
const PORT = process.env.PORT || 3000;

app.listen(PORT, '0.0.0.0', () => {
    console.log(`🚀 API running on port: ${PORT}`);
});
