const express = require('express');
const cors = require('cors');
const jwt = require('jwt-simple');
const bcrypt = require('bcrypt');
const pool = require('./db');
require('dotenv').config();

const app = express();
app.use(cors());
app.use(express.json());

const JWT_SECRET = process.env.JWT_SECRET || 'your_super_secret_jwt_key';

// 1. CONDITIONAL LOGIN ENDPOINT WITH 2FA VERIFICATION CHANNELS
app.post('/api/login', async (req, res) => {
  const { username, password, pinCode } = req.body;
  try {
    const result = await pool.query(
      `SELECT u.*, a.account_type, d.department_name 
       FROM public."User" u
       JOIN public.account a ON u.a_id = a.a_id
       JOIN public.department d ON u.d_id = d.d_id
       WHERE u.username = $1`, 
      [username]
    );

    if (result.rows.length === 0) return res.status(401).json({ error: 'Invalid username or password' });

    const user = result.rows[0];
    const isMatch = await bcrypt.compare(password, user.password);
    if (!isMatch) return res.status(401).json({ error: 'Invalid username or password' });

    // Conditional Step: If user enabled 2FA and hasn't provided the PIN yet
    if (user.two_fa_enabled && !pinCode) {
      return res.json({ require2FA: true });
    }

    // Verify PIN if 2FA is active
    if (user.two_fa_enabled && pinCode) {
      if (user.two_fa_code !== pinCode) {
        return res.status(401).json({ error: 'Invalid security PIN combination code' });
      }
    }

    const token = jwt.encode({ u_id: user.u_id, username: user.username, a_id: user.a_id }, JWT_SECRET);
    res.json({ 
      token, 
      role: user.a_id, 
      roleName: user.account_type,
      fullName: user.full_name, 
      userId: user.u_id 
    });
  } catch (err) {
    console.error(err);
    res.status(500).json({ error: 'Server logging calculation error' });
  }
});

// 2. RETRIEVE DETAILED PROFILE METADATA
app.get('/api/profile/:userId', async (req, res) => {
  try {
    const result = await pool.query(
      `SELECT u.u_id, u.full_name, u.uni_email, u.faculty_id, u.two_fa_enabled, u.two_fa_code,
              a.account_type, d.department_name
       FROM public."User" u
       JOIN public.account a ON u.a_id = a.a_id
       JOIN public.department d ON u.d_id = d.d_id
       WHERE u.u_id = $1`,
      [req.params.userId]
    );
    if (result.rows.length === 0) return res.status(404).json({ error: 'User profiles entry missing' });
    res.json(result.rows[0]);
  } catch (err) {
    res.status(500).json({ error: 'Failed to look up user metadata frame' });
  }
});

// 3. RE-INDEX AND SAVE PROFILE CHANGES
app.put('/api/profile/:userId', async (req, res) => {
  const { fullName, email, twoFaEnabled, twoFaCode } = req.body;
  try {
    await pool.query(
      `UPDATE public."User" 
       SET full_name = $1, uni_email = $2, two_fa_enabled = $3, two_fa_code = $4
       WHERE u_id = $5`,
      [fullName, email, twoFaEnabled, twoFaCode || null, req.params.userId]
    );
    res.json({ message: 'Profile variables synchronized successfully!' });
  } catch (err) {
    res.status(500).json({ error: 'Failed to synchronize layout values' });
  }
});

// 4. SECURE PASSWORD UPDATE ENDPOINT
app.put('/api/profile/:userId/password', async (req, res) => {
  const { currentPassword, newPassword } = req.body;
  try {
    const userRes = await pool.query('SELECT password FROM public."User" WHERE u_id = $1', [req.params.userId]);
    const user = userRes.rows[0];

    const isMatch = await bcrypt.compare(currentPassword, user.password);
    if (!isMatch) return res.status(400).json({ error: 'Current password credentials record mismatch' });

    const newHashed = await bcrypt.hash(newPassword, 10);
    await pool.query('UPDATE public."User" SET password = $1 WHERE u_id = $2', [newHashed, req.params.userId]);
    res.json({ message: 'Credentials records changed cleanly' });
  } catch (err) {
    res.status(500).json({ error: 'Failed to rewrite target security credentials record' });
  }
});

