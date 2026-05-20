import 'package:flutter/material.dart';
import 'dart:async';
import '../../data/services/api_service.dart';

class ProviderDashboard extends StatefulWidget {
  final String providerId;

  const ProviderDashboard({Key? key, required this.providerId}) : super(key: key);

  @override
  State<ProviderDashboard> createState() => _ProviderDashboardState();
}

class _ProviderDashboardState extends State<ProviderDashboard> {
  List<dynamic> _pendingJobs = [];
  Timer? _pollingTimer;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchJobs();
    // Poll every 5 seconds for incoming jobs
    _pollingTimer = Timer.periodic(const Duration(seconds: 5), (_) => _fetchJobs());
  }

  @override
  void dispose() {
    _pollingTimer?.cancel();
    super.dispose();
  }

  Future<void> _fetchJobs() async {
    try {
      final jobs = await ApiService.getPendingBookings(widget.providerId);
      if (mounted) {
        setState(() {
          _pendingJobs = jobs;
          _isLoading = false;
        });
      }
    } catch (e) {
      print("Error fetching jobs: $e");
    }
  }

  Future<void> _respond(String bookingId, String action) async {
    try {
      final success = await ApiService.respondToBooking(bookingId, action);
      if (success) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Successfully ${action}ed job!')),
        );
        _fetchJobs();
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Provider Dashboard"),
        backgroundColor: Colors.deepPurple,
        foregroundColor: Colors.white,
      ),
      body: _isLoading 
        ? const Center(child: CircularProgressIndicator())
        : _pendingJobs.isEmpty
          ? const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.check_circle_outline, size: 80, color: Colors.green),
                  SizedBox(height: 16),
                  Text("You're all caught up!", style: TextStyle(fontSize: 20, color: Colors.grey)),
                  Text("Waiting for new service requests...", style: TextStyle(color: Colors.grey)),
                ],
              ),
            )
          : ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: _pendingJobs.length,
              itemBuilder: (ctx, i) {
                final job = _pendingJobs[i];
                final req = job['request_data'];
                return Card(
                  elevation: 4,
                  margin: const EdgeInsets.only(bottom: 16),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(req['service_type'] ?? 'Unknown Service', 
                              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                color: job['status'] == 'CONFIRMED' ? Colors.green : Colors.orange,
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Text(
                                job['status'] == 'CONFIRMED' ? "CONFIRMED" : "NEW", 
                                style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold)
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Row(children: [
                          const Icon(Icons.location_on, size: 16, color: Colors.grey),
                          const SizedBox(width: 4),
                          Text(req['location'] ?? 'Unknown Location'),
                        ]),
                        const SizedBox(height: 4),
                        Row(children: [
                          const Icon(Icons.access_time, size: 16, color: Colors.grey),
                          const SizedBox(width: 4),
                          Text("${req['date']} - ${req['time_preference']}"),
                        ]),
                        if (job['status'] == 'PENDING' && job['deadline'] != null)
                          Padding(
                            padding: const EdgeInsets.only(top: 8),
                            child: StreamBuilder(
                              stream: Stream.periodic(const Duration(seconds: 1)),
                              builder: (context, snapshot) {
                                final deadline = DateTime.parse(job['deadline']).toLocal();
                                final now = DateTime.now();
                                final diff = deadline.difference(now);
                                if (diff.isNegative) {
                                  return const Text("Time expired", style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold));
                                }
                                return Text(
                                  "Respond within: ${diff.inMinutes}:${(diff.inSeconds % 60).toString().padLeft(2, '0')}",
                                  style: const TextStyle(color: Colors.red, fontWeight: FontWeight.bold),
                                );
                              },
                            ),
                          ),
                        const SizedBox(height: 16),
                        if (job['status'] == 'PENDING')
                          Row(
                            children: [
                              Expanded(
                                child: OutlinedButton(
                                  onPressed: () => _respond(job['id'], "reject"),
                                  style: OutlinedButton.styleFrom(foregroundColor: Colors.red),
                                  child: const Text("Reject"),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: OutlinedButton(
                                  onPressed: () => _respond(job['id'], "renegotiate"),
                                  style: OutlinedButton.styleFrom(foregroundColor: Colors.orange),
                                  child: const Text("Renegotiate"),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: ElevatedButton(
                                  onPressed: () => _respond(job['id'], "accept"),
                                  style: ElevatedButton.styleFrom(backgroundColor: Colors.green, foregroundColor: Colors.white),
                                  child: const Text("Accept"),
                                ),
                              ),
                            ],
                          )
                        else if (job['status'] == 'CONFIRMED')
                          SizedBox(
                            width: double.infinity,
                            child: ElevatedButton(
                              onPressed: () => _respond(job['id'], "complete"),
                              style: ElevatedButton.styleFrom(backgroundColor: Colors.blue, foregroundColor: Colors.white),
                              child: const Text("Mark Service Completed"),
                            ),
                          ),
                      ],
                    ),
                  ),
                );
              },
            ),
    );
  }
}
