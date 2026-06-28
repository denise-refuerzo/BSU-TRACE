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
// 1. LOGIN ENDPOINT
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
    const query = `
      SELECT 
        i.qr_code,
        i.title, 
        p.process_name AS form_type, 
        o.office_name AS origin_office, 
        s.current_status AS status, 
        pd.time_in,
        pd.time_out,
        TO_CHAR(pd.time_in, 'YYYY-MM-DD"T"HH24:MI:SS"+08:00"') AS created_at
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
// ==========================================
app.get('/api/users/:id/dashboard-stats', async (req, res) => {
  const userId = req.params.id;

  try {
    const query = `
      SELECT 
        COUNT(i.ini_id) AS total_docs,
        SUM(CASE WHEN s.current_status = 'pending' THEN 1 ELSE 0 END) AS pending_docs,
        SUM(CASE WHEN s.current_status = 'Completed' THEN 1 ELSE 0 END) AS completed_docs,
        SUM(CASE WHEN s.current_status = 'Archived' THEN 1 ELSE 0 END) AS archived_docs
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
      archived_docs: stats.archived_docs || 0
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
    const query = `
      SELECT 
        o1.office_name AS stop_1,
        o2.office_name AS stop_2,
        o3.office_name AS stop_3,
        o4.office_name AS stop_4,
        o5.office_name AS stop_5,
        o6.office_name AS stop_6,
        o7.office_name AS stop_7
      FROM public.process_type p
      JOIN public.route r ON p.r_id = r.r_id
      LEFT JOIN public.offices o1 ON r.stop_1 = o1.o_id
      LEFT JOIN public.offices o2 ON r.stop_2 = o2.o_id
      LEFT JOIN public.offices o3 ON r.stop_3 = o3.o_id
      LEFT JOIN public.offices o4 ON r.stop_4 = o4.o_id
      LEFT JOIN public.offices o5 ON r.stop_5 = o5.o_id
      LEFT JOIN public.offices o6 ON r.stop_6 = o6.o_id
      LEFT JOIN public.offices o7 ON r.stop_7 = o7.o_id
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
  const { u_id, title, p_id } = req.body;

  if (!u_id || !title || !p_id) {
    return res.status(400).json({ error: 'Missing required fields' });
  }

  try {
    const processResult = await pool.query(
      'SELECT r.stop_1 FROM public.process_type p JOIN public.route r ON p.r_id = r.r_id WHERE p.p_id = $1',
      [p_id]
    );

    if (processResult.rows.length === 0) {
      return res.status(404).json({ error: 'Process type not found' });
    }

    const firstOfficeId = processResult.rows[0].stop_1;

    const qrCode = `TRK-${Date.now()}-${Math.floor(Math.random() * 100)}`;
    const edcDate = new Date();
    edcDate.setDate(edcDate.getDate() + 7);

    const insertDocQuery = `
      INSERT INTO public.initial_document (p_id, u_id, title, edc, qr_code)
      VALUES ($1, $2, $3, $4, $5)
      RETURNING ini_id
    `;
    const docResult = await pool.query(insertDocQuery, [p_id, u_id, title, edcDate, qrCode]);
    const newIniId = docResult.rows[0].ini_id;

    // FIX: Set time_in to NULL so it isn't automatically marked "In Verification" upon creation
    const insertTrackQuery = `
      INSERT INTO public.processed_document (ini_id, s_id, current_office_id, time_in)
      VALUES ($1, 1, $2, NULL)
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

    // Target the latest routing step for this document, mark as Signed, and record the exit time
    await pool.query(
      `UPDATE public.processed_document 
       SET s_id = (SELECT s_id FROM public.status WHERE current_status = 'Signed' LIMIT 1),
           time_out = timezone('Asia/Manila', now())
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
    // 1. Find the absolute latest processing step using pd_id
    const docResult = await pool.query(`
      SELECT pd.pd_id, pd.time_in, s.current_status, i.ini_id
      FROM public.processed_document pd
      JOIN public.initial_document i ON pd.ini_id = i.ini_id
      JOIN public.status s ON pd.s_id = s.s_id
      WHERE i.qr_code = $1
      ORDER BY pd.pd_id DESC 
      LIMIT 1
    `, [qrCode]);

    if (docResult.rows.length === 0) {
      return res.status(404).json({ error: 'Document not found.' });
    }

    const { pd_id, time_in } = docResult.rows[0];

    // 2. Prevent scanning in if it has already been scanned in
    if (time_in !== null) {
      return res.status(400).json({ error: 'Document has already been scanned IN.' });
    }

    // 3. Update the record: Set time_in to now, and status to 'In Verification'
    await pool.query(
      `UPDATE public.processed_document 
       SET time_in = timezone('Asia/Manila', now()),
           s_id = (SELECT s_id FROM public.status WHERE current_status ILIKE 'In Verification' LIMIT 1)
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
    // 1. Find the absolute latest processing step using pd_id
    const docResult = await pool.query(`
      SELECT pd.pd_id, pd.time_in, pd.time_out, s.current_status, i.ini_id
      FROM public.processed_document pd
      JOIN public.initial_document i ON pd.ini_id = i.ini_id
      JOIN public.status s ON pd.s_id = s.s_id
      WHERE i.qr_code = $1
      ORDER BY pd.pd_id DESC 
      LIMIT 1
    `, [qrCode]);

    if (docResult.rows.length === 0) {
      return res.status(404).json({ error: 'Document not found.' });
    }

    const { pd_id, time_in, time_out, current_status } = docResult.rows[0];

    // 2. Prevent scanning out if already scanned out
    if (time_out !== null) {
      return res.status(400).json({ error: 'Document has already been scanned OUT.' });
    }

    // 3. Prevent scanning out if it hasn't even been scanned in yet
    if (time_in === null) {
      return res.status(400).json({ error: 'Document must be scanned IN first.' });
    }

    // 4. Prevent scanning out if the signee hasn't acted
    const statusLower = current_status.toLowerCase();
    if (statusLower === 'in verification' || statusLower === 'pending') {
      return res.status(400).json({ error: 'Cannot scan out: Signee has not signed or acted upon this document yet.' });
    }

    // 5. Update the record: Set time_out to now, and advance status to 'Verified'
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

    // 2. Fetch records including the current_status
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
        AND s.current_status NOT ILIKE 'pending'
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
// SERVER INITIALIZATION
// ==========================================
const PORT = process.env.PORT || 3000;
app.listen(PORT, () => {
  console.log(`API Server running on port ${PORT}`);
});