import React, { useState } from 'react';
import { useNavigate } from 'react-router-dom';

export default function Login() {
  const [username, setUsername] = useState('');
  const [password, setPassword] = useState('');
  const [pinCode, setPinCode] = useState('');
  const [require2FA, setRequire2FA] = useState(false);
  const [error, setError] = useState('');
  const navigate = useNavigate();

  const handleSignIn = async (e) => {
    e.preventDefault();
    setError('');

    try {
      const response = await fetch('http://localhost:5000/api/login', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ username, password, pinCode: require2FA ? pinCode : undefined })
      });
      
      const data = await response.json();
      if (!response.ok) throw new Error(data.error || 'Login failed');

      // Intercept if 2FA state is triggered by backend response flag
      if (data.require2FA) {
        setRequire2FA(true);
        return;
      }

      localStorage.setItem('token', data.token);
      localStorage.setItem('user', data.fullName);
      const cleanUserId = String(data.userId).split(':')[0].trim();
      localStorage.setItem('userId', cleanUserId);

      if (data.role === 5) {
        navigate('/admin/accounts');
      } else {
        navigate('/dashboard');
      }
    } catch (err) {
      setError(err.message);
    }
  };

  return (
    <div className="flex h-screen w-screen bg-neutral-50 font-sans relative">
      {/* 2FA CONDITIONAL OVERLAY FORM DIALOG BOX */}
      {require2FA && (
        <div className="fixed inset-0 bg-neutral-950/50 backdrop-blur-xs flex items-center justify-center z-50 p-4">
          <div className="bg-white p-6 rounded-2xl border shadow-2xl max-w-sm w-full text-center space-y-4 animate-in zoom-in-95 duration-100">
            <div className="w-12 h-12 bg-red-50 text-red-800 rounded-full flex items-center justify-center mx-auto text-xl">🛡️</div>
            <div>
              <h4 className="font-bold text-neutral-900 text-base">Two-Factor Authentication</h4>
              <p className="text-xs text-neutral-400 mt-1">Please type your numeric combination code pin setup.</p>
            </div>
            {error && <div className="p-2 bg-red-50 text-red-600 text-[11px] rounded border border-red-100">{error}</div>}
            <form onSubmit={handleSignIn} className="space-y-3">
              <input 
                type="text" maxLength={6} required value={pinCode} onChange={e => setPinCode(e.target.value.replace(/\D/g, ""))}
                placeholder="Enter 6-digit code pin" className="w-full border px-4 py-2 text-center font-mono text-sm tracking-widest rounded-lg focus:ring-1 focus:ring-red-700 outline-none" 
              />
              <div className="flex gap-2">
                <button type="button" onClick={() => { setRequire2FA(false); setPinCode(''); setError(''); }} className="w-1/2 border py-2 text-xs font-semibold text-gray-500 rounded-lg hover:bg-neutral-50">Cancel</button>
                <button type="submit" className="w-1/2 bg-red-800 hover:bg-red-900 text-white text-xs font-semibold rounded-lg">Verify Pin</button>
              </div>
            </form>
          </div>
        </div>
      )}

      {/* Left Branding Column */}
      <div className="hidden lg:flex w-1/2 bg-cover bg-center relative items-center justify-center p-12 text-white" 
           style={{ backgroundImage: "linear-gradient(rgba(0,0,0,0.65), rgba(0,0,0,0.75)), url('https://images.unsplash.com/photo-1541339907198-e08756dedf3f?q=80&w=1470')" }}>
        <div className="text-center max-w-md">
          <div className="text-5xl mb-4 flex justify-center">🎓</div>
          <h1 className="text-3xl font-bold tracking-wide uppercase mb-4">BSU Institutional Portal</h1>
          <p className="text-gray-200 text-sm leading-relaxed mb-8">
            Access the university's central administrative hub. Manage academic resources, institutional documentation, and faculty communications in one integrated ecosystem.
          </p>
          <div className="grid grid-cols-3 gap-4 border-t border-white/20 pt-6">
            <div><p className="text-2xl font-bold">15k+</p><p className="text-xs text-gray-300">Students</p></div>
            <div><p className="text-2xl font-bold">800+</p><p className="text-xs text-gray-300">Faculty</p></div>
            <div><p className="text-2xl font-bold">45</p><p className="text-xs text-gray-300">Programs</p></div>
          </div>
        </div>
        <p className="absolute bottom-4 text-xs text-white/40">© 2024 BSU Institutional Management. All Rights Reserved.</p>
      </div>

      {/* Right Form Input Column */}
      <div className="w-full lg:w-1/2 flex flex-col justify-between p-8 bg-[#FAF8F5]">
        <div className="m-auto w-full max-w-md">
          <div className="text-center mb-8">
            <div className="text-red-700 text-4xl mb-2 flex justify-center">🛑</div>
            <h2 className="text-2xl font-bold text-red-800">University Portal</h2>
            <p className="text-xs text-gray-500 uppercase tracking-widest">BSU Institutional Portal</p>
          </div>

          <div className="bg-white p-8 rounded-2xl shadow-sm border border-neutral-200/60">
            <h3 className="text-xl font-bold text-center text-red-700 tracking-wider mb-6">SIGN IN</h3>
            
            {error && !require2FA && <div className="mb-4 p-3 bg-red-50 text-red-600 text-xs rounded-lg border border-red-200">{error}</div>}

            <form onSubmit={handleSignIn} className="space-y-4">
              <div>
                <label className="block text-xs font-semibold text-gray-600 mb-1">Username</label>
                <input type="text" value={username} onChange={e => setUsername(e.target.value)} required
                       className="w-full px-4 py-2.5 border border-neutral-300 rounded-lg text-sm focus:outline-none focus:ring-1 focus:ring-red-700" placeholder="Username" />
              </div>
              <div>
                <label className="block text-xs font-semibold text-gray-600 mb-1">Password</label>
                <input type="password" value={password} onChange={e => setPassword(e.target.value)} required
                       className="w-full px-4 py-2.5 border border-neutral-300 rounded-lg text-sm focus:outline-none focus:ring-1 focus:ring-red-700" placeholder="••••••••" />
              </div>
              <div className="text-right">
                <a href="#" className="text-xs text-red-600 hover:underline">Forgot Password?</a>
              </div>
              <button type="submit" className="w-full bg-red-700 text-white py-2.5 rounded-lg font-medium text-sm flex items-center justify-center gap-2 hover:bg-red-700 transition-colors">
                SIGN IN <span>→</span>
              </button>
            </form>
          </div>
        </div>
        <div className="text-center text-xs text-gray-400">
          <p>Need assistance? <a href="#" className="text-red-600 hover:underline">Contact IT Support</a></p>
          <p className="mt-2">© 2024 University Institutional Portal. All rights reserved.</p>
        </div>
      </div>
    </div>
  );
}