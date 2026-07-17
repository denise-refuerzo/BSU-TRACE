import React, { useState, useEffect, useRef } from 'react';
import { useNavigate } from 'react-router-dom';
import Swal from 'sweetalert2';
import { QRCodeSVG } from 'qrcode.react';
import { 
  LayoutDashboard, 
  FileText, 
  History, 
  Bell, 
  User, 
  Search, 
  Filter, 
  X, 
  QrCode, 
  LogOut, 
  Eye, 
  GitBranch,
  Camera,
  KeyRound,
  ShieldCheck,
  Building,
  Landmark
} from 'lucide-react';
import { fetchWithAuth } from '../api';

const minimalSwal = Swal.mixin({
  customClass: {
    confirmButton: 'px-6 py-2.5 rounded-xl text-xs font-black uppercase tracking-wider text-white bg-red-800 hover:bg-red-900 shadow-md mx-2',
    cancelButton: 'px-6 py-2.5 rounded-xl text-xs font-bold uppercase tracking-wider text-neutral-600 border border-neutral-200 bg-white hover:bg-neutral-50 mx-2',
    popup: 'rounded-3xl border border-neutral-100 shadow-2xl',
    title: 'text-lg font-black text-neutral-900',
    htmlContainer: 'text-sm font-medium text-neutral-500'
  },
  buttonsStyling: false
});

