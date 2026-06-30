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
    rejectUnauthorized: false 
  }
});

pool.connect((err, client, release) => {
  if (err) {
    return console.error('Error acquiring client', err.stack);
  }
  console.log('Successfully connected to the Neon PostgreSQL database');
  release();
});

// ==========================================
// 1. LOGIN ENDPOINT (Updated to return two_fa_enabled)
// ==========================================
app.post('/api/login', async (req, res) => {
  const { username, password } = req.body;

  try {
    // Added two_fa_enabled to the SELECT query
    const result = await pool.query(
      'SELECT u_id, password, a_id, two_fa_enabled FROM public."User" WHERE username = $1',
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
      a_id: user.a_id,
      two_fa_enabled: user.two_fa_enabled // Tell the app if we need to ask for a PIN
    });

  } catch (error) {
    console.error('Login Error:', error);
    res.status(500).json({ error: 'Internal server error' });
  }
});

// ==========================================
// 3. UPDATE USER PROFILE DETAILS ENDPOINT (Updated to save PIN)
// ==========================================
app.put('/api/users/:id', async (req, res) => {
  const userId = req.params.id;
  const { full_name, uni_email, two_fa_enabled, two_fa_code } = req.body;

  try {
    // COALESCE ensures we don't overwrite an existing code with NULL if it isn't passed
    const query = `
      UPDATE public."User"
      SET full_name = $1, 
          uni_email = $2, 
          two_fa_enabled = $3,
          two_fa_code = COALESCE($4, two_fa_code) 
      WHERE u_id = $5
      RETURNING u_id
    `;
    
    const values = [full_name, uni_email, two_fa_enabled, two_fa_code, userId];
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
// 1.5 NEW: VERIFY 2FA ENDPOINT
// ==========================================
app.post('/api/verify-2fa', async (req, res) => {
  const { u_id, code } = req.body;

  try {
    const result = await pool.query('SELECT two_fa_code FROM public."User" WHERE u_id = $1', [u_id]);
    
    if (result.rows.length === 0) return res.status(404).json({ error: 'User not found' });

    if (result.rows[0].two_fa_code === code) {
      res.status(200).json({ success: true });
    } else {
      res.status(401).json({ error: 'Invalid PIN' });
    }
  } catch (error) {
    console.error('2FA Verification Error:', error);
    res.status(500).json({ error: 'Internal server error' });
  }
});

// ==========================================
// 2. FETCH USER PROFILE ENDPOINT
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
// ==========================================
app.put('/api/users/:id/password', async (req, res) => {
  const userId = req.params.id;
  const { currentPassword, newPassword } = req.body;

  if (!currentPassword || !newPassword) {
    return res.status(400).json({ error: 'Both current and new passwords are required.' });
  }

  try {
    const userResult = await pool.query(
      'SELECT password FROM public."User" WHERE u_id = $1',
      [userId]
    );

    if (userResult.rows.length === 0) {
      return res.status(404).json({ error: 'User not found.' });
    }

    const currentHashedPassword = userResult.rows[0].password;

    const isMatch = await bcrypt.compare(currentPassword, currentHashedPassword);
    if (!isMatch) {
      return res.status(401).json({ error: 'Incorrect current password.' });
    }

    const saltRounds = 10;
    const newHashedPassword = await bcrypt.hash(newPassword, saltRounds);

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
// ==========================================
app.get('/api/documents', async (req, res) => {
  try {
    // FIX: Uses ROW_NUMBER() to guarantee only 1 tile per document.
    // FIX: Pulls the origin from the true start of the route (r.stop_1), not the current location.
    const query = `
      WITH RankedDocs AS (
        SELECT 
          i.qr_code,
          i.title, 
          p.process_name AS form_type, 
          origin_o.office_name AS origin_office, 
          s.current_status AS status, 
          pd.time_in,
          pd.time_out,
          TO_CHAR(pd.time_in, 'YYYY-MM-DD"T"HH24:MI:SS"+08:00"') AS created_at,
          ROW_NUMBER() OVER (PARTITION BY i.ini_id ORDER BY pd.pd_id DESC) as rn
        FROM public.initial_document i
        LEFT JOIN public.process_type p ON i.p_id = p.p_id
        LEFT JOIN public.route r ON p.r_id = r.r_id
        LEFT JOIN public.offices origin_o ON r.stop_1 = origin_o.o_id
        LEFT JOIN public.processed_document pd ON i.ini_id = pd.ini_id
        LEFT JOIN public.status s ON pd.s_id = s.s_id
      )
      SELECT qr_code, title, form_type, origin_office, status, time_in, time_out, created_at
      FROM RankedDocs
      WHERE rn = 1
      ORDER BY time_in DESC NULLS LAST
    `;

    const result = await pool.query(query);
    res.status(200).json(result.rows);

  } catch (error) {
    console.error('Document Fetch Error:', error);
    res.status(500).json({ error: 'Internal server error' });
  }
});

// ==========================================
// 5.5 FETCH PROCESSOR-ISOLATED DOCUMENTS 
// ==========================================
app.get('/api/processors/:id/documents', async (req, res) => {
  const userId = req.params.id;

  try {
    const userRes = await pool.query('SELECT o_id FROM public."User" WHERE u_id = $1', [userId]);
    if (userRes.rows.length === 0 || !userRes.rows[0].o_id) {
      return res.status(404).json({ error: 'Processor office not found' });
    }
    const o_id = userRes.rows[0].o_id;

    // FIX: We removed the predictive 'route' checking. 
    // It now strictly checks if the document is CURRENTLY at their office, 
    // or if they have previously interacted with it.
    const query = `
      WITH RankedDocs AS (
        SELECT 
          i.qr_code, i.title, p.process_name AS form_type, origin_o.office_name AS origin_office, 
          s.current_status AS status, pd.time_in, pd.time_out,
          TO_CHAR(pd.time_in, 'YYYY-MM-DD"T"HH24:MI:SS"+08:00"') AS created_at,
          pd.current_office_id, pd.is_adhoc,
          ROW_NUMBER() OVER (PARTITION BY i.ini_id ORDER BY pd.pd_id DESC) as rn,
          EXISTS (
            SELECT 1 FROM public.processed_document past_pd 
            WHERE past_pd.ini_id = i.ini_id 
              AND past_pd.current_office_id = $1 
              AND past_pd.time_out IS NOT NULL
          ) as is_completed_by_me,
          EXISTS (
            SELECT 1 FROM public.processed_document all_pd 
            WHERE all_pd.ini_id = i.ini_id 
              AND all_pd.current_office_id = $1
          ) as touches_my_office
        FROM public.initial_document i
        LEFT JOIN public.process_type p ON i.p_id = p.p_id
        LEFT JOIN public.route r ON p.r_id = r.r_id
        LEFT JOIN public.offices origin_o ON r.stop_1 = origin_o.o_id
        LEFT JOIN public.processed_document pd ON i.ini_id = pd.ini_id
        LEFT JOIN public.status s ON pd.s_id = s.s_id
      )
      SELECT qr_code, title, form_type, origin_office, status, time_in, time_out, created_at, current_office_id,
        CASE WHEN current_office_id = $1 THEN true ELSE false END as is_at_current_office,
        is_adhoc, is_completed_by_me
      FROM RankedDocs
      WHERE rn = 1 
        AND touches_my_office = true
        AND status NOT ILIKE 'Completed'
      ORDER BY time_in DESC NULLS LAST
    `;

    const result = await pool.query(query, [o_id]);
    res.status(200).json(result.rows);

  } catch (error) {
    console.error('Processor Document Fetch Error:', error);
    res.status(500).json({ error: 'Internal server error' });
  }
});

// ==========================================
// 5.6 FETCH SIGNEE PENDING APPROVALS
// ==========================================
app.get('/api/signees/:id/pending-documents', async (req, res) => {
  const userId = req.params.id;

  try {
    // 1. Get the Signee's Office ID
    const userRes = await pool.query('SELECT o_id FROM public."User" WHERE u_id = $1', [userId]);
    if (userRes.rows.length === 0 || !userRes.rows[0].o_id) {
      return res.status(404).json({ error: 'Signee office not found' });
    }
    const o_id = userRes.rows[0].o_id;

    // 2. Fetch documents currently at the Signee's office waiting to be signed
    const query = `
      SELECT 
        i.qr_code, 
        i.title, 
        p.process_name AS form_type, 
        u.full_name AS requestor,
        s.current_status AS status, 
        TO_CHAR(pd.time_in, 'YYYY-MM-DD"T"HH24:MI:SS"+08:00"') AS time_in
      FROM public.processed_document pd
      JOIN public.initial_document i ON pd.ini_id = i.ini_id
      JOIN public.process_type p ON i.p_id = p.p_id
      JOIN public.status s ON pd.s_id = s.s_id
      JOIN public."User" u ON i.u_id = u.u_id
      WHERE pd.current_office_id = $1
        AND pd.time_in IS NOT NULL 
        AND pd.time_out IS NULL
        AND s.current_status IN ('pending', 'In Verification')
      ORDER BY pd.time_in ASC;
    `;

    const result = await pool.query(query, [o_id]);
    res.status(200).json(result.rows);

  } catch (error) {
    console.error('Signee Pending Documents Fetch Error:', error);
    res.status(500).json({ error: 'Internal server error' });
  }
});

// ==========================================
// 6. FETCH USER DASHBOARD STATS ENDPOINT
// ==========================================
app.get('/api/users/:id/dashboard-stats', async (req, res) => {
  const userId = req.params.id;

  try {
    const query = `
      SELECT 
        COUNT(i.ini_id) AS total_docs,
        SUM(CASE WHEN s.current_status = 'pending' THEN 1 ELSE 0 END) AS pending_docs,
        SUM(CASE WHEN s.current_status = 'Completed' THEN 1 ELSE 0 END) AS completed_docs,
        -- Changed 'Sent Back' to 'Action Required' here
        SUM(CASE WHEN s.current_status ILIKE 'Action Required' THEN 1 ELSE 0 END) AS sent_back_docs
      FROM public.initial_document i
      LEFT JOIN public.processed_document pd ON i.ini_id = pd.ini_id
      LEFT JOIN public.status s ON pd.s_id = s.s_id
      WHERE i.u_id = $1
    `;

    const result = await pool.query(query, [userId]);
    const stats = result.rows[0];
    res.status(200).json({
      total_docs: stats.total_docs || 0,
      pending_docs: stats.pending_docs || 0,
      completed_docs: stats.completed_docs || 0,
      sent_back_docs: stats.sent_back_docs || 0
    });

  } catch (error) {
    console.error('Dashboard Stats Fetch Error:', error);
    res.status(500).json({ error: 'Internal server error' });
  }
});


// ==========================================
// 7. FETCH USER-SPECIFIC DOCUMENTS ENDPOINT
// ==========================================
app.get('/api/users/:id/documents', async (req, res) => {
  const userId = req.params.id;

  try {
    const query = `
      WITH RankedDocs AS (
        SELECT 
          i.ini_id,
          i.qr_code,
          i.title,
          p.process_name AS form_type,
          o.office_name AS current_location,
          s.current_status AS status,
          -- Format directly to string in DB
          TO_CHAR(pd.time_in, 'YYYY-MM-DD"T"HH24:MI:SS"+08:00"') AS updated_at,
          pd.time_in,
          ROW_NUMBER() OVER (PARTITION BY i.ini_id ORDER BY pd.time_in DESC) as rn
        FROM public.initial_document i
        LEFT JOIN public.process_type p ON i.p_id = p.p_id
        LEFT JOIN public.processed_document pd ON i.ini_id = pd.ini_id
        LEFT JOIN public.status s ON pd.s_id = s.s_id
        LEFT JOIN public.offices o ON pd.current_office_id = o.o_id
        WHERE i.u_id = $1
      )
      SELECT ini_id, qr_code, title, form_type, current_location, status, updated_at 
      FROM RankedDocs 
      WHERE rn = 1 
      ORDER BY time_in DESC;
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
// ==========================================
app.get('/api/documents/:id/details', async (req, res) => {
  const docId = req.params.id;

  try {
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

    const historyQuery = `
      SELECT 
        o.office_name, 
        TO_CHAR(pd.time_in, 'YYYY-MM-DD"T"HH24:MI:SS"+08:00"') AS time_in, 
        TO_CHAR(pd.time_out, 'YYYY-MM-DD"T"HH24:MI:SS"+08:00"') AS time_out, 
        s.current_status
      FROM public.processed_document pd
      JOIN public.offices o ON pd.current_office_id = o.o_id
      JOIN public.status s ON pd.s_id = s.s_id
      WHERE pd.ini_id = $1
      ORDER BY pd.time_in ASC;
    `;
    const historyResult = await pool.query(historyQuery, [docId]);

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
// 9. FETCH PROCESS TYPES ENDPOINT
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
// 9.5 FETCH ROUTE FOR SPECIFIC PROCESS TYPE
// ==========================================
app.get('/api/process-types/:id/route', async (req, res) => {
  const processId = req.params.id;

  try {
    // CHANGED: We now fetch the raw integer IDs (stop_1, stop_2, etc.) 
    // instead of joining the offices table for the string names.
    // This allows the Flutter app to map them directly to the dropdown IDs.
    const query = `
      SELECT 
        r.stop_1,
        r.stop_2,
        r.stop_3,
        r.stop_4,
        r.stop_5,
        r.stop_6,
        r.stop_7
      FROM public.process_type p
      JOIN public.route r ON p.r_id = r.r_id
      WHERE p.p_id = $1;
    `;
    
    const result = await pool.query(query, [processId]);
    
    if (result.rows.length === 0) {
      return res.status(404).json({ error: 'Route not found for this process type' });
    }

    const row = result.rows[0];
    const stops = [
      row.stop_1, row.stop_2, row.stop_3, row.stop_4,
      row.stop_5, row.stop_6, row.stop_7
    ].filter(stop => stop !== null);

    res.status(200).json({ stops });
  } catch (error) {
    console.error('Fetch Process Route Error:', error);
    res.status(500).json({ error: 'Internal server error' });
  }
});

// ==========================================
// 10. CREATE NEW DOCUMENT ENDPOINT
// ==========================================
app.post('/api/documents', async (req, res) => {
  const { u_id, title, p_id, route, stops } = req.body;

  if (!u_id || !title || !p_id) {
    return res.status(400).json({ error: 'Missing required fields' });
  }

  try {
    let firstOfficeId, secondOfficeId;
    let processIdToUse = p_id;
    
    // Accept either 'route' or 'stops' array from the frontend
    const customRoute = route || stops;

    if (customRoute && Array.isArray(customRoute) && customRoute.length > 0) {
      // 1. The user explicitly defined a custom routing order (e.g., [10, 11])
      firstOfficeId = customRoute[0];
      secondOfficeId = customRoute.length > 1 ? customRoute[1] : null;

      // 2. Insert this unique route sequence into the route table to persist it
      // Note: stop_2 uses a fallback to satisfy the NOT NULL constraint if a 1-stop route is passed
      const routeInsert = await pool.query(
        `INSERT INTO public.route (stop_1, stop_2, stop_3, stop_4, stop_5, stop_6, stop_7) 
         VALUES ($1, $2, $3, $4, $5, $6, $7) RETURNING r_id`,
        [
          customRoute[0] || null, 
          customRoute.length > 1 ? customRoute[1] : customRoute[0], 
          customRoute[2] || null, customRoute[3] || null, 
          customRoute[4] || null, customRoute[5] || null, customRoute[6] || null
        ]
      );
      const newRouteId = routeInsert.rows[0].r_id;

      // 3. Fetch the base process name so the document still identifies correctly
      const pNameRes = await pool.query('SELECT process_name FROM public.process_type WHERE p_id = $1', [p_id]);
      const baseProcessName = pNameRes.rows.length > 0 ? pNameRes.rows[0].process_name : 'Custom Form';

      // 4. Create a unique process_type entry linking to the new custom route
      const processInsert = await pool.query(
        `INSERT INTO public.process_type (r_id, process_name) VALUES ($1, $2) RETURNING p_id`,
        [newRouteId, baseProcessName]
      );
      processIdToUse = processInsert.rows[0].p_id;

    } else {
      // Standard behavior: Fallback to the default hardcoded process route
      const processResult = await pool.query(
        'SELECT r.stop_1, r.stop_2 FROM public.process_type p JOIN public.route r ON p.r_id = r.r_id WHERE p.p_id = $1',
        [p_id]
      );

      if (processResult.rows.length === 0) {
        return res.status(404).json({ error: 'Process type not found' });
      }

      firstOfficeId = processResult.rows[0].stop_1;
      secondOfficeId = processResult.rows[0].stop_2;
    }

    // Generate QR and expiration date
    const qrCode = `TRK-${Date.now()}-${Math.floor(Math.random() * 100)}`;
    const edcDate = new Date();
    edcDate.setDate(edcDate.getDate() + 7);

    // Create the initial document using the resolved p_id (Custom or Default)
    const insertDocQuery = `
      INSERT INTO public.initial_document (p_id, u_id, title, edc, qr_code)
      VALUES ($1, $2, $3, $4, $5)
      RETURNING ini_id
    `;
    const docResult = await pool.query(insertDocQuery, [processIdToUse, u_id, title, edcDate, qrCode]);
    const newIniId = docResult.rows[0].ini_id;

    // Log the very first step in the tracking ledger ensuring it registers at the correct first stop
    const insertTrackQuery = `
      INSERT INTO public.processed_document (ini_id, s_id, current_office_id, next_office_id, time_in)
      VALUES ($1, 1, $2, $3, NULL)
    `;
    await pool.query(insertTrackQuery, [newIniId, firstOfficeId, secondOfficeId]);

    res.status(201).json({ message: 'Document created successfully', qr_code: qrCode });

  } catch (error) {
    console.error('Create Document Error:', error);
    res.status(500).json({ error: 'Internal server error' });
  }
});

// ==========================================
// 11. FETCH ALL BOOKINGS FOR SCHEDULER
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
// ==========================================
app.get('/api/scheduler/inventory', async (req, res) => {
  try {
    const totalQuery = `
      SELECT asset_name, quantity 
      FROM public.asset_details 
      WHERE asset_name IN ('Stackable Chairs', 'Folding Table')
    `;
    const totalResult = await pool.query(totalQuery);

    const usageQuery = `
      SELECT SUM(g.expected_attendees) as total_attendees
      FROM public.bookings b
      JOIN public.gm_requirements g ON b.booking_id = g.booking_id
      WHERE b.reservation_date = CURRENT_DATE 
      AND b.status IN ('Reserved', 'Confirmed')
    `;
    const usageResult = await pool.query(usageQuery);
    const activeAttendees = parseInt(usageResult.rows[0].total_attendees) || 0;

    const inventoryData = totalResult.rows.map(item => {
      let inUse = 0;
      
      if (item.asset_name === 'Stackable Chairs') {
        inUse = activeAttendees;
      } else if (item.asset_name === 'Folding Table') {
        inUse = Math.ceil(activeAttendees / 4);
      }
      
      return {
        asset_name: item.asset_name,
        total: item.quantity,
        in_use: inUse > item.quantity ? item.quantity : inUse 
      };
    });

    res.status(200).json(inventoryData);
  } catch (error) {
    console.error('Inventory Fetch Error:', error);
    res.status(500).json({ error: 'Internal server error' });
  }
});


// ==========================================
// 13. CREATE NEW BOOKING (SCHEDULER)
// ==========================================
app.post('/api/scheduler/bookings', async (req, res) => {
  const { u_id, booking_type, reservation_date, purpose, destination, start_time, end_time, asset_name } = req.body;

  try {
    await pool.query('BEGIN'); 

    const deptResult = await pool.query(
      'SELECT d.department_name FROM public."User" u JOIN public.department d ON u.d_id = d.d_id WHERE u.u_id = $1',
      [u_id]
    );
    const department = deptResult.rows.length > 0 ? deptResult.rows[0].department_name : 'General';

    const bookingQuery = `
      INSERT INTO public.bookings (u_id, booking_type, department, reservation_date, purpose, status)
      VALUES ($1, $2, $3, $4, $5, 'Reserved')
      RETURNING booking_id;
    `;
    const bookingResult = await pool.query(bookingQuery, [u_id, booking_type, department, reservation_date, purpose]);
    const bookingId = bookingResult.rows[0].booking_id;

    const assetQuery = `SELECT asd_id FROM public.asset_details WHERE asset_name = $1 LIMIT 1;`;
    const assetResult = await pool.query(assetQuery, [asset_name]);
    const asd_id = assetResult.rows.length > 0 ? assetResult.rows[0].asd_id : 1; 

    if (booking_type === 'Vehicle') {
      const vQuery = `
        INSERT INTO public.vehicle_requirements (asd_id, sv_id, booking_id, destination, passenger_count, pick_up_time, drop_off_time)
        VALUES ($1, 3, $2, $3, 1, $4, $5);
      `;
      await pool.query(vQuery, [asd_id, bookingId, destination || purpose, start_time, end_time]);
    } else {
      const gmQuery = `
        INSERT INTO public.gm_requirements (asd_id, booking_id, start_time, end_time, expected_attendees)
        VALUES ($1, $2, $3, $4, 10);
      `;
      await pool.query(gmQuery, [asd_id, bookingId, start_time, end_time]);
    }

    await pool.query('COMMIT'); 
    res.status(201).json({ message: 'Booking created successfully' });

  } catch (error) {
    await pool.query('ROLLBACK'); 
    console.error('Create Booking Error:', error);
    res.status(500).json({ error: 'Internal server error' });
  }
});

// ==========================================
// 14. SIGN DOCUMENT ENDPOINT
// ==========================================
app.put('/api/documents/:qrCode/sign', async (req, res) => {
  const { qrCode } = req.params;

  try {
    const docResult = await pool.query('SELECT ini_id FROM public.initial_document WHERE qr_code = $1', [qrCode]);
    if (docResult.rows.length === 0) {
      return res.status(404).json({ error: 'Document not found' });
    }
    const iniId = docResult.rows[0].ini_id;

    // Target the latest routing step and mark as Signed WITHOUT setting time_out
    await pool.query(
      `UPDATE public.processed_document 
       SET s_id = (SELECT s_id FROM public.status WHERE current_status = 'Signed' LIMIT 1)
       WHERE ini_id = $1 
       AND pd_id = (SELECT pd_id FROM public.processed_document WHERE ini_id = $1 ORDER BY time_in DESC LIMIT 1)`,
      [iniId]
    );

    res.status(200).json({ message: 'Document signed successfully' });
  } catch (error) {
    console.error('Sign Document Error:', error);
    res.status(500).json({ error: 'Internal server error' });
  }
});

// ==========================================
// 15. SCAN IN DOCUMENT (Processor)
// ==========================================
app.put('/api/documents/:qrCode/scan-in', async (req, res) => {
  const { qrCode } = req.params;

  try {
    const docResult = await pool.query(`
      SELECT pd.pd_id, pd.time_in, s.current_status, i.ini_id
      FROM public.processed_document pd
      JOIN public.initial_document i ON pd.ini_id = i.ini_id
      JOIN public.status s ON pd.s_id = s.s_id
      WHERE i.qr_code = $1 AND pd.time_in IS NULL
      ORDER BY pd.pd_id ASC 
      LIMIT 1
    `, [qrCode]);

    if (docResult.rows.length === 0) {
      return res.status(404).json({ error: 'No pending document found to scan in.' });
    }

    const { pd_id } = docResult.rows[0];

    // FIX: If it was routed ad-hoc, keep it 'In Verification'. 
    // Otherwise, standard scans become 'Pending'.
    await pool.query(
      `UPDATE public.processed_document 
       SET time_in = timezone('Asia/Manila', now()),
           s_id = CASE 
                    WHEN s_id = (SELECT s_id FROM public.status WHERE current_status ILIKE 'In Verification' LIMIT 1) THEN s_id
                    ELSE (SELECT s_id FROM public.status WHERE current_status ILIKE 'Pending' LIMIT 1)
                  END
       WHERE pd_id = $1`,
      [pd_id]
    );

    res.status(200).json({ message: 'Document scanned IN successfully.' });
  } catch (error) {
    console.error('Scan In Error:', error);
    res.status(500).json({ error: 'Internal server error' });
  }
});

// ==========================================
// 16. SCAN OUT DOCUMENT (Processor)
// ==========================================
app.put('/api/documents/:qrCode/scan-out', async (req, res) => {
  const { qrCode } = req.params;

  try {
    // FIX: Specifically look for the step that is scanned IN, but not yet scanned OUT
    const docResult = await pool.query(`
      SELECT pd.pd_id, pd.time_in, pd.time_out, s.current_status, i.ini_id
      FROM public.processed_document pd
      JOIN public.initial_document i ON pd.ini_id = i.ini_id
      JOIN public.status s ON pd.s_id = s.s_id
      WHERE i.qr_code = $1 
        AND pd.time_in IS NOT NULL 
        AND pd.time_out IS NULL
      ORDER BY pd.pd_id DESC 
      LIMIT 1
    `, [qrCode]);

    if (docResult.rows.length === 0) {
      return res.status(404).json({ error: 'No active document found ready for scan-out.' });
    }

    const { pd_id, current_status } = docResult.rows[0];
    const statusLower = current_status.toLowerCase();

    if (statusLower === 'in verification' || statusLower === 'pending') {
      return res.status(400).json({ error: 'Cannot scan out: Signee has not signed or acted upon this document yet.' });
    }

    await pool.query(
      `UPDATE public.processed_document 
       SET time_out = timezone('Asia/Manila', now()),
           s_id = (SELECT s_id FROM public.status WHERE current_status ILIKE 'Verified' LIMIT 1)
       WHERE pd_id = $1`,
      [pd_id]
    );

    res.status(200).json({ message: 'Document scanned OUT successfully.' });
  } catch (error) {
    console.error('Scan Out Error:', error);
    res.status(500).json({ error: 'Internal server error' });
  }
});

// ==========================================
// 17. FETCH PROCESSOR SCANNING TIMELINE
// ==========================================
app.get('/api/users/:id/processing-timeline', async (req, res) => {
  const userId = req.params.id;

  try {
    // 1. Find the office assigned to this processor
    const userRes = await pool.query('SELECT o_id FROM public."User" WHERE u_id = $1', [userId]);
    if (userRes.rows.length === 0) {
      return res.status(404).json({ error: 'User not found' });
    }
    const o_id = userRes.rows[0].o_id;

    // 2. Fetch records: Removed the restrictive 'NOT ILIKE pending' filter
    // to ensure 'In Verification' documents are always captured.
    const query = `
      SELECT 
        pd.pd_id,
        i.qr_code,
        i.title,
        p.process_name AS form_type,
        s.current_status AS status,
        TO_CHAR(pd.time_in, 'YYYY-MM-DD"T"HH24:MI:SS"+08:00"') AS time_in,
        TO_CHAR(pd.time_out, 'YYYY-MM-DD"T"HH24:MI:SS"+08:00"') AS time_out
      FROM public.processed_document pd
      JOIN public.initial_document i ON pd.ini_id = i.ini_id
      JOIN public.process_type p ON i.p_id = p.p_id
      JOIN public.status s ON pd.s_id = s.s_id
      WHERE pd.current_office_id = $1 
        AND pd.time_in IS NOT NULL
      ORDER BY pd.time_in DESC;
    `;

    const result = await pool.query(query, [o_id]);
    res.status(200).json(result.rows);

  } catch (error) {
    console.error('Timeline Fetch Error:', error);
    res.status(500).json({ error: 'Internal server error' });
  }
});

// ==========================================
// 18. FETCH ALL OFFICES (For Dropdowns)
// ==========================================
app.get('/api/offices', async (req, res) => {
  try {
    const result = await pool.query('SELECT o_id, office_name FROM public.offices ORDER BY office_name ASC');
    res.status(200).json(result.rows);
  } catch (error) {
    console.error('Fetch Offices Error:', error);
    res.status(500).json({ error: 'Internal server error' });
  }
});

// ==========================================
// 19. AD-HOC ROUTING ENDPOINT
// ==========================================
app.post('/api/documents/:qrCode/ad-hoc', async (req, res) => {
  const { qrCode } = req.params;
  const { target_office_id, reason } = req.body;

  if (!target_office_id) {
    return res.status(400).json({ error: 'Target office is required' });
  }

  try {
    const docResult = await pool.query('SELECT ini_id FROM public.initial_document WHERE qr_code = $1', [qrCode]);
    if (docResult.rows.length === 0) {
      return res.status(404).json({ error: 'Document not found' });
    }
    const iniId = docResult.rows[0].ini_id;

    // FIX: We revert to INSERT so history is saved.
    // The ROW_NUMBER() logic in Section 5 prevents this from showing as a duplicate tile.
    // By hardcoding the s_id to 'In Verification', the app will instantly override the 'Incoming' status.
    await pool.query(
      `INSERT INTO public.processed_document (ini_id, s_id, current_office_id, time_in)
       VALUES ($1, (SELECT s_id FROM public.status WHERE current_status ILIKE 'In Verification' LIMIT 1), $2, NULL)`,
      [iniId, target_office_id]
    );

    res.status(200).json({ message: 'Document successfully routed ad-hoc' });
  } catch (error) {
    console.error('Ad-Hoc Routing Error:', error);
    res.status(500).json({ error: 'Internal server error' });
  }
});

// ==========================================
// 20. SEND BACK DOCUMENT ENDPOINT
// ==========================================
app.put('/api/documents/:qrCode/send-back', async (req, res) => {
  const { qrCode } = req.params;

  try {
    const docResult = await pool.query('SELECT ini_id FROM public.initial_document WHERE qr_code = $1', [qrCode]);
    if (docResult.rows.length === 0) {
      return res.status(404).json({ error: 'Document not found' });
    }
    const iniId = docResult.rows[0].ini_id;

    // Target the latest routing step and mark as 'Action Required'
    await pool.query(
      `UPDATE public.processed_document 
       SET s_id = (SELECT s_id FROM public.status WHERE current_status ILIKE 'Action Required' LIMIT 1)
       WHERE ini_id = $1 
       AND pd_id = (SELECT pd_id FROM public.processed_document WHERE ini_id = $1 ORDER BY time_in DESC LIMIT 1)`,
      [iniId]
    );

    res.status(200).json({ message: 'Document sent back (Action Required) successfully' });
  } catch (error) {
    console.error('Send Back Document Error:', error);
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