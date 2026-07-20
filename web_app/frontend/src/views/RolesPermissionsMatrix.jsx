import React, { useState, useEffect } from 'react';
import { useNavigate } from 'react-router-dom';
import Swal from 'sweetalert2'; // 🚨 Handles explicit confirmation validations
import { fetchWithAuth } from '../api';

export default function RolesPermissionsMatrix() {
  const navigate = useNavigate();
  const adminName = localStorage.getItem('user') || 'Admin User';
  const [activeTab, setActiveTab] = useState('routes'); // 'routes' | 'rbac' | 'infrastructure'

  // --- CATALOG INDICES STATES ---
  const [offices, setOffices] = useState([]);
  const [processTypes, setProcessTypes] = useState([]);
  const [infraSummary, setInfraSummary] = useState({ departments: [], roleStatistics: [], officeCapacity: [] });

  // --- INTERACTIVE VISUALIZER FORM STATES ---
  const [newProcessName, setNewProcessName] = useState('');
  const [selectedStops, setSelectedStops] = useState([null, null]); // Instantiated with minimum 2 rows configuration blocks

  // --- TRACKING METADATA CONTROLLER ---
  // Tracks if the form is in "Create Mode" (null) or "Edit Mode" (populated with database key pointers)
  const [formMeta, setFormMeta] = useState({ currentProcessId: null, currentRouteId: null, is_active: true });

  // --- CAMPUS STRUCTURES FORM STATES ---
  const [newDeptName, setNewDeptName] = useState('');
  const [newOfficeName, setNewOfficeName] = useState('');

  useEffect(() => {
    fetchBaselineCatalogs();
  }, [activeTab]);

  const fetchBaselineCatalogs = async () => {
    try {
      const officeRes = await fetchWithAuth('http://localhost:5000/api/offices');
      const officeData = await officeRes.json();
      if (officeRes.ok) setOffices(officeData);

      const processRes = await fetchWithAuth('http://localhost:5000/api/process-types');
      const processData = await processRes.json();
      if (processRes.ok) setProcessTypes(processData);

      const summaryRes = await fetchWithAuth('http://localhost:5000/api/admin/infrastructure-summary');
      const summaryData = await summaryRes.json();
      if (summaryRes.ok) setInfraSummary(summaryData);
    } catch (err) {
      console.error("Error updating configuration indices matrices lines:", err);
    }
  };

  // --- DYNAMIC VISUALIZER STOP HANDLING ---
  const handleAddStopSlot = () => {
    if (selectedStops.length >= 7) {
      Swal.fire('Limit Reached', 'System routing columns limit workflows to a maximum constraint layer of 7 stops.', 'warning');
      return;
    }
    setSelectedStops([...selectedStops, null]);
  };

  const handleRemoveTrailingStopSlot = () => {
    if (selectedStops.length <= 2) {
      Swal.fire('Constraint Conflict', 'Relational database definitions dictate that process templates require a minimum of 2 stops.', 'warning');
      return;
    }
    const filtered = [...selectedStops];
    filtered.pop();
    setSelectedStops(filtered);
  };

  const handleStopSelectorChange = (index, value) => {
    const updated = [...selectedStops];
    const parsedValue = value ? parseInt(value) : null;
    updated[index] = parsedValue;

    // Automated Chain-Limiting Guard: If an admin clears a middle step out, clear all downstream choices
    if (parsedValue === null) {
      for (let i = index; i < updated.length; i++) {
        updated[i] = null;
      }
    }
    setSelectedStops(updated);
  };

  // Resets the workflow form back to creation defaults
  const resetWorkflowForm = () => {
    setNewProcessName('');
    setSelectedStops([null, null]);
    setFormMeta({ currentProcessId: null, currentRouteId: null, is_active: true });
  };

  // --- PROCESS TEMPLATE ROUTING TRANSACTION SUBMISSION ---
  const handleProcessFormSubmit = async (e) => {
    e.preventDefault();
    const processedStopsPayload = selectedStops.filter(s => s !== null);

    if (processedStopsPayload.length < 2) {
      Swal.fire('Configuration Rejection', 'Invalid configuration path: A minimum sequence of 2 office locations must be assigned.', 'error');
      return;
    }

    const isEditing = formMeta.currentProcessId !== null;
    const targetUrl = isEditing 
      ? `http://localhost:5000/api/process-types/${formMeta.currentProcessId}`
      : 'http://localhost:5000/api/process-types';
    const targetMethod = isEditing ? 'PUT' : 'POST';

    Swal.fire({
      title: isEditing ? 'Save Workflow Changes?' : 'Compile Workflow Template?',
      text: isEditing 
        ? `Are you sure you want to update the sequence layers for "${newProcessName}"? This adjusts downstream workflow processing queues immediately.`
        : `Are you sure you want to index the "${newProcessName}" document routing sequence? Active tracking modules will begin evaluating this layout immediately.`,
      icon: 'question',
      showCancelButton: true,
      confirmButtonColor: '#800000',
      cancelButtonColor: '#4b5563',
      confirmButtonText: isEditing ? 'Yes, Save Overrides' : 'Yes, Deploy Template'
    }).then(async (result) => {
      if (result.isConfirmed) {
        try {
          const response = await fetchWithAuth(targetUrl, {
            method: targetMethod,
            headers: { 'Content-Type': 'application/json' },
            body: JSON.stringify({ 
              processName: newProcessName, 
              stops: processedStopsPayload,
              routeId: formMeta.currentRouteId,
              isActive: formMeta.is_active
            })
          });
          const data = await response.json();

          if (!response.ok) throw new Error(data.error || 'Pipeline operation sequence crashed.');

          Swal.fire('Success!', data.message, 'success');
          resetWorkflowForm();
          fetchBaselineCatalogs();
        } catch (err) {
          Swal.fire('Operation Refused', err.message, 'error');
        }
      }
    });
  };

  // --- LOCATION INFRASTRUCTURE SUBMISSIONS ---
  const handleCreateDepartment = async (e) => {
    e.preventDefault();
    try {
      const response = await fetchWithAuth('http://localhost:5000/api/departments', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ departmentName: newDeptName })
      });
      const data = await response.json();
      if (!response.ok) throw new Error(data.error);

      Swal.fire('Registered!', data.message, 'success');
      setNewDeptName('');
      fetchBaselineCatalogs();
    } catch (err) {
      Swal.fire('Operation Blocked', err.message, 'error');
    }
  };

  const handleCreateOffice = async (e) => {
    e.preventDefault();
    try {
      const response = await fetchWithAuth('http://localhost:5000/api/offices', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ officeName: newOfficeName })
      });
      const data = await response.json();
      if (!response.ok) throw new Error(data.error);

      Swal.fire('Registered!', data.message, 'success');
      setNewOfficeName('');
      fetchBaselineCatalogs();
    } catch (err) {
      Swal.fire('Operation Blocked', err.message, 'error');
    }
  };

  return (
    <div className="flex h-screen w-screen bg-[#FDFBF9] overflow-hidden text-neutral-800 font-sans">
      {/* Fixed Admin Sidebar Menu */}
      <div className="w-64 bg-[#2D1F1E] text-neutral-300 flex flex-col justify-between p-4 shrink-0">
        <div>
          <div className="flex items-center gap-3 border-b border-neutral-700 pb-4 mb-6">
            <div className="bg-red-700 p-2 rounded-lg text-white text-xl">🎓</div>
            <div>
              <h1 className="font-bold text-white text-sm leading-none">BSU Portal</h1>
              <span className="text-[10px] text-neutral-400 uppercase tracking-widest">Admin Console</span>
            </div>
          </div>
          <nav className="space-y-1 text-sm text-left">
            <button type="button" onClick={() => navigate('/admin/dashboard')} className="w-full flex items-center gap-3 px-3 py-2.5 rounded-lg text-neutral-400 hover:bg-neutral-800 hover:text-white transition-colors">📊 Dashboard</button>
            <button type="button" onClick={() => navigate('/admin/accounts')} className="w-full flex items-center gap-3 px-3 py-2.5 rounded-lg text-neutral-400 hover:bg-neutral-800 hover:text-white transition-colors">👥 Accounts</button>
            <button type="button" className="w-full flex items-center gap-3 px-3 py-2.5 rounded-lg bg-neutral-800 text-white font-medium">🛡️ Roles & Matrix</button>
            <button type="button" onClick={() => navigate('/admin/analytics')} className={`w-full flex items-center gap-3 px-3 py-2.5 rounded-lg transition-colors ${ window.location.pathname === '/admin/analytics' ? 'bg-neutral-800 text-white font-medium' : 'text-neutral-400 hover:bg-neutral-800 hover:text-white' }`}> 📈 Operational Analytics </button>
          </nav>
        </div>
        <button type="button" onClick={() => { localStorage.clear(); navigate('/login'); }} className="flex items-center gap-3 px-3 py-2.5 text-sm text-neutral-400 hover:text-red-400 rounded-lg transition-colors">
          🚪 Logout
        </button>
      </div>

      {/* Main Workspace Sheet */}
      <div className="flex-1 flex flex-col overflow-y-auto">
        <header className="h-16 border-b border-neutral-200/80 bg-white px-8 flex items-center justify-between shadow-xs shrink-0">
          <div className="text-neutral-900 font-black text-sm uppercase tracking-wider font-mono">Roles & Permissions Matrix Dashboard Node</div>
          <div className="flex items-center gap-2 border-l pl-4 border-neutral-200 text-xs">
            <span className="font-bold text-neutral-900">{adminName}</span>
            <span className="bg-neutral-100 px-2 py-0.5 rounded text-[10px] uppercase text-neutral-500 font-bold">ICT Root</span>
          </div>
        </header>

        <main className="p-8 max-w-5xl w-full mx-auto space-y-6">
          <div className="text-left">
            <h2 className="text-2xl font-black tracking-tight text-neutral-900">System Permissions & Workflow Engineering</h2>
            <p className="text-xs text-gray-500">Configure dynamic tracking routes, security matrix parameters, and registration building locations.</p>
          </div>

          {/* TAB CONTROL SELECTOR ROW */}
          <div className="flex border-b border-neutral-200 gap-2">
            <button type="button" onClick={() => setActiveTab('routes')} className={`px-4 py-2 text-xs font-bold uppercase tracking-wider border-b-2 transition-all ${activeTab === 'routes' ? 'border-red-800 text-red-800' : 'border-transparent text-gray-400 hover:text-neutral-700'}`}>🗺️ Interactive Visualizer</button>
            <button type="button" onClick={() => setActiveTab('infrastructure')} className={`px-4 py-2 text-xs font-bold uppercase tracking-wider border-b-2 transition-all ${activeTab === 'infrastructure' ? 'border-red-800 text-red-800' : 'border-transparent text-gray-400 hover:text-neutral-700'}`}>🏢 Campus Infrastructure</button>
          </div>

          {/* TAB PANEL 1: WORKFLOW ENGINEERING DECK */}
          {activeTab === 'routes' && (
            <div className="grid grid-cols-1 lg:grid-cols-3 gap-6 items-start">
              <div className="lg:col-span-2 bg-white border border-neutral-200 rounded-2xl p-6 shadow-sm space-y-4 text-left">
                <div className="flex justify-between items-center">
                  <div>
                    <h3 className="text-sm font-bold uppercase tracking-wider text-red-800">
                      {formMeta.currentProcessId ? "🔧 Update Workflow Blueprint" : "Compile New Workflow Template"}
                    </h3>
                    <p className="text-[11px] text-gray-400 mt-0.5">Design linear multi-stop routing pipelines mapping across campus destinations.</p>
                  </div>
                  {formMeta.currentProcessId && (
                    <button 
                      type="button" 
                      onClick={resetWorkflowForm}
                      className="text-[10px] bg-neutral-900 text-white font-bold px-2 py-1 rounded hover:bg-red-800 transition-all cursor-pointer"
                    >
                      Reset Form Mode
                    </button>
                  )}
                </div>

                <form onSubmit={handleProcessFormSubmit} className="space-y-4 text-xs font-bold">
                  <div>
                    <label className="block text-[10px] uppercase text-gray-500 mb-1">Process Action Name (e.g. Equipment borrowing Request)</label>
                    <input type="text" required value={newProcessName} onChange={e => setNewProcessName(e.target.value)} placeholder="Enter process title descriptive tag..." className="w-full border border-neutral-300 bg-[#FDFBF9] rounded-lg px-3 py-2 text-sm focus:ring-1 focus:ring-red-700 outline-none" />
                  </div>

                  <div className="space-y-3">
                    <label className="block text-[10px] uppercase text-gray-500">Pipeline Tracking Progress Sequence Stops Matrix</label>
                    
                    {selectedStops.map((stop, index) => (
                      <div key={index} className="flex items-center gap-3 bg-neutral-50 p-2 border rounded-xl animate-in slide-in-from-top-2 duration-100">
                        <span className="w-6 h-6 rounded-full bg-neutral-900 text-white flex items-center justify-center font-mono font-bold text-[10px] shadow-xs">{index + 1}</span>
                        <select
                          required={index < 2}
                          value={stop || ''}
                          onChange={e => handleStopSelectorChange(index, e.target.value)}
                          className="flex-1 bg-white border rounded-lg p-2 text-xs outline-none cursor-pointer"
                        >
                          <option value="">{index < 2 ? `-- Select Required Target Stop Location (Required) --` : `-- Select Optional Downstream Station (Optional Null Loop) --`}</option>
                          {offices.map(o => (
                            <option key={o.id} value={o.id}>🏬 {o.name}</option>
                          ))}
                        </select>
                      </div>
                    ))}
                  </div>

                  <div className="flex gap-2">
                    <button type="button" onClick={handleAddStopSlot} className="px-3 py-2 border bg-white border-neutral-300 rounded-lg hover:bg-neutral-50 transition-all text-[11px] font-bold cursor-pointer">➕ Add Downstream Step</button>
                    <button type="button" onClick={handleRemoveTrailingStopSlot} className="px-3 py-2 border bg-white border-neutral-300 rounded-lg text-red-700 hover:bg-red-50 transition-all text-[11px] font-bold cursor-pointer">✕ Delete Last Step</button>
                  </div>

                  {/* 🔒 SOFT SUSPENSION OVERVIEW FOR WORKFLOW BLUEPRINTS */}
                  {formMeta.currentProcessId && (
                    <div className="bg-neutral-50 p-3.5 rounded-xl border border-neutral-200 flex items-center justify-between animate-in fade-in duration-200">
                      <div>
                        <label className="block text-xs font-bold text-neutral-700 select-none">Template Operational Status</label>
                        <p className="text-[10px] text-gray-400 font-normal mt-0.5">Archiving hides this workflow option from faculty dashboards instantly without breaking log integrity profiles.</p>
                      </div>
                      <button
                        type="button"
                        onClick={() => setFormMeta({ ...formMeta, is_active: !formMeta.is_active })}
                        className={`px-3 py-1 rounded-lg text-[10px] font-black uppercase transition-all shadow-xs cursor-pointer ${
                          formMeta.is_active 
                            ? 'bg-emerald-100 text-emerald-800 border border-emerald-300' 
                            : 'bg-red-100 text-red-800 border border-red-200'
                        }`}
                      >
                        {formMeta.is_active ? "🟢 Template Active" : "🔴 Archived / Hidden"}
                      </button>
                    </div>
                  )}

                  <div className="flex justify-end pt-4 border-t">
                    <button type="submit" className="px-5 py-2.5 bg-red-800 text-white text-xs tracking-wider uppercase font-black hover:bg-red-900 rounded-xl shadow-xs transition-all cursor-pointer">
                      {formMeta.currentProcessId ? "Save Structural Changes" : "Deploy Tracking Template"}
                    </button>
                  </div>
                </form>
              </div>

              {/* Dynamic Interactive Blueprints Directory List Sideboard Card */}
              <div className="bg-[#2D1F1E] text-neutral-300 p-5 rounded-2xl shadow-sm space-y-4 text-left">
                <div className="flex justify-between items-center">
                  <h4 className="text-xs font-bold tracking-wider text-white uppercase flex items-center gap-1">📋 Pipeline Blueprints ({processTypes.length})</h4>
                  {formMeta.currentProcessId && (
                    <span className="text-[9px] bg-red-600/30 text-red-300 font-mono font-bold px-2 py-0.5 rounded border border-red-500/20 animate-pulse">Editing Mode</span>
                  )}
                </div>

                <div className="space-y-2 text-[11px] max-h-[380px] overflow-y-auto custom-scrollbar">
                  {processTypes.map((p) => {
                    const stopsArray = [p.stop_1, p.stop_2, p.stop_3, p.stop_4, p.stop_5, p.stop_6, p.stop_7].filter(Boolean);
                    const isSelectedCard = formMeta.currentProcessId === p.p_id;

                    return (
                      <div 
                        key={p.p_id} 
                        onClick={() => {
                          setNewProcessName(p.process_name);
                          setSelectedStops(stopsArray);
                          setFormMeta({ currentProcessId: p.p_id, currentRouteId: p.r_id, is_active: p.is_active ?? true });
                        }}
                        className={`p-2.5 rounded-lg border transition-all ${
                          isSelectedCard 
                            ? 'bg-red-900/30 border-red-400 shadow-md ring-1 ring-red-400/30'
                            : p.is_active === false 
                              ? 'bg-neutral-800/40 opacity-40 border-neutral-700/30 italic' 
                              : 'bg-white/5 border-neutral-700/50 hover:border-red-400 cursor-pointer'
                        }`}
                      >
                        <div className="flex justify-between items-center">
                          <p className="font-bold text-white text-xs">{p.process_name}</p>
                          {p.is_active === false && <span className="text-[9px] font-mono text-red-400 font-bold uppercase">[Archived]</span>}
                        </div>
                        <div className="text-[10px] text-neutral-400 font-mono tracking-tight leading-normal space-y-0.5 mt-1">
                          <p>{[p.stop_1_name, p.stop_2_name, p.stop_3_name, p.stop_4_name, p.stop_5_name, p.stop_6_name, p.stop_7_name].filter(Boolean).join(' ➔ ')}</p>
                          <p className="text-neutral-500 text-[9px] mt-1.5 italic">➔ Click template blueprint to edit path columns</p>
                        </div>
                      </div>
                    );
                  })}
                </div>
              </div>
            </div>
          )}

          {/* TAB PANEL 3: PHYSICAL LOCATIONS BUILDING MODULE */}
          {activeTab === 'infrastructure' && (
            <div className="space-y-6 text-left">
              <div className="grid grid-cols-1 md:grid-cols-2 gap-6">
                <div className="bg-white border border-neutral-200 rounded-2xl p-5 shadow-sm space-y-3">
                  <div>
                    <h4 className="text-xs font-bold text-red-800 uppercase tracking-wider">Register New Campus Department Structure</h4>
                    <p className="text-[10px] text-gray-400 mt-0.5">Expands available lookups inside user account creation forms option blocks.</p>
                  </div>
                  <form onSubmit={handleCreateDepartment} className="flex gap-2 text-xs font-bold">
                    <input type="text" required value={newDeptName} onChange={e => setNewDeptName(e.target.value)} placeholder="e.g. CICS, CABEIHM" className="flex-1 border rounded-lg px-3 py-2 outline-none focus:ring-1 focus:ring-red-700 bg-[#FDFBF9]" />
                    <button type="submit" className="px-4 py-2 bg-neutral-900 hover:bg-neutral-950 text-white text-[11px] font-black rounded-lg uppercase tracking-wide cursor-pointer">Add Dept</button>
                  </form>
                </div>

                <div className="bg-white border border-neutral-200 rounded-2xl p-5 shadow-sm space-y-3">
                  <div>
                    <h4 className="text-xs font-bold text-red-800 uppercase tracking-wider">Register New Campus Branch Office Station Node</h4>
                    <p className="text-[10px] text-gray-400 mt-0.5">Populates available nodes inside both user assignment forms and step visuals.</p>
                  </div>
                  <form onSubmit={handleCreateOffice} className="flex gap-2 text-xs font-bold">
                    <input type="text" required value={newOfficeName} onChange={e => setNewOfficeName(e.target.value)} placeholder="e.g. Guidance Office, Cashier" className="flex-1 border rounded-lg px-3 py-2 outline-none focus:ring-1 focus:ring-red-700 bg-[#FDFBF9]" />
                    <button type="submit" className="px-4 py-2 bg-neutral-900 hover:bg-neutral-950 text-white text-[11px] font-black rounded-lg uppercase tracking-wide cursor-pointer">Add Office</button>
                  </form>
                </div>
              </div>

              <div className="bg-white border border-neutral-200 rounded-2xl p-6 shadow-sm space-y-4">
                <div>
                  <h4 className="text-xs font-black uppercase tracking-widest text-neutral-900">Active Station Capacity Monitors</h4>
                  <p className="text-[10px] text-gray-400 mt-0.5">Live index count detailing personnel distribution weights mapped straight out of storage nodes.</p>
                </div>
                <div className="grid grid-cols-1 sm:grid-cols-2 md:grid-cols-3 gap-3 text-xs font-bold">
                  {infraSummary.officeCapacity.map((off, idx) => (
                    <div key={idx} className="p-2 border border-neutral-200/70 bg-[#FDFBF9] rounded-xl flex justify-between items-center shadow-2xs">
                      <span className="text-neutral-700 font-sans tracking-tight">🏬 {off.office_name}</span>
                      <span className={`px-2 py-0.5 rounded-full text-[10px] font-black ${off.staff_count > 0 ? 'bg-emerald-50 text-emerald-700 border border-emerald-200' : 'bg-red-50 text-red-700 border border-red-200'}`}>{off.staff_count} STAFF</span>
                    </div>
                  ))}
                </div>
              </div>
            </div>
          )}
        </main>
      </div>
    </div>
  );
}