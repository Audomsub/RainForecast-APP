const dns = require('dns');
try {
    dns.setDefaultResultOrder('ipv4first');
    console.log("🔒 Force IPv4 First: Enabled");
} catch (e) {
    console.log("⚠️ Node version < 17, cannot force IPv4 via code.");
}

const express = require("express");
const morgan = require("morgan");
const app = express();

app.use(morgan("dev"));
app.use(express.json());
require('./scheduler');

app.use("/api/radar", require("./routes/radar.routes"));
app.use("/api/ai", require("./routes/ai.routes"));
app.use("/api/map", require("./routes/map.routes"));


app.get("/api/health", (req,res)=>{
res.json({status:"OK", service:"RainForecast Backend MVC"});
});


app.listen(3000, ()=>console.log("API running :3000"));

