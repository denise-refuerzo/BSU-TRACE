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
// 6. FETCH USER DASHBOARD STATS ENDPOINT
// Route: GET /api/users/:id/dashboard-stats
// ==========================================
app.get('/api/users/:id/dashboard-stats', async (req, res) => {
  const userId = req.params.id;

  try {
    const query = `
      SELECT 
        COUNT(i.ini_id) AS total_docs,
        SUM(CASE WHEN s.current_status = 'pending' THEN 1 ELSE 0 END) AS pending_docs,
        SUM(CASE WHEN s.current_status = 'Completed' THEN 1 ELSE 0 END) AS completed_docs,
        -- Assuming 'Archived' logic, otherwise defaults to 0
        SUM(CASE WHEN s.current_status = 'Archived' THEN 1 ELSE 0 END) AS archived_docs
      FROM public.initial_document i
      LEFT JOIN public.processed_document pd ON i.ini_id = pd.ini_id
      LEFT JOIN public.status s ON pd.s_id = s.s_id
      WHERE i.u_id = $1
    `;

    const result = await pool.query(query, [userId]);
    
    // If user has no documents, SUM returns null, so we default to 0
    const stats = result.rows[0];
    res.status(200).json({
      total_docs: stats.total_docs || 0,
      pending_docs: stats.pending_docs || 0,
      completed_docs: stats.completed_docs || 0,
      archived_docs: stats.archived_docs || 0
    });

  } catch (error) {
    console.error('Dashboard Stats Fetch Error:', error);
    res.status(500).json({ error: 'Internal server error' });
  }
});

// ==========================================
// 7. FETCH USER-SPECIFIC DOCUMENTS ENDPOINT
// Route: GET /api/users/:id/documents
// ==========================================
app.get('/api/users/:id/documents', async (req, res) => {
  const userId = req.params.id;

  try {
    const query = `
      WITH RankedDocs AS (
        SELECT 
          i.ini_id,
          i.title,
          p.process_name AS form_type,
          o.office_name AS current_location,
          s.current_status AS status,
          pd.time_in AS updated_at,
          ROW_NUMBER() OVER (PARTITION BY i.ini_id ORDER BY pd.time_in DESC) as rn
        FROM public.initial_document i
        LEFT JOIN public.process_type p ON i.p_id = p.p_id
        LEFT JOIN public.processed_document pd ON i.ini_id = pd.ini_id
        LEFT JOIN public.status s ON pd.s_id = s.s_id
        LEFT JOIN public.offices o ON pd.current_office_id = o.o_id
        WHERE i.u_id = $1
      )
      SELECT * FROM RankedDocs WHERE rn = 1 ORDER BY updated_at DESC;
    `;

    const result = await pool.query(query, [userId]);
    res.status(200).json(result.rows);

  } catch (error) {
    console.error('User Documents Fetch Error:', error);
    res.status(500).json({ error: 'Internal server error' });
  }
});

// ==========================================
// 8. FETCH SPECIFIC DOCUMENT DETAILS ENDPOINT
// Route: GET /api/documents/:id/details
// ==========================================
app.get('/api/documents/:id/details', async (req, res) => {
  const docId = req.params.id;

  try {
    // 1. Fetch main document info (Requestor, EDC, Title, QR, Status)
    const detailsQuery = `
      SELECT 
        i.ini_id, i.title, i.edc, i.qr_code,
        u.full_name AS requestor,
        p.process_name AS form_type,
        s.current_status AS status
      FROM public.initial_document i
      JOIN public."User" u ON i.u_id = u.u_id
      JOIN public.process_type p ON i.p_id = p.p_id
      LEFT JOIN public.processed_document pd ON i.ini_id = pd.ini_id
      LEFT JOIN public.status s ON pd.s_id = s.s_id
      WHERE i.ini_id = $1
      ORDER BY pd.time_in DESC
      LIMIT 1;
    `;
    const detailsResult = await pool.query(detailsQuery, [docId]);
    
    if (detailsResult.rows.length === 0) {
      return res.status(404).json({ error: 'Document not found' });
    }

    // 2. Fetch routing timeline history
    const historyQuery = `
      SELECT 
        o.office_name, 
        pd.time_in, 
        pd.time_out, 
        s.current_status
      FROM public.processed_document pd
      JOIN public.offices o ON pd.current_office_id = o.o_id
      JOIN public.status s ON pd.s_id = s.s_id
      WHERE pd.ini_id = $1
      ORDER BY pd.time_in ASC;
    `;
    const historyResult = await pool.query(historyQuery, [docId]);

    // Combine and send back
    res.status(200).json({
      ...detailsResult.rows[0],
      history: historyResult.rows
    });

  } catch (error) {
    console.error('Document Details Fetch Error:', error);
    res.status(500).json({ error: 'Internal server error' });
  }
});

