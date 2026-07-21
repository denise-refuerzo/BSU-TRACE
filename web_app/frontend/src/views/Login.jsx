import React, { useState } from 'react';
import { useNavigate } from 'react-router-dom';
import Swal from 'sweetalert2';

export default function Login() {
  const [username, setUsername] = useState('');
  const [password, setPassword] = useState('');
  
  // New State variables for the dynamic 2FA flow
  const [require2FA, setRequire2FA] = useState(false);
  const [otpCode, setOtpCode] = useState('');
  const [tempUserId, setTempUserId] = useState(null); // Holds user ID between step 1 and step 2
  
  const [error, setError] = useState('');
  const navigate = useNavigate();

  // Forgot Password Workspace States  
  const [showForgotModal, setShowForgotModal] = useState(false);  
  const [forgotStep, setForgotStep] = useState(1); 
  const [forgotUsername, setForgotUsername] = useState('');  
  const [maskedEmail, setMaskedEmail] = useState('');  
  const [typedEmail, setTypedEmail] = useState('');  
  const [resetCode, setResetCode] = useState('');  
  const [newPassword, setNewPassword] = useState('');  
  const [confirmPassword, setConfirmPassword] = useState('');  
  const [forgotError, setForgotError] = useState('');  
  const [forgotSuccess, setForgotSuccess] = useState('');  

  // Visibility states
  const [showSignInPassword, setShowSignInPassword] = useState(false);  
  const [showNewPassword, setShowNewPassword] = useState(false);  
  const [showConfirmPassword, setShowConfirmPassword] = useState(false);  

  // --- STEP 1: INITIAL LOGIN CONTROLLER ---
  const handleSignIn = async (e) => {
    e.preventDefault();
    setError('');

    try {
      const response = await fetch('http://localhost:5000/api/login', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ username, password })  
      });
      
      const data = await response.json();
      
      if (!response.ok) {
        throw new Error(data.error || 'Login failed');  
      }

      // Check if backend requires 2FA to complete the login
      if (data.two_fa_enabled) {
        setTempUserId(data.u_id);
        setRequire2FA(true);  
        Swal.fire({
          title: 'Verification Required',
          text: 'A 6-digit verification code has been sent to your university email.',
          icon: 'info',
          confirmButtonColor: '#800000'
        });
        return; 
      }

      // If 2FA is OFF, log them in immediately
      completeLogin(data);
      
    } catch (err) {
      setError(err.message);  
    }
  };

  // --- STEP 2: 2FA OTP VERIFICATION CONTROLLER ---
  const handleVerifyOTP = async (e) => {
    e.preventDefault();
    setError('');

    try {
      const response = await fetch('http://localhost:5000/api/login/verify-2fa', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ userId: tempUserId, otpCode: otpCode })
      });

      const data = await response.json();

      if (!response.ok) {
        throw new Error(data.error || 'Verification failed');
      }

      // Re-fetch standard login data if needed or decode token if your backend sends it back here.
      // Since our backend verify route returns u_id, a_id, and session_token, we can proceed.
      // NOTE: You may need to ensure your backend `/verify-2fa` endpoint also returns `token`, `role`, `roleName`, `fullName` just like the normal login does, OR you fetch it here.
      // For now, assuming the backend `/verify-2fa` is updated to return the same payload as standard login:
      completeLogin(data);

    } catch (err) {
      setError(err.message);
    }
  }

  // --- FINAL ROUTING ---
  const completeLogin = (data) => {
    localStorage.setItem('token', data.token);  
    localStorage.setItem('user', data.fullName);  
    const cleanUserId = String(data.userId || data.u_id).split(':')[0].trim();  
    localStorage.setItem('userId', cleanUserId);  

    const role = data.role || data.a_id;
    if (role === 5) {
      navigate('/admin/dashboard')  
    } else if (role === 2) {
      navigate('/processor/dashboard');   
    } else if (role === 3) {
      navigate('/signee/dashboard');   
    } else if (role === 4) {
      navigate('/gso-dashboard'); 
    } else {
      navigate('/dashboard');    
    }
  }

  // FORGOT PASSWORD STEP 1: Verify Username exists  
  const handleIdentifyUser = async (e) => {
    e.preventDefault();  
    setForgotError('');  
    try {
      const res = await fetch('http://localhost:5000/api/auth/forgot-password/identify', {
        method: 'POST',  
        headers: { 'Content-Type': 'application/json' },  
        body: JSON.stringify({ username: forgotUsername })  
      });
      const data = await res.json();  
      if (!res.ok) throw new Error(data.error || 'User verification failed.');  
      
      setMaskedEmail(data.maskedEmail);  
      setForgotStep(2);  
    } catch (err) {
      setForgotError(err.message);  
    }
  };

  // FORGOT PASSWORD STEP 2 & 3: Match Email precisely and request SMTP token dispatch  
  const handleVerifyEmail = async (e) => {
    e.preventDefault();  
    setForgotError('');  
    try {
      const res = await fetch('http://localhost:5000/api/auth/forgot-password/verify-email', {
        method: 'POST',  
        headers: { 'Content-Type': 'application/json' },  
        body: JSON.stringify({ username: forgotUsername, fullEmail: typedEmail })  
      });
      const data = await res.json();  
      if (!res.ok) throw new Error(data.error || 'Email challenge failed.');  
      
      setForgotStep(3);  
    } catch (err) {
      setForgotError(err.message);  
    }
  };

  // FORGOT PASSWORD STEP 4: Reset Password Commitment  
  const handleResetPassword = async (e) => {
    e.preventDefault();  
    setForgotError('');  
    
    if (newPassword !== confirmPassword) {
      setForgotError('New passwords do not match.');  
      return;  
    }

    try {
      const res = await fetch('http://localhost:5000/api/auth/forgot-password/reset', {
        method: 'POST',  
        headers: { 'Content-Type': 'application/json' },  
        body: JSON.stringify({ username: forgotUsername, code: resetCode, newPassword })  
      });
      const data = await res.json();  
      if (!res.ok) throw new Error(data.error || 'Password adjustment sequence failed.');  
      
      setForgotSuccess(data.message);  
      setForgotStep(4);  
    } catch (err) {
      setForgotError(err.message);  
    }
  };

  const closeForgotModal = () => {
    setShowForgotModal(false);  
    setForgotStep(1);  
    setForgotUsername('');  
    setMaskedEmail('');  
    setTypedEmail('');  
    setResetCode('');  
    setNewPassword('');  
    setConfirmPassword('');  
    setForgotError('');  
    setForgotSuccess('');  
    setShowSignInPassword(false);  
    setShowNewPassword(false);  
    setShowConfirmPassword(false);  
  };

  return (
    <div className="flex h-screen w-screen bg-neutral-50 font-sans relative">  
      
      {/* 2FA CONDITIONAL OVERLAY FORM DIALOG BOX */}  
      {require2FA && (
        <div className="fixed inset-0 bg-neutral-950/50 backdrop-blur-xs flex items-center justify-center z-50 p-4">  
          <div className="bg-white p-6 rounded-2xl border shadow-2xl max-w-sm w-full text-center space-y-4 animate-in zoom-in-95 duration-100">  
            <div className="w-12 h-12 bg-red-50 text-red-800 rounded-full flex items-center justify-center mx-auto text-xl">🛡️</div>  
            <div>
              <h4 className="font-bold text-neutral-900 text-base">Security Verification</h4>  
              <p className="text-xs text-neutral-400 mt-1">Check your email for the 6-digit OTP code to continue.</p>  
            </div>
            {error && <div className="p-2 bg-red-50 text-red-600 text-[11px] rounded border border-red-100">{error}</div>}  
            <form onSubmit={handleVerifyOTP} className="space-y-3">  
              <input 
                type="text" maxLength={6} required value={otpCode} onChange={e => setOtpCode(e.target.value.replace(/\D/g, ""))}  
                placeholder="Enter 6-digit code" className="w-full border px-4 py-2 text-center font-mono text-sm tracking-widest rounded-lg focus:ring-1 focus:ring-red-700 outline-none" 
              />

              <div className="flex gap-2">  
                <button type="button" onClick={() => { setRequire2FA(false); setOtpCode(''); setError(''); setTempUserId(null); }} className="w-1/2 border py-2 text-xs font-semibold text-gray-500 rounded-lg hover:bg-neutral-50">Cancel</button>  
                <button type="submit" className="w-1/2 bg-red-800 hover:bg-red-900 text-white text-xs font-semibold rounded-lg">Confirm</button>  
              </div>
            </form>
          </div>
        </div>
      )}

      {/* MULTI-STEP FORGOT PASSWORD MODAL OVERLAY */}  
      {showForgotModal && (
        <div className="fixed inset-0 bg-neutral-950/50 backdrop-blur-xs flex items-center justify-center z-50 p-4">  
          <div className="bg-white p-6 rounded-2xl border shadow-2xl max-w-md w-full space-y-4 animate-in zoom-in-95 duration-100">  
            <div className="flex items-center gap-3 border-b pb-3 border-neutral-100">  
              <span className="text-xl">🔑</span>  
              <div>
                <h4 className="font-bold text-neutral-900 text-base">Account Recovery</h4>  
                <p className="text-xs text-neutral-400">Follow the steps to establish a clean configuration profile link.</p>  
              </div>
            </div>

            {forgotError && <div className="p-2.5 bg-red-50 text-red-600 text-xs rounded border border-red-100">{forgotError}</div>}  

            {/* STEP 1: FIND USERNAME */}  
            {forgotStep === 1 && (
              <form onSubmit={handleIdentifyUser} className="space-y-4">  
                <div>
                  <label className="block text-xs font-semibold text-gray-600 mb-1">Enter Username</label>  
                  <input type="text" required value={forgotUsername} onChange={e => setForgotUsername(e.target.value)}  
                         className="w-full px-4 py-2 border rounded-lg text-sm focus:ring-1 focus:ring-red-700 outline-none" placeholder="University Username" />  
                </div>
                <div className="flex gap-2 justify-end pt-2">  
                  <button type="button" onClick={closeForgotModal} className="px-4 py-2 text-xs font-semibold text-gray-500 border rounded-lg hover:bg-neutral-50">Cancel</button>  
                  <button type="submit" className="px-4 py-2 bg-red-700 hover:bg-red-800 text-white text-xs font-semibold rounded-lg">Find Account</button>  
                </div>
              </form>
            )}

            {/* STEP 2: CHALLENGE EMAIL FILL-IN */}  
            {forgotStep === 2 && (
              <form onSubmit={handleVerifyEmail} className="space-y-4">  
                <div className="p-3 bg-neutral-50 rounded-lg border border-neutral-200">  
                  <p className="text-xs text-gray-600">An account was identified matching your criteria.</p>  
                  <p className="text-sm font-mono font-bold text-center text-red-800 mt-2 tracking-wide">{maskedEmail}</p>  
                </div>
                <div>
                  <label className="block text-xs font-semibold text-gray-600 mb-1">Retype your Full Email Address</label>  
                  <input type="email" required value={typedEmail} onChange={e => setTypedEmail(e.target.value)}  
                         className="w-full px-4 py-2 border rounded-lg text-sm focus:ring-1 focus:ring-red-700 outline-none" placeholder="your_email@gmail.com" />  
                </div>
                <div className="flex gap-2 justify-end pt-2">  
                  <button type="button" onClick={closeForgotModal} className="px-4 py-2 text-xs font-semibold text-gray-500 border rounded-lg hover:bg-neutral-50">Cancel</button>  
                  <button type="submit" className="px-4 py-2 bg-red-700 hover:bg-red-800 text-white text-xs font-semibold rounded-lg">Send Verification Code</button>  
                </div>
              </form>
            )}

            {/* STEP 3: CODE CHECK & PASSWORD INPUTS */}  
            {forgotStep === 3 && (
              <form onSubmit={handleResetPassword} className="space-y-4">  
                <div className="p-3 bg-green-50 rounded-lg border border-green-200 text-center">  
                  <p className="text-xs text-green-700 font-medium">A security code has been dispatched to your validated inbox.</p>  
                </div>
                <div>
                  <label className="block text-xs font-semibold text-gray-600 mb-1">6-Digit Recovery Token</label>  
                  <input type="text" maxLength={6} required value={resetCode} onChange={e => setResetCode(e.target.value.replace(/\D/g, ""))}  
                        className="w-full px-4 py-2 text-center font-mono font-bold text-base tracking-widest border rounded-lg focus:ring-1 focus:ring-red-700 outline-none" placeholder="000000" />  
                </div>
                
                <div>
                  <label className="block text-xs font-semibold text-gray-600 mb-1">Create New Password</label>  
                  <div className="relative flex items-center">  
                    <input 
                      type={showNewPassword ? "text" : "password"}  
                      required 
                      value={newPassword} 
                      onChange={e => setNewPassword(e.target.value)}  
                      className="w-full pl-4 pr-14 py-2 border rounded-lg text-sm focus:ring-1 focus:ring-red-700 outline-none" 
                      placeholder="••••••••" 
                    />
                    <button
                      type="button"
                      onClick={() => setShowNewPassword(!showNewPassword)}  
                      className="absolute right-3 text-[11px] font-bold uppercase tracking-wider text-neutral-400 hover:text-neutral-600 select-none bg-transparent border-none cursor-pointer"
                    >
                      {showNewPassword ? "Hide" : "Show"}  
                    </button>
                  </div>
                </div>

                <div>
                  <label className="block text-xs font-semibold text-gray-600 mb-1">Confirm New Password</label>  
                  <div className="relative flex items-center">  
                    <input 
                      type={showConfirmPassword ? "text" : "password"}  
                      required 
                      value={confirmPassword} 
                      onChange={e => setConfirmPassword(e.target.value)}  
                      className="w-full pl-4 pr-14 py-2 border rounded-lg text-sm focus:ring-1 focus:ring-red-700 outline-none" 
                      placeholder="••••••••" 
                    />
                    <button
                      type="button"
                      onClick={() => setShowConfirmPassword(!showConfirmPassword)}  
                      className="absolute right-3 text-[11px] font-bold uppercase tracking-wider text-neutral-400 hover:text-neutral-600 select-none bg-transparent border-none cursor-pointer"
                    >
                      {showConfirmPassword ? "Hide" : "Show"}  
                    </button>
                  </div>
                </div>

                <div className="flex gap-2 justify-end pt-2">  
                  <button type="button" onClick={closeForgotModal} className="px-4 py-2 text-xs font-semibold text-gray-500 border rounded-lg hover:bg-neutral-50">Cancel</button>  
                  <button type="submit" className="px-4 py-2 bg-red-700 hover:bg-red-800 text-white text-xs font-semibold rounded-lg">Reset Password</button>  
                </div>
              </form>
            )}

            {/* STEP 4: SUCCESS SYNCHRONIZATION */}  
            {forgotStep === 4 && (
              <div className="space-y-4 text-center py-2">  
                <div className="w-12 h-12 bg-green-50 text-green-700 border border-green-200 rounded-full flex items-center justify-center mx-auto text-xl">✓</div>  
                <div>
                  <h5 className="font-bold text-neutral-900 text-sm">Credentials Changed cleanly</h5>  
                  <p className="text-xs text-neutral-400 mt-1">{forgotSuccess}</p>  
                </div>
                <button type="button" onClick={closeForgotModal} className="w-full bg-neutral-900 hover:bg-neutral-950 text-white text-xs font-semibold py-2.5 rounded-lg">  
                  Return to Sign In Dashboard
                </button>
              </div>
            )}
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
                <div className="relative flex items-center">  
                  <input 
                    type={showSignInPassword ? "text" : "password"}  
                    value={password} 
                    onChange={e => setPassword(e.target.value)}  
                    required
                    className="w-full pl-4 pr-14 py-2.5 border border-neutral-300 rounded-lg text-sm focus:outline-none focus:ring-1 focus:ring-red-700" 
                    placeholder="••••••••" 
                  />
                  <button
                    type="button"
                    onClick={() => setShowSignInPassword(!showSignInPassword)}  
                    className="absolute right-3 text-[11px] font-bold uppercase tracking-wider text-neutral-400 hover:text-neutral-600 select-none bg-transparent border-none cursor-pointer"
                  >
                    {showSignInPassword ? "Hide" : "Show"}  
                  </button>
                </div>
              </div>
              
              <div className="text-right">  
                <button type="button" onClick={() => setShowForgotModal(true)} className="text-xs text-red-600 hover:underline bg-transparent border-none p-0 cursor-pointer">  
                  Forgot Password?  
                </button>  
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