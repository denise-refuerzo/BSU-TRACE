import React, { useState, useEffect } from 'react';
import { ChevronLeft, ChevronRight, Plus, X } from 'lucide-react';
import { fetchWithAuth } from '../api';

export default function ResourceScheduler({ userId }) {
  const userName = localStorage.getItem('user') || 'Faculty User';
  
  // Tab Facility Toggle State: 'Gymnasium' | 'Multimedia Room' | 'Van'
  const [activeFacility, setActiveFacility] = useState('Gymnasium');
  
  // Domain Data States
  const [bookings, setBookings] = useState([]);
  const [inventory, setInventory] = useState([]);
  
  // Set calendar base tracking to October 2026 to align with your project data logs context
  const [currentDate, setCurrentDate] = useState(new Date(2026, 9, 1)); 
  
  // Modal Controllers
  const [showFormModal, setShowFormModal] = useState(false);
  
  // Get string representing todays current date format for strict past-date blocking checks
  const todayString = new Date().toISOString().split('T')[0];

  // Forms Tracking States
  const [form, setForm] = useState({
    reservationDate: '', purpose: '', department: 'CICS',
    startTime: '', endTime: '', expectedAttendees: '', // GM Requirements
    destination: '', passengerCount: '', serviceTypeId: '3', pickUpTime: '', dropOffTime: '' // Vehicle items
  });

  useEffect(() => {
    fetchActiveReservations();
    fetchInventoryMetrics();
  }, [activeFacility]);

  const fetchActiveReservations = async () => {
    try {
      const res = await fetchWithAuth('http://localhost:5000/api/resources/bookings');
      const data = await res.json();
      if (res.ok) setBookings(data);
    } catch (err) { console.error("Error connecting calendar rows:", err); }
  };

  const fetchInventoryMetrics = async () => {
    try {
      const res = await fetchWithAuth('http://localhost:5000/api/resources/inventory');
      const data = await res.json();
      if (res.ok) setInventory(data);
    } catch (err) { console.error(err); }
  };

  const handleBookingSubmit = async (e) => {
    e.preventDefault();
    const typeMapping = { 'Gymnasium': 'Gymnasium', 'Multimedia Room': 'Room', 'Van': 'Vehicle' };
    
    // Safety check: ensure selected time doesn't match an impossible layout frame rule
    if (activeFacility !== 'Van' && form.startTime >= form.endTime) {
      return alert("Invalid Timeline: End time must fall strictly after start time coordinates.");
    }

    const payload = {
      userId: parseInt(userId),
      bookingType: typeMapping[activeFacility],
      assetName: activeFacility,
      ...form
    };

    try {
      const res = await fetchWithAuth('http://localhost:5000/api/resources/book', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify(payload)
      });
      if (res.ok) {
        alert("🎉 Reservation successfully registered in system! Current status: Reserved.");
        setShowFormModal(false);
        // Reset form variables
        setForm({ reservationDate: '', purpose: '', department: 'CICS', startTime: '', endTime: '', expectedAttendees: '', destination: '', passengerCount: '', serviceTypeId: '3', pickUpTime: '', dropOffTime: '' });
        fetchActiveReservations();
      } else {
        const err = await res.json();
        alert(err.error || "Submission rejected.");
      }
    } catch (err) { console.error(err); }
  };

  // Calendar Render calculations
  const year = currentDate.getFullYear();
  const month = currentDate.getMonth();
  const daysInMonth = new Date(year, month + 1, 0).getDate();
  const firstDayIndex = new Date(year, month, 1).getDay();
  
  const monthNames = ["January", "February", "March", "April", "May", "June", "July", "August", "September", "October", "November", "December"];
  const calendarDays = Array.from({ length: firstDayIndex }, () => null).concat(
    Array.from({ length: daysInMonth }, (_, i) => i + 1)
  );

  return (
    <div className="space-y-6 max-w-6xl mx-auto text-left animate-in fade-in duration-150">
      
      {/* Top Section Layout Header */}
      <div className="flex flex-col sm:flex-row justify-between items-start sm:items-center gap-4">
        <div>
          <h3 className="text-2xl font-black tracking-tight text-neutral-900">Resource Scheduler</h3>
          <p className="text-xs text-neutral-400 mt-0.5">Manage institutional asset schedules and venue reservations.</p>
        </div>
        
        {/* Dynamic Facility Switching Controls */}
        <div className="bg-neutral-200/60 p-1 rounded-xl flex items-center gap-1 font-bold text-xs">
          {['Van', 'Multimedia Room', 'Gymnasium'].map((fac) => (
            <button 
              key={fac} 
              onClick={() => setActiveFacility(fac)}
              className={`px-4 py-2 rounded-lg uppercase tracking-wide transition-all ${
                activeFacility === fac ? 'bg-red-800 text-white shadow-sm' : 'text-neutral-500 hover:text-neutral-800'
              }`}
            >
              {fac === 'Van' ? '🚍 Vehicles' : fac}
            </button>
          ))}
        </div>
      </div>

      {/* ==========================================
          CALENDAR SCHEDULER VIEW MATRIX CANVAS
          ========================================== */}
      <div className="bg-white border border-neutral-200 rounded-2xl shadow-sm p-6 space-y-6">
        <div className="flex justify-between items-center">
          <div className="flex items-center gap-4">
            <h4 className="text-base font-black tracking-tight text-neutral-900">
              {activeFacility} Schedule — <span className="text-red-800">{monthNames[month]} {year}</span>
            </h4>
            
            {/* Legend Markers mapping your status requirements */}
            <div className="flex items-center gap-3 text-[10px] font-bold uppercase tracking-wider text-neutral-400">
              <span className="flex items-center gap-1"><span className="w-2.5 h-2.5 bg-red-600 rounded-sm"></span> Reserved</span>
              <span className="flex items-center gap-1"><span className="w-2.5 h-2.5 bg-green-600 rounded-sm"></span> Confirmed</span>
            </div>
          </div>
          
          <div className="flex items-center gap-3">
            <div className="flex gap-1 border rounded-lg p-1 bg-neutral-50">
              <button onClick={() => setCurrentDate(new Date(year, month - 1, 1))} className="p-1 hover:bg-white rounded transition-colors"><ChevronLeft size={16} /></button>
              <button onClick={() => setCurrentDate(new Date(year, month + 1, 1))} className="p-1 hover:bg-white rounded transition-colors"><ChevronRight size={16} /></button>
            </div>
            <button onClick={() => setShowFormModal(true)} className="px-4 py-2 bg-red-800 hover:bg-red-900 text-white font-medium text-xs rounded-xl flex items-center gap-1.5 shadow-sm transition-colors">
              <Plus size={14} /> New Request
            </button>
          </div>
        </div>

        <div className="grid grid-cols-7 gap-2 text-center text-[10px] font-black uppercase text-neutral-400 tracking-wider border-b pb-2">
          {['Sun', 'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat'].map(d => <div key={d}>{d}</div>)}
        </div>

        {/* Dynamic Days Mapping Grid */}
        <div className="grid grid-cols-7 gap-2">
          {calendarDays.map((day, index) => {
            if (!day) return <div key={index} className="bg-neutral-50/50 border border-dashed border-neutral-100 rounded-xl min-h-[110px]"></div>;
            
            const dayString = `${year}-${String(month + 1).padStart(2, '0')}-${String(day).padStart(2, '0')}`;
            const matches = bookings.filter(b => b.reservation_date.split('T')[0] === dayString && b.asset_name === activeFacility);

            return (
              <div key={index} className="bg-white border border-neutral-200 rounded-xl p-2 min-h-[110px] flex flex-col justify-between hover:border-neutral-300 transition-colors">
                <span className="text-xs font-black text-neutral-400 block self-start">{day}</span>
                <div className="flex-1 overflow-y-auto space-y-1 mt-1 max-h-[85px] scrollbar-thin">
                  {matches.map((b, idx) => {
                    // DYNAMIC STATUS COLOR MAP RULES: "Reserved" -> Crimson, "Confirmed" -> Emerald Green
                    const isConfirmed = b.status?.toLowerCase() === 'confirmed' || b.status?.toLowerCase() === 'approved';
                    
                    return (
                      <div key={idx} className={`p-1.5 rounded-lg border text-[10px] font-bold text-left leading-tight transition-colors ${
                        isConfirmed 
                          ? 'bg-green-50 border-green-200 text-green-800' 
                          : 'bg-red-50 border-red-200 text-red-800'
                      }`}>
                        <p className="truncate uppercase font-black">{b.purpose}</p>
                        <p className="text-[9px] opacity-80 mt-0.5 truncate">
                          {b.booking_type === 'Vehicle' 
                            ? `🚍 Dest: ${b.destination || 'Campus'}`
                            : `⏱️ ${b.gm_start?.substring(0,5)} - ${b.gm_end?.substring(0,5)}`
                          }
                        </p>
                        <span className="text-[8px] block opacity-60 font-medium truncate">By: {b.full_name}</span>
                      </div>
                    );
                  })}
                </div>
              </div>
            );
          })}
        </div>
      </div>

      {/* INVENTORY VIEWER CONTAINER */}
      <div className="border border-neutral-200 bg-white rounded-2xl p-6 shadow-sm">
        <h4 className="text-sm font-black uppercase tracking-wider mb-4 text-neutral-400 flex items-center gap-1.5">📊 Logistics Inventory <span className="text-[9px] px-2 py-0.5 bg-neutral-100 rounded-full font-black text-neutral-500 tracking-normal">View Only</span></h4>
        <div className="grid grid-cols-1 md:grid-cols-2 gap-4">
          {inventory.map((item) => (
            <div key={item.asd_id} className="border border-neutral-200 rounded-xl p-4 flex items-center justify-between bg-[#FDFBF9]">
              <div className="flex items-center gap-3">
                <div className="p-2.5 bg-red-50 text-red-800 rounded-xl font-bold text-xl">
                  {item.asset_name.includes('Chairs') ? '🪑' : '🪵'}
                </div>
                <div>
                  <p className="font-bold text-neutral-800 text-xs uppercase tracking-wide">{item.asset_name}</p>
                  <p className="text-[11px] text-neutral-400 mt-0.5">Quantities manually managed via GSO Admin accounts</p>
                </div>
              </div>
              <div className="text-right">
                <p className="text-2xl font-black text-neutral-900 tracking-tight">{item.quantity}</p>
                <span className="text-[10px] text-neutral-400 block font-semibold uppercase">Total Available</span>
              </div>
            </div>
          ))}
        </div>
      </div>

      {/* ==========================================
          MODAL: DYNAMIC CONDITIONAL BOOKING FORMS
          ========================================== */}
      {showFormModal && (
        <div className="fixed inset-0 bg-neutral-950/40 backdrop-blur-xs flex items-center justify-center p-4 z-50 animate-in fade-in duration-100">
          <div className="bg-white w-full max-w-lg rounded-2xl shadow-2xl border flex flex-col text-left overflow-hidden">
            <div className="p-5 border-b bg-red-800 text-white flex items-center justify-between">
              <h3 className="font-black uppercase text-sm tracking-wider">{activeFacility} Reservation</h3>
              <button onClick={() => setShowFormModal(false)} className="text-white/80 hover:text-white"><X size={18} /></button>
            </div>
            
            <form onSubmit={handleBookingSubmit} className="p-6 space-y-4 max-h-[75vh] overflow-y-auto">
              <div className="grid grid-cols-2 gap-4">
                <div>
                  <label className="block text-[10px] font-bold text-gray-400 uppercase mb-1">Requestor's Name</label>
                  <input type="text" readOnly value={userName} className="w-full border px-3 py-2 text-xs font-semibold bg-neutral-50 cursor-not-allowed text-neutral-400 rounded-lg outline-none" />
                </div>
                <div>
                  <label className="block text-[10px] font-bold text-gray-400 uppercase mb-1">Reservation Date</label>
                  {/* REQUIREMENT FIXED: Added 'min' tag restriction to isolate and block all past days */}
                  <input type="date" required min={todayString} value={form.reservationDate} onChange={e => setForm({...form, reservationDate: e.target.value})} className="w-full border px-3 py-2 text-xs rounded-lg border-neutral-300 focus:ring-1 focus:ring-red-700 outline-none bg-white" />
                </div>
              </div>

              <div className="grid grid-cols-2 gap-4">
                <div>
                  <label className="block text-[10px] font-bold text-gray-400 uppercase mb-1">Department Unit</label>
                  <select value={form.department} onChange={e => setForm({...form, department: e.target.value})} className="w-full border px-3 py-2 text-xs rounded-lg border-neutral-300 focus:ring-1 focus:ring-red-700 outline-none bg-white font-bold text-neutral-700">
                    <option value="College of Education">College of Education</option>
                    <option value="CICS Department">CICS Department</option>
                    <option value="CABEIHM">CABEIHM</option>
                    <option value="CAS Department">CAS Department</option>
                  </select>
                </div>
              </div>

              <div>
                <label className="block text-[10px] font-bold text-gray-400 uppercase mb-1">Purpose of Reservation</label>
                <textarea required rows={3} placeholder="Describe the purpose..." value={form.purpose} onChange={e => setForm({...form, purpose: e.target.value})} className="w-full border px-3 py-2 text-xs rounded-lg border-neutral-300 focus:ring-1 focus:ring-red-700 outline-none resize-none" />
              </div>

              {/* GYMNASIUM & MULTIMEDIA ROOM RENDER SCHEME BLOCK */}
              {activeFacility !== 'Van' ? (
                <div className="space-y-4 pt-2 border-t border-dashed border-neutral-200 animate-in fade-in">
                  <div className="grid grid-cols-2 gap-4">
                    <div>
                      <label className="block text-[10px] font-bold text-gray-400 uppercase mb-1">Start Time</label>
                      <input type="time" required value={form.startTime} onChange={e => setForm({...form, startTime: e.target.value})} className="w-full border px-3 py-2 text-xs rounded-lg border-neutral-300 outline-none bg-white" />
                    </div>
                    <div>
                      <label className="block text-[10px] font-bold text-gray-400 uppercase mb-1">End Time</label>
                      <input type="time" required value={form.endTime} onChange={e => setForm({...form, endTime: e.target.value})} className="w-full border px-3 py-2 text-xs rounded-lg border-neutral-300 outline-none bg-white" />
                    </div>
                  </div>
                  <div>
                    <label className="block text-[10px] font-bold text-gray-400 uppercase mb-1">Expected Attendance</label>
                    <input type="number" required placeholder="Estimated headcount" value={form.expectedAttendees} onChange={e => setForm({...form, expectedAttendees: e.target.value})} className="w-full border px-3 py-2 text-xs rounded-lg border-neutral-300 outline-none bg-white" />
                  </div>
                </div>
              ) : (
                /* VEHICLE RENDER SCHEME BLOCK */
                <div className="space-y-4 pt-2 border-t border-dashed border-neutral-200 animate-in fade-in">
                  <div className="grid grid-cols-2 gap-4">
                    <div>
                      <label className="block text-[10px] font-bold text-gray-400 uppercase mb-1">Destination Target</label>
                      <input type="text" required placeholder="e.g., BatStateU Main Campus" value={form.destination} onChange={e => setForm({...form, destination: e.target.value})} className="w-full border px-3 py-2 text-xs rounded-lg border-neutral-300 outline-none bg-white" />
                    </div>
                    <div>
                      <label className="block text-[10px] font-bold text-gray-400 uppercase mb-1">Passenger Count</label>
                      <input type="number" required placeholder="e.g., 12" value={form.passengerCount} onChange={e => setForm({...form, passengerCount: e.target.value})} className="w-full border px-3 py-2 text-xs rounded-lg border-neutral-300 outline-none bg-white" />
                    </div>
                  </div>
                  
                  <div>
                    <label className="block text-[10px] font-bold text-gray-400 uppercase mb-1">Service Type</label>
                    <div className="flex gap-4 items-center text-xs font-bold text-neutral-600 mt-2">
                      {[{ id: '1', l: 'Pick-up' }, { id: '2', l: 'Drop-off' }, { id: '3', l: 'Both' }].map(s => (
                        <label key={s.id} className="flex items-center gap-1.5 cursor-pointer">
                          <input type="radio" name="srv" checked={form.serviceTypeId === s.id} onChange={() => setForm({...form, serviceTypeId: s.id})} className="text-red-800 focus:ring-red-700" />
                          {s.l}
                        </label>
                      ))}
                    </div>
                  </div>

                  <div className="grid grid-cols-2 gap-4">
                    <div>
                      <label className="block text-[10px] font-bold text-gray-400 uppercase mb-1">Pick-up Time</label>
                      {/* REQUIREMENT FIXED: Disables input conditionally based on active radio choices */}
                      <input 
                        type="time" 
                        required={form.serviceTypeId === '1' || form.serviceTypeId === '3'} 
                        disabled={form.serviceTypeId === '2'} 
                        value={form.pickUpTime} 
                        onChange={e => setForm({...form, pickUpTime: e.target.value})} 
                        className={`w-full border px-3 py-2 text-xs rounded-lg outline-none transition-all ${
                          form.serviceTypeId === '2' ? 'bg-neutral-100 text-neutral-400 border-neutral-200 cursor-not-allowed' : 'bg-white border-neutral-300'
                        }`} 
                      />
                    </div>
                    <div>
                      <label className="block text-[10px] font-bold text-gray-400 uppercase mb-1">Drop-off Time</label>
                      <input 
                        type="time" 
                        required={form.serviceTypeId === '2' || form.serviceTypeId === '3'} 
                        disabled={form.serviceTypeId === '1'} 
                        value={form.dropOffTime} 
                        onChange={e => setForm({...form, dropOffTime: e.target.value})} 
                        className={`w-full border px-3 py-2 text-xs rounded-lg outline-none transition-all ${
                          form.serviceTypeId === '1' ? 'bg-neutral-100 text-neutral-400 border-neutral-200 cursor-not-allowed' : 'bg-white border-neutral-300'
                        }`} 
                      />
                    </div>
                  </div>
                </div>
              )}

              <div className="flex items-start gap-2.5 pt-3">
                <input type="checkbox" id="resConfirm" required className="mt-0.5 rounded text-red-800 focus:ring-red-700 w-3.5 h-3.5" />
                <label htmlFor="resConfirm" className="text-[11px] text-gray-400 leading-tight">
                  I verify that all information provided is accurate and I agree to follow the institutional resource usage policies.
                </label>
              </div>

              <div className="flex justify-end gap-2.5 pt-4 border-t border-neutral-100">
                <button type="button" onClick={() => setShowFormModal(false)} className="px-4 py-2 border font-bold text-gray-500 text-xs rounded-lg hover:bg-neutral-50">Cancel</button>
                <button type="submit" className="px-5 py-2 font-bold bg-red-800 hover:bg-red-900 text-white text-xs rounded-lg">Submit Request</button>
              </div>
            </form>
          </div>
        </div>
      )}

    </div>
  );
}