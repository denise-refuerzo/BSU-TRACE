import React from 'react';
import { BrowserRouter as Router, Routes, Route, Navigate } from 'react-router-dom';
import Login from './views/Login';
import AccountManagement from './views/AccountManagement';
import OriginatorDashboard from './views/OriginatorDashboard';
import ProcessorDashboard from './views/ProcessorDashboard';

function App() {
  return (
    <Router>
      <Routes>
        <Route path="/login" element={<Login />} />
        <Route path="/admin/accounts" element={<AccountManagement />} />
        <Route path="/dashboard" element={<OriginatorDashboard />} />
        <Route path="/processor/dashboard" element={<ProcessorDashboard />} />
        <Route path="*" element={<Navigate to="/login" replace />} />
      </Routes>
    </Router>
  );
}

export default App;