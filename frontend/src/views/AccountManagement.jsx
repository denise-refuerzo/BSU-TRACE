import React, { useState } from 'react';
import { useNavigate } from 'react-router-dom';

export default function AccountManagement() {
  const navigate = useNavigate();
  const adminName = localStorage.getItem('user') || 'Admin User';
  
  const [form, setForm] = useState({
    username: '', password: '', accountType: '', fullName: '', email: '', departmentId: ''
  });
  const [message, setMessage] = useState({ type: '', text: '' });

  const handleCreateAccount = async (e) => {
    e.preventDefault();
    setMessage({ type: '', text: '' });

    try {
      const response = await fetch('http://localhost:5000/api/accounts', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify(form)
      });
      const data = await response.json();
      
      if (!response.ok) throw new Error(data.error || 'Creation failed');

      setMessage({ type: 'success', text: data.message });
      setForm({ username: '', password: '', accountType: '', fullName: '', email: '', departmentId: '' });
    } catch (err) {
      setMessage({ type: 'error', text: err.message });
    }
  };

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
            <button className="w-full flex items-center gap-3 px-3 py-2.5 rounded-lg text-neutral-400 hover:bg-neutral-800 hover:text-white transition-colors">📊 Dashboard</button>
            <button className="w-full flex items-center gap-3 px-3 py-2.5 rounded-lg bg-neutral-800 text-white font-medium">👥 Accounts</button>
            <button className="w-full flex items-center gap-3 px-3 py-2.5 rounded-lg text-neutral-400 hover:bg-neutral-800 hover:text-white transition-colors">🛡️ Roles</button>
          </nav>
        </div>
        <button onClick={() => { localStorage.clear(); navigate('/login'); }} className="flex items-center gap-3 px-3 py-2.5 text-sm text-neutral-400 hover:text-red-400 rounded-lg transition-colors">
          🚪 Logout
        </button>
      </div>

      {/* Main Panel Frame */}
      <div className="flex-1 flex flex-col overflow-y-auto">
        {/* Top bar control */}
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

        {/* Console Workspace */}
        <main className="p-8 max-w-5xl w-full mx-auto grid grid-cols-1 lg:grid-cols-3 gap-8">
          <div className="lg:col-span-2">
            <h2 className="text-2xl font-bold tracking-tight">Account Management</h2>
            <p className="text-xs text-gray-500 mb-6">Manage university staff access and system permissions.</p>

            {/* Account Creation Block */}
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
                    <select required value={form.departmentId} onChange={e => setForm({...form, departmentId: parseInt(e.target.value)})}
                            className="w-full border border-neutral-300 bg-white rounded-lg px-3 py-2 text-sm focus:ring-1 focus:ring-red-700 outline-none">
                      <option value="">Select campus department...</option>
                      <option value="1">CICS</option>
                      <option value="2">CABEIHM</option>
                      <option value="3">CAS</option>
                      <option value="4">CIT</option>
                    </select>
                  </div>
                </div>

                <div className="flex justify-end gap-3 pt-4 border-t border-neutral-100">
                  <button type="button" onClick={() => setForm({ username: '', password: '', accountType: '', fullName: '', email: '', departmentId: '' })}
                          className="px-4 py-2 text-sm border font-medium text-gray-500 rounded-lg hover:bg-neutral-50">RESET</button>
                  <button type="submit" className="px-5 py-2 text-sm font-medium bg-red-800 text-white rounded-lg hover:bg-red-900">CREATE ACCOUNT</button>
                </div>
              </form>
            </div>
          </div>

          {/* Right Side Informational Modules */}
          <div className="space-y-6 mt-14">
            <div className="bg-[#2D1F1E] text-neutral-300 p-5 rounded-2xl shadow-sm">
              <h4 className="text-sm font-bold text-white mb-4 flex items-center gap-2">ℹ️ Role Definitions</h4>
              <div className="space-y-4 text-xs">
                <div className="p-3 bg-white/5 rounded-lg border-l-2 border-red-600"><p className="font-bold text-white">Originator:</p><p className="text-neutral-400 mt-0.5">Initializes new document workflows and drafts requests.</p></div>
                <div><p className="font-bold text-neutral-200">Processor:</p><p className="text-neutral-400 mt-0.5">Validates data entry and reviews workflow compliance.</p></div>
                <div><p className="font-bold text-neutral-200">Signee:</p><p className="text-neutral-400 mt-0.5">Final authority for digital signatures and document execution.</p></div>
              </div>
            </div>

            <div className="bg-gradient-to-br from-neutral-900 to-neutral-800 text-white p-5 rounded-2xl relative overflow-hidden">
              <div className="absolute top-0 right-0 w-32 h-32 bg-white/5 rounded-full transform translate-x-10 -translate-y-10 pointer-events-none"></div>
              <h4 className="text-sm font-bold mb-1">Security Standards</h4>
              <p className="text-[11px] text-neutral-400">All account lifecycle and tracking initialization actions are recorded for audit compliance.</p>
            </div>
          </div>
        </main>
      </div>
    </div>
  );
}