export default function SigneeDashboard() {
  const navigate = useNavigate();
  const notificationRef = useRef(null);
  
  const userId = localStorage.getItem('userId');
  const userName = localStorage.getItem('user') || 'Office Signee';
  
  const [activeTab, setActiveTab] = useState('dashboard');
  const [showNotifications, setShowNotifications] = useState(false);
  const [notifications, setNotifications] = useState([]);
  
  const [pipelineDocs, setPipelineDocs] = useState([]);  
  const [processTypes, setProcessTypes] = useState([]);
  const [officesList, setOfficesList] = useState([]);
  const [actionHistory, setActionHistory] = useState([]);
  const [isHistoryDetails, setIsHistoryDetails] = useState(false);
  
  const [profileName, setProfileName] = useState('');
  const [profileEmail, setProfileEmail] = useState('');
  const [facultyId, setFacultyId] = useState('N/A');
  const [departmentName, setDepartmentName] = useState('N/A');
  const [twoFaEnabled, setTwoFaEnabled] = useState(false);
  const [twoFaCode, setTwoFaCode] = useState('');
  
  const [currentPassword, setCurrentPassword] = useState('');
  const [newPassword, setNewPassword] = useState('');
  const [confirmPassword, setConfirmPassword] = useState('');

  const [selectedDoc, setSelectedDoc] = useState(null);
  const [showDetailsModal, setShowDetailsModal] = useState(false);
  const [showAdHocForm, setShowAdHocForm] = useState(false);
  const [showSendBackForm, setShowSendBackForm] = useState(false);
  const [showPassModal, setShowPassModal] = useState(false);
  const [returnReason, setReturnReason] = useState('');
  const [selectedAdHocOffice, setSelectedAdHocOffice] = useState('');
  const [isActionProcessing, setIsActionProcessing] = useState(false);

  const [search, setSearch] = useState('');
  const [filterStatus, setFilterStatus] = useState('All'); 
  const [historyFilter, setHistoryFilter] = useState('All');
  const [signeeOfficeName, setSigneeOfficeName] = useState('Loading Office...');
  const [signeeOfficeId, setSigneeOfficeId] = useState(null);

  const [dashboardPage, setDashboardPage] = useState(1);
  const [pipelinePage, setPipelinePage] = useState(1);
  const [historyPage, setHistoryPage] = useState(1);
  const itemsPerPage = 5;

  useEffect(() => {
    if (!userId || userId === 'undefined') {
      localStorage.clear();
      navigate('/login');
      return;
    }
    fetchSigneeMeta();
    fetchWorkflowTemplates();
    fetchOfficesList();
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

  const handleLogout = () => {
    minimalSwal.fire({
      title: 'Sign Out?',
      text: 'Are you sure you want to securely end your session?',
      icon: 'question',
      showCancelButton: true,
      confirmButtonText: 'Yes, Sign Out'
    }).then((result) => {
      if (result.isConfirmed) {
        localStorage.clear();
        navigate('/login');
      }
    });
  };

  const fetchLiveNotificationFeeds = async () => {
    if (!signeeOfficeId) return;
    try {
      const res = await fetchWithAuth(`http://localhost:5000/api/notifications/${userId}/3/${signeeOfficeId}`);
      const data = await res.json();
      if (res.ok) {
        setNotifications(data.map(n => ({
          id: n.id,
          title: n.title,
          message: n.message,
          time: new Date(n.time).toLocaleTimeString('en-US', { hour: '2-digit', minute: '2-digit', hour12: true })
        })));
      }
    } catch (err) { 
      console.error(err); 
    }
  };

  const fetchSigneeMeta = async () => {
    try {
      const res = await fetchWithAuth(`http://localhost:5000/api/profile/${userId}`);
      const data = await res.json();
      if (res.ok) {
        setSigneeOfficeName(data.office_name || 'CICS Office');
        setSigneeOfficeId(data.o_id);
        
        setProfileName(data.full_name || '');
        setProfileEmail(data.uni_email || '');
        setFacultyId(data.faculty_id || 'NOT ASSIGNED');
        setDepartmentName(data.department_name || 'CICS');
        setTwoFaEnabled(data.two_fa_enabled || false);
        setTwoFaCode(data.two_fa_code || '');

        fetchPipelineDocs(data.o_id);
        fetchOfficeActionHistory(data.o_id);
      }
    } catch (err) { 
      console.error("Error connecting metadata:", err); 
    }
  };

  const fetchPipelineDocs = async (officeId) => {
    if (!officeId) return;
    try {
      const res = await fetchWithAuth(`http://localhost:5000/api/processor/documents/pipeline/${officeId}`);
      const data = await res.json();
      if (res.ok) {
        setPipelineDocs(data);
        const pendingCount = data.filter(d => d.status?.toLowerCase() === 'pending' && !d.time_out).length;
        if (pendingCount > 0) {
          // Grab the time_in value from the first pending document entry row
          const firstPending = data.find(d => d.status?.toLowerCase() === 'pending' && !d.time_out);
          setNotifications([
            { 
              id: 1, 
              title: "Action Required", 
              message: `You have ${pendingCount} incoming files waiting for signature approval.`, 
              time: firstPending ? firstPending.time_in : new Date().toISOString() // Dynamic mapping fallback[cite: 6]
            }
          ]);
        }
      }
    } catch (err) { console.error("Pipeline sync error:", err); }
  };

  const fetchOfficeActionHistory = async (officeId) => {
    if (!officeId) return;
    try {
      const res = await fetchWithAuth(`http://localhost:5000/api/processor/history/${officeId}`);
      const data = await res.json();
      if (res.ok) setActionHistory(data);
    } catch (err) { console.error("History transaction log retrieval error:", err); }
  };

  const fetchWorkflowTemplates = async () => {
    try {
      const res = await fetchWithAuth('http://localhost:5000/api/process-types');
      const data = await res.json();
      if (res.ok) setProcessTypes(data);
    } catch (err) { console.error(err); }
  };

  const fetchOfficesList = async () => {
    try {
      const res = await fetchWithAuth('http://localhost:5000/api/offices'); 
      const data = await res.json();
      if (res.ok) setOfficesList(data);
    } catch (err) { console.error("Error building office lookup:", err); }
  };

  const handleUpdateProfile = async (e) => {
    e.preventDefault();
    try {
      const res = await fetchWithAuth(`http://localhost:5000/api/profile/${userId}`, {
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
        minimalSwal.fire({ icon: 'success', title: 'Profile Updated', text: 'Profile settings updated.' });
        localStorage.setItem('user', profileName);
        fetchSigneeMeta();
      }
    } catch (err) { 
      minimalSwal.fire({ icon: 'error', title: 'Error', text: 'Failed to synchronize profile changes.' }); 
    }
  };

  const handleUpdatePassword = async (e) => {
    e.preventDefault();
    if (newPassword !== confirmPassword) {
      return minimalSwal.fire({ icon: 'warning', title: 'Mismatch', text: 'New passwords do not match.' });
    }
    try {
      const res = await fetchWithAuth(`http://localhost:5000/api/profile/${userId}/password`, {
        method: 'PUT',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ currentPassword, newPassword })
      });
      const data = await res.json();
      if (res.ok) {
        minimalSwal.fire({ icon: 'success', title: 'Password Updated', text: 'Security credentials updated cleanly.' });
        setShowPassModal(false);
        setCurrentPassword('');
        setNewPassword('');
        setConfirmPassword('');
      } else {
        minimalSwal.fire({ icon: 'error', title: 'Error', text: data.error || 'Password update rejected.' });
      }
    } catch (err) { 
      minimalSwal.fire({ icon: 'error', title: 'Error', text: 'Failed to modify database records.' }); 
    }
  };

  const toggle2FA = async (checked) => {
    setTwoFaEnabled(checked);
    if (!checked) {
      try {
        const res = await fetchWithAuth(`http://localhost:5000/api/profile/${userId}`, {
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
          minimalSwal.fire({ icon: 'info', title: 'Security Update', text: 'Two-Factor PIN verification disabled.' });
        }
      } catch (err) { console.error(err); }
    }
  };

  const handleSaveCustomPin = async (e) => {
    e.preventDefault();
    if (twoFaCode.length < 4 || twoFaCode.length > 6 || isNaN(twoFaCode)) {
      return minimalSwal.fire({ icon: 'warning', title: 'Invalid PIN', text: 'PIN must be a 4-6 digit numeric code.' });
    }
    try {
      const res = await fetchWithAuth(`http://localhost:5000/api/profile/${userId}`, {
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
        minimalSwal.fire({ icon: 'success', title: 'PIN Configured', text: 'Custom security authentication PIN configured.' });
        fetchSigneeMeta();
      }
    } catch (err) { minimalSwal.fire({ icon: 'error', title: 'Error', text: 'Failed to update credentials security PIN.' }); }
  };

  const handleOpenDetails = (doc, fromHistory = false) => {
    setSelectedDoc(doc);
    setIsHistoryDetails(fromHistory);
    setShowSendBackForm(false);
    setShowAdHocForm(false);
    setReturnReason('');
    setSelectedAdHocOffice('');
    setShowDetailsModal(true);
  };

  const handleSignDocument = async () => {
    if (!selectedDoc) return;

    minimalSwal.fire({
      title: 'Confirm Signature',
      text: `This will certify "${selectedDoc.title || selectedDoc.document_title}" and advance it to the next office stage.`,
      icon: 'warning',
      showCancelButton: true,
      confirmButtonText: 'Yes, Sign Document',
      cancelButtonText: 'Cancel'
    }).then(async (result) => {
      if (result.isConfirmed) {
        setIsActionProcessing(true);
        try {
          const res = await fetchWithAuth(`http://localhost:5000/api/signee/sign`, {
            method: 'POST',
            headers: { 'Content-Type': 'application/json' },
            body: JSON.stringify({
              iniId: selectedDoc.ini_id,
              currentOfficeId: signeeOfficeId,
              signeeUserId: parseInt(userId)
            })
          });
          
          if (res.ok) {
            minimalSwal.fire({ icon: 'success', title: 'Successfully Signed!', text: 'The document identity seal has been committed. Processors can now check it out.' });
            setShowDetailsModal(false);
            fetchSigneeMeta();
          }
        } catch (err) {
          minimalSwal.fire({ icon: 'error', title: 'Error', text: 'Failed sequence commitment tracking link.' });
        } finally {
          setIsActionProcessing(false);
        }
      }
    });
  };

  const handleExecuteReturn = async (e) => {
    e.preventDefault();
    if (!returnReason.trim()) return;

    setIsActionProcessing(true);
    try {
      const res = await fetchWithAuth(`http://localhost:5000/api/signee/return`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({
          iniId: selectedDoc.ini_id,
          currentOfficeId: signeeOfficeId,
          signeeUserId: parseInt(userId),
          reason: returnReason
        })
      });

      if (res.ok) {
        minimalSwal.fire({ icon: 'success', title: 'Document Sent Back', text: 'The file has been frozen with Action Required status flags.' });
        setShowDetailsModal(false);
        fetchSigneeMeta();
      }
    } catch (err) {
      minimalSwal.fire({ icon: 'error', title: 'Error', text: 'Failed to commit document updates.' });
    } finally {
      setIsActionProcessing(false);
    }
  };

  const handleExecuteAdHocDetour = async (e) => {
    e.preventDefault();
    if (!selectedAdHocOffice) {
      return minimalSwal.fire({ icon: 'warning', title: 'Required', text: 'Please select a destination campus unit.' });
    }
    
    setIsActionProcessing(true);
    try {
      const res = await fetchWithAuth('http://localhost:5000/api/processor/documents/ad-hoc', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({
          iniId: selectedDoc.ini_id,
          targetOfficeId: parseInt(selectedAdHocOffice),
          currentOfficeId: signeeOfficeId,
          executorUserId: parseInt(userId)
        })
      });
      if (res.ok) {
        minimalSwal.fire({ icon: 'success', title: 'Detour Routed', text: 'Ad-hoc validation checkpoint successfully injected.' });
        setShowDetailsModal(false);
        fetchSigneeMeta();
      }
    } catch (err) { 
      minimalSwal.fire({ icon: 'error', title: 'Error', text: 'Ad-hoc communication assignment breakdown.' }); 
    } finally { 
      setIsActionProcessing(false); 
    }
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

  const pendingDocsList = pipelineDocs.filter(d => d.status?.toLowerCase() === 'pending' && !d.time_out);
  const signedDocsList = pipelineDocs.filter(d => d.status?.toLowerCase() === 'signed' || d.status?.toLowerCase() === 'completed');
  const verificationDocsList = pipelineDocs.filter(d => 
    d.status?.toLowerCase() === 'in verification' || 
    ((d.current_step_is_adhoc || d.is_adhoc) && d.current_office !== signeeOfficeName)
  );
  const sentBackDocsList = pipelineDocs.filter(d => d.status?.toLowerCase() === 'action required');

  const filteredDashDocs = pendingDocsList.filter(doc => 
    doc.title?.toLowerCase().includes(search.toLowerCase()) || doc.qr_code?.toLowerCase().includes(search.toLowerCase())
  );

  const filteredPipelineDocs = pipelineDocs.filter(doc => {
    const matchesSearch = doc.title?.toLowerCase().includes(search.toLowerCase()) || doc.qr_code?.toLowerCase().includes(search.toLowerCase());
    if (filterStatus === 'Pending') return matchesSearch && doc.status?.toLowerCase() === 'pending' && !doc.time_out;
    if (filterStatus === 'Signed') return matchesSearch && (doc.status?.toLowerCase() === 'signed' || doc.status?.toLowerCase() === 'completed');
    if (filterStatus === 'In Verification') return matchesSearch && (doc.status?.toLowerCase() === 'in verification' || ((doc.current_step_is_adhoc || doc.is_adhoc) && doc.current_office !== signeeOfficeName));    
    if (filterStatus === 'Action Required') return matchesSearch && doc.status?.toLowerCase() === 'action required';
    return matchesSearch;
  });

  const filteredHistoryLogs = actionHistory.filter(log => {
    const matchesSearch = log.title?.toLowerCase().includes(search.toLowerCase()) || log.full_name?.toLowerCase().includes(search.toLowerCase()) || log.qr_code?.toLowerCase().includes(search.toLowerCase());
    return historyFilter !== 'All' ? (matchesSearch && log.action_type === historyFilter) : matchesSearch;
  });

  const currentDashDocs = filteredDashDocs.slice((dashboardPage - 1) * itemsPerPage, dashboardPage * itemsPerPage);
  const totalDashPages = Math.ceil(filteredDashDocs.length / itemsPerPage);

  const currentPipeDocs = filteredPipelineDocs.slice((pipelinePage - 1) * itemsPerPage, pipelinePage * itemsPerPage);
  const totalPipePages = Math.ceil(filteredPipelineDocs.length / itemsPerPage);

  const currentHistoryPageRows = filteredHistoryLogs.slice((historyPage - 1) * itemsPerPage, historyPage * itemsPerPage);
  const totalHistoryTabPages = Math.ceil(filteredHistoryLogs.length / itemsPerPage);

  const isInVerification = selectedDoc?.status?.toLowerCase() === 'in verification' || ((selectedDoc?.current_step_is_adhoc || selectedDoc?.is_adhoc) && selectedDoc?.current_office !== signeeOfficeName);
  const isAwaitingScanIn = selectedDoc && !selectedDoc.time_in;
  const isActionAltered = selectedDoc && (selectedDoc.status?.toLowerCase() === 'signed' || selectedDoc.status?.toLowerCase() === 'completed' || selectedDoc.status?.toLowerCase() === 'action required');

  const formatRelativeTime = (timestamp) => {
    if (!timestamp) return 'Just now';
    
    // Clean PostgreSQL offset characters if present
    const localizedString = String(timestamp).replace(/(\+00:00|\+00|Z)$/i, '');
    const now = new Date();
    const past = new Date(localizedString);
    const msPerMinute = 60 * 1000;
    const msPerHour = msPerMinute * 60;
    const msPerDay = msPerHour * 24;
    
    const elapsed = now - past;
    
    if (elapsed < msPerMinute) {
       return 'Just now';
    } else if (elapsed < msPerHour) {
       const minutes = Math.round(elapsed / msPerMinute);
       return `${minutes} ${minutes === 1 ? 'minute' : 'minutes'} ago`;   
    } else if (elapsed < msPerDay) {
       const hours = Math.round(elapsed / msPerHour);
       return `${hours} ${hours === 1 ? 'hour' : 'hours'} ago`;   
    } else {
       const days = Math.round(elapsed / msPerDay);
       return `${days} ${days === 1 ? 'day' : 'days'} ago`;   
    }
  };

  return (
    <div className="flex h-screen w-screen bg-[#FAF8F5] text-neutral-800 font-sans overflow-hidden">
      
      <div className="w-64 bg-[#2D1F1E] text-neutral-300 flex flex-col justify-between p-4 flex-shrink-0 text-left">
        <div>
          <div className="flex items-center gap-3 border-b border-neutral-700 pb-4 mb-6">
            <div className="bg-red-800 p-2 rounded-lg text-white font-bold text-xl">🎓</div>
            <div>
              <h1 className="font-bold text-white text-sm">Office Signee</h1>
              <span className="text-[10px] text-neutral-400 uppercase tracking-widest font-black">Institutional Portal</span>
            </div>
          </div>
          
          <nav className="space-y-1 text-sm">
            <button onClick={() => { setActiveTab('dashboard'); setSearch(''); setDashboardPage(1); }} className={`w-full flex items-center gap-3 px-3 py-2.5 rounded-lg font-bold transition-colors ${activeTab === 'dashboard' ? 'bg-neutral-800 text-white' : 'text-neutral-400 hover:bg-neutral-800 hover:text-white'}`}>
              <LayoutDashboard size={18} /> Dashboard
            </button>
            <button onClick={() => { setActiveTab('documents'); setSearch(''); setFilterStatus('All'); setPipelinePage(1); }} className={`w-full flex items-center gap-3 px-3 py-2.5 rounded-lg font-bold transition-colors ${activeTab === 'documents' ? 'bg-neutral-800 text-white' : 'text-neutral-400 hover:bg-neutral-800 hover:text-white'}`}>
              <FileText size={18} /> Documents
            </button>
            <button onClick={() => { setActiveTab('history'); setSearch(''); setHistoryFilter('All'); setHistoryPage(1); }} className={`w-full flex items-center gap-3 px-3 py-2.5 rounded-lg font-bold transition-colors ${activeTab === 'history' ? 'bg-neutral-800 text-white' : 'text-neutral-400 hover:bg-neutral-800 hover:text-white'}`}>
              <History size={18} /> History
            </button>
          </nav>
        </div>

        <div className="border-t border-neutral-700 pt-4 flex items-center gap-3">
          <img src="https://images.unsplash.com/photo-1472099645785-5658abf4ff4e?auto=format&fit=facearea&facepad=2&w=256&h=256&q=80" className="w-10 h-10 rounded-xl object-cover" alt="User Profile" />
          <div className="flex-1 text-left min-w-0">
            <p className="text-xs font-black text-white truncate">{userName}</p>
            <p className="text-[9px] text-neutral-400 font-bold uppercase truncate">{signeeOfficeName}</p>
          </div>
          <button onClick={handleLogout} className="text-neutral-400 hover:text-red-400 transition-colors"><LogOut size={16} /></button>
        </div>
      </div>

      <div className="flex-1 flex flex-col overflow-hidden">
        
        <header className="h-16 border-b border-neutral-200 bg-white px-8 flex items-center justify-between shadow-sm flex-shrink-0 relative">
          <div className="text-left">
            <h2 className="text-lg font-black text-neutral-900 capitalize">
              {activeTab === 'profile' ? 'Profile Management Hub' : `${activeTab} Operational Hub`}
            </h2>
            <p className="text-[10px] font-bold text-neutral-400 uppercase tracking-wide">Assigned: {signeeOfficeName}</p>
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
                        <div key={n.id} className="p-4 text-xs border-b last:border-b-0">
                          <div className="flex justify-between items-start gap-2">
                            <p className="font-bold text-neutral-900">{n.title}</p>
                            {/* Added your relative time span here */}
                            <span className="text-[10px] text-neutral-400 whitespace-nowrap">
                              {formatRelativeTime(n.time)}
                            </span>
                          </div>
                          <p className="text-neutral-500 mt-1">{n.message}</p>
                        </div>
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

        <div className="flex-1 overflow-y-auto p-8 space-y-6">

          {activeTab === 'dashboard' && (
            <>
              <div className="grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-4 gap-4 text-left">
                <div className="bg-white p-4 rounded-xl border border-neutral-200 border-l-4 border-l-red-600 shadow-sm">
                  <span className="text-[10px] uppercase font-black text-neutral-400 tracking-wider block">Pending Documents</span>
                  <p className="text-2xl font-black text-neutral-900 mt-1">{String(pendingDocsList.length).padStart(2, '0')}</p>
                  <span className="text-[10px] text-red-600 font-bold mt-1 block">⚠️ Requires attention</span>
                </div>
                <div className="bg-white p-4 rounded-xl border border-neutral-200 border-l-4 border-l-green-600 shadow-sm">
                  <span className="text-[10px] uppercase font-black text-neutral-400 tracking-wider block">Signed Documents</span>
                  <p className="text-2xl font-black text-neutral-900 mt-1">{String(signedDocsList.length).padStart(2, '0')}</p>
                  <span className="text-[10px] text-green-600 font-bold mt-1 block">✓ Cleared / Signed</span>
                </div>
                <div className="bg-white p-4 rounded-xl border border-neutral-200 border-l-4 border-l-amber-500 shadow-sm">
                  <span className="text-[10px] uppercase font-black text-neutral-400 tracking-wider block">In Verification</span>
                  <p className="text-2xl font-black text-neutral-900 mt-1">{String(verificationDocsList.length).padStart(2, '0')}</p>
                  <span className="text-[10px] text-amber-600 font-bold mt-1 block">🕒 Pending audit detour</span>
                </div>
                <div className="bg-white p-4 rounded-xl border border-neutral-200 border-l-4 border-l-blue-600 shadow-sm">
                  <span className="text-[10px] uppercase font-black text-neutral-400 tracking-wider block">Sent Back</span>
                  <p className="text-2xl font-black text-neutral-900 mt-1">{String(sentBackDocsList.length).padStart(2, '0')}</p>
                  <span className="text-[10px] text-blue-600 font-bold mt-1 block">↩ Action Required</span>
                </div>
              </div>

              <div className="bg-white border border-neutral-200 rounded-2xl shadow-sm overflow-hidden text-left">
                <div className="p-5 border-b border-neutral-100 flex flex-col sm:flex-row justify-between items-center gap-4">
                  <h3 className="text-sm font-black text-neutral-900">Documents Pending Signature</h3>
                  <div className="relative">
                    <Search className="absolute left-3 top-2.5 text-neutral-400" size={14} />
                    <input type="text" placeholder="Search pending titles..." value={search} onChange={e => { setSearch(e.target.value); setDashboardPage(1); }} className="pl-9 pr-4 py-2 text-xs border border-neutral-300 rounded-lg outline-none w-64 bg-neutral-50" />
                  </div>
                </div>

                <div className="overflow-x-auto">
                  <table className="w-full text-xs text-left">
                    <thead>
                      <tr className="bg-[#FFFDFB] border-b border-neutral-200 font-black uppercase text-[10px] text-neutral-400 tracking-wider">
                        <th className="p-4">Title</th>
                        <th className="p-4">Form Type</th>
                        <th className="p-4">Current Status</th>
                        <th className="p-4">Originating Office</th>
                        <th className="p-4 text-center">Action</th>
                      </tr>
                    </thead>
                    <tbody className="divide-y divide-neutral-100 font-medium">
                      {currentDashDocs.map((doc, idx) => (
                        <tr key={idx} className="hover:bg-neutral-50/50 transition-colors">
                          <td className="p-4 font-bold text-neutral-900">{doc.title}</td>
                          <td className="p-4 font-semibold text-neutral-500">{doc.process_name}</td>
                          <td className="p-4"><span className="px-2 py-0.5 bg-red-50 text-red-700 border border-red-100 rounded font-black text-[9px] uppercase tracking-wider">• {doc.status || 'Pending'}</span></td>
                          <td className="p-4 font-semibold text-neutral-600">{doc.originating_office || 'University Unit'}</td>
                          <td className="p-4 text-center">
                            <button onClick={() => handleOpenDetails(doc, false)} className="p-1.5 hover:bg-neutral-100 rounded-lg text-red-800 inline-flex items-center"><Eye size={16} /></button>
                          </td>
                        </tr>
                      ))}
                    </tbody>
                  </table>
                  {filteredDashDocs.length === 0 && <div className="p-12 text-center text-neutral-400">📭 Signature checklist is empty.</div>}
                </div>

                {totalDashPages > 1 && (
                  <div className="p-4 border-t bg-neutral-50 flex items-center justify-between text-xs font-bold text-neutral-500 px-6">
                    <span>Showing page {dashboardPage} of {totalDashPages}</span>
                    <div className="flex gap-1">
                      <button disabled={dashboardPage === 1} onClick={() => setDashboardPage(prev => prev - 1)} className="px-3 py-1.5 border bg-white rounded-lg disabled:opacity-40">Previous</button>
                      <button disabled={dashboardPage === totalDashPages} onClick={() => setDashboardPage(prev => prev + 1)} className="px-3 py-1.5 border bg-white rounded-lg disabled:opacity-40">Next</button>
                    </div>
                  </div>
                )}
              </div>
            </>
          )}

          {activeTab === 'documents' && (
            <div className="bg-white border border-neutral-200 rounded-2xl shadow-sm overflow-hidden text-left">
              <div className="p-5 border-b border-neutral-100 flex flex-col sm:flex-row items-stretch sm:items-center justify-between gap-4">
                <h3 className="text-sm font-black text-neutral-900">Administrative Tracking Streams</h3>
                <div className="flex items-center gap-2">
                  <div className="flex items-center gap-1 border rounded-lg px-2 py-1.5 bg-neutral-50">
                    <Filter size={14} className="text-neutral-400" />
                    <select value={filterStatus} onChange={e => { setFilterStatus(e.target.value); setPipelinePage(1); }} className="bg-transparent text-xs outline-none cursor-pointer font-bold text-neutral-600">
                      <option value="All">All Status Profiles</option>
                      <option value="Pending">Pending Signature</option>
                      <option value="Signed">Signed / Completed</option>
                      <option value="In Verification">In Audit Verification</option>
                      <option value="Action Required">Action Required (Sent Back)</option>
                    </select>
                  </div>
                  <div className="relative">
                    <Search className="absolute left-3 top-2.5 text-neutral-400" size={14} />
                    <input type="text" placeholder="Search records..." value={search} onChange={e => { setSearch(e.target.value); setPipelinePage(1); }} className="pl-9 pr-4 py-2 text-xs border border-neutral-300 rounded-lg outline-none w-56 bg-neutral-50" />
                  </div>
                </div>
              </div>

              <div className="overflow-x-auto">
                <table className="w-full text-xs text-left">
                  <thead>
                    <tr className="bg-neutral-50 border-b border-neutral-200 font-black uppercase text-[10px] text-neutral-400 tracking-wider">
                      <th className="p-4">Title</th>
                      <th className="p-4">Form Type</th>
                      <th className="p-4">Pipeline Status</th>
                      <th className="p-4">Next Destination</th>
                      <th className="p-4 text-center">Action</th>
                    </tr>
                  </thead>
                  <tbody className="divide-y divide-neutral-100 font-medium">
                    {currentPipeDocs.map((doc, idx) => (
                      <tr key={idx} className="hover:bg-neutral-50/50 transition-colors">
                        <td className="p-4 font-bold text-neutral-900">{doc.title}</td>
                        <td className="p-4 font-semibold text-neutral-500">{doc.process_name}</td>
                        <td className="p-4">
                          <span className={`inline-flex items-center gap-1.5 font-bold ${
                            doc.status?.toLowerCase() === 'completed' || doc.status?.toLowerCase() === 'signed' ? 'text-green-600' : doc.status?.toLowerCase() === 'action required' ? 'text-blue-600' : 'text-red-700'
                          }`}>
                            {!doc.time_in ? 'Incoming' : doc.time_out ? 'Completed' : doc.status || 'Pending'}
                          </span>
                        </td>
                        <td className="p-4 font-semibold text-neutral-500">{doc.next_office || 'Final Stop'}</td>
                        <td className="p-4 text-center">
                          <button onClick={() => handleOpenDetails(doc, false)} className="p-1.5 hover:bg-neutral-100 rounded-lg text-red-800 inline-flex items-center"><Eye size={16} /></button>
                        </td>
                      </tr>
                    ))}
                  </tbody>
                </table>
                {filteredPipelineDocs.length === 0 && <div className="p-12 text-center text-neutral-400">📭 No pipeline records match selected criteria filters.</div>}
              </div>

              {totalPipePages > 1 && (
                <div className="p-4 border-t bg-neutral-50 flex items-center justify-between text-xs font-bold text-neutral-500 px-6">
                  <span>Showing page {pipelinePage} of {totalPipePages}</span>
                  <div className="flex gap-1">
                    <button disabled={pipelinePage === 1} onClick={() => setPipelinePage(prev => prev - 1)} className="px-3 py-1.5 border bg-white rounded-lg disabled:opacity-40">Previous</button>
                    <button disabled={pipelinePage === totalPipePages} onClick={() => setPipelinePage(prev => prev + 1)} className="px-3 py-1.5 border bg-white rounded-lg disabled:opacity-40">Next</button>
                  </div>
                </div>
              )}
            </div>
          )}

          {activeTab === 'history' && (
            <div className="bg-white border border-neutral-200 rounded-2xl shadow-sm overflow-hidden text-left">
              <div className="p-5 border-b border-neutral-100 flex flex-col sm:flex-row justify-between items-center gap-4">
                <h3 className="text-sm font-black text-neutral-950 tracking-tight">Audit Trail Ledger</h3>
                <div className="flex flex-wrap items-center gap-3">
                  <div className="flex items-center gap-1 border border-neutral-300 rounded-lg px-2 py-1.5 bg-neutral-50">
                    <Filter size={14} className="text-neutral-400" />
                    <select value={historyFilter} onChange={e => { setHistoryFilter(e.target.value); setHistoryPage(1); }} className="bg-transparent text-xs outline-none cursor-pointer font-bold text-neutral-600">
                      <option value="All">All Actions</option>
                      <option value="Scanned In">Scanned In</option>
                      <option value="Scanned Out">Scanned Out</option>
                      <option value="Ad-Hoc Detour Routed">Ad-Hoc Detour</option>
                    </select>
                  </div>
                  <div className="relative">
                    <Search className="absolute left-3 top-2.5 text-neutral-400" size={14} />
                    <input type="text" placeholder="Search history records..." value={search} onChange={e => { setSearch(e.target.value); setHistoryPage(1); }} className="pl-9 pr-4 py-2 text-xs border border-neutral-300 rounded-lg outline-none w-56 bg-neutral-50 font-medium" />
                  </div>
                </div>
              </div>

              <div className="overflow-x-auto">
                <table className="w-full text-left text-xs border-collapse">
                  <thead>
                    <tr className="bg-neutral-50 text-neutral-400 border-b border-neutral-200 font-black uppercase text-[10px] tracking-wider">
                      <th className="p-4">Timestamp</th>
                      <th className="p-4">Action Event</th>
                      <th className="p-4">Executed By</th>
                      <th className="p-4">Document Title</th>
                      <th className="p-4 text-center">Verification</th>
                    </tr>
                  </thead>
                  <tbody className="divide-y divide-neutral-100 font-medium">
                    {currentHistoryPageRows.map((log, index) => {
                      const rawTimestamp = log.action_timestamp; 
                      let formattedTime = 'N/A';
                      
                      if (rawTimestamp) {
                        const localizedString = String(rawTimestamp).replace(/(\+00:00|\+00|Z)$/i, '');
                        const d = new Date(localizedString);
                        formattedTime = d.toLocaleDateString('en-US', { month: 'short', day: 'numeric', year: 'numeric' }) + ', ' + d.toLocaleTimeString('en-US', { hour: '2-digit', minute: '2-digit', hour12: true });
                      }

                      return (
                        <tr key={log.history_id || index} className="hover:bg-neutral-50/70 transition-colors">
                          <td className="p-4 font-mono text-neutral-600">{formattedTime}</td>
                          <td className="p-4">
                            <span className={`px-2.5 py-0.5 rounded text-[9px] font-black uppercase tracking-wide border ${
                              log.action_type === 'Scanned In' ? 'bg-blue-50 text-blue-800 border-blue-100' :
                              log.action_type === 'Scanned Out' ? 'bg-green-50 text-green-800 border-green-100' :
                              log.action_type === 'Ad-Hoc Detour Routed' ? 'bg-purple-50 text-purple-800 border-purple-100' : 'bg-amber-50 text-amber-800 border-amber-100'
                            }`}>{log.action_type}</span>
                          </td>
                          <td className="p-4 text-neutral-900 font-bold">{log.full_name}</td>
                          <td className="p-4 text-neutral-700 font-semibold">{log.title}</td>
                          <td className="p-4 text-center">
                            <button onClick={() => handleOpenDetails(log, true)} className="p-1.5 hover:bg-neutral-100 rounded-lg text-red-800 inline-flex items-center"><Eye size={16} /></button>
                          </td>
                        </tr>
                      );
                    })}
                  </tbody>
                </table>
                {filteredHistoryLogs.length === 0 && <div className="p-12 text-center text-neutral-400 font-medium">📜 No logging entries match criteria filters.</div>}
              </div>

              {totalHistoryTabPages > 1 && (
                <div className="p-4 border-t border-neutral-100 bg-neutral-50 flex items-center justify-between text-xs px-6">
                  <span className="text-neutral-500 font-medium">Showing page <b>{historyPage}</b> of {totalHistoryTabPages}</span>
                  <div className="flex gap-1">
                    <button disabled={historyPage === 1} onClick={() => setHistoryPage(prev => prev - 1)} className="px-3 py-1.5 border rounded-lg bg-white font-bold text-neutral-600">Previous</button>
                    <button disabled={historyPage === totalHistoryTabPages} onClick={() => setHistoryPage(prev => prev + 1)} className="px-3 py-1.5 border rounded-lg bg-white font-bold text-neutral-600">Next</button>
                  </div>
                </div>
              )}
            </div>
          )}

          {activeTab === 'profile' && (
            <div className="max-w-5xl mx-auto grid grid-cols-1 lg:grid-cols-3 gap-6 text-left animate-in fade-in duration-200">
              <div className="lg:col-span-3 bg-white border border-neutral-200 p-6 rounded-2xl flex items-center gap-6 shadow-sm">
                <div className="relative">
                  <img src="https://images.unsplash.com/photo-1472099645785-5658abf4ff4e?auto=format&fit=facearea&facepad=2&w=256&h=256&q=80" alt="Profile" className="w-24 h-24 rounded-2xl object-cover border-2 border-neutral-100 shadow-sm" />
                  <div className="absolute -bottom-1 -right-1 bg-red-800 p-1.5 rounded-lg text-white shadow-md cursor-pointer"><Camera size={14} /></div>
                </div>
                <div className="space-y-1">
                  <div className="flex items-center gap-3">
                    <h3 className="text-xl font-black text-neutral-900">{profileName || 'Office Signee'}</h3>
                    <span className="px-2 py-0.5 bg-red-50 text-red-800 border border-red-100 rounded text-[9px] font-black uppercase tracking-wider">Signee Authority</span>
                  </div>
                  <p className="text-xs text-neutral-400 font-bold flex items-center gap-1.5"><Building size={12} /> Unit Sector • {signeeOfficeName}</p>
                  <p className="text-xs text-green-600 font-bold flex items-center gap-1 mt-1"><span className="w-2 h-2 bg-green-500 rounded-full animate-pulse"></span> Security Seal Status: Active</p>
                </div>
              </div>

              <div className="lg:col-span-2 space-y-6">
                <div className="bg-white border border-neutral-200 rounded-2xl p-6 shadow-sm">
                  <div className="flex items-center gap-2 border-b border-neutral-100 pb-3 mb-4">
                    <User size={16} className="text-red-800" />
                    <h4 className="text-xs uppercase font-black text-neutral-900 tracking-wider">Personal Information & Recovery Settings</h4>
                  </div>
                  <form onSubmit={handleUpdateProfile} className="space-y-4">
                    <div className="grid grid-cols-1 sm:grid-cols-2 gap-4">
                      <div>
                        <label className="block text-[10px] font-black text-neutral-400 uppercase mb-1 tracking-wide">Full Authority Name</label>
                        <input type="text" required value={profileName} onChange={e => setProfileName(e.target.value)} className="w-full px-4 py-2 text-xs border border-neutral-300 rounded-xl outline-none bg-neutral-50 font-bold text-neutral-800" />
                      </div>
                      <div>
                        <label className="block text-[10px] font-black text-neutral-400 uppercase mb-1 tracking-wide">System Recovery Email Address</label>
                        <input type="email" required value={profileEmail} onChange={e => setProfileEmail(e.target.value)} className="w-full px-4 py-2 text-xs border border-neutral-300 rounded-xl outline-none bg-neutral-50 font-bold text-neutral-800" />
                      </div>
                    </div>
                    <div className="flex justify-end pt-2">
                      <button type="submit" className="px-4 py-2 bg-neutral-900 hover:bg-black text-white font-bold text-xs rounded-xl uppercase tracking-wide transition-all shadow-sm">Save Profiles Changes</button>
                    </div>
                  </form>
                </div>

                <div className="bg-white border border-neutral-200 rounded-2xl p-6 shadow-sm space-y-4">
                  <div className="flex items-center gap-2 border-b border-neutral-100 pb-3 mb-2">
                    <ShieldCheck size={16} className="text-red-800" />
                    <h4 className="text-xs uppercase font-black text-neutral-900 tracking-wider">Account Security Protocols</h4>
                  </div>
                  
                  <div className="border border-neutral-200 rounded-xl p-4 flex items-center justify-between hover:bg-neutral-50/50 transition-colors">
                    <div>
                      <h5 className="text-xs font-black text-neutral-900">Change Account Password</h5>
                      <p className="text-[11px] text-neutral-400 mt-0.5 font-medium">Update your administrative account passcode credentials regularly.</p>
                    </div>
                    <button onClick={() => { setShowPassModal(true); }} className="text-xs font-black text-red-800 hover:underline">Update</button>
                  </div>

                  <div className="border border-neutral-200 rounded-xl p-4 flex flex-col gap-4 hover:bg-neutral-50/50 transition-colors">
                    <div className="flex items-center justify-between">
                      <div>
                        <h5 className="text-xs font-black text-neutral-900">Secondary Two-Factor Authentication PIN</h5>
                        <p className="text-[11px] text-neutral-400 mt-0.5 font-medium">Enforce secondary multi-factor challenge prompt criteria upon account entry checkpoints.</p>
                      </div>
                      <label className="relative inline-flex items-center cursor-pointer select-none">
                        <input type="checkbox" checked={twoFaEnabled} onChange={e => toggle2FA(e.target.checked)} className="sr-only peer" />
                        <div className="w-11 h-6 bg-neutral-200 rounded-full peer peer-checked:after:translate-x-full after:content-[''] after:absolute after:top-[2px] after:left-[2px] after:bg-white after:border-neutral-300 after:border after:rounded-full after:h-5 after:w-5 after:transition-all peer-checked:bg-red-800"></div>
                      </label>
                    </div>
                    {twoFaEnabled && (
                      <form onSubmit={handleSaveCustomPin} className="border-t border-dashed border-neutral-200 pt-3 space-y-2 animate-in slide-in-from-top-1">
                        <label className="block text-[10px] font-black text-neutral-400 uppercase tracking-wide">Set Your Custom Authority Code Validation PIN</label>
                        <div className="flex items-center gap-2">
                          <input type="text" maxLength={6} required placeholder="Enter numeric validation pin" value={twoFaCode} onChange={e => setTwoFaCode(e.target.value.replace(/\D/g, ''))} className="w-full max-w-xs px-4 py-2 text-xs border border-neutral-300 rounded-xl outline-none font-mono tracking-widest text-neutral-800" />
                          <button type="submit" className="px-4 py-2 bg-neutral-900 text-white font-bold text-xs rounded-xl uppercase tracking-wide shadow-sm">Save PIN</button>
                        </div>
                      </form>
                    )}
                  </div>
                </div>
              </div>

              <div className="space-y-6">
                <div className="bg-white border border-neutral-200 rounded-2xl p-6 shadow-sm">
                  <div className="flex items-center gap-2 border-b border-neutral-100 pb-3 mb-4">
                    <Landmark size={16} className="text-neutral-500" />
                    <h4 className="text-xs uppercase font-black text-neutral-900 tracking-wider">Institutional Data Placement</h4>
                  </div>
                  <div className="space-y-4 text-xs">
                    <div>
                      <span className="text-[9px] font-black text-neutral-400 uppercase tracking-wide block">Authority Faculty Identifier</span>
                      <p className="font-black text-neutral-900 text-sm mt-0.5">{facultyId}</p>
                    </div>
                    <div>
                      <span className="text-[9px] font-black text-neutral-400 uppercase tracking-wide block">Campus Assigned Terminal Branch Unit</span>
                      <p className="font-bold text-neutral-700 mt-0.5">{signeeOfficeName}</p>
                    </div>
                  </div>
                </div>
                <div className="bg-red-50/40 border border-red-100 rounded-2xl p-4 text-[11px] leading-relaxed text-neutral-500 font-medium">
                  ℹ️ <span className="font-bold text-neutral-800">Note:</span> Maintaining institutional profile bindings and role configurations falls under the jurisdiction of the University Central Registry Database console. Contact <span className="text-red-800 font-bold hover:underline">Campus IT Support</span> for configuration adjustments.
                </div>
              </div>
            </div>
          )}

        </div>
      </div>

      {showDetailsModal && selectedDoc && (() => {
        const docTitle = selectedDoc.title || selectedDoc.document_title || 'N/A';
        const docProcess = selectedDoc.process_name || 'Administrative Request';
        const docStatus = selectedDoc.status || 'Active Path';
        const docQr = selectedDoc.qr_code || 'N/A';
        const docOrigin = selectedDoc.originating_office || selectedDoc.origin || 'University Unit';
        const docNext = selectedDoc.next_office || 'None (Final Stop)';
        const docRequestor = selectedDoc.requestor_name || 'N/A';

        return (
          <div className="fixed inset-0 bg-neutral-950/60 backdrop-blur-xs flex items-center justify-center p-4 z-[100] animate-in fade-in duration-150">
            <div className="bg-white w-full max-w-2xl rounded-2xl shadow-2xl border overflow-hidden flex flex-col text-left animate-in zoom-in-95 duration-200">
              
              <div className="p-4 bg-red-800 text-white font-bold text-sm flex items-center justify-between">
                <span>Document Routing Identification Verification</span>
                <button onClick={() => setShowDetailsModal(false)} className="hover:opacity-80"><X size={18} /></button>
              </div>

              <div className="p-6 space-y-6 max-h-[80vh] overflow-y-auto leading-relaxed">
                <div className="grid grid-cols-1 md:grid-cols-2 gap-8 items-start">
                  
                  <div className="space-y-4 text-xs">
                    <div>
                      <span className="text-[10px] font-bold uppercase tracking-wider text-neutral-400 block mb-1">Document Title</span>
                      <p className="text-lg font-black text-neutral-900 leading-tight tracking-tight">{docTitle}</p>
                    </div>
                    
                    <div className="grid grid-cols-2 gap-4 border-b border-neutral-100 pb-3">
                      <div>
                        <span className="text-[10px] font-bold uppercase text-neutral-400 tracking-wider block">Form Type</span>
                        <p className="font-bold text-neutral-700 text-xs mt-1">{docProcess}</p>
                      </div>
                      <div>
                        <span className="text-[9px] font-bold uppercase text-neutral-400 tracking-wide block">Current Status</span>
                        <span className="px-2.5 py-0.5 bg-red-50 text-red-800 border border-red-200 rounded font-black text-[9px] uppercase tracking-wider inline-block mt-1">
                          {docStatus}
                        </span>
                      </div>
                    </div>

                    <div className="grid grid-cols-3 gap-4 border-b pb-3">
                      <div>
                        <span className="text-[9px] font-black uppercase text-neutral-400 tracking-wide block">Originating Office</span>
                        <p className="font-bold text-neutral-700 mt-1">{docOrigin}</p>
                      </div>
                      <div>
                        <span className="text-[9px] font-black uppercase text-neutral-400 tracking-wide block">Date Created</span>
                        <p className="font-bold text-neutral-700 mt-1">
                          {selectedDoc.created_at ? new Date(selectedDoc.created_at).toLocaleDateString('en-US', { month: 'short', day: 'numeric', year: 'numeric' }) : 'N/A'}
                        </p>
                      </div>
                      <div>
                        <span className="text-[9px] font-black uppercase text-neutral-400 tracking-wide block">Next Office Stop</span>
                        <p className="font-bold text-neutral-700 mt-1">{docNext}</p>
                      </div>
                    </div>

                    <div className="grid grid-cols-3 gap-2 pt-1">
                      <div>
                        <span className="text-[9px] font-black uppercase text-neutral-400 tracking-wide block">Requestor</span>
                        <p className="font-black text-neutral-800 mt-1 truncate">{docRequestor}</p>
                      </div>
                      <div>
                        <span className="text-[9px] font-black uppercase text-neutral-400 tracking-wide block">Time In Arrival</span>
                        <p className="font-mono text-[11px] font-bold mt-1 text-neutral-600">
                        {selectedDoc.time_in ? (
                          new Date(selectedDoc.time_in).toLocaleTimeString('en-US', { hour: '2-digit', minute: '2-digit' })
                        ) : (
                            <span className="text-red-700 bg-red-50 px-1.5 py-0.5 rounded text-[9px] font-black uppercase">Awaiting Scan</span>
                          )}
                        </p>
                      </div>
                      <div>
                        <span className="text-[9px] font-black uppercase text-neutral-400 tracking-wide block">Time Out Release</span>
                        <p className="font-mono text-[11px] font-bold mt-0.5 text-neutral-600">
                        {selectedDoc.time_out ? (
                          new Date(selectedDoc.time_out).toLocaleTimeString('en-US', { hour: '2-digit', minute: '2-digit' })
                        ) : (
                          <span className="text-amber-600 bg-amber-50 px-1.5 py-0.5 rounded text-[9px] font-black tracking-wide uppercase">In Progress</span>
                        )}                        </p>
                      </div>
                    </div>
                  </div>
                  <div className="border border-neutral-200/80 p-5 rounded-xl bg-white flex flex-col items-center justify-center text-center shadow-xs">
                    <span className="text-[10px] font-black uppercase text-neutral-400 tracking-wide mb-3">Security QR Identity Token</span>
                    <div className="bg-white p-3 border border-neutral-200 rounded-xl shadow-xs">
                      {/* Replaced placeholder with real QR */}
                      <QRCodeSVG 
                        value={docQr} 
                        size={115} 
                        level={"H"} 
                        fgColor={"#171717"} 
                      />
                    </div>
                    <div className="mt-4 text-center">
                      <span className="text-[9px] font-black uppercase text-neutral-400 tracking-wider block">Tracking Reference Number</span>
                      <span className="font-mono text-xs font-black text-red-800 tracking-wide mt-1 block">{docQr}</span>
                    </div>
                  </div>
                </div>

                {isHistoryDetails || selectedDoc.time_out ? (
                  <div className="bg-blue-50 border border-blue-200 rounded-xl p-4 flex gap-3.5 items-start">
                    <span className="text-xl mt-0.5">ℹ️</span>
                    <div className="text-xs text-left">
                      <p className="font-black text-blue-900 uppercase tracking-wide">Vault History View Only</p>
                      <p className="text-blue-700 font-medium mt-1 leading-normal">
                        This document step has been locked into the history vault. Active signatures or workflow re-routing permissions are disabled.
                      </p>
                    </div>
                  </div>
                ) : isAwaitingScanIn ? (
                  <div className="bg-red-50 border border-red-200 rounded-xl p-4 flex gap-3.5 items-start animate-in fade-in duration-150">
                    <span className="text-xl mt-0.5">🛑</span>
                    <div className="text-xs text-left">
                      <p className="font-black text-red-900 uppercase tracking-wide">Processing Unavailable: Not yet Scanned in</p>
                      <p className="text-red-700 font-medium mt-1 leading-normal">
                        This administrative document cannot be signed or sent back yet. The office Processor must physically scan the file barcode tracking token to confirm its official safe arrival inside your department workspace branch first.
                      </p>
                    </div>
                  </div>
                ) : isInVerification ? (
                  <div className="bg-amber-50/60 border border-amber-200 rounded-xl p-4 flex gap-3.5 items-start animate-in fade-in duration-100">
                    <span className="text-xl mt-0.5">⚖️</span>
                    <div className="text-xs text-left">
                      <p className="font-black text-amber-900 uppercase tracking-wide">Document In Verification Checkpoint</p>
                      <p className="text-amber-700 font-medium mt-1 leading-normal">
                        This administrative request is currently routing through an active external ad-hoc detour verification branch step. Action workflow options are suspended until it completes its path loop back to your campus terminal office sector.
                      </p>
                    </div>
                  </div>
                ) : isActionAltered ? (
                  <div className="bg-green-50 border border-green-200 rounded-xl p-4 flex gap-3.5 items-start">
                    <span className="text-xl mt-0.5">🛡️</span>
                    <div className="text-xs text-left">
                      <p className="font-black text-green-900 uppercase tracking-wide">Action Completed Securely</p>
                      <p className="text-green-700 font-medium mt-1 leading-normal">
                        Your official action signature seal has been submitted successfully for this station. Double modifications are restricted. Processors can now complete the Time-Out clearance sequence.
                      </p>
                    </div>
                  </div>
                ) : (
                  <div className="space-y-4 border-t pt-4">
                    <div className="flex flex-wrap gap-2">
                      <button 
                        type="button" 
                        onClick={() => { setShowAdHocForm(!showAdHocForm); setShowSendBackForm(false); }} 
                        className="px-4 py-2 bg-red-50 hover:bg-red-100 text-red-900 rounded-xl font-bold text-xs flex items-center gap-2 border border-red-100 transition-all"
                      >
                        <GitBranch size={14} /> Request Ad-hoc Detour
                      </button>
                    </div>

                    {showAdHocForm && (
                      <form onSubmit={handleExecuteAdHocDetour} className="bg-neutral-50 p-4 border rounded-xl space-y-3 animate-in slide-in-from-top-1 duration-150">
                        <label className="block text-[10px] font-black uppercase tracking-wider text-neutral-400">Select Verification Destination Campus Unit</label>
                        <div className="flex gap-2">
                          <select required value={selectedAdHocOffice} onChange={e => setSelectedAdHocOffice(e.target.value)} className="flex-1 bg-white border border-neutral-300 rounded-lg px-3 py-1.5 text-xs font-bold text-neutral-700">
                            <option value="">-- Choose Destination Branch --</option>
                            {officesList.map((off, idx) => (off.id !== signeeOfficeId && <option key={idx} value={off.id}>{off.name}</option>))}
                          </select>
                          <button type="submit" disabled={isActionProcessing} className="px-5 py-1.5 bg-red-800 text-white font-bold text-xs rounded-lg uppercase tracking-wider shadow-sm">Route Detour</button>
                        </div>
                      </form>
                    )}

                    {showSendBackForm && (
                      <form onSubmit={handleExecuteReturn} className="bg-red-50/40 border border-red-100 rounded-xl p-4 space-y-3 animate-in slide-in-from-top-1 duration-150">
                        <div className="space-y-1.5">
                          <label className="block text-[10px] font-black text-red-900 uppercase tracking-wider">Reason for Return (Revision Notes Required)</label>
                          <textarea required rows={3} placeholder="Enter specific reason detailing why this documentation is being sent back to the originator for modifications..." value={returnReason} onChange={e => setReturnReason(e.target.value)} className="w-full border bg-white rounded-lg p-3 text-xs outline-none focus:ring-1 focus:ring-red-800 font-medium text-neutral-800" />
                        </div>
                        <div className="flex justify-end">
                          <button type="submit" disabled={isActionProcessing} className="px-5 py-2 bg-red-800 hover:bg-red-900 text-white font-bold text-xs rounded-lg uppercase tracking-wide shadow-md">Submit & Return to Originator</button>
                        </div>
                      </form>
                    )}
                  </div>
                )}
              </div>

              <div className="p-4 border-t bg-neutral-50/80 flex justify-end gap-2 px-6">
                <button 
                  type="button" 
                  onClick={() => { setShowSendBackForm(!showSendBackForm); setShowAdHocForm(false); }} 
                  disabled={isHistoryDetails || isInVerification || isAwaitingScanIn || isActionAltered || selectedDoc.time_out}
                  className="px-5 py-2 border border-neutral-300 bg-white hover:bg-neutral-100 disabled:opacity-30 rounded-xl font-bold text-xs text-neutral-600 shadow-xs transition-all"
                >
                  {showSendBackForm ? 'Cancel Revision' : 'Send Back'}
                </button>
                <button 
                  type="button" 
                  disabled={isActionProcessing || isHistoryDetails || isActionAltered || isInVerification || isAwaitingScanIn || selectedDoc.time_out} 
                  onClick={handleSignDocument} 
                  className="px-6 py-2 bg-red-800 hover:bg-red-900 text-white font-bold text-xs rounded-xl shadow-md uppercase tracking-wider transition-all disabled:opacity-30"
                >
                  Sign File
                </button>
              </div>
            </div>
          </div>
        );
      })()}

    </div>
  );
}