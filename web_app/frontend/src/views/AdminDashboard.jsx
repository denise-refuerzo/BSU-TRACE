import React, { useState, useEffect } from 'react';
import { useNavigate } from 'react-router-dom';
import { fetchWithAuth } from '../api';

export default function AdminDashboard() {
  const navigate = useNavigate();
  const adminName = localStorage.getItem('user') || 'Admin User';
  const [loading, setLoading] = useState(true);
  const [data, setData] = useState({
    counters: { activeTracks: 0, systemUsers: 0, workflowBlueprints: 0 },
    liveAuditTrail: [],
    stalledBottlenecks: []
  });

  useEffect(() => {
    fetchDashboardMetrics();
    // Establish a live pooling cycle to auto-refresh feeds every 30 seconds
    const interval = setInterval(fetchDashboardMetrics, 30000);
    return () => clearInterval(interval);
  }, []);

  const fetchDashboardMetrics = async () => {
    try {
      const res = await fetchWithAuth('http://localhost:5000/api/admin/dashboard-metrics');
      const payload = await res.json();
      if (res.ok) setData(payload);
    } catch (err) {
      console.error("Error gathering ecosystem infrastructure parameters:", err);
    } finally {
      setLoading(false);
    }
  };


  return (
    <div className="flex h-screen w-screen bg-[#FDFBF9] overflow-hidden text-neutral-800 font-sans">
      {/* Sidebar Navigation Panel */}
      <div className="w-64 bg-[#2D1F1E] text-neutral-300 flex flex-col justify-between p-4 shrink-0">
        <div>
          <div className="flex items-center gap-3 border-b border-neutral-700 pb-4 mb-6">
            <div className="bg-red-700 p-2 rounded-lg text-white text-xl">🎓</div>
            <div>
              <h1 className="font-bold text-white text-sm leading-none">BSU Portal</h1>
              <span className="text-[10px] text-neutral-400 uppercase tracking-widest">Admin Console</span>
            </div>
          </div>
          <nav className="space-y-1 text-sm">
            <button type="button" className="w-full flex items-center gap-3 px-3 py-2.5 rounded-lg bg-neutral-800 text-white font-medium text-left">📊 Dashboard</button>
            <button type="button" onClick={() => navigate('/admin/accounts')} className="w-full flex items-center gap-3 px-3 py-2.5 rounded-lg text-neutral-400 hover:bg-neutral-800 hover:text-white transition-colors">👥 Accounts</button>
            <button type="button" onClick={() => navigate('/admin/matrix')} className="w-full flex items-center gap-3 px-3 py-2.5 rounded-lg text-neutral-400 hover:bg-neutral-800 hover:text-white transition-colors">🛡️ Roles & Matrix</button>
          </nav>
        </div>
        <button type="button" onClick={() => { localStorage.clear(); navigate('/login'); }} className="flex items-center gap-3 px-3 py-2.5 text-sm text-neutral-400 hover:text-red-400 rounded-lg transition-colors text-left">
          🚪 Logout
        </button>
      </div>

      {/* Main Panel Content Scroll Area */}
      <div className="flex-1 flex flex-col overflow-y-auto">
        <header className="h-16 border-b border-neutral-200/80 bg-white px-8 flex items-center justify-between shadow-xs shrink-0">
          <div className="text-neutral-900 font-black text-xs uppercase tracking-wider font-mono">Infrastructure Overview Dashboard Controller</div>
          <div className="flex items-center gap-2 border-l pl-4 border-neutral-200 text-xs">
            <span className="font-bold text-neutral-900">{adminName}</span>
            <span className="bg-neutral-100 px-2 py-0.5 rounded text-[10px] uppercase text-neutral-500 font-bold">ICT Root</span>
          </div>
        </header>

        <main className="p-8 max-w-5xl w-full mx-auto space-y-8">
          <div>
            <h2 className="text-2xl font-black tracking-tight text-neutral-900">Operations Control Center</h2>
            <p className="text-xs text-gray-500">Real-time telemetry monitoring background data pipelines, traffic flows, and operational backlogs.</p>
          </div>

          {/* VITAL COUNTERS ROW */}
          <div className="grid grid-cols-1 sm:grid-cols-3 gap-4">
            <div className="bg-white border border-neutral-200 p-5 rounded-2xl shadow-xs flex items-center justify-between">
              <div>
                <p className="text-[10px] text-gray-400 uppercase font-bold tracking-wider">Active Document Tracks</p>
                <h3 className="text-2xl font-black mt-1 text-neutral-900">{data.counters.activeTracks}</h3>
              </div>
              <span className="text-2xl p-2 bg-red-50 rounded-xl">📄</span>
            </div>
            <div className="bg-white border border-neutral-200 p-5 rounded-2xl shadow-xs flex items-center justify-between">
              <div>
                <p className="text-[10px] text-gray-400 uppercase font-bold tracking-wider">Registered Personnel</p>
                <h3 className="text-2xl font-black mt-1 text-neutral-900">{data.counters.systemUsers}</h3>
              </div>
              <span className="text-2xl p-2 bg-blue-50 rounded-xl">👥</span>
            </div>
            <div className="bg-white border border-neutral-200 p-5 rounded-2xl shadow-xs flex items-center justify-between">
              <div>
                <p className="text-[10px] text-gray-400 uppercase font-bold tracking-wider">Workflow Blueprints</p>
                <h3 className="text-2xl font-black mt-1 text-neutral-900">{data.counters.workflowBlueprints}</h3>
              </div>
              <span className="text-2xl p-2 bg-purple-50 rounded-xl">🗺️</span>
            </div>
          </div>

          <div className="grid grid-cols-1 lg:grid-cols-3 gap-8 items-start">
            {/* LEFT COLUMN: LIVE STREAM AUDIT LOG FEED */}
            <div className="lg:col-span-2 bg-white border border-neutral-200 rounded-2xl p-6 shadow-sm space-y-4">
              <div>
                <h3 className="text-xs font-black uppercase tracking-wider text-red-800 flex items-center gap-2">
                  <span className="inline-block w-2 h-2 rounded-full bg-emerald-500 animate-ping"></span>
                  Live System-Wide Audit Stream Feed
                </h3>
                <p className="text-[11px] text-gray-400 mt-0.5">Real-time rolling ledger tracing pipeline checkpoints and structural user actions campus-wide.</p>
              </div>

              <div className="space-y-2 max-h-[380px] overflow-y-auto pr-1 custom-scrollbar divide-y divide-neutral-100">
                {data.liveAuditTrail.map((log) => (
                  <div key={log.history_id} className="pt-2.5 first:pt-0 flex justify-between items-start text-xs font-semibold">
                    <div className="space-y-0.5 max-w-[75%]">
                      <p className="text-neutral-900 font-bold">
                        {log.operator_name} applied <span className="text-red-800">"{log.action_type}"</span>
                      </p>
                      <p className="text-[11px] text-gray-500 font-normal">
                        Document: <span className="font-semibold text-neutral-700">`{log.document_title}`</span>
                      </p>
                      <p className="text-[10px] text-gray-400 font-mono font-normal">🏬 Location Block: {log.office_name || 'Global Core Node'}</p>
                    </div>
                    <span className="text-[10px] text-gray-400 font-mono font-normal whitespace-nowrap">
                      {log.action_timestamp
                        ? new Date(String(log.action_timestamp).replace(/(\+00:00|\+00|Z)$/i, '')).toLocaleTimeString('en-US', { 
                            hour: '2-digit', 
                            minute: '2-digit',
                            hour12: true // Kept true to match your working block's format
                          })
                        : 'N/A'}
                    </span>
                  </div>
                ))}
                {data.liveAuditTrail.length === 0 && (
                  <p className="text-center text-xs italic text-gray-400 py-8">No transaction execution records have logged across network clusters today.</p>
                )}
              </div>
            </div>

            {/* RIGHT COLUMN: DELAY CONGESTION ALERTS PANEL */}
            <div className="bg-white border border-neutral-200 rounded-2xl p-5 shadow-sm space-y-4">
              <div>
                <h4 className="text-xs font-black tracking-wider text-red-800 uppercase flex items-center gap-1.5">🚨 Stalled Queue Congestion Alerts</h4>
                <p className="text-[10px] text-gray-400 mt-0.5">Identifies critical workflows sitting inside an office destination past 48 hours without release scans.</p>
              </div>

              <div className="space-y-2.5 max-h-[380px] overflow-y-auto custom-scrollbar">
                {data.stalledBottlenecks.map((item, index) => (
                  <div key={index} className="p-3 bg-red-50/60 border border-red-100 rounded-xl space-y-1 animate-pulse">
                    <div className="flex justify-between items-center">
                      <span className="text-neutral-900 font-bold text-xs truncate max-w-[70%]">{item.document_title}</span>
                      <span className="text-[9px] bg-red-700 text-white font-black px-1.5 py-0.5 rounded font-mono">
                        +{Math.floor(item.hours_stalled)} HOURS
                      </span>
                    </div>
                    <p className="text-[10px] text-red-900 font-medium">Stuck at: <span className="font-bold underline">{item.office_name}</span></p>
                    <p className="text-[9px] text-neutral-400 font-normal font-mono">Arrived: {new Date(item.time_in).toLocaleDateString()} | {new Date(item.time_in).toLocaleTimeString([], { hour: '2-digit', minute: '2-digit' })}</p>
                  </div>
                ))}
                {data.stalledBottlenecks.length === 0 && (
                  <div className="text-center py-8 bg-emerald-50/40 border border-emerald-100 rounded-xl p-4">
                    <span className="text-xl block mb-1">✅</span>
                    <p className="text-xs font-bold text-emerald-800 uppercase">Pipelines Nominal</p>
                    <p className="text-[10px] text-emerald-600 font-normal mt-0.5">Zero tracking files currently breach operational turnaround velocity schedules.</p>
                  </div>
                )}
              </div>
            </div>
          </div>
        </main>
      </div>
    </div>
  );
}