// ==========================================
// 9. FETCH PROCESS TYPES ENDPOINT (For Dropdowns)
// Route: GET /api/process-types
// ==========================================
app.get('/api/process-types', async (req, res) => {
  try {
    const result = await pool.query('SELECT p_id, process_name FROM public.process_type ORDER BY p_id ASC');
    res.status(200).json(result.rows);
  } catch (error) {
    console.error('Process Types Fetch Error:', error);
    res.status(500).json({ error: 'Internal server error' });
  }
});

// ==========================================
// 10. CREATE NEW DOCUMENT ENDPOINT
// Route: POST /api/documents
// ==========================================
app.post('/api/documents', async (req, res) => {
  const { u_id, title, p_id } = req.body;

  if (!u_id || !title || !p_id) {
    return res.status(400).json({ error: 'Missing required fields' });
  }

  try {
    // 1. Get the first office from the predefined route for this process type
    const processResult = await pool.query(
      'SELECT r.stop_1 FROM public.process_type p JOIN public.route r ON p.r_id = r.r_id WHERE p.p_id = $1',
      [p_id]
    );

    if (processResult.rows.length === 0) {
      return res.status(404).json({ error: 'Process type not found' });
    }

    const firstOfficeId = processResult.rows[0].stop_1;

    // 2. Generate a unique tracking code & estimated completion date (7 days from now)
    const qrCode = `TRK-${Date.now()}-${Math.floor(Math.random() * 100)}`;
    const edcDate = new Date();
    edcDate.setDate(edcDate.getDate() + 7);

    // 3. Insert into initial_document
    const insertDocQuery = `
      INSERT INTO public.initial_document (p_id, u_id, title, edc, qr_code)
      VALUES ($1, $2, $3, $4, $5)
      RETURNING ini_id
    `;
    const docResult = await pool.query(insertDocQuery, [p_id, u_id, title, edcDate, qrCode]);
    const newIniId = docResult.rows[0].ini_id;

    // 4. Create the first processed_document entry (s_id = 1 is 'pending') to initiate tracking
    const insertTrackQuery = `
      INSERT INTO public.processed_document (ini_id, s_id, current_office_id, time_in)
      VALUES ($1, 1, $2, CURRENT_TIMESTAMP)
    `;
    await pool.query(insertTrackQuery, [newIniId, firstOfficeId]);

    res.status(201).json({ message: 'Document created successfully', qr_code: qrCode });

  } catch (error) {
    console.error('Create Document Error:', error);
    res.status(500).json({ error: 'Internal server error' });
  }
});

