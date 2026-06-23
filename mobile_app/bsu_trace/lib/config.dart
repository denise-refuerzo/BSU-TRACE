class AppConfig {
  // Toggle this to switch between local and production
  static const bool isProduction = true; 

  static const String localApiUrl = 'http://10.0.2.2:3000/api';
  static const String liveApiUrl = 'https://bsu-trace.onrender.com';

  static String get baseUrl {
    return isProduction ? liveApiUrl : localApiUrl;
  }
}