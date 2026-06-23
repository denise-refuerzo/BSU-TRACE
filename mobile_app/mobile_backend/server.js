// 1. Imports
const express = require('express');
const bcrypt = require('bcrypt');
const { Pool } = require('pg');

// 2. Initialize App
const app = express();

// 3. Middleware (Required to parse Flutter requests)
app.use(express.json());
app.use(express.urlencoded({ extended: true }));

// 4. Database Connection
const pool = new Pool({
  connectionString: process.env.DATABASE_URL,
  ssl: { rejectUnauthorized: false }
});

// --- ROUTES ---

// Login Endpoint
app.post('/api/login', async (req, res) => {
  const { username, password, role } = req.body;
  try {
    const userQuery = await pool.query(
      'SELECT * FROM public."User" WHERE username = $1 OR uni_email = $1',
      [username]
    );
    if (userQuery.rows.length === 0) return res.status(401).json({ error: 'User not found' });
    const user = userQuery.rows[0];
    const isMatch = await bcrypt.compare(password, user.password);
    if (!isMatch) return res.status(401).json({ error: 'Incorrect password' });

    const roleMap = { 'user': 1, 'processor': 2, 'signee': 3, 'admin': 4, 'ictAdmin': 5 };
    if (user.a_id !== roleMap[role]) return res.status(403).json({ error: 'Unauthorized role' });

    res.status(200).json({ a_id: user.a_id, u_id: user.u_id, full_name: user.full_name });
  } catch (error) {
    res.status(500).json({ error: 'Server error' });
  }
});

// Documents Endpoint
app.get('/api/documents', async (req, res) => {
  try {
    const query = `
      SELECT d.ini_id, d.title, p.process_name AS form_type, o.office_name AS origin_office, s.current_status AS status
      FROM public.initial_document d
      LEFT JOIN public.process_type p ON d.p_id = p.p_id
      LEFT JOIN public.processed_document pd ON d.ini_id = pd.ini_id
      LEFT JOIN public.offices o ON pd.current_office_id = o.o_id
      LEFT JOIN public.status s ON pd.s_id = s.s_id;
    `;
    const result = await pool.query(query);
    res.status(200).json(result.rows);
  } catch (error) {
    res.status(500).json({ error: 'Failed to fetch documents' });
  }
});

// Tracking Endpoint
app.get('/api/tracking/:document_id', async (req, res) => {
  try {
    const result = await pool.query('SELECT o.office_name, s.current_status, pd.time_in FROM public.processed_document pd JOIN public.offices o ON pd.current_office_id = o.o_id JOIN public.status s ON pd.s_id = s.s_id WHERE pd.ini_id = $1', [req.params.document_id]);
    res.status(200).json(result.rows);
  } catch (error) {
    res.status(500).json({ error: 'Failed to fetch tracking' });
  }
});

// Bookings Endpoint
app.get('/api/bookings', async (req, res) => {
  try {
    const result = await pool.query('SELECT * FROM public.bookings ORDER BY reservation_date ASC');
    res.status(200).json(result.rows);
  } catch (error) {
    res.status(500).json({ error: 'Failed to fetch bookings' });
  }
});

// 5. Start Server
const PORT = process.env.PORT || 3000;
app.listen(PORT, () => console.log(`🚀 API Server running on port ${PORT}`));