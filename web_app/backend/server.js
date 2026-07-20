const express = require('express');
const cors = require('cors');
const jwt = require('jwt-simple');
const bcrypt = require('bcrypt');
const pool = require('./db');
const { sendResetCodeEmail, sendTrackingAlertEmail } = require('./mailer');
const crypto = require('crypto');
const axios = require('axios');
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

// ==========================================
// REAL-TIME POSTGRESQL NOTIFICATION LISTENER
// ==========================================
const initDatabaseListener = async () => {
  try {
    const client = await pool.connect();
    await client.query('LISTEN document_status_email_channel');
    console.log('Successfully listening to database channel: document_status_email_channel');

    client.on('notification', async (msg) => {
      if (msg.channel === 'document_status_email_channel') {
        try {
          const payload = JSON.parse(msg.payload); // Contains { ini_id, s_id }
          const { ini_id, s_id } = payload;

          // STRICT FILTER: Only proceed if status is 4 (Action Required) or 5 (Completed)
          if (s_id !== 4 && s_id !== 5) {
            return; 
          }

          console.log(`🔔 Received strict DB trigger payload: Document ID ${ini_id}, Status ID ${s_id}`);

          const query = `
            SELECT 
              i.title, 
              u.uni_email, 
              u.full_name, 
              s.current_status
            FROM public.initial_document i
            JOIN public."User" u ON i.u_id = u.u_id
            JOIN public.processed_document pd ON i.ini_id = pd.ini_id
            JOIN public.status s ON pd.s_id = s.s_id
            WHERE i.ini_id = $1 AND pd.s_id = $2
            ORDER BY pd.pd_id DESC
            LIMIT 1;
          `;
          
          const result = await pool.query(query, [ini_id, s_id]);

          if (result.rows.length > 0) {
            const { title, uni_email, full_name, current_status } = result.rows[0];

            let bodyText = '';
            
            if (s_id === 4) { // Action Required / Halted
              bodyText = `Your document "${title}" requires your immediate attention. It has been marked as "Action Required" / Halted. Please check the administrative remarks frame to complete any necessary structural file revisions and re-submit.`;
            } else if (s_id === 5) { // Completed
              bodyText = `Great news! Your document "${title}" has finished its entire institutional verification sequence and is now officially finalized and marked as "Completed".`;
            }

            // Fire via your local nodemailer transporter utility
            await sendTrackingAlertEmail(uni_email, full_name, title, current_status, bodyText);
          } else {
            console.log(`⚠️ Database lookup returned 0 rows for Document ID ${ini_id} with Status ID ${s_id}. Verification skipped.`);
          }
        } catch (err) {
          console.error('Error processing database notification payload:', err);
        }
      }
    });

    client.on('error', (err) => {
      console.error('Database listener client crashed. Reconnecting...', err);
      client.release();
      setTimeout(initDatabaseListener, 5000);
    });

  } catch (error) {
    console.error('Failed to initialize database notification listener. Retrying in 5s...', error);
    setTimeout(initDatabaseListener, 5000);
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

    const assignedOfficeId = (parseInt(accountType) === 2 || parseInt(accountType) === 3 || parseInt(accountType) === 4) && officeId 
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
                'time_out', p2.time_out,
                'is_adhoc', p2.is_adhoc
              ) ORDER BY p2.pd_id ASC)
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
      ORDER BY idoc.ini_id DESC, (pdoc.time_out IS NULL) DESC, pdoc.pd_id DESC;
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
    // 1. Fetch the Originator's Department ID (d_id)
    const userRes = await pool.query('SELECT d_id FROM public."User" WHERE u_id = $1', [userId]);
    const userDeptId = userRes.rows[0]?.d_id;

    // 2. Map the Department ID to the specific College Office ID (o_id)
    const departmentToOfficeMap = {
        1: 11, // CICS (d_id 1) -> CICS Office (o_id 11)
        2: 12, // CABEIHM -> CABEIHM Office
        3: 13, // CAS -> CAS Office
        4: 14, // CIT -> CE / CIT Office
        5: 14, // CE -> CE / CIT Office
        6: 24  // CTE -> CTE Office
    };
    
    // Default to CICS if mapping fails
    const assignedOfficeId = departmentToOfficeMap[userDeptId] || 11; 

    const uniqueQrPayload = `TRK-${Date.now()}-${Math.floor(Math.random() * 1000)}`;
    const docResult = await pool.query(
      `INSERT INTO public.initial_document (p_id, u_id, title, edc, qr_code, created_at) 
       VALUES ($1, $2, $3, $4, $5, TIMEZONE('Asia/Manila', NOW())) RETURNING *`,
      [processTypeId, userId, title, edc , uniqueQrPayload] // 'edc' variable is used here
    );
    const newDoc = docResult.rows[0];
    
    const routeResult = await pool.query(`SELECT r.stop_1, r.stop_2 FROM public.process_type pt JOIN public.route r ON pt.r_id = r.r_id WHERE pt.p_id = $1`, [processTypeId]);
    const route = routeResult.rows[0];
    
    if (route) {
      // 3. The Dynamic Swap Logic
      let firstStop = route.stop_1;
      
      // If the template uses the 999 Placeholder, swap it with the Originator's mapped office
      if (firstStop === 999) {
          firstStop = assignedOfficeId;
      }

      await pool.query(
        `INSERT INTO public.processed_document (ini_id, s_id, current_office_id, next_office_id) 
         VALUES ($1, 1, $2, $3)`, 
        [newDoc.ini_id, firstStop, route.stop_2]
      );
    }
    res.status(201).json({ message: 'Document tracking active!', qrCode: uniqueQrPayload });
  } catch (err) { 
    console.error(err);
    res.status(500).json({ error: 'Failed' }); 
  }
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
    
    
    const assignedOfficeId = (parseInt(accountType) === 2 || parseInt(accountType) === 3 || parseInt(accountType) === 4) && officeId 
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
    const query = `
      SELECT 
        ad.asd_id, 
        ad.asset_name, 
        ad.quantity as capacity,
        (ad.quantity - COALESCE(
          (SELECT SUM(qty_borrowed) FROM public.equipment_ledgers el 
           WHERE el.asd_id = ad.asd_id AND el.status = 'Borrowed'), 0
        )) as current_stock
      FROM public.asset_details ad 
      WHERE ad.ast_id = 3
      ORDER BY ad.asd_id ASC
    `;
    const result = await pool.query(query);
    res.json(result.rows);
  } catch (err) {
    res.status(500).json({ error: "Failed to grab inventory quantities" });
  }
});

