import React, { useState, useEffect, useRef } from 'react';
import { useNavigate } from 'react-router-dom';
import { LayoutDashboard, FileText, History, Bell, User, Search, Filter, X, QrCode, LogOut, Camera, KeyRound, ShieldCheck, Building, Landmark } from 'lucide-react';

export default function ProcessorDashboard() {
  const navigate = useNavigate();
  const notificationRef = useRef(null);
  
  const userId = localStorage.getItem('userId');
  const userName = localStorage.getItem('user') || 'Office Processor';
  
  // Tab States: 'dashboard' | 'documents' | 'history' | 'profile'
  const [activeTab, setActiveTab] = useState('dashboard');
  const [showNotifications, setShowNotifications] = useState(false);
  const [notifications, setNotifications] = useState([]);
  
  // Domain Data States
  const [incomingDocs, setIncomingDocs] = useState([]); // Documents currently sitting open in your office queue (time_out IS NULL)
  const [pipelineDocs, setPipelineDocs] = useState([]);   // ALL historical steps associated with your office workspace (including timed-out ones)
  const [selectedDoc, setSelectedDoc] = useState(null);
  const [processTypes, setProcessTypes] = useState([]);
  
  // Interactive Modal Triggers
  const [showDetailsModal, setShowDetailsModal] = useState(false); // Dashboard Modal
  const [showPipelineModal, setShowPipelineModal] = useState(false); // Documents Tab Modal
  const [showScannerModal, setShowScannerModal] = useState(false);
  const [showPassModal, setShowPassModal] = useState(false);
  const [scanMode, setScanMode] = useState('time-in');
  const [simulatedQrInput, setSimulatedQrPayload] = useState('');
  
  // Profile Editable State Fields
  const [profileName, setProfileName] = useState('');
  const [profileEmail, setProfileEmail] = useState('');
  const [facultyId, setFacultyId] = useState('N/A');
  const [departmentName, setDepartmentName] = useState('N/A');
  const [twoFaEnabled, setTwoFaEnabled] = useState(false);
  const [twoFaCode, setTwoFaCode] = useState('');
  
  // Password Input Fields
  const [currentPassword, setCurrentPassword] = useState('');
  const [newPassword, setNewPassword] = useState('');
  const [confirmPassword, setConfirmPassword] = useState('');

  // Search & Filter Hooks
  const [search, setSearch] = useState('');
  const [filterStatus, setFilterStatus] = useState('All'); 
  const [processorOfficeName, setProcessorOfficeName] = useState('Loading Office...');
  const [processorOfficeId, setProcessorOfficeId] = useState(null);

  const [officesList, setOfficesList] = useState([]);
  const [selectedAdHocOffice, setSelectedAdHocOffice] = useState('');
  const [isAdHocProcessing, setIsAdHocProcessing] = useState(false);

  // Pagination State Controls (Items Per Page = 5)
  const [dashboardPage, setDashboardPage] = useState(1);
  const [pipelinePage, setPipelinePage] = useState(1);
  const itemsPerPage = 5;

  useEffect(() => {
    if (!userId || userId === 'undefined') {
      localStorage.clear();
      navigate('/login');
      return;
    }
    fetchProcessorMeta();
    fetchWorkflowTemplates();
  }, [userId]);

  useEffect(() => {
    function handleClickOutside(event) {
      if (notificationRef.current && !notificationRef.current.contains(event.target)) {
        setShowNotifications(false);
      }
    }
    document.addEventListener("mousedown", handleClickOutside);
    return () => document.removeEventListener("mousedown", handleClickOutside);
  }, []);

  const fetchProcessorMeta = async () => {
    try {
      const res = await fetch(`http://localhost:5000/api/profile/${userId}`);
      const data = await res.json();
      if (res.ok) {
        setProcessorOfficeName(data.office_name || 'CICS Office');
        setProcessorOfficeId(data.o_id);
        
        // Populate profile form values
        setProfileName(data.full_name || '');
        setProfileEmail(data.uni_email || '');
        setFacultyId(data.faculty_id || 'NOT ASSIGNED');
        setDepartmentName(data.department_name || 'CICS');
        setTwoFaEnabled(data.two_fa_enabled || false);
        setTwoFaCode(data.two_fa_code || '');

        fetchIncomingDocumentLogs(data.o_id);
        fetchPipelineDocs(data.o_id);
      }
    } catch (err) { 
      console.error("Error connecting metadata:", err); 
    }
  };

  // FETCH INCOMING ACTIVE STREAMS (WHERE CURRENT_OFFICE_ID = YOU AND TIME_OUT IS NULL)
  const fetchIncomingDocumentLogs = async (officeId) => {
    if (!officeId) return;
    try {
      const res = await fetch(`http://localhost:5000/api/processor/documents/${officeId}`);
      const data = await res.json();
      if (res.ok) {
        setIncomingDocs(data);
        if (data.length > 0) {
          setNotifications([
            { id: 1, title: "New Document Routing", message: `Document "${data[0].title}" entered your office queue. Action required.`, time: "2h ago" }
          ]);
        }
      }
    } catch (err) { console.error("Frontend document log sync error:", err); }
  };

  // FETCH ALL HISTORY STEPS (INCLUDING TIME_OUT STEPS AND DETOURS)
  const fetchPipelineDocs = async (officeId) => {
    if (!officeId) return;
    try {
      const res = await fetch(`http://localhost:5000/api/processor/documents/pipeline/${officeId}`);
      const data = await res.json();
      if (res.ok) setPipelineDocs(data);
    } catch (err) { console.error("Pipeline sync error:", err); }
  };

  const fetchWorkflowTemplates = async () => {
    try {
      const res = await fetch('http://localhost:5000/api/process-types');
      const data = await res.json();
      if (res.ok) setProcessTypes(data);
    } catch (err) { console.error(err); }
  };

  const fetchOfficesList = async () => {
    try {
      const res = await fetch('http://localhost:5000/api/offices'); 
      const data = await res.json();
      if (res.ok) {
        setOfficesList(data);
      }
    } catch (err) { 
      console.error("Error building ad-hoc office lookup dictionary:", err); 
    }
  };

  const handleUpdateProfile = async (e) => {
    e.preventDefault();
    try {
      const res = await fetch(`http://localhost:5000/api/profile/${userId}`, {
        method: 'PUT',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({
          fullName: profileName,
          email: profileEmail,
          twoFaEnabled: twoFaEnabled,
          twoFaCode: twoFaCode || null
        })
      });
      if (res.ok) {
        alert("🟢 Profile information synchronized successfully!");
        localStorage.setItem('user', profileName);
        fetchProcessorMeta();
      }
    } catch (err) { alert("Failed to save changes."); }
  };

  const handleUpdatePassword = async (e) => {
    e.preventDefault();
    if (newPassword !== confirmPassword) return alert("New passwords do not match.");
    try {
      const res = await fetch(`http://localhost:5000/api/profile/${userId}/password`, {
        method: 'PUT',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ currentPassword, newPassword })
      });
      const data = await res.json();
      if (res.ok) {
        alert("🟢 Password updated cleanly.");
        setShowPassModal(false);
        setCurrentPassword('');
        setNewPassword('');
        setConfirmPassword('');
      } else {
        alert(`🔴 ${data.error}`);
      }
    } catch (err) { alert("Failed to change credentials record."); }
  };

  const toggle2FA = async (checked) => {
    setTwoFaEnabled(checked);
    if (!checked) {
      try {
        const res = await fetch(`http://localhost:5000/api/profile/${userId}`, {
          method: 'PUT',
          headers: { 'Content-Type': 'application/json' },
          body: JSON.stringify({
            fullName: profileName,
            email: profileEmail,
            twoFaEnabled: false,
            twoFaCode: null
          })
        });
        if (res.ok) {
          setTwoFaCode('');
          alert("🔓 Two-Factor Authentication disabled.");
        }
      } catch (err) { console.error(err); }
    }
  };

  const handleSaveCustomPin = async (e) => {
    e.preventDefault();
    if (twoFaCode.length < 4 || twoFaCode.length > 6 || isNaN(twoFaCode)) {
      return alert("Please enter a valid 4-6 digit numeric security PIN code.");
    }
    try {
      const res = await fetch(`http://localhost:5000/api/profile/${userId}`, {
        method: 'PUT',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({
          fullName: profileName,
          email: profileEmail,
          twoFaEnabled: true,
          twoFaCode: twoFaCode
        })
      });
      if (res.ok) {
        alert("🔒 Custom security PIN configured successfully!");
        fetchProcessorMeta();
      }
    } catch (err) { alert("Failed to save security configuration."); }
  };

  const handleOpenDashboardDetails = (doc) => {
    setSelectedDoc(doc);
    setShowDetailsModal(true);
  };

  const handleOpenPipelineDetails = (doc) => {
    setSelectedDoc(doc);
    fetchOfficesList();
    setShowPipelineModal(true);
  };

  const handleExecuteAdHocDetour = async (e) => {
    e.preventDefault();
    if (!selectedAdHocOffice) return alert("Please select a target verification destination office step first.");
    
    setIsAdHocProcessing(true);
    try {
      const res = await fetch('http://localhost:5000/api/processor/documents/ad-hoc', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({
          iniId: selectedDoc.ini_id,
          targetOfficeId: parseInt(selectedAdHocOffice),
          currentOfficeId: processorOfficeId
        })
      });
      const data = await res.json();
      if (res.ok) {
        alert(`🟢 Detour Activated: ${data.message}`);
        setShowPipelineModal(false);
        setSelectedAdHocOffice('');
        fetchIncomingDocumentLogs(processorOfficeId);
        fetchPipelineDocs(processorOfficeId);
      } else {
        alert(`🔴 ${data.error}`);
      }
    } catch (err) { alert("Network communication error routing detour."); }
    finally { setIsAdHocProcessing(false); }
  };

  const executeSimulatedScanner = async (e) => {
    e.preventDefault();
    if (!simulatedQrInput.trim()) return alert("Please type or scan a valid reference token string first.");
    const targetUrl = scanMode === 'time-in' 
      ? 'http://localhost:5000/api/documents/scan-in' 
      : 'http://localhost:5000/api/documents/scan-out';

    try {
      const res = await fetch(targetUrl, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ qrCode: simulatedQrInput, processorUserId: parseInt(userId) })
      });
      const data = await res.json();
      if (res.ok) {
        alert(`🟢 Transaction Approved:\n${data.message}`);
        setShowScannerModal(false);
        setSimulatedQrPayload('');
        fetchIncomingDocumentLogs(processorOfficeId);
        fetchPipelineDocs(processorOfficeId);
      } else {
        alert(`🔴 ${data.error || 'Processing verification failed.'}`);
      }
    } catch (err) { alert("Failed to establish server authentication checks."); }
  };

  const getRouteStopsArray = (doc) => {
    const match = processTypes.find(p => p.process_name === doc.process_name);
    if (match) {
      const stops = [];
      for (let i = 1; i <= 7; i++) {
        if (match[`stop_${i}_name`]) stops.push(match[`stop_${i}_name`]);
      }
      return stops;
    }
    return [doc.current_office || 'Active Office'];
  };

  // =========================================================
  // 🔍 REAL-TIME INTERCEPTOR FILTERS (SYNCHRONIZED METRICS)
  // =========================================================

  // DASHBOARD FILTERING LOGIC
  const filteredDocs = incomingDocs.filter(doc => {
    const matchesSearch = doc.title.toLowerCase().includes(search.toLowerCase()) || 
                          doc.qr_code.toLowerCase().includes(search.toLowerCase());
    
    if (filterStatus === 'Awaiting Scan-In') {
      return matchesSearch && (doc.time_in === null || doc.time_in === undefined) && (!doc.time_out);
    }
    if (filterStatus === 'Pending') {
      return matchesSearch; 
    }
    if (filterStatus === 'In Verification') {
      return matchesSearch && doc.status?.toLowerCase() === 'in verification';
    }
    return matchesSearch;
  });

  // PIPELINE FILTERING LOGIC
  const filteredPipelineDocs = pipelineDocs.filter(doc => {
    const matchesSearch = doc.title.toLowerCase().includes(search.toLowerCase()) || 
                          doc.qr_code.toLowerCase().includes(search.toLowerCase());
    
    if (filterStatus === 'Awaiting Scan-In') {
      return matchesSearch && (doc.time_in === null || doc.time_in === undefined) && (!doc.time_out);
    }
    if (filterStatus === 'Pending') {
      return matchesSearch && !doc.time_out; 
    }
    if (filterStatus === 'In Verification') {
      return matchesSearch && doc.status?.toLowerCase() === 'in verification' && !doc.time_out;
    }
    if (filterStatus === 'Completed') {
      return matchesSearch && doc.time_out !== null && doc.time_out !== undefined; 
    }
    return matchesSearch;
  });

  // Calculate paginated slices
  const indexOfLastDash = dashboardPage * itemsPerPage;
  const indexOfFirstDash = indexOfLastDash - itemsPerPage;
  const currentDashDocs = filteredDocs.slice(indexOfFirstDash, indexOfLastDash);
  const totalDashPages = Math.ceil(filteredDocs.length / itemsPerPage);

  const indexOfLastPipe = pipelinePage * itemsPerPage;
  const indexOfFirstPipe = indexOfLastPipe - itemsPerPage;
  const currentPipeDocs = filteredPipelineDocs.slice(indexOfFirstPipe, indexOfLastPipe);
  const totalPipePages = Math.ceil(filteredPipelineDocs.length / itemsPerPage);

  // =========================================================
  // 📊 RE-COMPILING THE STATISTICAL KPI CALCULATIONS
  // =========================================================
  
  // 1. Incoming Documents: Any active item on campus that has this office in its routing sequence but hasn't completed it yet.
  const incomingCount = pipelineDocs.filter(d => {
    if (d.time_out !== null && d.time_out !== undefined) return false;
    if (d.current_office_id === processorOfficeId) return true;

    const match = processTypes.find(p => p.process_name === d.process_name);
    if (match) {
      const stops = [];
      for (let i = 1; i <= 7; i++) {
        if (match[`stop_${i}_name`]) stops.push(match[`stop_${i}_name`]);
      }
      return stops.includes(processorOfficeName);
    }
    return false;
  }).length;

  // 2. Awaiting Scan-In: Physical items that have arrived in your workspace queue but do not possess a scan time_in mark yet.
  const awaitingScanInCount = incomingDocs.filter(d => d.time_in === null || d.time_in === undefined).length;

  // 3. Pending Documents: Total open elements mapped straight to incoming active matrix parameters
  const pendingCount = incomingDocs.length;

  // 4. Completed Documents: Total items containing completed out-stamps
  const completedProcessingCount = pipelineDocs.filter(d => d.time_out !== null && d.time_out !== undefined).length;

  // 5. In Verification: Active detours inside pipelineDocs
  const inVerificationCount = pipelineDocs.filter(d => d.status?.toLowerCase() === 'in verification' && (d.time_out === null || d.time_out === undefined)).length;

  return (
    <div className="flex h-screen w-screen bg-[#FAF8F5] text-neutral-800 font-sans overflow-hidden">
      
      {/* SIDEBAR NAVIGATION PANEL */}
      <div className="w-64 bg-[#2D1F1E] text-neutral-300 flex flex-col justify-between p-4 flex-shrink-0 text-left">
        <div>
          <div className="flex items-center gap-3 border-b border-neutral-700 pb-4 mb-6">
            <div className="bg-red-700 p-2 rounded-lg text-white font-bold text-xl">🎓</div>
            <div>
              <h1 className="font-bold text-white text-sm">BSU Portal</h1>
              <span className="text-[10px] text-neutral-400 uppercase tracking-widest font-black">Office Processor</span>
            </div>
          </div>
          
          <nav className="space-y-1 text-sm">
            <button onClick={() => { setActiveTab('dashboard'); setSearch(''); setFilterStatus('All'); setDashboardPage(1); }} className={`w-full flex items-center gap-3 px-3 py-2.5 rounded-lg font-bold transition-colors ${activeTab === 'dashboard' ? 'bg-neutral-800 text-white' : 'text-neutral-400 hover:bg-neutral-800 hover:text-white'}`}>
              <LayoutDashboard size={18} /> Dashboard
            </button>
            <button onClick={() => { setActiveTab('documents'); setSearch(''); setFilterStatus('All'); setPipelinePage(1); }} className={`w-full flex items-center gap-3 px-3 py-2.5 rounded-lg font-bold transition-colors ${activeTab === 'documents' ? 'bg-neutral-800 text-white' : 'text-neutral-400 hover:bg-neutral-800 hover:text-white'}`}>
              <FileText size={18} /> Documents
            </button>
            <button onClick={() => setActiveTab('history')} className={`w-full flex items-center gap-3 px-3 py-2.5 rounded-lg font-bold transition-colors ${activeTab === 'history' ? 'bg-neutral-800 text-white' : 'text-neutral-400 hover:bg-neutral-800 hover:text-white'}`}>
              <History size={18} /> History
            </button>
          </nav>
        </div>

        <div className="space-y-4">
          <button 
            onClick={() => { setScanMode('time-in'); setShowScannerModal(true); }}
            className="w-full py-3 bg-red-700 hover:bg-red-800 text-white text-xs font-black rounded-xl flex items-center justify-center gap-2 transition-all shadow-md uppercase tracking-wider"
          >
            <Camera size={16} /> Scan Document
          </button>
          
          <div className="border-t border-neutral-700 pt-4">
            <button onClick={() => { localStorage.clear(); navigate('/login'); }} className="w-full flex items-center gap-3 px-3 py-2 text-sm text-neutral-400 hover:text-red-400 font-semibold transition-colors">
              <LogOut size={16} /> Sign Out
            </button>
          </div>
        </div>
      </div>

      {/* WORKSPACE AREA */}
      <div className="flex-1 flex flex-col overflow-hidden">
        
        {/* TOP BAR HEADER */}
        <header className="h-16 border-b border-neutral-200 bg-white px-8 flex items-center justify-between shadow-sm flex-shrink-0 relative">
          <div className="text-left">
            <h2 className="text-lg font-black text-neutral-900">
              {activeTab === 'profile' ? 'Profile Hub' : activeTab === 'documents' ? 'Office Processing System' : 'Processor Dashboard'}
            </h2>
            <p className="text-[10px] font-bold text-neutral-400 uppercase tracking-wide">Assigned: {processorOfficeName}</p>
          </div>
          
          <div className="flex items-center gap-4 text-neutral-600">
            <div className="relative" ref={notificationRef}>
              <button onClick={() => setShowNotifications(!showNotifications)} className="p-2 rounded-full hover:bg-neutral-100 relative transition-colors">
                <Bell size={20} />
                {notifications.length > 0 && <span className="absolute top-1 right-1 w-2 h-2 bg-red-600 rounded-full"></span>}
              </button>
              
              {showNotifications && (
                <div className="absolute right-0 mt-2 w-80 bg-white border border-neutral-200 rounded-2xl shadow-xl z-50 overflow-hidden text-left">
                  <div className="p-4 border-b border-neutral-100 bg-[#FDFBF9] font-bold text-xs uppercase text-neutral-900 tracking-wide">Notifications</div>
                  <div className="max-h-64 overflow-y-auto divide-y divide-neutral-100">
                    {notifications.map(n => (
                      <div key={n.id} className="p-4 text-xs"><p className="font-bold text-neutral-900">{n.title}</p><p className="text-neutral-500 mt-1">{n.message}</p></div>
                    ))}
                  </div>
                </div>
              )}
            </div>
            
            <button 
              onClick={() => setActiveTab(activeTab === 'profile' ? 'dashboard' : 'profile')} 
              className={`p-2 rounded-full transition-colors ${activeTab === 'profile' ? 'bg-red-50 text-red-700' : 'hover:bg-neutral-100'}`}
            >
              <User size={20} />
            </button>
          </div>
        </header>

        {/* CONTAINER SCROLL GRID SYSTEM */}
        <div className="flex-1 overflow-y-auto p-8">
          
          {/* TAB 1: OPERATIONAL HUB DASHBOARD VIEW */}
          {activeTab === 'dashboard' && (
            <div className="space-y-8 max-w-6xl mx-auto text-left">
              
              {/* CORE DASHBOARD KPI BLOCKS */}
              <div className="grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-4 gap-4">
                <div className="bg-white p-5 rounded-2xl border border-neutral-200 shadow-sm relative overflow-hidden">
                  <span className="text-[10px] uppercase font-black text-neutral-400 tracking-wider">Incoming Documents</span>
                  <p className="text-3xl font-black text-neutral-900 mt-2">{String(incomingCount).padStart(2, '0')}</p>
                  <div className="absolute right-4 bottom-4 text-lg opacity-40">📂</div>
                  <div className="h-1 bg-blue-600 absolute bottom-0 left-0 right-0"></div>
                </div>

                <div className="bg-white p-5 rounded-2xl border border-neutral-200 shadow-sm relative overflow-hidden">
                  <span className="text-[10px] uppercase font-black text-neutral-400 tracking-wider">Awaiting Scan-In</span>
                  <p className="text-3xl font-black text-neutral-900 mt-2">{String(awaitingScanInCount).padStart(2, '0')}</p>
                  <div className="absolute right-4 bottom-4 text-lg opacity-40">📥</div>
                  <div className="h-1 bg-red-700 absolute bottom-0 left-0 right-0"></div>
                </div>

                <div className="bg-white p-5 rounded-2xl border border-neutral-200 shadow-sm relative overflow-hidden">
                  <span className="text-[10px] uppercase font-black text-neutral-400 tracking-wider">Pending Documents</span>
                  <p className="text-3xl font-black text-neutral-900 mt-2">{String(pendingCount).padStart(2, '0')}</p>
                  <div className="absolute right-4 bottom-4 text-lg opacity-40">⏳</div>
                  <div className="h-1 bg-amber-500 absolute bottom-0 left-0 right-0"></div>
                </div>

                <div className="bg-white p-5 rounded-2xl border border-neutral-200 shadow-sm relative overflow-hidden">
                  <span className="text-[10px] uppercase font-black text-neutral-400 tracking-wider">Completed Documents</span>
                  <p className="text-3xl font-black text-neutral-900 mt-2">{String(completedProcessingCount).padStart(2, '0')}</p>
                  <div className="absolute right-4 bottom-4 text-lg opacity-40">✅</div>
                  <div className="h-1 bg-green-600 absolute bottom-0 left-0 right-0"></div>
                </div>
              </div>

              <div className="bg-white border border-neutral-200 rounded-2xl shadow-sm overflow-hidden">
                <div className="p-6 border-b border-neutral-100 flex flex-col sm:flex-row items-stretch sm:items-center justify-between gap-4">
                  <h3 className="text-base font-black tracking-tight text-neutral-950">Recent Document Logs</h3>
                  <div className="flex flex-wrap items-center gap-2">
                    <div className="flex items-center gap-1 border border-neutral-300 rounded-lg px-2 py-1.5 bg-neutral-50">
                      <Filter size={14} className="text-neutral-400" />
                      <select value={filterStatus} onChange={e => { setFilterStatus(e.target.value); setDashboardPage(1); }} className="bg-transparent text-xs outline-none cursor-pointer font-bold text-neutral-600">
                        <option value="All">All Statuses</option>
                        <option value="Awaiting Scan-In">Awaiting Scan-In</option>
                        <option value="Pending">Pending</option>
                        <option value="In Verification">In Verification</option>
                      </select>
                    </div>
                    <div className="relative">
                      <Search className="absolute left-3 top-2.5 text-neutral-400" size={14} />
                      <input type="text" placeholder="Search documents..." value={search} onChange={e => { setSearch(e.target.value); setDashboardPage(1); }} className="pl-9 pr-4 py-2 text-xs border border-neutral-300 rounded-lg outline-none focus:ring-1 focus:ring-red-700 bg-neutral-50" />
                    </div>
                  </div>
                </div>

                <div className="overflow-x-auto">
                  <table className="w-full text-left text-xs border-collapse">
                    <thead>
                      <tr className="bg-neutral-50 text-neutral-500 border-b border-neutral-200 font-black uppercase text-[10px] tracking-wider">
                        <th className="p-4">Title</th>
                        <th className="p-4">Form Type</th>
                        <th className="p-4">Status</th>
                        <th className="p-4">Next Office</th>
                        <th className="p-4 text-center">Action</th>
                      </tr>
                    </thead>
                    <tbody className="divide-y divide-neutral-100 font-medium">
                      {currentDashDocs.map((doc, index) => (
                        <tr key={index} className="hover:bg-neutral-50/70 transition-colors">
                          <td className="p-4">
                            <p className="font-bold text-neutral-900">{doc.title}</p>
                            <span className="text-[10px] text-gray-400">Received recently</span>
                          </td>
                          <td className="p-4">
                            <span className="px-2 py-0.5 bg-red-50 text-red-800 border border-red-100 font-black text-[9px] uppercase rounded">
                              {doc.process_name || 'REGISTRAR FORM'}
                            </span>
                          </td>
                          <td className="p-4">
                            <span className={`inline-flex items-center gap-1.5 font-bold ${doc.status?.toLowerCase() === 'completed' ? 'text-green-600' : 'text-red-700'}`}>
                              • {doc.status || 'Incoming'}
                            </span>
                          </td>
                          <td className="p-4 text-neutral-600 font-semibold">{doc.next_office || 'None (Final Stop)'}</td>
                          <td className="p-4 text-center">
                            <button onClick={() => handleOpenDashboardDetails(doc)} className="text-xs text-red-700 font-black hover:underline px-3 py-1 bg-red-50/50 hover:bg-red-50 rounded-lg transition-all">
                              View Details
                            </button>
                          </td>
                        </tr>
                      ))}
                    </tbody>
                  </table>
                  {filteredDocs.length === 0 && <div className="p-12 text-center text-neutral-400">📭 Your office workspace document queue is empty.</div>}
                </div>

                {totalDashPages > 1 && (
                  <div className="p-4 border-t border-neutral-100 bg-neutral-50/50 flex items-center justify-between text-xs px-6">
                    <span className="text-neutral-500 font-medium">Showing page <b>{dashboardPage}</b> of {totalDashPages}</span>
                    <div className="flex gap-1">
                      <button disabled={dashboardPage === 1} onClick={() => setDashboardPage(prev => prev - 1)} className="px-3 py-1.5 border rounded-lg bg-white font-bold text-neutral-600 hover:bg-neutral-50 disabled:opacity-40 transition-all">Previous</button>
                      <button disabled={dashboardPage === totalDashPages} onClick={() => setDashboardPage(prev => prev + 1)} className="px-3 py-1.5 border rounded-lg bg-white font-bold text-neutral-600 hover:bg-neutral-50 disabled:opacity-40 transition-all">Next</button>
                    </div>
                  </div>
                )}
              </div>
            </div>
          )}

          {/* TAB 2: OPERATIONAL DOCUMENTS PIPELINE VIEW WITH DYNAMIC 5-METRIC TRACKING */}
          {activeTab === 'documents' && (
            <div className="space-y-8 max-w-6xl mx-auto text-left animate-in fade-in duration-200">
              <div>
                <h2 className="text-2xl font-black text-neutral-900 tracking-tight">Documents Pipeline</h2>
                <p className="text-xs text-neutral-500 font-medium mt-0.5">Review and process active administrative requests</p>
              </div>

              {/* DYNAMIC PIPELINE MATRIX GRID */}
              <div className="grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-5 gap-4">
                {[
                  { title: 'Incoming Docs', count: incomingCount, border: 'border-l-blue-500', icon: '📂' },
                  { title: 'Awaiting Scan-In', count: awaitingScanInCount, border: 'border-l-red-600', icon: '📥' },
                  { title: 'Pending Docs', count: pendingCount, border: 'border-l-amber-500', icon: '🕒' },
                  { title: 'Completed Docs', count: completedProcessingCount, border: 'border-l-green-500', icon: '✅' },
                  { title: 'In Verification', count: inVerificationCount, border: 'border-l-purple-500', icon: '⚖️' }
                ].map((card, i) => (
                  <div key={i} className={`bg-white p-4 rounded-2xl border border-neutral-200 border-l-4 ${card.border} shadow-xs flex items-center justify-between`}>
                    <div className="space-y-1">
                      <span className="text-[9px] uppercase font-black text-neutral-400 tracking-wider block leading-tight">{card.title}</span>
                      <p className="text-2xl font-black text-neutral-900">{String(card.count).padStart(2, '0')}</p>
                    </div>
                    <div className="text-lg opacity-60 bg-neutral-50 p-2 rounded-xl border">{card.icon}</div>
                  </div>
                ))}
              </div>

              <div className="bg-white border border-neutral-200 rounded-2xl shadow-sm overflow-hidden">
                <div className="p-5 border-b border-neutral-100 flex flex-col sm:flex-row items-stretch sm:items-center justify-between gap-4">
                  <h3 className="text-sm font-black text-neutral-950 tracking-tight">Active Requests</h3>
                  <div className="flex flex-wrap items-center gap-3">
                    <div className="relative">
                      <Search className="absolute left-3 top-2.5 text-neutral-400" size={14} />
                      <input type="text" placeholder="Search by document title or ID..." value={search} onChange={e => { setSearch(e.target.value); setPipelinePage(1); }} className="pl-9 pr-4 py-2 text-xs border border-neutral-300 rounded-lg outline-none focus:ring-1 focus:ring-red-700 bg-neutral-50 w-56 font-medium" />
                    </div>
                    <div className="flex items-center gap-1 border border-neutral-300 rounded-lg px-2 py-1.5 bg-neutral-50">
                      <Filter size={14} className="text-neutral-400" />
                      <select value={filterStatus} onChange={e => { setFilterStatus(e.target.value); setPipelinePage(1); }} className="bg-transparent text-xs outline-none cursor-pointer font-bold text-neutral-600">
                        <option value="All">All Statuses</option>
                        <option value="Awaiting Scan-In">Awaiting Scan-In</option>
                        <option value="Pending">Pending</option>
                        <option value="In Verification">In Verification</option>
                        <option value="Completed">Completed</option>
                      </select>
                    </div>
                    <span className="text-[10px] font-black uppercase text-green-600 bg-green-50 px-2.5 py-1.5 rounded-lg border border-green-100 flex items-center gap-1.5">
                      <span className="w-1.5 h-1.5 bg-green-500 rounded-full animate-ping"></span> Real-time Updates On
                    </span>
                  </div>
                </div>

                <div className="overflow-x-auto">
                  <table className="w-full text-left text-xs border-collapse">
                    <thead>
                      <tr className="bg-neutral-50 text-neutral-400 border-b border-neutral-200 font-black uppercase text-[10px] tracking-wider">
                        {/* 🛠️ REMOVED THE w-2/5 WIDTH PROPERTY FOR BALANCED SPACING */}
                        <th className="p-4">Title</th>
                        <th className="p-4">Form Type</th>
                        <th className="p-4">Current Status</th>
                        <th className="p-4">Next Office</th>
                        <th className="p-4 text-center">Action</th>
                      </tr>
                    </thead>
                    <tbody className="divide-y divide-neutral-100 font-medium">
                      {currentPipeDocs.map((doc, index) => (
                        <tr key={index} className="hover:bg-neutral-50/70 transition-colors">
                          <td className="p-4">
                            <p className="font-bold text-neutral-950 text-sm leading-tight">{doc.title}</p>
                          </td>
                          <td className="p-4">
                            <span className="px-2 py-0.5 bg-neutral-100 text-neutral-700 border border-neutral-200 font-black text-[9px] uppercase rounded">
                              {doc.process_name}
                            </span>
                          </td>
                          <td className="p-4">
                            <span className={`inline-flex items-center gap-1.5 font-bold ${
                              doc.status?.toLowerCase() === 'completed' ? 'text-green-600' : doc.status?.toLowerCase() === 'in verification' ? 'text-red-600' : 'text-blue-500'
                            }`}>
                              <span className={`w-1.5 h-1.5 rounded-full ${
                                doc.status?.toLowerCase() === 'completed' ? 'bg-green-600' : doc.status?.toLowerCase() === 'in verification' ? 'bg-red-600' : 'bg-blue-500'
                              }`}></span>
                              {doc.status || 'Incoming'}
                            </span>
                          </td>
                          <td className="p-4 text-neutral-600 font-semibold">{doc.next_office || 'None (Final Stop)'}</td>
                          <td className="p-4 text-center">
                            <button onClick={() => handleOpenPipelineDetails(doc)} className="text-xs text-red-700 font-black hover:underline px-3 py-1 bg-red-50/50 hover:bg-red-50 rounded-lg transition-all">
                              View Details
                            </button>
                          </td>
                        </tr>
                      ))}
                    </tbody>
                  </table>
                  {filteredPipelineDocs.length === 0 && <div className="p-12 text-center text-neutral-400 font-medium">📭 No operational document streams registered to this network.</div>}
                </div>

                {totalPipePages > 1 && (
                  <div className="p-4 border-t border-neutral-100 bg-neutral-50/50 flex items-center justify-between text-xs px-6">
                    <span className="text-neutral-500 font-medium">Showing page <b>{pipelinePage}</b> of {totalPipePages}</span>
                    <div className="flex gap-1">
                      <button disabled={pipelinePage === 1} onClick={() => setPipelinePage(prev => prev - 1)} className="px-3 py-1.5 border rounded-lg bg-white font-bold text-neutral-600 hover:bg-neutral-50 disabled:opacity-40 transition-all">Previous</button>
                      <button disabled={pipelinePage === totalPipePages} onClick={() => setPipelinePage(prev => prev + 1)} className="px-3 py-1.5 border rounded-lg bg-white font-bold text-neutral-600 hover:bg-neutral-50 disabled:opacity-40 transition-all">Next</button>
                    </div>
                  </div>
                )}
              </div>
            </div>
          )}

          {/* TAB 3: PROFILE HUB */}
          {activeTab === 'profile' && (
            <div className="max-w-5xl mx-auto grid grid-cols-1 lg:grid-cols-3 gap-6 animate-in fade-in duration-200 text-left">
              <div className="lg:col-span-3 bg-white border border-neutral-200 p-6 rounded-2xl flex items-center gap-6 shadow-xs relative">
                <div className="relative">
                  <img src="https://images.unsplash.com/photo-1534528741775-53994a69daeb?auto=format&fit=crop&q=80&w=200" alt="Profile" className="w-24 h-24 rounded-2xl object-cover border-2 border-neutral-100 shadow-sm" />
                  <div className="absolute -bottom-1 -right-1 bg-red-700 p-1.5 rounded-lg text-white shadow-md cursor-pointer hover:scale-105 transition-transform"><Camera size={14} /></div>
                </div>
                <div className="space-y-1">
                  <div className="flex items-center gap-3">
                    <h3 className="text-xl font-black text-neutral-900">{profileName || 'Office Processor'}</h3>
                    <span className="px-2 py-0.5 bg-red-50 text-red-800 border border-red-100 rounded text-[9px] font-black uppercase tracking-wider">Processor</span>
                  </div>
                  <p className="text-xs text-neutral-400 font-medium flex items-center gap-1.5"><Building size={12} /> Faculty • {departmentName}</p>
                  <p className="text-xs text-green-600 font-bold flex items-center gap-1 mt-1"><span className="w-2 h-2 bg-green-500 rounded-full animate-pulse"></span> Active System Status</p>
                </div>
              </div>

              <div className="lg:col-span-2 space-y-6">
                <div className="bg-white border border-neutral-200 rounded-2xl p-6 shadow-xs">
                  <div className="flex items-center gap-2 border-b border-neutral-100 pb-3 mb-4">
                    <User size={16} className="text-red-700" />
                    <h4 className="text-xs uppercase font-black text-neutral-900 tracking-wider">Personal Information</h4>
                  </div>
                  <form onSubmit={handleUpdateProfile} className="space-y-4">
                    <div className="grid grid-cols-1 sm:grid-cols-2 gap-4">
                      <div>
                        <label className="block text-[10px] font-black text-neutral-400 uppercase mb-1 tracking-wide">Full Name</label>
                        <input type="text" required value={profileName} onChange={e => setProfileName(e.target.value)} className="w-full px-4 py-2 text-xs border border-neutral-300 rounded-xl focus:ring-1 focus:ring-red-700 outline-none bg-neutral-50 font-bold text-neutral-800 transition-all" />
                      </div>
                      <div>
                        <label className="block text-[10px] font-black text-neutral-400 uppercase mb-1 tracking-wide">University Email</label>
                        <input type="email" required value={profileEmail} onChange={e => setProfileEmail(e.target.value)} className="w-full px-4 py-2 text-xs border border-neutral-300 rounded-xl focus:ring-1 focus:ring-red-700 outline-none bg-neutral-50 font-bold text-neutral-800 transition-all" />
                      </div>
                    </div>
                    <div className="flex justify-end pt-2">
                      <button type="submit" className="px-4 py-2 bg-neutral-900 hover:bg-black text-white font-bold text-xs rounded-xl transition-all shadow-xs uppercase tracking-wide">Save Changes</button>
                    </div>
                  </form>
                </div>

                <div className="bg-white border border-neutral-200 rounded-2xl p-6 shadow-xs space-y-4">
                  <div className="flex items-center gap-2 border-b border-neutral-100 pb-3 mb-2">
                    <ShieldCheck size={16} className="text-red-700" />
                    <h4 className="text-xs uppercase font-black text-neutral-900 tracking-wider">Account Security</h4>
                  </div>
                  <div className="border border-neutral-200 rounded-xl p-4 flex items-center justify-between hover:bg-neutral-50/50 transition-colors">
                    <div>
                      <h5 className="text-xs font-black text-neutral-900">Change Password</h5>
                      <p className="text-[11px] text-neutral-400 mt-0.5 font-medium">Update your system login credentials regularly.</p>
                    </div>
                    <button onClick={() => setShowPassModal(true)} className="text-xs font-black text-red-700 hover:text-red-800 hover:underline transition-all">Update</button>
                  </div>

                  <div className="border border-neutral-200 rounded-xl p-4 flex flex-col gap-4 hover:bg-neutral-50/50 transition-colors">
                    <div className="flex items-center justify-between">
                      <div>
                        <h5 className="text-xs font-black text-neutral-900">Two-Factor Authentication (2FA)</h5>
                        <p className="text-[11px] text-neutral-400 mt-0.5 font-medium">Secure your account access with a secondary pin prompt.</p>
                      </div>
                      <label className="relative inline-flex items-center cursor-pointer select-none">
                        <input type="checkbox" checked={twoFaEnabled} onChange={e => toggle2FA(e.target.checked)} className="sr-only peer" />
                        <div className="w-11 h-6 bg-neutral-200 peer-focus:outline-none rounded-full peer peer-checked:after:translate-x-full peer-checked:after:border-white after:content-[''] after:absolute after:top-[2px] after:left-[2px] after:bg-white after:border-neutral-300 after:border after:rounded-full after:h-5 after:w-5 after:transition-all peer-checked:bg-red-700"></div>
                      </label>
                    </div>
                    {twoFaEnabled && (
                      <form onSubmit={handleSaveCustomPin} className="border-t border-dashed border-neutral-200 pt-3 space-y-2 animate-in slide-in-from-top-1 duration-150">
                        <label className="block text-[10px] font-black text-neutral-400 uppercase tracking-wide">Set Your Custom Numeric Security Code PIN</label>
                        <div className="flex items-center gap-2">
                          <input type="text" maxLength={6} required placeholder="Enter 4-6 digit numeric pin code" value={twoFaCode} onChange={e => setTwoFaCode(e.target.value.replace(/\D/g, ''))} className="w-full max-w-xs px-4 py-2 text-xs border border-neutral-300 rounded-xl focus:ring-1 focus:ring-red-700 outline-none bg-white font-mono tracking-widest text-neutral-800" />
                          <button type="submit" className="px-4 py-2 bg-neutral-900 hover:bg-black text-white font-bold text-xs rounded-xl transition-all shadow-xs uppercase tracking-wide">Save PIN</button>
                        </div>
                      </form>
                    )}
                  </div>
                </div>
              </div>

              <div className="space-y-6">
                <div className="bg-white border border-neutral-200 rounded-2xl p-6 shadow-xs">
                  <div className="flex items-center gap-2 border-b border-neutral-100 pb-3 mb-4">
                    <Landmark size={16} className="text-neutral-500" />
                    <h4 className="text-xs uppercase font-black text-neutral-900 tracking-wider">Institutional Details</h4>
                  </div>
                  <div className="space-y-4 text-xs">
                    <div>
                      <span className="text-[9px] font-black text-neutral-400 uppercase tracking-wide block">Faculty ID</span>
                      <p className="font-black text-neutral-900 text-sm mt-0.5">{facultyId}</p>
                    </div>
                    <div>
                      <span className="text-[9px] font-black text-neutral-400 uppercase tracking-wide block">Assigned Campus Unit</span>
                      <p className="font-bold text-neutral-700 mt-0.5">{processorOfficeName}</p>
                    </div>
                  </div>
                </div>
                <div className="bg-red-50/40 border border-red-100 rounded-2xl p-4">
                  <p className="text-[11px] leading-relaxed text-neutral-500 font-medium">ℹ️ <span className="font-bold text-neutral-800">Institutional data variables</span> are managed natively by the university registry database. Contact <span className="text-red-700 font-bold hover:underline cursor-pointer">ICT Support</span> for details.</p>
                </div>
              </div>
            </div>
          )}

          {activeTab === 'history' && <div className="text-center py-12 text-neutral-400">📜 Processing checkout transaction logs history coming next.</div>}
        </div>
      </div>

      {/* MODAL 1: LIVE SCANNER OVERLAY */}
      {showScannerModal && (
        <div className="fixed inset-0 bg-neutral-950/40 backdrop-blur-xs flex items-center justify-center p-4 z-50 animate-in fade-in duration-100">
          <div className="bg-white w-full max-w-sm rounded-2xl border shadow-2xl p-6 text-center space-y-4">
            <div className="w-12 h-12 bg-red-50 text-red-800 rounded-full flex items-center justify-center mx-auto text-xl">📷</div>
            <div>
              <h4 className="font-bold text-neutral-900 text-base">Simulated QR Scanner Camera</h4>
              <p className="text-xs text-neutral-400 mt-1">Simulate scanning a token to perform automated validation checks.</p>
            </div>
            <div className="bg-neutral-100 p-2 rounded-xl flex border font-bold text-xs">
              <button type="button" onClick={() => setScanMode('time-in')} className={`w-1/2 py-1.5 rounded-lg transition-all uppercase ${scanMode === 'time-in' ? 'bg-white text-red-800 shadow-xs' : 'text-neutral-400'}`}>Time-In</button>
              <button type="button" onClick={() => setScanMode('time-out')} className={`w-1/2 py-1.5 rounded-lg transition-all uppercase ${scanMode === 'time-out' ? 'bg-white text-red-800 shadow-xs' : 'text-neutral-400'}`}>Time-Out</button>
            </div>
            <form onSubmit={executeSimulatedScanner} className="space-y-3">
              <input type="text" required placeholder="Paste or Type Tracking Token (e.g., TRK-...)" value={simulatedQrInput} onChange={e => setSimulatedQrPayload(e.target.value)} className="w-full border px-3 py-2 text-xs font-mono text-center rounded-lg focus:ring-1 focus:ring-red-700 outline-none" />
              <div className="flex gap-2 pt-2">
                <button type="button" onClick={() => { setShowScannerModal(false); setSimulatedQrPayload(''); }} className="w-1/2 border py-2 text-xs font-bold text-gray-500 rounded-xl hover:bg-neutral-50">Cancel</button>
                <button type="submit" className="w-1/2 bg-red-800 hover:bg-red-900 text-white text-xs font-bold rounded-xl shadow-sm uppercase tracking-wide">Execute Scan</button>
              </div>
            </form>
          </div>
        </div>
      )}

      {/* MODAL 2: DASHBOARD DETAIL OVERVIEW */}
      {showDetailsModal && selectedDoc && (
        <div className="fixed inset-0 bg-neutral-950/40 backdrop-blur-xs flex items-center justify-center p-4 z-50">
          <div className="bg-white w-full max-w-lg rounded-2xl shadow-2xl border overflow-hidden flex flex-col text-left">
            <div className="p-4 border-b bg-[#FDFBF9] flex items-center justify-between">
              <h3 className="font-bold text-neutral-900 text-sm">Document Tracking Details</h3>
              <button onClick={() => setShowDetailsModal(false)} className="text-neutral-400 hover:text-neutral-600"><X size={16} /></button>
            </div>
            <div className="p-6 space-y-6 overflow-y-auto max-h-[70vh]">
              <div className="flex justify-between items-start gap-4">
                <div className="space-y-3 flex-1">
                  <div>
                    <span className="text-[9px] font-black text-neutral-400 uppercase tracking-wider block">Document Title</span>
                    <h4 className="text-base font-black text-neutral-900 leading-tight">{selectedDoc.title}</h4>
                  </div>
                  <div className="grid grid-cols-2 gap-2 text-xs">
                    <div><span className="text-[9px] font-bold text-neutral-400 uppercase block">Reference ID</span><p className="font-mono font-bold text-red-800">{selectedDoc.qr_code}</p></div>
                    <div><span className="text-[9px] font-bold text-neutral-400 uppercase block">Form Type</span><p className="font-bold text-neutral-700">{selectedDoc.process_name}</p></div>
                  </div>
                  <div>
                    <span className="text-[9px] font-bold text-neutral-400 uppercase block">Current Status</span>
                    <span className="px-2.5 py-0.5 mt-1 bg-red-50 text-red-800 border rounded-full font-black text-[9px] uppercase tracking-wider inline-block">{selectedDoc.status || 'Active Path'}</span>
                  </div>
                </div>
                <div className="bg-neutral-50 p-2 border rounded-xl text-center flex-shrink-0">
                  <QrCode size={70} className="text-neutral-800" />
                </div>
              </div>
              <div className="pt-4 border-t text-left">
                <span className="text-[9px] font-black text-neutral-400 uppercase tracking-wider block mb-4">Submission Route Status</span>
                <div className="relative pl-6 space-y-4">
                  <div className="absolute left-[5px] top-1 bottom-1 w-0.5 bg-neutral-200"></div>
                  {getRouteStopsArray(selectedDoc).map((stop, i) => {
                    const isCurrent = stop === selectedDoc.current_office;
                    return (
                      <div key={i} className="relative flex flex-col">
                        <div className={`absolute -left-[24px] top-0.5 w-3 h-3 rounded-full border-2 bg-white ${isCurrent ? 'border-red-700 bg-red-700 ring-4 ring-red-100' : 'border-neutral-300'}`} />
                        <p className={`text-xs font-bold ${isCurrent ? 'text-red-800' : 'text-neutral-700'}`}>{stop}</p>
                      </div>
                    );
                  })}
                </div>
              </div>
            </div>
            <div className="p-4 border-t bg-neutral-50/50 flex justify-end gap-2">
              <button onClick={() => setShowDetailsModal(false)} className="px-4 py-2 border rounded-xl text-xs font-bold text-gray-500 hover:bg-neutral-100">Close</button>
            </div>
          </div>
        </div>
      )}

      {/* MODAL 3: DOCUMENTS PIPELINE VERIFICATION DETAILS */}
      {showPipelineModal && selectedDoc && (
        <div className="fixed inset-0 bg-neutral-950/40 backdrop-blur-xs flex items-center justify-center p-4 z-50 animate-in fade-in duration-150">
          <div className="bg-white w-full max-w-xl rounded-3xl shadow-2xl border overflow-hidden flex flex-col text-left">
            <div className="p-5 border-b bg-[#FDFBF9] flex items-center justify-between">
              <h3 className="font-bold text-neutral-900 text-sm">Document Verification Detail</h3>
              <button onClick={() => setShowPipelineModal(false)} className="text-neutral-400 hover:text-neutral-600"><X size={16} /></button>
            </div>
            
            <div className="p-6 grid grid-cols-1 md:grid-cols-2 gap-6 items-stretch">
              <div className="space-y-5 flex flex-col justify-between">
                <div className="space-y-4">
                  <div>
                    <span className="text-[9px] font-black text-neutral-400 uppercase tracking-wider block">Reference Number</span>
                    <h4 className="text-sm font-black text-red-800 font-mono tracking-wide mt-0.5">{selectedDoc.qr_code}</h4>
                  </div>
                  <div>
                    <span className="text-[9px] font-black text-neutral-400 uppercase tracking-wider block">Subject</span>
                    <p className="text-xs font-bold text-neutral-700 leading-normal mt-0.5">{selectedDoc.title}</p>
                  </div>

                  <div className="grid grid-cols-2 gap-y-3 gap-x-2 text-xs border-t border-b border-neutral-100 py-3">
                    <div>
                      <span className="text-[9px] font-black text-neutral-400 uppercase tracking-wider block">Origin</span>
                      <p className="font-bold text-neutral-800 mt-0.5">{selectedDoc.originating_office || 'University Unit'}</p>
                    </div>
                    <div>
                      <span className="text-[9px] font-black text-neutral-400 uppercase tracking-wider block">Target Delivery</span>
                      <p className="font-bold text-neutral-500 mt-0.5">
                        {selectedDoc.edc ? new Date(selectedDoc.edc).toLocaleDateString('en-US', { month: 'short', day: 'numeric', year: 'numeric' }) : 'N/A'}
                      </p>
                    </div>
                    <div>
                      <span className="text-[9px] font-black text-neutral-400 uppercase tracking-wider block">Time-In Arrival</span>
                      <p className="font-mono text-[11px] font-bold mt-0.5 text-neutral-700">
                        {selectedDoc.time_in ? (
                          new Date(selectedDoc.time_in).toLocaleTimeString('en-US', { hour: '2-digit', minute: '2-digit', second: '2-digit' })
                        ) : (
                          <span className="text-red-600 bg-red-50 px-1.5 py-0.5 rounded text-[9px] font-black tracking-wide uppercase">Awaiting Scan</span>
                        )}
                      </p>
                    </div>
                    <div>
                      <span className="text-[9px] font-black text-neutral-400 uppercase tracking-wider block">Time-Out Release</span>
                      <p className="font-mono text-[11px] font-bold mt-0.5 text-neutral-700">
                        {selectedDoc.time_out ? (
                          new Date(selectedDoc.time_out).toLocaleTimeString('en-US', { hour: '2-digit', minute: '2-digit', second: '2-digit' })
                        ) : (
                          <span className="text-amber-600 bg-amber-50 px-1.5 py-0.5 rounded text-[9px] font-black tracking-wide uppercase">In Progress</span>
                        )}
                      </p>
                    </div>
                  </div>
                </div>

                <div className="bg-red-50/30 border border-red-100 p-4 rounded-2xl">
                  <span className="text-[9px] font-black text-red-800 uppercase tracking-wider block mb-3">📋 Routing Status</span>
                  <div className="flex items-center justify-between text-[10px] font-black text-neutral-600 relative px-1">
                    {getRouteStopsArray(selectedDoc).slice(0, 4).map((stop, i) => {
                      const isCurrent = stop === selectedDoc.current_office;
                      return (
                        <div key={i} className="flex flex-col items-center relative z-10">
                          <div className={`w-5 h-5 rounded-full flex items-center justify-center border-2 font-mono text-[9px] ${
                            isCurrent ? 'bg-red-700 text-white border-red-700 ring-4 ring-red-100' : 'bg-white text-neutral-400 border-neutral-300'
                          }`}>
                            {i + 1}
                          </div>
                          <span className={`text-[8px] mt-1 tracking-tight max-w-[50px] text-center truncate font-bold ${isCurrent ? 'text-red-800 font-black' : 'text-neutral-400'}`}>
                            {stop.replace('Office', '').trim()}
                          </span>
                        </div>
                      );
                    })}
                    <div className="absolute left-4 right-4 top-2.5 h-0.5 bg-neutral-200 -z-10"></div>
                  </div>
                </div>
              </div>

              <div className="border border-neutral-200 rounded-2xl p-5 bg-neutral-50/50 flex flex-col justify-between items-center text-center">
                <span className="text-[9px] font-black text-neutral-400 uppercase tracking-wider">Security QR Identity</span>
                <div className="bg-white p-4 border border-neutral-200 rounded-2xl shadow-xs my-3">
                  <QrCode size={110} className="text-red-900" />
                </div>
                <p className="text-[10px] text-neutral-400 leading-normal max-w-[180px] font-medium">Scan to verify authenticity on any authorized workstation.</p>
                
                {selectedDoc.time_in ? (
                    <form onSubmit={handleExecuteAdHocDetour} className="w-full mt-4 border-t border-dashed border-neutral-200 pt-4 space-y-2 text-left">
                      <label className="block text-[9px] font-black text-neutral-400 uppercase tracking-wider">
                        Request Ad-hoc Verification Detour
                      </label>
                      <div className="flex flex-col gap-2">
                        <select 
                          required 
                          value={selectedAdHocOffice} 
                          onChange={e => setSelectedAdHocOffice(e.target.value)}
                          className="w-full bg-white border border-neutral-300 rounded-xl px-3 py-2 text-xs outline-none focus:ring-1 focus:ring-red-700 font-bold text-neutral-700 cursor-pointer"
                        >
                          <option value="">-- Select Destination Office --</option>
                          {officesList.map((off, idx) => (
                            off.id !== processorOfficeId && <option key={idx} value={off.id}>{off.name}</option>
                          ))}
                        </select>
                        
                        <button 
                          type="submit" 
                          disabled={isAdHocProcessing}
                          className="w-full py-2.5 bg-red-800 hover:bg-red-900 disabled:bg-neutral-400 text-white text-xs font-black rounded-xl flex items-center justify-center gap-2 transition-all uppercase tracking-wider shadow-xs"
                        >
                          {isAdHocProcessing ? 'Processing Detour...' : '🛡️ Route Ad-hoc Verification'}
                        </button>
                      </div>
                    </form>
                  ) : (
                    <div className="w-full mt-4 border-t border-dashed border-neutral-200 pt-4 text-center">
                      <p className="text-[10px] font-black text-red-700 bg-red-50/70 border border-red-100 rounded-xl p-3 uppercase tracking-wide">
                        🛑 Ad-Hoc Detour Unavailable: Document must be scanned for Time-In at your office first.
                      </p>
                    </div>
                  )}
              </div>
            </div>

            <div className="p-4 border-t bg-neutral-50/50 flex justify-end">
              <button onClick={() => setShowPipelineModal(false)} className="px-5 py-2 border rounded-xl text-xs font-bold text-gray-500 hover:bg-neutral-100 transition-colors">Close</button>
            </div>
          </div>
        </div>
      )}

      {/* MODAL 4: PASSWORD RE-AUTHENTICATOR */}
      {showPassModal && (
        <div className="fixed inset-0 bg-neutral-950/40 backdrop-blur-xs flex items-center justify-center p-4 z-50 animate-in fade-in duration-150">
          <div className="bg-white w-full max-w-sm rounded-2xl shadow-xl border overflow-hidden flex flex-col text-left">
            <div className="p-4 border-b bg-[#FDFBF9] flex items-center justify-between">
              <h3 className="font-bold text-neutral-900 text-sm flex items-center gap-2"><KeyRound size={16} className="text-red-700" /> Change Password</h3>
              <button onClick={() => setShowPassModal(false)} className="text-neutral-400 hover:text-neutral-600"><X size={16} /></button>
            </div>
            <form onSubmit={handleUpdatePassword} className="p-5 space-y-4 text-xs">
              <div>
                <label className="block text-[10px] font-bold text-gray-500 uppercase mb-1">Current Password</label>
                <input type="password" required value={currentPassword} onChange={e => setCurrentPassword(e.target.value)} className="w-full px-4 py-2 border border-neutral-300 rounded-lg focus:ring-1 focus:ring-red-700 outline-none bg-neutral-50 font-medium" />
              </div>
              <div>
                <label className="block text-[10px] font-bold text-gray-500 uppercase mb-1">New Password</label>
                <input type="password" required value={newPassword} onChange={e => setNewPassword(e.target.value)} className="w-full px-4 py-2 border border-neutral-300 rounded-lg focus:ring-1 focus:ring-red-700 outline-none bg-neutral-50 font-medium" />
              </div>
              <div>
                <label className="block text-[10px] font-bold text-gray-500 uppercase mb-1">Confirm New Password</label>
                <input type="password" required value={confirmPassword} onChange={e => setConfirmPassword(e.target.value)} className="w-full px-4 py-2 border border-neutral-300 rounded-lg focus:ring-1 focus:ring-red-700 outline-none bg-neutral-50 font-medium" />
              </div>
              <div className="flex justify-end gap-2 pt-2 border-t">
                <button type="button" onClick={() => setShowPassModal(false)} className="px-4 py-2 border rounded-xl font-bold text-gray-500 hover:bg-neutral-50">Cancel</button>
                <button type="submit" className="px-4 py-2 bg-red-700 hover:bg-red-800 text-white font-bold rounded-xl shadow-xs uppercase tracking-wide">Update Password</button>
              </div>
            </form>
          </div>
        </div>
      )}

    </div>
  );
}