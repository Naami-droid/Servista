import 'package:flutter/material.dart';
import 'dart:async';
import '../../data/services/api_service.dart';

class LiveChatScreen extends StatefulWidget {
  final String bookingId;
  final String userId;
  final String userRole; // 'customer' or 'provider'

  const LiveChatScreen({
    Key? key,
    required this.bookingId,
    required this.userId,
    required this.userRole,
  }) : super(key: key);

  @override
  State<LiveChatScreen> createState() => _LiveChatScreenState();
}

class _LiveChatScreenState extends State<LiveChatScreen> {
  final TextEditingController _textController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  List<dynamic> _messages = [];
  Timer? _pollingTimer;

  @override
  void initState() {
    super.initState();
    _fetchMessages();
    _pollingTimer = Timer.periodic(const Duration(seconds: 3), (_) => _fetchMessages());
  }

  @override
  void dispose() {
    _pollingTimer?.cancel();
    _textController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _fetchMessages() async {
    try {
      final messages = await ApiService.getMessages(widget.bookingId);
      if (mounted) {
        setState(() {
          _messages = messages;
        });
        _scrollToBottom();
      }
    } catch (e) {
      print("Error fetching messages: $e");
    }
  }

  void _scrollToBottom() {
    if (_scrollController.hasClients) {
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
    }
  }

  Future<void> _sendMessage() async {
    final text = _textController.text.trim();
    if (text.isEmpty) return;

    _textController.clear();
    // Optimistic UI update
    setState(() {
      _messages.add({
        'sender_role': widget.userRole,
        'text': text,
      });
    });
    _scrollToBottom();

    try {
      await ApiService.sendMessage(widget.bookingId, widget.userId, widget.userRole, text);
      _fetchMessages();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Failed to send message: $e")));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 1,
        iconTheme: const IconThemeData(color: Color(0xFF1a56db)),
        title: Row(
          children: [
            const CircleAvatar(
              backgroundImage: NetworkImage('https://i.pravatar.cc/150?img=33'),
              radius: 18,
            ),
            const SizedBox(width: 12),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(widget.userRole == 'customer' ? "Ahmed Khan" : "Customer", style: const TextStyle(color: Colors.black87, fontSize: 16, fontWeight: FontWeight.bold)),
                const Row(
                  children: [
                    Icon(Icons.circle, color: Colors.green, size: 10),
                    SizedBox(width: 4),
                    Text("Online", style: TextStyle(color: Colors.green, fontSize: 12)),
                  ],
                ),
              ],
            ),
          ],
        ),
        actions: [
          IconButton(icon: const Icon(Icons.call_outlined), onPressed: () {}),
          IconButton(icon: const Icon(Icons.more_vert), onPressed: () {}),
        ],
      ),
      backgroundColor: Colors.grey[50],
      body: Column(
        children: [
          Expanded(
            child: ListView.builder(
              controller: _scrollController,
              padding: const EdgeInsets.all(16),
              itemCount: _messages.length,
              itemBuilder: (context, index) {
                final msg = _messages[index];
                final isMe = msg['sender_role'] == widget.userRole;
                return Align(
                  alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
                  child: Container(
                    margin: EdgeInsets.only(bottom: 8, top: 8, left: isMe ? 40.0 : 0.0, right: isMe ? 0.0 : 40.0),
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    decoration: BoxDecoration(
                      color: isMe ? const Color(0xFF1a56db) : Colors.white,
                      borderRadius: BorderRadius.only(
                        topLeft: const Radius.circular(16),
                        topRight: const Radius.circular(16),
                        bottomLeft: Radius.circular(isMe ? 16 : 0),
                        bottomRight: Radius.circular(isMe ? 0 : 16),
                      ),
                      boxShadow: isMe ? [] : [BoxShadow(color: Colors.black12, blurRadius: 4, offset: const Offset(0, 2))],
                    ),
                    child: Text(
                      msg['text'] ?? '',
                      style: TextStyle(
                        color: isMe ? Colors.white : Colors.black87,
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
            color: Colors.white,
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _textController,
                    decoration: InputDecoration(
                      hintText: "Type a message...",
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
                    icon: const Icon(Icons.send, color: Colors.white),
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
}
