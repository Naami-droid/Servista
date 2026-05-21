import 'dart:convert';
import 'package:http/http.dart' as http;
import 'offline_sync_service.dart';

class ApiService {
  // Use production backend URL
  static String baseUrl = 'https://servista-backend-production.up.railway.app';

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

  static Future<Map<String, dynamic>> createChatSession(String customerId, {String? title}) async {
    final response = await http.post(
      Uri.parse('$baseUrl/chat/sessions/create'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'customer_id': customerId,
        if (title != null) 'title': title,
      }),
    );
    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    } else {
      throw Exception('Failed to create chat session');
    }
  }

  static Future<Map<String, dynamic>> listChatSessions(String customerId) async {
    final response = await http.get(
      Uri.parse('$baseUrl/chat/sessions/list/$customerId'),
      headers: {'Content-Type': 'application/json'},
    );
    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    } else {
      throw Exception('Failed to list chat sessions');
    }
  }

  static Future<Map<String, dynamic>> getChatSessionMessages(String chatId) async {
    final response = await http.get(
      Uri.parse('$baseUrl/chat/sessions/$chatId/messages'),
      headers: {'Content-Type': 'application/json'},
    );
    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    } else {
      throw Exception('Failed to load chat messages');
    }
  }

  static Future<Map<String, dynamic>> addChatSessionMessage(String chatId, Map<String, dynamic> message) async {
    final response = await http.post(
      Uri.parse('$baseUrl/chat/sessions/$chatId/messages/add'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'message': message,
      }),
    );
    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    } else {
      throw Exception('Failed to persist message');
    }
  }

  static Future<Map<String, dynamic>> deleteChatSession(String chatId) async {
    final response = await http.delete(
      Uri.parse('$baseUrl/chat/sessions/$chatId'),
      headers: {'Content-Type': 'application/json'},
    );
    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    } else {
      throw Exception('Failed to delete chat session');
    }
  }

  static Future<Map<String, dynamic>> createBooking(String customerId, Map<String, dynamic> requestData, List<String> offeredProviders, Map<String, dynamic> reasoning) async {
    final Map<String, dynamic> body = {
      'customer_id': customerId,
      'request_data': requestData,
      'offered_provider_ids': offeredProviders,
      'reasoning_data': reasoning
    };
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/bookings/create'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(body),
      );

      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      } else {
        throw Exception('Booking failed: ${response.statusCode} - ${response.body}');
      }
    } catch (e) {
      await OfflineSyncService().enqueueRequest('/bookings/create', 'POST', body);
      throw Exception('offline_queued:Booking request queued. It will sync once network is restored!');
    }
  }

  static Future<List<dynamic>> getPendingBookings(String providerId) async {
    try {
      final response = await http.get(Uri.parse('$baseUrl/bookings/pending/$providerId'));
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['status'] == 'success') return data['bookings'];
      }
    } catch (e) {
      print("Offline getPendingBookings: returning empty list");
    }
    return [];
  }

  static Future<bool> respondToBooking(String bookingId, String action) async {
    final Map<String, dynamic> body = {
      'booking_id': bookingId,
      'action': action,
    };
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/bookings/action'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(body),
      );
      return response.statusCode == 200;
    } catch (e) {
      await OfflineSyncService().enqueueRequest('/bookings/action', 'POST', body);
      throw Exception('offline_queued:Action queued. It will sync once network is restored!');
    }
  }

  static Future<String> getBookingStatus(String bookingId) async {
    try {
      final response = await http.get(Uri.parse('$baseUrl/bookings/status/$bookingId'));
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['status'] == 'success') return data['booking_status'];
      }
    } catch (e) {
      print("Offline getBookingStatus: returning PENDING");
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
    final Map<String, dynamic> body = {
      'booking_id': bookingId,
      'customer_id': 'user_123',
      'rating': rating,
      'review_text': reviewText,
    };
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/reviews/submit'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(body),
      );
      if (response.statusCode != 200) {
        throw Exception('Failed to submit review');
      }
    } catch (e) {
      if (e.toString().startsWith('Exception: Failed to submit review')) {
        rethrow;
      }
      await OfflineSyncService().enqueueRequest('/reviews/submit', 'POST', body);
      throw Exception('offline_queued:Review queued. It will sync once network is restored!');
    }
  }

  static Future<List<dynamic>> getMessages(String bookingId) async {
    try {
      final response = await http.get(Uri.parse('$baseUrl/chat/$bookingId/messages'));
      if (response.statusCode == 200) {
        return jsonDecode(response.body)['messages'];
      }
    } catch (e) {
      print("Offline getMessages: returning empty list");
    }
    return [];
  }

  static Future<void> sendMessage(String bookingId, String senderId, String senderRole, String text) async {
    final Map<String, dynamic> body = {
      'sender_id': senderId,
      'sender_role': senderRole,
      'text': text,
    };
    try {
      await http.post(
        Uri.parse('$baseUrl/chat/$bookingId/send'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(body),
      );
    } catch (e) {
      await OfflineSyncService().enqueueRequest('/chat/$bookingId/send', 'POST', body);
      throw Exception('offline_queued:Message queued. It will sync once network is restored!');
    }
  }

  static Future<bool> cancelBooking(String bookingId) async {
    final Map<String, dynamic> body = {
      'booking_id': bookingId,
      'action': 'cancel',
    };
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/bookings/action'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(body),
      );
      return response.statusCode == 200;
    } catch (e) {
      await OfflineSyncService().enqueueRequest('/bookings/action', 'POST', body);
      throw Exception('offline_queued:Cancellation queued. It will sync once network is restored!');
    }
  }
}
