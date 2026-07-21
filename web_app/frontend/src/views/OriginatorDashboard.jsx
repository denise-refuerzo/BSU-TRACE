import React, { useState, useEffect, useRef } from 'react';
import { useNavigate } from 'react-router-dom';
import { QRCodeSVG } from 'qrcode.react';
import { LayoutDashboard, FileText, School, Bell, User, Plus, Search, Filter, X, QrCode, ChevronLeft, ChevronRight, MessageSquare } from 'lucide-react';
import DocumentsHub from './DocumentsHub';
import ResourceScheduler from './ResourceScheduler';
import OfficeChatHub from './OfficeChatHub';
import Swal from 'sweetalert2'; 
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

export default function OriginatorDashboard() {
  const navigate = useNavigate();
  const notificationRef = useRef(null);
  
  const userId = localStorage.getItem('userId');
  const userName = localStorage.getItem('user') || 'Faculty User';
  
  const [activeTab, setActiveTab] = useState('dashboard');
  const [edcPredictions, setEdcPredictions] = useState([]);
  const [documents, setDocuments] = useState([]);
  const [processTypes, setProcessTypes] = useState([]);
  const [search, setSearch] = useState('');
  const [filterStatus, setFilterStatus] = useState('All');
  
  // Pagination State for Dashboard Ledger
  const [currentPage, setCurrentPage] = useState(1);
  const [hasUnreadChats, setHasUnreadChats] = useState(false);
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
        
        const departmentToOfficeMap = {
          'College of Informatics and Computing Sciences': 'CICS Office',
          'College of Accountancy, Business, Economics and International Hospitality Management': 'CABEIHM Office',
          'College of Arts and Sciences': 'CAS Office',
          'College of Industrial Technology': 'CE / CIT Office',
          'College of Engineering': 'CE / CIT Office',
          'College of Teacher Education': 'CTE Office'
        };

        for (let i = 1; i <= 7; i++) {
          let stopName = match[`stop_${i}_name`];
          
          if (stopName === 'ORIGINATING_COLLEGE_DYNAMIC') {
            // Locks the display value to your account profile unit statically
            stopName = departmentToOfficeMap[profile.departmentName] || activeDoc.current_office || 'Origin Unit';
          }
          if (stopName) stops.push(stopName);
        }
        setRecentDocStops(stops);
      } else {
        setRecentDocStops([activeDoc.current_office || 'Origin Unit', activeDoc.next_office || 'Next Stop'].filter(Boolean));
      }
    }
  }, [documents, processTypes, profile.departmentName]);

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
    const fetchEDC = async () => {
      try {
        const res = await fetchWithAuth('http://localhost:5000/api/analytics/edc');
        if (res.ok) {
          const data = await res.json();
          setEdcPredictions(data);
        }
      } catch (err) { console.error("Error fetching EDC data:", err); }
    };
    fetchEDC();
  }, []);

  useEffect(() => {
    fetchLiveNotificationFeeds();
    const alertInterval = setInterval(fetchLiveNotificationFeeds, 10000);

    // CHAT SIDEBAR RED BADGE STATUS CHECK
    const checkChatBadgeStatus = async () => {
      try {
        const res = await fetchWithAuth('http://localhost:5000/api/chat/active-documents-directory');
        const data = await res.json();
        if (res.ok) {
          const hasAnyActiveOngoingChat = data.some(d => d.hasAnyChat === true);
          setHasUnreadChats(hasAnyActiveOngoingChat);
        }
      } catch (err) { console.error(err); }
    };
    checkChatBadgeStatus();
    const chatBadgeInterval = setInterval(checkChatBadgeStatus, 15000);

    return () => {
      clearInterval(alertInterval);
      clearInterval(chatBadgeInterval);
    };
  }, [userId]);

  // Reset pagination when search or filter changes
  useEffect(() => {
    setCurrentPage(1);
  }, [search, filterStatus]);

  // HANDLER FOR CHAT SHORTCUT REDIRECTS
  useEffect(() => {
    const pendingRedirectId = localStorage.getItem('redirect_target_doc_id');
    // If a user clicked "Chat regarding this file", switch to the messages tab immediately
    if (pendingRedirectId && activeTab !== 'messages') {
      setActiveTab('messages');
    }
  }, [activeTab]);

  const fetchLiveNotificationFeeds = async () => {
    try {
      const res = await fetchWithAuth(`http://localhost:5000/api/notifications/${userId}/1/0`);
      const data = await res.json();
      if (res.ok) {
        const alertCollection = data.map(n => ({
          id: n.id,
          ini_id: n.ini_id, // Captures document ID matching link
          title: n.title,
          message: n.message,
          time: n.time // Keep raw timestamp string for relative helper matching
        }));
        setNotifications(alertCollection);
      }
    } catch (err) { 
      console.error("Error retrieving notifications:", err); 
    }
  };

  const handleNotificationClick = (notif) => {
    setShowNotifications(false);
    if (!notif.ini_id) return;

    // Cache the intended target document identifier to the browser engine session
    localStorage.setItem('redirect_target_doc_id', String(notif.ini_id));
    
    // Switch the view instantly over to your documents workspace hub
    setActiveTab('documents');
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
      
      // FIND MATCHING PREDICTION
      const prediction = edcPredictions.find(e => e.process_id === parseInt(pId));
      
      if (prediction) {
        const hours = prediction.estimated_hours_to_complete;
        const futureDate = new Date();
        futureDate.setHours(futureDate.getHours() + hours);
        setEstimatedDate(futureDate.toLocaleDateString('en-US', { year: 'numeric', month: 'long', day: 'numeric' }));
      } else {
        setEstimatedDate("Estimation pending...");
      }
    } else {
      setSelectedRoutePreview([]);
      setForm({ ...form, processTypeId: '' });
      setEstimatedDate('');
    }
  };

  const submitDocument = async (e) => {
    e.preventDefault();
  
    // FIX: Convert "July 22, 2026" to "2026-07-22"
    let edcPayload = null;
    if (estimatedDate && estimatedDate !== "Estimation pending...") {
      const d = new Date(estimatedDate);
      edcPayload = `${d.getFullYear()}-${String(d.getMonth() + 1).padStart(2, '0')}-${String(d.getDate()).padStart(2, '0')}`;
    }
  
    try {
      const res = await fetchWithAuth('http://localhost:5000/api/documents', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ 
          userId: parseInt(userId), 
          title: form.title, 
          processTypeId: parseInt(form.processTypeId), 
          edc: edcPayload // Now passing 'YYYY-MM-DD'
        })
      });
      
      const data = await res.json();
      if (!res.ok) throw new Error(data.error || "Failed to submit");
      
      setGeneratedQr(data.qrCode);
      setShowModal(false);
      setShowQrModal(true);
      setForm({ title: '', processTypeId: '', confirmation: false });
      setSelectedRoutePreview([]);
      setEstimatedDate(''); // Reset
      fetchDashboardLedger();
    } catch (err) { 
      console.error("Frontend Submit Error:", err); 
      alert("Submission failed: " + err.message);
    }
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
            <button onClick={() => { setActiveTab('messages'); setHasUnreadChats(false); }} className={`w-full flex items-center justify-between px-3 py-2.5 rounded-lg text-left transition-colors ${activeTab === 'messages' ? 'bg-neutral-800 text-white font-medium' : 'text-neutral-400 hover:bg-neutral-800 hover:text-white'}`}>
                <div className="flex items-center gap-3">
                  <MessageSquare size={18} /> Chat with Offices
                </div>
                {hasUnreadChats && (
                  <span className="w-2 h-2 bg-red-600 rounded-full mr-1 animate-pulse"></span>
                )}
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
          <h2 className="text-lg font-bold text-neutral-800 capitalize">{activeTab} Management Hub</h2>
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
                      <div 
                        key={n.id} 
                        onClick={() => handleNotificationClick(n)}
                        className="p-4 text-xs text-left hover:bg-neutral-50 cursor-pointer transition-colors border-b last:border-b-0"
                      >
                        <div className="flex justify-between items-start gap-2">
                          <p className="font-bold text-neutral-900">{n.title}</p>
                          <span className="text-[10px] text-neutral-400 whitespace-nowrap">
                            {formatRelativeTime(n.time)}
                          </span>
                        </div>
                        <p className="text-neutral-500 mt-1">{n.message}</p>
                      </div>
                    ))}
                    {notifications.length === 0 && (
                      <div className="p-4 text-xs text-neutral-400 text-center font-bold">📭 No active updates.</div>
                    )}
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
                  <div className="flex justify-between items-center mb-4">
                    <h4 className="text-sm font-bold tracking-tight text-neutral-500 uppercase">
                      Recent Document: <span className="text-neutral-900 font-extrabold uppercase">{mostRecentDoc.title}</span>
                    </h4>
                    {mostRecentDoc.history_logs?.some(l => (l.is_adhoc === true || String(l.is_adhoc) === 'true' || l.is_adhoc === 1) && !l.time_out) && (
                      <span className="px-2 py-0.5 bg-purple-100 border border-purple-200 text-purple-800 rounded text-[9px] font-black uppercase tracking-wide">
                        📍 AD-HOC DETOUR ACTIVE
                      </span>
                    )}
                  </div>

                  {mostRecentDoc.history_logs?.some(l => (l.is_adhoc === true || String(l.is_adhoc) === 'true' || l.is_adhoc === 1) && !l.time_out) && (
                    <div className="mb-5 p-3.5 bg-purple-50/60 border border-purple-200 rounded-xl text-xs text-purple-800 font-medium flex items-center gap-2">
                      <span className="text-purple-600">⚡</span>
                      <span>This document has been temporarily routed to <strong className="text-purple-900 underline">{mostRecentDoc.current_office}</strong> for an unscheduled ad-hoc verification detour. Standard routing pipeline will resume once cleared.</span>
                    </div>
                  )}

                  <div className="relative flex items-center justify-between mt-6 px-4">
                    <div className="absolute left-4 right-4 h-1 bg-neutral-200 top-3 -z-10"></div>
                    
                    {(() => {
                      const historyLogs = mostRecentDoc.history_logs || [];
                      const isAdhocLog = (l) => l && (l.is_adhoc === true || String(l.is_adhoc) === 'true' || l.is_adhoc === 1 || String(l.is_adhoc) === 't');
                      
                      let resultStops = [];
                      let normalIndex = 0;
                      for (let i = 0; i < historyLogs.length; i++) {
                        const log = historyLogs[i];
                        if (isAdhocLog(log)) {
                          resultStops.push({ name: log.office_name, isAdhocNode: true, logRef: log });
                        } else {
                          if (normalIndex < recentDocStops.length) {
                            resultStops.push({ name: recentDocStops[normalIndex], isAdhocNode: false, logRef: log });
                            normalIndex++;
                          }
                        }
                      }
                      while (normalIndex < recentDocStops.length) {
                        resultStops.push({ name: recentDocStops[normalIndex], isAdhocNode: false, logRef: null });
                        normalIndex++;
                      }

                      let activeIndex = 0;
                      for (let i = 0; i < resultStops.length; i++) {
                         if (resultStops[i].logRef) activeIndex = i;
                      }
                      const percentage = resultStops.length <= 1 ? 0 : (Math.min(activeIndex, resultStops.length - 1) / (resultStops.length - 1)) * 100;

                      return (
                        <>
                          <div 
                            className={`absolute left-4 h-1 top-3 -z-10 transition-all duration-500 ease-in-out ${resultStops.some(n => n.isAdhocNode && n.logRef && !n.logRef.time_out) ? 'bg-purple-600' : 'bg-red-700'}`}
                            style={{ width: `calc(${mostRecentDoc.status?.toLowerCase() === 'completed' ? 100 : percentage}% - 32px)` }}
                          ></div>
                          
                          {resultStops.map((node, index) => {
                            const isCompletedAll = mostRecentDoc.status?.toLowerCase() === 'completed';
                            let isCurrent = false;
                            let isPast = false;

                            if (isCompletedAll) {
                              isPast = true;
                            } else if (node.logRef) {
                              if (!node.logRef.time_out) isCurrent = true;
                              else isPast = true;
                            }

                            return (
                              <div key={index} className="text-center flex flex-col items-center flex-1">
                                <div className={`w-7 h-7 rounded-full flex items-center justify-center text-xs font-bold transition-all shadow-xs ${
                                  isCurrent && node.isAdhocNode ? 'bg-purple-600 text-white ring-4 ring-purple-100 animate-pulse' :
                                  isCurrent ? 'bg-red-700 text-white ring-4 ring-red-100 animate-pulse' :
                                  isPast ? 'bg-red-800 text-white' : 'bg-neutral-200 text-neutral-500'
                                }`}>
                                  {isPast && !isCurrent ? '✓' : node.isAdhocNode ? '⚡' : index - resultStops.slice(0, index).filter(n => n.isAdhocNode).length + 1}
                                </div>
                                <p className={`text-[11px] font-bold mt-2 truncate max-w-[130px] ${isCurrent && node.isAdhocNode ? 'text-purple-700 font-extrabold' : isCurrent ? 'text-red-800 font-extrabold' : 'text-neutral-500'}`}>
                                  {node.name}
                                </p>
                              </div>
                            );
                          })}
                        </>
                      );
                    })()}
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
                      <input 
                        type="checkbox" 
                        checked={profile.twoFaEnabled} 
                        onChange={async (e) => {
                          const checked = e.target.checked;
                          if (!checked) {
                            // If turning off, update immediately
                            try {
                              const res = await fetchWithAuth(`http://localhost:5000/api/profile/${userId}`, {
                                method: 'PUT',
                                headers: { 'Content-Type': 'application/json' },
                                body: JSON.stringify({ 
                                  fullName: profile.fullName, 
                                  email: profile.email, 
                                  twoFaEnabled: false,
                                  twoFaCode: null 
                                })
                              });
                              if (res.ok) {
                                setProfile({...profile, twoFaEnabled: false});
                                minimalSwal.fire({ 
                                  icon: 'success', 
                                  title: 'Disabled', 
                                  text: 'Two-Factor Authentication is now off.' 
                                });
                              }
                            } catch (err) {
                              minimalSwal.fire({ 
                                icon: 'error', 
                                title: 'Error', 
                                text: 'Failed to update security settings.' 
                              });
                            }
                            return;
                          }
                          
                          // IF TURNING ON - Show loading state
                          minimalSwal.fire({
                            title: 'Sending Code...',
                            text: 'Please wait while we dispatch your verification email.',
                            allowOutsideClick: false,
                            didOpen: () => { minimalSwal.showLoading(); }
                          });

                          try {
                            // Trigger OTP email dispatch
                            const requestRes = await fetchWithAuth(`http://localhost:5000/api/users/${userId}/request-profile-otp`, { 
                              method: 'POST' 
                            });

                            if (!requestRes.ok) throw new Error('Failed to dispatch email.');

                            // Close the loading dialog
                            minimalSwal.close();

                            // Prompt for code input
                            const { value: otpCode } = await minimalSwal.fire({
                              title: 'Verify Your Email',
                              text: `We sent a 6-digit code to ${profile.email}.`,
                              input: 'text',
                              inputAttributes: { maxLength: 6, style: 'text-align: center; letter-spacing: 0.5em; font-weight: bold;' },
                              showCancelButton: true,
                              confirmButtonText: 'Verify & Enable',
                              cancelButtonText: 'Cancel'
                            });

                            if (otpCode) {
                              const verifyRes = await fetchWithAuth(`http://localhost:5000/api/profile/${userId}/verify-enable-2fa`, {
                                method: 'POST',
                                headers: { 'Content-Type': 'application/json' },
                                body: JSON.stringify({ otpCode })
                              });

                              if (verifyRes.ok) {
                                setProfile({...profile, twoFaEnabled: true});
                                minimalSwal.fire({ 
                                  icon: 'success', 
                                  title: 'Secured!', 
                                  text: 'Email Two-Factor Authentication is now active.' 
                                });
                              } else {
                                minimalSwal.fire({ 
                                  icon: 'error', 
                                  title: 'Invalid Code', 
                                  text: 'The verification code was incorrect.' 
                                });
                                // Keep 2FA disabled since verification failed
                                setProfile({...profile, twoFaEnabled: false});
                              }
                            } else {
                              // User cancelled the input
                              setProfile({...profile, twoFaEnabled: false});
                            }
                          } catch (err) {
                            minimalSwal.close();
                            minimalSwal.fire({ 
                              icon: 'error', 
                              title: 'Error', 
                              text: 'Failed to communicate with authentication server.' 
                            });
                            setProfile({...profile, twoFaEnabled: false});
                          }
                        }} 
                        className="sr-only peer" 
                      />
                        <div className="w-9 h-5 bg-neutral-200 peer-focus:outline-none rounded-full peer peer-checked:after:translate-x-full peer-checked:after:border-white after:content-[''] after:absolute after:top-[2px] after:left-[2px] after:bg-white after:border-gray-300 after:border after:rounded-full after:h-4 after:w-4 after:transition-all peer-checked:bg-red-700"></div>
                      </label>
                      </div>

                      
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
          {activeTab === 'messages' && (
            <OfficeChatHub userId={userId} roleId={1} />
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
            <QRCodeSVG 
                value={generatedQr} 
                size={140} 
                level={"H"} 
                includeMargin={true}
                fgColor={"#171717"}
              />
              <code className="text-[10px] mt-3 font-mono bg-white px-2 py-0.5 border rounded text-neutral-600 tracking-wider font-bold">
                {generatedQr}
              </code>
            </div>
            <button type="button" onClick={() => setShowQrModal(false)} className="w-full py-2 bg-neutral-900 hover:bg-neutral-800 text-white font-medium text-xs rounded-lg transition-colors">Done & Close</button>
          </div>
        </div> 
      )}
    </div>
  );
}