const pool = require('./db');
const bcrypt = require('bcrypt');

async function seedInitialAdmin() {
  const username = 'admin123';
  const password = 'admin123'; // Change this to your desired initial password
  const fullName = 'System ICT Administrator';
  const email = 'ictadmin@batstate-u.edu.ph';
  const accountTypeId = 5; // 5 = ICT Admin based on your SQL dump
  const departmentId = 1;  // 1 = CICS or any valid department ID from your table
  const facultyId = 'ICT-ADMIN-01';

  try {
    // 1. Check if an admin already exists to prevent duplicates
    const checkUser = await pool.query('SELECT * FROM public."User" WHERE username = $1', [username]);
    
    if (checkUser.rows.length > 0) {
      console.log(`⚠️ Admin user '${username}' already exists. Skipping seeding.`);
      process.exit(0);
    }

    // 2. Hash the password securely
    const saltRounds = 10;
    const hashedPassword = await bcrypt.hash(password, saltRounds);

    // 3. Insert the user into the database
    const insertQuery = `
      INSERT INTO public."User" (a_id, d_id, username, password, full_name, uni_email, faculty_id)
      VALUES ($1, $2, $3, $4, $5, $6, $7)
      RETURNING u_id, username;
    `;

    const values = [accountTypeId, departmentId, username, hashedPassword, fullName, email, facultyId];
    const res = await pool.query(insertQuery, values);

    console.log('✅ Success! Initial ICT Admin account created successfully.');
    console.log(`👤 Username: ${res.rows[0].username}`);
    console.log(`🔒 Password: ${password} (Hashed in database)`);

  } catch (error) {
    console.error('❌ Error seeding the admin user:', error);
  } finally {
    // Close the database pool connection
    await pool.end();
  }
}

seedInitialAdmin();