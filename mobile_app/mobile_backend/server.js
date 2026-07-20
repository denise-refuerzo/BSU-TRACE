//require('dotenv').config();
const express = require('express');
const nodemailer = require('nodemailer');
const { google } = require('googleapis');
const crypto = require('crypto');
const cors = require('cors');
const { Pool, Client } = require('pg');
const bcrypt = require('bcrypt');

const app = express();

// ==========================================
// IN-MEMORY TRACKER (No Database Column Required)
// ==========================================
// This stores failed attempts like: { "user_id_1": 4, "user_id_2": 9 }
const failed2FAAttempts = new Map();

// ==========================================
// MIDDLEWARE & CONFIGURATION
// ==========================================
app.use(cors());
app.use(express.json());

// 1. POOLED CONNECTION: Used for all standard API routes (Fast, transaction-based)
const pool = new Pool({
  connectionString: process.env.DATABASE_URL_POOLED, 
  ssl: { rejectUnauthorized: false }
});

// ==========================================
// REAL-TIME POSTGRESQL NOTIFICATION LISTENER
// ==========================================
const initDatabaseListener = async () => {
  // FIX: Create a brand new client instance every time this function runs
  const listenClient = new Client({
    connectionString: process.env.DATABASE_URL_DIRECT,
    ssl: { rejectUnauthorized: false }
  });

  try {
    // Connect using the newly minted DIRECT client
    await listenClient.connect();
    
    // Start listening to the trigger channel
    await listenClient.query('LISTEN document_status_email_channel');
    console.log('Successfully listening to database channel: document_status_email_channel');

    // Handle notifications coming from pg_notify
    listenClient.on('notification', async (msg) => {
      if (msg.channel === 'document_status_email_channel') {
        try {
          const payload = JSON.parse(msg.payload); 
          const { ini_id, s_id } = payload;

          console.log(`🔔 Received real-time DB trigger payload: Document ID ${ini_id}, Status ID ${s_id}`);

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
          
          // Use the POOL for the actual data lookup to maintain performance
          const result = await pool.query(query, [ini_id, s_id]);

          if (result.rows.length > 0) {
            const { title, uni_email, full_name, current_status } = result.rows[0];

            let subject = `BSU-Trace Notification: Document Updated`;
            let messageText = `Hello ${full_name},\n\nYour document "${title}" has been updated to status: ${current_status}.\n\nPlease check your mobile app for details.`;

            if (s_id === 4) { 
              subject = `🚨 Action Required: BSU-Trace Document Halted`;
              messageText = `Hello ${full_name},\n\nYour document "${title}" requires your immediate attention. It has been marked as "Action Required" / Halted.\n\nPlease log in to the BSU-Trace app to view the revision notes and re-submit.`;
            } else if (s_id === 5) { 
              subject = `🎉 BSU-Trace: Document Flow Completed!`;
              messageText = `Hello ${full_name},\n\nGreat news! Your document "${title}" has finished its entire routing sequence and is now officially marked as "Completed".`;
            }

            await sendSystemEmail(uni_email, subject, messageText);
            console.log(`✉️ Automated alert email successfully dispatched to ${uni_email} for document title: "${title}"`);
          } else {
            console.log(`⚠️ Database lookup returned 0 rows for Document ID ${ini_id} with Status ID ${s_id}. Verification failed.`);
          }
        } catch (err) {
          console.error('Error processing database notification payload:', err);
        }
      }
    });

    // Handle unexpected disconnects (like server reboots or network drops)
    listenClient.on('end', () => {
      console.log('Database listener client disconnected. Reconnecting...');
      setTimeout(initDatabaseListener, 5000);
    });

    listenClient.on('error', (err) => {
      console.error('Database listener client crashed. Reconnecting...', err.message);
      setTimeout(initDatabaseListener, 5000);
    });

  } catch (error) {
    console.error('Failed to initialize database notification listener. Retrying in 5s...', error.message);
    setTimeout(initDatabaseListener, 5000);
  }
};

// ==========================================
// GOOGLE API OAUTH2 EMAIL SETUP
// ==========================================
const OAuth2 = google.auth.OAuth2;

