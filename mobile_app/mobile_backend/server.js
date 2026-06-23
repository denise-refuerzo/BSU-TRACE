// ==========================================
// 1. DOCUMENTS API
// Fetches the list of documents for the DocumentsScreen
// ==========================================
app.get('/api/documents', async (req, res) => {
  try {
    // We join 5 tables here to give Flutter exactly the fields it expects:
    // title, form_type (process_name), origin_office (office_name), and status
    const query = `
      SELECT 
        d.ini_id, 
        d.title, 
        p.process_name AS form_type, 
        o.office_name AS origin_office, 
        s.current_status AS status, 
        pd.time_in AS created_at
      FROM public.initial_document d
      LEFT JOIN public.process_type p ON d.p_id = p.p_id
      LEFT JOIN public.processed_document pd ON d.ini_id = pd.ini_id
      LEFT JOIN public.offices o ON pd.current_office_id = o.o_id
      LEFT JOIN public.status s ON pd.s_id = s.s_id
      ORDER BY pd.time_in DESC;
    `;
    const result = await pool.query(query);
    res.status(200).json(result.rows);
  } catch (error) {
    console.error('Error fetching documents:', error);
    res.status(500).json({ error: 'Failed to fetch documents' });
  }
});

// ==========================================
// 2. LIVE TRACKING API
// Fetches the history/timeline of a specific document
// ==========================================
app.get('/api/tracking/:document_id', async (req, res) => {
  const { document_id } = req.params;
  try {
    const query = `
      SELECT 
        pd.pd_id,
        o.office_name,
        s.current_status,
        pd.time_in,
        pd.time_out
      FROM public.processed_document pd
      JOIN public.offices o ON pd.current_office_id = o.o_id
      JOIN public.status s ON pd.s_id = s.s_id
      WHERE pd.ini_id = $1
      ORDER BY pd.time_in ASC;
    `;
    const result = await pool.query(query, [document_id]);
    
    if (result.rows.length === 0) {
      return res.status(404).json({ error: 'No tracking history found for this document.' });
    }
    
    res.status(200).json(result.rows);
  } catch (error) {
    console.error('Error fetching tracking data:', error);
    res.status(500).json({ error: 'Failed to fetch tracking history' });
  }
});

// ==========================================
// 3. RESOURCE SCHEDULER API
// Fetches and creates calendar bookings/reservations
// ==========================================
app.get('/api/bookings', async (req, res) => {
  try {
    const query = `
      SELECT booking_id, booking_type, department, reservation_date, purpose, status 
      FROM public.bookings 
      ORDER BY reservation_date ASC;
    `;
    const result = await pool.query(query);
    res.status(200).json(result.rows);
  } catch (error) {
    console.error('Error fetching bookings:', error);
    res.status(500).json({ error: 'Failed to fetch bookings' });
  }
});

app.post('/api/bookings', async (req, res) => {
  const { u_id, booking_type, department, reservation_date, purpose } = req.body;
  try {
    const query = `
      INSERT INTO public.bookings (u_id, booking_type, department, reservation_date, purpose, status)
      VALUES ($1, $2, $3, $4, $5, 'Reserved')
      RETURNING *;
    `;
    const result = await pool.query(query, [u_id, booking_type, department, reservation_date, purpose]);
    res.status(201).json({ message: 'Booking created successfully', booking: result.rows[0] });
  } catch (error) {
    console.error('Error creating booking:', error);
    res.status(500).json({ error: 'Failed to create booking' });
  }
});