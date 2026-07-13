const express = require('express');
const cors = require('cors');
const jwt = require('jwt-simple');
const bcrypt = require('bcrypt');
const pool = require('./db');
const { sendResetCodeEmail } = require('./mailer');
const crypto = require('crypto');
require('dotenv').config();

const app = express();
app.use(cors());
app.use(express.json());

const JWT_SECRET = process.env.JWT_SECRET || 'your_super_secret_jwt_key';

const failed2faAttemptsTracker = {};

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

    if (user.is_active === false) {
      return res.status(403).json({ error: 'Access Revoked: This user profile has been deactivated by administration.' });
    }

    if (!failed2faAttemptsTracker[user.u_id]) {
      failed2faAttemptsTracker[user.u_id] = 0;
    }

    if (user.two_fa_enabled && failed2faAttemptsTracker[user.u_id] >= 10) {
      return res.status(423).json({ 
        error: 'Security Lockout: 10 consecutive wrong entry combinations detected. Manual security PIN reset required.',
        requiresPinReset: true 
      });
    }

    if (user.two_fa_enabled && !pinCode) {
      return res.json({ require2FA: true });
    }

    if (user.two_fa_enabled && pinCode) {
      if (user.two_fa_code !== pinCode) {
        failed2faAttemptsTracker[user.u_id] += 1;
        
        const remainingAttempts = 10 - failed2faAttemptsTracker[user.u_id];
        if (remainingAttempts <= 0) {
          return res.status(423).json({ 
            error: 'Security Lockout: 10 consecutive wrong entry combinations detected. Manual security PIN reset required.',
            requiresPinReset: true 
          });
        }
        
        return res.status(401).json({ 
          error: `Invalid security PIN code combination. Warning: ${remainingAttempts} attempts remaining before system lockout.` 
        });
      }
      
      failed2faAttemptsTracker[user.u_id] = 0;
    }

    // --- NEW SESSION TOKEN GENERATION & DATABASE STORAGE ---
    const newSessionToken = crypto.randomBytes(16).toString('hex');

    await pool.query(
      `UPDATE public."User" SET session_token = $1 WHERE u_id = $2`, 
      [newSessionToken, user.u_id]
    );

    // Inject the newSessionToken into the JWT payload
    const token = jwt.encode({ 
      u_id: user.u_id, 
      username: user.username, 
      a_id: user.a_id,
      session_token: newSessionToken 
    }, JWT_SECRET);

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

// SESSION VERIFICATION MIDDLEWARE
const requireAuth = async (req, res, next) => {
  const authHeader = req.headers.authorization;
  
  if (!authHeader) {
    return res.status(401).json({ error: 'Unauthorized access. Please log in.' });
  }

  const token = authHeader.split(' ')[1]; // Expects format: "Bearer <token>"

  try {
    const decoded = jwt.decode(token, JWT_SECRET);
    
    // Check the database to see if the session token matches the current one
    const result = await pool.query('SELECT session_token FROM public."User" WHERE u_id = $1', [decoded.u_id]);
    
    if (result.rows.length === 0) {
      return res.status(401).json({ error: 'User account no longer exists.' });
    }

    const currentDbToken = result.rows[0].session_token;

    // THE KICK-OUT LOGIC: If the tokens don't match, they logged in somewhere else!
    if (currentDbToken !== decoded.session_token) {
      return res.status(401).json({ 
        error: 'Session expired. You logged in from another device.', 
        forceLogout: true 
      });
    }

    // If it matches, attach user info to req and proceed
    req.user = decoded;
    next();
  } catch (err) {
    return res.status(401).json({ error: 'Invalid or expired token.' });
  }
};

app.get('/api/accounts', requireAuth, async (req, res) => {
  try {
    const query = `
                  SELECT u.u_id, u.username, u.full_name, u.uni_email, u.faculty_id, u.two_fa_enabled, u.a_id, u.d_id, u.o_id, u.is_active,
                        a.account_type as role_name,
                        d.department_name,
                        off.office_name
                  FROM public."User" u
                  JOIN public.account a ON u.a_id = a.a_id
                  JOIN public.department d ON u.d_id = d.d_id
                  LEFT JOIN public.offices off ON u.o_id = off.o_id
                  ORDER BY u.u_id DESC;
                `;
    const result = await pool.query(query);
    res.json(result.rows);
  } catch (err) {
    console.error("Error fetching institutional accounts database ledger:", err);
    res.status(500).json({ error: 'Failed to extract institutional accounts mapping directory loop.' });
  }
});

app.put('/api/accounts/:userId', requireAuth, async (req, res) => {
  const { userId } = req.params;
  const { username, fullName, email, accountType, departmentId, officeId, isActive } = req.body;  
  try {
    const duplicateCheck = await pool.query(
      `SELECT * FROM public."User" WHERE username = $1 AND u_id != $2`,
      [username, parseInt(userId)]
    );

    if (duplicateCheck.rows.length > 0) {
      return res.status(400).json({ error: 'Rejection: This username identifier is already registered to another user account.' });
    }

    const assignedOfficeId = (parseInt(accountType) === 2 || parseInt(accountType) === 3) && officeId 
      ? parseInt(officeId) 
      : null;

    const assignedDepartmentId = departmentId ? parseInt(departmentId) : 1;

    const query = `
      UPDATE public."User"
      SET username = $1, full_name = $2, uni_email = $3, a_id = $4, d_id = $5, o_id = $6, is_active = $7
      WHERE u_id = $8
    `;
    
    await pool.query(query, [
      username, fullName, email, parseInt(accountType), assignedDepartmentId, assignedOfficeId, isActive, parseInt(userId)
    ]);

    res.json({ message: 'Personnel access profile parameters re-indexed and synchronized cleanly!' });
  } catch (err) {
    console.error("Account update failure:", err);
    res.status(500).json({ error: 'Failed execution update sequence constraint loop.' });
  }
});

app.get('/api/profile/:userId', requireAuth, async (req, res) => {
  try {
    const result = await pool.query(
      `SELECT u.u_id, u.full_name, u.uni_email, u.faculty_id, u.two_fa_enabled, u.two_fa_code, u.o_id,
              a.account_type, d.department_name, off.office_name
       FROM public."User" u
       JOIN public.account a ON u.a_id = a.a_id
       JOIN public.department d ON u.d_id = d.d_id
       LEFT JOIN public.offices off ON u.o_id = off.o_id
       WHERE u.u_id = $1`,
      [req.params.userId]
    );
    if (result.rows.length === 0) return res.status(404).json({ error: 'User profiles entry missing' });
    res.json(result.rows[0]);
  } catch (err) {
    console.error("Profile lookup error:", err);
    res.status(500).json({ error: 'Failed to look up user metadata frame' });
  }
});

