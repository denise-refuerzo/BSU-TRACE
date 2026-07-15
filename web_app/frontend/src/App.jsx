import React from 'react';
import { BrowserRouter as Router, Routes, Route, Navigate } from 'react-router-dom';
import Login from './views/Login';
import AccountManagement from './views/AccountManagement';
import RolesPermissionsMatrix from './views/RolesPermissionsMatrix';
import AdminDashboard from './views/AdminDashboard';
import OriginatorDashboard from './views/OriginatorDashboard';
import ProcessorDashboard from './views/ProcessorDashboard';
import SigneeDashboard from './views/SigneeDashboard';
import GSOAdminDashboard from './views/GSOAdminDashboard';

function App() {
  return (
    <Router>
      <Routes>
        <Route path="/login" element={<Login />} />
        <Route path="/admin/dashboard" element={<AdminDashboard />} />
        <Route path="/admin/accounts" element={<AccountManagement />} />
        <Route path="/admin/matrix" element={<RolesPermissionsMatrix />} />
        <Route path="/dashboard" element={<OriginatorDashboard />} />
        <Route path="/processor/dashboard" element={<ProcessorDashboard />} />
        <Route path="/signee/dashboard" element={<SigneeDashboard />} />
        <Route path="/gso-dashboard" element={<GSOAdminDashboard />} />
        <Route path="*" element={<Navigate to="/login" replace />} />
      </Routes>
    </Router>
  );
}

export default App;