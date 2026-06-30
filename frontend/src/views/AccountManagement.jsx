import React, { useState, useEffect } from 'react';
import { useNavigate } from 'react-router-dom';
import Swal from 'sweetalert2'; // 🚨 SweetAlert2 handles explicit double-check confirmations

export default function AccountManagement() {
  const navigate = useNavigate();
  const adminName = localStorage.getItem('user') || 'Admin User';
  
  // Tab control state: toggles view smoothly between registry table and creation form
  const [activeTab, setActiveTab] = useState('registry');

  // --- REGISTRATION FORM STATES (COMPLETELY PRESERVED) ---
  const [form, setForm] = useState({
    username: '', password: '', accountType: '', fullName: '', email: '', departmentId: '', officeId: ''
  });
  const [message, setMessage] = useState({ type: '', text: '' });
  const [offices, setOffices] = useState([]);

  // --- ADVANCED MANAGEMENT REGISTRY STATES ---
  const [accounts, setAccounts] = useState([]);
  const [searchTerm, setSearchTerm] = useState('');
  const [roleFilter, setRoleFilter] = useState('');
  const [selectedUser, setSelectedUser] = useState(null); // Tracks account loaded into editing modal

  // Sync baseline lookup catalogs upon initial component mount
  useEffect(() => {
    fetchOffices();
    fetchAccounts();
  }, []);

  const fetchOffices = async () => {
    try {
      const res = await fetch('http://localhost:5000/api/offices');
      const data = await res.json();
      if (res.ok) setOffices(data);
    } catch (err) {
      console.error("Failed building office catalog options drop down:", err);
    }
  };

  const fetchAccounts = async () => {
    try {
      const res = await fetch('http://localhost:5000/api/accounts');
      const data = await res.json();
      if (res.ok) setAccounts(data);
    } catch (err) {
      console.error("Error fetching institutional accounts catalog ledger:", err);
    }
  };

  // --- ACCOUNT CREATION SUBMISSION ---
  const handleCreateAccount = async (e) => {
    e.preventDefault();
    setMessage({ type: '', text: '' });

    const submissionFormPayload = { ...form };
    if (form.accountType !== 2 && form.accountType !== 3) {
      submissionFormPayload.officeId = null;
    }

    try {
      const response = await fetch('http://localhost:5000/api/accounts', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify(submissionFormPayload)
      });
      const data = await response.json();
      
      if (!response.ok) throw new Error(data.error || 'Creation failed');

      setMessage({ type: 'success', text: data.message });
      setForm({ username: '', password: '', accountType: '', fullName: '', email: '', departmentId: '', officeId: '' });
      fetchAccounts(); // Silent refresh of registry data cache
    } catch (err) {
      setMessage({ type: 'error', text: err.message });
    }
  };

  // --- MODIFICATION HANDLER BACKED BY SWEETALERT2 VERIFICATION ---
  const handleUpdateAccount = async (e) => {
    e.preventDefault();

    Swal.fire({
      title: 'Verify Profile Changes?',
      text: `Are you sure you want to alter parameters for ${selectedUser.full_name}? This overwrites core credentials across university system tables.`,
      icon: 'warning',
      showCancelButton: true,
      confirmButtonColor: '#800000',
      cancelButtonColor: '#4b5563',
      confirmButtonText: 'Yes, Apply Synchronization',
      cancelButtonText: 'Abort Changes'
    }).then(async (result) => {
      if (result.isConfirmed) {
        try {
          const response = await fetch(`http://localhost:5000/api/accounts/${selectedUser.u_id}`, {
            method: 'PUT',
            headers: { 'Content-Type': 'application/json' },
            body: JSON.stringify({
              username: selectedUser.username,
              fullName: selectedUser.full_name,
              email: selectedUser.uni_email,
              accountType: selectedUser.a_id,
              departmentId: selectedUser.d_id,
              officeId: selectedUser.o_id,
              isActive: selectedUser.is_active // 🟢 Passed soft active state toggle to backend schema query maps
            })
          });
          const data = await response.json();

          if (!response.ok) throw new Error(data.error || 'Synchronization update failure.');

          Swal.fire('Synchronized!', 'Personnel access profiles updated cleanly.', 'success');
          setSelectedUser(null); // Terminate modal context view
          fetchAccounts(); // Pull active changes straight from storage nodes
        } catch (err) {
          Swal.fire('Operational Fault', err.message, 'error');
        }
      }
    });
  };

  // Filter computation logic processing locally cached state arrays on the fly
  const filteredAccounts = accounts.filter(acc => {
    const matchesSearch = acc.full_name.toLowerCase().includes(searchTerm.toLowerCase()) || 
                          acc.username.toLowerCase().includes(searchTerm.toLowerCase()) ||
                          acc.uni_email.toLowerCase().includes(searchTerm.toLowerCase());
    const matchesRole = roleFilter === '' || acc.a_id === parseInt(roleFilter);
    return matchesSearch && matchesRole;
  });

  return (
    <div className="flex h-screen w-screen bg-[#FDFBF9] overflow-hidden text-neutral-800 font-sans">
      {/* Sidebar Navigation */}
      <div className="w-64 bg-[#2D1F1E] text-neutral-300 flex flex-col justify-between p-4">
        <div>
          <div className="flex items-center gap-3 border-b border-neutral-700 pb-4 mb-6">
            <div className="bg-red-700 p-2 rounded-lg text-white text-xl">🎓</div>
            <div>
              <h1 className="font-bold text-white text-sm leading-none">BSU Portal</h1>
              <span className="text-[10px] text-neutral-400 uppercase tracking-widest">Admin Console</span>
            </div>
          </div>
          <nav className="space-y-1 text-sm">
            <button type="button" className="w-full flex items-center gap-3 px-3 py-2.5 rounded-lg text-neutral-400 hover:bg-neutral-800 hover:text-white transition-colors">📊 Dashboard</button>
            <button type="button" className="w-full flex items-center gap-3 px-3 py-2.5 rounded-lg bg-neutral-800 text-white font-medium">👥 Accounts</button>
            <button type="button" className="w-full flex items-center gap-3 px-3 py-2.5 rounded-lg text-neutral-400 hover:bg-neutral-800 hover:text-white transition-colors">🛡️ Roles</button>
          </nav>
        </div>
        <button type="button" onClick={() => { localStorage.clear(); navigate('/login'); }} className="flex items-center gap-3 px-3 py-2.5 text-sm text-neutral-400 hover:text-red-400 rounded-lg transition-colors">
          🚪 Logout
        </button>
      </div>

      {/* Main Panel Frame */}
      <div className="flex-1 flex flex-col overflow-y-auto">
        <header className="h-16 border-b border-neutral-200/80 bg-white px-8 flex items-center justify-between shadow-sm">
          <div className="text-neutral-400 text-sm">🔍 Search dashboard...</div>
          <div className="flex items-center gap-4 text-xs">
            <span className="text-xl">🔔</span>
            <span className="text-xl">⚙️</span>
            <div className="flex items-center gap-2 border-l pl-4 border-neutral-200">
              <div className="text-right">
                <p className="font-bold text-neutral-900">{adminName}</p>
                <p className="text-[10px] text-gray-400 uppercase">System Manager</p>
              </div>
              <div className="w-8 h-8 rounded-full bg-neutral-200 border flex items-center justify-center font-bold text-neutral-600">A</div>
            </div>
          </div>
        </header>

        {/* Console Workspace Layout */}
        <main className="p-8 max-w-5xl w-full mx-auto grid grid-cols-1 lg:grid-cols-3 gap-8">
          <div className="lg:col-span-2">
            <h2 className="text-2xl font-bold tracking-tight">Account Management</h2>
            <p className="text-xs text-gray-500 mb-6">Manage university staff access and system permissions.</p>

            {/* TAB SELECTOR CONTROL BAR */}
            <div className="flex border-b border-neutral-200 mb-6 gap-2">
              <button 
                type="button"
                onClick={() => setActiveTab('registry')}
                className={`px-4 py-2 text-xs font-bold uppercase tracking-wider border-b-2 transition-all ${activeTab === 'registry' ? 'border-red-800 text-red-800' : 'border-transparent text-gray-400 hover:text-neutral-700'}`}
              >
                📋 Accounts Registry Table
              </button>
              <button 
                type="button"
                onClick={() => setActiveTab('create')}
                className={`px-4 py-2 text-xs font-bold uppercase tracking-wider border-b-2 transition-all ${activeTab === 'create' ? 'border-red-800 text-red-800' : 'border-transparent text-gray-400 hover:text-neutral-700'}`}
              >
                ➕ Create New Account
              </button>
            </div>

            {/* PANEL CONTEXT 1: ACCOUNTS REGISTRY TABLE */}
            {activeTab === 'registry' && (
              <div className="space-y-4">
                <div className="flex gap-3 grid grid-cols-3 bg-white p-3 border border-neutral-200/80 rounded-xl shadow-xs">
                  <input 
                    type="text" placeholder="Search registry records..." value={searchTerm}
                    onChange={e => setSearchTerm(e.target.value)}
                    className="col-span-2 text-xs border border-neutral-300 rounded-lg px-3 py-2 outline-none focus:ring-1 focus:ring-red-700 bg-[#FDFBF9]"
                  />
                  <select 
                    value={roleFilter} onChange={e => setRoleFilter(e.target.value)}
                    className="text-xs border border-neutral-300 bg-white rounded-lg px-2 py-2 outline-none"
                  >
                    <option value="">All Roles</option>
                    <option value="1">Originator</option>
                    <option value="2">Processor</option>
                    <option value="3">Signee</option>
                    <option value="4">GSO Admin</option>
                    <option value="5">ICT Admin</option>
                  </select>
                </div>

                {/* SCROLL CONTAINER (max height maps ~6 rows max footprint layout wrapper) */}
                <div className="bg-white border border-neutral-200 rounded-xl overflow-hidden shadow-sm max-h-[362px] overflow-y-auto">
                  <table className="w-full text-left border-collapse text-xs relative">
                    <thead className="sticky top-0 bg-neutral-50 z-10 shadow-xs">
                      <tr className="text-neutral-500 font-bold border-b border-neutral-200 uppercase tracking-wider text-[10px]">
                        <th className="p-3">User Profile / Info</th>
                        <th className="p-3">Role</th>
                        <th className="p-3">Station / Scope Location</th>
                        <th className="p-3 text-center">Actions</th>
                      </tr>
                    </thead>
                    <tbody className="divide-y divide-neutral-100 font-medium">
                      {filteredAccounts.map((user) => (
                        <tr key={user.u_id} className={`transition-colors ${user.is_active === false ? 'bg-neutral-100/70 opacity-60 italic' : 'hover:bg-neutral-50/50'}`}>
                          <td className="p-3">
                            <p className="font-bold text-neutral-900">{user.full_name} {user.is_active === false && <span className="text-[10px] text-red-700 ml-1 font-mono font-bold uppercase">[Suspended]</span>}</p>
                            <p className="text-[11px] text-gray-400">@{user.username} | {user.uni_email}</p>
                          </td>
                          <td className="p-3">
                            <span className={`px-2 py-0.5 rounded-full font-bold text-[10px] uppercase ${
                              user.a_id === 5 ? 'bg-purple-100 text-purple-700' :
                              user.a_id === 3 ? 'bg-amber-100 text-amber-700' :
                              user.a_id === 2 ? 'bg-blue-100 text-blue-700' : 'bg-gray-100 text-gray-700'
                            }`}>
                              {user.role_name}
                            </span>
                          </td>
                          <td className="p-3 text-gray-500">
                            {user.office_name ? (
                              <span className="text-red-800 font-semibold font-sans">🏬 {user.office_name}</span>
                            ) : (
                              <span>📁 Dept: {user.department_name}</span>
                            )}
                          </td>
                          <td className="p-3 text-center">
                            <button 
                              type="button"
                              onClick={() => setSelectedUser({ ...user })}
                              className="px-3 py-1 bg-neutral-900 text-white font-bold rounded-md hover:bg-red-800 transition-all text-[11px] cursor-pointer"
                            >
                              ⚙️ MANAGE
                            </button>
                          </td>
                        </tr>
                      ))}
                    </tbody>
                  </table>
                </div>
              </div>
            )}

            {/* PANEL CONTEXT 2: CREATE BLOCK */}
            {activeTab === 'create' && (
              <div className="bg-white border border-neutral-200/80 rounded-2xl p-6 shadow-sm">
                <h3 className="text-base font-bold mb-1 text-neutral-900">Create New Account</h3>
                <p className="text-xs text-gray-400 mb-6">Enter credentials and assign institutional roles</p>

                {message.text && (
                  <div className={`mb-4 p-3 rounded-lg text-xs border ${message.type === 'success' ? 'bg-green-50 border-green-200 text-green-700' : 'bg-red-50 border-red-200 text-red-700'}`}>
                    {message.text}
                  </div>
                )}

                <form onSubmit={handleCreateAccount} className="space-y-4">
                  <div className="grid grid-cols-2 gap-4">
                    <div>
                      <label className="block text-[11px] font-bold text-gray-500 uppercase mb-1">Full Name</label>
                      <input type="text" required value={form.fullName} onChange={e => setForm({...form, fullName: e.target.value})}
                             className="w-full border border-neutral-300 rounded-lg px-3 py-2 text-sm focus:ring-1 focus:ring-red-700 outline-none" placeholder="Juan Dela Cruz" />
                    </div>
                    <div>
                      <label className="block text-[11px] font-bold text-gray-500 uppercase mb-1">University Email</label>
                      <input type="email" required value={form.email} onChange={e => setForm({...form, email: e.target.value})}
                             className="w-full border border-neutral-300 rounded-lg px-3 py-2 text-sm focus:ring-1 focus:ring-red-700 outline-none" placeholder="juan.delacruz@batstate-u.edu.ph" />
                    </div>
                  </div>

                  <div className="grid grid-cols-2 gap-4">
                    <div>
                      <label className="block text-[11px] font-bold text-gray-500 uppercase mb-1">Username</label>
                      <input type="text" required value={form.username} onChange={e => setForm({...form, username: e.target.value})}
                             className="w-full border border-neutral-300 rounded-lg px-3 py-2 text-sm focus:ring-1 focus:ring-red-700 outline-none" placeholder="j_delacruz" />
                    </div>
                    <div>
                      <label className="block text-[11px] font-bold text-gray-500 uppercase mb-1">Password</label>
                      <input type="password" required value={form.password} onChange={e => setForm({...form, password: e.target.value})}
                             className="w-full border border-neutral-300 rounded-lg px-3 py-2 text-sm focus:ring-1 focus:ring-red-700 outline-none" placeholder="••••••••••••" />
                    </div>
                  </div>

                  <div className="grid grid-cols-2 gap-4">
                    <div>
                      <label className="block text-[11px] font-bold text-gray-500 uppercase mb-1">Account Type (Role)</label>
                      <select required value={form.accountType} onChange={e => setForm({...form, accountType: parseInt(e.target.value)})}
                              className="w-full border border-neutral-300 bg-white rounded-lg px-3 py-2 text-sm focus:ring-1 focus:ring-red-700 outline-none">
                        <option value="">Select assigned role...</option>
                        <option value="1">Originator</option>
                        <option value="2">Processor</option>
                        <option value="3">Signee</option>
                        <option value="4">GSO Admin</option>
                      </select>
                    </div>
                    <div>
                      <label className="block text-[11px] font-bold text-gray-500 uppercase mb-1">Department Scope</label>
                      <select 
                        required={form.accountType !== 2 && form.accountType !== 3} value={form.departmentId} 
                        onChange={e => setForm({...form, departmentId: e.target.value ? parseInt(e.target.value) : ''})}
                        className="w-full border border-neutral-300 bg-white rounded-lg px-3 py-2 text-sm focus:ring-1 focus:ring-red-700 outline-none"
                      >
                        <option value="">Select campus department (Optional for Processors/Signees)...</option>
                        <option value="1">CICS</option>
                        <option value="2">CABEIHM</option>
                        <option value="3">CAS</option>
                        <option value="4">CIT</option>
                      </select>
                    </div>
                  </div>

                  {(form.accountType === 2 || form.accountType === 3) && (
                    <div className="animate-in fade-in slide-in-from-top-2 duration-200">
                      <label className="block text-[11px] font-black text-red-800 uppercase mb-1 tracking-wider">Assigned Office Workspace (Required for routing)</label>
                      <select 
                        required value={form.officeId} onChange={e => setForm({...form, officeId: parseInt(e.target.value)})}
                        className="w-full border-2 border-red-200 bg-white rounded-lg px-3 py-2.5 text-sm focus:ring-1 focus:ring-red-700 outline-none font-semibold text-neutral-700 cursor-pointer shadow-xs"
                      >
                        <option value="">-- Choose Assigned Campus Branch Office Stop --</option>
                        {offices.map((off) => (
                          <option key={off.id} value={off.id}>{off.name}</option>
                        ))}
                      </select>
                    </div>
                  )}

                  <div className="flex justify-end gap-3 pt-4 border-t border-neutral-100">
                    <button type="button" onClick={() => setForm({ username: '', password: '', accountType: '', fullName: '', email: '', departmentId: '', officeId: '' })}
                            className="px-4 py-2 text-sm border font-medium text-gray-500 rounded-lg hover:bg-neutral-50">RESET</button>
                    <button type="submit" className="px-5 py-2 text-sm font-medium bg-red-800 text-white rounded-lg hover:bg-red-900">CREATE ACCOUNT</button>
                  </div>
                </form>
              </div>
            )}
          </div>

          <div className="space-y-6 mt-14">
            <div className="bg-[#2D1F1E] text-neutral-300 p-5 rounded-2xl shadow-sm">
              <h4 className="text-sm font-bold text-white mb-4 flex items-center gap-2">ℹ️ Role Definitions</h4>
              <div className="space-y-4 text-xs">
                <div className="p-3 bg-white/5 rounded-lg border-l-2 border-red-600"><p className="font-bold text-white">Originator:</p><p className="text-neutral-400 mt-0.5">Initializes new document workflows and drafts requests.</p></div>
                <div className="p-3 bg-white/5 rounded-lg border-l-2 border-amber-500"><p className="font-bold text-white">Processor:</p><p className="text-neutral-400 mt-0.5">Validates data entry, handles scan arrivals/releases, and routes ad-hoc workflows inside an assigned office destination.</p></div>
                <div className="p-3 bg-white/5 rounded-lg border-l-2 border-purple-500"><p className="font-bold text-white">Signee:</p><p className="text-neutral-400 mt-0.5">Final authority within an assigned office branch with access privileges to evaluate, sign, or reject active document states.</p></div>
              </div>
            </div>
          </div>
        </main>
      </div>

      {/* OVERRIDE MANAGEMENT MODAL SHEET */}
      {selectedUser && (
        <div className="fixed inset-0 z-50 bg-neutral-950/60 backdrop-blur-xs flex items-center justify-center p-4 overflow-y-auto">
          <div className="bg-white border border-neutral-200 max-w-lg w-full rounded-2xl p-6 shadow-2xl animate-in fade-in zoom-in-95 duration-150">
            <div className="flex justify-between items-center border-b border-neutral-100 pb-3 mb-4">
              <div>
                <h3 className="text-base font-black text-neutral-900">Manage Operational Profile</h3>
                <p className="text-[11px] text-gray-400">System Parameter Re-indexing Node (u_id: {selectedUser.u_id})</p>
              </div>
              <button type="button" onClick={() => setSelectedUser(null)} className="text-gray-400 hover:text-neutral-800 text-lg p-1 cursor-pointer">✕</button>
            </div>

            <form onSubmit={handleUpdateAccount} className="space-y-4 text-xs font-semibold">
              <div>
                <label className="block text-[10px] uppercase text-gray-400 font-bold mb-1 tracking-wider text-red-800 font-black">System Username Identifier</label>
                <input 
                  type="text" required value={selectedUser.username}
                  onChange={e => setSelectedUser({...selectedUser, username: e.target.value.trim()})}
                  className="w-full border-2 border-red-50 bg-white font-mono font-bold text-neutral-700 rounded-lg px-3 py-2 text-sm outline-none focus:border-red-700"
                />
              </div>

              <div>
                <label className="block text-[10px] uppercase text-gray-400 font-bold mb-1">Personnel Full Name</label>
                <input 
                  type="text" required value={selectedUser.full_name}
                  onChange={e => setSelectedUser({...selectedUser, full_name: e.target.value})}
                  className="w-full border border-neutral-300 rounded-lg px-3 py-2 text-sm outline-none"
                />
              </div>

              <div>
                <label className="block text-[10px] uppercase text-gray-400 font-bold mb-1">Institutional Notification Email</label>
                <input 
                  type="email" required value={selectedUser.uni_email}
                  onChange={e => setSelectedUser({...selectedUser, uni_email: e.target.value})}
                  className="w-full border border-neutral-300 rounded-lg px-3 py-2 text-sm outline-none"
                />
              </div>

              <div className="grid grid-cols-2 gap-4">
                <div>
                  <label className="block text-[10px] uppercase text-gray-400 font-bold mb-1">System Privilege Level</label>
                  <select 
                    value={selectedUser.a_id}
                    onChange={e => setSelectedUser({...selectedUser, a_id: parseInt(e.target.value)})}
                    className="w-full border border-neutral-300 bg-white rounded-lg px-2 py-2 outline-none"
                  >
                    <option value="1">Originator</option>
                    <option value="2">Processor</option>
                    <option value="3">Signee</option>
                    <option value="4">GSO Admin</option>
                    <option value="5">ICT Admin</option>
                  </select>
                </div>

                <div>
                  <label className="block text-[10px] uppercase text-gray-400 font-bold mb-1">Department Sector Linkage</label>
                  <select 
                    value={selectedUser.d_id}
                    onChange={e => setSelectedUser({...selectedUser, d_id: parseInt(e.target.value)})}
                    className="w-full border border-neutral-300 bg-white rounded-lg px-2 py-2 outline-none"
                  >
                    <option value="1">CICS</option>
                    <option value="2">CABEIHM</option>
                    <option value="3">CAS</option>
                    <option value="4">CIT</option>
                  </select>
                </div>
              </div>

              {(selectedUser.a_id === 2 || selectedUser.a_id === 3) && (
                <div className="p-3 bg-red-50 border border-red-100 rounded-xl">
                  <label className="block text-[10px] uppercase text-red-800 font-black mb-1">Assigned Branch Destination Office Block</label>
                  <select 
                    required value={selectedUser.o_id || ''}
                    onChange={e => setSelectedUser({...selectedUser, o_id: e.target.value ? parseInt(e.target.value) : null})}
                    className="w-full border border-neutral-300 bg-white rounded-lg px-2 py-2 font-bold outline-none text-neutral-700"
                  >
                    <option value="">-- No Location Assigned --</option>
                    {offices.map((off) => (
                      <option key={off.id} value={off.id}>{off.name}</option>
                    ))}
                  </select>
                </div>
              )}

              {/* 🔒 READ-ONLY ZERO KNOWLEDGE 2FA AUDIT SHEET */}
              <div className="bg-neutral-50 p-3.5 rounded-xl border border-neutral-200">
                <label className="block text-[10px] uppercase text-gray-400 font-bold mb-2 tracking-wider">Multi-Factor Authentication Status Audit</label>
                {selectedUser.two_fa_enabled ? (
                  <div className="text-[11px] text-emerald-800 font-bold bg-emerald-50 border border-emerald-200/60 p-2.5 rounded-lg flex items-center gap-2">
                    <span>🔒</span>
                    <div>
                      <p className="leading-tight">MFA Protection Enforced</p>
                      <p className="text-[9px] text-emerald-600 font-normal mt-0.5">Cryptographic zero-knowledge lock active. Status cannot be modified by administrators.</p>
                    </div>
                  </div>
                ) : (
                  <div className="text-[11px] text-amber-800 font-bold bg-amber-50 border border-amber-200/60 p-2.5 rounded-lg flex items-center gap-2">
                    <span>⚠️</span>
                    <div>
                      <p className="leading-tight">MFA Protection Inactive</p>
                      <p className="text-[9px] text-amber-600 font-normal mt-0.5">This profile has not activated secondary login verification keys yet.</p>
                    </div>
                  </div>
                )}
              </div>

              {/* 🟢 NEW SOFT DEACTIVATION MANAGED SYSTEM TOGGLE ELEMENT */}
              <div className="bg-neutral-50 p-3.5 rounded-xl border border-neutral-200 flex items-center justify-between">
                <div>
                  <label className="block text-xs font-bold text-neutral-700 select-none">Account Access Status</label>
                  <p className="text-[10px] text-gray-400 font-normal leading-tight mt-0.5">Deactivating suspends profile login privileges without bricking core historical logs tracking links.</p>
                </div>
                <button
                  type="button"
                  onClick={() => setSelectedUser({ ...selectedUser, is_active: !selectedUser.is_active })}
                  className={`px-4 py-1.5 rounded-lg text-[11px] font-black uppercase transition-all shadow-xs cursor-pointer ${
                    selectedUser.is_active || selectedUser.is_active === undefined
                      ? 'bg-emerald-100 text-emerald-800 hover:bg-emerald-200 border border-emerald-300' 
                      : 'bg-red-100 text-red-800 hover:bg-red-200 border border-red-300'
                  }`}
                >
                  {selectedUser.is_active || selectedUser.is_active === undefined ? "🟢 Active" : "🔴 Suspended"}
                </button>
              </div>

              <div className="flex justify-end gap-2 pt-3 border-t border-neutral-100">
                <button type="button" onClick={() => setSelectedUser(null)} className="px-4 py-2 border text-gray-500 rounded-lg hover:bg-neutral-50 font-bold transition-all">CANCEL</button>
                <button type="submit" className="px-5 py-2 bg-red-800 text-white rounded-lg hover:bg-red-900 font-bold transition-all">SAVE OVERRIDES</button>
              </div>
            </form>
          </div>
        </div>
      )}
    </div>
  );
}