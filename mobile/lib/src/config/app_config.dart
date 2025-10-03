class AppConfig {
  static const String appName = 'RentalSpace';
  static const String appVersion = '1.0.0';
  
  // API Configuration
  static const String baseUrl = 'http://localhost:3001/api';
  static const String baseUrlProduction = 'https://tu-dominio.com/api';
  
  // Timeouts
  static const int connectionTimeout = 30000; // 30 segundos
  static const int receiveTimeout = 30000; // 30 segundos
  
  // Pagination
  static const int defaultPageSize = 20;
  
  // Storage Keys
  static const String tokenKey = 'auth_token';
  static const String userKey = 'user_data';
  static const String settingsKey = 'app_settings';
  
  // Validation
  static const int minPasswordLength = 6;
  static const int maxNameLength = 50;
  
  // Business Rules
  static const int maxBookingDays = 30;
  static const int minBookingHours = 1;
  static const double minPaymentAmount = 1.0;
  
  // Stripe Configuration (Test Keys)
  static const String stripePublishableKey = 'pk_test_...'; // Usar tu key real
  
  // Environment
  static bool get isProduction => const bool.fromEnvironment('dart.vm.product');
  static String get currentBaseUrl => isProduction ? baseUrlProduction : baseUrl;
}