app.put('/api/profile/:userId', requireAuth, async (req, res) => {
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

app.put('/api/profile/:userId/password', requireAuth, async (req, res) => {
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

app.get('/api/process-types', requireAuth, async (req, res) => {
  try {
    const query = `
      SELECT p.p_id, p.process_name, p.is_active, r.r_id,
             r.stop_1, r.stop_2, r.stop_3, r.stop_4, r.stop_5, r.stop_6, r.stop_7,
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
      LEFT JOIN public.offices o7 ON r.stop_7 = o7.o_id
      ORDER BY p.p_id DESC`;
    const result = await pool.query(query);
    res.json(result.rows);
  } catch (err) { 
    res.status(500).json({ error: 'Failed to pull templates' }); 
  }
});

app.get('/api/documents/:userId', requireAuth, async (req, res) => {
  try {
    const query = `
      SELECT DISTINCT ON (idoc.ini_id)
             idoc.ini_id, 
             idoc.title, 
             idoc.edc, 
             idoc.qr_code, 
             idoc.created_at,
             pt.process_name,
             curr_o.office_name as current_office, 
             next_o.office_name as next_office, 
             st.current_status as status,
             (
               SELECT action_type 
               FROM public.office_action_history 
               WHERE ini_id = idoc.ini_id AND action_type LIKE 'Sent Back for Revision:%'
               ORDER BY history_id DESC 
               LIMIT 1
             ) as last_action,
             (
               SELECT json_agg(json_build_object(
                 'office_name', off2.office_name,
                 'time_in', p2.time_in,
                 'time_out', p2.time_out
               ))
               FROM public.processed_document p2
               JOIN public.offices off2 ON p2.current_office_id = off2.o_id
               WHERE p2.ini_id = idoc.ini_id
             ) as history_logs
      FROM public.initial_document idoc
      JOIN public.process_type pt ON idoc.p_id = pt.p_id
      LEFT JOIN public.processed_document pdoc ON idoc.ini_id = pdoc.ini_id
      LEFT JOIN public.offices curr_o ON pdoc.current_office_id = curr_o.o_id
      LEFT JOIN public.offices next_o ON pdoc.next_office_id = next_o.o_id
      LEFT JOIN public.status st ON pdoc.s_id = st.s_id
      WHERE idoc.u_id = $1 
      ORDER BY idoc.ini_id DESC, pdoc.pd_id DESC;
    `;
    const result = await pool.query(query, [req.params.userId]);
    res.json(result.rows);
  } catch (err) { 
    console.error(err);
    res.status(500).json({ error: 'Failed mapping logs' }); 
  }
});

app.post('/api/documents', requireAuth, async (req, res) => {
  const { userId, title, processTypeId, edc } = req.body;
  try {
    const uniqueQrPayload = `TRK-${Date.now()}-${Math.floor(Math.random() * 1000)}`;
    const docResult = await pool.query(
      `INSERT INTO public.initial_document (p_id, u_id, title, edc, qr_code, created_at) 
       VALUES ($1, $2, $3, $4, $5, TIMEZONE('Asia/Manila', NOW())) RETURNING *`,
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

app.post('/api/accounts', requireAuth, async (req, res) => {
  const { username, password, accountType, fullName, email, departmentId, officeId } = req.body;
  try {
    const userCheck = await pool.query(
      'SELECT * FROM public."User" WHERE username = $1 OR uni_email = $2', 
      [username, email]
    );
    if (userCheck.rows.length > 0) {
      return res.status(400).json({ error: 'Rejection: Username or email already registered.' });
    }

    const hashedPassword = await bcrypt.hash(password, 10);
    
    const assignedOfficeId = (parseInt(accountType) === 2 || parseInt(accountType) === 3) && officeId 
      ? parseInt(officeId) 
      : null;

    const assignedDepartmentId = departmentId ? parseInt(departmentId) : 1;

    await pool.query(
      `INSERT INTO public."User" (a_id, d_id, username, password, full_name, uni_email, o_id) 
       VALUES ($1, $2, $3, $4, $5, $6, $7)`, 
      [parseInt(accountType), assignedDepartmentId, username, hashedPassword, fullName, email, assignedOfficeId]
    );

    res.status(201).json({ message: 'Success: Account architecture generated and synchronized successfully!' });
  } catch (err) {
    console.error("Account registration script processing breakdown:", err);
    res.status(500).json({ error: 'Failed account generation sequence structural assignment loop.' });
  }
});

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

app.get('/api/resources/inventory', async (req, res) => {
  try {
    const result = await pool.query(
      `SELECT asd_id, asset_name, quantity FROM public.asset_details WHERE ast_id = 3`
    );
    res.json(result.rows);
  } catch (err) {
    res.status(500).json({ error: "Failed to grab inventory quantities" });
  }
});

app.post('/api/resources/book', async (req, res) => {
  const { 
    userId, bookingType, assetName, reservationDate, purpose, department,
    startTime, endTime, expectedAttendees,
    destination, passengerCount, serviceTypeId, pickUpTime, dropOffTime
  } = req.body;

  const client = await pool.connect();
  try {
    await client.query('BEGIN');

    const assetRes = await client.query('SELECT asd_id FROM public.asset_details WHERE asset_name = $1', [assetName]);
    if (assetRes.rows.length === 0) throw new Error("Target university asset resource not registered.");
    const asdId = assetRes.rows[0].asd_id;

    const bookingRes = await client.query(
      `INSERT INTO public.bookings (u_id, booking_type, department, reservation_date, purpose, status)
       VALUES ($1, $2, $3, $4, $5, 'Reserved') RETURNING booking_id`,
      [userId, bookingType, department, reservationDate, purpose]
    );
    const bookingId = bookingRes.rows[0].booking_id;

    if (bookingType === 'Room' || bookingType === 'Gymnasium') {
      await client.query(
        `INSERT INTO public.gm_requirements (asd_id, booking_id, start_time, end_time, expected_attendees)
         VALUES ($1, $2, $3, $4, $5)`,
        [asdId, bookingId, startTime, endTime, expectedAttendees || 0]
      );
    } else if (bookingType === 'Vehicle') {
      const finalizedPickUp = pickUpTime && pickUpTime.trim() !== "" ? pickUpTime : "00:00:00";
      const finalizedDropOff = dropOffTime && dropOffTime.trim() !== "" ? dropOffTime : "00:00:00";

      await client.query(
        `INSERT INTO public.vehicle_requirements (asd_id, sv_id, booking_id, destination, passenger_count, pick_up_time, drop_off_time)
         VALUES ($1, $2, $3, $4, $5, $6, $7)`,
        [asdId, parseInt(serviceTypeId) || 3, bookingId, destination, parseInt(passengerCount) || 1, finalizedPickUp, finalizedDropOff]
      );
    }

    await client.query('COMMIT');
    res.status(201).json({ message: "Reservation recorded successfully! Awaiting status validation." });
  } catch (err) {
    await client.query('ROLLBACK');
    res.status(500).json({ error: err.message || "Failed transactional database commitment sequence." });
  } finally {
    client.release();
  }
});

// FETCH INCOMING ACTIVE PENDING DOCUMENTS FOR PROCESSOR/SIGNEE DASHBOARD LISTS ONLY
app.get('/api/processor/documents/:officeId', requireAuth, async (req, res) => {
  const { officeId } = req.params;
  try {
    const query = `
      SELECT 
        idoc.ini_id, 
        idoc.title, 
        idoc.edc, 
        idoc.qr_code, 
        idoc.created_at, 
        pt.process_name,
        INITCAP(st.current_status) as status,
        curr_o.office_name as current_office, 
        next_o.office_name as next_office,
        pdoc.time_in,
        pdoc.time_out,
        pdoc.is_adhoc,
        pdoc.adhoc_return_office_id,
        r.stop_1 as route_start_id,
        creator.full_name AS requestor_name
      FROM public.processed_document pdoc
      JOIN public.initial_document idoc ON pdoc.ini_id = idoc.ini_id
      JOIN public.process_type pt ON idoc.p_id = pt.p_id
      JOIN public.route r ON pt.r_id = r.r_id
      JOIN public."User" creator ON idoc.u_id = creator.u_id
      LEFT JOIN public.offices curr_o ON pdoc.current_office_id = curr_o.o_id
      LEFT JOIN public.offices next_o ON pdoc.next_office_id = next_o.o_id
      LEFT JOIN public.status st ON pdoc.s_id = st.s_id
      WHERE pdoc.current_office_id = $1 AND pdoc.time_out IS NULL
      ORDER BY pdoc.pd_id DESC;
    `;
    const result = await pool.query(query, [parseInt(officeId)]);
    res.json(result.rows);
  } catch (err) {
    console.error("Processor active document lookup failure:", err);
    res.status(500).json({ error: "Failed to load active office document stream parameters." });
  }
});

// FETCH EXTENDED PIPELINE TRACKS CONTAINING HISTORICAL ENGAGEMENTS UNIQUE TO THIS STATION
app.get('/api/processor/documents/pipeline/:officeId', requireAuth, async (req, res) => {
  const { officeId } = req.params;
  try {
    const query = `
      SELECT DISTINCT ON (idoc.ini_id)
        idoc.ini_id, 
        idoc.title, 
        idoc.edc, 
        idoc.qr_code, 
        idoc.created_at, 
        pt.process_name,
        INITCAP(st.current_status) as status,
        orig_o.office_name as originating_office,
        curr_o.office_name as current_office, 
        next_o.office_name as next_office,
        pdoc_office.time_in,
        pdoc_office.time_out,
        pdoc_active.current_office_id,
        pdoc_active.is_adhoc AS current_step_is_adhoc,
        creator.full_name AS requestor_name
      FROM public.initial_document idoc
      JOIN public.process_type pt ON idoc.p_id = pt.p_id
      JOIN public.route r ON pt.r_id = r.r_id
      JOIN public."User" creator ON idoc.u_id = creator.u_id
      JOIN public.processed_document pdoc_office ON idoc.ini_id = pdoc_office.ini_id
      LEFT JOIN public.processed_document pdoc_active ON idoc.ini_id = pdoc_active.ini_id AND pdoc_active.time_out IS NULL
      LEFT JOIN public.offices orig_o ON r.stop_1 = orig_o.o_id
      LEFT JOIN public.offices curr_o ON COALESCE(pdoc_active.current_office_id, pdoc_office.current_office_id) = curr_o.o_id
      LEFT JOIN public.offices next_o ON pdoc_active.next_office_id = next_o.o_id
      LEFT JOIN public.status st ON COALESCE(pdoc_active.s_id, pdoc_office.s_id) = st.s_id
      WHERE pdoc_office.current_office_id = $1
      ORDER BY idoc.ini_id DESC, pdoc_office.pd_id DESC;
    `;
    const result = await pool.query(query, [parseInt(officeId)]);
    res.json(result.rows);
  } catch (err) {
    console.error("Pipeline analytics ledger parsing fault:", err);
    res.status(500).json({ error: "Failed compiling analytical structural route loops." });
  }
});

// ==========================================
// SMART SCANNER ENDPOINTS WITH MANILA TIMEZONE
// ==========================================
app.post('/api/documents/scan-in', requireAuth, async (req, res) => {
  const { qrCode, processorUserId } = req.body;
  try {
    const procRes = await pool.query('SELECT o_id FROM public."User" WHERE u_id = $1', [processorUserId]);
    const processorOfficeId = procRes.rows[0]?.o_id;

    if (!processorOfficeId) {
      return res.status(400).json({ error: "Your account is not assigned to a physical campus office workspace." });
    }

    const docRes = await pool.query(`
      SELECT pd.pd_id, pd.ini_id, pd.current_office_id, pd.time_in, idoc.title, off.office_name as expected_office_name
      FROM public.processed_document pd
      JOIN public.initial_document idoc ON pd.ini_id = idoc.ini_id
      JOIN public.offices off ON pd.current_office_id = off.o_id
      WHERE idoc.qr_code = $1 AND pd.time_out IS NULL
      ORDER BY pd.pd_id DESC LIMIT 1
    `, [qrCode]);

    if (docRes.rows.length === 0) {
      return res.status(422).json({ error: "Rejection: Document token is either invalid or already fully completed." });
    }

    const activeLog = docRes.rows[0];

    if (activeLog.current_office_id !== processorOfficeId) {
      return res.status(400).json({ 
        error: `Notice of Rejection: This document belongs to the ${activeLog.expected_office_name}. It cannot be scanned here.` 
      });
    }

    if (activeLog.time_in !== null) {
      return res.status(400).json({ 
        error: `Notice: "${activeLog.title}" has already been clocked into your office.` 
      });
    }

    await pool.query(`
      UPDATE public.processed_document 
      SET time_in = TIMEZONE('Asia/Manila', NOW()) 
      WHERE pd_id = $1
    `, [activeLog.pd_id]);

    await pool.query(`
      INSERT INTO public.office_action_history (ini_id, u_id, o_id, action_type, action_timestamp)
      VALUES ($1, $2, $3, 'Scanned In', TIMEZONE('Asia/Manila', NOW()))
    `, [activeLog.ini_id, processorUserId, processorOfficeId]);

    res.json({ message: `Successfully registered Time-In for document: "${activeLog.title}"` });

  } catch (err) {
    console.error("Scan-In Error:", err);
    res.status(500).json({ error: "Internal Server Error during logging computation." });
  }
});

app.post('/api/documents/scan-out', requireAuth, async (req, res) => {
  const { qrCode, processorUserId } = req.body;
  try {
    const procRes = await pool.query('SELECT o_id FROM public."User" WHERE u_id = $1', [processorUserId]);
    const processorOfficeId = procRes.rows[0]?.o_id;

    // 1. Fetch current document state along with its numeric status ID (s_id)
    // FIX: Added pd.current_office_id to the SELECT statement
    const checkStatusRes = await pool.query(`
      SELECT pd.pd_id, pd.time_in, pd.s_id, st.current_status, pd.current_office_id, pd.next_office_id, pd.ini_id, idoc.title
      FROM public.processed_document pd
      JOIN public.initial_document idoc ON pd.ini_id = idoc.ini_id
      JOIN public.status st ON pd.s_id = st.s_id
      WHERE idoc.qr_code = $1 AND pd.time_out IS NULL
      ORDER BY pd.pd_id DESC LIMIT 1
    `, [qrCode]);

    if (checkStatusRes.rows.length === 0) {
      return res.status(444).json({ error: "Document not found or already checked out." });
    }

    const currentActiveStep = checkStatusRes.rows[0];
    const currentStatusClean = currentActiveStep.current_status.toLowerCase();

    if (currentActiveStep.time_in === null) {
      return res.status(400).json({
        error: `Rejection: Cannot complete Time-Out. "${currentActiveStep.title}" must be scanned for Time-In first upon arrival.`
      });
    }

    // 2. Prevent scanning out if it's still generic pending or verification state
    if (currentStatusClean === 'pending' || currentStatusClean === 'in verification') {
      return res.status(400).json({ 
        error: "Rejection: This document cannot be signed out yet. It requires approval/signature or explicit action from the office Signee." 
      });
    }

    // ==========================================================
    // CRITICAL PATCH: HANDLE SENT BACK / ACTION REQUIRED WORKFLOW
    // ==========================================================
    if (currentActiveStep.s_id === 4 || currentStatusClean === 'action required') {
      // Clock out of current office but preserve s_id = 4 so it remains frozen as Action Required
      await pool.query(`
        UPDATE public.processed_document 
        SET time_out = TIMEZONE('Asia/Manila', NOW())
        WHERE pd_id = $1
      `, [currentActiveStep.pd_id]);

      if (processorOfficeId) {
        await pool.query(`
          INSERT INTO public.office_action_history (ini_id, u_id, o_id, action_type, action_timestamp)
          VALUES ($1, $2, $3, 'Scanned Out (Halted - Revision Required)', TIMEZONE('Asia/Manila', NOW()))
        `, [currentActiveStep.ini_id, processorUserId, processorOfficeId]);
      }

      return res.json({ 
        message: "Document safely checked out and frozen. Workflow halted pending Originator revisions." 
      });
    }
    // ==========================================================

    // 3. Normal route processing continues below for non-halted documents
    const adhocCheckRes = await pool.query(`
      SELECT is_adhoc, adhoc_return_office_id, is_returned_from_adhoc, current_office_id
      FROM public.processed_document
      WHERE pd_id = $1
    `, [currentActiveStep.pd_id]);

    const adhocData = adhocCheckRes.rows[0];

    const routeRes = await pool.query(`
      SELECT r.stop_1, r.stop_2, r.stop_3, r.stop_4, r.stop_5, r.stop_6, r.stop_7
      FROM public.initial_document idoc
      JOIN public.process_type pt ON idoc.p_id = pt.p_id
      JOIN public.route r ON pt.r_id = r.r_id
      WHERE idoc.ini_id = $1
    `, [currentActiveStep.ini_id]);

    const r = routeRes.rows[0];

    // ==========================================================
    // 1. AD-HOC RETURN TRIP LOGIC
    // ==========================================================
    if (adhocData && adhocData.is_adhoc) {
      // Clock out of Transferred Office (Office B)
      await pool.query(`
        UPDATE public.processed_document 
        SET time_out = TIMEZONE('Asia/Manila', NOW()) 
        WHERE pd_id = $1
      `, [currentActiveStep.pd_id]);

      // UNFREEZE Original Office (Office A) back to pending (s_id = 1)
      await pool.query(`
        UPDATE public.processed_document 
        SET s_id = 1
        WHERE ini_id = $1 AND current_office_id = $2 AND time_out IS NULL
      `, [currentActiveStep.ini_id, adhocData.adhoc_return_office_id]);
      
    } else {
      // ==========================================================
      // 2. NORMAL 7-STOP ROUTING LOGIC
      // ==========================================================
      const sequence = [r.stop_1, r.stop_2, r.stop_3, r.stop_4, r.stop_5, r.stop_6, r.stop_7].filter(Boolean);
      
      // Look for the office we are CURRENTLY scanning out of
      const currentIndex = sequence.indexOf(currentActiveStep.current_office_id);
      
      let nextStopToReceive = null;
      let followingStop = null;

      if (currentIndex !== -1 && currentIndex + 1 < sequence.length) {
        nextStopToReceive = sequence[currentIndex + 1]; // The immediate next stop
        if (currentIndex + 2 < sequence.length) {
          followingStop = sequence[currentIndex + 2]; // The stop after next (for UI display)
        }
      }

      if (!nextStopToReceive) {
        // If there is no next stop, the document has finished its ENTIRE route!
        await pool.query(`
          UPDATE public.processed_document 
          SET time_out = TIMEZONE('Asia/Manila', NOW()), s_id = 5
          WHERE pd_id = $1
        `, [currentActiveStep.pd_id]);
      } else {
        // Clock out of current office
        await pool.query(`
          UPDATE public.processed_document 
          SET time_out = TIMEZONE('Asia/Manila', NOW()) 
          WHERE pd_id = $1
        `, [currentActiveStep.pd_id]);

        // Push to the next office in the sequence
        await pool.query(`
          INSERT INTO public.processed_document (ini_id, s_id, current_office_id, next_office_id, time_in)
          VALUES ($1, 1, $2, $3, NULL)
        `, [currentActiveStep.ini_id, nextStopToReceive, followingStop]);
      }
    }

    if (processorOfficeId) {
      await pool.query(`
        INSERT INTO public.office_action_history (ini_id, u_id, o_id, action_type, action_timestamp)
        VALUES ($1, $2, $3, 'Scanned Out', TIMEZONE('Asia/Manila', NOW()))
      `, [currentActiveStep.ini_id, processorUserId, processorOfficeId]);
    }

    res.json({ message: "Document safely checked out and pushed to next workflow queue block." });

  } catch (err) {
    console.error("Scan-Out Error:", err);
    res.status(500).json({ error: "Internal Server Error checking out document." });
  }
});

// ==========================================
// AD-HOC VERIFICATION DETOUR ENDPOINT
// ==========================================
app.post('/api/processor/documents/ad-hoc', requireAuth, async (req, res) => {
  const { iniId, targetOfficeId, currentOfficeId, executorUserId } = req.body;
  const client = await pool.connect();

  try {
    await client.query('BEGIN');

    const activeRes = await client.query(`
      SELECT pd_id, time_in 
      FROM public.processed_document 
      WHERE ini_id = $1 AND current_office_id = $2 AND time_out IS NULL
    `, [iniId, currentOfficeId]);

    if (activeRes.rows.length === 0) throw new Error("Active document track not found in your office.");
    const activeStep = activeRes.rows[0];

    if (activeStep.time_in === null) throw new Error("Cannot route detour: Document must be Scanned-In to your office first.");

    // PATCH 1: Do NOT clock out Office A. Just change status to In Verification (s_id = 2).
    await client.query(`
      UPDATE public.processed_document 
      SET s_id = 2
      WHERE pd_id = $1
    `, [activeStep.pd_id]);

    // Insert Office B's new record
    await client.query(`
      INSERT INTO public.processed_document 
      (ini_id, s_id, current_office_id, next_office_id, is_adhoc, adhoc_return_office_id, time_in)
      VALUES ($1, 1, $2, NULL, true, $3, NULL)
    `, [iniId, targetOfficeId, currentOfficeId]);

    await client.query(`
      INSERT INTO public.office_action_history 
      (ini_id, u_id, o_id, action_type, action_timestamp)
      VALUES ($1, $2, $3, 'Ad-Hoc Detour Routed', TIMEZONE('Asia/Manila', NOW()))
    `, [iniId, executorUserId, currentOfficeId]);

    await client.query('COMMIT');
    res.json({ message: "Detour active. Document transferred to target office for verification." });

  } catch (err) {
    await client.query('ROLLBACK');
    res.status(500).json({ error: err.message || "Failed to process ad-hoc detour route." });
  } finally {
    client.release();
  }
});

// FETCH HISTORY DATA LEDGER FOR ALL PROCESSORS IN THE SPECIFIC OFFICE
app.get('/api/processor/history/:officeId', requireAuth, async (req, res) => {
  const { officeId } = req.params;
  try {
    const query = `
      SELECT 
        h.history_id,
        h.action_type,
        h.action_timestamp,
        u.full_name,
        idoc.title,
        idoc.qr_code,
        idoc.ini_id,
        idoc.edc,
        idoc.created_at, 
        pt.process_name,
        COALESCE(INITCAP(st.current_status), 'Active Path') as status,
        curr_o.office_name as current_office,
        next_o.office_name as next_office,
        pdoc.time_in,
        pdoc.time_out,
        pdoc.is_adhoc,
        creator.full_name AS requestor_name
      FROM public.office_action_history h
      JOIN public."User" u ON h.u_id = u.u_id
      JOIN public.initial_document idoc ON h.ini_id = idoc.ini_id
      JOIN public.process_type pt ON idoc.p_id = pt.p_id
      JOIN public."User" creator ON idoc.u_id = creator.u_id
      LEFT JOIN LATERAL (
        SELECT pd.time_in, pd.time_out, pd.is_adhoc, pd.s_id, pd.current_office_id, pd.next_office_id
        FROM public.processed_document pd
        WHERE pd.ini_id = h.ini_id 
          AND pd.current_office_id = h.o_id
        ORDER BY pd.pd_id DESC
        LIMIT 1
      ) pdoc ON TRUE
      LEFT JOIN public.offices curr_o ON h.o_id = curr_o.o_id
      LEFT JOIN public.offices next_o ON pdoc.next_office_id = next_o.o_id
      LEFT JOIN public.status st ON pdoc.s_id = st.s_id
      WHERE h.o_id = $1
      ORDER BY h.action_timestamp DESC;
    `;
    const result = await pool.query(query, [parseInt(officeId)]);
    res.json(result.rows);
  } catch (err) {
    console.error("Audit trail lookup mapping error:", err);
    res.status(500).json({ error: "Failed to map historical action segments." });
  }
});

app.get('/api/offices', async (req, res) => {
  try {
    const result = await pool.query(
      'SELECT o_id AS id, office_name AS name FROM public.offices ORDER BY office_name ASC'
    );
    res.json(result.rows);
  } catch (err) {
    console.error("Error fetching offices directory:", err);
    res.status(500).json({ error: "Failed to pull campus offices directory." });
  }
});

app.post('/api/signee/sign', requireAuth, async (req, res) => {
  const { iniId, currentOfficeId, signeeUserId } = req.body;
  try {
    const updateResult = await pool.query(`
      UPDATE public.processed_document
      SET s_id = 3 
      WHERE ini_id = $1 AND current_office_id = $2 AND time_out IS NULL
      RETURNING pd_id
    `, [parseInt(iniId), parseInt(currentOfficeId)]);

    if (updateResult.rows.length === 0) {
      return res.status(404).json({ error: "No active processing track found for signature in this branch." });
    }

    await pool.query(`
      INSERT INTO public.office_action_history (ini_id, u_id, o_id, action_type, action_timestamp)
      VALUES ($1, $2, $3, 'Approved & Signed', TIMEZONE('Asia/Manila', NOW()))
    `, [parseInt(iniId), parseInt(signeeUserId), parseInt(currentOfficeId)]);

    res.json({ message: "Document authorization seal applied successfully!" });
  } catch (err) {
    console.error("Signature processing error:", err);
    res.status(500).json({ error: "Failed sequence allocation structural logic loop." });
  }
});

app.post('/api/signee/return', requireAuth, async (req, res) => {
  const { iniId, currentOfficeId, signeeUserId, reason } = req.body;
  try {
    // Set status to 'Action Required' (s_id = 4) and decouple next_office_id to freeze the route
    const updateResult = await pool.query(`
      UPDATE public.processed_document
      SET s_id = 4, next_office_id = NULL
      WHERE ini_id = $1 AND current_office_id = $2 AND time_out IS NULL
      RETURNING pd_id
    `, [parseInt(iniId), parseInt(currentOfficeId)]);

    if (updateResult.rows.length === 0) {
      return res.status(404).json({ error: "Document active link context is missing." });
    }

    const actionMessage = `Sent Back for Revision: ${reason}`;
    await pool.query(`
      INSERT INTO public.office_action_history (ini_id, u_id, o_id, action_type, action_timestamp)
      VALUES ($1, $2, $3, $4, TIMEZONE('Asia/Manila', NOW()))
    `, [parseInt(iniId), parseInt(signeeUserId), parseInt(currentOfficeId), actionMessage]);

    res.json({ message: "Document flagged for corrections and route path frozen cleanly." });
  } catch (err) {
    console.error("Return routing tracking error:", err);
    res.status(500).json({ error: "Internal processing structural breakdown." });
  }
});

app.post('/api/auth/forgot-password/identify', async (req, res) => {
  const { username } = req.body;
  if (!username) return res.status(400).json({ error: 'Username is required.' });

  try {
    const result = await pool.query(
      'SELECT uni_email, full_name FROM public."User" WHERE username = $1',
      [username.trim()]
    );

    if (result.rows.length === 0) {
      return res.status(404).json({ error: 'Username not found in the university database.' });
    }

    const { uni_email, full_name } = result.rows[0];

    const maskEmail = (email) => {
      const [localPart, domain] = email.split('@');
      if (localPart.length <= 2) return `${localPart[0]}***@${domain}`;
      return `${localPart[0]}${'*'.repeat(localPart.length - 2)}${localPart[localPart.length - 1]}@${domain}`;
    };

    res.json({ 
      maskedEmail: maskEmail(uni_email),
      username: username.trim()
    });
  } catch (err) {
    console.error("Identify user error:", err);
    res.status(500).json({ error: 'Database tracking configuration lookup error.' });
  }
});

app.post('/api/auth/forgot-password/verify-email', async (req, res) => {
  const { username, fullEmail } = req.body;
  if (!username || !fullEmail) return res.status(400).json({ error: 'All fields are required.' });

  try {
    const result = await pool.query(
      'SELECT uni_email, full_name FROM public."User" WHERE username = $1',
      [username.trim()]
    );

    if (result.rows.length === 0) return res.status(404).json({ error: 'User link context missing.' });

    const user = result.rows[0];

    if (user.uni_email.toLowerCase().trim() !== fullEmail.toLowerCase().trim()) {
      return res.status(400).json({ error: 'The email address provided does not match our records.' });
    }

    const verificationCode = Math.floor(100000 + Math.random() * 900000).toString();
    const expiryTime = new Date(Date.now() + 10 * 60 * 1000);

    await pool.query(
      `UPDATE public."User" 
       SET reset_token = $1, reset_token_expires = $2 
       WHERE username = $3`,
      [verificationCode, expiryTime, username.trim()]
    );

    const emailDelivery = await sendResetCodeEmail(user.uni_email, user.full_name, verificationCode);

    if (!emailDelivery.success) {
      return res.status(500).json({ error: 'Failed to send verification code email. Try again later.' });
    }

    res.json({ message: 'Verification code dispatched successfully!' });
  } catch (err) {
    console.error("Email verification dispatch loop failure:", err);
    res.status(500).json({ error: 'Internal pipeline verification structural error.' });
  }
});

app.post('/api/auth/forgot-password/reset', async (req, res) => {
  const { username, code, newPassword } = req.body;
  if (!username || !code || !newPassword) return res.status(400).json({ error: 'All fields are required.' });

  try {
    const result = await pool.query(
      'SELECT reset_token, reset_token_expires FROM public."User" WHERE username = $1',
      [username.trim()]
    );

    if (result.rows.length === 0) return res.status(404).json({ error: 'User mapping context context missing.' });

    const user = result.rows[0];

    if (!user.reset_token || user.reset_token !== code.trim()) {
      return res.status(400).json({ error: 'Invalid verification token mismatch.' });
    }

    const now = new Date();
    if (new Date(user.reset_token_expires) < now) {
      return res.status(400).json({ error: 'Verification code has expired. Please request a new one.' });
    }

    const hashedNewPassword = await bcrypt.hash(newPassword, 10);

    await pool.query(
      `UPDATE public."User" 
       SET password = $1, reset_token = NULL, reset_token_expires = NULL 
       WHERE username = $2`,
      [hashedNewPassword, username.trim()]
    );

    res.json({ message: 'Your password has been successfully reset! You can now log in.' });
  } catch (err) {
    console.error("Finalization password allocation loop breakdown:", err);
    res.status(500).json({ error: 'Structural commitment change sequence transaction breakdown.' });
  }
});

app.post('/api/auth/forgot-pin/reset', async (req, res) => {
  const { username } = req.body;
  try {
    const result = await pool.query(
      'SELECT u_id, uni_email, full_name FROM public."User" WHERE username = $1',
      [username.trim()]
    );
    if (result.rows.length === 0) return res.status(404).json({ error: 'Account username reference entry missing.' });

    const user = result.rows[0];
    const newRandomPin = Math.floor(100000 + Math.random() * 900000).toString();

    await pool.query('UPDATE public."User" SET two_fa_code = $1 WHERE u_id = $2', [newRandomPin, user.u_id]);
    failed2faAttemptsTracker[user.u_id] = 0; 

    await sendResetCodeEmail(user.uni_email, user.full_name, `YOUR SECURITY DASHBOARD TWO-FACTOR AUTHENTICATION PIN HAS BEEN RESET TO: ${newRandomPin}`);

    res.json({ message: 'A fresh verification PIN has been dispatched to your institutional inbox successfully!' });
  } catch (err) {
    res.status(500).json({ error: 'Failed autonomous self-service recovery tracking code loop.' });
  }
});

app.post('/api/process-types', async (req, res) => {
  const { processName, stops } = req.body;

  if (!processName || !stops || !Array.isArray(stops) || stops.length < 2) {
    return res.status(400).json({ error: 'Rejection: Routing workflows require a valid process name and a minimum sequence of 2 office stops.' });
  }

  if (stops.length > 7) {
    return res.status(400).json({ error: 'Rejection: System architecture restricts document tracking pipelines to a maximum configuration ceiling of 7 stops.' });
  }

  const client = await pool.connect();
  try {
    const nameCheck = await client.query('SELECT * FROM public.process_type WHERE LOWER(process_name) = $1', [processName.trim().toLowerCase()]);
    if (nameCheck.rows.length > 0) {
      return res.status(400).json({ error: 'Rejection: A tracking template matching this process designation already exists.' });
    }

    await client.query('BEGIN');

    const parameterizedStops = [...stops];
    while (parameterizedStops.length < 7) {
      parameterizedStops.push(null);
    }

    const insertRouteQuery = `
      INSERT INTO public.route (stop_1, stop_2, stop_3, stop_4, stop_5, stop_6, stop_7)
      VALUES ($1, $2, $3, $4, $5, $6, $7)
      RETURNING r_id
    `;
    const routeResult = await client.query(insertRouteQuery, parameterizedStops);
    const generatedRouteId = routeResult.rows[0].r_id;

    const insertProcessQuery = `
      INSERT INTO public.process_type (process_name, r_id)
      VALUES ($1, $2)
      RETURNING p_id
    `;
    await client.query(insertProcessQuery, [processName.trim(), generatedRouteId]);

    await client.query('COMMIT');
    res.status(201).json({ message: 'Success: Workflow template compiled and active across routing tables!' });
  } catch (err) {
    await client.query('ROLLBACK');
    console.error("Workflow creation processing exception:", err);
    res.status(500).json({ error: 'Failed execution transaction sequence process template assignment loops.' });
  } finally {
    client.release();
  }
});

app.put('/api/process-types/:processId', async (req, res) => {
  const { processId } = req.params;
  const { processName, stops, routeId, isActive } = req.body;

  if (!processName || !stops || !Array.isArray(stops) || stops.length < 2) {
    return res.status(400).json({ error: 'Rejection: Routing sequences require a title and a minimum of 2 office locations.' });
  }

  const client = await pool.connect();
  try {
    await client.query('BEGIN');

    await client.query(
      `UPDATE public.process_type 
       SET process_name = $1, is_active = $2 
       WHERE p_id = $3`,
      [processName.trim(), isActive, parseInt(processId)]
    );

    const parameterizedStops = [...stops];
    while (parameterizedStops.length < 7) {
      parameterizedStops.push(null);
    }

    const updateRouteQuery = `
      UPDATE public.route 
      SET stop_1 = $1, stop_2 = $2, stop_3 = $3, stop_4 = $4, stop_5 = $5, stop_6 = $6, stop_7 = $7
      WHERE r_id = $8
    `;
    await client.query(updateRouteQuery, [...parameterizedStops, parseInt(routeId)]);

    await client.query('COMMIT');
    res.json({ message: 'Success: Workflow template structural overrides committed cleanly!' });
  } catch (err) {
    await client.query('ROLLBACK');
    console.error("Workflow update error:", err);
    res.status(500).json({ error: 'Failed transaction updates sequence routing allocation loops.' });
  } finally {
    client.release();
  }
});

app.post('/api/departments', async (req, res) => {
  const { departmentName } = req.body;
  if (!departmentName || departmentName.trim() === "") {
    return res.status(400).json({ error: 'Rejection: Department names cannot be instantiated as empty text strings.' });
  }

  try {
    const checkDup = await pool.query('SELECT * FROM public.department WHERE LOWER(department_name) = $1', [departmentName.trim().toLowerCase()]);
    if (checkDup.rows.length > 0) {
      return res.status(400).json({ error: 'Rejection: This institutional department context is already indexed.' });
    }

    await pool.query('INSERT INTO public.department (department_name) VALUES ($1)', [departmentName.trim()]);
    res.status(201).json({ message: 'Success: Global department structure synchronized successfully!' });
  } catch (err) {
    console.error("Department registration exception:", err);
    res.status(500).json({ error: 'Failed execution query write department sequence context.' });
  }
});

app.post('/api/offices', async (req, res) => {
  const { officeName } = req.body;
  if (!officeName || officeName.trim() === "") {
    return res.status(400).json({ error: 'Rejection: Office destination tags cannot be instantiated as empty text strings.' });
  }

  try {
    const checkDup = await pool.query('SELECT * FROM public.offices WHERE LOWER(office_name) = $1', [officeName.trim().toLowerCase()]);
    if (checkDup.rows.length > 0) {
      return res.status(400).json({ error: 'Rejection: A structural branch mapping this destination name is already registered.' });
    }

    await pool.query('INSERT INTO public.offices (office_name) VALUES ($1)', [officeName.trim()]);
    res.status(201).json({ message: 'Success: Physical campus office station indexed into global catalogs!' });
  } catch (err) {
    console.error("Office drop node registration exception:", err);
    res.status(500).json({ error: 'Failed execution query write offices sequence context.' });
  }
});

app.get('/api/admin/infrastructure-summary', async (req, res) => {
  try {
    const deptRes = await pool.query('SELECT d_id AS id, department_name AS name FROM public.department ORDER BY department_name ASC');
    const roleStatsRes = await pool.query(`
      SELECT a.account_type, COUNT(u.u_id)::int as total_staff 
      FROM public.account a 
      LEFT JOIN public."User" u ON a.a_id = u.a_id 
      GROUP BY a.account_type, a.a_id 
      ORDER BY a.a_id ASC
    `);
    const officeCapacityRes = await pool.query(`
      SELECT off.office_name, COUNT(u.u_id)::int as staff_count 
      FROM public.offices off 
      LEFT JOIN public."User" u ON off.o_id = u.o_id 
      GROUP BY off.office_name 
      ORDER BY office_name ASC
    `);

    res.json({
      departments: deptRes.rows,
      roleStatistics: roleStatsRes.rows,
      officeCapacity: officeCapacityRes.rows
    });
  } catch (err) {
    console.error("Summary analytical loading fault:", err);
    res.status(500).json({ error: 'Failed compilation aggregate system status metrics loops.' });
  }
});

app.get('/api/admin/dashboard-metrics', async (req, res) => {
  try {
    const activeTracksRes = await pool.query(
      'SELECT COUNT(DISTINCT ini_id)::int as total FROM public.processed_document WHERE time_out IS NULL'
    );

    const systemUsersRes = await pool.query(
      'SELECT COUNT(u_id)::int as total FROM public."User"'
    );

    const workflowsCountRes = await pool.query(
      'SELECT COUNT(p_id)::int as total FROM public.process_type'
    );

    const liveFeedQuery = `
      SELECT 
        h.history_id,
        h.action_type,
        h.action_timestamp,
        u.full_name as operator_name,
        off.office_name,
        idoc.title as document_title
      FROM public.office_action_history h
      JOIN public."User" u ON h.u_id = u.u_id
      JOIN public.initial_document idoc ON h.ini_id = idoc.ini_id
      LEFT JOIN public.offices off ON h.o_id = off.o_id
      ORDER BY h.action_timestamp DESC
      LIMIT 15;
    `;
    const liveFeedRes = await pool.query(liveFeedQuery);

    const bottlenecksQuery = `
      SELECT 
        idoc.title as document_title,
        off.office_name,
        pdoc.time_in,
        EXTRACT(EPOCH FROM (TIMEZONE('Asia/Manila', NOW()) - pdoc.time_in))/3600 as hours_stalled
      FROM public.processed_document pdoc
      JOIN public.initial_document idoc ON pdoc.ini_id = idoc.ini_id
      JOIN public.offices off ON pdoc.current_office_id = off.o_id
      WHERE pdoc.time_in IS NOT NULL 
        AND pdoc.time_out IS NULL
        AND pdoc.time_in < TIMEZONE('Asia/Manila', NOW()) - INTERVAL '48 hours'
      ORDER BY pdoc.time_in ASC;
    `;
    const bottlenecksRes = await pool.query(bottlenecksQuery);

    res.json({
      counters: {
        activeTracks: activeTracksRes.rows[0].total,
        systemUsers: systemUsersRes.rows[0].total,
        workflowBlueprints: workflowsCountRes.rows[0].total
      },
      liveAuditTrail: liveFeedRes.rows,
      stalledBottlenecks: bottlenecksRes.rows
    });

  } catch (err) {
    console.error("Dashboard operations metrics collection exception:", err);
    res.status(500).json({ error: 'Failed aggregate calculation sequences for dashboard indicators.' });
  }
});

app.get('/api/notifications/:userId/:roleId/:officeId', requireAuth, async (req, res) => {
  const userId = parseInt(req.params.userId);
  const roleId = parseInt(req.params.roleId);
  const officeId = parseInt(req.params.officeId) || 0;

  try {
    let alertRows = [];
    
    if (roleId === 1) {
      // 1. ORIGINATOR: Alerts every time any action occurs on their document
      const query = `
        SELECT 
          h.history_id as id,
          idoc.title,
          h.action_type as title_alert,
          ('Action performed at ' || off.office_name) as message,
          h.action_timestamp as time
        FROM public.office_action_history h
        JOIN public.initial_document idoc ON h.ini_id = idoc.ini_id
        LEFT JOIN public.offices off ON h.o_id = off.o_id
        WHERE idoc.u_id = $1
        ORDER BY h.action_timestamp DESC LIMIT 10;
      `;
      const result = await pool.query(query, [userId]);
      alertRows = result.rows.map(row => ({
        id: row.id,
        title: row.title_alert,
        message: `"${row.title}": ${row.message}`,
        time: row.time
      }));

    } else if (roleId === 2) {
      // 2. PROCESSOR: Alerts when an incoming document is created, showing title and requestor name
      const query = `
        SELECT 
          pd.pd_id as id,
          idoc.title,
          u.full_name as requestor,
          idoc.created_at as time
        FROM public.processed_document pd
        JOIN public.initial_document idoc ON pd.ini_id = idoc.ini_id
        JOIN public."User" u ON idoc.u_id = u.u_id
        WHERE pd.current_office_id = $1 AND pd.time_in IS NULL
        ORDER BY pd.pd_id DESC LIMIT 10;
      `;
      const result = await pool.query(query, [officeId]);
      alertRows = result.rows.map(row => ({
        id: row.id,
        title: "Incoming Document",
        message: `"${row.title}" submitted by ${row.requestor}`,
        time: row.time
      }));

    } else if (roleId === 3) {
      // 3. SIGNEE: Alerts when a processor signs a document in (Time-In matches, pending action)
      const query = `
        SELECT 
          pd.pd_id as id,
          idoc.title,
          u.full_name as requestor,
          pd.time_in as time
        FROM public.processed_document pd
        JOIN public.initial_document idoc ON pd.ini_id = idoc.ini_id
        JOIN public."User" u ON idoc.u_id = u.u_id
        WHERE pd.current_office_id = $1 AND pd.time_in IS NOT NULL AND pd.s_id = 1
        ORDER BY pd.pd_id DESC LIMIT 10;
      `;
      const result = await pool.query(query, [officeId]);
      alertRows = result.rows.map(row => ({
        id: row.id,
        title: "Pending Document",
        message: `"${row.title}" from ${row.requestor} is awaiting your signature.`,
        time: row.time
      }));
    }

    res.json(alertRows);
  } catch (err) {
    console.error("Notification pull error:", err);
    res.json([]);
  }
});

// FETCH GLOBAL INCOMING COUNT (ALL EXPECTED DOCUMENTS FOR THIS OFFICE)
app.get('/api/processor/documents/expected-count/:officeId', requireAuth, async (req, res) => {
  const { officeId } = req.params;
  try {
    const query = `
      SELECT COUNT(DISTINCT idoc.ini_id) as expected_count
      FROM public.initial_document idoc
      JOIN public.process_type pt ON idoc.p_id = pt.p_id
      JOIN public.route r ON pt.r_id = r.r_id
      LEFT JOIN public.processed_document pdoc_active ON idoc.ini_id = pdoc_active.ini_id AND pdoc_active.time_out IS NULL
      WHERE $1 IN (r.stop_1, r.stop_2, r.stop_3, r.stop_4, r.stop_5, r.stop_6, r.stop_7)
        AND COALESCE(pdoc_active.s_id, 1) != 4 
        AND COALESCE(pdoc_active.s_id, 1) != 5
        AND NOT EXISTS (
          SELECT 1 FROM public.processed_document pd_past 
          WHERE pd_past.ini_id = idoc.ini_id 
            AND pd_past.current_office_id = $1 
            AND pd_past.time_out IS NOT NULL
        )
    `;
    const result = await pool.query(query, [parseInt(officeId)]);
    res.json({ count: parseInt(result.rows[0].expected_count, 10) });
  } catch (err) {
    console.error("Expected incoming documents count error:", err);
    res.status(500).json({ error: "Failed to compile incoming documents KPI." });
  }
});

const PORT = 5000;
app.listen(PORT, () => console.log(`🚀 Core backend subsystem running on port ${PORT}`));