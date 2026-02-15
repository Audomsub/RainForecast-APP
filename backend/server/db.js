const { Pool } = require('pg');
require('dotenv').config();

// สร้าง Pool แบบมาตรฐาน (ให้ pg จัดการ DNS และ Connection เอง)
const pool = new Pool({
    connectionString: process.env.DATABASE_URL,
    ssl: { rejectUnauthorized: false } // จำเป็นสำหรับ Supabase
});

// ดักจับ Error ของ Pool เพื่อไม่ให้แอป crash เงียบๆ
pool.on('error', (err) => {
    console.error('❌ Unexpected error on idle client', err);
    process.exit(-1);
});

module.exports = {
    query: (text, params) => pool.query(text, params),
    end: () => pool.end(),
};