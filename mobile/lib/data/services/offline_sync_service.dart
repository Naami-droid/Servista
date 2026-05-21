import 'dart:convert';
import 'dart:async';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;
import 'api_service.dart';

class OfflineSyncService {
  static final OfflineSyncService _instance = OfflineSyncService._internal();
  factory OfflineSyncService() => _instance;
  OfflineSyncService._internal();

  static const String _queueKey = 'offline_sync_queue';
  Timer? _syncTimer;
  bool _isSyncing = false;

  void init() {
    _syncTimer?.cancel();
    // Periodically attempt to sync enqueued requests every 15 seconds
    _syncTimer = Timer.periodic(const Duration(seconds: 15), (_) => syncQueue());
  }

  Future<void> enqueueRequest(String path, String method, Map<String, dynamic> body) async {
    final prefs = await SharedPreferences.getInstance();
    final queue = prefs.getStringList(_queueKey) ?? [];

    final requestItem = {
      'path': path,
      'method': method,
      'body': body,
      'timestamp': DateTime.now().toIso8601String(),
    };

    queue.add(jsonEncode(requestItem));
    await prefs.setStringList(_queueKey, queue);
    print("📥 OfflineSyncService: Enqueued offline request to $path");
  }

  Future<void> syncQueue() async {
    if (_isSyncing) return;
    _isSyncing = true;

    try {
      final prefs = await SharedPreferences.getInstance();
      final queue = prefs.getStringList(_queueKey) ?? [];

      if (queue.isEmpty) {
        _isSyncing = false;
        return;
      }

      print("🔄 OfflineSyncService: Attempting to sync ${queue.length} enqueued requests...");
      final remainingQueue = <String>[];

      for (final itemStr in queue) {
        final item = jsonDecode(itemStr);
        final String path = item['path'];
        final String method = item['method'];
        final Map<String, dynamic> body = item['body'];

        bool success = false;
        try {
          final uri = Uri.parse('${ApiService.baseUrl}$path');
          http.Response response;

          if (method == 'POST') {
            response = await http.post(
              uri,
              headers: {'Content-Type': 'application/json'},
              body: jsonEncode(body),
            );
          } else {
            response = await http.get(uri);
          }

          if (response.statusCode >= 200 && response.statusCode < 300) {
            success = true;
            print("✅ OfflineSyncService: Successfully synced request to $path");
          } else {
            print("⚠️ OfflineSyncService: Failed request to $path with code ${response.statusCode}");
          }
        } catch (e) {
          print("❌ OfflineSyncService: Network error syncing request to $path: $e");
        }

        if (!success) {
          remainingQueue.add(itemStr);
        }
      }

      await prefs.setStringList(_queueKey, remainingQueue);
    } catch (e) {
      print("❌ OfflineSyncService: Sync queue failed: $e");
    } finally {
      _isSyncing = false;
    }
  }

  Future<int> getQueueSize() async {
    final prefs = await SharedPreferences.getInstance();
    return (prefs.getStringList(_queueKey) ?? []).length;
  }
}