// 2. PROCESS LENDING FORM
app.post('/api/resources/inventory/lend', requireAuth, async (req, res) => {
  const { asd_id, requestorName, department, purpose, quantityNeeded, duration } = req.body;
  try {
    // Basic validation to prevent borrowing more than exists
    const stockCheck = await pool.query(`
      SELECT (quantity - COALESCE((SELECT SUM(qty_borrowed) FROM public.equipment_ledgers WHERE asd_id = $1 AND status = 'Borrowed'), 0)) as current_stock 
      FROM public.asset_details WHERE asd_id = $1
    `, [asd_id]);
    
    if (stockCheck.rows[0].current_stock < quantityNeeded) {
      return res.status(400).json({ error: "Not enough current stock available for this request." });
    }

    await pool.query(`
      INSERT INTO public.equipment_ledgers (asd_id, requestor_name, department, purpose, qty_borrowed, expected_return, status, processed_by)
      VALUES ($1, $2, $3, $4, $5, TIMEZONE('Asia/Manila', NOW()) + interval '1 hour' * $6, 'Borrowed', $7)
    `, [asd_id, requestorName, department, purpose, quantityNeeded, parseInt(duration) || 24, req.user.u_id]);
    
    res.json({ message: "Equipment successfully logged as borrowed." });
  } catch (err) {
    console.error(err);
    res.status(500).json({ error: "Failed to process lending transaction." });
  }
});