// ==========================================
// GOOGLE API HTTPS EMAIL SETUP (Bypasses Render SMTP Block)
// ==========================================
const sendSystemEmail = async (to, subject, text) => {
  // 1. Authenticate using OAuth2
  const oauth2Client = new google.auth.OAuth2(
    process.env.CLIENT_ID,
    process.env.CLIENT_SECRET,
    "https://developers.google.com/oauthplayground"
  );

  oauth2Client.setCredentials({
    refresh_token: process.env.REFRESH_TOKEN
  });

  // 2. Initialize the Gmail API service
  const gmail = google.gmail({ version: 'v1', auth: oauth2Client });

  // 3. Format the email as a standard RFC 2822 message
  const utf8Subject = `=?utf-8?B?${Buffer.from(subject).toString('base64')}?=`;
  const messageParts = [
    // Change EMAIL_USER to your dummy email here if you verified one!
    `From: "BSU-Trace Security" <bsutrace@gmail.com>`, 
    `To: ${to}`,
    'Content-Type: text/plain; charset=utf-8',
    'MIME-Version: 1.0',
    `Subject: ${utf8Subject}`,
    '',
    text,
  ];
  
  const message = messageParts.join('\n');

  // 4. Encode the message in base64url format (required by Gmail API)
  const encodedMessage = Buffer.from(message)
    .toString('base64')
    .replace(/\+/g, '-')
    .replace(/\//g, '_')
    .replace(/=+$/, '');

  // 5. Send via Google's HTTPS API (Port 443 - Never blocked by Render)
  await gmail.users.messages.send({
    userId: 'me',
    requestBody: {
      raw: encodedMessage,
    },
  });
};

// Add this near the very top of server.js with your other requires
const { GoogleGenerativeAI } = require("@google/generative-ai");

// ==========================================
// GEMINI AI CHATBOT ENDPOINT
// ==========================================
// Initialize the SDK. It automatically picks up process.env.GEMINI_API_KEY
const genAI = new GoogleGenerativeAI(process.env.GEMINI_API_KEY);

app.post('/api/chat', async (req, res) => {
  const { userMessage } = req.body;

  if (!userMessage) {
    return res.status(400).json({ error: 'Message is required' });
  }

  try {
    // We use gemini-1.5-flash because it is the fastest and most cost-effective
    const model = genAI.getGenerativeModel({ model: "gemini-2.5-flash" });

    // SYSTEM PROMPT: This tells Gemini who it is and how to behave. 
    // You can customize this to fit BSU-Trace perfectly.
    const systemPrompt = `You are a helpful, professional AI assistant for BSU-Trace, a university document tracking system. 
    Answer this user query politely and concisely: ${userMessage}. Don't answer questions unrelated to the system.`;

    // Ask Gemini to generate the response
    const result = await model.generateContent(systemPrompt);
    const botReply = result.response.text();

    // Send the text back to your Flutter app
    res.status(200).json({ reply: botReply });

  } catch (error) {
    console.error('Gemini API Error:', error);
    res.status(500).json({ error: 'Failed to generate a response from the AI' });
  }
});

// ==========================================
// 1. LOGIN ENDPOINT (Enforces is_active restriction)
// ==========================================
app.post('/api/login', async (req, res) => {
  const { username, password } = req.body;

  try {
    const result = await pool.query(
      'SELECT u_id, password, a_id, two_fa_enabled, is_active FROM public."User" WHERE username = $1',
      [username]
    );

    if (result.rows.length === 0) {
      return res.status(401).json({ error: 'Invalid credentials' });
    }

    const user = result.rows[0];

    // RESTRICTION CHECK: Block login if the account is explicitly deactivated
    if (user.is_active === false) {
      return res.status(403).json({ error: 'Account disabled. Please contact the ICT Administrator.' });
    }

    const isMatch = await bcrypt.compare(password, user.password);
    if (!isMatch) {
      return res.status(401).json({ error: 'Invalid credentials' });
    }

    const sessionToken = crypto.randomBytes(32).toString('hex');
    await pool.query('UPDATE public."User" SET session_token = $1 WHERE u_id = $2', [sessionToken, user.u_id]);

    // FIX: Send exactly ONE unified response package and return immediately
    return res.status(200).json({
      u_id: user.u_id,
      a_id: user.a_id,
      two_fa_enabled: user.two_fa_enabled,
      session_token: sessionToken 
    });

  } catch (error) {
    console.error('Login Error:', error);
    if (!res.headersSent) {
      return res.status(500).json({ error: 'Internal server error' });
    }
  }
});

// ==========================================
// 1.5 VERIFY 2FA ENDPOINT (With Auto-Reset)
// ==========================================
app.post('/api/verify-2fa', async (req, res) => {
  const { u_id, code } = req.body;

  try {
    const result = await pool.query(
      'SELECT uni_email, two_fa_code FROM public."User" WHERE u_id = $1',
      [u_id]
    );

    if (result.rows.length === 0) return res.status(404).json({ error: 'User not found' });

    const user = result.rows[0];

    if (user.two_fa_code === code) {
      failed2FAAttempts.delete(u_id);
      const sessionToken = crypto.randomBytes(32).toString('hex');
      await pool.query('UPDATE public."User" SET session_token = $1 WHERE u_id = $2', [sessionToken, u_id]);
      return res.status(200).json({ success: true });
    } else {
      const currentAttempts = (failed2FAAttempts.get(u_id) || 0) + 1;

      if (currentAttempts >= 10) {
        const newPin = crypto.randomInt(100000, 999999).toString();

        await pool.query(
          'UPDATE public."User" SET two_fa_code = $1 WHERE u_id = $2',
          [newPin, u_id]
        );

        // USING THE NEW GOOGLE API HELPER
        await sendSystemEmail(
          user.uni_email,
          'BSU-Trace Security Alert: New 2FA PIN',
          `There were 10 failed attempts to enter your 2FA PIN.\n\nFor your security, your PIN has been automatically reset.\n\nYour NEW 2FA PIN is: ${newPin}\n\nPlease use this new PIN to log in.`
        );

        failed2FAAttempts.delete(u_id); 
        return res.status(401).json({ error: 'Too many failed attempts. A NEW PIN has been sent to your email.' });
      } else {
        failed2FAAttempts.set(u_id, currentAttempts);
        return res.status(401).json({ error: `Invalid PIN. ${10 - currentAttempts} attempts remaining.` });
      }
    }
  } catch (error) {
    console.error('2FA Verification Error:', error);
    res.status(500).json({ error: 'Internal server error' });
  }
});

// ==========================================
// 1.6 CHECK SESSION ENDPOINT (Single Device Login)
// ==========================================
app.post('/api/check-session', async (req, res) => {
  const { u_id, session_token } = req.body;
  if (!u_id || !session_token) return res.status(400).json({ valid: false });

  try {
    const result = await pool.query('SELECT session_token FROM public."User" WHERE u_id = $1', [u_id]);
    
    // If the token in the DB doesn't match the app's token, another device logged in
    if (result.rows.length === 0 || result.rows[0].session_token !== session_token) {
      return res.status(401).json({ valid: false, error: 'Logged in from another device' });
    }
    
    res.status(200).json({ valid: true });
  } catch (error) {
    res.status(500).json({ error: 'Internal server error' });
  }
});

// ==========================================
// Verify Code & Reset 2FA PIN (Manual Screen)
// ==========================================
app.post('/api/auth/reset-2fa', async (req, res) => {
    const { uni_email, code } = req.body;
    try {
        const result = await pool.query(
          'SELECT u_id, reset_token, reset_token_expires FROM public."User" WHERE uni_email = $1', 
          [uni_email]
        );

        if (result.rows.length === 0) return res.status(400).json({ message: "No request found." });

        const user = result.rows[0];

        if (!user.reset_token) return res.status(400).json({ message: "No request found." });
        if (new Date() > new Date(user.reset_token_expires)) {
            await pool.query('UPDATE public."User" SET reset_token = NULL, reset_token_expires = NULL WHERE uni_email = $1', [uni_email]);
            return res.status(400).json({ message: "Code has expired." });
        }
        if (user.reset_token !== code) return res.status(400).json({ message: "Invalid code." });

        // TRIGGER: Generate a NEW 2FA PIN instead of disabling it entirely
        const newPin = crypto.randomInt(100000, 999999).toString();

        await pool.query(
          'UPDATE public."User" SET two_fa_code = $1, reset_token = NULL, reset_token_expires = NULL WHERE uni_email = $2', 
          [newPin, uni_email]
        );
        
        // Also clear any tracked failed attempts from memory for this user
        failed2FAAttempts.delete(user.u_id);

        // Email the brand new 2FA PIN
        await transporter.sendMail({
          from: process.env.EMAIL_USER,
          to: uni_email,
          subject: 'BSU-Trace: Your New 2FA PIN',
          text: `Your 2FA recovery was successful.\n\nYour NEW 2FA PIN is: ${newPin}\n\nPlease use this new PIN to log in.`
        });

        res.status(200).json({ message: "Success! Your new 2FA PIN has been sent to your email." });
    } catch (error) {
        console.error("Reset 2FA Error:", error);
        res.status(500).json({ message: "Error resetting 2FA." });
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
// 2.5 FETCH ALL USERS (ICT ADMIN) - LEFT JOIN FIX
// ==========================================
app.get('/api/users', async (req, res) => {
  try {
    const query = `
      SELECT 
        u.u_id, 
        u.full_name, 
        u.uni_email,
        u.is_active,
        u.two_fa_enabled,
        a.account_type AS role,
        d.department_name AS department
      FROM public."User" u
      JOIN public.account a ON u.a_id = a.a_id
      LEFT JOIN public.department d ON u.d_id = d.d_id
      ORDER BY u.full_name ASC;
    `;

    const result = await pool.query(query);
    res.status(200).json(result.rows);

  } catch (error) {
    console.error('Fetch All Users Error:', error);
    res.status(500).json({ error: 'Internal server error' });
  }
});

// ==========================================
// 2.6 ADD NEW USER (ICT ADMIN)
// ==========================================
app.post('/api/users', async (req, res) => {
  const { username, password, full_name, uni_email, a_id, d_id, o_id } = req.body;

  // 1. Basic validation (Removed d_id since it's optional)
  if (!username || !password || !full_name || !uni_email || !a_id) {
    return res.status(400).json({ error: 'Missing required fields' });
  }

  // 2. Conditional Office Validation
  // If the account type is 2 (Processor) or 3 (Signee), an office ID is strictly required
  if ((a_id === 2 || a_id === 3) && !o_id) {
    return res.status(400).json({ error: 'Office assignment is required for Processors and Signees' });
  }

  try {
    // 3. Check if username or email already exists
    const checkQuery = `SELECT u_id FROM public."User" WHERE username = $1 OR uni_email = $2`;
    const checkResult = await pool.query(checkQuery, [username, uni_email]);
    
    if (checkResult.rows.length > 0) {
      return res.status(400).json({ error: 'Username or Email is already registered.' });
    }

    // 4. Hash the password securely before saving
    const saltRounds = 10;
    const hashedPassword = await bcrypt.hash(password, saltRounds);

    // 5. Insert the new user (d_id and o_id are handled securely with COALESCE/fallback to null)
    const insertQuery = `
      INSERT INTO public."User" 
      (username, password, full_name, uni_email, a_id, d_id, o_id, is_active)
      VALUES ($1, $2, $3, $4, $5, $6, $7, true)
      RETURNING u_id
    `;
    const values = [
      username, 
      hashedPassword, 
      full_name, 
      uni_email, 
      a_id, 
      d_id || null, 
      o_id || null
    ];
    
    await pool.query(insertQuery, values);

    res.status(201).json({ message: 'User created successfully' });

  } catch (error) {
    console.error('Add User Error:', error);
    res.status(500).json({ error: 'Internal server error' });
  }
});

// ==========================================
// 2.7 ADMIN UPDATE USER ACCOUNT
// ==========================================
app.put('/api/users/:id/admin-update', async (req, res) => {
  const userId = req.params.id;
  const { full_name, uni_email, a_id, d_id, is_active, two_fa_enabled, two_fa_code } = req.body;

  try {
    const checkQuery = `SELECT u_id FROM public."User" WHERE uni_email = $1 AND u_id != $2`;
    const checkResult = await pool.query(checkQuery, [uni_email, userId]);
    if (checkResult.rows.length > 0) return res.status(400).json({ error: 'Email is already registered.' });

    // FIX: Fetch the current PIN so we don't accidentally erase it if the admin only updates the name/role
    const currentRes = await pool.query('SELECT two_fa_code FROM public."User" WHERE u_id = $1', [userId]);
    let codeToSave = currentRes.rows[0]?.two_fa_code || null;

    if (two_fa_enabled) {
      if (two_fa_code) codeToSave = two_fa_code; // Apply new PIN if provided
    } else {
      codeToSave = null; // Wipe PIN if 2FA is toggled off
    }

    const updateQuery = `
      UPDATE public."User"
      SET full_name = $1, uni_email = $2, a_id = $3, d_id = $4, is_active = $5, two_fa_enabled = $6, two_fa_code = $7
      WHERE u_id = $8
    `;
    
    await pool.query(updateQuery, [full_name, uni_email, a_id, d_id, is_active, two_fa_enabled, codeToSave, userId]);
    res.status(200).json({ message: 'Account updated successfully' });

  } catch (error) {
    console.error('Admin Update Error:', error);
    res.status(500).json({ error: 'Internal server error' });
  }
});

// ==========================================
// 2.8 DELETE USER ACCOUNT
// ==========================================
app.delete('/api/users/:id', async (req, res) => {
  const userId = req.params.id;

  try {
    const deleteQuery = `DELETE FROM public."User" WHERE u_id = $1 RETURNING u_id`;
    const result = await pool.query(deleteQuery, [userId]);

    if (result.rows.length === 0) {
      return res.status(404).json({ error: 'User not found' });
    }

    res.status(200).json({ message: 'User deleted successfully' });
  } catch (error) {
    console.error('Delete User Error:', error);
    // Note: If they have tied documents or bookings, this might fail due to foreign key constraints.
    // If so, PostgreSQL will throw an error, which we catch here.
    res.status(500).json({ error: 'Cannot delete user because they have existing documents or bookings tied to their account.' });
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

    // FIX: 
    // 1. Sorts by pd_id to ensure "Awaiting Scan In" (NULL timestamps) appear at the very top.
    // 2. Strictly tracks physical custody to prevent false-positive "Incoming" floods from custom routes.
    const query = `
      WITH RankedDocs AS (
        SELECT 
          i.ini_id, i.qr_code, i.title, p.process_name AS form_type, origin_o.office_name AS origin_office, 
          s.current_status AS status, pd.time_in, pd.time_out,
          pd.current_office_id, pd.is_adhoc, pd.pd_id,
          ROW_NUMBER() OVER (PARTITION BY i.ini_id ORDER BY pd.pd_id DESC) as rn
        FROM public.initial_document i
        LEFT JOIN public.process_type p ON i.p_id = p.p_id
        LEFT JOIN public.route r ON p.r_id = r.r_id
        LEFT JOIN public.offices origin_o ON r.stop_1 = origin_o.o_id
        LEFT JOIN public.processed_document pd ON i.ini_id = pd.ini_id
        LEFT JOIN public.status s ON pd.s_id = s.s_id
      )
      SELECT qr_code, title, form_type, origin_office, status, time_in, time_out, current_office_id,
        TO_CHAR(COALESCE(time_in, CURRENT_TIMESTAMP), 'YYYY-MM-DD"T"HH24:MI:SS"+08:00"') AS created_at,
        CASE WHEN current_office_id = $1 THEN true ELSE false END as is_at_current_office,
        is_adhoc,
        EXISTS (
          SELECT 1 FROM public.processed_document past_pd 
          WHERE past_pd.ini_id = RankedDocs.ini_id 
            AND past_pd.current_office_id = $1 
            AND past_pd.time_out IS NOT NULL
        ) as is_completed_by_me
      FROM RankedDocs
      WHERE rn = 1 
        AND (
          current_office_id = $1 
          OR EXISTS (
            SELECT 1 FROM public.processed_document all_pd 
            WHERE all_pd.ini_id = RankedDocs.ini_id 
              AND all_pd.current_office_id = $1
          )
        )
      ORDER BY pd_id DESC;
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
    
    // Fetch the Originator's Department ID to handle dynamic routing
    const userRes = await pool.query('SELECT d_id FROM public."User" WHERE u_id = $1', [u_id]);
    const userDeptId = userRes.rows[0]?.d_id;

    // Map the Department ID to the specific College Office ID (o_id)
    const departmentToOfficeMap = {
        1: 11, // CICS -> CICS Office
        2: 12, // CABEIHM -> CABEIHM Office
        3: 13, // CAS -> CAS Office
        4: 14, // CIT -> CE / CIT Office
        5: 14, // CE -> CE / CIT Office
        6: 24  // CTE -> CTE Office
    };
    
    // Default to CICS if mapping fails
    const assignedOfficeId = departmentToOfficeMap[userDeptId] || 11;

    // Accept either 'route' or 'stops' array from the frontend
    const customRoute = route || stops;

    if (customRoute && Array.isArray(customRoute) && customRoute.length > 0) {
      // 1. The user explicitly defined a custom routing order
      firstOfficeId = customRoute[0];
      secondOfficeId = customRoute.length > 1 ? customRoute[1] : null;

      // 2. Insert this unique route sequence into the route table to persist it
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

      // 5. The Dynamic Swap Logic
      firstOfficeId = processResult.rows[0].stop_1;
      
      // If the template uses the 999 Placeholder, swap it with the Originator's mapped office
      if (firstOfficeId === 999) {
          firstOfficeId = assignedOfficeId;
      }
      
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
    const docResult = await pool.query(`
      SELECT pd.pd_id, pd.time_in, pd.time_out, s.current_status, i.ini_id, pd.current_office_id
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

    const currentActiveStep = docResult.rows[0];
    const statusLower = currentActiveStep.current_status.toLowerCase();

    if (statusLower === 'in verification' || statusLower === 'pending') {
      return res.status(400).json({ error: 'Cannot scan out: Signee has not signed or acted upon this document yet.' });
    }

    // 1. Fetch the route and the Originator's Department ID
    const routeRes = await pool.query(`
      SELECT r.stop_1, r.stop_2, r.stop_3, r.stop_4, r.stop_5, r.stop_6, r.stop_7, u.d_id as originator_dept_id
      FROM public.initial_document idoc
      JOIN public.process_type pt ON idoc.p_id = pt.p_id
      JOIN public.route r ON pt.r_id = r.r_id
      JOIN public."User" u ON idoc.u_id = u.u_id
      WHERE idoc.ini_id = $1
    `, [currentActiveStep.ini_id]);

    const r = routeRes.rows[0];
    let mappedStop1 = r.stop_1;
    
    // 2. The Dynamic Swap: Translate 999 back into the Originator's actual office
    if (mappedStop1 === 999) {
        const departmentToOfficeMap = {
            1: 11, 2: 12, 3: 13, 4: 14, 5: 14, 6: 24
        };
        mappedStop1 = departmentToOfficeMap[r.originator_dept_id] || 11;
    }

    // 3. Build the sequence array
    const sequence = [mappedStop1, r.stop_2, r.stop_3, r.stop_4, r.stop_5, r.stop_6, r.stop_7].filter(Boolean);
    const currentIndex = sequence.indexOf(currentActiveStep.current_office_id);

    let nextStopToReceive = null;
    let followingStop = null;

    if (currentIndex !== -1 && currentIndex + 1 < sequence.length) {
      nextStopToReceive = sequence[currentIndex + 1];
      if (currentIndex + 2 < sequence.length) {
        followingStop = sequence[currentIndex + 2];
      }
    }

    // 4. Update the database
    if (!nextStopToReceive) {
      // Document is completely finished
      await pool.query(
        `UPDATE public.processed_document 
         SET time_out = timezone('Asia/Manila', now()),
             s_id = (SELECT s_id FROM public.status WHERE current_status ILIKE 'Completed' LIMIT 1)
         WHERE pd_id = $1`,
        [currentActiveStep.pd_id]
      );
    } else {
      // Clock out of current office
      await pool.query(
        `UPDATE public.processed_document 
         SET time_out = timezone('Asia/Manila', now()),
             s_id = (SELECT s_id FROM public.status WHERE current_status ILIKE 'Verified' LIMIT 1)
         WHERE pd_id = $1`,
        [currentActiveStep.pd_id]
      );

      // Create next track sequence
      await pool.query(`
        INSERT INTO public.processed_document (ini_id, s_id, current_office_id, next_office_id, time_in)
        VALUES ($1, (SELECT s_id FROM public.status WHERE current_status ILIKE 'Pending' LIMIT 1), $2, $3, NULL)
      `, [currentActiveStep.ini_id, nextStopToReceive, followingStop]);
    }

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
// 18. FETCH ALL OFFICES (For Dropdowns & UI)
// ==========================================
app.get('/api/offices', async (req, res) => {
  try {
    const query = `
      SELECT 
        o.o_id, 
        o.office_name,
        COUNT(u.u_id)::int AS staff_count
      FROM public.offices o
      LEFT JOIN public."User" u ON o.o_id = u.o_id
      GROUP BY o.o_id, o.office_name
      ORDER BY o.office_name ASC
    `;
    const result = await pool.query(query);
    res.status(200).json(result.rows);
  } catch (error) {
    console.error('Fetch Offices Error:', error);
    res.status(500).json({ error: 'Internal server error' });
  }
});

// ==========================================
// 18.5 REGISTER NEW BRANCH OFFICE NODE
// ==========================================
app.post('/api/offices', async (req, res) => {
  const { office_name } = req.body;

  if (!office_name) {
    return res.status(400).json({ error: 'Office name is required' });
  }

  try {
    // Insert into the public.offices table
    await pool.query(
      'INSERT INTO public.offices (office_name) VALUES ($1)',
      [office_name]
    );
    res.status(201).json({ message: 'Office added successfully' });
  } catch (error) {
    console.error('Add Office Error:', error);
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
// 21. AUTHENTICATION & PASSWORD RESET 
// ==========================================

// Step 1: Send the Code and save it to the DB
app.post('/api/auth/forgot-password', async (req, res) => {
  console.log("1. Forgot password request received for:", req.body.email || req.body.uni_email);
  
  try {
    const email = req.body.email || req.body.uni_email; 

    if (!email) {
      console.log("1b. No email provided in request body.");
      return res.status(400).json({ message: "Email is required" });
    }

    console.log("2. Checking PostgreSQL database for user...");
    const userCheck = await pool.query('SELECT u_id FROM public."User" WHERE uni_email = $1', [email]);
    
    if (userCheck.rows.length === 0) {
      console.log("2b. User not found in database.");
      return res.status(404).json({ message: "No account found with this email." });
    }

    console.log("3. User found! Updating reset token in database...");
    const resetCode = crypto.randomInt(100000, 999999).toString();
    const expiresAt = new Date(Date.now() + 15 * 60 * 1000); 

    await pool.query(
      'UPDATE public."User" SET reset_token = $1, reset_token_expires = $2 WHERE uni_email = $3',
      [resetCode, expiresAt, email]
    );

    console.log("4. Token updated. Attempting to connect to Gmail APIs and send email...");
    // USING THE NEW GOOGLE API HELPER
    await sendSystemEmail(
      email,
      "Your BSU-Trace Password Reset Code",
      `Your password reset code is: ${resetCode}\n\nThis code will expire in 15 minutes.`
    );

    console.log("5. Email sent successfully!");
    res.status(200).json({ message: "Reset code sent successfully!" });

  } catch (error) {
    console.error("6. Forgot Password Error Caught:", error);
    res.status(500).json({ message: "Failed to send email" });
  }
});

// Step 2: Verify Code & Update Password from DB
app.post('/api/auth/reset-password', async (req, res) => {
    const email = req.body.email || req.body.uni_email;
    const code = req.body.code;
    const newPassword = req.body.newPassword || req.body.new_password;

    try {
        // Fetch the user's stored token data
        const result = await pool.query(
          'SELECT reset_token, reset_token_expires FROM public."User" WHERE uni_email = $1', 
          [email]
        );

        if (result.rows.length === 0) {
            return res.status(400).json({ message: "No user found with this email." });
        }

        const user = result.rows[0];

        if (!user.reset_token) {
            return res.status(400).json({ message: "No reset request found for this email." });
        }

        // Check if the token is expired
        if (new Date() > new Date(user.reset_token_expires)) {
            // Clean up the expired token
            await pool.query('UPDATE public."User" SET reset_token = NULL, reset_token_expires = NULL WHERE uni_email = $1', [email]);
            return res.status(400).json({ message: "Reset code has expired. Please request a new one." });
        }

        // Check if the token matches
        if (user.reset_token !== code) {
            return res.status(400).json({ message: "Invalid reset code." });
        }

        // Hash the new password
        const salt = await bcrypt.genSalt(10);
        const hashedPassword = await bcrypt.hash(newPassword, salt);

        // Update password AND clear the used reset token
        await pool.query(
          'UPDATE public."User" SET password = $1, reset_token = NULL, reset_token_expires = NULL WHERE uni_email = $2', 
          [hashedPassword, email]
        );

        res.status(200).json({ message: "Password updated successfully!" });

    } catch (error) {
        console.error("Reset Password Route Error:", error);
        res.status(500).json({ message: "Internal server error while resetting password." });
    }
});

// ==========================================
// 22. FETCH ICT ADMIN DASHBOARD STATS
// ==========================================
app.get('/api/dashboard/ict/stats', async (req, res) => {
  try {
    // Count total documents
    const activeDocsRes = await pool.query(`SELECT COUNT(*) FROM public.initial_document`);
    // Count total users
    const usersRes = await pool.query(`SELECT COUNT(*) FROM public."User"`);
    // Count total process types/workflows
    const workflowsRes = await pool.query(`SELECT COUNT(*) FROM public.process_type`);

    res.status(200).json({
      active_documents: parseInt(activeDocsRes.rows[0].count) || 0,
      total_users: parseInt(usersRes.rows[0].count) || 0,
      total_workflows: parseInt(workflowsRes.rows[0].count) || 0
    });
  } catch (error) {
    console.error('ICT Stats Error:', error);
    res.status(500).json({ error: 'Internal server error' });
  }
});

// ==========================================
// 23. FETCH ICT ADMIN AUDIT LOGS
// ==========================================
app.get('/api/dashboard/ict/logs', async (req, res) => {
  try {
    // Dynamically generates a log sentence by joining the document, status, and office tables
    const query = `
      SELECT 
        'Document "' || i.title || '" marked as "' || s.current_status || '" at ' || o.office_name AS message,
        TO_CHAR(pd.time_in, 'HH12:MI AM') AS timestamp
      FROM public.processed_document pd
      JOIN public.initial_document i ON pd.ini_id = i.ini_id
      JOIN public.status s ON pd.s_id = s.s_id
      JOIN public.offices o ON pd.current_office_id = o.o_id
      WHERE pd.time_in IS NOT NULL
      ORDER BY pd.time_in DESC
      LIMIT 5;
    `;
    const result = await pool.query(query);
    
    res.status(200).json({ logs: result.rows });
  } catch (error) {
    console.error('ICT Logs Error:', error);
    res.status(500).json({ error: 'Internal server error' });
  }
});

// ==========================================
// 24. CREATE NEW WORKFLOW TEMPLATE
// ==========================================
app.post('/api/process-types', async (req, res) => {
  const { process_name, stops } = req.body;

  if (!process_name || !stops || !Array.isArray(stops) || stops.length < 2) {
    return res.status(400).json({ error: 'Process name and at least 2 stops are required.' });
  }

  try {
    // 1. Ensure we don't exceed the database schema (stop_1 to stop_7)
    if (stops.length > 7) {
      return res.status(400).json({ error: 'Maximum of 7 stops allowed per route.' });
    }

    // 2. Insert the new route sequence
    // We pad the array to 7 items with null to match table structure
    const paddedStops = [...stops, ...Array(7 - stops.length).fill(null)];
    
    const routeInsert = await pool.query(
      `INSERT INTO public.route (stop_1, stop_2, stop_3, stop_4, stop_5, stop_6, stop_7) 
       VALUES ($1, $2, $3, $4, $5, $6, $7) 
       RETURNING r_id`,
      paddedStops
    );
    const newRouteId = routeInsert.rows[0].r_id;

    // 3. Insert the new process type linked to the route
    const processInsert = await pool.query(
      `INSERT INTO public.process_type (r_id, process_name, is_active) 
       VALUES ($1, $2, true) 
       RETURNING p_id`,
      [newRouteId, process_name]
    );

    res.status(201).json({ 
      message: 'Workflow template deployed successfully', 
      p_id: processInsert.rows[0].p_id 
    });

  } catch (error) {
    console.error('Deploy Workflow Error:', error);
    res.status(500).json({ error: 'Internal server error while deploying workflow.' });
  }
});

// ==========================================
// 25. REGISTER NEW DEPARTMENT
// ==========================================
app.post('/api/departments', async (req, res) => {
  const { department_name } = req.body;

  if (!department_name) {
    return res.status(400).json({ error: 'Department name is required' });
  }

  try {
    await pool.query(
      'INSERT INTO public.department (department_name) VALUES ($1)',
      [department_name]
    );
    res.status(201).json({ message: 'Department added successfully' });
  } catch (error) {
    console.error('Add Department Error:', error);
    res.status(500).json({ error: 'Internal server error' });
  }
});

// ==========================================
// 25.5 FETCH ALL DEPARTMENTS (WITH STAFF COUNT)
// ==========================================
app.get('/api/departments', async (req, res) => {
  try {
    const query = `
      SELECT 
        d.d_id, 
        d.department_name,
        COUNT(u.u_id)::int AS staff_count
      FROM public.department d
      LEFT JOIN public."User" u ON d.d_id = u.d_id
      GROUP BY d.d_id, d.department_name
      ORDER BY d.department_name ASC
    `;
    const result = await pool.query(query);
    res.status(200).json(result.rows);
  } catch (error) {
    console.error('Fetch Departments Error:', error);
    res.status(500).json({ error: 'Internal server error' });
  }
});

// ==========================================
// 26. EDIT & DELETE DEPARTMENTS
// ==========================================
app.put('/api/departments/:id', async (req, res) => {
  const { department_name } = req.body;
  try {
    await pool.query('UPDATE public.department SET department_name = $1 WHERE d_id = $2', [department_name, req.params.id]);
    res.status(200).json({ message: 'Department updated successfully' });
  } catch (error) { res.status(500).json({ error: 'Server error' }); }
});

app.delete('/api/departments/:id', async (req, res) => {
  try {
    await pool.query('DELETE FROM public.department WHERE d_id = $1', [req.params.id]);
    res.status(200).json({ message: 'Department deleted successfully' });
  } catch (error) { res.status(500).json({ error: 'Cannot delete: This department is currently assigned to active users.' }); }
});

// ==========================================
// 27. EDIT & DELETE OFFICES
// ==========================================
app.put('/api/offices/:id', async (req, res) => {
  const { office_name } = req.body;
  try {
    await pool.query('UPDATE public.offices SET office_name = $1 WHERE o_id = $2', [office_name, req.params.id]);
    res.status(200).json({ message: 'Office updated successfully' });
  } catch (error) { res.status(500).json({ error: 'Server error' }); }
});

app.delete('/api/offices/:id', async (req, res) => {
  try {
    await pool.query('DELETE FROM public.offices WHERE o_id = $1', [req.params.id]);
    res.status(200).json({ message: 'Office deleted successfully' });
  } catch (error) { res.status(500).json({ error: 'Cannot delete: This office is tied to active users or document routes.' }); }
});

// ==========================================
// 28. EDIT & DELETE PROCESS TYPES
// ==========================================
app.put('/api/process-types/:id', async (req, res) => {
  const { process_name } = req.body;
  try {
    await pool.query('UPDATE public.process_type SET process_name = $1 WHERE p_id = $2', [process_name, req.params.id]);
    res.status(200).json({ message: 'Workflow updated successfully' });
  } catch (error) { res.status(500).json({ error: 'Server error' }); }
});

app.delete('/api/process-types/:id', async (req, res) => {
  try {
    await pool.query('DELETE FROM public.process_type WHERE p_id = $1', [req.params.id]);
    res.status(200).json({ message: 'Workflow deleted successfully' });
  } catch (error) { res.status(500).json({ error: 'Cannot delete: There are active documents currently using this workflow.' }); }
});

// ==========================================
// 28.5 EDIT ROUTE SEQUENCE FOR WORKFLOW
// ==========================================
app.put('/api/process-types/:id/route', async (req, res) => {
  const processId = req.params.id;
  const { stops } = req.body;

  if (!Array.isArray(stops) || stops.length < 2) {
    return res.status(400).json({ error: 'A route must have at least 2 stops.' });
  }
  if (stops.includes(null) || stops.includes(undefined)) {
    return res.status(400).json({ error: 'All stops must be valid offices.' });
  }

  const client = await pool.connect();
  try {
    await client.query('BEGIN');
    
    // Find the routing ID linked to this process
    const processResult = await client.query('SELECT r_id FROM public.process_type WHERE p_id = $1', [processId]);
    if (processResult.rows.length === 0) throw new Error("Process not found");
    const r_id = processResult.rows[0].r_id;

    // Pad the sequence to match the 7-stop column structure in DB
    const paddedStops = [...stops, ...Array(7 - stops.length).fill(null)];

    await client.query(
      `UPDATE public.route 
       SET stop_1=$1, stop_2=$2, stop_3=$3, stop_4=$4, stop_5=$5, stop_6=$6, stop_7=$7 
       WHERE r_id = $8`,
      [...paddedStops, r_id]
    );

    await client.query('COMMIT');
    res.status(200).json({ message: 'Route updated successfully' });
  } catch (error) {
    await client.query('ROLLBACK');
    console.error('Update Route Error:', error);
    res.status(500).json({ error: 'Server error' });
  } finally {
    client.release();
  }
});

// ==========================================
// 29. NOTIFICATIONS FOR ORIGINATOR
// ==========================================
app.get('/api/notifications/:userId', async (req, res) => {
    const { userId } = req.params;
    
    try {
        // Query every action on the originator's documents, including the actor's name
        const query = `
            SELECT 
                oah.action_type, 
                oah.action_timestamp, 
                id.title AS document_title, 
                o.office_name,
                actor.full_name AS actor_name
            FROM office_action_history oah
            JOIN initial_document id ON oah.ini_id = id.ini_id
            JOIN offices o ON oah.o_id = o.o_id
            JOIN "User" actor ON oah.u_id = actor.u_id
            WHERE id.u_id = $1
            ORDER BY oah.action_timestamp DESC
            LIMIT 20;
        `;
        
        const result = await db.query(query, [userId]);
        res.status(200).json(result.rows);
    } catch (err) {
        console.error('Error fetching notifications:', err);
        res.status(500).json({ error: 'Failed to fetch notifications' });
    }
});

// Request 2FA Recovery Code
app.post('/api/auth/forgot-2fa', async (req, res) => {
    const { uni_email } = req.body;
    try {
        const userCheck = await pool.query('SELECT u_id, two_fa_enabled FROM public."User" WHERE uni_email = $1', [uni_email]);
        if (userCheck.rows.length === 0) return res.status(404).json({ message: "No account found." });
        if (!userCheck.rows[0].two_fa_enabled) return res.status(400).json({ message: "2FA is not enabled." });

        const code = crypto.randomInt(100000, 999999).toString();
        const expiresAt = new Date(Date.now() + 15 * 60 * 1000);

        // Save token to DB
        await pool.query(
          'UPDATE public."User" SET reset_token = $1, reset_token_expires = $2 WHERE uni_email = $3',
          [code, expiresAt, uni_email]
        );

        await sendSystemEmail(
            uni_email,
            'BSU-Trace 2FA Recovery',
            `Your 2FA recovery code is: ${code}\n\nThis expires in 15 minutes.`
        );
        
        res.status(200).json({ message: "2FA Recovery code sent." });

        await transporter.sendMail({
            from: process.env.EMAIL_USER, 
            to: uni_email, 
            subject: 'BSU-Trace 2FA Recovery',
            text: `Your 2FA recovery code is: ${code}\n\nThis expires in 15 minutes.`
        });
        res.status(200).json({ message: "2FA Recovery code sent." });
    } catch (error) {
        console.error("Forgot 2FA Error:", error);
        res.status(500).json({ message: "Error sending email." });
    }
});

// Verify Code & Disable 2FA
app.post('/api/auth/reset-2fa', async (req, res) => {
    const { uni_email, code } = req.body;
    try {
        const result = await pool.query(
          'SELECT reset_token, reset_token_expires FROM public."User" WHERE uni_email = $1', 
          [uni_email]
        );

        if (result.rows.length === 0) return res.status(400).json({ message: "No request found." });

        const user = result.rows[0];

        if (!user.reset_token) return res.status(400).json({ message: "No request found." });
        if (new Date() > new Date(user.reset_token_expires)) {
            await pool.query('UPDATE public."User" SET reset_token = NULL, reset_token_expires = NULL WHERE uni_email = $1', [uni_email]);
            return res.status(400).json({ message: "Code has expired." });
        }
        if (user.reset_token !== code) return res.status(400).json({ message: "Invalid code." });

        // Disable 2FA and clear token
        await pool.query(
          'UPDATE public."User" SET two_fa_enabled = false, two_fa_code = NULL, reset_token = NULL, reset_token_expires = NULL WHERE uni_email = $1', 
          [uni_email]
        );
        
        failed2FAAttempts.delete(user.u_id);

        // USING THE NEW GOOGLE API HELPER
        await sendSystemEmail(
          uni_email,
          'BSU-Trace: Your New 2FA PIN',
          `Your 2FA recovery was successful.\n\nYour NEW 2FA PIN is: ${newPin}\n\nPlease use this new PIN to log in.`
        );

        res.status(200).json({ message: "Success! Your new 2FA PIN has been sent to your email." });

        res.status(200).json({ message: "2FA has been disabled." });
    } catch (error) {
        console.error("Reset 2FA Error:", error);
        res.status(500).json({ message: "Error resetting 2FA." });
    }
});

// ==========================================
// GSO ADMIN COMPREHENSIVE DASHBOARD ENDPOINT
// ==========================================
app.get('/api/gso/:id/dashboard-data', async (req, res) => {
  const userId = req.params.id;
  const authHeader = req.headers.authorization;

  if (!authHeader) {
    return res.status(401).json({ error: 'Unauthorized access. Please log in.' });
  }

  try {
    // Resolve GSO Office ID from user mapping (defaults to 3 for General Services Office if unassigned)
    const userRes = await pool.query('SELECT o_id FROM public."User" WHERE u_id = $1', [userId]);
    if (userRes.rows.length === 0) {
      return res.status(404).json({ error: 'User not found' });
    }
    const o_id = userRes.rows[0]?.o_id || 3;

    const query = `
      SELECT DISTINCT ON (i.ini_id)
        i.ini_id, 
        i.qr_code, 
        i.title, 
        p.process_name AS form_type, 
        origin_o.office_name AS origin_office, 
        s_global.current_status AS global_status,
        COALESCE(s_office.current_status, 
          CASE 
            WHEN pd_office.time_in IS NULL THEN 'Awaiting Scan In'
            ELSE 'Pending'
          END, 'Upcoming Route'
        ) AS status,
        pd_office.time_in, 
        pd_office.time_out,
        pd_office.current_office_id,
        CASE WHEN pd_office.current_office_id = $1 AND pd_office.time_out IS NULL THEN true ELSE false END as is_at_current_office
      FROM public.initial_document i
      LEFT JOIN public.process_type p ON i.p_id = p.p_id
      LEFT JOIN public.route r ON p.r_id = r.r_id
      LEFT JOIN public.offices origin_o ON r.stop_1 = origin_o.o_id
      LEFT JOIN public.processed_document pd_office ON i.ini_id = pd_office.ini_id AND pd_office.current_office_id = $1
      LEFT JOIN public.status s_office ON pd_office.s_id = s_office.s_id
      LEFT JOIN LATERAL (
        SELECT s.current_status 
        FROM public.processed_document pd_l 
        JOIN public.status s ON pd_l.s_id = s.s_id 
        WHERE pd_l.ini_id = i.ini_id 
        ORDER BY pd_l.pd_id DESC LIMIT 1
      ) s_global ON true
      WHERE $1 IN (r.stop_1, r.stop_2, r.stop_3, r.stop_4, r.stop_5, r.stop_6, r.stop_7)
         OR EXISTS (
           SELECT 1 FROM public.processed_document past_pd 
           WHERE past_pd.ini_id = i.ini_id AND past_pd.current_office_id = $1
         )
      ORDER BY i.ini_id DESC, pd_office.pd_id DESC NULLS LAST;
    `;

    const result = await pool.query(query, [o_id]);
    const documents = result.rows;

    const completedDocs = documents.filter(d => 
      d.global_status?.toLowerCase() === 'completed' || d.status?.toLowerCase() === 'completed'
    );
    const sentBackDocs = documents.filter(d => 
      d.status?.toLowerCase() === 'action required' || d.global_status?.toLowerCase() === 'action required'
    );

    const totalMap = new Map();
    [...completedDocs, ...sentBackDocs].forEach(d => totalMap.set(d.ini_id, d));
    const total_documents = totalMap.size;

    const incoming = documents.filter(d => d.current_office_id === o_id && d.time_in === null).length;
    const pending = documents.filter(d => d.current_office_id === o_id && d.time_in !== null && d.time_out === null).length;
    const archived_action_required = sentBackDocs.length;
    const completed = completedDocs.length;

    res.status(200).json({
      metrics: {
        total_documents,
        incoming,
        pending,
        archived_action_required,
        completed
      },
      documents
    });

  } catch (error) {
    console.error('GSO Dashboard Data Error:', error);
    res.status(500).json({ error: 'Internal server error' });
  }
});
// ==========================================
// SERVER INITIALIZATION
// ==========================================
// Ensure this block is at the VERY bottom, and only appears once.
const PORT = process.env.PORT || 3000;
app.listen(PORT, () => {
  console.log(`API Server running on port ${PORT}`);

  initDatabaseListener();
});