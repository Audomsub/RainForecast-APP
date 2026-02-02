const db = require("../db");

exports.create = async ({ radar_id, rain_probability, level }) => {
    const { rows } = await db.query(
        "INSERT INTO predictions (radar_id, rain_probability, level) VALUES ($1, $2, $3) RETURNING *",
        [radar_id, rain_probability, level]
    );
    return rows[0];
};

exports.getAll = async () => {
    const { rows } = await db.query(`
        SELECT p.*, r.filename, r.filepath 
        FROM predictions p
        JOIN radar_images r ON p.radar_id = r.id
        ORDER BY p.created_at DESC
    `);
    return rows;
};