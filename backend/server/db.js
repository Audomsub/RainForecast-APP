const { Pool } = require('pg');
const dns = require('dns');
const { promisify } = require('util');
const { URL } = require('url');
require('dotenv').config();

const lookup = promisify(dns.lookup);
let pool = null;

// ฟังก์ชันสำหรับสร้าง Pool ที่บังคับใช้ IPv4 เสมอ
async function getPool() {
    if (pool) return pool;

    let connectionString = process.env.DATABASE_URL;

    try {
        // 🔍 แปลง Hostname เป็น IPv4 (Manual Resolve)
        const dbUrl = new URL(connectionString);
        console.log(`🔍 Resolving DNS for: ${dbUrl.hostname}`);
        
        const { address } = await lookup(dbUrl.hostname, { family: 4 });
        console.log(`✅ Force IPv4 Resolved: ${dbUrl.hostname} -> ${address}`);
        
        // แทนที่ Hostname เดิมด้วย IP ที่ได้
        dbUrl.hostname = address;
        connectionString = dbUrl.toString();
    } catch (err) {
        console.error("⚠️ DNS Lookup Failed (using original URL):", err.message);
    }

    pool = new Pool({
        connectionString: connectionString,
        ssl: { rejectUnauthorized: false }
    });

    return pool;
}

module.exports = {
    query: async (text, params) => {
        const p = await getPool();
        return p.query(text, params);
    },
    end: async () => {
        if (pool) await pool.end();
    },
};