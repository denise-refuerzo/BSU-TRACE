const express = require('express');
const bcrypt = require('bcrypt');
const { Pool } = require('pg');

const app = express();

// --- THE FIX: Accept both JSON and Flutter's default Form Data ---
app.use(express.json());
app.use(express.urlencoded({ extended: true }));

const pool = new Pool({
  connectionString: process.env.DATABASE_URL,
  ssl: { rejectUnauthorized: false }
});

app.post('/api/login', async (req, res) => {
  console.log("=====================================");
  console.log("🚨 INCOMING LOGIN ATTEMPT 🚨");
  console.log("Data received from Flutter:", req.body);
  
  const { username, password, role } = req.body;

  if (!username || !password || !role) {
    console.log("❌ ERROR: Missing fields. Did the app send them correctly?");
    return res.status(400).json({ error: 'Missing fields' });
  }

  try {
    const userQuery = await pool.query(
      'SELECT * FROM public."User" WHERE username = $1 OR uni_email = $1',
      [username]
    );

    if (userQuery.rows.length === 0) {
      console.log(`❌ ERROR: Could not find username or email '${username}' in Neon DB.`);
      return res.status(401).json({ error: 'User not found' });
    }

    const user = userQuery.rows[0];
    console.log(`✅ User found in DB: ${user.username}`);

    const isMatch = await bcrypt.compare(password, user.password);

    if (!isMatch) {
      console.log(`❌ ERROR: The password typed (${password}) DOES NOT MATCH the hash in the DB (${user.password}).`);
      return res.status(401).json({ error: 'Incorrect password' });
    }
    console.log("✅ Password matches perfectly!");

    const roleMap = { 'user': 1, 'processor': 2, 'signee': 3, 'admin': 4, 'ictAdmin': 5 };
    
    if (user.a_id !== roleMap[role]) {
      console.log(`❌ ERROR: Role mismatch. User has a_id ${user.a_id}, but tried to log in as '${role}' (expects ${roleMap[role]}).`);
      return res.status(403).json({ error: 'Unauthorized role selected' });
    }

    console.log("🎉 SUCCESS: Sending approval back to Flutter!");
    console.log("=====================================");
    return res.status(200).json({
      message: 'Login successful',
      a_id: user.a_id,
      u_id: user.u_id
    });

  } catch (error) {
    console.error('🔥 CRITICAL DATABASE ERROR:', error);
    return res.status(500).json({ error: 'Server error' });
  }
});

const PORT = process.env.PORT || 3000;
app.listen(PORT, () => console.log(`🚀 API Live and listening on port ${PORT}`));