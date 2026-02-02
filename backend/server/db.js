const { Pool } = require('pg');
require('dotenv').config();

const pool = new Pool({
    connectionString: process.env.DATABASE_URL,
    ssl: { rejectUnauthorized: false } // จำเป็นสำหรับต่อ Supabase
});

console.log("🔌 Connecting to Supabase (PostgreSQL)...");

module.exports = {
    query: (text, params) => pool.query(text, params),
    end: () => pool.end(),
};