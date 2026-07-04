const express = require('express');
const cors = require('cors');
const jwt = require('jwt-simple');
const bcrypt = require('bcrypt');
const pool = require('./db');
const { sendResetCodeEmail } = require('./mailer');
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

    // 🛡️ THE DEACTIVATION LOCK GATEKEEPER
    // Instantly rejects login attempts if the account access flag has been disabled by the admin
    if (user.is_active === false) {
      return res.status(403).json({ error: 'Access Revoked: This user profile has been deactivated by administration.' });
    }

    // Initialize state counter if missing from cache array
    if (!failed2faAttemptsTracker[user.u_id]) {
      failed2faAttemptsTracker[user.u_id] = 0;
    }

    // Lockout gatekeeper: if failed entries surpass 10 consecutive loops, throw structural lockout code
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
        failed2faAttemptsTracker[user.u_id] += 1; // Increment metric log
        
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
      
      // Clear memory tracking if evaluation succeeds
      failed2faAttemptsTracker[user.u_id] = 0;
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

// ====================================================================
// NEW ICT ADMIN ENDPOINT: FETCH ALL USERS WITH RELATIONALLY JOINED NAMES
// ====================================================================
app.get('/api/accounts', async (req, res) => {
  try {
    // We select critical profile fields, joining tables to map role strings and office names
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

// ====================================================================
// NEW ICT ADMIN ENDPOINT: SECURE ACCOUNT RECONFIGURATION OVERRIDE
// ====================================================================
app.put('/api/accounts/:userId', async (req, res) => {
  const { userId } = req.params;
  // 🛡️ SECURITY SHIELD: twoFaEnabled and twoFaCode are completely stripped out of parameters map
  const { username, fullName, email, accountType, departmentId, officeId, isActive } = req.body;  
  try {
    // Validate if the modified username is taken by another account primary key identifier
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

    // 🛡️ IMMUTABLE QUERY: Omit setting the two_fa columns entirely to neutralize Admin override tampering
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

// 2. RETRIEVE DETAILED PROFILE METADATA 
app.get('/api/profile/:userId', async (req, res) => {
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

app.get('/api/process-types', async (req, res) => {
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

app.get('/api/documents/:userId', async (req, res) => {
  try {
    const query = `
      SELECT DISTINCT ON (idoc.ini_id)
             idoc.ini_id, 
             idoc.title, 
             idoc.edc, 
             idoc.qr_code, 
             pt.process_name,
             curr_o.office_name as current_office, 
             next_o.office_name as next_office, 
             st.current_status as status
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

app.post('/api/documents', async (req, res) => {
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

app.post('/api/accounts', async (req, res) => {
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

// ==========================================
// SCHOOL RESOURCES SCHEDULER ENDPOINTS
// ==========================================
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

// FETCH INCOMING DOCUMENTS FILTERED BY THE PROCESSOR'S ASSIGNED OFFICE
app.get('/api/processor/documents/:officeId', async (req, res) => {
  const { officeId } = req.params;
  try {
    const query = `
      SELECT 
        idoc.ini_id, 
        idoc.title, 
        idoc.edc, 
        idoc.qr_code, 
        pt.process_name,
        INITCAP(st.current_status) as status,
        curr_o.office_name as current_office, 
        next_o.office_name as next_office,
        pdoc.time_in,
        pdoc.time_out,
        pdoc.is_adhoc,
        pdoc.adhoc_return_office_id
      FROM public.processed_document pdoc
      JOIN public.initial_document idoc ON pdoc.ini_id = idoc.ini_id
      JOIN public.process_type pt ON idoc.p_id = pt.p_id
      LEFT JOIN public.offices curr_o ON pdoc.current_office_id = curr_o.o_id
      LEFT JOIN public.offices next_o ON pdoc.next_office_id = next_o.o_id
      LEFT JOIN public.status st ON pdoc.s_id = st.s_id
      WHERE pdoc.current_office_id = $1 AND pdoc.time_out IS NULL
      ORDER BY pdoc.time_in DESC NULLS LAST;
    `;
    const result = await pool.query(query, [parseInt(officeId)]);
    res.json(result.rows);
  } catch (err) {
    console.error("Processor document query error:", err);
    res.status(500).json({ error: "Failed to load office document streams" });
  }
});

// ==========================================
// SMART SCANNER ENDPOINTS WITH MANILA TIMEZONE
// ==========================================
app.post('/api/documents/scan-in', async (req, res) => {
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

app.post('/api/documents/scan-out', async (req, res) => {
  const { qrCode, processorUserId } = req.body;
  try {
    const procRes = await pool.query('SELECT o_id FROM public."User" WHERE u_id = $1', [processorUserId]);
    const processorOfficeId = procRes.rows[0]?.o_id;

    const checkStatusRes = await pool.query(`
      SELECT pd.pd_id, pd.time_in, st.current_status, pd.next_office_id, pd.ini_id, idoc.title
      FROM public.processed_document pd
      JOIN public.initial_document idoc ON pd.ini_id = idoc.ini_id
      JOIN public.status st ON pd.s_id = st.s_id
      WHERE idoc.qr_code = $1 AND pd.time_out IS NULL
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

    if (currentStatusClean === 'pending' || currentStatusClean === 'in verification') {
      return res.status(400).json({ 
        error: "Rejection: This document cannot be signed out yet. It requires approval/signature from the office Signee." 
      });
    }

    // Record the checkout timestamp for the current station
    await pool.query(`
      UPDATE public.processed_document 
      SET time_out = TIMEZONE('Asia/Manila', NOW()) 
      WHERE pd_id = $1
    `, [currentActiveStep.pd_id]);

    const adhocCheckRes = await pool.query(`
      SELECT is_adhoc, adhoc_return_office_id, is_returned_from_adhoc, current_office_id
      FROM public.processed_document
      WHERE pd_id = $1
    `, [currentActiveStep.pd_id]);

    const adhocData = adhocCheckRes.rows[0];

    if (adhocData && adhocData.is_adhoc) {
      // Return route execution from ad-hoc detour sub-loops
      await pool.query(`
        INSERT INTO public.processed_document (ini_id, s_id, current_office_id, next_office_id, is_returned_from_adhoc, time_in)
        VALUES ($1, 1, $2, NULL, true, NULL)
      `, [currentActiveStep.ini_id, adhocData.adhoc_return_office_id]);
    } else {
      const routeRes = await pool.query(`
        SELECT r.stop_1, r.stop_2, r.stop_3, r.stop_4, r.stop_5, r.stop_6, r.stop_7
        FROM public.initial_document idoc
        JOIN public.process_type pt ON idoc.p_id = pt.p_id
        JOIN public.route r ON pt.r_id = r.r_id
        WHERE idoc.ini_id = $1
      `, [currentActiveStep.ini_id]);

      const r = routeRes.rows[0];
      let foundNextStop = null;
      let targetCurrentOffice = currentActiveStep.next_office_id || adhocData.current_office_id;

      if (r) {
        const sequence = [r.stop_1, r.stop_2, r.stop_3, r.stop_4, r.stop_5, r.stop_6, r.stop_7].filter(Boolean);
        const currentIndex = sequence.indexOf(targetCurrentOffice);
        if (currentIndex !== -1 && currentIndex + 1 < sequence.length) {
          foundNextStop = sequence[currentIndex + 1];
        }
      }

      if (!foundNextStop) {
        // 🏁 PIPELINE ROUTE COMPLETION
        // No further stops remaining in sequence: allocate finalized confirmation step log (s_id = 5)
        await pool.query(`
          INSERT INTO public.processed_document (ini_id, s_id, current_office_id, next_office_id, time_in, time_out)
          VALUES ($1, 5, $2, NULL, TIMEZONE('Asia/Manila', NOW()), TIMEZONE('Asia/Manila', NOW()))
        `, [currentActiveStep.ini_id, targetCurrentOffice]);
      } else {
        // Dispatch document forward to next standard sequence office lane block
        await pool.query(`
          INSERT INTO public.processed_document (ini_id, s_id, current_office_id, next_office_id, time_in)
          VALUES ($1, 1, $2, $3, NULL)
        `, [currentActiveStep.ini_id, targetCurrentOffice, foundNextStop]);
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

// FETCH EXTENDED PIPELINE RECORDS FOR THE MASTER DOCUMENTS TAB
app.get('/api/processor/documents/pipeline/:officeId', async (req, res) => {
  const { officeId } = req.params;
  try {
    const query = `
      SELECT DISTINCT ON (idoc.ini_id)
        idoc.ini_id, 
        idoc.title, 
        idoc.edc, 
        idoc.qr_code, 
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
      LEFT JOIN public.processed_document pdoc_office ON idoc.ini_id = pdoc_office.ini_id AND pdoc_office.current_office_id = $1
      LEFT JOIN public.processed_document pdoc_active ON idoc.ini_id = pdoc_active.ini_id AND pdoc_active.time_out IS NULL
      LEFT JOIN public.offices orig_o ON r.stop_1 = orig_o.o_id
      LEFT JOIN public.offices curr_o ON pdoc_active.current_office_id = curr_o.o_id
      LEFT JOIN public.offices next_o ON pdoc_active.next_office_id = next_o.o_id
      LEFT JOIN public.status st ON pdoc_active.s_id = st.s_id
      WHERE pdoc_office.pd_id IS NOT NULL 
         OR pdoc_active.current_office_id = $1
         OR r.stop_1 = $1 OR r.stop_2 = $1 OR r.stop_3 = $1 OR r.stop_4 = $1 OR r.stop_5 = $1 OR r.stop_6 = $1 OR r.stop_7 = $1
      ORDER BY idoc.ini_id DESC;
    `;
    const result = await pool.query(query, [parseInt(officeId)]);
    res.json(result.rows);
  } catch (err) {
    console.error("Pipeline query error:", err);
    res.status(500).json({ error: "Failed to load master pipeline streams" });
  }
});

// EXECUTE AD-HOC DETOUR VERIFICATION REROUTE
app.post('/api/processor/documents/ad-hoc', async (req, res) => {
  const { iniId, targetOfficeId, currentOfficeId, executorUserId } = req.body;

  const client = await pool.connect();
  try {
    await client.query('BEGIN');

    const activeStepRes = await client.query(`
      SELECT pd_id, next_office_id, time_in 
      FROM public.processed_document 
      WHERE ini_id = $1 AND current_office_id = $2 AND time_out IS NULL
    `, [parseInt(iniId), parseInt(currentOfficeId)]);

    if (activeStepRes.rows.length === 0) {
      throw new Error("No active, open tracking step found for this document in your office.");
    }

    const currentStep = activeStepRes.rows[0];

    if (currentStep.time_in === null) {
      throw new Error("Rejection: Cannot request an ad-hoc detour. This document has not been scanned for Time-In at your office.");
    }

    await client.query (`
      UPDATE public.processed_document
      SET s_id = 2 -- 'In Verification'
      WHERE pd_id = $1
    `, [currentStep.pd_id]);

    await client.query(`
      INSERT INTO public.processed_document (
        ini_id, 
        s_id, 
        current_office_id, 
        next_office_id, 
        is_adhoc, 
        adhoc_return_office_id, 
        time_in, 
        time_out
      )
      VALUES ($1, 1, $2, $3, true, $3, NULL, NULL)
    `, [parseInt(iniId), parseInt(targetOfficeId), parseInt(currentOfficeId)]);

    await client.query(`
      INSERT INTO public.office_action_history (ini_id, u_id, o_id, action_type, action_timestamp)
      VALUES ($1, $2, $3, 'Ad-Hoc Detour Routed', TIMEZONE('Asia/Manila', NOW()))
    `, [parseInt(iniId), parseInt(executorUserId), parseInt(currentOfficeId)]);

    await client.query('COMMIT');
    res.json({ message: "Ad-hoc verification detour successfully injected into tracking pipeline!" });

  } catch (err) {
    await client.query('ROLLBACK');
    console.error("Ad-hoc routing transaction error:", err);
    res.status(500).json({ error: err.message || "Failed to commit ad-hoc routing detour step." });
  } finally {
    client.release();
  }
});

// FETCH HISTORY DATA LEDGER FOR ALL PROCESSORS IN THE SPECIFIC OFFICE
app.get('/api/processor/history/:officeId', async (req, res) => {
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
        ORDER BY ABS(EXTRACT(EPOCH FROM (pd.time_in - h.action_timestamp))) ASC NULLS LAST
        LIMIT 1
      ) pdoc ON TRUE
      LEFT JOIN public.offices curr_o ON pdoc.current_office_id = curr_o.o_id
      LEFT JOIN public.offices next_o ON pdoc.next_office_id = next_o.o_id
      LEFT JOIN public.status st ON pdoc.s_id = st.s_id
      WHERE h.o_id = $1
      ORDER BY h.action_timestamp DESC;
    `;
    const result = await pool.query(query, [parseInt(officeId)]);
    res.json(result.rows);
  } catch (err) {
    console.error("Audit trail lookup log mapping error:", err);
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

// SIGNEE ACTION: OFFICIAL ROUTING SIGNATURE RECORD
app.post('/api/signee/sign', async (req, res) => {
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

// SIGNEE ACTION: SEND BACK FOR REVISION (HALTS ALL WORKFLOW STEPS)
app.post('/api/signee/return', async (req, res) => {
  const { iniId, currentOfficeId, signeeUserId, reason } = req.body;

  try {
    const updateResult = await pool.query(`
      UPDATE public.processed_document
      SET s_id = 4
      WHERE ini_id = $1 AND current_office_id = $2 AND time_out IS NULL
      RETURNING pd_id
    `, [parseInt(iniId), parseInt(currentOfficeId)]);

    if (updateResult.rows.length === 0) {
      return res.status(404).json({ error: "Document active link context is missing." });
    }

    const actionMessage = `Sent Back for Revision: ${reason.substring(0, 100)}`;
    await pool.query(`
      INSERT INTO public.office_action_history (ini_id, u_id, o_id, action_type, action_timestamp)
      VALUES ($1, $2, $3, $4, TIMEZONE('Asia/Manila', NOW()))
    `, [parseInt(iniId), parseInt(signeeUserId), parseInt(currentOfficeId), actionMessage]);

    res.json({ message: "Document flagged for corrections and halted cleanly." });
  } catch (err) {
    console.error("Return routing tracking mismatch error:", err);
    res.status(500).json({ error: "Internal processing structural breakdown." });
  }
});

// FORGOT PASSWORD STEP 1: IDENTIFY ACCOUNT & MASK EMAIL
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

// FORGOT PASSWORD STEP 2 & 3: VERIFY EMAIL & DISPATCH 6-DIGIT CODE
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

// FORGOT PASSWORD STEP 4: VALIDATE CODE AND COMMIT NEW HASHED PASSWORD
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

    // Directly overwrite code entries in the database and unlock any active memory lockouts
    await pool.query('UPDATE public."User" SET two_fa_code = $1 WHERE u_id = $2', [newRandomPin, user.u_id]);
    failed2faAttemptsTracker[user.u_id] = 0; 

    // Send the freshly generated PIN code directly to the user's university email box
    await sendResetCodeEmail(user.uni_email, user.full_name, `YOUR SECURITY DASHBOARD TWO-FACTOR AUTHENTICATION PIN HAS BEEN RESET TO: ${newRandomPin}`);

    res.json({ message: 'A fresh verification PIN has been dispatched to your institutional inbox successfully!' });
  } catch (err) {
    res.status(500).json({ error: 'Failed autonomous self-service recovery tracking code loop.' });
  }
});

// ====================================================================
// SECTION 3: ROLES, PERMISSIONS & WORKFLOW MANAGEMENT ENDPOINTS
// ====================================================================

// 1. DISPATCH NEW PROCESS TEMPLATE AND STEP WORKFLOW VIA TRANSACTION MATRIX
app.post('/api/process-types', async (req, res) => {
  const { processName, stops } = req.body;

  // Structural Safeguard Rule Check: Enforce database constraint minimums
  if (!processName || !stops || !Array.isArray(stops) || stops.length < 2) {
    return res.status(400).json({ error: 'Rejection: Routing workflows require a valid process name and a minimum sequence of 2 office stops.' });
  }

  // Structural Safeguard Rule Check: Enforce maximum linear bounds
  if (stops.length > 7) {
    return res.status(400).json({ error: 'Rejection: System architecture restricts document tracking pipelines to a maximum configuration ceiling of 7 stops.' });
  }

  const client = await pool.connect();
  try {
    // Check if the process name already exists to prevent duplicate workflows
    const nameCheck = await client.query('SELECT * FROM public.process_type WHERE LOWER(process_name) = $1', [processName.trim().toLowerCase()]);
    if (nameCheck.rows.length > 0) {
      return res.status(400).json({ error: 'Rejection: A tracking template matching this process designation already exists.' });
    }

    await client.query('BEGIN'); // Start ACID database transaction sequence

    // Pad the incoming array up to 7 elements with null values to map securely to table columns
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

    await client.query('COMMIT'); // Commit structural variables across relational storage nodes
    res.status(201).json({ message: 'Success: Workflow template compiled and active across routing tables!' });
  } catch (err) {
    await client.query('ROLLBACK'); // Abort and roll back tracking values safely on exceptions
    console.error("Workflow creation processing exception:", err);
    res.status(500).json({ error: 'Failed execution transaction sequence process template assignment loops.' });
  } finally {
    client.release();
  }
});

// UPDATE AN EXISTING PROCESS NAME, ACCESS SELECTIONS, AND ITS COMPLETE ROUTE STOPS SEQUENCE
app.put('/api/process-types/:processId', async (req, res) => {
  const { processId } = req.params;
  const { processName, stops, routeId, isActive } = req.body;

  if (!processName || !stops || !Array.isArray(stops) || stops.length < 2) {
    return res.status(400).json({ error: 'Rejection: Routing sequences require a title and a minimum of 2 office locations.' });
  }

  const client = await pool.connect();
  try {
    await client.query('BEGIN'); // Start Transaction

    // 1. Update the Process parameters and the active soft deletion state flag
    await client.query(
      `UPDATE public.process_type 
       SET process_name = $1, is_active = $2 
       WHERE p_id = $3`,
      [processName.trim(), isActive, parseInt(processId)]
    );

    // Pad your incoming route selection numbers up to 7 options
    const parameterizedStops = [...stops];
    while (parameterizedStops.length < 7) {
      parameterizedStops.push(null);
    }

    // 2. Overwrite the matching route stop columns sequence linked to this process template
    const updateRouteQuery = `
      UPDATE public.route 
      SET stop_1 = $1, stop_2 = $2, stop_3 = $3, stop_4 = $4, stop_5 = $5, stop_6 = $6, stop_7 = $7
      WHERE r_id = $8
    `;
    await client.query(updateRouteQuery, [...parameterizedStops, parseInt(routeId)]);

    await client.query('COMMIT'); // Commit Transaction
    res.json({ message: 'Success: Workflow template structural overrides committed cleanly!' });
  } catch (err) {
    await client.query('ROLLBACK'); // Abort on processing error exceptions
    console.error("Workflow update error:", err);
    res.status(500).json({ error: 'Failed transaction updates sequence routing allocation loops.' });
  } finally {
    client.release();
  }
});

// 2. REGISTER DYNAMIC NEW CAMPUS DEPARTMENTS FOR THE ACCOUNT CREATION VIEW
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

// 3. REGISTER DYNAMIC NEW PHYSICAL OFFICE STATION NODES
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

// 4. RETRIEVE GLOBAL AUDITING OVERVIEW OF CAMPUS INFRASTRUCTURE PARAMETERS
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
    // Metric 1: Compute Total Open Active Tracks (Documents currently in processing)
    const activeTracksRes = await pool.query(
      'SELECT COUNT(DISTINCT ini_id)::int as total FROM public.processed_document WHERE time_out IS NULL'
    );

    // Metric 2: Compute Total System Users
    const systemUsersRes = await pool.query(
      'SELECT COUNT(u_id)::int as total FROM public."User"'
    );

    // Metric 3: Compute Total Workflow Templates Registered
    const workflowsCountRes = await pool.query(
      'SELECT COUNT(p_id)::int as total FROM public.process_type'
    );

    // Metric 4: Extract Live System Audit Feed (Most recent 15 operations campus-wide)
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

    // Metric 5: Detect Stalled Documents (Items sitting inside an office past 48 hours without sign-out)
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

    // Respond with consolidated JSON metrics objects payload
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

const PORT = 5000;
app.listen(PORT, () => console.log(`🚀 Core backend subsystem running on port ${PORT}`));