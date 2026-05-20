import 'package:flutter/material.dart';
import 'dart:async';
import 'package:speech_to_text/speech_to_text.dart' as stt;
import '../../data/services/api_service.dart';
import '../../data/services/notification_service.dart';
import '../shared/reasoning_panel.dart';
import '../shared/live_chat_screen.dart';

class ChatScreen extends StatefulWidget {
  const ChatScreen({Key? key}) : super(key: key);

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final TextEditingController _controller = TextEditingController();
  final List<Map<String, dynamic>> _messages = [
    {'text': 'Salam! 👋\nHow can I help you today?', 'isUser': false}
  ];
  bool _isLoading = false;
  bool _isListening = false;

  // Real Speech To Text
  late stt.SpeechToText _speech;
  bool _speechAvailable = false;

  Map<String, dynamic>? _currentParsedRequest;
  BookingReasoning? _currentReasoning;
  List<dynamic>? _pendingProviders;

  // Booking State
  String? _pendingBookingId;
  Timer? _statusPoller;
  String _bookingStatus = "";

  @override
  void initState() {
    super.initState();
    _speech = stt.SpeechToText();
    _initSpeech();
    NotificationService().init();
  }

  Future<void> _initSpeech() async {
    try {
      bool available = await _speech.initialize(
        onStatus: (status) => print('Speech status: $status'),
        onError: (error) => print('Speech error: $error'),
      );
      if (mounted) {
        setState(() {
          _speechAvailable = available;
        });
      }
    } catch (e) {
      print("Speech initialization failed: $e");
    }
  }

  @override
  void dispose() {
    _statusPoller?.cancel();
    _controller.dispose();
    super.dispose();
  }

