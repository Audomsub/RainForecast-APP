const db = require("../db");

exports.create = async ({ filename, filepath, source_url }) => {
    // Database ต้องการ filename, filepath, source_url
    // ซึ่งตอนนี้ Service ส่งมาครบแล้ว
    const { rows } = await db.query(
        "INSERT INTO radar_images (filename, filepath, source_url) VALUES ($1, $2, $3) RETURNING *",
        [filename, filepath, source_url]
    );
    return rows[0];
};

exports.getLatest = async () => {
    const { rows } = await db.query("SELECT * FROM radar_images ORDER BY id DESC LIMIT 1");
    return rows[0];
};

exports.getById = async (id) => {
    const { rows } = await db.query("SELECT * FROM radar_images WHERE id = $1", [id]);
    return rows[0];
};

exports.getAll = async () => {
    const { rows } = await db.query("SELECT * FROM radar_images ORDER BY id DESC");
    return rows;
};

exports.deleteById = async (id) => {
    const { rows } = await db.query("DELETE FROM radar_images WHERE id = $1", [id]);
    return rows;
};