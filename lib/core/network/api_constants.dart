class ApiConstants {
  // Official One6 Live Cloud Backend Host
  static String customHost = 'webapi.hexgen.in';

  static String get baseUrl {
    if (customHost.contains('webapi.hexgen.in')) {
      return 'https://$customHost/api';
    }
    return 'http://$customHost/api';
  }

  // Auth endpoints
  static String get sendOtp => '$baseUrl/auth/send-otp';
  static String get verifyOtp => '$baseUrl/auth/verify-otp';
  static String get me => '$baseUrl/auth/me';

  // Venues & Slots
  static String get venues => '$baseUrl/venues';
  static String venueSlots(String venueId, {String date = 'today'}) =>
      '$baseUrl/venues/$venueId/slots?date=$date';

  // Bookings
  static String get createBooking => '$baseUrl/bookings';
  static String get myBookings => '$baseUrl/bookings/my-bookings';
  static String get health => '$baseUrl/health';

  // One6 Cricket Sessions (Cloud Backend Part 1)
  static String get createSession => '$baseUrl/v1/sessions/create';
  static String sessionLookup(String sessionId) => '$baseUrl/v1/sessions/$sessionId';
  static String updateSession(String sessionId) => '$baseUrl/v1/sessions/$sessionId';
  static String deleteSession(String sessionId) => '$baseUrl/v1/sessions/$sessionId';
  static String get completeSession => '$baseUrl/v1/sessions/complete';
  static String playerSessions(String mobile) => '$baseUrl/v1/sessions/player/$mobile';
  static String userSessions(String mobile) => '$baseUrl/v1/sessions/user/$mobile';
}