// ==========================================
// 11. FETCH ALL BOOKINGS FOR SCHEDULER
// Route: GET /api/scheduler/bookings
// ==========================================
app.get('/api/scheduler/bookings', async (req, res) => {
  try {
    const query = `
      SELECT 
          b.booking_id, b.booking_type, b.department, b.reservation_date, b.purpose, b.status,
          u.full_name AS requestor,
          COALESCE(g.start_time, v.pick_up_time) AS start_time,
          COALESCE(g.end_time, v.drop_off_time) AS end_time,
          v.destination
      FROM public.bookings b
      JOIN public."User" u ON b.u_id = u.u_id
      LEFT JOIN public.gm_requirements g ON b.booking_id = g.booking_id
      LEFT JOIN public.vehicle_requirements v ON b.booking_id = v.booking_id
      ORDER BY b.reservation_date ASC, start_time ASC;
    `;
    const result = await pool.query(query);
    res.status(200).json(result.rows);
  } catch (error) {
    console.error('Scheduler Bookings Fetch Error:', error);
    res.status(500).json({ error: 'Internal server error' });
  }
});

// ==========================================
// 12. FETCH LOGISTICS INVENTORY
// Route: GET /api/scheduler/inventory
// ==========================================
app.get('/api/scheduler/inventory', async (req, res) => {
  try {
    const query = `
      SELECT asset_name, quantity 
      FROM public.asset_details 
      WHERE asset_name IN ('Stackable Chairs', 'Folding Table')
    `;
    const result = await pool.query(query);
    res.status(200).json(result.rows);
  } catch (error) {
    console.error('Inventory Fetch Error:', error);
    res.status(500).json({ error: 'Internal server error' });
  }
});

// ==========================================
// 13. CREATE NEW BOOKING (SCHEDULER)
// Route: POST /api/scheduler/bookings
// ==========================================
app.post('/api/scheduler/bookings', async (req, res) => {
  const { u_id, booking_type, reservation_date, purpose, destination, start_time, end_time, asset_name } = req.body;

  try {
    // Start a SQL Transaction. If any step fails, it cancels everything.
    await pool.query('BEGIN'); 

    // 1. Get the user's exact department from the database
    const deptResult = await pool.query(
      'SELECT d.department_name FROM public."User" u JOIN public.department d ON u.d_id = d.d_id WHERE u.u_id = $1',
      [u_id]
    );
    const department = deptResult.rows.length > 0 ? deptResult.rows[0].department_name : 'General';

    // 2. Insert into the main Bookings table
    const bookingQuery = `
      INSERT INTO public.bookings (u_id, booking_type, department, reservation_date, purpose, status)
      VALUES ($1, $2, $3, $4, $5, 'Reserved')
      RETURNING booking_id;
    `;
    const bookingResult = await pool.query(bookingQuery, [u_id, booking_type, department, reservation_date, purpose]);
    const bookingId = bookingResult.rows[0].booking_id;

    // 3. Find the correct Asset ID based on what was requested (Van, Gymnasium, Multimedia Room)
    const assetQuery = `SELECT asd_id FROM public.asset_details WHERE asset_name = $1 LIMIT 1;`;
    const assetResult = await pool.query(assetQuery, [asset_name]);
    const asd_id = assetResult.rows.length > 0 ? assetResult.rows[0].asd_id : 1; 

    // 4. Insert into specific resource requirement tables
    if (booking_type === 'Vehicle') {
      const vQuery = `
        INSERT INTO public.vehicle_requirements (asd_id, sv_id, booking_id, destination, passenger_count, pick_up_time, drop_off_time)
        VALUES ($1, 3, $2, $3, 1, $4, $5);
      `;
      // sv_id = 3 corresponds to 'Both' (Pick-up and Drop-off) in your seed data
      await pool.query(vQuery, [asd_id, bookingId, destination || purpose, start_time, end_time]);
    } else {
      const gmQuery = `
        INSERT INTO public.gm_requirements (asd_id, booking_id, start_time, end_time, expected_attendees)
        VALUES ($1, $2, $3, $4, 10);
      `;
      await pool.query(gmQuery, [asd_id, bookingId, start_time, end_time]);
    }

    // Save the transaction
    await pool.query('COMMIT'); 
    res.status(201).json({ message: 'Booking created successfully' });

  } catch (error) {
    // Cancel the transaction if an error occurred
    await pool.query('ROLLBACK'); 
    console.error('Create Booking Error:', error);
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