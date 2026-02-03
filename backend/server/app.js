// backend/server/app.js
const dns = require('dns');
try {
    dns.setDefaultResultOrder('ipv4first');
    console.log("🔒 Force IPv4 First: Enabled");
} catch (e) {
    console.log("⚠️ Node version < 17, cannot force IPv4 via code.");
}

const express = require("express");
const morgan = require("morgan");
const cors = require("cors");
const path = require('path');
const app = express();

app.use(morgan("dev"));
app.use(express.json());
require('./scheduler');
app.use(cors());

// Routes
app.use("/api/radar", require("./routes/radar.routes"));
app.use("/api/ai", require("./routes/ai.routes"));
app.use("/api/map", require("./routes/map.routes"));
app.use('/storage', express.static(path.join(__dirname, 'storage')));
app.use("/api/admin", require("./routes/admin.routes"));

app.get("/api/health", (req, res) => {
    res.json({ status: "OK", service: "RainForecast Backend MVC" });
});

// แก้ไขส่วนการ Listen Port เพื่อรองรับ Render
const PORT = process.env.PORT || 3000;
app.listen(PORT, '0.0.0.0', () => {
    console.log(`🚀 API running on port: ${PORT}`);
});