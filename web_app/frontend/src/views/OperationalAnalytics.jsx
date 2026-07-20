import React, { useState, useEffect } from 'react';
import { useNavigate } from 'react-router-dom';
import { fetchWithAuth } from '../api';

export default function OperationalAnalytics() {
  const navigate = useNavigate();
  const adminName = localStorage.getItem('user') || 'Admin User';

  const [loading, setLoading] = useState(true);
  const [routePerf, setRoutePerf] = useState({ document_routes: [], vehicle_scheduling: [] });
  const [systemHealth, setSystemHealth] = useState({
    database_connection: 'CHECKING',
    data_quality_audit: { status: 'PASS', integrity_score_percentage: 100, audit_details: {} }
  });

  useEffect(() => {
    fetchAnalyticsData();
  }, []);

  const fetchAnalyticsData = async () => {
    setLoading(true);
    try {
      // 1. Fetch Route & Vehicle Performance Metrics
      const routeRes = await fetchWithAuth('http://localhost:5000/api/analytics/route-performance');
      if (routeRes.ok) {
        const routeData = await routeRes.json();
        setRoutePerf(routeData);
      }

      // 2. Fetch System Health & Data Quality Metrics
      const healthRes = await fetchWithAuth('http://localhost:5000/api/analytics/system-health');
      if (healthRes.ok) {
        const healthData = await healthRes.json();
        setSystemHealth(healthData);
      }
    } catch (err) {
      console.error("Error connecting to analytics engine:", err);
    } finally {
      setLoading(false);
    }
  };

  return (
    <div className="flex h-screen w-screen bg-[#FDFBF9] overflow-hidden text-neutral-800 font-sans">
      {/* Sidebar Navigation */}
      <div className="w-64 bg-[#2D1F1E] text-neutral-300 flex flex-col justify-between p-4 shrink-0 text-left">
        <div>
          <div className="flex items-center gap-3 border-b border-neutral-700 pb-4 mb-6">
            <div className="bg-red-700 p-2 rounded-lg text-white text-xl">🎓</div>
            <div>
              <h1 className="font-bold text-white text-sm leading-none">BSU Portal</h1>
              <span className="text-[10px] text-neutral-400 uppercase tracking-widest">Admin Console</span>
            </div>
          </div>
          <nav className="space-y-1 text-sm">
            <button type="button" onClick={() => navigate('/admin/dashboard')} className="w-full flex items-center gap-3 px-3 py-2.5 rounded-lg text-neutral-400 hover:bg-neutral-800 hover:text-white transition-colors">📊 Dashboard</button>
            <button type="button" onClick={() => navigate('/admin/accounts')} className="w-full flex items-center gap-3 px-3 py-2.5 rounded-lg text-neutral-400 hover:bg-neutral-800 hover:text-white transition-colors">👥 Accounts</button>
            <button type="button" onClick={() => navigate('/admin/matrix')} className="w-full flex items-center gap-3 px-3 py-2.5 rounded-lg text-neutral-400 hover:bg-neutral-800 hover:text-white transition-colors">🛡️ Roles & Matrix</button>
            <button type="button" className="w-full flex items-center gap-3 px-3 py-2.5 rounded-lg bg-neutral-800 text-white font-medium">📈 Operational Analytics</button>
          </nav>
        </div>
        <button type="button" onClick={() => { localStorage.clear(); navigate('/login'); }} className="flex items-center gap-3 px-3 py-2.5 text-sm text-neutral-400 hover:text-red-400 rounded-lg transition-colors">
          🚪 Logout
        </button>
      </div>

      {/* Main Workspace Frame */}
      <div className="flex-1 flex flex-col overflow-y-auto">
        <header className="h-16 border-b border-neutral-200/80 bg-white px-8 flex items-center justify-between shadow-xs shrink-0">
          <div className="text-neutral-900 font-black text-xs uppercase tracking-wider font-mono">Analytical Machine Learning Engine Console</div>
          <div className="flex items-center gap-2 border-l pl-4 border-neutral-200 text-xs">
            <span className="font-bold text-neutral-900">{adminName}</span>
            <span className="bg-neutral-100 px-2 py-0.5 rounded text-[10px] uppercase text-neutral-500 font-bold">ICT Root</span>
          </div>
        </header>

        <main className="p-8 max-w-5xl w-full mx-auto space-y-8 text-left">
          <div>
            <h2 className="text-2xl font-black tracking-tight text-neutral-900">Operational & Service Analytics</h2>
            <p className="text-xs text-gray-500">Live evaluation of routing efficiency, vehicle scheduling velocity, and database record health.</p>
          </div>

          {/* SYSTEM HEALTH KPI ROW */}
          <div className="grid grid-cols-1 sm:grid-cols-3 gap-4">
            <div className="bg-white border border-neutral-200 p-5 rounded-2xl shadow-xs">
              <p className="text-[10px] text-gray-400 uppercase font-bold tracking-wider">Database Connection</p>
              <div className="flex items-center justify-between mt-2">
                <span className={`px-3 py-1 rounded-full text-xs font-black uppercase ${
                  systemHealth.database_connection === 'HEALTHY' ? 'bg-emerald-100 text-emerald-800' : 'bg-red-100 text-red-800'
                }`}>
                  {systemHealth.database_connection}
                </span>
                <span className="text-2xl">🗄️</span>
              </div>
            </div>

            <div className="bg-white border border-neutral-200 p-5 rounded-2xl shadow-xs">
              <p className="text-[10px] text-gray-400 uppercase font-bold tracking-wider">Data Integrity Score</p>
              <div className="flex items-center justify-between mt-1">
                <h3 className="text-2xl font-black text-neutral-900">
                  {systemHealth.data_quality_audit.integrity_score_percentage}%
                </h3>
                <span className="text-2xl">🛡️</span>
              </div>
            </div>

            <div className="bg-white border border-neutral-200 p-5 rounded-2xl shadow-xs">
              <p className="text-[10px] text-gray-400 uppercase font-bold tracking-wider">Records Scanned</p>
              <div className="flex items-center justify-between mt-1">
                <h3 className="text-2xl font-black text-neutral-900">
                  {systemHealth.data_quality_audit.audit_details.total_records_scanned || 0}
                </h3>
                <span className="text-2xl">🔍</span>
              </div>
            </div>
          </div>

          {/* MAIN CONTENT GRID */}
          <div className="grid grid-cols-1 lg:grid-cols-2 gap-8">
            
            {/* DOCUMENT ROUTING EFFICIENCY TABLE */}
            <div className="bg-white border border-neutral-200 rounded-2xl p-6 shadow-sm space-y-4">
              <div>
                <h3 className="text-xs font-black uppercase tracking-wider text-red-800">
                  ⚡ Document Routing Efficiency (Avg. Completion Hours)
                </h3>
                <p className="text-[11px] text-gray-400 mt-0.5">Calculated duration documents spend traveling along prescribed routes.</p>
              </div>

              <div className="space-y-2 max-h-[350px] overflow-y-auto pr-1">
                {routePerf.document_routes.map((route, idx) => (
                  <div key={idx} className="p-3 bg-neutral-50 border border-neutral-200 rounded-xl flex justify-between items-center text-xs">
                    <span className="font-bold text-neutral-800 truncate max-w-[70%]">{route.route_name}</span>
                    <span className="font-mono font-black text-red-800 bg-red-50 border border-red-200 px-2 py-1 rounded">
                      {route.avg_completion_hours} hrs
                    </span>
                  </div>
                ))}

                {routePerf.document_routes.length === 0 && (
                  <p className="text-center text-xs italic text-gray-400 py-8">No completed document routing cycles logged yet.</p>
                )}
              </div>
            </div>

            {/* VEHICLE SCHEDULING PERFORMANCE TABLE */}
            <div className="bg-white border border-neutral-200 rounded-2xl p-6 shadow-sm space-y-4">
              <div>
                <h3 className="text-xs font-black uppercase tracking-wider text-red-800">
                  🚐 Vehicle Scheduling Turnaround Metrics
                </h3>
                <p className="text-[11px] text-gray-400 mt-0.5">Monitors trip counts and turnaround duration for fleet vehicles.</p>
              </div>

              <div className="space-y-2 max-h-[350px] overflow-y-auto pr-1">
                {routePerf.vehicle_scheduling.map((item, idx) => (
                  <div key={idx} className="p-3 bg-neutral-50 border border-neutral-200 rounded-xl flex justify-between items-center text-xs">
                    <div>
                    <p className="font-bold text-neutral-800">{item.asset_name}</p>
                      <p className="text-[10px] text-gray-400">Total Trips: {item.total_trips}</p>
                    </div>
                    <span className="font-mono font-black text-emerald-800 bg-emerald-50 border border-emerald-200 px-2 py-1 rounded">
                      {item.avg_turnaround_hours} hrs
                    </span>
                  </div>
                ))}

                {routePerf.vehicle_scheduling.length === 0 && (
                  <div className="text-center py-8 bg-neutral-50 border border-neutral-100 rounded-xl p-4">
                    <span className="text-xl block mb-1">🚐</span>
                    <p className="text-xs font-bold text-neutral-600 uppercase">No Fleet Trips Logged</p>
                    <p className="text-[10px] text-gray-400 font-normal mt-0.5">Completed vehicle schedules will automatically populate metrics here.</p>
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