// --- Existing Dashboard Endpoints Appended Below ---
app.get('/api/process-types', async (req, res) => {
  try {
    const query = `
      SELECT p.p_id, p.process_name, r.r_id,
             o1.office_name as stop_1_name, o2.office_name as stop_2_name, 
             o3.office_name as stop_3_name, o4.office_name as stop_4_name,
             o5.office_name as stop_5_name, o6.office_name as stop_6_name, 
             o7.office_name as stop_7_name
      FROM public.process_type p
      JOIN public.route r ON p.r_id = r.r_id
      LEFT JOIN public.offices o1 ON r.stop_1 = o1.o_id
      LEFT JOIN public.offices o2 ON r.stop_2 = o2.o_id
      LEFT JOIN public.offices o3 ON r.stop_3 = o3.o_id
      LEFT JOIN public.offices o4 ON r.stop_4 = o4.o_id
      LEFT JOIN public.offices o5 ON r.stop_5 = o5.o_id
      LEFT JOIN public.offices o6 ON r.stop_6 = o6.o_id
      LEFT JOIN public.offices o7 ON r.stop_7 = o7.o_id`;
    const result = await pool.query(query);
    res.json(result.rows);
  } catch (err) { res.status(500).json({ error: 'Failed to pull' }); }
});

app.get('/api/documents/:userId', async (req, res) => {
  try {
    const query = `
      SELECT idoc.ini_id, idoc.title, idoc.edc, idoc.qr_code, pt.process_name,
             curr_o.office_name as current_office, next_o.office_name as next_office, st.current_status as status
      FROM public.initial_document idoc
      JOIN public.process_type pt ON idoc.p_id = pt.p_id
      LEFT JOIN public.processed_document pdoc ON idoc.ini_id = pdoc.ini_id
      LEFT JOIN public.offices curr_o ON pdoc.current_office_id = curr_o.o_id
      LEFT JOIN public.offices next_o ON pdoc.next_office_id = next_o.o_id
      LEFT JOIN public.status st ON pdoc.s_id = st.s_id
      WHERE idoc.u_id = $1 ORDER BY pdoc.time_in DESC NULLS LAST;`;
    const result = await pool.query(query, [req.params.userId]);
    res.json(result.rows);
  } catch (err) { res.status(500).json({ error: 'Failed mapping logs' }); }
});

app.post('/api/documents', async (req, res) => {
  const { userId, title, processTypeId, edc } = req.body;
  try {
    const uniqueQrPayload = `TRK-${Date.now()}-${Math.floor(Math.random() * 1000)}`;
    const docResult = await pool.query(
      `INSERT INTO public.initial_document (p_id, u_id, title, edc, qr_code) VALUES ($1, $2, $3, $4, $5) RETURNING *`,
      [processTypeId, userId, title, edc || null, uniqueQrPayload]
    );
    const newDoc = docResult.rows[0];
    const routeResult = await pool.query(`SELECT r.stop_1, r.stop_2 FROM public.process_type pt JOIN public.route r ON pt.r_id = r.r_id WHERE pt.p_id = $1`, [processTypeId]);
    const route = routeResult.rows[0];
    if (route) {
      await pool.query(`INSERT INTO public.processed_document (ini_id, s_id, current_office_id, next_office_id) VALUES ($1, 1, $2, $3)`, [newDoc.ini_id, route.stop_1, route.stop_2]);
    }
    res.status(201).json({ message: 'Document tracking active!', qrCode: uniqueQrPayload });
  } catch (err) { res.status(500).json({ error: 'Failed' }); }
});

app.post('/api/accounts', async (req, res) => {
  const { username, password, accountType, fullName, email, departmentId } = req.body;
  try {
    const userCheck = await pool.query('SELECT * FROM public."User" WHERE username = $1 OR uni_email = $2', [username, email]);
    if (userCheck.rows.length > 0) return res.status(400).json({ error: 'Username or Email registered' });
    const hashedPassword = await bcrypt.hash(password, 10);
    await pool.query(`INSERT INTO public."User" (a_id, d_id, username, password, full_name, uni_email) VALUES ($1, $2, $3, $4, $5, $6)`, [accountType, departmentId, username, hashedPassword, fullName, email]);
    res.status(201).json({ message: 'Account generated!' });
  } catch (err) { res.status(500).json({ error: 'Failed account generation' }); }
});

