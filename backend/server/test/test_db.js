// แก้ไข path ให้ชี้ไปที่ ../db.js (เพราะไฟล์ db.js อยู่นอกโฟลเดอร์ test หนึ่งชั้น)
const db = require('../db'); 

async function test() {
  try {
    // ลอง Query ดูตารางในฐานข้อมูล
    const [rows] = await db.query("SHOW TABLES");
    console.log("✅ เชื่อมต่อสำเร็จ! ตารางในฐานข้อมูล:", rows);
  } catch (error) {
    console.error("❌ เชื่อมต่อล้มเหลว:", error.message);
  } finally {
    // ปิดการเชื่อมต่อเมื่อเสร็จสิ้น เพื่อให้ process จบการทำงาน
    if (db) await db.end();
  }
}

test();