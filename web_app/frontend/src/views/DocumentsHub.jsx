import React, { useState, useEffect } from 'react';
import { MoreVertical, Search, Filter, Plus, X, QrCode, FileText, Download, Printer, AlertTriangle, ChevronLeft, ChevronRight } from 'lucide-react';
import { fetchWithAuth } from '../api';

export default function DocumentsHub({ 
  userId, 
  documents, 
  fetchDashboardLedger, 
  setShowModal, 
  processTypes 
}) {
  const userName = localStorage.getItem('user') || 'Faculty User';
  const [selectedDoc, setSelectedDoc] = useState(null);
  const [activeDetailsDoc, setActiveDetailsDoc] = useState(null); 
  const [showDetailsModal, setShowDetailsModal] = useState(false);
  const [showQrOverlay, setShowQrOverlay] = useState(false);
  const [search, setSearch] = useState('');
  const [filterStatus, setFilterStatus] = useState('All');
  const [activeRouteStops, setActiveRouteStops] = useState([]);

  // Pagination State for Documents Hub
  const [currentPage, setCurrentPage] = useState(1);
  const itemsPerPage = 5;

  useEffect(() => {
    if (documents.length > 0 && !selectedDoc) {
      handleSelectDocument(documents[0]);
    } else if (selectedDoc) {
      const updatedDoc = documents.find(d => d.ini_id === selectedDoc.ini_id);
      if (updatedDoc) handleSelectDocument(updatedDoc);
    }
  }, [documents]);

  // Reset pagination when search or filter changes
  useEffect(() => {
    setCurrentPage(1);
  }, [search, filterStatus]);

  const handleSelectDocument = (doc) => {
    setSelectedDoc(doc);
    const match = processTypes.find(p => p.process_name === doc.process_name);
    if (match) {
      const stops = [];
      for (let i = 1; i <= 7; i++) {
        if (match[`stop_${i}_name`]) stops.push(match[`stop_${i}_name`]);
      }
      setActiveRouteStops(stops);
    } else {
      setActiveRouteStops([doc.current_office || 'Origin Office', doc.next_office || 'Next Unit'].filter(Boolean));
    }
  };

  const handleOpenDetails = (e, doc) => {
    e.preventDefault();
    e.stopPropagation(); 
    setActiveDetailsDoc(doc);
    setShowDetailsModal(true);
  };

  const filteredDocs = documents.filter(doc => {
    const matchesSearch = doc.title.toLowerCase().includes(search.toLowerCase()) || 
                          doc.qr_code.toLowerCase().includes(search.toLowerCase());
    const matchesStatus = filterStatus === 'All' || doc.status?.toLowerCase() === filterStatus.toLowerCase();
    return matchesSearch && matchesStatus;
  });

  // Pagination Logic
  const indexOfLastDoc = currentPage * itemsPerPage;
  const indexOfFirstDoc = indexOfLastDoc - itemsPerPage;
  const currentDocs = filteredDocs.slice(indexOfFirstDoc, indexOfLastDoc);
  const totalPages = Math.ceil(filteredDocs.length / itemsPerPage);

  const getCurrentProgressPercent = (doc, stops) => {
    if (!doc || !stops || stops.length <= 1) return 0;
    if (doc.status?.toLowerCase() === 'completed') return 100;
    
    // If halted, lock progress representation to the current station visually
    const currentIndex = stops.indexOf(doc.current_office);
    if (currentIndex === -1) return 0;
    
    return (currentIndex / (stops.length - 1)) * 100;
  };

  return (
    <div className="space-y-6 max-w-6xl mx-auto text-left animate-in fade-in duration-150">
      
      {/* TOP TRACKER BAR SECTION */}
      {selectedDoc ? (
        <div className="bg-white border border-neutral-200 rounded-2xl p-6 shadow-sm relative">
          <div className="flex justify-between items-start mb-6">
            <div>
              <h3 className="text-base font-black tracking-tight text-neutral-900">Live Document Tracking</h3>
              <p className="text-xs text-neutral-400 mt-0.5">
                Currently viewing: <span className="text-red-800 font-bold font-mono">{selectedDoc.title}</span>
              </p>
            </div>
            <span className={`px-2.5 py-0.5 rounded-full text-[10px] font-black uppercase tracking-wider ${
              selectedDoc.status?.toLowerCase() === 'completed' ? 'bg-green-50 text-green-700' : 
              selectedDoc.status?.toLowerCase() === 'action required' ? 'bg-red-100 text-red-800 border border-red-200' : 'bg-amber-50 text-amber-700'
            }`}>
              {selectedDoc.status || 'Active Path'}
            </span>
          </div>

          {/* EXPLICIT SIGNEE FEEDBACK ERROR NOTICE BOX */}
          {selectedDoc.status?.toLowerCase() === 'action required' && (
            <div className="mb-6 p-4 bg-red-50 border border-red-200 rounded-xl flex gap-3 text-xs text-red-800 font-medium">
              <AlertTriangle className="w-4 h-4 text-red-700 flex-shrink-0 mt-0.5" />
              <div>
                <p className="font-black uppercase tracking-wide">⚠️ Workflow Halted (Action Required)</p>
                <p className="text-red-600 mt-1 font-mono bg-white p-2 border rounded-lg">
                  {selectedDoc.last_action || "Returned to Originator: Corrections required before workflow clearance can proceed further."}
                </p>
              </div>
            </div>
          )}
          
          {selectedDoc.status?.toLowerCase() === 'completed' && (
            <div className="mb-6 p-4 bg-green-50 border border-green-200 rounded-xl text-xs text-green-800 font-bold uppercase tracking-wider">
              🎉 Completed Successfully: Route completely clear and signed out of final stop.
            </div>
          )}

          <div className="relative flex items-center justify-between mt-8 mb-6 px-6">
            <div className="absolute left-6 right-6 h-1 bg-neutral-100 top-3 -z-10"></div>
            <div 
              className={`absolute left-6 h-1 top-3 -z-10 transition-all duration-500 ease-in-out ${
                selectedDoc.status?.toLowerCase() === 'action required' ? 'bg-red-600' : 'bg-red-700'
              }`}
              style={{ width: `calc(${getCurrentProgressPercent(selectedDoc, activeRouteStops)}% - 12px)` }}
            ></div>

            {activeRouteStops.map((stop, index) => {
              const currentOfficeIdx = activeRouteStops.indexOf(selectedDoc.current_office);
              const isCompletedAll = selectedDoc.status?.toLowerCase() === 'completed';
              const isHalted = selectedDoc.status?.toLowerCase() === 'action required';
              
              const isCurrent = stop === selectedDoc.current_office && !isCompletedAll;
              const isPast = isCompletedAll || (currentOfficeIdx !== -1 && index <= currentOfficeIdx);
              
              return (
                <div key={index} className="text-center flex flex-col items-center flex-1">
                  <div className={`w-7 h-7 rounded-full flex items-center justify-center text-xs font-bold transition-all shadow-xs ${
                    isCurrent && isHalted ? 'bg-red-700 text-white ring-4 ring-red-100' :
                    isCurrent ? 'bg-red-700 text-white ring-4 ring-red-100 animate-pulse' :
                    isPast ? 'bg-red-800 text-white' : 'bg-neutral-200 text-neutral-500'
                  }`}>
                    {isCurrent && isHalted ? '✕' : isPast && !isCurrent ? '✓' : index + 1}
                  </div>
                  <p className={`text-[11px] font-bold mt-2 truncate max-w-[120px] ${
                    isCurrent && isHalted ? 'text-red-700 font-black' : isCurrent ? 'text-red-800 font-extrabold' : 'text-neutral-500'
                  }`}>
                    {stop}
                  </p>
                </div>
              );
            })}
          </div>

          <div className="flex justify-end pt-4 border-t border-neutral-100">
            <button onClick={() => setShowQrOverlay(true)} className="px-4 py-2 border border-neutral-200 hover:bg-neutral-50 rounded-xl text-xs font-bold text-red-800 flex items-center gap-1.5 transition-colors">
              <QrCode size={14} /> VIEW TRACKING QR
            </button>
          </div>
        </div>
      ) : (
        <div className="bg-white border border-neutral-200 rounded-2xl p-8 text-center text-neutral-400 text-xs">
          Select an active workflow from the registry below to spin trace path models.
        </div>
      )}

      <div className="bg-white border border-neutral-200 rounded-2xl shadow-sm overflow-hidden flex flex-col">
        <div className="p-6 border-b border-neutral-100 flex flex-col sm:flex-row items-stretch sm:items-center justify-between gap-4">
          <h3 className="text-base font-bold text-neutral-950">Recent Submissions</h3>
          <div className="flex flex-wrap items-center gap-2">
            <div className="flex items-center gap-1 border border-neutral-300 rounded-lg px-2 py-1.5 bg-neutral-50">
              <Filter size={14} className="text-neutral-400" />
              <select value={filterStatus} onChange={e => setFilterStatus(e.target.value)}
                      className="bg-transparent text-xs outline-none cursor-pointer font-medium text-neutral-600">
                <option value="All">All Status</option>
                <option value="Pending">Pending</option>
                <option value="In Verification">In Verification</option>
                <option value="Action Required">Action Required</option>
                <option value="Completed">Completed</option>
              </select>
            </div>

            <div className="relative">
              <Search className="absolute left-3 top-2.5 text-neutral-400" size={14} />
              <input type="text" placeholder="Search by document title..." value={search} onChange={e => setSearch(e.target.value)}
                     className="pl-9 pr-4 py-2 text-xs border border-neutral-300 rounded-lg outline-none focus:ring-1 focus:ring-red-700 bg-neutral-50" />
            </div>
            
            <button onClick={() => setShowModal(true)} className="px-4 py-2 bg-red-800 hover:bg-red-900 text-white text-xs font-medium rounded-lg flex items-center gap-1.5 transition-colors">
              <Plus size={14} /> New Document
            </button>
          </div>
        </div>

        <div className="overflow-x-auto">
          <table className="w-full text-left text-xs border-collapse">
            <thead>
              <tr className="bg-neutral-50/70 text-neutral-500 border-b border-neutral-200 uppercase font-bold text-[10px] tracking-wider">
                <th className="p-4">Document Name</th>
                <th className="p-4">Reference ID (QR)</th>
                <th className="p-4">Process Type</th>
                <th className="p-4">Est. Completion</th>
                <th className="p-4">Current Location</th>
                <th className="p-4 text-center">Action</th>
              </tr>
            </thead>
            <tbody className="divide-y divide-neutral-100 font-medium">
              {currentDocs.map((doc) => (
                <tr key={doc.ini_id} 
                    onClick={() => handleSelectDocument(doc)}
                    className={`transition-colors cursor-pointer ${selectedDoc?.ini_id === doc.ini_id ? 'bg-red-50/20' : 'hover:bg-neutral-50/80'}`}>
                  <td className="p-4">
                    <div className="flex items-center gap-2.5">
                      <FileText size={16} className="text-red-700 flex-shrink-0" />
                      <div>
                        <p className="font-bold text-neutral-900">{doc.title}</p>
                        <span className="text-[10px] text-gray-400">Modified recently</span>
                      </div>
                    </div>
                  </td>
                  <td className="p-4 font-mono font-bold text-neutral-600">{doc.qr_code}</td>
                  <td className="p-4">
                    <span className="px-2 py-0.5 bg-neutral-100 text-neutral-700 font-bold text-[9px] uppercase rounded">
                      {doc.process_name}
                    </span>
                  </td>
                  <td className="p-4 text-neutral-500">
                    {doc.edc ? new Date(doc.edc).toLocaleDateString('en-US', { month: 'short', day: '2-digit', year: 'numeric' }) : 'Processing'}
                  </td>
                  <td className="p-4">
                    <span className={`font-bold ${
                      doc.status?.toLowerCase() === 'completed' ? 'text-green-600' : 
                      doc.status?.toLowerCase() === 'action required' ? 'text-red-600' : 'text-neutral-800'
                    }`}>
                      {doc.status?.toLowerCase() === 'completed' ? 'Completed' : 
                       doc.status?.toLowerCase() === 'action required' ? 'Halted Checklist' : (doc.current_office || 'Origin Unit')}
                    </span>
                  </td>
                  <td className="p-4 text-center">
                    <button 
                      onClick={(e) => handleOpenDetails(e, doc)} 
                      className="p-2 rounded-lg hover:bg-neutral-100 text-neutral-500 mx-auto flex items-center justify-center transition-colors"
                    >
                      <MoreVertical size={16} />
                    </button>
                  </td>
                </tr>
              ))}
              {currentDocs.length === 0 && (
                <tr>
                  <td colSpan="6" className="p-8 text-center text-neutral-500 text-xs">No documents found matching your criteria.</td>
                </tr>
              )}
            </tbody>
          </table>
        </div>

        {/* Pagination Controls */}
        {totalPages > 1 && (
          <div className="p-4 border-t border-neutral-100 flex items-center justify-between bg-neutral-50/50">
            <span className="text-xs text-neutral-500">
              Showing page <span className="font-bold text-neutral-900">{currentPage}</span> of {totalPages}
            </span>
            <div className="flex gap-2">
              <button 
                onClick={() => setCurrentPage(prev => Math.max(prev - 1, 1))} 
                disabled={currentPage === 1}
                className="p-2 border rounded-lg hover:bg-white disabled:opacity-50 disabled:cursor-not-allowed transition-colors text-neutral-600"
              >
                <ChevronLeft size={16} />
              </button>
              <button 
                onClick={() => setCurrentPage(prev => Math.min(prev + 1, totalPages))} 
                disabled={currentPage === totalPages}
                className="p-2 border rounded-lg hover:bg-white disabled:opacity-50 disabled:cursor-not-allowed transition-colors text-neutral-600"
              >
                <ChevronRight size={16} />
              </button>
            </div>
          </div>
        )}
      </div>

      {showDetailsModal && activeDetailsDoc && (
        <div className="fixed inset-0 bg-neutral-950/40 backdrop-blur-xs flex items-center justify-center p-4 z-50 animate-in fade-in duration-150">
          <div className="bg-white w-full max-w-xl rounded-2xl shadow-2xl border border-neutral-200 overflow-hidden flex flex-col">
            
            <div className="p-5 border-b border-neutral-100 flex items-center justify-between bg-[#FDFBF9]">
              <h3 className="font-bold text-neutral-950 text-base">Document Tracking Details</h3>
              <button onClick={() => setShowDetailsModal(false)} className="text-neutral-400 hover:text-neutral-600 transition-colors">
                <X size={18} />
              </button>
            </div>
            
            <div className="p-6 space-y-6 overflow-y-auto max-h-[70vh]">
            {activeDetailsDoc.status?.toLowerCase() === 'action required' && (
                <div className="p-4 bg-red-50 border border-red-200 rounded-xl text-xs text-red-900">
                  <p className="font-black uppercase flex items-center gap-1.5">
                    ⚠️ Revision Notes Added by Signee:
                  </p>
                  <p className="mt-2 font-medium font-mono text-red-700 bg-white p-2.5 border border-red-200 rounded-lg shadow-2xs">
                    {activeDetailsDoc.last_action 
                      ? activeDetailsDoc.last_action.replace('Sent Back for Revision:', '').trim()
                      : 'Corrections required before workflow clearance can proceed further.'}
                  </p>
                </div>
              )}

              <div className="flex justify-between items-start gap-4">
                <div className="space-y-4 flex-1">
                  <div>
                    <span className="text-[10px] font-bold text-neutral-400 uppercase tracking-wider block">Document Title</span>
                    <h4 className="text-lg font-black text-neutral-900 leading-tight mt-0.5">{activeDetailsDoc.title}</h4>
                  </div>
                  
                  <div className="grid grid-cols-2 gap-4">
                    <div>
                      <span className="text-[10px] font-bold text-neutral-400 uppercase tracking-wider block">Reference ID</span>
                      <p className="text-xs font-black font-mono text-red-800 tracking-wider mt-0.5">{activeDetailsDoc.qr_code}</p>
                    </div>
                    <div>
                      <span className="text-[10px] font-bold text-neutral-400 uppercase tracking-wider block">Requestor</span>
                      <p className="text-xs font-bold text-neutral-700 mt-0.5">{userName} <span className="text-neutral-400 font-normal">(Faculty)</span></p>
                    </div>
                  </div>

                  <div className="grid grid-cols-2 gap-4">
                    <div>
                      <span className="text-[10px] font-bold text-neutral-400 uppercase tracking-wider block">Form Type</span>
                      <p className="text-xs font-black text-neutral-800 uppercase tracking-tight mt-0.5">{activeDetailsDoc.process_name}</p>
                    </div>
                    <div>
                      <span className="text-[10px] font-bold text-neutral-400 uppercase tracking-wider block">Estimated Completion</span>
                      <p className="text-xs font-bold text-neutral-600 mt-0.5">
                        {activeDetailsDoc.edc ? new Date(activeDetailsDoc.edc).toLocaleDateString('en-US', { month: 'long', day: '2-digit', year: 'numeric' }) : 'Calculating...'}
                      </p>
                    </div>
                  </div>

                  <div>
                    <span className="text-[10px] font-bold text-neutral-400 uppercase tracking-wider block">Current Status</span>
                    <div className="mt-1">
                      <span className={`px-3 py-1 rounded-full font-black text-[10px] uppercase border shadow-2xs inline-block ${
                        activeDetailsDoc.status?.toLowerCase() === 'completed' ? 'bg-green-50 text-green-800 border-green-200' :
                        activeDetailsDoc.status?.toLowerCase() === 'action required' ? 'bg-red-50 text-red-800 border-red-200' : 'bg-amber-50 text-amber-800 border-amber-100'
                      }`}>
                        {activeDetailsDoc.status || 'Active Path'}
                      </span>
                    </div>
                  </div>
                </div>

                <div className="bg-neutral-50 p-3 border border-neutral-200 rounded-xl flex flex-col items-center flex-shrink-0">
                  <QrCode size={80} className="text-neutral-800" />
                  <span className="text-[8px] font-black text-neutral-400 mt-1.5 uppercase tracking-widest">Tracking QR</span>
                </div>
              </div>

              <div className="pt-4 border-t border-neutral-100 text-left">
                <span className="text-[10px] font-bold text-gray-400 uppercase tracking-wider block mb-4">Submission Route Status</span>
                <div className="relative pl-6 space-y-5">
                  <div className="absolute left-[6px] top-1.5 bottom-1.5 w-0.5 bg-neutral-200"></div>
                  
                  {activeRouteStops.map((stop, i) => {
                    const currentOfficeIdx = activeRouteStops.indexOf(activeDetailsDoc?.current_office);
                    const isCompletedAll = activeDetailsDoc?.status?.toLowerCase() === 'completed';
                    const isHalted = activeDetailsDoc?.status?.toLowerCase() === 'action required';
                    
                    const isCurrent = stop === activeDetailsDoc?.current_office && !isCompletedAll;
                    const isPast = isCompletedAll || (currentOfficeIdx !== -1 && i <= currentOfficeIdx);

                    return (
                      <div key={i} className="relative flex flex-col">
                        <div className={`absolute -left-[23px] top-0.5 w-3.5 h-3.5 rounded-full border-2 bg-white flex items-center justify-center transition-all z-10 ${
                          isCurrent && isHalted ? 'border-red-600 bg-red-600 shadow-sm' :
                          isCurrent ? 'border-red-700 bg-red-700 ring-4 ring-red-100' :
                          isPast ? 'border-red-800 bg-red-800' : 'border-neutral-300'
                        }`}>
                          {isCurrent && isHalted ? '✕' : isPast && <div className="w-1 h-1 bg-white rounded-full"></div>}
                        </div>
                        <p className={`text-xs font-bold leading-none ${
                          isCurrent && isHalted ? 'text-red-700 font-black' : isCurrent ? 'text-red-800 font-black' : isPast ? 'text-neutral-800' : 'text-neutral-400'
                        }`}>
                          {stop}
                        </p>
                        <span className="text-[10px] text-gray-400 mt-1 font-medium">
                          {isCurrent && isHalted ? '🛑 Route Halted Here for Revision Notes' : 
                           isCurrent ? 'Under Active Review' : isPast ? 'Completed signature verification step' : 'Awaiting structural arrival queue'}
                        </span>
                      </div>
                    );
                  })}
                </div>
              </div>
            </div>

            <div className="p-4 border-t border-neutral-100 bg-neutral-50/50 flex justify-between items-center">
              <div className="flex gap-2">
                <button type="button" className="px-4 py-2 border border-neutral-200 bg-white hover:bg-neutral-50 rounded-xl font-bold text-xs text-neutral-700 flex items-center gap-1.5 transition-colors">
                  <Download size={14} /> Download Copy
                </button>
                <button type="button" className="px-4 py-2 bg-red-800 hover:bg-red-900 rounded-xl font-bold text-xs text-white flex items-center gap-1.5 shadow-sm transition-colors">
                  <Printer size={14} /> Print Label
                </button>
              </div>
              <button onClick={() => setShowDetailsModal(false)} className="px-4 py-2 border rounded-xl text-xs font-bold text-gray-500 hover:bg-neutral-100 transition-colors">
                Close
              </button>
            </div>

          </div>
        </div>
      )}

      {showQrOverlay && selectedDoc && (
        <div className="fixed inset-0 bg-neutral-950/50 backdrop-blur-xs flex items-center justify-center p-4 z-50 animate-in fade-in duration-100">
          <div className="bg-white rounded-2xl p-6 text-center max-w-sm w-full border shadow-2xl space-y-4">
            <div className="w-12 h-12 rounded-full bg-red-50 text-red-800 flex items-center justify-center mx-auto text-xl">📋</div>
            <div>
              <h3 className="text-base font-bold text-neutral-900">{selectedDoc.title}</h3>
              <p className="text-xs text-neutral-400 mt-1">Scan this token code to capture current tracking coordinates.</p>
            </div>
            <div className="bg-neutral-50 p-6 border rounded-xl flex flex-col items-center justify-center border-dashed">
              <QrCode size={160} className="text-neutral-800" strokeWidth={1.5} />
              <code className="text-[10px] mt-3 font-mono bg-white px-2 py-0.5 border rounded text-neutral-600 tracking-wider font-bold">
                {selectedDoc.qr_code}
              </code>
            </div>
            <button onClick={() => setShowQrOverlay(false)} className="w-full py-2 bg-neutral-900 hover:bg-neutral-800 text-white font-medium text-xs rounded-lg transition-colors">
              Dismiss Viewer
            </button>
          </div>
        </div>
      )}

    </div>
  );
}