  // ─── Voice Recording ─────────────────────────────────────
  void _toggleVoice() async {
    if (!_speechAvailable) {
      // Fallback simulation if mic is unavailable
      setState(() => _isListening = !_isListening);
      if (_isListening) {
        Future.delayed(const Duration(seconds: 2), () {
          if (mounted) {
            setState(() {
              _isListening = false;
              _controller.text = "Mujhe kal subah G-13 mein AC technician chahiye";
            });
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text("🎤 Voice recognized (Demo Mode)!"), duration: Duration(seconds: 1)),
            );
          }
        });
      }
      return;
    }

    if (_isListening) {
      setState(() => _isListening = false);
      _speech.stop();
    } else {
      setState(() => _isListening = true);
      await _speech.listen(
        onResult: (val) {
          if (mounted) {
            setState(() {
              _controller.text = val.recognizedWords;
              if (val.finalResult) {
                _isListening = false;
              }
            });
          }
        },
      );
    }
  }

  // ─── Send Message to AI ─────────────────────────────────
  void _sendMessage() async {
    final text = _controller.text.trim();
    if (text.isEmpty) return;

    final historyToSend = _messages
        .where((m) => m.containsKey('text'))
        .take(6)
        .map((m) => {
              'role': (m['isUser'] as bool) ? 'user' : 'assistant',
              'content': m['text'] as String
            })
        .toList()
        .reversed
        .toList();

    setState(() {
      _messages.insert(0, {'text': text, 'isUser': true});
      _isLoading = true;
      _controller.clear();
      _currentReasoning = null;
      _pendingProviders = null;
      _pendingBookingId = null;
      _bookingStatus = "";
    });

    setState(() {
      _messages.insert(0, {'isThinking': true, 'isUser': false});
    });

    try {
      final response = await ApiService.sendChatMessage("user_123", text, history: historyToSend);

      setState(() {
        _messages.removeWhere((m) => m.containsKey('isThinking'));
      });

      if (response['status'] == 'success') {
        final reasoningData = response['reasoning'];
        if (reasoningData != null && reasoningData['recommended_two'] != null) {
          final recs = reasoningData['recommended_two'];
          final parsedReq = response['parsed_request'];
          setState(() {
            _messages.insert(0, {
              'isStep': true,
              'steps': [
                "✅ Detected location: ${parsedReq['location'] ?? 'N/A'}",
                "✅ Service category: ${parsedReq['service_type'] ?? 'N/A'}",
                "🔍 Finding providers for ${parsedReq['date'] ?? 'today'}...",
                "📊 Found ${response['recommended_providers']?.length ?? 0} matching providers",
              ],
              'isUser': false,
            });
          });

          setState(() {
            _currentParsedRequest = parsedReq;

            final newReasoning = BookingReasoning(
              option1: ReasoningOption(
                  providerId: recs[0]['provider_id'],
                  headline: recs[0]['headline'] ?? '',
                  reasoning: recs[0]['reasoning'] ?? '',
                  tradeoff: recs[0]['tradeoff'] ?? ''),
              option2: recs.length > 1
                  ? ReasoningOption(
                      providerId: recs[1]['provider_id'],
                      headline: recs[1]['headline'] ?? '',
                      reasoning: recs[1]['reasoning'] ?? '',
                      tradeoff: recs[1]['tradeoff'] ?? '')
                  : ReasoningOption(providerId: '', headline: '', reasoning: '', tradeoff: ''),
              whyOthersExcluded: reasoningData['why_others_excluded'] ?? '',
            );

            _currentReasoning = newReasoning;
            _pendingProviders = response['recommended_providers'];
            _messages.insert(0, {'isReasoning': true, 'reasoning': newReasoning, 'isUser': false});

            _messages.insert(0, {
              'text': "I found ${_pendingProviders!.length} great providers near you! Select one below to book.",
              'isUser': false,
            });
          });
        }
      } else if (response['status'] == 'clarify') {
        setState(() {
          _messages.insert(0, {'text': response['message'] ?? 'Could you tell me more?', 'isUser': false});
        });
      } else {
        setState(() {
          _messages.insert(0, {'text': response['message'] ?? 'Something went wrong', 'isUser': false});
        });
      }
    } catch (e) {
      setState(() {
        _messages.removeWhere((m) => m.containsKey('isThinking'));
        _messages.insert(0, {'text': 'Error connecting to AI: $e', 'isUser': false});
      });
    } finally {
      setState(() => _isLoading = false);
    }
  }

  // ─── Book Provider ──────────────────────────────────────
  void _selectProvider(String providerId) async {
    if (_currentParsedRequest == null || _currentReasoning == null) return;

    Map<String, dynamic> reasoningMap = {
      "option1": {"provider_id": _currentReasoning!.option1.providerId},
      "option2": {"provider_id": _currentReasoning!.option2.providerId}
    };

    try {
      final res = await ApiService.createBooking("user_123", _currentParsedRequest!, [], reasoningMap);

      setState(() {
        _pendingBookingId = res['booking_id'];
        _pendingProviders = null;
        _bookingStatus = "PENDING";
        _messages.insert(0, {'text': "📩 Request sent! Waiting for provider to accept...", 'isUser': false});
      });

      _startStatusPolling();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed to book: $e')));
    }
  }

  // ─── Status Polling ─────────────────────────────────────
  void _startStatusPolling() {
    _statusPoller?.cancel();
    _statusPoller = Timer.periodic(const Duration(seconds: 3), (_) async {
      if (_pendingBookingId == null) return;
      try {
        final status = await ApiService.getBookingStatus(_pendingBookingId!);
        if (status != _bookingStatus && mounted) {
          setState(() {
            _bookingStatus = status;
          });
          if (status == "CONFIRMED") {
            _statusPoller?.cancel();
            setState(() {
              _messages.insert(0, {'text': "✅ Provider accepted! You can now chat with them.", 'isUser': false});
            });

            // Schedule a reminder alarm one hour before
            _scheduleMeetingAlarm();
          } else if (status == "REJECTED" || status == "CANCELLED") {
            _statusPoller?.cancel();
            setState(() {
              _messages.insert(0, {'text': "❌ Provider declined or request was cancelled.", 'isUser': false});
            });
            NotificationService().cancelForBooking(_pendingBookingId!);
          } else if (status == "COMPLETED") {
            _statusPoller?.cancel();
            setState(() {
              _messages.insert(0, {'text': "🎉 Service completed! Please rate your experience.", 'isUser': false});
            });
            _showRatingDialog();
          }
        }
      } catch (_) {}
    });
  }

  // ─── Schedule Meeting Alarm ──────────────────────────────
  void _scheduleMeetingAlarm() {
    if (_currentParsedRequest == null || _pendingBookingId == null) return;
    
    // Default meeting time is today plus 2 hours
    DateTime meetingTime = DateTime.now().add(const Duration(hours: 2));
    
    // Add Immediate Notification
    NotificationService().addImmediate(
      title: "Booking Confirmed! 🎉",
      body: "Meeting scheduled for ${meetingTime.hour}:${meetingTime.minute.toString().padLeft(2, '0')}.",
      bookingId: _pendingBookingId,
      type: NotificationType.confirmed,
    );

    // Schedule 1 hour before meeting alarm notification
    final alarmTime = meetingTime.subtract(const Duration(hours: 1));
    NotificationService().schedule(
      title: "⏰ Upcoming Meeting Alarm",
      body: "Your Servista appointment starts in 1 hour.",
      fireAt: alarmTime,
      bookingId: _pendingBookingId,
    );

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text("⏰ Alarm set for ${alarmTime.hour}:${alarmTime.minute.toString().padLeft(2, '0')} (1 hour before meeting)"),
        backgroundColor: Colors.green,
      ),
    );
  }

  // ─── Cancel Booking ─────────────────────────────────────
  void _cancelBooking() {
    if (_pendingBookingId == null) return;
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("Cancel Request?"),
        content: const Text("Are you sure you want to cancel this service request?"),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("No")),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(ctx);
              try {
                await ApiService.respondToBooking(_pendingBookingId!, "reject");
                NotificationService().cancelForBooking(_pendingBookingId!);
                setState(() {
                  _bookingStatus = "";
                  _pendingBookingId = null;
                  _messages.insert(0, {'text': "Request cancelled.", 'isUser': false});
                });
                _statusPoller?.cancel();
              } catch (e) {
                ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Cancel failed: $e')));
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white),
            child: const Text("Yes, Cancel"),
          ),
        ],
      ),
    );
  }

  // ─── Show Notifications Drawer ───────────────────────────
  void _showNotificationsPanel() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) {
        final notifications = NotificationService().history;
        return StatefulBuilder(
          builder: (context, setSheetState) {
            return Container(
              height: MediaQuery.of(ctx).size.height * 0.5,
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Container(width: 40, height: 4, margin: const EdgeInsets.only(bottom: 16),
                      decoration: BoxDecoration(color: Colors.grey.shade300, borderRadius: BorderRadius.circular(2))),
                  ),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text("Scheduled Alarms", style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                      if (notifications.isNotEmpty)
                        TextButton(
                          onPressed: () {
                            setState(() {
                              NotificationService().markAllRead();
                            });
                            setSheetState(() {});
                          },
                          child: const Text("Clear All"),
                        ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Expanded(
                    child: notifications.isEmpty
                      ? const Center(child: Text("No notification alarms scheduled yet.", style: TextStyle(color: Colors.grey)))
                      : ListView.builder(
                          itemCount: notifications.length,
                          itemBuilder: (_, i) {
                            final n = notifications[i];
                            return Card(
                              margin: const EdgeInsets.only(bottom: 8),
                              child: ListTile(
                                leading: CircleAvatar(
                                  backgroundColor: n.color.withValues(alpha: 0.1),
                                  child: Icon(n.icon, color: n.color),
                                ),
                                title: Text(n.title, style: const TextStyle(fontWeight: FontWeight.bold)),
                                subtitle: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(n.body),
                                    const SizedBox(height: 4),
                                    Text("${n.time.hour}:${n.time.minute.toString().padLeft(2, '0')}", style: const TextStyle(fontSize: 10, color: Colors.grey)),
                                  ],
                                ),
                                trailing: n.bookingId != null && _bookingStatus == "CONFIRMED"
                                  ? TextButton(
                                      onPressed: () {
                                        Navigator.pop(ctx);
                                        _cancelBooking();
                                      },
                                      child: const Text("Cancel Booking", style: TextStyle(color: Colors.red)),
                                    )
                                  : null,
                              ),
                            );
                          },
                        ),
                  ),
                ],
              ),
            );
          }
        );
      },
    );
  }

  // ─── Rating Dialog ──────────────────────────────────────
  void _showRatingDialog() {
    int selectedRating = 5;
    final reviewController = TextEditingController();

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: const Text("Rate Your Experience", textAlign: TextAlign.center),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text("How was the service?", style: TextStyle(color: Colors.grey)),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(5, (i) {
                  return GestureDetector(
                    onTap: () => setDialogState(() => selectedRating = i + 1),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 4),
                      child: Icon(
                        i < selectedRating ? Icons.star : Icons.star_border,
                        color: Colors.orange,
                        size: 36,
                      ),
                    ),
                  );
                }),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: reviewController,
                decoration: InputDecoration(
                  hintText: "Write a short review...",
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  filled: true,
                  fillColor: Colors.grey.shade100,
                ),
                maxLines: 3,
              ),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("Skip")),
            ElevatedButton(
              onPressed: () async {
                try {
                  await ApiService.submitReview(_pendingBookingId!, selectedRating.toDouble(), reviewController.text);
                  if (ctx.mounted) Navigator.pop(ctx);
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text("⭐ Review submitted! Thank you.")),
                    );
                    setState(() {
                      _bookingStatus = "";
                      _pendingBookingId = null;
                    });
                  }
                } catch (e) {
                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Review failed: $e')));
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF1a56db),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              child: const Text("Submit"),
            ),
          ],
        ),
      ),
    );
  }

  // ─── BUILD ──────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Servista", style: TextStyle(color: Color(0xFF1a56db), fontWeight: FontWeight.bold, fontSize: 24)),
        centerTitle: true,
        backgroundColor: Colors.white,
        elevation: 0,
        leading: const Padding(
          padding: EdgeInsets.all(8.0),
          child: CircleAvatar(backgroundImage: NetworkImage('https://i.pravatar.cc/150?img=11')),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.notifications_outlined, color: Color(0xFF1a56db)),
            onPressed: _showNotificationsPanel,
          ),
        ],
      ),
      backgroundColor: Colors.grey[50],
      body: Column(
        children: [
          // Active booking status bar
          if (_pendingBookingId != null && _bookingStatus.isNotEmpty)
            _buildStatusBar(),

          // Chat messages
          Expanded(
            child: ListView.builder(
              reverse: true,
              padding: const EdgeInsets.all(16),
              itemCount: _messages.length,
              itemBuilder: (ctx, i) {
                final msg = _messages[i];
                final isUser = msg['isUser'] as bool;

                // Thinking indicator
                if (msg.containsKey('isThinking')) {
                  return Align(
                    alignment: Alignment.centerLeft,
                    child: Container(
                      margin: const EdgeInsets.only(bottom: 8, right: 60),
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 4, offset: Offset(0, 2))],
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          SizedBox(
                            width: 20, height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2, color: const Color(0xFF1a56db).withValues(alpha: 0.6)),
                          ),
                          const SizedBox(width: 12),
                          const Text("AI Reasoning...", style: TextStyle(color: Colors.grey, fontStyle: FontStyle.italic)),
                        ],
                      ),
                    ),
                  );
                }

                // AI reasoning steps
                if (msg.containsKey('isStep')) {
                  final steps = msg['steps'] as List<String>;
                  return Align(
                    alignment: Alignment.centerLeft,
                    child: Container(
                      margin: const EdgeInsets.only(bottom: 8, right: 40),
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF0F4FF),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: const Color(0xFF1a56db).withValues(alpha: 0.2)),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Row(
                            children: [
                              Icon(Icons.psychology, size: 16, color: Color(0xFF1a56db)),
                              SizedBox(width: 6),
                              Text("AI Reasoning...", style: TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF1a56db), fontSize: 13)),
                            ],
                          ),
                          const SizedBox(height: 8),
                          ...steps.map((s) => Padding(
                            padding: const EdgeInsets.only(bottom: 4),
                            child: Text(s, style: const TextStyle(fontSize: 13, color: Colors.black87)),
                          )),
                        ],
                      ),
                    ),
                  );
                }

                // Reasoning panel
                if (msg.containsKey('isReasoning') && msg['isReasoning'] == true) {
                  return Align(
                    alignment: Alignment.centerLeft,
                    child: Padding(
                      padding: const EdgeInsets.only(bottom: 8.0, right: 40.0),
                      child: ReasoningPanel(reasoning: msg['reasoning'] as BookingReasoning),
                    ),
                  );
                }

                // Normal message bubble
                return Align(
                  alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
                  child: Container(
                    margin: EdgeInsets.only(bottom: 8, left: isUser ? 40.0 : 0.0, right: isUser ? 0.0 : 40.0),
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    decoration: BoxDecoration(
                      color: isUser ? const Color(0xFF1a56db) : Colors.white,
                      borderRadius: BorderRadius.only(
                        topLeft: const Radius.circular(16),
                        topRight: const Radius.circular(16),
                        bottomLeft: Radius.circular(isUser ? 16 : 0),
                        bottomRight: Radius.circular(isUser ? 0 : 16),
                      ),
                      boxShadow: isUser ? [] : [const BoxShadow(color: Colors.black12, blurRadius: 4, offset: Offset(0, 2))],
                    ),
                    child: Text(
                      msg['text'] as String,
                      style: TextStyle(color: isUser ? Colors.white : Colors.black87, fontSize: 15),
                    ),
                  ),
                );
              },
            ),
          ),

          // Loading indicator
          if (_isLoading)
            const Padding(padding: EdgeInsets.all(8.0), child: LinearProgressIndicator()),

          // Provider cards
          if (_pendingProviders != null)
            Container(
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
                boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 10, offset: Offset(0, -5))],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Padding(
                    padding: EdgeInsets.fromLTRB(16, 16, 16, 8),
                    child: Text("Recommended Providers", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: Color(0xFF1a56db))),
                  ),
                  ConstrainedBox(
                    constraints: const BoxConstraints(maxHeight: 220),
                    child: ListView.builder(
                      shrinkWrap: true,
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      itemCount: _pendingProviders!.length,
                      itemBuilder: (ctx, i) {
                        final p = _pendingProviders![i]['provider_info'];
                        return Container(
                          margin: const EdgeInsets.only(bottom: 12),
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: Colors.grey.shade200),
                            boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 4, offset: Offset(0, 2))],
                          ),
                          child: Row(
                            children: [
                              CircleAvatar(
                                radius: 24,
                                backgroundImage: NetworkImage('https://i.pravatar.cc/150?u=${p['uid']}'),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(p['full_name'] ?? 'Provider', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                                    const SizedBox(height: 2),
                                    Row(children: [
                                      const Icon(Icons.star, color: Colors.orange, size: 14),
                                      Text(" ${p['rating']}  ·  ${_pendingProviders![i]['distance_km']} km",
                                          style: const TextStyle(color: Colors.grey, fontSize: 12)),
                                    ]),
                                  ],
                                ),
                              ),
                              ElevatedButton(
                                onPressed: () => _selectProvider(p['uid']),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: const Color(0xFF1a56db),
                                  foregroundColor: Colors.white,
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                                ),
                                child: const Text('Book Now', style: TextStyle(fontSize: 13)),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),

          // Quick action chips
          if (_messages.length <= 2 && _pendingProviders == null && _pendingBookingId == null)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 4.0),
              child: Wrap(
                spacing: 8.0,
                children: [
                  _buildQuickChip("🔧 AC Repair", "AC not cooling, need repair today in F-8"),
                  _buildQuickChip("🔌 Electrician", "Bijli ka masla hai, electrician bhejo"),
                  _buildQuickChip("🚿 Plumber", "Pipe leak in bathroom, need plumber"),
                  _buildQuickChip("📚 Tutor", "Bache ke liye math tutor chahiye"),
                ],
              ),
            ),

          // Input bar
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
            color: Colors.white,
            child: Row(
              children: [
                GestureDetector(
                  onTap: _toggleVoice,
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 300),
                    width: 42,
                    height: 42,
                    decoration: BoxDecoration(
                      color: _isListening ? Colors.red : const Color(0xFF1a56db),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      _isListening ? Icons.stop : Icons.mic,
                      color: Colors.white,
                      size: 22,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: TextField(
                    controller: _controller,
                    decoration: InputDecoration(
                      hintText: "Type or tap mic...",
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(24),
                        borderSide: BorderSide.none,
                      ),
                      filled: true,
                      fillColor: Colors.grey.shade100,
                      contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                    ),
                    onSubmitted: (_) => _sendMessage(),
                  ),
                ),
                const SizedBox(width: 8),
                CircleAvatar(
                  backgroundColor: const Color(0xFF1a56db),
                  child: IconButton(
                    icon: const Icon(Icons.send, color: Colors.white, size: 20),
                    onPressed: _sendMessage,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildQuickChip(String label, String query) {
    return ActionChip(
      label: Text(label, style: const TextStyle(fontSize: 12)),
      backgroundColor: const Color(0xFFF0F4FF),
      side: BorderSide(color: const Color(0xFF1a56db).withValues(alpha: 0.3)),
      onPressed: () {
        _controller.text = query;
        _sendMessage();
      },
    );
  }

  Widget _buildStatusBar() {
    Color bgColor;
    String label;
    IconData icon;
    List<Widget> actions = [];

    switch (_bookingStatus) {
      case "PENDING":
        bgColor = Colors.orange;
        label = "⏳ Waiting for provider response...";
        icon = Icons.hourglass_top;
        actions = [
          TextButton(
            onPressed: _cancelBooking,
            child: const Text("Cancel", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          ),
        ];
        break;
      case "CONFIRMED":
        bgColor = Colors.green;
        label = "✅ Provider confirmed!";
        icon = Icons.check_circle;
        actions = [
          TextButton(
            onPressed: () {
              Navigator.push(context, MaterialPageRoute(
                builder: (_) => LiveChatScreen(
                  bookingId: _pendingBookingId!,
                  userId: "customer_123",
                  userRole: "customer",
                ),
              ));
            },
            child: const Text("Open Chat", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          ),
        ];
        break;
      case "COMPLETED":
        bgColor = const Color(0xFF1a56db);
        label = "🎉 Service completed!";
        icon = Icons.star;
        actions = [
          TextButton(
            onPressed: _showRatingDialog,
            child: const Text("Rate Now", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          ),
        ];
        break;
      default:
        bgColor = Colors.grey;
        label = _bookingStatus;
        icon = Icons.info;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      color: bgColor,
      child: Row(
        children: [
          Icon(icon, color: Colors.white, size: 20),
          const SizedBox(width: 8),
          Expanded(child: Text(label, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600))),
          ...actions,
        ],
      ),
    );
  }
}
