class AppConfig {
  // Set this to true to use the live Render server
  static const bool isProduction = false;
  static const String localApiUrl = 'http://192.168.1.185:3000/api';
  static const String liveApiUrl =  'https://bsu-trace.onrender.com/api'; // <-- Ensure '/api' is at the end!
  static String get baseUrl {
    return isProduction ? liveApiUrl : localApiUrl;
  }
}