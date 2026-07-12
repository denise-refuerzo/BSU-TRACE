import React, { useState, useEffect, useRef } from 'react';
import { useNavigate } from 'react-router-dom';
import { LayoutDashboard, FileText, School, Bell, User, Plus, Search, Filter, X, QrCode, ChevronLeft, ChevronRight } from 'lucide-react';
import DocumentsHub from './DocumentsHub';
import ResourceScheduler from './ResourceScheduler';
import { fetchWithAuth } from '../api';

export default function OriginatorDashboard() {
  const navigate = useNavigate();
  const notificationRef = useRef(null);
  
  const userId = localStorage.getItem('userId');
  const userName = localStorage.getItem('user') || 'Faculty User';
  
  const [activeTab, setActiveTab] = useState('dashboard');
  
  const [documents, setDocuments] = useState([]);
  const [processTypes, setProcessTypes] = useState([]);
  const [search, setSearch] = useState('');
  const [filterStatus, setFilterStatus] = useState('All');
  
  // Pagination State for Dashboard Ledger
  const [currentPage, setCurrentPage] = useState(1);
  const itemsPerPage = 5;

  const [showNotifications, setShowNotifications] = useState(false);
  const [notifications, setNotifications] = useState([]);
  
  const [profile, setProfile] = useState({
    fullName: userName,
    email: 'faculty@batstate-u.edu.ph',
    facultyId: '2024-FAC-1029',
    departmentName: 'CICS Department',
    accountType: 'Faculty User',
    twoFaEnabled: false,
    twoFaCode: ''
  });
  
  const [initialProfile, setInitialProfile] = useState(null);
  
  const [showModal, setShowModal] = useState(false);
  const [showQrModal, setShowQrModal] = useState(false);
  const [showPassModal, setShowPassModal] = useState(false);
  const [generatedQr, setGeneratedQr] = useState('');
  
  const [form, setForm] = useState({ title: '', processTypeId: '', confirmation: false });
  const [passForm, setPassForm] = useState({ currentPassword: '', newPassword: '', confirmNew: '' });
  const [selectedRoutePreview, setSelectedRoutePreview] = useState([]);
  const [estimatedDate, setEstimatedDate] = useState('');
  const [statusMsg, setStatusMsg] = useState('');

  const [recentDocStops, setRecentDocStops] = useState([]);

  useEffect(() => {
    if (!userId || userId === 'undefined') {
      localStorage.clear();
      navigate('/login');
      return;
    }
    fetchDashboardLedger();
    fetchWorkflowTemplates();
    fetchUserProfile();
  }, [userId]);

  useEffect(() => {
    if (documents.length > 0 && processTypes.length > 0) {
      const activeDoc = documents[0];
      const match = processTypes.find(p => p.process_name === activeDoc.process_name);
      if (match) {
        const stops = [];
        for (let i = 1; i <= 7; i++) {
          if (match[`stop_${i}_name`]) stops.push(match[`stop_${i}_name`]);
        }
        setRecentDocStops(stops);
      } else {
        setRecentDocStops([activeDoc.current_office || 'Origin Unit', activeDoc.next_office || 'Next Stop'].filter(Boolean));
      }
    }
  }, [documents, processTypes]);

  useEffect(() => {
    function handleClickOutside(event) {
      if (notificationRef.current && !notificationRef.current.contains(event.target)) {
        setShowNotifications(false);
      }
    }
    document.addEventListener("mousedown", handleClickOutside);
    return () => document.removeEventListener("mousedown", handleClickOutside);
  }, []);

  useEffect(() => {
    fetchLiveNotificationFeeds();
    const alertInterval = setInterval(fetchLiveNotificationFeeds, 10000);
    return () => clearInterval(alertInterval);
  }, [userId]);

  // Reset pagination when search or filter changes
  useEffect(() => {
    setCurrentPage(1);
  }, [search, filterStatus]);

  const fetchLiveNotificationFeeds = async () => {
    try {
      const res = await fetchWithAuth(`http://localhost:5000/api/notifications/${userId}/1/0`);
      const data = await res.json();
      if (res.ok) {
        const alertCollection = data.map(n => ({
          id: n.id,
          title: n.title,
          message: n.message,
          time: new Date(n.time).toLocaleTimeString('en-US', { hour: '2-digit', minute: '2-digit', hour12: true })
        }));
        setNotifications(alertCollection);
      }
    } catch (err) { 
      console.error("Error retrieving notifications:", err); 
    }
  };

  const fetchUserProfile = async () => {
    try {
      const res = await fetchWithAuth(`http://localhost:5000/api/profile/${userId}`);
      const data = await res.json();
      if (res.ok && data) {
        const loadedProfile = {
          fullName: data.full_name || userName,
          email: data.uni_email || 'faculty@batstate-u.edu.ph',
          facultyId: data.faculty_id || '2024-FAC-1029',
          departmentName: data.department_name || 'CICS Department',
          accountType: data.account_type || 'Faculty User',
          twoFaEnabled: !!data.two_fa_enabled,
          twoFaCode: data.two_fa_code || ''
        };
        setProfile(loadedProfile);
        setInitialProfile(loadedProfile);
      } else {
        setInitialProfile({ ...profile });
      }
    } catch (err) { 
      console.error("Profile load err:", err); 
      setInitialProfile({ ...profile });
    }
  };

  const fetchDashboardLedger = async () => {
    try {
      const res = await fetchWithAuth(`http://localhost:5000/api/documents/${userId}`);
      const data = await res.json();
      if (res.ok) {
        setDocuments(data);
        if (data.length > 0) {
          setNotifications([{ id: 1, title: "Pipeline Active", message: `Tracking is now active for your submission: "${data[0].title}".`, time: "Just now", unread: true }]);
        }
      }
    } catch (err) { console.error(err); }
  };

  const fetchWorkflowTemplates = async () => {
    try {
      const res = await fetchWithAuth('http://localhost:5000/api/process-types');
      const data = await res.json();
      if (res.ok) setProcessTypes(data);
    } catch (err) { console.error(err); }
  };

  const saveProfileChanges = async (e) => {
    if (e) e.preventDefault();
    setStatusMsg('');

    if (!profile.fullName.trim() || !profile.email.trim()) {
      return alert("Validation Error: Personal Information fields cannot be left empty.");
    }

    if (profile.twoFaEnabled && (!profile.twoFaCode || profile.twoFaCode.length < 4)) {
      return alert("Please set up a valid numeric code pin combination first.");
    }
    
    try {
      const res = await fetchWithAuth(`http://localhost:5000/api/profile/${userId}`, {
        method: 'PUT',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify(profile)
      });
      if (res.ok) {
        setStatusMsg("✅ Profile modifications saved instantly!");
        localStorage.setItem('user', profile.fullName);
        setInitialProfile(profile);
      }
    } catch (err) { alert("Failed sync configuration parameters."); }
  };

  const updatePasswordRequest = async (e) => {
    e.preventDefault();
    if (passForm.newPassword !== passForm.confirmNew) return alert("New passwords mismatched.");
    try {
      const res = await fetchWithAuth(`http://localhost:5000/api/profile/${userId}/password`, {
        method: 'PUT',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify(passForm)
      });
      const data = await res.json();
      if (!res.ok) throw new Error(data.error);
      alert("✅ Password record securely altered!");
      setShowPassModal(false);
      setPassForm({ currentPassword: '', newPassword: '', confirmNew: '' });
    } catch (err) { alert(err.message); }
  };

  const handleProcessChange = (pId) => {
    const selected = processTypes.find(p => p.p_id === parseInt(pId));
    if (selected) {
      const stops = [];
      for (let i = 1; i <= 7; i++) if (selected[`stop_${i}_name`]) stops.push(selected[`stop_${i}_name`]);
      setSelectedRoutePreview(stops);
      setForm({ ...form, processTypeId: pId });
      
      const futureDate = new Date();
      futureDate.setDate(futureDate.getDate() + (stops.length * 2)); 
      setEstimatedDate(futureDate.toLocaleDateString('en-US', { year: 'numeric', month: 'long', day: 'numeric' }));
    } else {
      setSelectedRoutePreview([]);
      setForm({ ...form, processTypeId: '' });
      setEstimatedDate('');
    }
  };

  const submitDocument = async (e) => {
    e.preventDefault();
    try {
      const res = await fetchWithAuth('http://localhost:5000/api/documents', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ userId: parseInt(userId), title: form.title, processTypeId: parseInt(form.processTypeId), edc: estimatedDate ? new Date(estimatedDate).toISOString().split('T')[0] : null })
      });
      const data = await res.json();
      setGeneratedQr(data.qrCode);
      setShowModal(false);
      setShowQrModal(true);
      setForm({ title: '', processTypeId: '', confirmation: false });
      setSelectedRoutePreview([]);
      fetchDashboardLedger();
    } catch (err) { console.error(err); }
  };

  const filteredDocuments = documents.filter(doc => {
    return doc.title.toLowerCase().includes(search.toLowerCase()) && (filterStatus === 'All' || doc.status?.toLowerCase() === filterStatus.toLowerCase());
  });

  // Pagination Logic for Ledger
  const indexOfLastDoc = currentPage * itemsPerPage;
  const indexOfFirstDoc = indexOfLastDoc - itemsPerPage;
  const currentLedgerDocs = filteredDocuments.slice(indexOfFirstDoc, indexOfLastDoc);
  const totalPages = Math.ceil(filteredDocuments.length / itemsPerPage);

  const pendingCount = documents.filter(d => d.status?.toLowerCase() === 'pending' || d.status?.toLowerCase() === 'in verification').length;
  const mostRecentDoc = documents[0];

  const isProfileChanged = initialProfile 
    ? (JSON.stringify(profile) !== JSON.stringify(initialProfile) && profile.fullName.trim() !== '' && profile.email.trim() !== '')
    : false;

  return (
    <div className="flex h-screen w-screen bg-[#FAF8F5] text-neutral-800 font-sans overflow-hidden">
      <div className="w-64 bg-[#2D1F1E] text-neutral-300 flex flex-col justify-between p-4 flex-shrink-0">
        <div>
          <div className="flex items-center gap-3 border-b border-neutral-700 pb-4 mb-6">
            <div className="bg-red-700 p-2 rounded-lg text-white font-bold text-xl">🎓</div>
            <div>
              <h1 className="font-bold text-white text-sm">BSU Portal</h1>
              <span className="text-[10px] text-neutral-400 uppercase tracking-wider">Institutional Management</span>
            </div>
          </div>
          <nav className="space-y-1 text-sm">
            <button onClick={() => setActiveTab('dashboard')} className={`w-full flex items-center gap-3 px-3 py-2.5 rounded-lg text-left transition-colors ${activeTab === 'dashboard' ? 'bg-neutral-800 text-white font-medium' : 'text-neutral-400 hover:bg-neutral-800 hover:text-white'}`}>
              <LayoutDashboard size={18} /> Home
            </button>
            <button onClick={() => setActiveTab('documents')} className={`w-full flex items-center gap-3 px-3 py-2.5 rounded-lg text-left transition-colors ${activeTab === 'documents' ? 'bg-neutral-800 text-white font-medium' : 'text-neutral-400 hover:bg-neutral-800 hover:text-white'}`}>
              <FileText size={18} /> Documents
            </button>
            <button onClick={() => setActiveTab('resources')} className={`w-full flex items-center gap-3 px-3 py-2.5 rounded-lg text-left transition-colors ${activeTab === 'resources' ? 'bg-neutral-800 text-white font-medium' : 'text-neutral-400 hover:bg-neutral-800 hover:text-white'}`}>
              <School size={18} /> School Resources
            </button>
          </nav>
        </div>
        <div className="border-t border-neutral-700 pt-4">
          <button onClick={() => { localStorage.clear(); navigate('/login'); }} className="w-full flex items-center gap-3 px-3 py-2.5 text-sm text-neutral-400 hover:bg-red-950/40 hover:text-red-400 font-semibold rounded-lg transition-colors">
            <span>🚪</span> Logout Session
          </button>
        </div>
      </div>

      <div className="flex-1 flex flex-col overflow-hidden">
        <header className="h-16 border-b border-neutral-200 bg-white px-8 flex items-center justify-between shadow-sm flex-shrink-0 relative">
          <h2 className="text-lg font-bold text-neutral-800 capitalize">{activeTab} Hub</h2>
          <div className="flex items-center gap-4 text-neutral-600">
            <div className="relative" ref={notificationRef}>
              <button onClick={() => setShowNotifications(!showNotifications)} className="p-2 rounded-full hover:bg-neutral-100 relative">
                <Bell size={20} />
                {notifications.length > 0 && <span className="absolute top-1 right-1 w-2 h-2 bg-red-600 rounded-full"></span>}
              </button>
              {showNotifications && (
                <div className="absolute right-0 mt-2 w-80 bg-white border border-neutral-200 rounded-2xl shadow-xl z-50 overflow-hidden">
                  <div className="p-4 border-b border-neutral-100 bg-[#FDFBF9] font-bold text-xs uppercase text-neutral-900">Notifications</div>
                  <div className="max-h-64 overflow-y-auto divide-y divide-neutral-100">
                    {notifications.map(n => (
                      <div key={n.id} className="p-4 text-xs text-left"><p className="font-bold text-neutral-900">{n.title}</p><p className="text-neutral-500 mt-1">{n.message}</p></div>
                    ))}
                  </div>
                </div>
              )}
            </div>
            <button onClick={() => setActiveTab('profile')} className={`p-2 rounded-full hover:bg-neutral-100 transition-colors ${activeTab === 'profile' ? 'bg-neutral-100 text-red-800' : ''}`}><User size={20} /></button>
          </div>
        </header>

        <div className="flex-1 overflow-y-auto p-8">
          {activeTab === 'dashboard' && (
            <div className="space-y-8 max-w-6xl mx-auto">
              <div className="grid grid-cols-1 xl:grid-cols-3 gap-6">
                <div className="bg-white p-6 rounded-2xl border border-neutral-200 shadow-sm text-left flex flex-col justify-between">
                  <div>
                    <span className="text-[10px] uppercase font-bold text-red-700 tracking-wider">Institutional Profile</span>
                    <h3 className="text-xl font-bold mt-1 text-neutral-900">{profile.fullName || userName}</h3>
                    <p className="text-xs text-neutral-400 mt-0.5">{profile.accountType} / {profile.departmentName}</p>
                  </div>
                  <button onClick={() => setActiveTab('profile')} className="mt-4 px-4 py-1.5 w-max bg-red-800 text-white rounded-lg text-xs font-medium hover:bg-red-900">View Profile</button>
                </div>
                <div className="xl:col-span-2 grid grid-cols-2 sm:grid-cols-4 gap-4">
                  {[{ label: 'Total Documents', val: documents.length, color: 'text-neutral-900' }, { label: 'Pending Process', val: pendingCount, color: 'text-amber-600' }, { label: 'Action Required', val: documents.filter(d => d.status?.toLowerCase() === 'action required').length, color: 'text-red-600' }, { label: 'Completed Log', val: documents.filter(d => d.status?.toLowerCase() === 'completed').length, color: 'text-green-600' }].map((kpi, idx) => (
                    <div key={idx} className="bg-white p-5 rounded-2xl border border-neutral-200 shadow-sm text-center">
                      <p className="text-xs font-bold text-neutral-400 uppercase tracking-tight mb-2">{kpi.label}</p>
                      <p className={`text-4xl font-extrabold ${kpi.color}`}>{String(kpi.val).padStart(2, '0')}</p>
                    </div>
                  ))}
                </div>
              </div>

              {mostRecentDoc && (
              <div className="bg-white p-6 rounded-2xl border border-neutral-200 shadow-sm text-left">
                <h4 className="text-sm font-bold tracking-tight text-neutral-500 uppercase mb-4">
                  Recent Document: <span className="text-neutral-900 font-extrabold uppercase">{mostRecentDoc.title}</span>
                </h4>
                <div className="relative flex items-center justify-between mt-6 px-4">
                  <div className="absolute left-4 right-4 h-1 bg-neutral-200 top-3 -z-10"></div>
                  <div 
                    className="absolute left-4 h-1 bg-red-700 top-3 -z-10 transition-all duration-500 ease-in-out"
                    style={{
                      width: (() => {
                        if (mostRecentDoc.status?.toLowerCase() === 'completed') return 'calc(100% - 32px)';
                        const idx = recentDocStops.indexOf(mostRecentDoc.current_office);
                        if (idx === -1 || recentDocStops.length <= 1) return '0%';
                        return `calc(${(idx / (recentDocStops.length - 1)) * 100}% - 12px)`;
                      })()
                    }}
                  ></div>
                  
                  {recentDocStops.map((stop, index) => {
                    const currentOfficeIdx = recentDocStops.indexOf(mostRecentDoc.current_office);
                    const isCompletedAll = mostRecentDoc.status?.toLowerCase() === 'completed';
                    const isCurrent = stop === mostRecentDoc.current_office && !isCompletedAll;
                    const isPast = isCompletedAll || (currentOfficeIdx !== -1 && index <= currentOfficeIdx);

                    return (
                      <div key={index} className="text-center flex flex-col items-center flex-1">
                        <div className={`w-7 h-7 rounded-full flex items-center justify-center text-xs font-bold transition-all shadow-xs ${
                          isCurrent ? 'bg-red-700 text-white ring-4 ring-red-100 animate-pulse' :
                          isPast ? 'bg-red-800 text-white' : 'bg-neutral-200 text-neutral-500'
                        }`}>
                          {isPast && !isCurrent ? '✓' : index + 1}
                        </div>
                        <p className={`text-[11px] font-bold mt-2 truncate max-w-[130px] ${isCurrent ? 'text-red-800 font-extrabold' : 'text-neutral-500'}`}>
                          {stop}
                        </p>
                      </div>
                    );
                  })}
                </div>
              </div>
            )}

              <div className="bg-white border border-neutral-200 rounded-2xl shadow-sm overflow-hidden text-left flex flex-col">
                <div className="p-6 border-b border-neutral-100 flex items-center justify-between">
                  <div><h3 className="text-base font-bold text-neutral-950">Document Ledger Matrix</h3></div>
                  <button onClick={() => setShowModal(true)} className="px-4 py-2 bg-red-800 text-white text-xs font-medium rounded-lg flex items-center gap-1.5"><Plus size={14} /> New Document</button>
                </div>
                <div className="overflow-x-auto">
                  <table className="w-full text-left text-xs border-collapse">
                    <thead><tr className="bg-neutral-50 border-b"><th className="p-4">Title / ID</th><th className="p-4">Workflow Type</th><th className="p-4">Status</th></tr></thead>
                    <tbody>
                      {currentLedgerDocs.map(doc => (
                        <tr key={doc.ini_id} className="border-b"><td className="p-4 font-bold">{doc.title}</td><td className="p-4">{doc.process_name}</td><td className="p-4 text-amber-600 font-bold">• {doc.status || 'Active Path'}</td></tr>
                      ))}
                      {currentLedgerDocs.length === 0 && (
                        <tr>
                          <td colSpan="3" className="p-8 text-center text-neutral-500 text-xs">No documents found.</td>
                        </tr>
                      )}
                    </tbody>
                  </table>
                </div>
                
                {/* Pagination Controls */}
                {totalPages > 1 && (
                  <div className="p-4 border-t border-neutral-100 flex items-center justify-between bg-neutral-50/50">
                    <span className="text-xs text-neutral-500">
                      Page <span className="font-bold text-neutral-900">{currentPage}</span> of {totalPages}
                    </span>
                    <div className="flex gap-2">
                      <button 
                        onClick={() => setCurrentPage(prev => Math.max(prev - 1, 1))} 
                        disabled={currentPage === 1}
                        className="p-1.5 border rounded-lg hover:bg-white disabled:opacity-50 disabled:cursor-not-allowed transition-colors"
                      >
                        <ChevronLeft size={16} />
                      </button>
                      <button 
                        onClick={() => setCurrentPage(prev => Math.min(prev + 1, totalPages))} 
                        disabled={currentPage === totalPages}
                        className="p-1.5 border rounded-lg hover:bg-white disabled:opacity-50 disabled:cursor-not-allowed transition-colors"
                      >
                        <ChevronRight size={16} />
                      </button>
                    </div>
                  </div>
                )}
              </div>
            </div>
          )}

          {activeTab === 'documents' && (
            <DocumentsHub 
              userId={userId}
              documents={documents}
              fetchDashboardLedger={fetchDashboardLedger}
              setShowModal={setShowModal}
              processTypes={processTypes}
            />
          )}

          {activeTab === 'profile' && (
            <form onSubmit={saveProfileChanges} className="max-w-4xl mx-auto space-y-6 text-left animate-in fade-in duration-150">
              {statusMsg && <div className="p-3 bg-green-50 border border-green-200 rounded-xl text-green-700 text-xs font-semibold">{statusMsg}</div>}
              
              <div className="bg-white border border-neutral-200 rounded-2xl p-6 shadow-sm flex items-center gap-6">
                <div className="relative w-24 h-24 bg-neutral-100 border rounded-2xl overflow-hidden flex-shrink-0">
                  <img src="https://images.unsplash.com/photo-1560250097-0b93528c311a?q=80&w=256" alt="Profile avatar" className="w-full h-full object-cover" />
                  <div className="absolute bottom-1 right-1 bg-red-700 p-1.5 rounded-lg text-white text-[10px] cursor-pointer">✏️</div>
                </div>
                <div>
                  <div className="flex items-center gap-2">
                    <h3 className="text-2xl font-black text-neutral-900 tracking-tight">{profile.fullName}</h3>
                    <span className="px-2 py-0.5 bg-red-50 border border-red-100 text-[9px] font-black uppercase text-red-800 rounded">{profile.accountType}</span>
                  </div>
                  <p className="text-xs text-neutral-400 mt-1">Faculty • {profile.departmentName}</p>
                  <div className="flex items-center gap-1.5 text-xs text-green-600 font-semibold mt-2">
                    <span className="w-2 h-2 bg-green-500 rounded-full"></span> Active System Status
                  </div>
                </div>
              </div>

              <div className="grid grid-cols-1 md:grid-cols-3 gap-6 items-start">
                <div className="md:col-span-2 space-y-6">
                  <div className="bg-white border border-neutral-200 rounded-2xl p-6 shadow-sm space-y-4">
                    <h4 className="text-sm font-bold text-neutral-800 uppercase tracking-wider pb-2 border-b">👤 Personal Information</h4>
                    <div className="grid grid-cols-1 sm:grid-cols-2 gap-4">
                      <div>
                        <label className="block text-[10px] font-bold text-gray-400 uppercase mb-1">Full Name</label>
                        <input type="text" required value={profile.fullName} onChange={e => setProfile({...profile, fullName: e.target.value})}
                               className="w-full border px-3 py-2 text-xs font-medium rounded-lg focus:ring-1 focus:ring-red-700 outline-none border-neutral-300" />
                      </div>
                      <div>
                        <label className="block text-[10px] font-bold text-gray-400 uppercase mb-1">University Email</label>
                        <input type="email" required value={profile.email} onChange={e => setProfile({...profile, email: e.target.value})}
                               className="w-full border px-3 py-2 text-xs font-medium rounded-lg focus:ring-1 focus:ring-red-700 outline-none border-neutral-300" />
                      </div>
                    </div>
                  </div>

                  <div className="bg-white border border-neutral-200 rounded-2xl p-6 shadow-sm space-y-4">
                    <h4 className="text-sm font-bold text-neutral-800 uppercase tracking-wider pb-2 border-b">🛡️ Account Security</h4>
                    
                    <div className="flex items-center justify-between p-3 border rounded-xl bg-neutral-50/50">
                      <div>
                        <p className="text-xs font-bold text-neutral-900">Change Password</p>
                        <p className="text-[11px] text-neutral-400 mt-0.5">Update your system login credentials regularly.</p>
                      </div>
                      <button type="button" onClick={() => setShowPassModal(true)} className="text-xs text-red-700 font-bold hover:underline">Update</button>
                    </div>

                    <div className="p-4 border rounded-xl bg-neutral-50/50 space-y-3">
                      <div className="flex items-center justify-between">
                        <div>
                          <p className="text-xs font-bold text-neutral-900">Two-Factor Authentication (2FA)</p>
                          <p className="text-[11px] text-neutral-400 mt-0.5">Secure your account access with a secondary code combination pin prompt.</p>
                        </div>
                        <label className="relative inline-flex items-center cursor-pointer">
                          <input type="checkbox" checked={profile.twoFaEnabled} onChange={e => setProfile({...profile, twoFaEnabled: e.target.checked, twoFaCode: e.target.checked ? profile.twoFaCode : ''})} className="sr-only peer" />
                          <div className="w-9 h-5 bg-neutral-200 peer-focus:outline-none rounded-full peer peer-checked:after:translate-x-full peer-checked:after:border-white after:content-[''] after:absolute after:top-[2px] after:left-[2px] after:bg-white after:border-gray-300 after:border after:rounded-full after:h-4 after:w-4 after:transition-all peer-checked:bg-red-700"></div>
                        </label>
                      </div>

                      {profile.twoFaEnabled && (
                        <div className="pt-3 border-t border-dashed animate-in fade-in duration-100">
                          <label className="block text-[10px] font-bold text-gray-500 uppercase tracking-wider mb-1">Set Your Custom Numeric Security Code PIN</label>
                          <input type="text" maxLength={6} placeholder="Enter 4-6 digit numeric pin" value={profile.twoFaCode} onChange={e => setProfile({...profile, twoFaCode: e.target.value.replace(/\D/g, "")})}
                                 className="w-48 border px-3 py-1.5 font-mono tracking-widest text-xs rounded-lg outline-none focus:ring-1 focus:ring-red-700" />
                        </div>
                      )}
                    </div>
                  </div>
                </div>

                <div className="space-y-6">
                  <div className="bg-white border border-neutral-200 rounded-2xl p-6 shadow-sm space-y-4">
                    <h4 className="text-sm font-bold text-neutral-800 uppercase tracking-wider pb-2 border-b">🏛️ Institutional Details</h4>
                    <div>
                      <span className="text-[9px] font-bold text-gray-400 uppercase tracking-wider">Faculty ID</span>
                      <p className="text-base font-black text-neutral-800 tracking-tight mt-0.5">{profile.facultyId}</p>
                    </div>
                    <div>
                      <span className="text-[9px] font-bold text-gray-400 uppercase tracking-wider">Assigned Campus Unit</span>
                      <p className="text-xs font-bold text-neutral-700 mt-0.5">{profile.departmentName}</p>
                    </div>
                  </div>

                  <div className="p-4 bg-red-50/50 border border-red-100 text-red-800 rounded-xl text-[11px] leading-relaxed">
                    ℹ️ Institutional data variables are managed natively by the university registry core database. Please contact <span className="font-bold underline underline-offset-2 cursor-pointer">ICT Support</span> for data correction rules.
                  </div>
                </div>
              </div>

              <div className="flex justify-end gap-3 pt-4 border-t border-neutral-200">
                <button type="button" onClick={() => { fetchUserProfile(); setActiveTab('dashboard'); }} className="px-5 py-2 border font-medium text-xs text-gray-500 rounded-lg hover:bg-neutral-50">Cancel</button>
                <button 
                  type="submit"
                  disabled={!isProfileChanged} 
                  className={`px-6 py-2 font-medium text-xs rounded-lg transition-all ${
                    isProfileChanged 
                      ? 'bg-red-800 text-white hover:bg-red-900 shadow-md cursor-pointer' 
                      : 'bg-neutral-200 text-neutral-400 cursor-not-allowed'
                  }`}
                >
                  Save Changes
                </button>
              </div>
            </form>
          )}

          {activeTab === 'resources' && (
            <ResourceScheduler userId={userId} />
          )}
        </div>
      </div>

      {/* Modals... */}
      {showPassModal && (
        <div className="fixed inset-0 bg-neutral-950/40 backdrop-blur-xs flex items-center justify-center p-4 z-50">
          <div className="bg-white w-full max-w-sm rounded-2xl shadow-xl border overflow-hidden flex flex-col animate-in fade-in zoom-in-95 duration-100">
            <div className="p-4 border-b bg-[#FDFBF9] flex items-center justify-between"><h3 className="font-bold text-neutral-950 text-sm text-left">Update Security Password</h3><button type="button" onClick={() => setShowPassModal(false)} className="text-neutral-400"><X size={16} /></button></div>
            <form onSubmit={updatePasswordRequest} className="p-5 space-y-4 text-left">
              <div><label className="block text-[10px] font-bold text-gray-500 uppercase mb-1">Current Password</label><input type="password" required value={passForm.currentPassword} onChange={e => setPassForm({...passForm, currentPassword: e.target.value})} className="w-full border px-3 py-2 text-xs rounded-lg outline-none focus:ring-1 focus:ring-red-700" /></div>
              <div><label className="block text-[10px] font-bold text-gray-500 uppercase mb-1">New Password</label><input type="password" required value={passForm.newPassword} onChange={e => setPassForm({...passForm, newPassword: e.target.value})} className="w-full border px-3 py-2 text-xs rounded-lg outline-none focus:ring-1 focus:ring-red-700" /></div>
              <div><label className="block text-[10px] font-bold text-gray-500 uppercase mb-1">Confirm New Password</label><input type="password" required value={passForm.confirmNew} onChange={e => setPassForm({...passForm, confirmNew: e.target.value})} className="w-full border px-3 py-2 text-xs rounded-lg outline-none focus:ring-1 focus:ring-red-700" /></div>
              <div className="flex justify-end gap-2 pt-2 border-t"><button type="button" onClick={() => setShowPassModal(false)} className="px-3 py-1.5 border text-xs text-gray-500 rounded-lg">Cancel</button><button type="submit" className="px-4 py-1.5 bg-red-800 text-white text-xs font-medium rounded-lg">Alter Security Password</button></div>
            </form>
          </div>
        </div>
      )}

      {showModal && ( 
        <div className="fixed inset-0 bg-neutral-950/40 backdrop-blur-xs flex items-center justify-center p-4 z-50">
          <div className="bg-white w-full max-w-xl rounded-2xl shadow-xl border overflow-hidden flex flex-col text-left animate-in fade-in zoom-in-95 duration-150">
            <div className="p-5 border-b bg-[#FDFBF9] flex items-center justify-between">
              <h3 className="font-bold text-neutral-950">Submit New Document</h3>
              <button type="button" onClick={() => { setShowModal(false); setSelectedRoutePreview([]); setEstimatedDate(''); }} className="text-neutral-400"><X size={18} /></button>
            </div>
            <form onSubmit={submitDocument} className="p-6 space-y-4">
              <div>
                <label className="block text-[10px] font-bold text-gray-500 uppercase tracking-wider mb-1">Document Title</label>
                <input type="text" required placeholder="e.g., Curriculum Revision Request" value={form.title} onChange={e => setForm({...form, title: e.target.value})} className="w-full border rounded-lg px-3 py-2 text-xs outline-none focus:ring-1 focus:ring-red-700 border-neutral-300" />
              </div>
              <div className="grid grid-cols-1 sm:grid-cols-2 gap-4">
                <div>
                  <label className="block text-[10px] font-bold text-gray-500 uppercase tracking-wider mb-1">Process Type</label>
                  <select required value={form.processTypeId} onChange={e => handleProcessChange(e.target.value)} className="w-full border bg-white rounded-lg px-3 py-2 text-xs outline-none focus:ring-1 focus:ring-red-700 border-neutral-300">
                    <option value="">Select process pattern...</option>
                    {processTypes.map(p => (<option key={p.p_id} value={p.p_id}>{p.process_name}</option>))}
                  </select>
                </div>
                <div>
                  <label className="block text-[10px] font-bold text-neutral-400 uppercase tracking-wider mb-1">Automatic Estimate Based On Route (EDC)</label>
                  <input type="text" readOnly value={estimatedDate || "Select a process type..."} className="w-full border bg-neutral-50 font-medium text-neutral-500 rounded-lg px-3 py-2 text-xs outline-none cursor-not-allowed border-neutral-200" />
                </div>
              </div>
              {selectedRoutePreview.length > 0 && (
                <div>
                  <label className="block text-[10px] font-bold text-gray-500 uppercase tracking-wider mb-2">Submission Route Path</label>
                  <div className="bg-red-50/50 border border-red-100 rounded-xl p-4 flex flex-wrap items-center gap-2 text-xs font-semibold text-neutral-700">
                    {selectedRoutePreview.map((stop, i) => (
                      <React.Fragment key={i}>
                        <span className="bg-white px-2.5 py-1 rounded-lg border shadow-xs flex items-center gap-1">
                          <span className="w-4 h-4 rounded-full bg-red-800 text-white text-[9px] flex items-center justify-center font-bold">{i+1}</span>
                          {stop}
                        </span>
                        {i < selectedRoutePreview.length - 1 && <span className="text-neutral-400 font-bold">→</span>}
                      </React.Fragment>
                    ))}
                  </div>
                </div>
              )}
              <div className="flex items-start gap-2.5 pt-2">
                <input type="checkbox" id="confirmBox" required checked={form.confirmation} onChange={e => setForm({...form, confirmation: e.target.checked})} className="mt-0.5 rounded text-red-800 focus:ring-red-700 w-3.5 h-3.5" />
                <label htmlFor="confirmBox" className="text-[11px] text-gray-500 leading-tight select-none">I confirm that the information provided is accurate and all necessary supporting documents are attached as per institutional guidelines.</label>
              </div>
              <div className="flex justify-end gap-2.5 pt-4 border-t border-neutral-100">
                <button type="button" onClick={() => { setShowModal(false); setSelectedRoutePreview([]); setEstimatedDate(''); }} className="px-4 py-2 border font-medium text-gray-500 text-xs rounded-lg hover:bg-neutral-50">Cancel</button>
                <button type="submit" className="px-5 py-2 font-medium bg-red-800 hover:bg-red-900 text-white text-xs rounded-lg">Submit Document</button>
              </div>
            </form>
          </div>
        </div> 
      )}

      {showQrModal && ( 
        <div className="fixed inset-0 bg-neutral-950/50 backdrop-blur-xs flex items-center justify-center p-4 z-50">
          <div className="bg-white rounded-2xl p-6 text-center max-w-sm w-full border shadow-2xl space-y-4 animate-in zoom-in-95 duration-100">
            <div className="w-12 h-12 rounded-full bg-green-100 text-green-700 flex items-center justify-center mx-auto text-xl font-bold">✓</div>
            <div>
              <h3 className="text-lg font-bold text-neutral-900">Tracking Pipeline Open!</h3>
              <p className="text-xs text-neutral-400 mt-1">Your unique tracking token registry code is now active.</p>
            </div>
            <div className="bg-neutral-50 p-6 border rounded-xl flex flex-col items-center justify-center border-dashed">
              <QrCode size={140} className="text-neutral-800" strokeWidth={1.5} />
              <code className="text-[10px] mt-3 font-mono bg-white px-2 py-0.5 border rounded text-neutral-600 tracking-wider font-bold">{generatedQr}</code>
            </div>
            <button type="button" onClick={() => setShowQrModal(false)} className="w-full py-2 bg-neutral-900 hover:bg-neutral-800 text-white font-medium text-xs rounded-lg transition-colors">Done & Close</button>
          </div>
        </div> 
      )}
    </div>
  );
}