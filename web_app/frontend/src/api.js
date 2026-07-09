import Swal from 'sweetalert2';

export const fetchWithAuth = async (url, options = {}) => {
  const token = localStorage.getItem('token');
  
  // Attach the Authorization header automatically
  const headers = {
    'Content-Type': 'application/json',
    ...options.headers,
    'Authorization': token ? `Bearer ${token}` : ''
  };

  const response = await fetch(url, { ...options, headers });
  const data = await response.json();

  // 🚨 THE KICK-OUT INTERCEPTOR: Checks if another device logged in
  if (response.status === 401 && data.forceLogout) {
    Swal.fire({
      title: '⚠️ Session Expired',
      text: 'You have been logged out because your account was accessed from another device or location.',
      icon: 'warning',
      confirmButtonColor: '#800000',
      allowOutsideClick: false
    }).then(() => {
      localStorage.clear(); // Wipe saved credentials
      window.location.href = '/login'; // Boot them back to the login screen
    });
    throw new Error('Session terminated by concurrent login.');
  }

  if (!response.ok) {
    throw new Error(data.error || 'Request failed');
  }

  return data;
};