import 'dart:convert';
import 'package:http/http.dart' as http;

class ApiService {
  // Use 127.0.0.1 for Flutter Web to hit PC localhost
  static const String baseUrl = 'http://127.0.0.1:8000';

  static Future<Map<String, dynamic>> sendChatMessage(String customerId, String message, {List<Map<String, String>> history = const [], List<String> excludedProviders = const [], Map<String, dynamic>? parsedOverride}) async {
    final response = await http.post(
      Uri.parse('$baseUrl/agent/chat'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'customer_id': customerId,
        'message': message,
        'conversation_history': history,
        'excluded_providers': excludedProviders,
        if (parsedOverride != null) 'parsed_override': parsedOverride,
      }),
    );

    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    } else {
      throw Exception('Failed to load AI response');
    }
  }

  static Future<Map<String, dynamic>> createBooking(String customerId, Map<String, dynamic> requestData, List<String> offeredProviders, Map<String, dynamic> reasoning) async {
    final response = await http.post(
      Uri.parse('$baseUrl/bookings/create'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'customer_id': customerId,
        'request_data': requestData,
        'offered_provider_ids': offeredProviders,
        'reasoning_data': reasoning
      }),
    );

    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    } else {
      throw Exception('Booking failed: ${response.statusCode} - ${response.body}');
    }
  }

  static Future<List<dynamic>> getPendingBookings(String providerId) async {
    final response = await http.get(Uri.parse('$baseUrl/bookings/pending/$providerId'));
    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      if (data['status'] == 'success') return data['bookings'];
    }
    return [];
  }

  static Future<bool> respondToBooking(String bookingId, String action) async {
    final response = await http.post(
      Uri.parse('$baseUrl/bookings/action'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'booking_id': bookingId,
        'action': action,
      }),
    );
    return response.statusCode == 200;
  }

  static Future<String> getBookingStatus(String bookingId) async {
    final response = await http.get(Uri.parse('$baseUrl/bookings/status/$bookingId'));
    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      if (data['status'] == 'success') return data['booking_status'];
    }
    return "PENDING";
  }
  static Future<Map<String, dynamic>> login(String email, String password, String role) async {
    final response = await http.post(
      Uri.parse('$baseUrl/auth/login'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'email': email,
        'password': password,
        'role': role,
      }),
    );
    
    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    } else {
      throw Exception('Login failed: ${jsonDecode(response.body)['detail']}');
    }
  }

  static Future<void> submitReview(String bookingId, double rating, String reviewText) async {
    final response = await http.post(
      Uri.parse('$baseUrl/reviews/submit'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'booking_id': bookingId,
        'customer_id': 'user_123',
        'rating': rating,
        'review_text': reviewText,
      }),
    );
    if (response.statusCode != 200) {
      throw Exception('Failed to submit review');
    }
  }
}
