// config/env.js
require('dotenv').config();

if (!process.env.SUPABASE_URL || !process.env.SUPABASE_KEY) {
    console.error("❌ ENV not loaded: SUPABASE_URL / SUPABASE_KEY missing");
}
