import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

class SessionStatusService {
  static const String _baseUrl = 'https://webapi.hexgen.in';

  /// Check if a session has been consumed/played on the machine.
  /// Returns the full status map from the cloud.
  static Future<Map<String, dynamic>> checkSessionStatus(String sessionId) async {
    if (sessionId.trim().isEmpty) {
      return {'valid': false, 'status': 'NOT_FOUND', 'error': true};
    }
    final url = Uri.parse('$_baseUrl/api/v1/sessions/$sessionId/verify');

    try {
      final response = await http
          .get(url, headers: {'Accept': 'application/json'})
          .timeout(const Duration(seconds: 5));

      if (response.statusCode == 200) {
        return jsonDecode(response.body) as Map<String, dynamic>;
      }
      return {'valid': true, 'status': 'READY_TO_BOWL', 'error': false};
    } catch (e) {
      debugPrint('[SessionStatusService] checkSessionStatus error: $e');
      // Network error — assume still upcoming (don't wrongly move to past)
      return {'valid': true, 'status': 'READY_TO_BOWL', 'error': true};
    }
  }

  /// Returns true if the session has been played/completed on the One6 machine.
  static Future<bool> isSessionCompleted(String sessionId) async {
    final result = await checkSessionStatus(sessionId);
    final status = result['status']?.toString().toUpperCase() ?? '';
    final isValid = result['valid'] as bool?;

    // Status is explicitly marked COMPLETED or CONSUMED
    if (status == 'COMPLETED' || status == 'CONSUMED') {
      return true;
    }

    // When machine scans and marks complete, valid becomes false with played_at or completed status
    if (isValid == false && (result.containsKey('played_at') || status == 'COMPLETED')) {
      return true;
    }

    return false;
  }
}
