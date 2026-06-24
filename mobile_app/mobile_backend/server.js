// require('dotenv').config();
const express = require('express');
const cors = require('cors');
const { Pool } = require('pg');
const bcrypt = require('bcrypt');

const app = express();

// ==========================================
// MIDDLEWARE & CONFIGURATION
// ==========================================
app.use(cors());
app.use(express.json());

// Neon PostgreSQL Connection Pool
const pool = new Pool({
  connectionString: process.env.DATABASE_URL,
  ssl: {
    rejectUnauthorized: false // Required for Neon serverless connections
  }
});

// Test the database connection on startup
pool.connect((err, client, release) => {
  if (err) {
    return console.error('Error acquiring client', err.stack);
  }
  console.log('Successfully connected to the Neon PostgreSQL database');
  release();
});


// ==========================================
// 1. LOGIN ENDPOINT
// Route: POST /api/login
// ==========================================
app.post('/api/login', async (req, res) => {
  const { username, password } = req.body;

  try {
    const result = await pool.query(
      'SELECT u_id, password, a_id FROM public."User" WHERE username = $1',
      [username]
    );

    if (result.rows.length === 0) {
      return res.status(401).json({ error: 'Invalid credentials' });
    }

    const user = result.rows[0];

    const isMatch = await bcrypt.compare(password, user.password);
    if (!isMatch) {
      return res.status(401).json({ error: 'Invalid credentials' });
    }

    res.status(200).json({
      u_id: user.u_id,
      a_id: user.a_id
    });

  } catch (error) {
    console.error('Login Error:', error);
    res.status(500).json({ error: 'Internal server error' });
  }
});


// ==========================================
// 2. FETCH USER PROFILE ENDPOINT
// Route: GET /api/users/:id
// ==========================================
app.get('/api/users/:id', async (req, res) => {
  const userId = req.params.id;

  try {
    const query = `
      SELECT 
        u.u_id, 
        u.full_name, 
        u.uni_email, 
        u.faculty_id, 
        u.two_fa_enabled,
        a.account_type, 
        d.department_name
      FROM public."User" u
      JOIN public.account a ON u.a_id = a.a_id
      JOIN public.department d ON u.d_id = d.d_id
      WHERE u.u_id = $1
    `;

    const result = await pool.query(query, [userId]);

    if (result.rows.length === 0) {
      return res.status(404).json({ error: 'User not found' });
    }

    res.status(200).json(result.rows[0]);

  } catch (error) {
    console.error('Profile Fetch Error:', error);
    res.status(500).json({ error: 'Internal server error' });
  }
});


// ==========================================
// 3. UPDATE USER PROFILE DETAILS ENDPOINT
// Route: PUT /api/users/:id
// ==========================================
app.put('/api/users/:id', async (req, res) => {
  const userId = req.params.id;
  const { full_name, uni_email, two_fa_enabled } = req.body;

  try {
    const query = `
      UPDATE public."User"
      SET full_name = $1, 
          uni_email = $2, 
          two_fa_enabled = $3
      WHERE u_id = $4
      RETURNING u_id
    `;
    
    const values = [full_name, uni_email, two_fa_enabled, userId];
    const result = await pool.query(query, values);

    if (result.rows.length === 0) {
      return res.status(404).json({ error: 'User not found' });
    }

    res.status(200).json({ message: 'Profile updated successfully' });

  } catch (error) {
    console.error('Update Profile Error:', error);
    res.status(500).json({ error: 'Internal server error' });
  }
});


// ==========================================
// 4. CHANGE PASSWORD ENDPOINT
// Route: PUT /api/users/:id/password
// ==========================================
app.put('/api/users/:id/password', async (req, res) => {
  const userId = req.params.id;
  const { currentPassword, newPassword } = req.body;

  if (!currentPassword || !newPassword) {
    return res.status(400).json({ error: 'Both current and new passwords are required.' });
  }

  try {
    // Fetch current hashed password
    const userResult = await pool.query(
      'SELECT password FROM public."User" WHERE u_id = $1',
      [userId]
    );

    if (userResult.rows.length === 0) {
      return res.status(404).json({ error: 'User not found.' });
    }

    const currentHashedPassword = userResult.rows[0].password;

    // Verify current password
    const isMatch = await bcrypt.compare(currentPassword, currentHashedPassword);
    if (!isMatch) {
      return res.status(401).json({ error: 'Incorrect current password.' });
    }

    // Hash new password
    const saltRounds = 10;
    const newHashedPassword = await bcrypt.hash(newPassword, saltRounds);

    // Update the database
    await pool.query(
      'UPDATE public."User" SET password = $1 WHERE u_id = $2',
      [newHashedPassword, userId]
    );

    res.status(200).json({ message: 'Password updated successfully.' });

  } catch (error) {
    console.error('Password Update Error:', error);
    res.status(500).json({ error: 'Internal server error' });
  }
});


// ==========================================
// 5. FETCH DOCUMENTS LIST ENDPOINT
// Route: GET /api/documents
// ==========================================
app.get('/api/documents', async (req, res) => {
  try {
    const query = `
      SELECT 
        i.title, 
        p.process_name AS form_type, 
        o.office_name AS origin_office, 
        s.current_status AS status, 
        pd.time_in AS created_at
      FROM public.initial_document i
      JOIN public.process_type p ON i.p_id = p.p_id
      JOIN public.processed_document pd ON i.ini_id = pd.ini_id
      JOIN public.status s ON pd.s_id = s.s_id
      JOIN public.offices o ON pd.current_office_id = o.o_id
      ORDER BY pd.time_in DESC
    `;

    const result = await pool.query(query);
    res.status(200).json(result.rows);

  } catch (error) {
    console.error('Document Fetch Error:', error);
    res.status(500).json({ error: 'Internal server error' });
  }
});


// ==========================================
// SERVER INITIALIZATION
// ==========================================
const PORT = process.env.PORT || 3000;
app.listen(PORT, () => {
  console.log(`API Server running on port ${PORT}`);
});