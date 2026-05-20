import 'package:flutter/material.dart';
import '../../data/services/api_service.dart';
import '../shared/reasoning_panel.dart';
import 'provider_timer_widget.dart';

class ChatScreen extends StatefulWidget {
  const ChatScreen({Key? key}) : super(key: key);

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final TextEditingController _controller = TextEditingController();
  final List<Map<String, dynamic>> _messages = [];
  bool _isLoading = false;

  Map<String, dynamic>? _currentParsedRequest;
  BookingReasoning? _currentReasoning;
  List<dynamic>? _pendingProviders;
  
  // Timer State
  DateTime? _timerDeadline;
  String? _pendingBookingId;

  void _sendMessage() async {
    final text = _controller.text.trim();
    if (text.isEmpty) return;

    // Extract up to 6 previous messages for context
    final historyToSend = _messages.take(6).map((m) {
      return {
        'role': (m['isUser'] as bool) ? 'user' : 'assistant',
        'content': m['text'] as String
      };
    }).toList().reversed.toList();

    setState(() {
      _messages.insert(0, {'text': text, 'isUser': true});
      _isLoading = true;
      _controller.clear();
      _currentReasoning = null;
      _pendingProviders = null;
      _timerDeadline = null;
      _pendingBookingId = null;
    });

    try {
      final response = await ApiService.sendChatMessage("user_123", text, history: historyToSend);
      
      if (response['status'] == 'success') {
        final reasoningData = response['reasoning'];
        if (reasoningData != null && reasoningData['recommended_two'] != null) {
          final recs = reasoningData['recommended_two'];
          
          setState(() {
            _currentParsedRequest = response['parsed_request'];
            
            final newReasoning = BookingReasoning(
              option1: ReasoningOption(
                providerId: recs[0]['provider_id'],
                headline: recs[0]['headline'] ?? '',
                reasoning: recs[0]['reasoning'] ?? '',
                tradeoff: recs[0]['tradeoff'] ?? ''
              ),
              option2: recs.length > 1 ? ReasoningOption(
                providerId: recs[1]['provider_id'],
                headline: recs[1]['headline'] ?? '',
                reasoning: recs[1]['reasoning'] ?? '',
                tradeoff: recs[1]['tradeoff'] ?? ''
              ) : ReasoningOption(providerId: '', headline: '', reasoning: '', tradeoff: ''),
              whyOthersExcluded: reasoningData['why_others_excluded'] ?? ''
            );
            
            _currentReasoning = newReasoning;
            _pendingProviders = response['recommended_providers'];
            
            // Insert reasoning bubble into chat
            _messages.insert(0, {'isReasoning': true, 'reasoning': newReasoning, 'isUser': false});
          });
        }
      } else {
        setState(() {
          _messages.insert(0, {'text': response['message'] ?? 'Something went wrong', 'isUser': false});
        });
      }
    } catch (e) {
      setState(() {
         _messages.insert(0, {'text': 'Error connecting to AI: $e', 'isUser': false});
      });
    } finally {
      setState(() => _isLoading = false);
    }
  }

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
        _timerDeadline = DateTime.parse(res['deadline']); 
        _pendingProviders = null; 
        _messages.insert(0, {'text': "Request sent! Provider has 3 minutes to confirm ⏱", 'isUser': false});
      });
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed to create booking: $e')));
    }
  }



  void _handleTimerExpired() async {
    setState(() {
      _messages.insert(0, {'text': "⏱ Providers didn't respond in time. Searching for new ones...", 'isUser': false});
      _timerDeadline = null;
      _pendingBookingId = null;
    });
    
    if (_currentParsedRequest != null && _pendingProviders != null) {
      List<String> excluded = _pendingProviders!.map<String>((p) => p['provider_info']['uid'].toString()).toList();
      
      try {
        final response = await ApiService.sendChatMessage(
          "user_123", 
          "Find other providers", 
          excludedProviders: excluded,
          parsedOverride: _currentParsedRequest
        );
        
        if (response['status'] == 'success') {
          setState(() {
            _currentParsedRequest = response['parsed_request'];
            final reasoningData = response['reasoning'];
            if (reasoningData != null && reasoningData['recommended_two'] != null) {
              final recs = reasoningData['recommended_two'];
              _currentReasoning = BookingReasoning(
                option1: ReasoningOption(
                  providerId: recs[0]['provider_id'],
                  headline: recs[0]['headline'] ?? '',
                  reasoning: recs[0]['reasoning'] ?? '',
                  tradeoff: recs[0]['tradeoff'] ?? ''
                ),
                option2: recs.length > 1 ? ReasoningOption(
                  providerId: recs[1]['provider_id'],
                  headline: recs[1]['headline'] ?? '',
                  reasoning: recs[1]['reasoning'] ?? '',
                  tradeoff: recs[1]['tradeoff'] ?? ''
                ) : ReasoningOption(providerId: '', headline: '', reasoning: '', tradeoff: ''),
                whyOthersExcluded: reasoningData['why_others_excluded'] ?? ''
              );
              _messages.insert(0, {'isReasoning': true, 'reasoning': _currentReasoning, 'isUser': false});
            }
            _pendingProviders = response['providers'];
          });
        } else if (response['status'] == 'no_providers') {
          setState(() {
             _messages.insert(0, {'text': response['message'], 'isUser': false});
          });
        }
      } catch (e) {
        setState(() {
          _messages.insert(0, {'text': 'Error finding new providers: $e', 'isUser': false});
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Row(children: [
          CircleAvatar(child: Text("K", style: TextStyle(fontSize: 14)), radius: 14),
          SizedBox(width: 8),
          Text("Karobar AI"),
        ]),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
      ),
      body: Column(
        children: [
          if (_timerDeadline != null && _pendingBookingId != null)
             ProviderTimerWidget(
               deadline: _timerDeadline!, 
               bookingId: _pendingBookingId!, 
               onExpired: _handleTimerExpired
             ),
             
          Expanded(
            child: ListView.builder(
              reverse: true,
              padding: const EdgeInsets.all(16),
              itemCount: _messages.length,
              itemBuilder: (ctx, i) {
                final msg = _messages[i];
                final isUser = msg['isUser'] as bool;
                
                if (msg.containsKey('isReasoning') && msg['isReasoning'] == true) {
                  return Align(
                    alignment: Alignment.centerLeft,
                    child: Padding(
                      padding: const EdgeInsets.only(bottom: 8.0, right: 40.0),
                      child: ReasoningPanel(reasoning: msg['reasoning'] as BookingReasoning),
                    )
                  );
                }
                
                return Align(
                  alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
                  child: Container(
                    margin: EdgeInsets.only(bottom: 8, left: isUser ? 40.0 : 0.0, right: isUser ? 0.0 : 40.0),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: isUser ? Colors.deepPurple[100] : Colors.grey[200],
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(msg['text'] as String),
                  ),
                );
              },
            ),
          ),
          
          if (_isLoading) const Padding(padding: EdgeInsets.all(8.0), child: CircularProgressIndicator()),
          
          if (_pendingProviders != null)
            SizedBox(
              height: 145,
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                itemCount: _pendingProviders!.length,
                itemBuilder: (ctx, i) {
                   final p = _pendingProviders![i]['provider_info'];
                   return Card(
                     margin: const EdgeInsets.all(8),
                     child: Container(
                       padding: const EdgeInsets.all(8),
                       width: 200,
                       child: Column(
                         crossAxisAlignment: CrossAxisAlignment.start,
                         children: [
                           Text(p['full_name'], style: const TextStyle(fontWeight: FontWeight.bold)),
                           Text("${p['rating']} ⭐ | PKR ${p['base_rate']}"),
                            Text("${_pendingProviders![i]['distance_km']} km away", style: const TextStyle(color: Colors.grey, fontSize: 12)),
                           const Spacer(),
                           ElevatedButton(
                             onPressed: () => _selectProvider(p['uid']),
                             child: const Text('Select Provider'),
                           )
                         ]
                       )
                     )
                   );
                }
              )
            ),
            
          if (_messages.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 4.0),
              child: Wrap(
                spacing: 8.0,
                children: [
                  ActionChip(
                    label: const Text("AC Repair"),
                    onPressed: () {
                      _controller.text = "AC not cooling, need repair today.";
                      _sendMessage();
                    },
                  ),
                  ActionChip(
                    label: const Text("Plumber"),
                    onPressed: () {
                      _controller.text = "Leaking pipe in bathroom.";
                      _sendMessage();
                    },
                  ),
                ],
              ),
            ),
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: Row(
              children: [
                IconButton(
                  icon: const Icon(Icons.mic, color: Colors.deepPurple),
                  onPressed: () {
                    // Simulate voice input for hackathon demo
                    _controller.text = "Mujhe kal subah G-13 mein AC technician chahiye";
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text("Voice converted to text!"), duration: Duration(seconds: 1)),
                    );
                  },
                ),
                Expanded(
                  child: TextField(
                    controller: _controller,
                    decoration: const InputDecoration(
                      hintText: "Mujhe AC repair karwana hai...",
                      border: OutlineInputBorder(),
                    ),
                    onSubmitted: (_) => _sendMessage(),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.send),
                  onPressed: _sendMessage,
                )
              ],
            ),
          )
        ],
      ),
    );
  }
}