// 3. PROCESS RETURN FORM
app.post('/api/resources/inventory/return', requireAuth, async (req, res) => {
  const { asd_id, requestorName, quantityReturned, isDamaged, damageNotes } = req.body;
  try {
    const activeLog = await pool.query(`
      SELECT log_id FROM public.equipment_ledgers 
      WHERE asd_id = $1 AND LOWER(requestor_name) = LOWER($2) AND status = 'Borrowed'
      ORDER BY borrowed_at ASC LIMIT 1
    `, [asd_id, requestorName]);

    if (activeLog.rows.length === 0) {
      return res.status(404).json({ error: "No active borrowing record found for this requestor and item." });
    }

    // Determine values to inject based on the boolean flag
    const condition = isDamaged ? 'Damaged' : 'Good';
    const notes = isDamaged ? damageNotes : null;

    await pool.query(`
      UPDATE public.equipment_ledgers 
      SET status = 'Returned', returned_at = TIMEZONE('Asia/Manila', NOW()), processed_by = $1,
          condition_on_return = $3, damage_notes = $4
      WHERE log_id = $2
    `, [req.user.u_id, activeLog.rows[0].log_id, condition, notes]);

    res.json({ message: "Equipment return successfully logged. Stock replenished." });
  } catch (err) {
    console.error(err);
    res.status(500).json({ error: "Failed to process return transaction." });
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

    // =========================================================
    // OVERLAP PREVENTION LOGIC
    // =========================================================
    if (bookingType === 'Room' || bookingType === 'Gymnasium') {
      const overlapCheck = await client.query(`
        SELECT 1 FROM public.bookings b
        JOIN public.gm_requirements gm ON b.booking_id = gm.booking_id
        WHERE b.reservation_date = $1 AND gm.asd_id = $2 AND b.status IN ('Confirmed', 'Reserved')
        AND gm.start_time < $4 AND gm.end_time > $3
      `, [reservationDate, asdId, startTime, endTime]);
      
      if (overlapCheck.rows.length > 0) {
        throw new Error("This facility is already booked during this time frame.");
      }
    } else if (bookingType === 'Vehicle') {
      const finalizedPickUp = pickUpTime && pickUpTime.trim() !== "" ? pickUpTime : "00:00:00";
      const finalizedDropOff = dropOffTime && dropOffTime.trim() !== "" ? dropOffTime : "00:00:00";
      
      const overlapCheck = await client.query(`
        SELECT 1 FROM public.bookings b
        JOIN public.vehicle_requirements vr ON b.booking_id = vr.booking_id
        WHERE b.reservation_date = $1 AND vr.asd_id = $2 AND b.status IN ('Confirmed', 'Reserved')
        AND vr.pick_up_time < $4 AND vr.drop_off_time > $3
      `, [reservationDate, asdId, finalizedPickUp, finalizedDropOff]);

      if (overlapCheck.rows.length > 0) {
        throw new Error("This vehicle is already scheduled for transit during this time frame.");
      }
    }
    // =========================================================

    // Insert the booking
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

// FETCH ALL MASTER ASSETS
app.get('/api/resources/assets', async (req, res) => {
  try {
    const query = `
      SELECT ad.asd_id, ad.asset_name, ad.quantity, at.asset_type, at.ast_id,
      (
        SELECT CASE
          WHEN EXISTS (
            SELECT 1 FROM public.asset_blackouts ab 
            WHERE ab.asd_id = ad.asd_id AND TIMEZONE('Asia/Manila', NOW()) BETWEEN ab.start_time AND ab.end_time
          ) THEN 'Maintenance'
          WHEN EXISTS (
            SELECT 1 FROM public.bookings b
            JOIN public.gm_requirements gm ON b.booking_id = gm.booking_id
            WHERE gm.asd_id = ad.asd_id AND b.status = 'Confirmed'
            AND b.reservation_date = (TIMEZONE('Asia/Manila', NOW()))::date
            AND (TIMEZONE('Asia/Manila', NOW()))::time BETWEEN gm.start_time AND gm.end_time
          ) THEN 'Occupied'
          WHEN EXISTS (
            SELECT 1 FROM public.bookings b
            JOIN public.vehicle_requirements vr ON b.booking_id = vr.booking_id
            WHERE vr.asd_id = ad.asd_id AND b.status = 'Confirmed'
            AND b.reservation_date = (TIMEZONE('Asia/Manila', NOW()))::date
            AND (TIMEZONE('Asia/Manila', NOW()))::time BETWEEN vr.pick_up_time AND vr.drop_off_time
          ) THEN 'Occupied'
          ELSE 'Available'
        END
      ) as current_status
      FROM public.asset_details ad
      JOIN public.asset_type at ON ad.ast_id = at.ast_id
      ORDER BY ad.asd_id ASC
    `;
    const result = await pool.query(query);
    res.json(result.rows);
  } catch (err) {
    console.error("Error fetching master assets:", err);
    res.status(500).json({ error: "Failed to load institutional assets" });
  }
});

// 2. FETCH SPECIFIC ASSET SCHEDULE (For the Edit Modal)
app.get('/api/resources/assets/:id/schedule', async (req, res) => {
  const { id } = req.params;
  try {
    const query = `
      SELECT b.reservation_date, b.purpose, b.status, u.full_name as requestor,
             COALESCE(gm.start_time, vr.pick_up_time) as start_time,
             COALESCE(gm.end_time, vr.drop_off_time) as end_time
      FROM public.bookings b
      JOIN public."User" u ON b.u_id = u.u_id
      LEFT JOIN public.gm_requirements gm ON b.booking_id = gm.booking_id AND gm.asd_id = $1
      LEFT JOIN public.vehicle_requirements vr ON b.booking_id = vr.booking_id AND vr.asd_id = $1
      WHERE (gm.asd_id = $1 OR vr.asd_id = $1) 
      AND b.status = 'Confirmed'
      AND b.reservation_date >= (TIMEZONE('Asia/Manila', NOW()))::date
      ORDER BY b.reservation_date ASC, start_time ASC
    `;
    const result = await pool.query(query, [id]);
    res.json(result.rows);
  } catch (err) {
    res.status(500).json({ error: "Failed to fetch schedule." });
  }
});

// 3. EDIT ASSET
app.put('/api/resources/assets/:id', requireAuth, async (req, res) => {
  const { id } = req.params;
  const { assetName, quantity } = req.body;
  try {
    await pool.query(
      `UPDATE public.asset_details SET asset_name = $1, quantity = $2 WHERE asd_id = $3`,
      [assetName.trim(), parseInt(quantity), id]
    );
    res.json({ message: 'Asset updated successfully' });
  } catch (err) {
    res.status(500).json({ error: "Failed to update asset" });
  }
});

// 4. DELETE ASSET
app.delete('/api/resources/assets/:id', requireAuth, async (req, res) => {
  const { id } = req.params;
  try {
    await pool.query(`DELETE FROM public.asset_details WHERE asd_id = $1`, [id]);
    res.json({ message: 'Asset deleted successfully' });
  } catch (err) {
    res.status(500).json({ error: "Cannot delete asset. It may be tied to existing historical records." });
  }
});

// ADD NEW MASTER ASSET
app.post('/api/resources/assets', requireAuth, async (req, res) => {
  const { assetName, assetTypeId, quantity } = req.body;
  try {
    // Note: assetTypeId maps to ast_id (1: Room, 2: Gym, 3: Furniture/Equipment, 4: Vehicle)
    await pool.query(
      `INSERT INTO public.asset_details (ast_id, asset_name, quantity) VALUES ($1, $2, $3)`,
      [parseInt(assetTypeId), assetName.trim(), parseInt(quantity) || 1]
    );
    res.status(201).json({ message: 'Institutional Asset successfully registered!' });
  } catch (err) {
    console.error("Error adding asset:", err);
    res.status(500).json({ error: "Failed to register new asset to the database" });
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
        (SELECT o.office_name 
         FROM public.processed_document first_pd 
         JOIN public.offices o ON first_pd.current_office_id = o.o_id 
         WHERE first_pd.ini_id = idoc.ini_id 
         ORDER BY first_pd.pd_id ASC LIMIT 1) as originating_office,
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
      SELECT r.stop_1, r.stop_2, r.stop_3, r.stop_4, r.stop_5, r.stop_6, r.stop_7, u.d_id as originator_dept_id
      FROM public.initial_document idoc
      JOIN public.process_type pt ON idoc.p_id = pt.p_id
      JOIN public.route r ON pt.r_id = r.r_id
      JOIN public."User" u ON idoc.u_id = u.u_id
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
      let mappedStop1 = r.stop_1;
      
      // The Dynamic Swap: Translate 999 back into the Originator's actual office
      if (mappedStop1 === 999) {
          const departmentToOfficeMap = {
              1: 11, 2: 12, 3: 13, 4: 14, 5: 14, 6: 24
          };
          mappedStop1 = departmentToOfficeMap[r.originator_dept_id] || 11;
      }

      // Build the sequence using mappedStop1 instead of the raw r.stop_1
      const sequence = [mappedStop1, r.stop_2, r.stop_3, r.stop_4, r.stop_5, r.stop_6, r.stop_7].filter(Boolean);
      
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
          idoc.ini_id,  /* CRITICAL ADDITION: Pulls the document reference key */
          idoc.title,
          h.action_type as title_alert,
          ('Action performed at ' || COALESCE(off.office_name, 'Origin Station')) as message,
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
        ini_id: row.ini_id, /* Passed cleanly down to client tracking layer */
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

// FETCH ALL BLACKOUTS
app.get('/api/resources/blackouts', async (req, res) => {
  try {
    // JOIN added so the frontend gets the asset_name directly
    const query = `
      SELECT ab.*, ad.asset_name 
      FROM public.asset_blackouts ab
      JOIN public.asset_details ad ON ab.asd_id = ad.asd_id
    `;
    const result = await pool.query(query);
    res.json(result.rows);
  } catch (err) {
    res.status(500).json({ error: "Failed to fetch blackout records." });
  }
});

// CREATE A NEW BLACKOUT
app.post('/api/resources/blackouts', requireAuth, async (req, res) => {
  const { asd_id, start_time, end_time, reason } = req.body;
  try {
    await pool.query(
      `INSERT INTO public.asset_blackouts (asd_id, start_time, end_time, reason, blocked_by) 
       VALUES ($1, $2, $3, $4, $5)`,
      // We added parseInt() here to ensure the database gets a strict number
      [parseInt(asd_id), start_time, end_time, reason, req.user.u_id] 
    );
    res.status(201).json({ message: "Asset successfully blocked." });
  } catch (err) {
    console.error("Blackout Insert Error:", err); // Added this so it's easier to spot in the terminal!
    res.status(500).json({ error: "Failed to apply blackout date." });
  }
});

// FETCH ALL PROCUREMENT RESERVATIONS
app.get('/api/procurement/reservations', requireAuth, async (req, res) => {
  try {
    const query = `
      SELECT b.booking_id, b.booking_type, b.reservation_date, b.purpose, b.status, 
             b.created_at, 
             CASE 
                WHEN b.status = 'Confirmed' THEN b.updated_at 
                ELSE NULL 
             END as updated_at,
             u.full_name as requestor,
             COALESCE(gm.start_time, vr.pick_up_time) as start_time,
             COALESCE(gm.end_time, vr.drop_off_time) as end_time,
             ad.asset_name
      FROM public.bookings b
      JOIN public."User" u ON b.u_id = u.u_id
      LEFT JOIN public.gm_requirements gm ON b.booking_id = gm.booking_id
      LEFT JOIN public.vehicle_requirements vr ON b.booking_id = vr.booking_id
      LEFT JOIN public.asset_details ad ON (gm.asd_id = ad.asd_id OR vr.asd_id = ad.asd_id)
      ORDER BY b.reservation_date DESC
    `;
    const result = await pool.query(query);
    res.json(result.rows);
  } catch (err) {
    res.status(500).json({ error: "Failed to fetch procurement reservations." });
  }
});

// FETCH LOGISTICS HISTORY (Equipment Ledgers)
app.get('/api/procurement/logistics', requireAuth, async (req, res) => {
  try {
    const query = `
      SELECT 
        el.log_id,
        ad.asset_name, 
        el.requestor_name, 
        el.qty_borrowed, 
        el.borrowed_at, 
        el.returned_at,
        el.status,
        el.condition_on_return,
        el.damage_notes
      FROM public.equipment_ledgers el
      JOIN public.asset_details ad ON el.asd_id = ad.asd_id
      ORDER BY el.borrowed_at DESC
    `;
    const result = await pool.query(query);
    res.json(result.rows);
  } catch (err) {
    res.status(500).json({ error: "Failed to fetch logistics history." });
  }
});

// GET & SYNC BOOKING CHECKLIST
app.get('/api/procurement/checklists/:bookingId/:type', requireAuth, async (req, res) => {
  const { bookingId, type } = req.params;
  const client = await pool.connect();
  try {
    await client.query('BEGIN');
    
    // 1. Check if this booking already has checklist items
    const existingChecklist = await client.query('SELECT * FROM public.booking_checklists WHERE booking_id = $1', [bookingId]);
    
    if (existingChecklist.rows.length === 0) {
      // 2. If empty, generate them from the global template
      const templates = await client.query('SELECT item_name FROM public.checklist_templates WHERE booking_type = $1', [type]);
      if (templates.rows.length > 0) {
        for (let t of templates.rows) {
          await client.query(
            'INSERT INTO public.booking_checklists (booking_id, item_name, is_checked) VALUES ($1, $2, false)',
            [bookingId, t.item_name]
          );
        }
      }
    }
    
    // 3. Return the checklist state
    const currentChecklist = await client.query('SELECT * FROM public.booking_checklists WHERE booking_id = $1 ORDER BY check_id ASC', [bookingId]);
    await client.query('COMMIT');
    res.json(currentChecklist.rows);
  } catch (err) {
    await client.query('ROLLBACK');
    res.status(500).json({ error: "Failed to fetch checklist." });
  } finally {
    client.release();
  }
});

// UPDATE CHECKLIST STATUS & AUTO-CONFIRM
app.put('/api/procurement/checklists/:checkId', requireAuth, async (req, res) => {
  const { checkId } = req.params;
  const { isChecked, bookingId } = req.body;
  const client = await pool.connect();
  try {
    await client.query('BEGIN');
    
    // Update specific item
    await client.query('UPDATE public.booking_checklists SET is_checked = $1 WHERE check_id = $2', [isChecked, checkId]);
    
    // Check if ALL items for this booking are now ticked off
    const allItems = await client.query('SELECT is_checked FROM public.booking_checklists WHERE booking_id = $1', [bookingId]);
    const allChecked = allItems.rows.every(item => item.is_checked === true);
    
    // Auto-update booking status if requirements are met
// Auto-update booking status if requirements are met
  if (allChecked && allItems.rows.length > 0) {
    await client.query("UPDATE public.bookings SET status = 'Confirmed', updated_at = timezone('Asia/Manila', now()) WHERE booking_id = $1", [bookingId]);
  } else {
    await client.query("UPDATE public.bookings SET status = 'Reserved' WHERE booking_id = $1", [bookingId]);
  }

    await client.query('COMMIT');
    res.json({ message: "Checklist updated", allChecked });
  } catch (err) {
    await client.query('ROLLBACK');
    res.status(500).json({ error: "Failed to update checklist status." });
  } finally {
    client.release();
  }
});

// ==========================================
// MASTER CHECKLIST TEMPLATES ENDPOINTS
// ==========================================

// GET Master Templates by Facility Type
app.get('/api/procurement/templates/:type', requireAuth, async (req, res) => {
  try {
    const { type } = req.params;
    const result = await pool.query(
      'SELECT template_id, item_name, booking_type FROM public.checklist_templates WHERE booking_type = $1 ORDER BY template_id ASC', 
      [type]
    );
    res.json(result.rows);
  } catch (err) {
    res.status(500).json({ error: "Failed to fetch master checklist templates." });
  }
});

// POST New Master Template Item
app.post('/api/procurement/templates', requireAuth, async (req, res) => {
  try {
    const { bookingType, itemName } = req.body;
    await pool.query(
      'INSERT INTO public.checklist_templates (booking_type, item_name) VALUES ($1, $2)', 
      [bookingType, itemName]
    );
    res.status(201).json({ message: "Template item successfully added." });
  } catch (err) {
    res.status(500).json({ error: "Failed to add template item." });
  }
});

// DELETE Master Template Item
app.delete('/api/procurement/templates/:id', requireAuth, async (req, res) => {
  try {
    const { id } = req.params;
    await pool.query(
      'DELETE FROM public.checklist_templates WHERE template_id = $1', 
      [id]
    );
    res.json({ message: "Template item permanently removed." });
  } catch (err) {
    res.status(500).json({ error: "Failed to delete template item." });
  }
});

// =========================================================================
// CHAT WITH OFFICES (INQUIRING ON URGENT DOCUMENTS) ENDPOINTS
// =========================================================================

// 1. GET ALL CHAT CHANNELS FOR A SPECIFIC DOCUMENT (Evaluates Lock states dynamically)
app.get('/api/chat/document-channels/:iniId', requireAuth, async (req, res) => {
  const { iniId } = req.params;
  try {
    const docStepsQuery = `
      SELECT pd_id, s_id, current_office_id, next_office_id, time_in, time_out, is_adhoc, adhoc_return_office_id 
      FROM public.processed_document 
      WHERE ini_id = $1 
      ORDER BY pd_id ASC;
    `;
    const stepsResult = await pool.query(docStepsQuery, [parseInt(iniId)]);
    const steps = stepsResult.rows;

    if (steps.length === 0) {
      return res.json([]);
    }

    const officeChannels = {};
    const now = new Date();

    for (let i = 0; i < steps.length; i++) {
      const step = steps[i];
      const officeId = step.current_office_id;
      
      if (!officeChannels[officeId]) {
        officeChannels[officeId] = { officeId, isLocked: true, statusMessage: 'Read-Only Archive' };
      }

      const isLastStep = (i === steps.length - 1);

      if (isLastStep) {
        if (step.time_out === null) {
          officeChannels[officeId].isLocked = false;
          officeChannels[officeId].statusMessage = 'Active Connection';
        } else {
          if (step.s_id === 4 || step.s_id === 5) {
            const checkoutTime = new Date(step.time_out);
            const hoursElapsed = (now - checkoutTime) / (1000 * 60 * 60);

            if (hoursElapsed <= 24) {
              officeChannels[officeId].isLocked = false;
              officeChannels[officeId].statusMessage = `Interactive Grace Period (${Math.ceil(24 - hoursElapsed)}h remaining)`;
            } else {
              officeChannels[officeId].isLocked = true;
              officeChannels[officeId].statusMessage = 'Closed (Grace Period Expired)';
            }
          } else {
            const lookAheadNextStep = steps.find(s => s.current_office_id === step.next_office_id && s.pd_id > step.pd_id);
            
            if (lookAheadNextStep && lookAheadNextStep.time_in !== null) {
              officeChannels[officeId].isLocked = true;
              officeChannels[officeId].statusMessage = 'Read-Only Archive (Received by next station)';
            } else if (step.next_office_id) {
              officeChannels[officeId].isLocked = false;
              officeChannels[officeId].statusMessage = 'Active Connection (In Transit)';
            }
          }
        }

        if (step.is_adhoc && step.time_out === null) {
          const primaryOfficeId = step.adhoc_return_office_id;
          if (officeChannels[primaryOfficeId]) {
            officeChannels[primaryOfficeId].isLocked = false;
            officeChannels[primaryOfficeId].statusMessage = 'Active Connection (Awaiting Detour Return)';
          }
        }
      }
    }

    const finalChannels = [];
    for (const oId of Object.keys(officeChannels)) {
      const officeNameRes = await pool.query('SELECT office_name FROM public.offices WHERE o_id = $1', [parseInt(oId)]);
      
      // CHECK IF A CHAT ROOM ACTUALLY EXISTS AND HAS MESSAGES IN IT
      const checkRoom = await pool.query(
        `SELECT room_id FROM public.chat_rooms WHERE ini_id = $1 AND o_id = $2`,
        [parseInt(iniId), parseInt(oId)]
      );
      
      let hasChat = false;
      if (checkRoom.rows.length > 0) {
        const checkMessages = await pool.query(
          `SELECT COUNT(message_id)::int FROM public.chat_messages WHERE room_id = $1`,
          [checkRoom.rows[0].room_id]
        );
        hasChat = checkMessages.rows[0].count > 0;
      }

      finalChannels.push({
        officeId: parseInt(oId),
        officeName: officeNameRes.rows[0]?.office_name || `Office Station #${oId}`,
        isLocked: officeChannels[oId].isLocked,
        statusMessage: officeChannels[oId].statusMessage,
        hasChat: hasChat
      });
    }

    res.json(finalChannels);
  } catch (err) {
    console.error("Error evaluating chat layout channel rules:", err);
    res.status(500).json({ error: 'Failed evaluating channel permission tables.' });
  }
});
// 2. FETCH OR INITIALIZE ROOM ON-DEMAND (Only if originator initiates chat message)
app.post('/api/chat/get-or-create-room', requireAuth, async (req, res) => {
  const { iniId, officeId } = req.body;
  try {
    // Check if channel already exists to prevent duplicate tables instantiation
    let roomRes = await pool.query(
      'SELECT room_id FROM public.chat_rooms WHERE ini_id = $1 AND o_id = $2',
      [parseInt(iniId), parseInt(officeId)]
    );

    if (roomRes.rows.length === 0) {
      roomRes = await pool.query(
        `INSERT INTO public.chat_rooms (ini_id, o_id, created_at) 
         VALUES ($1, $2, TIMEZONE('Asia/Manila', NOW())) RETURNING room_id`,
        [parseInt(iniId), parseInt(officeId)]
      );
    }

    res.json({ roomId: roomRes.rows[0].room_id });
  } catch (err) {
    console.error("Error instantiating or resolving chat room nodes:", err);
    res.status(500).json({ error: 'Failed chat room assignment initialization query structural loops.' });
  }
});

// 3. GET MESSAGES STREAM FOR A SPECIFIC ROOM
app.get('/api/chat/rooms/:roomId/messages', requireAuth, async (req, res) => {
  const { roomId } = req.params;
  try {
    const messagesQuery = `
      SELECT m.message_id, m.room_id, m.sender_id, m.message_text, m.sent_at, u.full_name as sender_name, a.account_type as role_name
      FROM public.chat_messages m
      JOIN public."User" u ON m.sender_id = u.u_id
      JOIN public.account a ON u.a_id = a.a_id
      WHERE m.room_id = $1
      ORDER BY m.sent_at ASC;
    `;
    const result = await pool.query(messagesQuery, [parseInt(roomId)]);
    res.json(result.rows);
  } catch (err) {
    console.error("Error fetching historical stream messages loop:", err);
    res.status(500).json({ error: 'Failed message log extraction routing block sequence.' });
  }
});

// 4. POST NEW CHAT MESSAGE ENTRY
app.post('/api/chat/messages', requireAuth, async (req, res) => {
  const { roomId, messageText } = req.body;
  const senderId = req.user.u_id; // Decoded cleanly from your JWT authentication layer middleware
  try {
    const result = await pool.query(
      `INSERT INTO public.chat_messages (room_id, sender_id, message_text, sent_at)
       VALUES ($1, $2, $3, TIMEZONE('Asia/Manila', NOW()))
       RETURNING *`,
      [parseInt(roomId), senderId, messageText.trim()]
    );
    
    res.status(201).json(result.rows[0]);
  } catch (err) {
    console.error("Failed submitting secure message tracking block node:", err);
    res.status(500).json({ error: 'Structural breakdown committing message log row.' });
  }
});

// 5. FETCH ACTIVE CURRENT PENDING DOCUMENTS LIST FOR USER CHAT SELECTION BAR
app.get('/api/chat/active-documents-directory', requireAuth, async (req, res) => {
  const userId = req.user.u_id;
  const roleId = req.user.a_id;
  try {
    let query = '';
    let params = [];

    if (roleId === 1) {
      query = `
        SELECT DISTINCT ON (idoc.ini_id) idoc.ini_id, idoc.title, idoc.created_at
        FROM public.initial_document idoc
        WHERE idoc.u_id = $1
        ORDER BY idoc.ini_id DESC;
      `;
      params = [userId];
    } else if (roleId === 2 || roleId === 4) {
      const userOfficeRes = await pool.query('SELECT o_id FROM public."User" WHERE u_id = $1', [userId]);
      const officeId = userOfficeRes.rows[0]?.o_id;

      if (!officeId) return res.json([]);

      query = `
        SELECT DISTINCT ON (idoc.ini_id) idoc.ini_id, idoc.title, idoc.created_at
        FROM public.initial_document idoc
        JOIN public.processed_document pd ON idoc.ini_id = pd.ini_id
        WHERE pd.current_office_id = $1
        ORDER BY idoc.ini_id DESC;
      `;
      params = [officeId];
    } else {
      return res.json([]);
    }

    const result = await pool.query(query, params);
    const rows = result.rows;

    const finalDirectory = [];
    for (const doc of rows) {
      // Look to see if any station channel under this document contains active records
      const checkRooms = await pool.query(
        `SELECT room_id FROM public.chat_rooms WHERE ini_id = $1`,
        [doc.ini_id]
      );
      
      let hasAnyChat = false;
      if (checkRooms.rows.length > 0) {
        const roomIds = checkRooms.rows.map(r => r.room_id);
        const checkMsgs = await pool.query(
          `SELECT COUNT(message_id)::int FROM public.chat_messages WHERE room_id = ANY($1)`,
          [roomIds]
        );
        hasAnyChat = checkMsgs.rows[0].count > 0;
      }

      finalDirectory.push({
        ...doc,
        hasAnyChat: hasAnyChat
      });
    }

    res.json(finalDirectory);
  } catch (err) {
    console.error("Error compilation active track selection hub array:", err);
    res.status(500).json({ error: 'Failed extraction of operational document parameters directory loops.' });
  }
});

const PYTHON_MICROSERVICE_URL = 'http://localhost:8000';

// Proxy route for Peak Demand (Vehicle Scheduling)
app.get('/api/analytics/peak-demand', requireAuth, async (req, res) => {
    try {
        const response = await axios.get(`${PYTHON_MICROSERVICE_URL}/api/analytics/peak-demand`);
        res.json(response.data);
    } catch (error) {
        console.error('Error fetching peak demand analytics:', error.message);
        res.status(500).json({ message: 'Analytics service unavailable' });
    }
});

// Proxy route for Bottleneck Analytical Evaluation Process
//app.get('/api/analytics/bottlenecks', requireAuth, async (req, res) => {
  app.get('/api/analytics/bottlenecks', async (req, res) => {
    try {
        const response = await axios.get(`${PYTHON_MICROSERVICE_URL}/api/analytics/bottlenecks`);
        res.json(response.data);
    } catch (error) {
        console.error('Error fetching bottleneck analytics:', error.message);
        res.status(500).json({ message: 'Analytics service unavailable' });
    }
});

// Proxy route for Estimated Document Completion (EDC)
app.get('/api/analytics/edc', requireAuth, async (req, res) => {
    try {
        const response = await axios.get(`${PYTHON_MICROSERVICE_URL}/api/analytics/edc`);
        res.json(response.data);
    } catch (error) {
        console.error('Error fetching EDC analytics:', error.message);
        res.status(500).json({ message: 'Analytics service unavailable' });
    }
});

// Proxy route for Route Performance Analytics
app.get('/api/analytics/route-performance', requireAuth, async (req, res) => {
  try {
      const response = await axios.get(`${PYTHON_MICROSERVICE_URL}/api/analytics/route-performance`);
      res.json(response.data);
  } catch (error) {
      console.error('Error fetching route performance analytics:', error.message);
      res.status(500).json({ message: 'Analytics service unavailable' });
  }
});

// Proxy route for System Health & Data Audit
app.get('/api/analytics/system-health', requireAuth, async (req, res) => {
  try {
      const response = await axios.get(`${PYTHON_MICROSERVICE_URL}/api/analytics/system-health`);
      res.json(response.data);
  } catch (error) {
      console.error('Error fetching system health analytics:', error.message);
      res.status(500).json({ message: 'Analytics service unavailable' });
  }
});

const PORT = 5000;
app.listen(PORT, () => {
  console.log(`🚀 Core backend subsystem running on port ${PORT}`);
  initDatabaseListener();
});