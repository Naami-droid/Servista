import 'package:flutter/material.dart';
import 'dart:async';
import '../../data/services/api_service.dart';

class ProviderTimerWidget extends StatefulWidget {
  final DateTime deadline;
  final String bookingId;
  final VoidCallback onExpired;

  const ProviderTimerWidget({
    Key? key,
    required this.deadline,
    required this.bookingId,
    required this.onExpired,
  }) : super(key: key);

  @override
  State<ProviderTimerWidget> createState() => _ProviderTimerWidgetState();
}

class _ProviderTimerWidgetState extends State<ProviderTimerWidget>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Timer _ticker;
  Timer? _statusTimer;
  int _secondsLeft = 180;
  String _status = "PENDING";

  @override
  void initState() {
    super.initState();
    _secondsLeft = widget.deadline.difference(DateTime.now()).inSeconds.clamp(0, 180);

    _controller = AnimationController(
      vsync: this,
      duration: Duration(seconds: _secondsLeft),
    )..forward();

    _ticker = Timer.periodic(const Duration(seconds: 1), (_) {
      final left = widget.deadline.difference(DateTime.now()).inSeconds;
      if (left <= 0 && _status == "PENDING") {
        _ticker.cancel();
        _statusTimer?.cancel();
        setState(() => _secondsLeft = 0);
        return;
      }
      setState(() => _secondsLeft = left);
    });

    _statusTimer = Timer.periodic(const Duration(seconds: 3), (_) async {
      if (_status != "PENDING") return;
      try {
        final status = await ApiService.getBookingStatus(widget.bookingId);
        if (status != "PENDING" && mounted) {
          setState(() {
            _status = status;
          });
          _controller.stop();
          _ticker.cancel();
          _statusTimer?.cancel();
        }
      } catch (e) {
        // ignore
      }
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    _ticker.cancel();
    super.dispose();
  }

  String get _formatted =>
      "${(_secondsLeft ~/ 60).toString().padLeft(2, '0')}:"
      "${(_secondsLeft % 60).toString().padLeft(2, '0')}";

  Color get _ringColor {
    if (_secondsLeft > 120) return Colors.green;
    if (_secondsLeft > 60)  return Colors.orange;
    return Colors.red;
  }

  void _showReviewDialog(BuildContext context) {
    double rating = 5.0;
    TextEditingController reviewController = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          title: const Text("Rate Your Service"),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text("How was your experience?"),
              const SizedBox(height: 16),
              // Simple rating simulation
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(5, (index) => const Icon(Icons.star, color: Colors.orange)),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: reviewController,
                decoration: const InputDecoration(
                  hintText: "Write a short review...",
                  border: OutlineInputBorder(),
                ),
                maxLines: 3,
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text("Cancel"),
            ),
            ElevatedButton(
              onPressed: () async {
                await ApiService.submitReview(widget.bookingId, rating, reviewController.text);
                if (ctx.mounted) {
                  Navigator.pop(ctx);
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Review submitted successfully!")));
                }
              },
              child: const Text("Submit"),
            )
          ],
        );
      }
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_status == "REJECTED") {
      return Container(
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.red.withOpacity(0.1),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.red),
        ),
        child: Column(
          children: [
             const Text("Appointment Cancelled by Provider", style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
             const SizedBox(height: 8),
             Row(
               mainAxisAlignment: MainAxisAlignment.spaceEvenly,
               children: [
                 Expanded(
                   child: ElevatedButton(
                     onPressed: widget.onExpired, // Book new with someone else
                     style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white),
                     child: const Text("Book new", textAlign: TextAlign.center)
                   ),
                 ),
                 const SizedBox(width: 8),
                 Expanded(
                   child: OutlinedButton(
                     onPressed: () {}, // Reschedule existing
                     style: OutlinedButton.styleFrom(foregroundColor: Colors.red),
                     child: const Text("Reschedule", textAlign: TextAlign.center)
                   ),
                 ),
               ],
             )
          ]
        )
      );
    } else if (_status == "RENEGOTIATING") {
      return Container(
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.orange.withOpacity(0.1),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.orange),
        ),
        child: Column(
          children: [
             const Text("Provider wants to renegotiate terms", style: TextStyle(color: Colors.orange, fontWeight: FontWeight.bold)),
             const SizedBox(height: 8),
             Row(
               mainAxisAlignment: MainAxisAlignment.spaceEvenly,
               children: [
                 Expanded(
                   child: ElevatedButton(
                     onPressed: () {
                        setState(() => _status = "CONFIRMED");
                     }, // Accept new terms
                     style: ElevatedButton.styleFrom(backgroundColor: Colors.green, foregroundColor: Colors.white),
                     child: const Text("Accept")
                   ),
                 ),
                 const SizedBox(width: 8),
                 Expanded(
                   child: OutlinedButton(
                     onPressed: widget.onExpired, // Cancel/Reject renegotiation triggers new search
                     style: OutlinedButton.styleFrom(foregroundColor: Colors.red),
                     child: const Text("Reject")
                   ),
                 ),
               ],
             )
          ]
        )
      );
    } else if (_status == "CONFIRMED") {
      return Container(
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.green.withOpacity(0.1),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.green),
        ),
        child: const Center(
          child: Text("✅ Booking Confirmed! Chat with Provider", style: TextStyle(color: Colors.green, fontWeight: FontWeight.bold)),
        )
      );
    } else if (_status == "COMPLETED") {
      return Container(
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.blue.withOpacity(0.1),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.blue),
        ),
        child: Column(
          children: [
            const Text("🎉 Service Completed!", style: TextStyle(color: Colors.blue, fontWeight: FontWeight.bold, fontSize: 16)),
            const SizedBox(height: 8),
            ElevatedButton(
              onPressed: () {
                // We'll show a review dialog
                _showReviewDialog(context);
              },
              style: ElevatedButton.styleFrom(backgroundColor: Colors.blue, foregroundColor: Colors.white),
              child: const Text("Write a Review"),
            )
          ],
        )
      );
    } else if (_secondsLeft <= 0) {
      return Container(
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.red.withOpacity(0.08),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.red.withOpacity(0.4)),
        ),
        child: Column(
          children: [
             const Text("⏱ Providers didn't respond in time.", style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
             const SizedBox(height: 8),
             ElevatedButton(
                onPressed: widget.onExpired, // Manually trigger search again
                style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white),
                child: const Text("Search Other Providers")
             )
          ]
        )
      );
    }
    
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _ringColor.withOpacity(0.08),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _ringColor.withOpacity(0.4)),
      ),
      child: Row(
        children: [
          SizedBox(
            width: 56,
            height: 56,
            child: Stack(
              fit: StackFit.expand,
              children: [
                AnimatedBuilder(
                  animation: _controller,
                  builder: (_, __) => CircularProgressIndicator(
                    value: _secondsLeft / 180,
                    strokeWidth: 5,
                    backgroundColor: Colors.grey.withOpacity(0.2),
                    valueColor: AlwaysStoppedAnimation(_ringColor),
                  ),
                ),
                Center(
                  child: Text(_formatted,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                      color: _ringColor,
                    )),
                ),
              ],
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text("Waiting for provider response",
                  style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                const SizedBox(height: 4),
                Text(
                  _secondsLeft > 60
                    ? "Provider has $_formatted to accept your request"
                    : "Time running out — will auto-find new provider",
                  style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