// ==========================================
// 5. SCHOOL RESOURCES SCHEDULER ENDPOINTS
// ==========================================

// FETCH LIVE BOOKINGS REGISTER FOR CALENDAR POPULATION
app.get('/api/resources/bookings', async (req, res) => {
  try {
    const query = `
      SELECT b.booking_id, b.booking_type, b.reservation_date, b.purpose, b.status, u.full_name,
             gm.start_time as gm_start, gm.end_time as gm_end,
             vr.pick_up_time as vr_start, vr.drop_off_time as vr_end, vr.destination,
             ad.asset_name
      FROM public.bookings b
      JOIN public."User" u ON b.u_id = u.u_id
      LEFT JOIN public.gm_requirements gm ON b.booking_id = gm.booking_id
      LEFT JOIN public.vehicle_requirements vr ON b.booking_id = vr.booking_id
      LEFT JOIN public.asset_details ad ON (gm.asd_id = ad.asd_id OR vr.asd_id = ad.asd_id)
    `;
    const result = await pool.query(query);
    res.json(result.rows);
  } catch (err) {
    console.error("Error pulling calendar events:", err);
    res.status(500).json({ error: "Failed to load calendar reservation entries" });
  }
});

// FETCH LIVE COUNT LOGISTICS INVENTORY METRICS
app.get('/api/resources/inventory', async (req, res) => {
  try {
    const result = await pool.query(
      `SELECT asd_id, asset_name, quantity FROM public.asset_details WHERE ast_id = 3`
    );
    res.json(result.rows); // Returns stackable chairs & folding tables counts dynamically
  } catch (err) {
    res.status(500).json({ error: "Failed to grab inventory quantities" });
  }
});

// PROCESSED ASSET AND VENUE RESERVATION ROUTE SUBMISSIONS
app.post('/api/resources/book', async (req, res) => {
  const { 
    userId, bookingType, assetName, reservationDate, purpose, department,
    startTime, endTime, expectedAttendees, // GM fields
    destination, passengerCount, serviceTypeId, pickUpTime, dropOffTime // Vehicle fields
  } = req.body;

  const client = await pool.connect();
  try {
    await client.query('BEGIN');

    // 1. Resolve matching asset_details record to bind asset ID context
    const assetRes = await client.query('SELECT asd_id FROM public.asset_details WHERE asset_name = $1', [assetName]);
    if (assetRes.rows.length === 0) throw new Error("Target university asset resource not registered.");
    const asdId = assetRes.rows[0].asd_id;

    // 2. Commit parent booking row layout entry (default status matches database 'Reserved')
    const bookingRes = await client.query(
      `INSERT INTO public.bookings (u_id, booking_type, department, reservation_date, purpose)
       VALUES ($1, $2, $3, $4, $5) RETURNING booking_id`,
      [userId, bookingType, department, reservationDate, purpose]
    );
    const bookingId = bookingRes.rows[0].booking_id;

    // 3. Conditional step path: branch data distribution based on macro asset types
    if (bookingType === 'Room' || bookingType === 'Gymnasium') {
      await client.query(
        `INSERT INTO public.gm_requirements (asd_id, booking_id, start_time, end_time, expected_attendees)
         VALUES ($1, $2, $3, $4, $5)`,
        [asdId, bookingId, startTime, endTime, expectedAttendees || 0]
      );
    } else if (bookingType === 'Vehicle') {
      await client.query(
        `INSERT INTO public.vehicle_requirements (asd_id, sv_id, booking_id, destination, passenger_count, pick_up_time, drop_off_time)
         VALUES ($1, $2, $3, $4, $5, $6, $7)`,
        [asdId, serviceTypeId || 1, bookingId, destination, passengerCount || 1, pickUpTime, dropOffTime]
      );
    }

    await client.query('COMMIT');
    res.status(201).json({ message: "Reservation recorded successfully! Awaiting status validation." });
  } catch (err) {
    await client.query('ROLLBACK');
    console.error(err);
    res.status(500).json({ error: err.message || "Failed transactional database commitment sequence." });
  } finally {
    client.release();
  }
});

const PORT = 5000;
app.listen(PORT, () => console.log(`🚀 Core backend subsystem running on port ${PORT}`));