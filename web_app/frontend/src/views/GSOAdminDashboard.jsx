import React, { useState, useEffect, useRef } from 'react';
import { useNavigate } from 'react-router-dom';
import Swal from 'sweetalert2';
import { Scanner } from '@yudiel/react-qr-scanner';
import { QRCodeSVG } from 'qrcode.react';
import { 
  LayoutDashboard, Archive, ShoppingCart, BarChart3, History, Bell, User, Search, Filter, X, QrCode, LogOut, Eye, GitBranch, Camera, KeyRound, ShieldCheck, Building, Landmark, Download, FileText, Plus, Calendar, Lock, Edit, Trash2, Car, ChevronLeft, ChevronRight 
} from 'lucide-react';
import { AreaChart, Area, XAxis, YAxis, CartesianGrid, Tooltip, ResponsiveContainer, BarChart, Bar, Legend } from 'recharts';
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

export default function GSOAdminDashboard() {
  const navigate = useNavigate();
  const notificationRef = useRef(null);
  
  const userId = localStorage.getItem('userId');
  const userName = localStorage.getItem('user') || 'Admin User';
  
  const [activeTab, setActiveTab] = useState('dashboard');
  const [showNotifications, setShowNotifications] = useState(false);
  const [notifications, setNotifications] = useState([]);
  
  const [pipelineDocs, setPipelineDocs] = useState([]);  
  const [actionHistory, setActionHistory] = useState([]);
  const [processTypes, setProcessTypes] = useState([]);
  const [officesList, setOfficesList] = useState([]);
  const [expectedIncomingCount, setExpectedIncomingCount] = useState(0);
  
  // User Profile States
  const [profileName, setProfileName] = useState('');
  const [profileEmail, setProfileEmail] = useState('');
  const [facultyId, setFacultyId] = useState('N/A');
  const [departmentName, setDepartmentName] = useState('N/A');
  const [twoFaEnabled, setTwoFaEnabled] = useState(false);
  const [twoFaCode, setTwoFaCode] = useState('');
  const [currentPassword, setCurrentPassword] = useState('');
  const [newPassword, setNewPassword] = useState('');
  const [confirmPassword, setConfirmPassword] = useState('');

  // Workspace States
  const [gsoOfficeName, setGsoOfficeName] = useState('Loading Office...');
  const [gsoOfficeId, setGsoOfficeId] = useState(null);
  
  // UI & Search States
  const [search, setSearch] = useState('');
  const [filterStatus, setFilterStatus] = useState('All'); 
  const [historyFilter, setHistoryFilter] = useState('All'); // ✅ Added for History
  const [dashboardPage, setDashboardPage] = useState(1);
  const [historyPage, setHistoryPage] = useState(1);         // ✅ Added for History
  const [isHistoryDetails, setIsHistoryDetails] = useState(false); // ✅ Added to lock modal actions for history logs
  const itemsPerPage = 5;

  // Hybrid Modal States
  const [selectedDoc, setSelectedDoc] = useState(null);
  const [showDetailsModal, setShowDetailsModal] = useState(false);
  const [showAdHocForm, setShowAdHocForm] = useState(false);
  const [showSendBackForm, setShowSendBackForm] = useState(false);
  const [returnReason, setReturnReason] = useState('');
  const [selectedAdHocOffice, setSelectedAdHocOffice] = useState('');
  const [isActionProcessing, setIsActionProcessing] = useState(false);

  // Scanner States
  const [showScannerModal, setShowScannerModal] = useState(false);
  const [scanMode, setScanMode] = useState('time-in');
  const [simulatedQrInput, setSimulatedQrPayload] = useState('');
  const [showPassModal, setShowPassModal] = useState(false);

    // --- School Resources States ---
  const [assetsList, setAssetsList] = useState([]);
  const [equipmentInventory, setEquipmentInventory] = useState([]);
  const [assetBlackouts, setAssetBlackouts] = useState([]);
  const todayObj = new Date();
  const todayString = todayObj.toLocaleDateString('en-CA', { year: 'numeric', month: '2-digit', day: '2-digit' }).replace(/\//g, '-');

  // Resources Modal Controllers
  const [showAddAssetModal, setShowAddAssetModal] = useState(false);
  const [assetForm, setAssetForm] = useState({
    assetName: '',
    assetTypeId: '1', // Default to Room
    quantity: 1,
    isConfirmed: false
  });
  const [showInventoryModal, setShowInventoryModal] = useState(false);
  const [inventoryModalMode, setInventoryModalMode] = useState('LEND'); // 'LEND' or 'RETURN'
  const [selectedInventoryItem, setSelectedInventoryItem] = useState(null);
  const [showBlackoutModal, setShowBlackoutModal] = useState(false);

  const [showEditAssetModal, setShowEditAssetModal] = useState(false);
  const [selectedEditAsset, setSelectedEditAsset] = useState(null);
  const [assetSchedule, setAssetSchedule] = useState([]);

  const [activeCalendarTab, setActiveCalendarTab] = useState('Gymnasium'); // 'Vehicle' | 'Multimedia Room' | 'Gymnasium'
  const [blackoutForm, setBlackoutForm] = useState({ asd_id: '', start_time: '', end_time: '', reason: '' });
  const [currentCalendarDate, setCurrentCalendarDate] = useState(new Date());

  // Procurement & Modal States
  const [showChecklistMakerModal, setShowChecklistMakerModal] = useState(false);
  const [activeChecklistTab, setActiveChecklistTab] = useState('Vehicle');
  
  // Print Logs States
  const [showPrintModal, setShowPrintModal] = useState(false);
  const [printTargetTab, setPrintTargetTab] = useState('Vehicle'); 
  const [printStartDate, setPrintStartDate] = useState('');
  const [printEndDate, setPrintEndDate] = useState('');

  // --- Procurement Data States ---
  const [reservationsList, setReservationsList] = useState([]);
  const [logisticsList, setLogisticsList] = useState([]);

  // Procurement Search, Filter, and Pagination States
  const [procSearch, setProcSearch] = useState({ vehicle: '', multimedia: '', gym: '', logistics: '' });
  const [procFilter, setProcFilter] = useState({ vehicle: 'All', multimedia: 'All', gym: 'All', logistics: 'All' });
  const [procPage, setProcPage] = useState({ vehicle: 1, multimedia: 1, gym: 1, logistics: 1 });
  const itemsPerProcPage = 5;

  const fetchProcurementData = async () => {
    try {
      const resBookings = await fetchWithAuth('http://localhost:5000/api/procurement/reservations');
      if (resBookings.ok) {
        setReservationsList(await resBookings.json());
      }
      const resLogistics = await fetchWithAuth('http://localhost:5000/api/procurement/logistics');
      if (resLogistics.ok) {
        setLogisticsList(await resLogistics.json());
      }
    } catch (err) { console.error("Error fetching procurement data:", err); }
  };

  // Trigger fetch when Procurement tab is opened
  useEffect(() => {
    if (activeTab === 'procurement') {
      fetchProcurementData();
    }
  }, [activeTab]);

  const [bottleneckData, setBottleneckData] = useState([]);
  const [peakDemandData, setPeakDemandData] = useState([]);
  const [isAnalyticsLoading, setIsAnalyticsLoading] = useState(false);
  const [bottleneckSort, setBottleneckSort] = useState('desc');
  const [bottleneckSearch, setBottleneckSearch] = useState('');

  const fetchOperationalAnalytics = async () => {
    setIsAnalyticsLoading(true);
    try {
      // Fetch the Bottleneck Analytical Evaluation Process data
      const resBottlenecks = await fetchWithAuth('http://localhost:5000/api/analytics/bottlenecks');
      if (resBottlenecks.ok) {
        setBottleneckData(await resBottlenecks.json());
      }
      
      const resPeak = await fetchWithAuth('http://localhost:5000/api/analytics/peak-demand');
      if (resPeak.ok) {
        const rawPeakData = await resPeak.json();
        console.log("🔍 PYTHON PEAK DATA PAYLOAD:", rawPeakData); // Check your browser console!
        
        // Ensure values are numbers just in case Python sent strings
        const formattedPeakData = rawPeakData.map(item => ({
          ...item,
          demand: Number(item.demand || 0) 
        }));
        
        setPeakDemandData(formattedPeakData);
      }

      // Ensure inventory is loaded for the prescriptive card
      if (equipmentInventory.length === 0) {
        fetchInventoryMetrics();
      }
    } catch (err) {
      console.error("Error fetching analytics:", err);
    } finally {
      setIsAnalyticsLoading(false);
    }
  };

  // Trigger fetch when Analytics tab is opened
  useEffect(() => {
    if (activeTab === 'analytics') {
      fetchOperationalAnalytics();
    }
  }, [activeTab]);

  const fetchBlackouts = async () => {
    try {
      const res = await fetchWithAuth('http://localhost:5000/api/resources/blackouts');
      const data = await res.json();
      if (res.ok) setAssetBlackouts(data);
    } catch (err) { console.error(err); }
  };
  
  // Add fetchBlackouts to your existing useEffect for the resources tab
  useEffect(() => {
    if (activeTab === 'resources') {
      fetchMasterAssets();
      fetchInventoryMetrics();
      fetchBlackouts(); // <-- Added
    }
  }, [activeTab]);

  const [inventoryForm, setInventoryForm] = useState({
    requestorName: '', department: '', purpose: '', duration: '', quantityNeeded: '', 
    returnDate: '', returnTime: '', 
    isDamaged: false, damageNotes: '' // <-- Added these two
  });

const fetchMasterAssets = async () => {
  try {
    const res = await fetchWithAuth('http://localhost:5000/api/resources/assets');
    const data = await res.json();
    if (res.ok) setAssetsList(data);
  } catch (err) { console.error("Error pulling master assets:", err); }
};

// Trigger fetch when the Resources tab is clicked
useEffect(() => {
  if (activeTab === 'resources') {
    fetchMasterAssets();
  }
}, [activeTab]);

const handleAddAssetSubmit = async (e) => {
  e.preventDefault();
  if (!assetForm.isConfirmed) return minimalSwal.fire({ icon: 'warning', title: 'Confirmation Required', text: 'Please verify the asset accuracy.' });
  
  try {
    const res = await fetchWithAuth('http://localhost:5000/api/resources/assets', {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify(assetForm)
    });
    if (res.ok) {
      minimalSwal.fire({ icon: 'success', title: 'Asset Added', text: 'New asset registered to the master list.' });
      setShowAddAssetModal(false);
      setAssetForm({ assetName: '', assetTypeId: '1', quantity: 1, isConfirmed: false });
      fetchMasterAssets(); // Refresh the table
    }
  } catch (err) {
    minimalSwal.fire({ icon: 'error', title: 'Error', text: 'Failed to communicate with server.' });
  }
};

  useEffect(() => {
    if (!userId || userId === 'undefined') {
      localStorage.clear();
      navigate('/login');
      return;
    }
    fetchGSOMeta();
    fetchWorkflowTemplates();
    fetchOfficesList();
  }, [userId]);

  useEffect(() => {
    function handleClickOutside(event) {
      if (notificationRef.current && !notificationRef.current.contains(event.target)) setShowNotifications(false);
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

  const fetchGSOMeta = async () => {
    try {
      const res = await fetchWithAuth(`http://localhost:5000/api/profile/${userId}`);
      const data = await res.json();
      if (res.ok) {
        setGsoOfficeName(data.office_name || 'General Services Office');
        setGsoOfficeId(data.o_id);
        setProfileName(data.full_name || '');
        setProfileEmail(data.uni_email || '');
        setFacultyId(data.faculty_id || 'NOT ASSIGNED');
        setDepartmentName(data.department_name || 'GSO');
        setTwoFaEnabled(data.two_fa_enabled || false);
        setTwoFaCode(data.two_fa_code || '');

        fetchPipelineDocs(data.o_id);
        fetchOfficeActionHistory(data.o_id);
        fetchExpectedIncomingCount(data.o_id);
      }
    } catch (err) { console.error("Error connecting metadata:", err); }
  };

  const fetchExpectedIncomingCount = async (officeId) => {
    if (!officeId) return;
    try {
      const res = await fetchWithAuth(`http://localhost:5000/api/processor/documents/expected-count/${officeId}`);
      const data = await res.json();
      if (res.ok) setExpectedIncomingCount(data.count);
    } catch (err) { console.error("Expected incoming sync error:", err); }
  };

  const fetchGSOCombinedNotificationFeeds = async (officeId) => {
    if (!officeId) return;
    try {
      // 1. Fetch live parameters for Incoming Processor alerts
      const procRes = await fetchWithAuth(`http://localhost:5000/api/notifications/${userId}/2/${officeId}`);
      const procData = await procRes.json();
  
      // 2. Fetch live parameters for Pending Signee alerts
      const signRes = await fetchWithAuth(`http://localhost:5000/api/notifications/${userId}/3/${officeId}`);
      const signData = await signRes.json();
  
      if (procRes.ok && signRes.ok) {
        // Merge, unify payloads, and map database parameters cleanly
        const combined = [
          ...procData.map(n => ({ ...n, roleSource: 'Processor' })),
          ...signData.map(n => ({ ...n, roleSource: 'Signee' }))
        ];
  
        // Sort chronologically by newest time elements first
        combined.sort((a, b) => new Date(b.time) - new Date(a.time));
  
        setNotifications(combined.slice(0, 10)); // Keep the top 10 most recent alerts
      }
    } catch (err) {
      console.error("Error aggregating combined GSO alerts trail:", err);
    }
  };

  const fetchPipelineDocs = async (officeId) => {
    if (!officeId) return;
    try {
      const res = await fetchWithAuth(`http://localhost:5000/api/processor/documents/pipeline/${officeId}`);
      const data = await res.json();
      if (res.ok) setPipelineDocs(data);
    } catch (err) { console.error("Pipeline sync error:", err); }
  };

  const fetchOfficeActionHistory = async (officeId) => {
    if (!officeId) return;
    try {
      const res = await fetchWithAuth(`http://localhost:5000/api/processor/history/${officeId}`);
      const data = await res.json();
      if (res.ok) setActionHistory(data);
    } catch (err) { console.error("History log retrieval error:", err); }
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

  // --- Profile Hub Functions ---
  const handleUpdateProfile = async (e) => {
    e.preventDefault();
    try {
      const res = await fetchWithAuth(`http://localhost:5000/api/profile/${userId}`, {
        method: 'PUT',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ fullName: profileName, email: profileEmail, twoFaEnabled, twoFaCode: twoFaCode || null })
      });
      if (res.ok) {
        minimalSwal.fire({ icon: 'success', title: 'Profile Updated', text: 'Profile settings updated.' });
        localStorage.setItem('user', profileName);
        fetchGSOMeta();
      }
    } catch (err) { minimalSwal.fire({ icon: 'error', title: 'Error', text: 'Failed to synchronize profile changes.' }); }
  };

  const handleUpdatePassword = async (e) => {
    e.preventDefault();
    if (newPassword !== confirmPassword) return minimalSwal.fire({ icon: 'warning', title: 'Mismatch', text: 'New passwords do not match.' });
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
        setCurrentPassword(''); setNewPassword(''); setConfirmPassword('');
      } else {
        minimalSwal.fire({ icon: 'error', title: 'Error', text: data.error || 'Password update rejected.' });
      }
    } catch (err) { minimalSwal.fire({ icon: 'error', title: 'Error', text: 'Failed to modify database records.' }); }
  };

  const toggle2FA = async (checked) => {
    setTwoFaEnabled(checked);
    if (!checked) {
      try {
        const res = await fetchWithAuth(`http://localhost:5000/api/profile/${userId}`, {
          method: 'PUT',
          headers: { 'Content-Type': 'application/json' },
          body: JSON.stringify({ fullName: profileName, email: profileEmail, twoFaEnabled: false, twoFaCode: null })
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
    if (twoFaCode.length < 4 || twoFaCode.length > 6 || isNaN(twoFaCode)) return minimalSwal.fire({ icon: 'warning', title: 'Invalid PIN', text: 'PIN must be a 4-6 digit numeric code.' });
    try {
      const res = await fetchWithAuth(`http://localhost:5000/api/profile/${userId}`, {
        method: 'PUT',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ fullName: profileName, email: profileEmail, twoFaEnabled: true, twoFaCode })
      });
      if (res.ok) {
        minimalSwal.fire({ icon: 'success', title: 'PIN Configured', text: 'Custom security authentication PIN configured.' });
        fetchGSOMeta();
      }
    } catch (err) { minimalSwal.fire({ icon: 'error', title: 'Error', text: 'Failed to update credentials security PIN.' }); }
  };

  // --- Hybrid Functional Actions ---
  const executeSimulatedScanner = async (e, scannedCode = null) => {
    if (e) e.preventDefault();
    const targetQr = scannedCode || simulatedQrInput;
    if (!targetQr || !targetQr.trim()) {
      return minimalSwal.fire({ icon: 'warning', title: 'Input Required', text: 'Please type or scan a valid reference token string.' });
    }
    const targetUrl = scanMode === 'time-in' 
      ? 'http://localhost:5000/api/documents/scan-in' 
      : 'http://localhost:5000/api/documents/scan-out';

    try {
      const res = await fetchWithAuth(targetUrl, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ qrCode: targetQr, processorUserId: parseInt(userId) })
      });
      const data = await res.json();
      if (res.ok) {
        minimalSwal.fire({ icon: 'success', title: 'Transaction Approved', text: data.message });
        setShowScannerModal(false);
        setSimulatedQrPayload('');
        fetchGSOMeta();
      } else {
        minimalSwal.fire({ icon: 'error', title: 'Rejection', text: data.error || 'Processing verification failed.' });
      }
    } catch (err) { 
      minimalSwal.fire({ icon: 'error', title: 'Network Error', text: 'Failed to establish server authentication checks.' }); 
    }
  };

  const handleSignDocument = async () => {
    if (!selectedDoc) return;
    minimalSwal.fire({
      title: 'Confirm Signature',
      text: `This will certify "${selectedDoc.title}" and advance it out of GSO custody.`,
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
            body: JSON.stringify({ iniId: selectedDoc.ini_id, currentOfficeId: gsoOfficeId, signeeUserId: parseInt(userId) })
          });
          if (res.ok) {
            minimalSwal.fire({ icon: 'success', title: 'Successfully Signed!', text: 'Document approved. You may now Check-Out the physical file.' });
            setShowDetailsModal(false);
            fetchGSOMeta();
          }
        } catch (err) { minimalSwal.fire({ icon: 'error', title: 'Error', text: 'Signature commitment failed.' }); } 
        finally { setIsActionProcessing(false); }
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
        body: JSON.stringify({ iniId: selectedDoc.ini_id, currentOfficeId: gsoOfficeId, signeeUserId: parseInt(userId), reason: returnReason })
      });
      if (res.ok) {
        minimalSwal.fire({ icon: 'success', title: 'Document Sent Back', text: 'File frozen with Action Required status flags.' });
        setShowDetailsModal(false);
        fetchGSOMeta();
      }
    } catch (err) { minimalSwal.fire({ icon: 'error', title: 'Error', text: 'Failed to commit updates.' }); } 
    finally { setIsActionProcessing(false); }
  };

  const handleExecuteAdHocDetour = async (e) => {
    e.preventDefault();
    if (!selectedAdHocOffice) return minimalSwal.fire({ icon: 'warning', title: 'Required', text: 'Please select a destination campus unit.' });
    
    setIsActionProcessing(true);
    try {
      const res = await fetchWithAuth('http://localhost:5000/api/processor/documents/ad-hoc', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ iniId: selectedDoc.ini_id, targetOfficeId: parseInt(selectedAdHocOffice), currentOfficeId: gsoOfficeId, executorUserId: parseInt(userId) })
      });
      if (res.ok) {
        minimalSwal.fire({ icon: 'success', title: 'Detour Routed', text: 'Ad-hoc validation checkpoint successfully injected.' });
        setShowDetailsModal(false);
        fetchGSOMeta();
      }
    } catch (err) { minimalSwal.fire({ icon: 'error', title: 'Error', text: 'Ad-hoc communication assignment breakdown.' }); } 
    finally { setIsActionProcessing(false); }
  };

  const handleOpenDetails = (doc, fromHistory = false) => {
    setSelectedDoc(doc);
    setIsHistoryDetails(fromHistory); // ✅ Track if this is a historical view
    setShowSendBackForm(false);
    setShowAdHocForm(false);
    setReturnReason('');
    setSelectedAdHocOffice('');
    setShowDetailsModal(true);
  };

  // --- Filtering & Calculations ---
  
  const pendingDocsList = pipelineDocs.filter(d => d.status?.toLowerCase() === 'pending' && d.time_in !== null && !d.time_out);
  const archivedDocsList = pipelineDocs.filter(d => d.status?.toLowerCase() === 'action required');
  const completedDocsList = pipelineDocs.filter(d => d.status?.toLowerCase() === 'signed' || d.status?.toLowerCase() === 'completed' || d.time_out !== null);

  const filteredMasterDocs = pipelineDocs.filter(doc => {
    const matchesSearch = doc.title?.toLowerCase().includes(search.toLowerCase()) || doc.qr_code?.toLowerCase().includes(search.toLowerCase());
    if (filterStatus === 'Incoming') return matchesSearch && doc.time_in === null && !doc.time_out;
    if (filterStatus === 'Pending') return matchesSearch && doc.status?.toLowerCase() === 'pending' && doc.time_in !== null && !doc.time_out;
    if (filterStatus === 'Archived') return matchesSearch && doc.status?.toLowerCase() === 'action required';
    if (filterStatus === 'Completed') return matchesSearch && (doc.time_out !== null || doc.status?.toLowerCase() === 'signed' || doc.status?.toLowerCase() === 'completed');
    return matchesSearch;
  });

  const currentDashDocs = filteredMasterDocs.slice((dashboardPage - 1) * itemsPerPage, dashboardPage * itemsPerPage);
  const totalDashPages = Math.ceil(filteredMasterDocs.length / itemsPerPage);

  const isAwaitingScanIn = selectedDoc && !selectedDoc.time_in;
  const isInVerification = selectedDoc?.status?.toLowerCase() === 'in verification' || ((selectedDoc?.current_step_is_adhoc || selectedDoc?.is_adhoc) && selectedDoc?.current_office !== gsoOfficeName);
  const isActionAltered = selectedDoc && (selectedDoc.status?.toLowerCase() === 'signed' || selectedDoc.status?.toLowerCase() === 'completed' || selectedDoc.status?.toLowerCase() === 'action required' || selectedDoc.time_out);

  // --- History Log Calculations ---
  const filteredHistoryLogs = actionHistory.filter(log => {
    const matchesSearch = log.title?.toLowerCase().includes(search.toLowerCase()) || 
                          log.full_name?.toLowerCase().includes(search.toLowerCase()) || 
                          log.qr_code?.toLowerCase().includes(search.toLowerCase());
    return historyFilter !== 'All' ? (matchesSearch && log.action_type === historyFilter) : matchesSearch;
  });

  const currentHistoryPageRows = filteredHistoryLogs.slice((historyPage - 1) * itemsPerPage, historyPage * itemsPerPage);
  const totalHistoryTabPages = Math.ceil(filteredHistoryLogs.length / itemsPerPage);

  const handleDeleteAsset = (id, name) => {
    minimalSwal.fire({
      title: 'Delete Asset?',
      text: `Are you sure you want to permanently remove ${name}?`,
      icon: 'warning',
      showCancelButton: true,
      confirmButtonText: 'Yes, Delete'
    }).then(async (result) => {
      if (result.isConfirmed) {
        try {
          const res = await fetchWithAuth(`http://localhost:5000/api/resources/assets/${id}`, { method: 'DELETE' });
          if (res.ok) {
            minimalSwal.fire({ icon: 'success', title: 'Deleted', text: 'Asset removed from registry.' });
            fetchMasterAssets();
          } else {
            minimalSwal.fire({ icon: 'error', title: 'Error', text: 'Cannot delete asset tied to existing records.' });
          }
        } catch (err) { console.error(err); }
      }
    });
  };
  
  const handleOpenEditModal = async (asset) => {
    setSelectedEditAsset({ ...asset });
    setAssetSchedule([]); // Clear previous schedule
    setShowEditAssetModal(true);
    
    // Fetch upcoming confirmed reservations for this asset
    try {
      const res = await fetchWithAuth(`http://localhost:5000/api/resources/assets/${asset.asd_id}/schedule`);
      const data = await res.json();
      if (res.ok) setAssetSchedule(data);
    } catch (err) { console.error(err); }
  };
  
  const handleUpdateAsset = async (e) => {
    e.preventDefault();
    try {
      const res = await fetchWithAuth(`http://localhost:5000/api/resources/assets/${selectedEditAsset.asd_id}`, {
        method: 'PUT',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ assetName: selectedEditAsset.asset_name, quantity: selectedEditAsset.quantity })
      });
      if (res.ok) {
        minimalSwal.fire({ icon: 'success', title: 'Updated', text: 'Asset details saved.' });
        setShowEditAssetModal(false);
        fetchMasterAssets();
      }
    } catch (err) { console.error(err); }
  };

  const fetchInventoryMetrics = async () => {
    try {
      const res = await fetchWithAuth('http://localhost:5000/api/resources/inventory');
      const data = await res.json();
      if (res.ok) setEquipmentInventory(data);
    } catch (err) { console.error(err); }
  };
  
  // Update your existing useEffect to also fetch the inventory when the tab opens
  useEffect(() => {
    if (activeTab === 'resources') {
      fetchMasterAssets();
      fetchInventoryMetrics(); // <-- Add this line
    }
  }, [activeTab]);
  
  const handleInventorySubmit = async (e) => {
    e.preventDefault();
    setIsActionProcessing(true);
    
    const endpoint = inventoryModalMode === 'LEND' 
      ? 'http://localhost:5000/api/resources/inventory/lend' 
      : 'http://localhost:5000/api/resources/inventory/return';
  
      const payload = inventoryModalMode === 'LEND' ? {
        asd_id: selectedInventoryItem.asd_id,
        requestorName: inventoryForm.requestorName,
        department: inventoryForm.department,
        purpose: inventoryForm.purpose,
        quantityNeeded: parseInt(inventoryForm.quantityNeeded),
        duration: inventoryForm.duration
      } : {
        asd_id: selectedInventoryItem.asd_id,
        requestorName: inventoryForm.requestorName,
        quantityReturned: parseInt(inventoryForm.quantityNeeded),
        isDamaged: inventoryForm.isDamaged,        
        damageNotes: inventoryForm.damageNotes      
      };
  
    try {
      const res = await fetchWithAuth(endpoint, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify(payload)
      });
      
      if (res.ok) {
        minimalSwal.fire({ icon: 'success', title: 'Transaction Logged', text: `Stock successfully updated for ${selectedInventoryItem.asset_name}.` });
        setShowInventoryModal(false);
        setInventoryForm({ requestorName: '', department: '', purpose: '', duration: '', quantityNeeded: '', returnDate: '', returnTime: '' });
        fetchInventoryMetrics(); // Refresh the numbers!
      } else {
        const errData = await res.json();
        minimalSwal.fire({ icon: 'error', title: 'Error', text: errData.error || 'Transaction failed.' });
      }
    } catch (err) { console.error(err); }
    finally { setIsActionProcessing(false); }
  };

  const handleApplyBlackout = async (e) => {
    e.preventDefault();
    try {
      const res = await fetchWithAuth('http://localhost:5000/api/resources/blackouts', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify(blackoutForm)
      });
      if (res.ok) {
        minimalSwal.fire({ icon: 'success', title: 'Date Blocked', text: 'Asset availability updated.' });
        setShowBlackoutModal(false);
        setBlackoutForm({ asd_id: '', start_time: '', end_time: '', reason: '' });
        fetchBlackouts(); // Refresh the calendar!
      }
    } catch (err) { console.error(err); }
  };

  // --- Procurement Data Processing ---
  const processProcurementData = (type, dataArray, searchKey, filterKey, pageKey) => {
    let filtered = dataArray;
    
    // 1. Filter by Reservation Type (for the bookings table)
    if (type !== 'Logistics') {
      filtered = filtered.filter(item => item.booking_type === type);
    }

    // 2. Apply Search
    if (procSearch[searchKey]) {
      const lowerSearch = procSearch[searchKey].toLowerCase();
      filtered = filtered.filter(item => 
        (item.requestor && item.requestor.toLowerCase().includes(lowerSearch)) ||
        (item.requestor_name && item.requestor_name.toLowerCase().includes(lowerSearch)) ||
        (item.asset_name && item.asset_name.toLowerCase().includes(lowerSearch))
      );
    }

    // 3. Apply Status Filter
    if (procFilter[filterKey] !== 'All') {
      filtered = filtered.filter(item => item.status === procFilter[filterKey]);
    }

    // 4. Calculate Pagination
    const totalPages = Math.ceil(filtered.length / itemsPerProcPage) || 1;
    const currentPage = procPage[pageKey];
    const paginatedData = filtered.slice((currentPage - 1) * itemsPerProcPage, currentPage * itemsPerProcPage);

    return { filteredData: filtered, paginatedData, totalPages };
  };

  const vehicleData = processProcurementData('Vehicle', reservationsList, 'vehicle', 'vehicle', 'vehicle');
  const multimediaData = processProcurementData('Room', reservationsList, 'multimedia', 'multimedia', 'multimedia');
  const gymData = processProcurementData('Gymnasium', reservationsList, 'gym', 'gym', 'gym');
  const logData = processProcurementData('Logistics', logisticsList, 'logistics', 'logistics', 'logistics');

  // --- Active Checklist Modal States ---
  const [showActiveChecklistModal, setShowActiveChecklistModal] = useState(false);
  const [activeChecklistBooking, setActiveChecklistBooking] = useState(null);
  const [activeChecklistItems, setActiveChecklistItems] = useState([]);

  // Fetch the specific checklist for a reservation
  const handleViewChecklist = async (booking) => {
    setActiveChecklistBooking(booking);
    try {
      const res = await fetchWithAuth(`http://localhost:5000/api/procurement/checklists/${booking.booking_id}/${booking.booking_type}`);
      if (res.ok) {
        setActiveChecklistItems(await res.json());
        setShowActiveChecklistModal(true);
      }
    } catch (err) { console.error("Error fetching checklist:", err); }
  };

  // Toggle individual checklist items and trigger auto-confirm checks
  const handleToggleChecklistItem = async (checkId, currentStatus) => {
    try {
      const res = await fetchWithAuth(`http://localhost:5000/api/procurement/checklists/${checkId}`, {
        method: 'PUT',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ isChecked: !currentStatus, bookingId: activeChecklistBooking.booking_id })
      });
      if (res.ok) {
        // Update the local UI instantly so the checkmark appears
        setActiveChecklistItems(prev => prev.map(item => 
          item.check_id === checkId ? { ...item, is_checked: !currentStatus } : item
        ));

        window.dispatchEvent(new Event('refreshReservations'));
        
        // Refresh the main tables in the background so the status updates if it hit 100%
        fetchProcurementData(); 
      }
    } catch (err) { console.error("Error updating checklist:", err); }
  };

  // --- Master Checklist States & Functions ---
  const [masterChecklistItems, setMasterChecklistItems] = useState([]);
  const [newChecklistName, setNewChecklistName] = useState('');

  // Fetch templates when modal opens or tab changes
  useEffect(() => {
    if (showChecklistMakerModal) {
      const fetchTemplates = async () => {
        const typeMapping = { 'Vehicle': 'Vehicle', 'Multimedia Room': 'Room', 'Gymnasium': 'Gymnasium' };
        const targetType = typeMapping[activeChecklistTab];
        try {
          // Assuming your backend has an endpoint for templates by facility type
          const res = await fetchWithAuth(`http://localhost:5000/api/procurement/templates/${targetType}`);
          if (res.ok) setMasterChecklistItems(await res.json());
        } catch (err) { console.error("Error fetching templates:", err); }
      };
      fetchTemplates();
    }
  }, [showChecklistMakerModal, activeChecklistTab]);

  const handleAddMasterChecklistItem = async (e) => {
    e.preventDefault();
    if (!newChecklistName.trim()) return;

    const typeMapping = { 'Vehicle': 'Vehicle', 'Multimedia Room': 'Room', 'Gymnasium': 'Gymnasium' };
    const targetType = typeMapping[activeChecklistTab];

    try {
      const res = await fetchWithAuth(`http://localhost:5000/api/procurement/templates`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ bookingType: targetType, itemName: newChecklistName })
      });
      if (res.ok) {
        setNewChecklistName('');
        // Re-fetch to update the list
        const updated = await fetchWithAuth(`http://localhost:5000/api/procurement/templates/${targetType}`);
        setMasterChecklistItems(await updated.json());
      }
    } catch (err) { console.error("Error adding template:", err); }
  };

  const handleDeleteMasterChecklistItem = async (templateId) => {
    try {
      const res = await fetchWithAuth(`http://localhost:5000/api/procurement/templates/${templateId}`, {
        method: 'DELETE'
      });
      if (res.ok) {
        setMasterChecklistItems(prev => prev.filter(item => item.template_id !== templateId));
      }
    } catch (err) { console.error("Error deleting template:", err); }
  };

  // --- PDF Export Generation ---
  const handleGeneratePDF = () => {
    let dataToPrint = [];
    
    // Filter logic based on selected tab and dates
    if (printTargetTab === 'Logistics History') {
      dataToPrint = logisticsList.filter(log => {
        const logDate = new Date(log.borrowed_at).toISOString().split('T')[0];
        const afterStart = printStartDate ? logDate >= printStartDate : true;
        const beforeEnd = printEndDate ? logDate <= printEndDate : true;
        return afterStart && beforeEnd;
      });
    } else {
      const typeMap = { 'Vehicle': 'Vehicle', 'Multimedia Room': 'Room', 'Gymnasium': 'Gymnasium' };
      dataToPrint = reservationsList.filter(res => {
        const isCorrectType = res.booking_type === typeMap[printTargetTab];
        const resDate = new Date(res.reservation_date).toISOString().split('T')[0];
        const afterStart = printStartDate ? resDate >= printStartDate : true;
        const beforeEnd = printEndDate ? resDate <= printEndDate : true;
        return isCorrectType && afterStart && beforeEnd;
      });
    }

    if (dataToPrint.length === 0) {
      return minimalSwal.fire({ icon: 'warning', title: 'No Records', text: 'No records found for the selected date range.' });
    }

    // Build the HTML for the print window
    const printWindow = window.open('', '_blank');
    
    let tableHeaders = '';
    let tableRows = '';

    if (printTargetTab === 'Logistics History') {
      tableHeaders = `
        <tr>
          <th>Asset</th>
          <th>Requestor</th>
          <th>Qty</th>
          <th>Lending Time</th>
          <th>Return Time</th>
          <th>Condition / Notes</th>
        </tr>`;
      
      tableRows = dataToPrint.map(log => `
        <tr>
          <td><strong>${log.asset_name}</strong></td>
          <td>${log.requestor_name}</td>
          <td>${log.qty_borrowed}</td>
          <td>${log.borrowed_at ? new Date(log.borrowed_at).toLocaleString() : 'N/A'}</td>
          <td>${log.returned_at ? new Date(log.returned_at).toLocaleString() : 'Pending'}</td>
          <td>
          ${log.status === 'Returned'
            ? (log.condition_on_return === 'Damaged' ? `<span style="color:red; font-weight:bold;">Damaged:</span> ${log.damage_notes || 'No notes provided'}` : 'Good Condition')
            : 'Out / Borrowed'}
          </td>
        </tr>`).join('');
    } else {
      tableHeaders = `
        <tr>
          <th>Requestor</th>
          <th>Purpose</th>
          <th>Target Date & Time</th>
          <th>System Request Made</th>
          <th>Confirmed At</th>
          <th>Status</th>
        </tr>`;
      
      tableRows = dataToPrint.map(res => `
        <tr>
          <td><strong>${res.requestor || res.requestor_name || 'N/A'}</strong></td>
          <td>${res.purpose}</td>
          <td>${new Date(res.reservation_date).toLocaleDateString()} <br> <small>${res.start_time?.substring(0,5)} - ${res.end_time?.substring(0,5)}</small></td>
          <td>${res.created_at ? new Date(res.created_at).toLocaleString() : 'N/A'}</td>
          <td>${res.updated_at ? new Date(res.updated_at).toLocaleString() : 'Pending'}</td>
          <td style="font-weight:bold; color: ${res.status === 'Confirmed' ? 'green' : '#d97706'}">${res.status}</td>
        </tr>`).join('');
    }

    const htmlContent = `
      <html>
        <head>
          <title>Exported Logs - ${printTargetTab}</title>
          <style>
            body { font-family: 'Segoe UI', Tahoma, Geneva, Verdana, sans-serif; padding: 20px; color: #333; }
            .header { border-bottom: 2px solid #991b1b; padding-bottom: 10px; margin-bottom: 20px; }
            .header h1 { margin: 0; color: #991b1b; font-size: 24px; }
            .header p { margin: 5px 0 0 0; color: #666; font-size: 12px; }
            table { w-full; border-collapse: collapse; margin-top: 10px; font-size: 12px; width: 100%; }
            th { background-color: #f87171; color: white; text-align: left; padding: 10px; font-weight: bold; text-transform: uppercase; font-size: 10px; }
            td { padding: 10px; border-bottom: 1px solid #e5e5e5; }
            tr:nth-child(even) { background-color: #f9fafb; }
          </style>
        </head>
        <body>
          <div class="header">
            <h1>BSU GSO Procurement Logs</h1>
            <p><strong>Category:</strong> ${printTargetTab}</p>
            <p><strong>Date Filter:</strong> ${printStartDate || 'Beginning of records'} to ${printEndDate || 'Present'}</p>
            <p><strong>Generated On:</strong> ${new Date().toLocaleString()}</p>
          </div>
          <table>
            <thead>${tableHeaders}</thead>
            <tbody>${tableRows}</tbody>
          </table>
        </body>
      </html>
    `;

    printWindow.document.write(htmlContent);
    printWindow.document.close();
    
    // Allow styles to load before calling print
    setTimeout(() => {
      printWindow.print();
    }, 250);
  };

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

  const processedBottleneckData = [...bottleneckData]
    .filter(d => d.office_name?.toLowerCase().includes(bottleneckSearch.toLowerCase()))
    .sort((a, b) => bottleneckSort === 'desc' ? b.dwell_time_hours - a.dwell_time_hours : a.dwell_time_hours - b.dwell_time_hours)
    .slice(0, 5);

  return (
    <div className="flex h-screen w-screen bg-[#FAF8F5] text-neutral-800 font-sans overflow-hidden">
      
      {/* SIDEBAR */}
      <div className="w-64 bg-[#2D1F1E] text-neutral-300 flex flex-col justify-between p-4 flex-shrink-0 text-left">
        <div>
          <div className="border-b border-neutral-700 pb-4 mb-6">
            <h1 className="font-bold text-white text-lg">BSU Portal</h1>
            <span className="text-[10px] text-neutral-400 uppercase tracking-widest font-black">GSO Administration</span>
          </div>
          
          <nav className="space-y-1 text-sm">
            <button onClick={() => { setActiveTab('dashboard'); setSearch(''); setFilterStatus('All'); setDashboardPage(1); }} className={`w-full flex items-center gap-3 px-3 py-2.5 rounded-lg font-bold transition-colors ${activeTab === 'dashboard' ? 'bg-[#3b2a29] text-white border-l-4 border-red-700' : 'text-neutral-400 hover:bg-[#3b2a29] hover:text-white'}`}>
              <LayoutDashboard size={18} /> GSO Dashboard
            </button>
            <button onClick={() => setActiveTab('resources')} className={`w-full flex items-center gap-3 px-3 py-2.5 rounded-lg font-bold transition-colors ${activeTab === 'resources' ? 'bg-[#3b2a29] text-white border-l-4 border-red-700' : 'text-neutral-400 hover:bg-[#3b2a29] hover:text-white'}`}>
              <Archive size={18} /> School Resources
            </button>
            <button onClick={() => setActiveTab('procurement')} className={`w-full flex items-center gap-3 px-3 py-2.5 rounded-lg font-bold transition-colors ${activeTab === 'procurement' ? 'bg-[#3b2a29] text-white border-l-4 border-red-700' : 'text-neutral-400 hover:bg-[#3b2a29] hover:text-white'}`}>
              <ShoppingCart size={18} /> Procurement
            </button>
            <button onClick={() => setActiveTab('analytics')} className={`w-full flex items-center gap-3 px-3 py-2.5 rounded-lg font-bold transition-colors ${activeTab === 'analytics' ? 'bg-[#3b2a29] text-white border-l-4 border-red-700' : 'text-neutral-400 hover:bg-[#3b2a29] hover:text-white'}`}>
              <BarChart3 size={18} /> Operational Analytics
            </button>
            <button onClick={() => setActiveTab('history')} className={`w-full flex items-center gap-3 px-3 py-2.5 rounded-lg font-bold transition-colors ${activeTab === 'history' ? 'bg-[#3b2a29] text-white border-l-4 border-red-700' : 'text-neutral-400 hover:bg-[#3b2a29] hover:text-white'}`}>
              <History size={18} /> History
            </button>
          </nav>
        </div>

        <div className="border-t border-neutral-700 pt-4 flex items-center gap-3">
          <div className="bg-red-700 text-white font-black text-xs w-8 h-8 rounded-full flex items-center justify-center">GA</div>
          <div className="flex-1 text-left min-w-0">
            <p className="text-xs font-black text-white truncate">{userName}</p>
          </div>
          <button onClick={handleLogout} className="text-neutral-400 hover:text-red-400 transition-colors"><LogOut size={16} /></button>
        </div>
      </div>

      <div className="flex-1 flex flex-col overflow-hidden relative">
        
        {/* TOP HEADER */}
        <header className="h-16 border-b border-neutral-200 bg-white px-8 flex items-center justify-end shadow-sm flex-shrink-0 relative">
  <div className="flex items-center gap-4 text-neutral-600">
    
    {/* THE BELL CONTROLLER WRAPPER */}
    <div className="relative" ref={notificationRef}>
      <button 
        onClick={() => setShowNotifications(!showNotifications)} 
        className="p-2 rounded-full hover:bg-neutral-100 relative transition-colors"
      >
        <Bell size={20} />
        {notifications.length > 0 && <span className="absolute top-1 right-1 w-2 h-2 bg-red-600 rounded-full"></span>}
      </button>

      {/* PASTE THE DROPDOWN CODE BLOCK DIRECTLY HERE BELOW THE BUTTON */}
      {showNotifications && (
        <div className="absolute right-0 mt-2 w-80 bg-white border border-neutral-200 rounded-2xl shadow-xl z-50 overflow-hidden text-left">
          <div className="p-4 border-b border-neutral-100 bg-[#FDFBF9] font-bold text-xs uppercase text-neutral-900 tracking-wide">Notifications</div>
          <div className="max-h-64 overflow-y-auto divide-y divide-neutral-100">
            {notifications.map(n => (
              <div key={n.id} className="p-4 text-xs border-b last:border-b-0 hover:bg-neutral-50/50 transition-colors">
                <div className="flex justify-between items-start gap-2">
                  <div>
                    <p className="font-bold text-neutral-900">{n.title}</p>
                    <span className="text-[8px] bg-red-50 text-red-800 border px-1 rounded uppercase font-black tracking-tight mt-0.5 inline-block">
                      {n.roleSource || 'System'}
                    </span>
                  </div>
                  {/* Added relative time tracker span segment */}
                  <span className="text-[10px] text-neutral-400 whitespace-nowrap">
                    {formatRelativeTime(n.time)}
                  </span>
                </div>
                <p className="text-neutral-500 mt-1.5 font-medium leading-relaxed">{n.message}</p>
              </div>
            ))}
            {notifications.length === 0 && (
              <div className="p-6 text-center text-neutral-400 font-bold text-xs">📭 No active system notifications.</div>
            )}
          </div>
        </div>
      )}
    </div>
    
    <button onClick={() => setActiveTab('profile')} className="flex items-center gap-2 px-3 py-1.5 rounded-full hover:bg-neutral-100 transition-colors border">
      <User size={16} />
      <span className="text-xs font-bold text-neutral-800">GSO Admin Portal</span>
    </button>
  </div>
</header>

        <div className="flex-1 overflow-y-auto p-8">
          
          {activeTab === 'dashboard' && (
            <div className="space-y-6 max-w-7xl mx-auto text-left animate-in fade-in duration-200">
              
              {/* TOP CARDS SECTION */}
              <div className="grid grid-cols-1 lg:grid-cols-12 gap-4">
                
                {/* Profile Identity Card */}
                <div className="lg:col-span-4 bg-white border border-neutral-200 p-5 rounded-xl shadow-sm">
                  <span className="text-[10px] font-black uppercase text-red-700 tracking-wider">Institutional Profile</span>
                  <h2 className="text-xl font-black text-neutral-900 mt-1">{userName}</h2>
                  <div className="space-y-1 mt-3">
                    <p className="text-xs text-neutral-600 font-bold flex items-center gap-2"><User size={14} className="text-neutral-400"/> GSO Administrator</p>
                    <p className="text-xs text-neutral-600 font-bold flex items-center gap-2"><Building size={14} className="text-neutral-400"/> {gsoOfficeName}</p>
                  </div>
                  <div className="flex gap-2 mt-5">
                    <button onClick={() => setActiveTab('profile')} className="bg-red-800 text-white text-[10px] font-black uppercase tracking-wider px-4 py-2 rounded-lg hover:bg-red-900 transition-colors shadow-sm">Edit Profile</button>
                    <button onClick={() => setActiveTab('profile')} className="bg-white border border-red-200 text-red-800 text-[10px] font-black uppercase tracking-wider px-4 py-2 rounded-lg hover:bg-red-50 transition-colors">Settings</button>
                  </div>
                </div>

                {/* KPI Metrics List (Read Only Now) */}
                <div className="lg:col-span-8 grid grid-cols-2 md:grid-cols-5 gap-4">
                  {[
                    { label: 'Total Documents', count: pipelineDocs.length, icon: '📁', color: 'text-neutral-800' },
                    { label: 'Incoming', count: expectedIncomingCount, icon: '📥', color: 'text-blue-600' },
                    { label: 'Pending', count: pendingDocsList.length, icon: '⏳', color: 'text-amber-600' },
                    { label: 'Archived', count: archivedDocsList.length, icon: '📦', color: 'text-red-700' },
                    { label: 'Completed', count: completedDocsList.length, icon: '✅', color: 'text-green-600' }
                  ].map((kpi, idx) => (
                    <div 
                      key={idx} 
                      className="bg-white border border-neutral-200 p-4 rounded-xl shadow-sm flex flex-col justify-between"
                    >
                      <div className="text-center w-full flex flex-col items-center">
                        <div className="w-10 h-10 bg-neutral-50 border rounded-lg flex items-center justify-center text-lg mb-2">{kpi.icon}</div>
                        <span className="text-[9px] font-black uppercase text-neutral-400 tracking-wider text-center">{kpi.label}</span>
                      </div>
                      <p className={`text-3xl font-black text-center mt-2 ${kpi.color}`}>{kpi.count}</p>
                    </div>
                  ))}
                </div>
              </div>

              {/* UNIFIED GSO MASTER TABLE */}
              <div className="bg-white border border-neutral-200 rounded-xl shadow-sm overflow-hidden text-left">
                <div className="p-5 border-b border-neutral-100 flex flex-col md:flex-row justify-between items-center gap-4 bg-[#FDFBF9]">
                  <div>
                    <h3 className="text-lg font-black text-neutral-900">GSO Document Tracking</h3>
                    <p className="text-xs text-neutral-500 font-medium">Manage and monitor institutional procurement and property documents</p>
                  </div>
                  <div className="flex items-center gap-2">
                    <div className="relative">
                      <Search className="absolute left-3 top-2.5 text-neutral-400" size={14} />
                      <input type="text" placeholder="Search document title..." value={search} onChange={e => { setSearch(e.target.value); setDashboardPage(1); }} className="pl-9 pr-4 py-2 text-xs border border-neutral-300 rounded-lg outline-none w-64 bg-white shadow-xs focus:ring-1 focus:ring-red-700" />
                    </div>
                    {/* Filter and Download Combined Section */}
                    <div className="flex items-center gap-1 border border-neutral-300 bg-white px-2 py-1.5 rounded-lg text-xs font-bold text-neutral-700 shadow-xs hover:bg-neutral-50 transition-colors">
                      <Filter size={14} className="text-neutral-500" />
                      <select 
                        value={filterStatus} 
                        onChange={e => { setFilterStatus(e.target.value); setDashboardPage(1); }} 
                        className="bg-transparent outline-none cursor-pointer text-neutral-700 font-bold"
                      >
                        <option value="All">All Statuses</option>
                        <option value="Incoming">Awaiting Scan-In</option>
                        <option value="Pending">Pending Signature</option>
                        <option value="Archived">Action Required (Archived)</option>
                        <option value="Completed">Completed / Signed</option>
                      </select>
                    </div>
                    <button className="flex items-center justify-center border border-neutral-300 bg-white p-2 rounded-lg text-neutral-700 shadow-xs hover:bg-neutral-50 transition-colors">
                      <Download size={15} />
                    </button>
                  </div>
                </div>

                <div className="overflow-x-auto">
                  <table className="w-full text-xs text-left">
                    <thead>
                      <tr className="bg-white border-b border-neutral-200 font-black uppercase text-[10px] text-neutral-500 tracking-wider">
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
                          <td className="p-4">
                            <div className="flex items-center gap-3">
                              <FileText className="text-red-700 opacity-80" size={18} />
                              <div>
                                <p className="font-black text-neutral-900 text-sm leading-tight">{doc.title}</p>
                                <span className="text-[10px] text-neutral-400">{doc.process_name}</span>
                              </div>
                            </div>
                          </td>
                          <td className="p-4 font-bold text-neutral-600">
                            {doc.process_name.includes('APP') ? 'APP-GSO' : doc.process_name.includes('PAR') ? 'PAR-IT' : doc.process_name.includes('ICS') ? 'ICS-SUP' : 'GSO-FRM'}
                          </td>
                          <td className="p-4">
                            <span className={`inline-flex items-center gap-1.5 font-bold ${
                              !doc.time_in ? 'text-blue-600' :
                              doc.status?.toLowerCase() === 'in verification' ? 'text-red-700' :
                              doc.status?.toLowerCase() === 'signed' || doc.time_out ? 'text-green-600' :
                              'text-amber-600'
                            }`}>
                              <span className={`w-1.5 h-1.5 rounded-full ${
                                !doc.time_in ? 'bg-blue-600' :
                                doc.status?.toLowerCase() === 'in verification' ? 'bg-red-700' :
                                doc.status?.toLowerCase() === 'signed' || doc.time_out ? 'bg-green-600' :
                                'bg-amber-600'
                              }`}></span>
                              {!doc.time_in ? 'Incoming' : doc.time_out ? 'Completed' : doc.status || 'Pending'}
                            </span>
                          </td>
                          <td className="p-4 font-semibold text-neutral-600">{doc.originating_office || 'University Unit'}</td>
                          <td className="p-4 text-center">
                            <button onClick={() => handleOpenDetails(doc, false)} className="p-1.5 hover:bg-neutral-100 rounded-lg text-neutral-600 inline-flex items-center"><Eye size={18} /></button>
                          </td>
                        </tr>
                      ))}
                    </tbody>
                  </table>
                  {filteredMasterDocs.length === 0 && <div className="p-12 text-center text-neutral-400 font-bold">📭 No documents match the criteria.</div>}
                </div>

                <div className="p-4 border-t bg-[#FDFBF9] flex items-center justify-between text-xs font-bold text-neutral-500 px-6">
                  <span>Showing {currentDashDocs.length} of {filteredMasterDocs.length} records</span>
                  <div className="flex gap-1">
                    <button disabled={dashboardPage === 1} onClick={() => setDashboardPage(prev => prev - 1)} className="w-8 h-8 flex items-center justify-center border bg-white rounded-lg disabled:opacity-40 hover:bg-neutral-50">&lt;</button>
                    <span className="w-8 h-8 flex items-center justify-center bg-red-800 text-white rounded-lg">{dashboardPage}</span>
                    <button disabled={dashboardPage === totalDashPages || totalDashPages === 0} onClick={() => setDashboardPage(prev => prev + 1)} className="w-8 h-8 flex items-center justify-center border bg-white rounded-lg disabled:opacity-40 hover:bg-neutral-50">&gt;</button>
                  </div>
                </div>
              </div>

            </div>
          )}

            {activeTab === 'resources' && (
              <div className="max-w-7xl mx-auto space-y-6 text-left animate-in fade-in duration-200">
                
                {/* HEADER SECTION */}
                <div className="flex justify-between items-end border-b border-neutral-200 pb-4">
                  <div>
                    <h2 className="text-xl font-black text-neutral-900">Administrative Asset Management</h2>
                    <p className="text-xs text-neutral-500 font-medium mt-1">Hub for managing institutional resources and logistics</p>
                  </div>
                  <button 
                    onClick={() => setShowAddAssetModal(true)}
                    className="px-5 py-2 bg-red-800 hover:bg-red-900 text-white font-bold text-xs rounded-xl shadow-sm transition-colors flex items-center gap-2"
                  >
                    <Plus size={16} /> Add New Asset
                  </button>
                </div>

                {/* TOP ROW: Management Table & Inventory Cards */}
                <div className="grid grid-cols-1 lg:grid-cols-3 gap-6">
                  
                  {/* LEFT COLUMN: Resource Management Master Table */}
                  <div className="lg:col-span-2 bg-white border border-neutral-200 rounded-2xl p-5 shadow-sm">
                    <div className="flex justify-between items-center mb-4">
                      <h3 className="text-sm font-black text-neutral-900 flex items-center gap-2">
                        <Archive size={16} className="text-red-800" /> Resource Management
                      </h3>
                      <div className="flex items-center gap-2 text-xs">
                        <span className="font-bold text-neutral-500">Filter:</span>
                        <select className="border border-neutral-300 rounded-lg px-2 py-1 outline-none font-bold text-neutral-700 bg-neutral-50">
                          <option value="All">All Assets</option>
                          <option value="Room">Rooms</option>
                          <option value="Vehicle">Vehicles</option>
                        </select>
                      </div>
                    </div>
                    
                    {/* Table will go here */}
                    <div className="overflow-x-auto border border-neutral-200 rounded-xl">
                      <table className="w-full text-left text-xs">
                        <thead>
                          <tr className="bg-red-50/50 border-b border-neutral-200 font-black uppercase text-[10px] text-neutral-600 tracking-wider">
                            <th className="p-3 pl-4">Asset Name</th>
                            <th className="p-3">Type</th>
                            <th className="p-3">Status</th>
                            <th className="p-3 text-right pr-4">Actions</th>
                          </tr>
                        </thead>
                        <tbody className="divide-y divide-neutral-100 font-medium">
                        {assetsList.map((asset) => (
                          <tr key={asset.asd_id} className="hover:bg-neutral-50 transition-colors">
                            <td className="p-3 pl-4 flex items-center gap-3">
                              <div className={`p-1.5 rounded-lg ${asset.ast_id === 4 ? 'bg-amber-100 text-amber-700' : 'bg-red-100 text-red-800'}`}>
                                {asset.ast_id === 4 ? <Car size={16} /> : <Building size={16} />}
                              </div>
                              <span className="font-bold text-neutral-900">{asset.asset_name}</span>
                            </td>
                            <td className="p-3 text-neutral-600">{asset.asset_type === 'Furniture' ? 'Equipment' : asset.asset_type}</td>
                            <td className="p-3">
                              {/* Dynamic Status Indicator */}
                              <span className={`inline-flex items-center gap-1.5 px-2 py-1 border rounded-md font-bold text-[9px] uppercase tracking-wide
                                ${asset.current_status === 'Available' ? 'bg-green-50 text-green-700 border-green-200' : 
                                  asset.current_status === 'Maintenance' ? 'bg-neutral-100 text-neutral-700 border-neutral-300' : 
                                  'bg-red-50 text-red-700 border-red-200'}
                              `}>
                                <span className={`w-1.5 h-1.5 rounded-full 
                                  ${asset.current_status === 'Available' ? 'bg-green-500' : 
                                    asset.current_status === 'Maintenance' ? 'bg-neutral-500' : 'bg-red-500'}`}>
                                </span> 
                                {asset.current_status}
                              </span>
                            </td>
                            <td className="p-3 text-right pr-4">
                              <div className="flex items-center justify-end gap-4 text-red-800">
                                <button onClick={() => handleOpenEditModal(asset)} className="hover:text-red-900 transition-transform hover:scale-110"><Edit size={16}/></button>
                                <button onClick={() => handleDeleteAsset(asset.asd_id, asset.asset_name)} className="hover:text-red-900 transition-transform hover:scale-110"><Trash2 size={16}/></button>
                              </div>
                            </td>
                          </tr>
                        ))}
                  {assetsList.length === 0 && (
                    <tr><td colSpan="4" className="p-6 text-center text-neutral-400 font-bold">No assets found in the registry.</td></tr>
                  )}
                </tbody>
              </table>
            </div>
          </div>

          {/* RIGHT COLUMN: Logistics Inventory */}
          <div className="bg-white border border-neutral-200 rounded-2xl p-5 shadow-sm bg-neutral-50/30">
            <h3 className="text-sm font-black text-neutral-900 flex items-center gap-2 mb-4">
              <Archive size={16} className="text-red-800" /> Logistics Inventory
            </h3>
            
            {/* Inventory Cards will go here */}
            <div className="space-y-4">
              {equipmentInventory.length === 0 ? (
                <div className="text-center p-6 border-2 border-dashed border-neutral-200 rounded-xl text-neutral-400 text-xs font-bold">
                  No equipment registered.
                </div>
              ) : (
                equipmentInventory.map((item) => (
                  <div key={item.asd_id} className="bg-white border border-red-100 rounded-xl p-4 shadow-sm relative overflow-hidden group">
                    <div className="absolute top-0 right-0 w-16 h-16 bg-red-50 rounded-bl-full -z-10 group-hover:scale-110 transition-transform"></div>
                    <h4 className="font-black text-neutral-900 text-sm">{item.asset_name}</h4>
                    <span className="text-[9px] text-neutral-400 font-black uppercase tracking-wider block mt-0.5">EQP-ID-{item.asd_id}</span>
                    
                    <div className="flex justify-between items-center mt-4 mb-5">
                      <div className="text-center w-1/2 border-r border-neutral-100">
                        <span className="text-[10px] text-neutral-500 font-bold uppercase tracking-wide">Current</span>
                        <p className="text-xl font-black text-red-800 leading-none mt-1">{item.current_stock}</p>
                      </div>
                      <div className="text-center w-1/2">
                        <span className="text-[10px] text-neutral-500 font-bold uppercase tracking-wide">Capacity</span>
                        <p className="text-xl font-black text-neutral-800 leading-none mt-1">{item.capacity}</p>
                      </div>
                    </div>
                    
                    <button 
                      onClick={() => { setSelectedInventoryItem(item); setShowInventoryModal(true); }}
                      className="w-full py-2 border border-red-200 text-red-800 bg-red-50 hover:bg-red-100 font-bold text-xs rounded-lg transition-colors flex items-center justify-center gap-2"
                    >
                      <Edit size={14} /> Update Stock
                    </button>
                  </div>
                ))
              )}
            </div>
          </div>
        </div>

        {/* BOTTOM ROW: Calendar Availability Control */}
        <div className="bg-white border border-neutral-200 rounded-2xl p-5 shadow-sm mt-6">
        <div className="flex justify-between items-start mb-6">
          <div>
            <h3 className="text-sm font-black text-neutral-900 flex items-center gap-2">
              <Calendar size={16} className="text-red-800" /> Calendar Availability Control
            </h3>
            <p className="text-xs text-neutral-500 font-medium mt-1">Block dates for maintenance or priority events.</p>
            <button onClick={() => setShowBlackoutModal(true)} className="mt-3 px-4 py-2 bg-red-800 hover:bg-red-900 text-white font-bold text-[10px] uppercase tracking-wider rounded-lg shadow-sm flex items-center gap-2">
              <Lock size={12} /> Block Dates
            </button>
          </div>
          
          <div className="bg-neutral-100 p-1 rounded-xl flex font-bold text-[10px]">
            {['Vehicle', 'Multimedia Room', 'Gymnasium'].map((tab) => (
              <button 
                key={tab}
                onClick={() => setActiveCalendarTab(tab)}
                className={`px-4 py-2 rounded-lg uppercase tracking-wider transition-colors ${activeCalendarTab === tab ? 'bg-red-800 text-white shadow-sm' : 'text-neutral-500 hover:text-neutral-800'}`}
              >
                {tab}
              </button>
            ))}
          </div>
        </div>
  
  {/* Calendar Rendering Logic */}
  {(() => {
    const year = currentCalendarDate.getFullYear();
    const month = currentCalendarDate.getMonth();
    const daysInMonth = new Date(year, month + 1, 0).getDate();
    const firstDayIndex = new Date(year, month, 1).getDay();
    const calendarDays = Array.from({ length: firstDayIndex }, () => null).concat(Array.from({ length: daysInMonth }, (_, i) => i + 1));
    const monthNames = ["January", "February", "March", "April", "May", "June", "July", "August", "September", "October", "November", "December"];
    
    // Map the Tab string to the actual database asset_name
    const tabToAssetMap = { 'Vehicle': 'Van', 'Multimedia Room': 'Multimedia Room', 'Gymnasium': 'Gymnasium' };
    const mappedAsset = tabToAssetMap[activeCalendarTab];

    return (
      <div className="space-y-4">
        <div className="flex justify-between items-center text-sm font-black text-neutral-900">
          <span>{monthNames[month]} {year}</span>
          <div className="flex gap-1 border rounded-lg p-1 bg-neutral-50">
            <button onClick={() => setCurrentCalendarDate(new Date(year, month - 1, 1))} className="p-1 hover:bg-white rounded transition-colors"><ChevronLeft size={16} /></button>
            <button onClick={() => setCurrentCalendarDate(new Date(year, month + 1, 1))} className="p-1 hover:bg-white rounded transition-colors"><ChevronRight size={16} /></button>
          </div>
        </div>

        <div className="grid grid-cols-7 gap-1 border rounded-lg p-2 bg-neutral-50 text-[10px] font-black text-center text-neutral-400">
          {['Sun','Mon','Tue','Wed','Thu','Fri','Sat'].map(day => <div key={day}>{day}</div>)}
        </div>
        
        <div className="grid grid-cols-7 gap-2">
          {calendarDays.map((day, index) => {
            if (!day) return <div key={index} className="bg-neutral-50/50 border border-dashed border-neutral-100 rounded-xl min-h-[90px]"></div>;
            
            const dayString = `${year}-${String(month + 1).padStart(2, '0')}-${String(day).padStart(2, '0')}`;
            
            // Check if this specific day is inside a blackout range for the active asset
            const activeBlock = assetBlackouts.find(blk => {
              if (blk.asset_name !== mappedAsset) return false;
              const start = new Date(blk.start_time).toISOString().split('T')[0];
              const end = new Date(blk.end_time).toISOString().split('T')[0];
              return dayString >= start && dayString <= end;
            });

            return (
              <div key={index} className={`border rounded-xl p-2 min-h-[90px] flex flex-col justify-between transition-colors ${activeBlock ? 'bg-red-50/50 border-red-200' : 'bg-white border-neutral-200 hover:border-neutral-300'}`}>
                <span className={`text-xs font-black block self-start ${activeBlock ? 'text-red-800' : 'text-neutral-400'}`}>{day}</span>
                {activeBlock && (
                  <div className="bg-white border border-red-200 p-1.5 rounded-lg text-center mt-1">
                    <Lock size={12} className="mx-auto text-red-700 mb-0.5" />
                    <span className="text-[8px] font-black uppercase text-red-800 leading-tight block">{activeBlock.reason}</span>
                  </div>
                )}
              </div>
            );
          })}
        </div>
      </div>
    );
  })()}
</div>

      </div>
    )}

    {activeTab === 'history' && (
            <div className="max-w-7xl mx-auto bg-white border border-neutral-200 rounded-2xl shadow-sm overflow-hidden text-left animate-in fade-in duration-200">
              <div className="p-5 border-b border-neutral-100 flex flex-col sm:flex-row justify-between items-center gap-4">
                <h3 className="text-sm font-black text-neutral-950 tracking-tight">Audit Trail Ledger</h3>
                <div className="flex flex-wrap items-center gap-3">
                  <div className="flex items-center gap-1 border border-neutral-300 rounded-lg px-2 py-1.5 bg-neutral-50">
                    <Filter size={14} className="text-neutral-400" />
                    <select value={historyFilter} onChange={e => { setHistoryFilter(e.target.value); setHistoryPage(1); }} className="bg-transparent text-xs outline-none cursor-pointer font-bold text-neutral-600">
                      <option value="All">All Actions</option>
                      <option value="Scanned In">Scanned In</option>
                      <option value="Scanned Out">Scanned Out</option>
                      <option value="Approved & Signed">Approved & Signed</option>
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
                    <button disabled={historyPage === 1} onClick={() => setHistoryPage(prev => prev - 1)} className="px-3 py-1.5 border rounded-lg bg-white font-bold text-neutral-600 hover:bg-neutral-50 disabled:opacity-40">Previous</button>
                    <button disabled={historyPage === totalHistoryTabPages} onClick={() => setHistoryPage(prev => prev + 1)} className="px-3 py-1.5 border rounded-lg bg-white font-bold text-neutral-600 hover:bg-neutral-50 disabled:opacity-40">Next</button>
                  </div>
                </div>
              )}
            </div>
          )}

          {activeTab === 'procurement' && (
            <div className="max-w-7xl mx-auto space-y-6 text-left animate-in fade-in duration-200">
              
              {/* HEADER SECTION WITH CENTRALIZED BUTTONS */}
              <div className="flex justify-between items-start border-b border-neutral-200 pb-4">
                <div>
                  <h2 className="text-xl font-black text-neutral-900">Procurement Management</h2>
                  <p className="text-xs text-neutral-500 font-medium mt-1">Manage physical documents and requirements for reservations.</p>
                </div>
                <div className="flex gap-2">
                  <button 
                    onClick={() => setShowPrintModal(true)} 
                    className="px-4 py-2 bg-neutral-100 hover:bg-neutral-200 text-neutral-700 font-bold text-xs rounded-xl shadow-sm transition-colors flex items-center gap-2 border border-neutral-200"
                  >
                    <Download size={14} /> Master Print Logs
                  </button>
                  <button 
                    onClick={() => setShowChecklistMakerModal(true)} 
                    className="px-4 py-2 bg-red-800 hover:bg-red-900 text-white font-bold text-xs rounded-xl shadow-sm transition-colors flex items-center gap-2"
                  >
                    <Edit size={14} /> Master Checklist
                  </button>
                </div>
              </div>

              {/* HELPER FUNCTION TO RENDER RESERVATION TABLES */}
              {[
                { title: 'Vehicle Reservations', icon: <Car size={16} className="text-red-800"/>, data: vehicleData, sKey: 'vehicle' },
                { title: 'Multimedia Room', icon: <Building size={16} className="text-red-800"/>, data: multimediaData, sKey: 'multimedia' },
                { title: 'Gymnasium Reservations', icon: <Landmark size={16} className="text-red-800"/>, data: gymData, sKey: 'gym' }
              ].map((block, idx) => (
                <div key={idx} className="bg-white border border-neutral-200 rounded-2xl p-5 shadow-sm">
                  <div className="flex justify-between items-center mb-4">
                    <h3 className="text-sm font-black text-neutral-900 flex items-center gap-2">
                      {block.icon} {block.title}
                    </h3>
                    <div className="flex items-center gap-3">
                      <div className="relative">
                        <Search className="absolute left-2.5 top-2 text-neutral-400" size={14} />
                        <input type="text" placeholder="Search Requestor..." value={procSearch[block.sKey]} onChange={e => { setProcSearch({...procSearch, [block.sKey]: e.target.value}); setProcPage({...procPage, [block.sKey]: 1}); }} className="pl-8 pr-3 py-1.5 text-xs border rounded-lg bg-neutral-50 outline-none focus:ring-1 focus:ring-red-700 w-48" />
                      </div>
                      <select value={procFilter[block.sKey]} onChange={e => { setProcFilter({...procFilter, [block.sKey]: e.target.value}); setProcPage({...procPage, [block.sKey]: 1}); }} className="border border-neutral-300 rounded-lg px-2 py-1.5 text-xs font-bold text-neutral-700 bg-neutral-50 outline-none">
                        <option value="All">All Status</option>
                        <option value="Reserved">Pending / Reserved</option>
                        <option value="Confirmed">Confirmed</option>
                      </select>
                    </div>
                  </div>

                  <div className="overflow-x-auto border border-neutral-200 rounded-xl">
                    <table className="w-full text-left text-xs">
                      <thead>
                        <tr className="bg-neutral-50 border-b border-neutral-200 font-black uppercase text-[10px] text-neutral-600 tracking-wider">
                          <th className="p-3 pl-4">Requestor</th>
                          <th className="p-3">Purpose</th>
                          <th className="p-3">Date & Time</th>
                          <th className="p-3">Status</th>
                          <th className="p-3 text-center pr-4">Action</th>
                        </tr>
                      </thead>
                      <tbody className="divide-y divide-neutral-100 font-medium">
                        {block.data.paginatedData.map((res) => {
                          const dateObj = new Date(res.reservation_date);
                          return (
                            <tr key={res.booking_id} className="hover:bg-neutral-50 transition-colors">
                              <td className="p-3 pl-4 font-bold text-neutral-900">{res.requestor}</td>
                              <td className="p-3 text-neutral-600 truncate max-w-[150px]">{res.purpose}</td>
                              <td className="p-3 text-neutral-600">
                                <div className="font-bold text-neutral-800">{dateObj.toLocaleDateString('en-US', { month: 'short', day: 'numeric', year: 'numeric' })}</div>
                                <div className="text-[10px] text-neutral-500">{res.start_time?.substring(0,5)} - {res.end_time?.substring(0,5)}</div>
                              </td>
                              <td className="p-3">
                                <span className={`px-2 py-1 rounded text-[9px] font-black uppercase tracking-wide border ${res.status === 'Confirmed' ? 'bg-green-50 text-green-700 border-green-200' : 'bg-amber-50 text-amber-700 border-amber-200'}`}>
                                  {res.status}
                                </span>
                              </td>
                              <td className="p-3 text-center pr-4">
                              <button 
                                  onClick={() => handleViewChecklist(res)}
                                  className="px-3 py-1.5 bg-red-50 text-red-800 hover:bg-red-100 font-bold text-xs rounded-lg transition-colors border border-red-200"
                                >
                                  View Checklist
                                </button>
                              </td>
                            </tr>
                          );
                        })}
                        {block.data.paginatedData.length === 0 && (
                          <tr><td colSpan="5" className="p-6 text-center text-neutral-400 font-bold">No reservations found.</td></tr>
                        )}
                      </tbody>
                    </table>
                  </div>

                  {/* Pagination Controls */}
                  <div className="flex justify-between items-center mt-4 text-xs">
                    <span className="text-neutral-500 font-bold">Showing {block.data.paginatedData.length} of {block.data.filteredData.length} records</span>
                    <div className="flex gap-1">
                      <button disabled={procPage[block.sKey] === 1} onClick={() => setProcPage({...procPage, [block.sKey]: procPage[block.sKey] - 1})} className="px-3 py-1 border rounded-lg bg-white disabled:opacity-50 hover:bg-neutral-50 font-bold text-neutral-600">Prev</button>
                      <span className="px-3 py-1 border rounded-lg bg-neutral-100 font-black text-neutral-800">{procPage[block.sKey]} / {block.data.totalPages}</span>
                      <button disabled={procPage[block.sKey] === block.data.totalPages} onClick={() => setProcPage({...procPage, [block.sKey]: procPage[block.sKey] + 1})} className="px-3 py-1 border rounded-lg bg-white disabled:opacity-50 hover:bg-neutral-50 font-bold text-neutral-600">Next</button>
                    </div>
                  </div>
                </div>
              ))}

              {/* 4. LOGISTICS HISTORY */}
              <div className="bg-white border border-neutral-200 rounded-2xl p-5 shadow-sm">
                <div className="flex justify-between items-center mb-4">
                  <h3 className="text-sm font-black text-neutral-900 flex items-center gap-2">
                    <Archive size={16} className="text-red-800"/> Logistics History
                  </h3>
                  <div className="flex items-center gap-3">
                    <div className="relative">
                      <Search className="absolute left-2.5 top-2 text-neutral-400" size={14} />
                      <input type="text" placeholder="Search Asset or Requestor..." value={procSearch.logistics} onChange={e => { setProcSearch({...procSearch, logistics: e.target.value}); setProcPage({...procPage, logistics: 1}); }} className="pl-8 pr-3 py-1.5 text-xs border rounded-lg bg-neutral-50 outline-none focus:ring-1 focus:ring-red-700 w-48" />
                    </div>
                    <select value={procFilter.logistics} onChange={e => { setProcFilter({...procFilter, logistics: e.target.value}); setProcPage({...procPage, logistics: 1}); }} className="border border-neutral-300 rounded-lg px-2 py-1.5 text-xs font-bold text-neutral-700 bg-neutral-50 outline-none">
                      <option value="All">All Types</option>
                      <option value="Borrowed">Lending (Borrowed)</option>
                      <option value="Returned">Returned</option>
                    </select>
                  </div>
                </div>

                <div className="overflow-x-auto border border-neutral-200 rounded-xl">
                  <table className="w-full text-left text-xs">
                    <thead>
                      <tr className="bg-neutral-50 border-b border-neutral-200 font-black uppercase text-[10px] text-neutral-600 tracking-wider">
                        <th className="p-3 pl-4">Asset Name</th>
                        <th className="p-3">Requestor</th>
                        <th className="p-3">Qty</th>
                        <th className="p-3">Status</th>
                        <th className="p-3 pr-4 text-right">Timestamp</th>
                      </tr>
                    </thead>
                    <tbody className="divide-y divide-neutral-100 font-medium">
                      {logData.paginatedData.map((log) => {
                        const dateObj = new Date(log.borrowed_at);
                        return (
                          <tr key={log.log_id} className="hover:bg-neutral-50 transition-colors">
                            <td className="p-3 pl-4 font-bold text-neutral-900">{log.asset_name}</td>
                            <td className="p-3 text-neutral-600">{log.requestor_name}</td>
                            <td className="p-3 font-bold text-neutral-800">{log.qty_borrowed}</td>
                            <td className="p-3">
                              <span className={`px-2 py-1 rounded text-[9px] font-black uppercase tracking-wide border ${log.status === 'Returned' ? 'bg-blue-50 text-blue-700 border-blue-200' : 'bg-orange-50 text-orange-700 border-orange-200'}`}>
                                {log.status}
                              </span>
                            </td>
                            <td className="p-3 pr-4 text-right text-neutral-500 font-mono text-[10px]">
                              {dateObj.toLocaleDateString('en-US', { month: 'short', day: 'numeric', year: 'numeric' })}
                            </td>
                          </tr>
                        );
                      })}
                      {logData.paginatedData.length === 0 && (
                        <tr><td colSpan="5" className="p-6 text-center text-neutral-400 font-bold">No logistics history found.</td></tr>
                      )}
                    </tbody>
                  </table>
                </div>

                <div className="flex justify-between items-center mt-4 text-xs">
                  <span className="text-neutral-500 font-bold">Showing {logData.paginatedData.length} of {logData.filteredData.length} records</span>
                  <div className="flex gap-1">
                    <button disabled={procPage.logistics === 1} onClick={() => setProcPage({...procPage, logistics: procPage.logistics - 1})} className="px-3 py-1 border rounded-lg bg-white disabled:opacity-50 hover:bg-neutral-50 font-bold text-neutral-600">Prev</button>
                    <span className="px-3 py-1 border rounded-lg bg-neutral-100 font-black text-neutral-800">{procPage.logistics} / {logData.totalPages}</span>
                    <button disabled={procPage.logistics === logData.totalPages} onClick={() => setProcPage({...procPage, logistics: procPage.logistics + 1})} className="px-3 py-1 border rounded-lg bg-white disabled:opacity-50 hover:bg-neutral-50 font-bold text-neutral-600">Next</button>
                  </div>
                </div>
              </div>
            </div>
          )}

          {activeTab === 'analytics' && (
            <div className="max-w-7xl mx-auto space-y-6 text-left animate-in fade-in duration-200">
              
              {/* HEADER */}
              <div className="flex justify-between items-start border-b border-neutral-200 pb-4">
                <div>
                  <h2 className="text-2xl font-black text-neutral-900">Operational Analytics</h2>
                  <p className="text-xs text-neutral-500 font-medium mt-1">Data-driven insights for administrative evaluation and resource planning.</p>
                </div>
                <button className="px-5 py-2 bg-red-800 hover:bg-red-900 text-white font-bold text-xs rounded-xl shadow-sm transition-colors flex items-center gap-2">
                  <Download size={14} /> Generate Full Audit Report
                </button>
              </div>

              {isAnalyticsLoading ? (
                 <div className="flex items-center justify-center h-64 text-neutral-400 font-bold text-sm">
                   Fetching ML Models & Processing Data...
                 </div>
              ) : (
                <>
              <div className="grid grid-cols-1 lg:grid-cols-3 gap-6">
                    
                    {/* CARD 1: Bottleneck Analytical Evaluation Process (Now with Filters!) */}
                    <div className="lg:col-span-2 bg-white border border-neutral-200 rounded-2xl p-5 shadow-sm">
                      <div className="flex flex-col sm:flex-row sm:items-start justify-between gap-4 mb-6">
                        <div>
                          <h3 className="text-sm font-black text-neutral-900">Descriptive Analytics: Bottleneck Analytical Evaluation Process</h3>
                          <p className="text-[10px] text-neutral-500 font-medium">Visualizing document processing dwell times across campus units.</p>
                        </div>
                        
                        {/* Search & Sort Controls */}
                        <div className="flex flex-wrap items-center gap-2">
                          <input 
                            type="text" 
                            placeholder="Search Office..." 
                            value={bottleneckSearch} 
                            onChange={e => setBottleneckSearch(e.target.value)} 
                            className="px-3 py-1.5 text-xs border border-neutral-300 rounded-lg outline-none focus:ring-1 focus:ring-red-800 w-36 bg-neutral-50" 
                          />
                          <select 
                            value={bottleneckSort} 
                            onChange={e => setBottleneckSort(e.target.value)} 
                            className="px-2 py-1.5 text-xs font-bold text-neutral-700 border border-neutral-300 rounded-lg outline-none bg-neutral-50 cursor-pointer"
                          >
                            <option value="desc">Highest Delay</option>
                            <option value="asc">Lowest Delay</option>
                          </select>
                        </div>
                      </div>
                      
                      <div className="h-64">
                        <ResponsiveContainer width="100%" height="100%">
                          <BarChart data={processedBottleneckData} layout="vertical" margin={{ top: 5, right: 30, left: 20, bottom: 5 }}>
                            <CartesianGrid strokeDasharray="3 3" horizontal={true} vertical={false} stroke="#f5f5f5" />
                            <XAxis type="number" tick={{fontSize: 10}} unit="h" />
                            {/* Increased width to 140 to prevent overlapping names */}
                            <YAxis dataKey="office_name" type="category" tick={{fontSize: 10, fill: '#525252'}} width={140} />
                            <Tooltip cursor={{fill: '#f9fafb'}} contentStyle={{ borderRadius: '8px', border: 'none', boxShadow: '0 4px 6px -1px rgb(0 0 0 / 0.1)' }} />
                            <Bar dataKey="dwell_time_hours" fill="#991b1b" radius={[0, 4, 4, 0]} barSize={28} name="Dwell Time (Hours)" />
                          </BarChart>
                        </ResponsiveContainer>
                        {processedBottleneckData.length === 0 && (
                          <div className="text-center text-xs text-neutral-400 font-bold -mt-32">No offices match your search.</div>
                        )}
                      </div>
                    </div>

                    {/* CARD 2: Prescriptive Analytics (Bigger & Red Themed) */}
                    <div className="bg-white border border-neutral-200 rounded-2xl p-5 shadow-sm flex flex-col border-t-4 border-t-red-800">
                      <div className="mb-6">
                        <h3 className="text-base font-black text-neutral-900">Prescriptive Analytics: Event Equipment</h3>
                        <p className="text-[11px] text-neutral-500 font-medium">Current inventory status and loan commitments.</p>
                      </div>
                      
                      <div className="space-y-6 flex-1 overflow-y-auto pr-2">
                        {equipmentInventory.map(item => {
                          const percentAvailable = Math.round((item.current_stock / item.capacity) * 100) || 0;
                          const percentLoaned = 100 - percentAvailable;
                          
                          return (
                            <div key={item.asd_id}>
                              <div className="flex justify-between text-sm font-black mb-1.5">
                                <span className="text-neutral-900">{item.asset_name}</span>
                                <span className="text-neutral-500">{item.capacity} Total</span>
                              </div>
                              <div className="w-full bg-neutral-100 rounded-xl h-8 flex overflow-hidden border border-neutral-200 shadow-inner">
                                <div 
                                  className="h-full flex items-center justify-center text-[10px] font-black text-white bg-red-800 transition-all duration-500" 
                                  style={{ width: `${percentAvailable}%` }}
                                >
                                  {percentAvailable > 15 ? `${percentAvailable}% Avail` : ''}
                                </div>
                                <div 
                                  className="h-full flex items-center justify-center text-[10px] font-black text-red-900 bg-red-100 transition-all duration-500 border-l border-white/20" 
                                  style={{ width: `${percentLoaned}%` }}
                                >
                                  {percentLoaned > 15 ? `${percentLoaned}% Loaned` : ''}
                                </div>
                              </div>
                            </div>
                          );
                        })}
                        {equipmentInventory.length === 0 && <div className="text-sm text-neutral-400 font-bold text-center mt-10">No equipment data available.</div>}
                      </div>

                      <div className="mt-4 bg-red-50/50 border border-red-200 p-4 rounded-xl border-l-4 border-l-red-800 shadow-sm">
                        <p className="text-[11px] font-black text-red-900 flex items-center gap-1.5 mb-1">💡 System Insight</p>
                        <p className="text-[11px] text-red-800 font-medium leading-relaxed">Stock levels are currently stable based on historical borrowing patterns.</p>
                      </div>
                    </div>
                  </div>

                  {/* CARD 3: Predictive Analytics: Resource Demand Trends */}
                  <div className="bg-white border border-neutral-200 rounded-2xl p-5 shadow-sm mt-6">
                    <div className="flex justify-between items-end mb-6">
                      <div>
                        <h3 className="text-sm font-black text-neutral-900">Predictive Analytics: Total Resource Demand Forecast</h3>
                        <p className="text-[10px] text-neutral-500 font-medium">Holt-Winters exponential smoothing forecast vs. historical baseline.</p>
                      </div>
                    </div>
                    
                    <div className="h-72 w-full">
                      <ResponsiveContainer width="100%" height="100%">
                        <AreaChart data={peakDemandData} margin={{ top: 10, right: 30, left: -20, bottom: 0 }}>
                          <defs>
                            <linearGradient id="colorDemand" x1="0" y1="0" x2="0" y2="1">
                              <stop offset="5%" stopColor="#991b1b" stopOpacity={0.3}/>
                              <stop offset="95%" stopColor="#991b1b" stopOpacity={0}/>
                            </linearGradient>
                          </defs>
                          <XAxis dataKey="date" tick={{fontSize: 10}} axisLine={false} tickLine={false} />
                          <YAxis tick={{fontSize: 10}} axisLine={false} tickLine={false} />
                          <CartesianGrid strokeDasharray="3 3" vertical={false} stroke="#f0f0f0" />
                          <Tooltip 
                            contentStyle={{ borderRadius: '8px', border: 'none', boxShadow: '0 4px 6px -1px rgb(0 0 0 / 0.1)' }}
                            labelStyle={{ fontWeight: 'bold', color: '#171717' }} 
                          />
                          <Legend iconType="circle" wrapperStyle={{ fontSize: '12px', fontWeight: 'bold' }} />
                          <Area 
                            type="monotone" 
                            dataKey="demand" 
                            name="Total Daily Reservations" 
                            stroke="#991b1b" 
                            strokeWidth={3} 
                            fillOpacity={1} 
                            fill="url(#colorDemand)" 
                          />
                        </AreaChart>
                      </ResponsiveContainer>
                    </div>
                  </div>
                </>
              )}
            </div>
          )}

          {/* UNIFIED FULL PROFILE HUB (Matching Signee/Processor exact setup) */}
          {activeTab === 'profile' && (
            <div className="max-w-5xl mx-auto grid grid-cols-1 lg:grid-cols-3 gap-6 text-left animate-in fade-in duration-200">
              <div className="lg:col-span-3 bg-white border border-neutral-200 p-6 rounded-2xl flex items-center gap-6 shadow-sm relative">
                <div className="relative">
                  <img src="https://images.unsplash.com/photo-1472099645785-5658abf4ff4e?auto=format&fit=facearea&facepad=2&w=256&h=256&q=80" alt="Profile" className="w-24 h-24 rounded-2xl object-cover border-2 border-neutral-100 shadow-sm" />
                  <div className="absolute -bottom-1 -right-1 bg-red-800 p-1.5 rounded-lg text-white shadow-md cursor-pointer hover:scale-105 transition-transform"><Camera size={14} /></div>
                </div>
                <div className="space-y-1">
                  <div className="flex items-center gap-3">
                    <h3 className="text-xl font-black text-neutral-900">{profileName || 'GSO Admin'}</h3>
                    <span className="px-2 py-0.5 bg-red-50 text-red-800 border border-red-100 rounded text-[9px] font-black uppercase tracking-wider">GSO Administrator</span>
                  </div>
                  <p className="text-xs text-neutral-400 font-bold flex items-center gap-1.5"><Building size={12} /> Faculty • {departmentName}</p>
                  <p className="text-xs text-green-600 font-bold flex items-center gap-1 mt-1"><span className="w-2 h-2 bg-green-500 rounded-full animate-pulse"></span> Active System Status</p>
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
                        <input type="text" required value={profileName} onChange={e => setProfileName(e.target.value)} className="w-full px-4 py-2 text-xs border border-neutral-300 rounded-xl outline-none focus:ring-1 focus:ring-red-700 bg-neutral-50 font-bold text-neutral-800 transition-all" />
                      </div>
                      <div>
                        <label className="block text-[10px] font-black text-neutral-400 uppercase mb-1 tracking-wide">System Recovery Email Address</label>
                        <input type="email" required value={profileEmail} onChange={e => setProfileEmail(e.target.value)} className="w-full px-4 py-2 text-xs border border-neutral-300 rounded-xl outline-none focus:ring-1 focus:ring-red-700 bg-neutral-50 font-bold text-neutral-800 transition-all" />
                      </div>
                    </div>
                    <div className="flex justify-end pt-2">
                      <button type="submit" className="px-4 py-2 bg-neutral-900 hover:bg-black text-white font-bold text-xs rounded-xl uppercase tracking-wide transition-all shadow-sm">Save Profile Changes</button>
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
                    <button onClick={() => { setShowPassModal(true); }} className="text-xs font-black text-red-800 hover:underline transition-all">Update</button>
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
                      <form onSubmit={handleSaveCustomPin} className="border-t border-dashed border-neutral-200 pt-3 space-y-2 animate-in slide-in-from-top-1 duration-150">
                        <label className="block text-[10px] font-black text-neutral-400 uppercase tracking-wide">Set Your Custom Authority Code Validation PIN</label>
                        <div className="flex items-center gap-2">
                          <input type="text" maxLength={6} required placeholder="Enter numeric validation pin" value={twoFaCode} onChange={e => setTwoFaCode(e.target.value.replace(/\D/g, ''))} className="w-full max-w-xs px-4 py-2 text-xs border border-neutral-300 rounded-xl outline-none focus:ring-1 focus:ring-red-700 font-mono tracking-widest text-neutral-800" />
                          <button type="submit" className="px-4 py-2 bg-neutral-900 hover:bg-black text-white font-bold text-xs rounded-xl uppercase tracking-wide shadow-sm transition-all">Save PIN</button>
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
                      <p className="font-bold text-neutral-700 mt-0.5">{gsoOfficeName}</p>
                    </div>
                  </div>
                </div>
                <div className="bg-red-50/40 border border-red-100 rounded-2xl p-4 text-[11px] leading-relaxed text-neutral-500 font-medium">
                  ℹ️ <span className="font-bold text-neutral-800">Note:</span> Maintaining institutional profile bindings and role configurations falls under the jurisdiction of the University Central Registry Database console. Contact <span className="text-red-800 font-bold hover:underline cursor-pointer">Campus IT Support</span> for configuration adjustments.
                </div>
              </div>
            </div>
          )}

        </div>

        {/* BOTTOM RIGHT FLOATING QR SCANNER BUTTON */}
        <button 
          onClick={() => { setScanMode('time-in'); setShowScannerModal(true); }}
          className="absolute bottom-8 right-8 w-14 h-14 bg-red-800 hover:bg-red-900 text-white rounded-2xl shadow-xl flex items-center justify-center transition-transform hover:scale-105 z-40"
        >
          <QrCode size={24} />
        </button>

      </div>

    {/* --- HYBRID SMART MODAL --- */}
    {showDetailsModal && selectedDoc && (() => {
        const docTitle = selectedDoc.title || 'N/A';
        const docProcess = selectedDoc.process_name || 'Administrative Request';
        const docStatus = selectedDoc.status || 'Active Path';
        const docQr = selectedDoc.qr_code || 'N/A';
        const docOrigin = selectedDoc.originating_office || selectedDoc.origin || 'University Unit';
        const requestorName = selectedDoc.requestor_name || 'N/A'; // ✅ Added Requestor Name
        const nextOffice = selectedDoc.next_office || 'End of Route / Finished'; // ✅ Added Next Office Stop

        return (
          <div className="fixed inset-0 bg-neutral-950/60 backdrop-blur-xs flex items-center justify-center p-4 z-[100] animate-in fade-in duration-150">
            <div className="bg-white w-full max-w-3xl rounded-2xl shadow-2xl border overflow-hidden flex flex-col text-left">
              
              <div className="p-4 bg-[#FDFBF9] border-b font-bold text-sm flex items-center justify-between text-neutral-900">
                <div className="flex items-center gap-2"><FileText size={16} className="text-red-700"/> Document Audit Verification</div>
                <button onClick={() => setShowDetailsModal(false)} className="hover:bg-neutral-200 p-1 rounded-md"><X size={16} /></button>
              </div>

              <div className="p-6 grid grid-cols-1 md:grid-cols-3 gap-6 max-h-[80vh] overflow-y-auto">
                <div className="md:col-span-2 space-y-5">
                  <div>
                    <span className="text-[10px] font-black uppercase tracking-wider text-neutral-400">Document Title</span>
                    <h4 className="text-xl font-black text-neutral-900 leading-tight mt-1">{docTitle}</h4>
                  </div>
                  
                  {/* Updated Grid Section */}
                  <div className="grid grid-cols-2 gap-4 border-b border-neutral-100 pb-4">
                    <div>
                      <span className="text-[9px] font-bold uppercase text-neutral-400 block">Form Type</span>
                      <p className="font-bold text-neutral-700 text-xs mt-1">{docProcess}</p>
                    </div>
                    <div>
                      <span className="text-[9px] font-bold uppercase text-neutral-400 block">Current Status</span>
                      <span className="px-2.5 py-0.5 bg-neutral-100 border rounded font-black text-[9px] uppercase mt-1 inline-block">{docStatus}</span>
                    </div>
                    <div>
                      <span className="text-[9px] font-bold uppercase text-neutral-400 block">Originating Office</span>
                      <p className="font-bold text-neutral-700 mt-1 text-xs">{docOrigin}</p>
                    </div>
                    <div>
                      <span className="text-[9px] font-bold uppercase text-neutral-400 block">Requestor Name</span>
                      <p className="font-bold text-neutral-950 mt-1 text-xs">{requestorName}</p>
                    </div>
                    <div>
                      <span className="text-[9px] font-bold uppercase text-neutral-400 block">Time In Arrival</span>
                      <p className="font-mono text-xs font-bold mt-1 text-neutral-600">
                        {selectedDoc.time_in ? new Date(selectedDoc.time_in).toLocaleTimeString('en-US') : <span className="text-blue-600">Awaiting Scan-In</span>}
                      </p>
                    </div>
                    <div>
                      <span className="text-[9px] font-bold uppercase text-neutral-400 block">Time Out Departure</span>
                      <p className="font-mono text-xs font-bold mt-1 text-neutral-600">
                        {selectedDoc.time_out ? new Date(selectedDoc.time_out).toLocaleTimeString('en-US') : <span className="text-amber-600">Still at GSO Station</span>}
                      </p>
                    </div>
                    <div>
                      <span className="text-[9px] font-bold uppercase text-neutral-400 block">Next Office Stop</span>
                      <p className="font-bold text-red-800 mt-1 text-xs">🏢 {nextOffice}</p>
                    </div>
                    <div>
                      <span className="text-[9px] font-bold uppercase text-neutral-400 block flex items-center gap-1">
                        Est. Completion (EDC) 
                        <span className="text-[8px] bg-purple-100 text-purple-700 font-black px-1 rounded">ML Placeholder</span>
                      </span>
                      <p className="font-bold text-purple-800 mt-1 text-xs">
                        🕒 {selectedDoc.edc ? new Date(selectedDoc.edc).toLocaleDateString('en-US', { month: 'short', day: 'numeric', year: 'numeric' }) : 'Calculating (Awaiting ML Inference...)'}
                      </p>
                    </div>
                  </div>

                  {/* Smart Conditional Workflow Banners */}
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
                    <div className="bg-blue-50 border border-blue-200 rounded-xl p-4 flex gap-3 text-sm">
                      <span>🛑</span>
                      <div>
                        <p className="font-black text-blue-900 uppercase text-[10px] tracking-wide">Action Required: Scan-In Needed</p>
                        <p className="text-blue-700 font-medium text-xs mt-1">This document must be officially Scanned-In to GSO custody before any authorization logic can be applied.</p>
                      </div>
                    </div>
                  ) : isInVerification ? (
                    <div className="bg-red-50 border border-red-200 rounded-xl p-4 flex gap-3 text-sm">
                      <span>⚖️</span>
                      <div>
                        <p className="font-black text-red-900 uppercase text-[10px] tracking-wide">In Verification Checkpoint</p>
                        <p className="text-red-700 font-medium text-xs mt-1">This request is routing through an ad-hoc detour branch. Actions suspended until returned.</p>
                      </div>
                    </div>
                  ) : isActionAltered ? (
                    <div className="bg-green-50 border border-green-200 rounded-xl p-4 flex gap-3 text-sm">
                      <span>🛡️</span>
                      <div>
                        <p className="font-black text-green-900 uppercase text-[10px] tracking-wide">Vault Locked</p>
                        <p className="text-green-700 font-medium text-xs mt-1">Action completed. Ready for Time-Out scan to push to next destination.</p>
                      </div>
                    </div>
                  ) : (
                    <div className="space-y-4 pt-2">
                      <div className="flex gap-2">
                        <button type="button" onClick={() => { setShowAdHocForm(!showAdHocForm); setShowSendBackForm(false); }} className="px-4 py-2 bg-neutral-100 hover:bg-neutral-200 text-neutral-700 rounded-xl font-bold text-xs flex items-center gap-2 transition-all"><GitBranch size={14} /> Ad-hoc Detour</button>
                      </div>

                      {showAdHocForm && (
                        <form onSubmit={handleExecuteAdHocDetour} className="bg-neutral-50 p-4 border rounded-xl space-y-3">
                          <select required value={selectedAdHocOffice} onChange={e => setSelectedAdHocOffice(e.target.value)} className="w-full bg-white border border-neutral-300 rounded-lg px-3 py-2 text-xs font-bold text-neutral-700">
                            <option value="">-- Choose Detour Target --</option>
                            {officesList.map((off, idx) => (off.id !== gsoOfficeId && <option key={idx} value={off.id}>{off.name}</option>))}
                          </select>
                          <button type="submit" disabled={isActionProcessing} className="w-full py-2 bg-neutral-800 text-white font-bold text-xs rounded-lg uppercase">Route Detour</button>
                        </form>
                      )}

                      {showSendBackForm && (
                        <form onSubmit={handleExecuteReturn} className="bg-red-50/40 border border-red-100 rounded-xl p-4 space-y-3">
                          <textarea required rows={3} placeholder="Provide revision notes..." value={returnReason} onChange={e => setReturnReason(e.target.value)} className="w-full border rounded-lg p-3 text-xs outline-none focus:ring-1 focus:ring-red-800 font-medium text-neutral-800" />
                          <button type="submit" disabled={isActionProcessing} className="w-full py-2 bg-red-800 text-white font-bold text-xs rounded-lg uppercase tracking-wide">Submit Revision Request</button>
                        </form>
                      )}
                    </div>
                  )}
                </div>

                {/* Right Column: QR and Routing Visual */}
                <div className="border-l pl-6 space-y-6 flex flex-col items-center">
                  <div className="text-center w-full">
                    <span className="text-[9px] font-black uppercase text-neutral-400 tracking-wider">Identity Token</span>
                    <div className="bg-white p-3 border rounded-xl shadow-xs inline-block mt-2">
                      <QRCodeSVG value={docQr} size={120} level={"M"} fgColor={"#2D1F1E"} />
                    </div>
                    <span className="font-mono text-[10px] font-black text-red-800 tracking-wide mt-2 block break-all">{docQr}</span>
                  </div>
                </div>
              </div>

              {/* Action Footer */}
              <div className="p-4 border-t bg-[#FDFBF9] flex justify-end gap-2 px-6">
              {!isAwaitingScanIn && !isInVerification && !isActionAltered && !isHistoryDetails && (
                  <>
                    <button type="button" onClick={() => { setShowSendBackForm(!showSendBackForm); setShowAdHocForm(false); }} className="px-5 py-2 border bg-white hover:bg-neutral-50 rounded-xl font-bold text-xs text-neutral-600 transition-all">{showSendBackForm ? 'Cancel Revision' : 'Send Back'}</button>
                    <button type="button" disabled={isActionProcessing} onClick={handleSignDocument} className="px-6 py-2 bg-red-800 hover:bg-red-900 text-white font-bold text-xs rounded-xl uppercase tracking-wider shadow-md">Sign File</button>
                  </>
                )}
                {isAwaitingScanIn && (
                  <button type="button" onClick={() => { setShowDetailsModal(false); setScanMode('time-in'); setShowScannerModal(true); setSimulatedQrPayload(docQr); }} className="px-6 py-2 bg-blue-700 hover:bg-blue-800 text-white font-bold text-xs rounded-xl shadow-md uppercase tracking-wider flex items-center gap-2"><Camera size={14}/> Scan-In Now</button>
                )}
                {isActionAltered && !selectedDoc.time_out && (
                  <button type="button" onClick={() => { setShowDetailsModal(false); setScanMode('time-out'); setShowScannerModal(true); setSimulatedQrPayload(docQr); }} className="px-6 py-2 bg-green-700 hover:bg-green-800 text-white font-bold text-xs rounded-xl shadow-md uppercase tracking-wider flex items-center gap-2"><Camera size={14}/> Scan-Out Now</button>
                )}
              </div>
            </div>
          </div>
        );
      })()}

      {/* --- PROFILE CHANGE PASSWORD MODAL --- */}
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

      {/* --- SCANNER MODAL --- */}
      {showScannerModal && (
        <div className="fixed inset-0 bg-neutral-950/60 backdrop-blur-sm flex items-center justify-center p-4 z-[110] animate-in fade-in duration-150">
          <div className="bg-white w-full max-w-sm rounded-3xl border shadow-2xl p-6 text-center space-y-5">
            <div className="flex items-center justify-between border-b border-neutral-100 pb-3">
              <h4 className="font-black text-neutral-900 text-sm flex items-center gap-2"><QrCode size={18} className="text-red-800"/> GSO Scanner</h4>
              <button onClick={() => { setShowScannerModal(false); setSimulatedQrPayload(''); }} className="text-neutral-400 hover:text-neutral-600"><X size={20} /></button>
            </div>

            <div className="bg-neutral-100 p-1 rounded-xl flex font-bold text-[10px]">
              <button type="button" onClick={() => setScanMode('time-in')} className={`w-1/2 py-2 rounded-lg uppercase tracking-wider ${scanMode === 'time-in' ? 'bg-white text-blue-700 shadow-sm' : 'text-neutral-400'}`}>Arrival Scan-In</button>
              <button type="button" onClick={() => setScanMode('time-out')} className={`w-1/2 py-2 rounded-lg uppercase tracking-wider ${scanMode === 'time-out' ? 'bg-white text-green-700 shadow-sm' : 'text-neutral-400'}`}>Release Scan-Out</button>
            </div>

            <div className="overflow-hidden rounded-2xl bg-black relative h-56 flex items-center justify-center group">
              <Scanner onScan={(result) => { if (result?.[0]?.rawValue) { setSimulatedQrPayload(result[0].rawValue); executeSimulatedScanner(null, result[0].rawValue); } }} components={{ audio: false }} styles={{ container: { width: '100%', height: '100%', borderRadius: '1rem' } }} />
              <div className="absolute inset-0 pointer-events-none border-4 border-transparent group-hover:border-red-500/50 rounded-2xl"></div>
            </div>

            <form onSubmit={executeSimulatedScanner} className="pt-2 border-t">
              <input type="text" placeholder="Or enter manual token..." value={simulatedQrInput} onChange={e => setSimulatedQrPayload(e.target.value)} className="w-full border px-4 py-2.5 text-xs font-mono text-center rounded-xl outline-none focus:ring-1 focus:ring-red-800 mb-2 bg-neutral-50" />
              <button type="submit" className="w-full bg-neutral-900 hover:bg-black text-white text-xs py-2.5 font-bold rounded-xl uppercase tracking-wider">Process Submission</button>
            </form>
          </div>
        </div>
      )}

      {/* --- ADD NEW ASSET MODAL --- */}
      {showAddAssetModal && (
        <div className="fixed inset-0 bg-neutral-950/40 backdrop-blur-xs flex items-center justify-center p-4 z-[120] animate-in fade-in duration-150">
          <div className="bg-white w-full max-w-md rounded-2xl shadow-2xl border overflow-hidden flex flex-col text-left">
            <div className="p-4 border-b bg-[#FDFBF9] flex items-center justify-between">
              <h3 className="font-bold text-neutral-900 text-sm">Add New Institutional Asset</h3>
              <button onClick={() => setShowAddAssetModal(false)} className="text-neutral-400 hover:text-neutral-600"><X size={16} /></button>
            </div>
            
            <form onSubmit={handleAddAssetSubmit} className="p-6 space-y-4">
              <div>
                <label className="block text-[10px] font-bold text-gray-500 uppercase mb-1">Asset Name</label>
                <input 
                  type="text" 
                  required 
                  placeholder="e.g. Science Lab 302 or Bus 05" 
                  value={assetForm.assetName} 
                  onChange={e => setAssetForm({...assetForm, assetName: e.target.value})} 
                  className="w-full px-4 py-2 text-xs border border-neutral-300 rounded-lg focus:ring-1 focus:ring-red-700 outline-none" 
                />
              </div>
              
              <div>
                <label className="block text-[10px] font-bold text-gray-500 uppercase mb-1">Asset Type</label>
                <select 
                  value={assetForm.assetTypeId} 
                  onChange={e => setAssetForm({...assetForm, assetTypeId: e.target.value})} 
                  className="w-full px-4 py-2 text-xs border border-neutral-300 rounded-lg focus:ring-1 focus:ring-red-700 outline-none bg-white font-medium"
                >
                  <option value="1">Room</option>
                  <option value="2">Gymnasium</option>
                  <option value="4">Vehicle</option>
                  <option value="3">Equipment / Furniture</option>
                </select>
              </div>

              {/* Conditionally render Quantity if "Equipment / Furniture" (ast_id 3) is selected */}
              {assetForm.assetTypeId === '3' && (
                <div className="animate-in fade-in slide-in-from-top-2 duration-200">
                  <label className="block text-[10px] font-bold text-gray-500 uppercase mb-1">Total Quantity Stock</label>
                  <input 
                    type="number" 
                    required 
                    min="1"
                    placeholder="e.g. 50" 
                    value={assetForm.quantity} 
                    onChange={e => setAssetForm({...assetForm, quantity: e.target.value})} 
                    className="w-full px-4 py-2 text-xs border border-neutral-300 rounded-lg focus:ring-1 focus:ring-red-700 outline-none" 
                  />
                </div>
              )}

              <div className="flex items-start gap-2.5 pt-4">
                <input 
                  type="checkbox" 
                  id="assetConfirm" 
                  checked={assetForm.isConfirmed}
                  onChange={e => setAssetForm({...assetForm, isConfirmed: e.target.checked})}
                  className="mt-0.5 rounded text-red-800 focus:ring-red-700 w-3.5 h-3.5" 
                />
                <label htmlFor="assetConfirm" className="text-[11px] font-medium text-gray-500 leading-tight cursor-pointer">
                  I confirm the accuracy of this asset information and its current availability status.
                </label>
              </div>

              <div className="flex justify-between gap-3 pt-6 border-t border-neutral-100 mt-2">
                <button type="button" onClick={() => setShowAddAssetModal(false)} className="w-1/2 py-2.5 border rounded-xl font-bold text-xs text-gray-500 hover:bg-neutral-50 uppercase tracking-wide">Cancel</button>
                <button type="submit" className="w-1/2 py-2.5 bg-red-800 hover:bg-red-900 text-white font-bold rounded-xl shadow-xs uppercase tracking-wide text-xs">Add Asset</button>
              </div>
            </form>
          </div>
        </div>
      )}

      {/* --- EDIT ASSET & DETAILS MODAL --- */}
      {showEditAssetModal && selectedEditAsset && (
        <div className="fixed inset-0 bg-neutral-950/40 backdrop-blur-xs flex items-center justify-center p-4 z-[120] animate-in fade-in duration-150">
          <div className="bg-white w-full max-w-2xl rounded-2xl shadow-2xl border overflow-hidden flex flex-col text-left">
            <div className="p-4 border-b bg-[#FDFBF9] flex items-center justify-between">
              <h3 className="font-bold text-neutral-900 text-sm">Asset Details & Configuration</h3>
              <button onClick={() => setShowEditAssetModal(false)} className="text-neutral-400 hover:text-neutral-600"><X size={16} /></button>
            </div>
            
            <div className="flex flex-col md:flex-row h-[60vh] md:h-auto max-h-[80vh]">
              {/* Left Column: Edit Form */}
              <form onSubmit={handleUpdateAsset} className="p-6 md:w-1/2 space-y-4 border-b md:border-b-0 md:border-r border-neutral-100 overflow-y-auto">
                <div>
                  <label className="block text-[10px] font-bold text-gray-500 uppercase mb-1">Asset Name</label>
                  <input 
                    type="text" 
                    required 
                    value={selectedEditAsset.asset_name} 
                    onChange={e => setSelectedEditAsset({...selectedEditAsset, asset_name: e.target.value})} 
                    className="w-full px-4 py-2 text-xs border border-neutral-300 rounded-lg focus:ring-1 focus:ring-red-700 outline-none" 
                  />
                </div>
                
                <div>
                  <label className="block text-[10px] font-bold text-gray-500 uppercase mb-1">Asset Type</label>
                  <input 
                    type="text" 
                    readOnly
                    value={selectedEditAsset.asset_type === 'Furniture' ? 'Equipment' : selectedEditAsset.asset_type} 
                    className="w-full px-4 py-2 text-xs border border-neutral-200 bg-neutral-50 text-neutral-500 rounded-lg outline-none cursor-not-allowed" 
                  />
                </div>

                {selectedEditAsset.ast_id === 3 && (
                  <div>
                    <label className="block text-[10px] font-bold text-gray-500 uppercase mb-1">Total Quantity Stock</label>
                    <input 
                      type="number" 
                      required 
                      min="1"
                      value={selectedEditAsset.quantity} 
                      onChange={e => setSelectedEditAsset({...selectedEditAsset, quantity: e.target.value})} 
                      className="w-full px-4 py-2 text-xs border border-neutral-300 rounded-lg focus:ring-1 focus:ring-red-700 outline-none" 
                    />
                  </div>
                )}

                <div className="pt-6 border-t border-neutral-100 mt-auto">
                  <button type="submit" className="w-full py-2.5 bg-red-800 hover:bg-red-900 text-white font-bold rounded-xl shadow-xs uppercase tracking-wide text-xs">Save Changes</button>
                </div>
              </form>

              {/* Right Column: Upcoming Schedule */}
              <div className="p-6 md:w-1/2 bg-neutral-50/50 overflow-y-auto">
                <h4 className="text-xs font-black text-neutral-900 uppercase tracking-wider mb-4 flex items-center gap-2">
                  <Calendar size={14} className="text-red-800"/> Confirmed Schedule
                </h4>
                
                <div className="space-y-3">
                  {assetSchedule.length === 0 ? (
                    <div className="text-center p-6 border-2 border-dashed border-neutral-200 rounded-xl text-neutral-400 text-xs font-bold">
                      No upcoming confirmed reservations.
                    </div>
                  ) : (
                    assetSchedule.map((sched, idx) => {
                      const dateObj = new Date(sched.reservation_date);
                      return (
                        <div key={idx} className="bg-white p-3 rounded-xl border border-neutral-200 shadow-sm flex flex-col gap-1">
                          <div className="flex justify-between items-start">
                            <span className="font-bold text-neutral-900 text-xs">{dateObj.toLocaleDateString('en-US', { month: 'short', day: 'numeric', year: 'numeric' })}</span>
                            <span className="text-[10px] font-mono font-bold text-red-800 bg-red-50 px-2 py-0.5 rounded">
                              {sched.start_time.substring(0,5)} - {sched.end_time.substring(0,5)}
                            </span>
                          </div>
                          <p className="text-[11px] text-neutral-600 font-medium">For: <span className="font-bold">{sched.purpose}</span></p>
                          <p className="text-[10px] text-neutral-400">By: {sched.requestor}</p>
                        </div>
                      );
                    })
                  )}
                </div>
              </div>
            </div>
          </div>
        </div>
      )}

      {/* --- LOGISTICS INVENTORY LEND/RETURN MODAL --- */}
      {showInventoryModal && selectedInventoryItem && (
        <div className="fixed inset-0 bg-neutral-950/40 backdrop-blur-xs flex items-center justify-center p-4 z-[120] animate-in fade-in duration-150">
          <div className="bg-white w-full max-w-md rounded-2xl shadow-2xl border overflow-hidden flex flex-col text-left">
            
            {/* Tab Selectors */}
            <div className="flex border-b">
              <button 
                onClick={() => setInventoryModalMode('LEND')}
                className={`w-1/2 py-4 text-xs font-black uppercase tracking-wider transition-colors ${inventoryModalMode === 'LEND' ? 'text-red-800 border-b-2 border-red-800 bg-white' : 'text-neutral-400 bg-neutral-50 hover:bg-neutral-100'}`}
              >
                Lending Form
              </button>
              <button 
                onClick={() => setInventoryModalMode('RETURN')}
                className={`w-1/2 py-4 text-xs font-black uppercase tracking-wider transition-colors ${inventoryModalMode === 'RETURN' ? 'text-red-800 border-b-2 border-red-800 bg-white' : 'text-neutral-400 bg-neutral-50 hover:bg-neutral-100'}`}
              >
                Return Form
              </button>
            </div>
            
            <form onSubmit={handleInventorySubmit} className="p-6 space-y-4 max-h-[70vh] overflow-y-auto">
              <div className="bg-red-50/50 p-3 rounded-xl border border-red-100 mb-2">
                <span className="text-[10px] text-red-800 font-bold uppercase block">Target Asset</span>
                <span className="font-black text-neutral-900 text-sm">{selectedInventoryItem.asset_name}</span>
              </div>

              {inventoryModalMode === 'LEND' ? (
                <div className="space-y-4 animate-in fade-in slide-in-from-right-2 duration-200">
                  <div className="grid grid-cols-2 gap-4">
                    <div>
                      <label className="block text-[10px] font-bold text-gray-500 uppercase mb-1">Requestor</label>
                      <input type="text" required value={inventoryForm.requestorName} onChange={e => setInventoryForm({...inventoryForm, requestorName: e.target.value})} className="w-full px-4 py-2 text-xs border border-neutral-300 rounded-lg outline-none focus:ring-1 focus:ring-red-700" />
                    </div>
                    <div>
                      <label className="block text-[10px] font-bold text-gray-500 uppercase mb-1">Department</label>
                      <input type="text" required value={inventoryForm.department} onChange={e => setInventoryForm({...inventoryForm, department: e.target.value})} className="w-full px-4 py-2 text-xs border border-neutral-300 rounded-lg outline-none focus:ring-1 focus:ring-red-700" />
                    </div>
                  </div>
                  <div>
                    <label className="block text-[10px] font-bold text-gray-500 uppercase mb-1">Purpose</label>
                    <input type="text" required value={inventoryForm.purpose} onChange={e => setInventoryForm({...inventoryForm, purpose: e.target.value})} className="w-full px-4 py-2 text-xs border border-neutral-300 rounded-lg outline-none focus:ring-1 focus:ring-red-700" />
                  </div>
                  <div className="grid grid-cols-2 gap-4">
                  <div>
                      <label className="block text-[10px] font-bold text-gray-500 uppercase mb-1">Date</label>
                      <input 
                        type="date" 
                        required 
                        min={todayString} 
                        className="w-full px-4 py-2 text-xs border border-neutral-300 rounded-lg outline-none focus:ring-1 focus:ring-red-700" 
                      />
                  </div>
                    <div>
                      <label className="block text-[10px] font-bold text-gray-500 uppercase mb-1">Duration (Hours)</label>
                      <input type="number" required value={inventoryForm.duration} onChange={e => setInventoryForm({...inventoryForm, duration: e.target.value})} className="w-full px-4 py-2 text-xs border border-neutral-300 rounded-lg outline-none focus:ring-1 focus:ring-red-700" />
                    </div>
                  </div>
                  <div>
                    <label className="block text-[10px] font-bold text-gray-500 uppercase mb-1">Quantity Needed</label>
                    <input type="number" required max={selectedInventoryItem.current_stock} min="1" value={inventoryForm.quantityNeeded} onChange={e => setInventoryForm({...inventoryForm, quantityNeeded: e.target.value})} className="w-full px-4 py-2 text-xs border border-neutral-300 rounded-lg outline-none focus:ring-1 focus:ring-red-700" />
                  </div>
                </div>
              ) : (
                <div className="space-y-4 animate-in fade-in slide-in-from-left-2 duration-200">
                  <div>
                    <label className="block text-[10px] font-bold text-gray-500 uppercase mb-1">Requestor (Matching Name)</label>
                    <input type="text" required value={inventoryForm.requestorName} onChange={e => setInventoryForm({...inventoryForm, requestorName: e.target.value})} className="w-full px-4 py-2 text-xs border border-neutral-300 rounded-lg outline-none focus:ring-1 focus:ring-red-700" />
                  </div>
                  <div className="grid grid-cols-2 gap-4">
                    <div>
                      <label className="block text-[10px] font-bold text-gray-500 uppercase mb-1">Return Date</label>
                      <input type="date" required value={inventoryForm.returnDate} onChange={e => setInventoryForm({...inventoryForm, returnDate: e.target.value})} className="w-full px-4 py-2 text-xs border border-neutral-300 rounded-lg outline-none focus:ring-1 focus:ring-red-700" />
                    </div>
                    <div>
                      <label className="block text-[10px] font-bold text-gray-500 uppercase mb-1">Return Time</label>
                      <input type="time" required value={inventoryForm.returnTime} onChange={e => setInventoryForm({...inventoryForm, returnTime: e.target.value})} className="w-full px-4 py-2 text-xs border border-neutral-300 rounded-lg outline-none focus:ring-1 focus:ring-red-700" />
                    </div>
                  </div>
                  <div>
                    <label className="block text-[10px] font-bold text-gray-500 uppercase mb-1">Quantity Returned</label>
                    <input type="number" required min="1" value={inventoryForm.quantityNeeded} onChange={e => setInventoryForm({...inventoryForm, quantityNeeded: e.target.value})} className="w-full px-4 py-2 text-xs border border-neutral-300 rounded-lg outline-none focus:ring-1 focus:ring-red-700" />
                  </div>
                  <div className="pt-2 border-t border-neutral-100">
                  <label className="block text-[10px] font-bold text-gray-500 uppercase mb-3">Item Condition Upon Return</label>
                  <div className="flex gap-6">
                    <label className="flex items-center gap-2 text-xs font-bold text-neutral-700 cursor-pointer">
                      <input 
                        type="radio" 
                        name="condition" 
                        checked={!inventoryForm.isDamaged} 
                        onChange={() => setInventoryForm({...inventoryForm, isDamaged: false, damageNotes: ''})} 
                        className="text-red-800 focus:ring-red-700 w-3.5 h-3.5" 
                      />
                      Good / No Damages
                    </label>
                    <label className="flex items-center gap-2 text-xs font-bold text-neutral-700 cursor-pointer">
                      <input 
                        type="radio" 
                        name="condition" 
                        checked={inventoryForm.isDamaged} 
                        onChange={() => setInventoryForm({...inventoryForm, isDamaged: true})} 
                        className="text-red-800 focus:ring-red-700 w-3.5 h-3.5" 
                      />
                      Damaged
                    </label>
                  </div>

                  {/* Conditionally Render Damage Notes */}
                  {inventoryForm.isDamaged && (
                    <div className="mt-4 animate-in fade-in slide-in-from-top-1 duration-200">
                      <label className="block text-[10px] font-bold text-gray-500 uppercase mb-1">Damage Assessment Notes</label>
                      <textarea
                        required
                        rows="2"
                        placeholder="Describe the damages found (e.g., 2 chairs have broken legs)..."
                        value={inventoryForm.damageNotes}
                        onChange={e => setInventoryForm({...inventoryForm, damageNotes: e.target.value})}
                        className="w-full px-4 py-2 text-xs border border-red-300 rounded-lg outline-none focus:ring-1 focus:ring-red-700 bg-red-50 text-red-900 placeholder:text-red-300 resize-none"
                      />
                    </div>
                  )}
                </div>
                </div>
              )}

              <div className="flex justify-between gap-3 pt-6 border-t border-neutral-100 mt-2">
                <button type="button" onClick={() => setShowInventoryModal(false)} className="w-1/2 py-2.5 border rounded-xl font-bold text-xs text-gray-500 hover:bg-neutral-50 uppercase tracking-wide">Cancel</button>
                <button type="submit" disabled={isActionProcessing} className="w-1/2 py-2.5 bg-red-800 hover:bg-red-900 text-white font-bold rounded-xl shadow-xs uppercase tracking-wide text-xs disabled:opacity-50">
                  {inventoryModalMode === 'LEND' ? 'Submit' : 'Confirm Return'}
                </button>
              </div>
            </form>
          </div>
        </div>
      )}
      
      {/* --- APPLY BLACKOUT DATES MODAL --- */}
      {showBlackoutModal && (
        <div className="fixed inset-0 bg-neutral-950/40 backdrop-blur-xs flex items-center justify-center p-4 z-[120] animate-in fade-in duration-150">
          <div className="bg-white w-full max-w-md rounded-2xl shadow-2xl border overflow-hidden flex flex-col text-left">
            <div className="p-4 border-b bg-[#FDFBF9] flex items-center justify-between">
              <h3 className="font-bold text-neutral-900 text-sm flex items-center gap-2"><Lock size={16} className="text-red-800" /> Apply Facility Blackout</h3>
              <button onClick={() => setShowBlackoutModal(false)} className="text-neutral-400 hover:text-neutral-600"><X size={16} /></button>
            </div>
            
            <form onSubmit={handleApplyBlackout} className="p-6 space-y-4">
              <div>
                <label className="block text-[10px] font-bold text-gray-500 uppercase mb-1">Target Asset Facility</label>
                <select required value={blackoutForm.asd_id} onChange={e => setBlackoutForm({...blackoutForm, asd_id: e.target.value})} className="w-full px-4 py-2 text-xs border border-neutral-300 rounded-lg outline-none focus:ring-1 focus:ring-red-700 font-bold text-neutral-700">
                  <option value="">-- Select Facility --</option>
                  {assetsList.filter(a => a.ast_id !== 3).map(asset => (
                    <option key={asset.asd_id} value={asset.asd_id}>{asset.asset_name} ({asset.asset_type})</option>
                  ))}
                </select>
              </div>
              <div className="grid grid-cols-2 gap-4">
                <div>
                  <label className="block text-[10px] font-bold text-gray-500 uppercase mb-1">Start Date</label>
                  <input 
                    type="date" 
                    required 
                    min={todayString}
                    value={blackoutForm.start_time} 
                    onChange={e => setBlackoutForm({...blackoutForm, start_time: e.target.value})} 
                    className="w-full px-4 py-2 text-xs border border-neutral-300 rounded-lg outline-none focus:ring-1 focus:ring-red-700" 
                  />
                </div>
                <div>
                  <label className="block text-[10px] font-bold text-gray-500 uppercase mb-1">End Date</label>
                  {/* Ensures end date cannot be before the selected start date */}
                  <input 
                    type="date" 
                    required 
                    min={blackoutForm.start_time || todayString} 
                    value={blackoutForm.end_time} 
                    onChange={e => setBlackoutForm({...blackoutForm, end_time: e.target.value})} 
                    className="w-full px-4 py-2 text-xs border border-neutral-300 rounded-lg outline-none focus:ring-1 focus:ring-red-700" 
                  />
                </div>
              </div>
              <div>
                <label className="block text-[10px] font-bold text-gray-500 uppercase mb-1">Reason for Blackout (Maintenance, Repair, Event)</label>
                <input type="text" required value={blackoutForm.reason} onChange={e => setBlackoutForm({...blackoutForm, reason: e.target.value})} placeholder="e.g., Annual Maintenance" className="w-full px-4 py-2 text-xs border border-neutral-300 rounded-lg outline-none focus:ring-1 focus:ring-red-700" />
              </div>
              <div className="flex justify-between gap-3 pt-6 border-t border-neutral-100 mt-2">
                <button type="button" onClick={() => setShowBlackoutModal(false)} className="w-1/2 py-2.5 border rounded-xl font-bold text-xs text-gray-500 hover:bg-neutral-50 uppercase tracking-wide">Cancel</button>
                <button type="submit" className="w-1/2 py-2.5 bg-red-800 hover:bg-red-900 text-white font-bold rounded-xl shadow-xs uppercase tracking-wide text-xs">Confirm Block</button>
              </div>
            </form>
          </div>
        </div>
      )}

      {/* --- GLOBAL MASTER CHECKLIST MAKER MODAL --- */}
      {showChecklistMakerModal && (
        <div className="fixed inset-0 bg-neutral-950/40 backdrop-blur-xs flex items-center justify-center p-4 z-[120] animate-in fade-in duration-150">
          <div className="bg-white w-full max-w-lg rounded-2xl shadow-2xl border overflow-hidden flex flex-col text-left">
            
            <div className="p-4 border-b bg-[#FDFBF9] flex items-center justify-between">
              <h3 className="font-bold text-neutral-900 text-sm flex items-center gap-2">
                <Edit size={16} className="text-red-800" /> Master Checklist Configuration
              </h3>
              <button onClick={() => setShowChecklistMakerModal(false)} className="text-neutral-400 hover:text-neutral-600"><X size={16} /></button>
            </div>

            <div className="p-5 flex flex-col h-[50vh]">
              {/* Reservation Target Tabs */}
              <div className="bg-neutral-100 p-1 rounded-xl flex font-bold text-[10px] mb-4 flex-shrink-0">
                {['Vehicle', 'Multimedia Room', 'Gymnasium'].map((tab) => (
                  <button 
                    key={tab}
                    onClick={() => setActiveChecklistTab(tab)}
                    className={`w-1/3 py-2 rounded-lg uppercase tracking-wider transition-colors ${
                      activeChecklistTab === tab ? 'bg-white text-red-800 shadow-sm' : 'text-neutral-500 hover:text-neutral-800'
                    }`}
                  >
                    {tab}
                  </button>
                ))}
              </div>

              {/* Global List Editor */}
              <div className="flex-1 overflow-y-auto space-y-2 border border-neutral-200 bg-neutral-50 rounded-xl p-4">
                <p className="text-[10px] font-black uppercase text-neutral-400 tracking-wider mb-3 block">
                  {activeChecklistTab} Required Documents
                </p>
                
                {masterChecklistItems.length === 0 ? (
                  <div className="text-center p-4 text-neutral-400 text-xs font-bold">No requirements set.</div>
                ) : (
                  masterChecklistItems.map(item => (
                    <div key={item.template_id} className="flex justify-between items-center bg-white p-2.5 rounded-lg border border-neutral-200 shadow-sm animate-in fade-in">
                      <span className="text-xs font-bold text-neutral-700">{item.item_name}</span>
                      <button 
                        onClick={() => handleDeleteMasterChecklistItem(item.template_id)}
                        className="text-red-600 hover:text-red-800 hover:bg-red-50 p-1.5 rounded-md transition-colors"
                      >
                        <Trash2 size={14} />
                      </button>
                    </div>
                  ))
                )}
              </div>

              {/* Add New Item Input */}
              <form onSubmit={handleAddMasterChecklistItem} className="mt-4 flex gap-2 flex-shrink-0">
                <input 
                  type="text" 
                  value={newChecklistName}
                  onChange={(e) => setNewChecklistName(e.target.value)}
                  placeholder="Type new document requirement..." 
                  className="flex-1 px-3 py-2 text-xs border border-neutral-300 rounded-lg focus:ring-1 focus:ring-red-700 outline-none"
                />
                <button 
                  type="submit" 
                  className="px-4 py-2 bg-neutral-900 hover:bg-black text-white font-bold text-xs rounded-lg uppercase tracking-wide transition-colors"
                >
                  Add
                </button>
              </form>
            </div>

          </div>
        </div>
      )}

      {/* --- GLOBAL MASTER PRINT MODAL --- */}
      {showPrintModal && (
        <div className="fixed inset-0 bg-neutral-950/40 backdrop-blur-xs flex items-center justify-center p-4 z-[120] animate-in fade-in duration-150">
          <div className="bg-white w-full max-w-lg rounded-2xl shadow-2xl border overflow-hidden flex flex-col text-left">
            
            <div className="p-4 border-b bg-[#FDFBF9] flex items-center justify-between">
              <h3 className="font-bold text-neutral-900 text-sm flex items-center gap-2">
                <Download size={16} className="text-neutral-700" /> Export Procurement Logs
              </h3>
              <button onClick={() => setShowPrintModal(false)} className="text-neutral-400 hover:text-neutral-600"><X size={16} /></button>
            </div>

            <div className="p-5 flex flex-col">
              <label className="block text-[10px] font-black uppercase text-neutral-400 tracking-wider mb-2">Select Target Database</label>
              
              {/* Dynamic Tab Selection */}
              <div className="bg-neutral-100 p-1 rounded-xl flex font-bold text-[10px] mb-4 flex-wrap">
                {['Vehicle', 'Multimedia Room', 'Gymnasium', 'Logistics History'].map((tab) => (
                  <button 
                    key={tab}
                    onClick={() => setPrintTargetTab(tab)}
                    className={`flex-1 py-2 rounded-lg uppercase tracking-wider transition-colors min-w-[45%] m-0.5 ${
                      printTargetTab === tab ? 'bg-white text-neutral-900 shadow-sm border border-neutral-200' : 'text-neutral-500 hover:text-neutral-800'
                    }`}
                  >
                    {tab}
                  </button>
                ))}
              </div>

              {/* Date Filter Inputs */}
              <div className="grid grid-cols-2 gap-4 mt-2">
                <div>
                  <label className="block text-[10px] font-bold text-gray-500 uppercase mb-1">Start Date</label>
                  <input 
                    type="date" 
                    value={printStartDate}
                    onChange={(e) => setPrintStartDate(e.target.value)}
                    className="w-full px-4 py-2 text-xs border border-neutral-300 rounded-lg focus:ring-1 focus:ring-neutral-700 outline-none bg-neutral-50" 
                  />
                </div>
                <div>
                  <label className="block text-[10px] font-bold text-gray-500 uppercase mb-1">End Date</label>
                  <input 
                    type="date" 
                    value={printEndDate}
                    onChange={(e) => setPrintEndDate(e.target.value)}
                    className="w-full px-4 py-2 text-xs border border-neutral-300 rounded-lg focus:ring-1 focus:ring-neutral-700 outline-none bg-neutral-50" 
                  />
                </div>
              </div>

              <div className="flex justify-between gap-3 pt-6 border-t border-neutral-100 mt-6">
                <button type="button" onClick={() => setShowPrintModal(false)} className="w-1/2 py-2.5 border rounded-xl font-bold text-xs text-gray-500 hover:bg-neutral-50 uppercase tracking-wide">Cancel</button>
                <button 
                    type="button" 
                    onClick={handleGeneratePDF}
                    className="w-1/2 py-2.5 bg-neutral-900 hover:bg-black text-white font-bold rounded-xl shadow-xs uppercase tracking-wide text-xs flex items-center justify-center gap-2"
                  >
                    <Download size={14} /> Generate PDF
                  </button>
              </div>
            </div>

          </div>
        </div>
      )}

      {/* --- INDIVIDUAL RESERVATION CHECKLIST MODAL --- */}
      {showActiveChecklistModal && activeChecklistBooking && (
        <div className="fixed inset-0 bg-neutral-950/40 backdrop-blur-xs flex items-center justify-center p-4 z-[120] animate-in fade-in duration-150">
          <div className="bg-white w-full max-w-md rounded-2xl shadow-2xl border overflow-hidden flex flex-col text-left">
            
            <div className="p-4 border-b bg-[#FDFBF9] flex items-center justify-between">
              <h3 className="font-bold text-neutral-900 text-sm flex items-center gap-2">
                <FileText size={16} className="text-red-800" /> Booking Requirements
              </h3>
              <button onClick={() => setShowActiveChecklistModal(false)} className="text-neutral-400 hover:text-neutral-600"><X size={16} /></button>
            </div>

            <div className="p-5 flex flex-col">
              {/* Booking Context Header */}
              <div className="bg-neutral-50 border border-neutral-200 p-3 rounded-xl mb-4">
                <span className="text-[10px] font-black uppercase text-neutral-400 tracking-wider">Requestor</span>
                <p className="font-bold text-neutral-900 text-sm">{activeChecklistBooking.requestor}</p>
                <div className="flex justify-between items-end mt-2">
                  <div>
                    <span className="text-[10px] font-black uppercase text-neutral-400 tracking-wider block">Facility</span>
                    <p className="text-xs font-bold text-neutral-700">{activeChecklistBooking.booking_type}</p>
                  </div>
                  <div>
                    <span className={`px-2 py-0.5 rounded text-[9px] font-black uppercase tracking-wide border ${activeChecklistBooking.status === 'Confirmed' ? 'bg-green-50 text-green-700 border-green-200' : 'bg-amber-50 text-amber-700 border-amber-200'}`}>
                      {activeChecklistBooking.status}
                    </span>
                  </div>
                </div>
              </div>

              <p className="text-[10px] font-black uppercase text-neutral-400 tracking-wider mb-2 block">
                Required Documents Checklist
              </p>

              {/* Dynamic Checklist Render */}
              <div className="space-y-2 max-h-[40vh] overflow-y-auto">
                {activeChecklistItems.length === 0 ? (
                  <div className="text-center p-4 border border-dashed border-neutral-200 rounded-xl text-neutral-400 text-xs font-bold">
                    No requirements configured for this facility type.
                  </div>
                ) : (
                  activeChecklistItems.map((item) => (
                    <label 
                      key={item.check_id} 
                      className={`flex items-center gap-3 p-3 rounded-xl border cursor-pointer transition-colors ${
                        item.is_checked ? 'bg-green-50/50 border-green-200' : 'bg-white border-neutral-200 hover:bg-neutral-50'
                      }`}
                    >
                      <div className="relative flex items-center justify-center">
                        <input 
                          type="checkbox" 
                          checked={item.is_checked} 
                          onChange={() => handleToggleChecklistItem(item.check_id, item.is_checked)}
                          className="w-5 h-5 appearance-none border-2 border-neutral-300 rounded-md checked:border-green-600 checked:bg-green-600 transition-colors cursor-pointer"
                        />
                        {item.is_checked && <span className="absolute text-white pointer-events-none">✓</span>}
                      </div>
                      <span className={`text-xs font-bold ${item.is_checked ? 'text-green-800 line-through opacity-70' : 'text-neutral-700'}`}>
                        {item.item_name}
                      </span>
                    </label>
                  ))
                )}
              </div>

              <div className="mt-6 pt-4 border-t border-neutral-100">
                <button 
                  type="button" 
                  onClick={() => setShowActiveChecklistModal(false)} 
                  className="w-full py-2.5 bg-neutral-900 hover:bg-black text-white font-bold rounded-xl shadow-xs uppercase tracking-wide text-xs transition-colors"
                >
                  Done
                </button>
              </div>
            </div>

          </div>
        </div>
      )}

    </div>
  );
}