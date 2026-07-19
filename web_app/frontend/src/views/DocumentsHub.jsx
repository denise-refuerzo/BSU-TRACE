import React, { useState, useEffect } from 'react';
import { MoreVertical, Search, Filter, Plus, X, QrCode, FileText, Download, AlertTriangle, ChevronLeft, ChevronRight, MessageSquare } from 'lucide-react';
import { QRCodeSVG } from 'qrcode.react';

export default function DocumentsHub({ 
  userId, 
  documents, 
  fetchDashboardLedger, 
  setShowModal, 
  processTypes 
}) {
  const [selectedDoc, setSelectedDoc] = useState(null);
  const [activeDetailsDoc, setActiveDetailsDoc] = useState(null); 
  const [showDetailsModal, setShowDetailsModal] = useState(false);
  const [showQrOverlay, setShowQrOverlay] = useState(false);
  const [search, setSearch] = useState('');
  const [filterStatus, setFilterStatus] = useState('All');
  const [activeRouteStops, setActiveRouteStops] = useState([]);

  const [currentPage, setCurrentPage] = useState(1);
  const itemsPerPage = 5;

  // ROBUST ADHOC CHECKER: Covers PostgreSQL booleans, numeric bits, and string "true"
  const isAdhocLog = (l) => l && (l.is_adhoc === true || String(l.is_adhoc) === 'true' || l.is_adhoc === 1);

  useEffect(() => {
    if (documents.length > 0 && !selectedDoc) {
      handleSelectDocument(documents[0]);
    } else if (selectedDoc) {
      const updatedDoc = documents.find(d => d.ini_id === selectedDoc.ini_id);
      if (updatedDoc) handleSelectDocument(updatedDoc);
    }
  }, [documents]);

  useEffect(() => {
    setCurrentPage(1);
  }, [search, filterStatus]);

  const handleSelectDocument = (doc) => {
    setSelectedDoc(doc);
    const match = processTypes.find(p => p.process_name === doc.process_name);
    if (match) {
      const stops = [];
      for (let i = 1; i <= 7; i++) {
        let stopName = match[`stop_${i}_name`];
        
        // Preserve Dynamic Origin Office Layout mapping
        if (stopName === 'ORIGINATING_COLLEGE_DYNAMIC') {
          const firstNormalLog = doc.history_logs?.find(l => !isAdhocLog(l));
          stopName = firstNormalLog?.office_name || doc.current_office || 'Origin Office';
        }
        if (stopName) stops.push(stopName);
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

  const indexOfLastDoc = currentPage * itemsPerPage;
  const indexOfFirstDoc = indexOfLastDoc - itemsPerPage;
  const currentDocs = filteredDocs.slice(indexOfFirstDoc, indexOfLastDoc);
  const totalPages = Math.ceil(filteredDocs.length / itemsPerPage);

  const getRenderStops = (doc, baseStops) => {
    if (!doc || !baseStops) return [];
    const historyLogs = doc.history_logs || [];
    
    let resultStops = [];
    let normalIndex = 0;

    // Loop through the actual timeline to inject ad-hoc nodes exactly where they happened
    for (let i = 0; i < historyLogs.length; i++) {
      const log = historyLogs[i];
      if (isAdhocLog(log)) {
        resultStops.push({ name: log.office_name, isAdhocNode: true, logRef: log });
      } else {
        if (normalIndex < baseStops.length) {
          resultStops.push({ name: baseStops[normalIndex], isAdhocNode: false, logRef: log });
          normalIndex++;
        }
      }
    }

    // Append remaining untouched route stops
    while (normalIndex < baseStops.length) {
      resultStops.push({ name: baseStops[normalIndex], isAdhocNode: false, logRef: null });
      normalIndex++;
    }
    return resultStops;
  };

  const getCurrentProgressPercent = (doc, renderedNodes) => {
    if (!doc || !renderedNodes || renderedNodes.length <= 1) return 0;
    if (doc.status?.toLowerCase() === 'completed') return 100;
    
    // Find the index of the furthest reached step
    let activeIndex = 0;
    for (let i = 0; i < renderedNodes.length; i++) {
       if (renderedNodes[i].logRef) activeIndex = i;
    }
    
    return (Math.min(activeIndex, renderedNodes.length - 1) / (renderedNodes.length - 1)) * 100;
  };

  useEffect(() => {
    const pendingRedirectId = localStorage.getItem('redirect_target_doc_id');
    if (pendingRedirectId && documents.length > 0) {
      const targetDoc = documents.find(d => d.ini_id === parseInt(pendingRedirectId));
      if (targetDoc) {
        handleSelectDocument(targetDoc);
        setActiveDetailsDoc(targetDoc);
        setShowDetailsModal(true);
      }
      localStorage.removeItem('redirect_target_doc_id');
    }
  }, [documents]);

  const renderTimelineNodes = getRenderStops(selectedDoc, activeRouteStops);

  return (
    <div className="space-y-6 max-w-6xl mx-auto text-left animate-in fade-in duration-150">
      
      {selectedDoc ? (
        <div className="bg-white border border-neutral-200 rounded-2xl p-6 shadow-sm relative">
          <div className="flex justify-between items-start mb-6">
            <div>
              <h3 className="text-base font-black tracking-tight text-neutral-900">Live Document Tracking</h3>
              <p className="text-xs text-neutral-400 mt-0.5">
                Currently viewing: <span className="text-red-800 font-bold font-mono">{selectedDoc.title}</span>
              </p>
            </div>
            <div className="flex flex-col items-end gap-1">
              <span className={`px-2.5 py-0.5 rounded-full text-[10px] font-black uppercase tracking-wider ${
                selectedDoc.status?.toLowerCase() === 'completed' ? 'bg-green-50 text-green-700' : 
                selectedDoc.status?.toLowerCase() === 'action required' ? 'bg-red-100 text-red-800 border border-red-200' : 'bg-amber-50 text-amber-700'
              }`}>
                {selectedDoc.status || 'Active Path'}
              </span>
              {selectedDoc.history_logs?.some(l => isAdhocLog(l) && !l.time_out) && (
                <span className="px-2 py-0.5 bg-purple-100 border border-purple-200 text-purple-800 rounded-md text-[9px] font-black uppercase tracking-wide">
                  📍 AD-HOC DETOUR ACTIVE
                </span>
              )}
            </div>
          </div>

          {selectedDoc.history_logs?.some(l => isAdhocLog(l) && !l.time_out) && (
            <div className="mb-6 p-4 bg-purple-50/60 border border-purple-200 rounded-xl text-xs text-purple-800 font-medium flex items-center gap-2">
              <span className="text-purple-600 text-sm">⚡</span>
              <span>This document has been temporarily routed to <strong className="text-purple-900 underline">{selectedDoc.current_office}</strong> for an unscheduled ad-hoc verification detour. Standard routing pipeline will resume once cleared.</span>
            </div>
          )}

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
                selectedDoc.history_logs?.some(l => isAdhocLog(l) && !l.time_out) ? 'bg-purple-600' : 'bg-red-700'
              }`}
              style={{ width: `calc(${getCurrentProgressPercent(selectedDoc, renderTimelineNodes.map(n => n.name))}% - 12px)` }}
            ></div>

            {renderTimelineNodes.map((node, index) => {
              const isCompletedAll = selectedDoc?.status?.toLowerCase() === 'completed';
              const isHalted = selectedDoc?.status?.toLowerCase() === 'action required';
              
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
                    isCurrent && isHalted ? 'bg-red-700 text-white ring-4 ring-red-100' :
                    isCurrent ? 'bg-red-700 text-white ring-4 ring-red-100 animate-pulse' :
                    node.isAdhocNode ? 'bg-purple-200 text-purple-700' :
                    isPast ? 'bg-red-800 text-white' : 'bg-neutral-200 text-neutral-500'
                  }`}>
                    {isCurrent && isHalted ? '✕' : isPast && !isCurrent ? '✓' : node.isAdhocNode ? '⚡' : index - renderTimelineNodes.slice(0, index).filter(n => n.isAdhocNode).length + 1}
                  </div>
                  <p className={`text-[11px] font-bold mt-2 truncate max-w-[120px] ${
                    isCurrent && node.isAdhocNode ? 'text-purple-700 font-extrabold' : isCurrent ? 'text-red-800 font-extrabold' : 'text-neutral-500'
                  }`}>
                    {node.name}
                  </p>
                  <span className="text-[9px] text-neutral-400 font-medium block mt-0.5 leading-tight">
                    {isCurrent && node.isAdhocNode ? 'Currently in verification' :
                    isCurrent && isHalted ? 'Halted' : 
                    isCurrent ? 'Under Review' : 
                    isPast ? 'Cleared' : 'Awaiting'}
                  </span>
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

      {/* RECENT SUBMISSIONS TABLE */}
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
                      <span className="text-[10px] font-bold text-neutral-400 uppercase tracking-wider block">Date Created</span>
                      <p className="text-xs font-bold text-neutral-700 mt-0.5">
                        {activeDetailsDoc.created_at ? new Date(activeDetailsDoc.created_at).toLocaleDateString('en-US', { month: 'short', day: '2-digit', year: 'numeric' }) + ', ' + new Date(activeDetailsDoc.created_at).toLocaleTimeString('en-US', { hour: '2-digit', minute: '2-digit' }) : 'N/A'}
                      </p>
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
                  <QRCodeSVG 
                    value={activeDetailsDoc.qr_code} 
                    size={80} 
                    level={"M"}
                    fgColor={"#171717"}
                  />
                  <span className="text-[8px] font-black text-neutral-400 mt-1.5 uppercase tracking-widest">Tracking QR</span>
                </div>
              </div>

              <div className="pt-4 border-t border-neutral-100 text-left">
                <span className="text-[10px] font-bold text-gray-400 uppercase tracking-wider block mb-4">Submission Route Status</span>
                
                <div className="relative pl-6 space-y-5">
                  <div className="absolute left-[6px] top-1.5 bottom-1.5 w-0.5 bg-neutral-200"></div>
                  
                  {(() => {
const detailsStopsNodes = getRenderStops(activeDetailsDoc, activeRouteStops);
                    
return detailsStopsNodes.map((node, i) => {
  const isCompletedAll = activeDetailsDoc?.status?.toLowerCase() === 'completed';
  const isHalted = activeDetailsDoc?.status?.toLowerCase() === 'action required';
  
  let isCurrent = false;
  let isPast = false;

  if (isCompletedAll) {
    isPast = true;
  } else if (node.logRef) {
    if (!node.logRef.time_out) isCurrent = true;
    else isPast = true;
  }

  const stopLog = node.logRef;
  const formatTime = (ts) => ts ? new Date(ts).toLocaleTimeString('en-US', { hour: '2-digit', minute: '2-digit' }) : null;
  const timeIn = formatTime(stopLog?.time_in);
  const timeOut = formatTime(stopLog?.time_out);

                      return (
                        <div key={i} className="relative flex flex-col">
                          <div className={`absolute -left-[23px] top-0.5 w-3.5 h-3.5 rounded-full border-2 bg-white flex items-center justify-center transition-all z-10 ${
                            isCurrent && node.isAdhocNode ? 'border-purple-600 bg-purple-600 ring-4 ring-purple-100' :
                            isCurrent && isHalted ? 'border-red-600 bg-red-600 shadow-sm' :
                            isCurrent ? 'border-red-700 bg-red-700 ring-4 ring-red-100' :
                            node.isAdhocNode ? 'border-purple-300 bg-purple-50' :
                            isPast ? 'border-red-800 bg-red-800' : 'border-neutral-300'
                          }`}>
                            {isCurrent && isHalted ? '✕' : isCurrent && node.isAdhocNode ? '⚡' : isPast && <div className="w-1 h-1 bg-white rounded-full"></div>}
                          </div>
                          
                          <div className="flex justify-between items-start gap-4">
                            <div>
                              <p className={`text-xs font-bold leading-none ${
                                isCurrent && node.isAdhocNode ? 'text-purple-700 font-black' : isCurrent ? 'text-red-800 font-black' : isPast ? 'text-neutral-800' : 'text-neutral-400'
                              }`}>
                                {node.name}
                              </p>
                              <span className="text-[10px] text-gray-400 mt-1.5 font-medium block">
                                {isCurrent && node.isAdhocNode ? '📍 Currently in verification (Ad-Hoc Detour)' :
                                isCurrent && isHalted ? '🛑 Route Halted Here for Revision Notes' : 
                                isCurrent ? 'Under Active Review' : 
                                isPast ? 'Completed signature verification step' : 
                                'Awaiting structural arrival queue'}
                              </span>
                            </div>

                            {(timeIn || timeOut || isCurrent) && (
                              <div className="text-right flex flex-col items-end gap-1 flex-shrink-0">
                                {timeIn ? (
                                  <span className="text-[9px] font-mono font-bold text-neutral-600 bg-neutral-100/80 border border-neutral-200 px-1.5 py-0.5 rounded shadow-xs uppercase">
                                    IN: {timeIn}
                                  </span>
                                ) : (
                                  isCurrent && <span className="text-[9px] font-mono font-bold text-amber-700 bg-amber-50 border border-amber-200 px-1.5 py-0.5 rounded shadow-xs uppercase tracking-tight">Awaiting Scan In</span>
                                )}
                                
                                {timeOut && (
                                  <span className="text-[9px] font-mono font-bold text-neutral-600 bg-neutral-100/80 border border-neutral-200 px-1.5 py-0.5 rounded shadow-xs uppercase">
                                    OUT: {timeOut}
                                  </span>
                                )}
                              </div>
                            )}
                          </div>
                        </div>
                      );
                    });
                  })()}
                </div>
              </div>
            </div>

            <div className="p-4 border-t border-neutral-100 bg-neutral-50/50 flex justify-between items-center">
              <div className="flex gap-2">
              <button 
                  type="button" 
                    onClick={() => {
                      localStorage.setItem('redirect_target_doc_id', String(activeDetailsDoc.ini_id));
                      window.location.reload(); 
                    }}
                    className="px-4 py-2 border border-red-200 bg-red-50 hover:bg-red-100 rounded-xl font-bold text-xs text-red-800 flex items-center gap-1.5 transition-colors"
                  >
                  <MessageSquare size={18} /> Chat regarding this file
              </button>
                <button type="button" className="px-4 py-2 border border-neutral-200 bg-white hover:bg-neutral-50 rounded-xl font-bold text-xs text-neutral-700 flex items-center gap-1.5 transition-colors">
                  <Download size={14} /> Download QR Code
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
              <QRCodeSVG 
                value={selectedDoc.qr_code} 
                size={160} 
                level={"H"}
                includeMargin={true}
                fgColor={"#171717"}
              />
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