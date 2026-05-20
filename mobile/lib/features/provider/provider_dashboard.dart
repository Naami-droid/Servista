import 'package:flutter/material.dart';
import 'dart:async';
import '../../data/services/api_service.dart';
import '../shared/live_chat_screen.dart';

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
        title: const Text("Servista", style: TextStyle(color: Color(0xFF1a56db), fontWeight: FontWeight.bold, fontSize: 24)),
        centerTitle: true,
        backgroundColor: Colors.white,
        elevation: 0,
        leading: const Padding(
          padding: EdgeInsets.all(8.0),
          child: CircleAvatar(
            backgroundImage: NetworkImage('https://i.pravatar.cc/150?img=12'),
          ),
        ),
        actions: [
          Row(
            children: [
              const Text("Active for Jobs", style: TextStyle(color: Colors.black87, fontSize: 12)),
              Switch(value: true, onChanged: (v){}, activeColor: const Color(0xFF1a56db)),
            ],
          ),
          IconButton(
            icon: const Icon(Icons.notifications_outlined, color: Color(0xFF1a56db)),
            onPressed: () {},
          ),
        ],
      ),
      backgroundColor: Colors.grey[50],
      body: _isLoading 
        ? const Center(child: CircularProgressIndicator())
        : Column(
            children: [
              Container(
                margin: const EdgeInsets.all(16),
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: const Color(0xFF1a56db),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: const Column(
                  children: [
                    Text("PROVIDER STATUS", style: TextStyle(color: Colors.white70, fontSize: 12, fontWeight: FontWeight.bold, letterSpacing: 1.2)),
                    SizedBox(height: 8),
                    Text("Active & Ready", style: TextStyle(color: Colors.white, fontSize: 32, fontWeight: FontWeight.bold)),
                    SizedBox(height: 24),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: null,
                        child: Text("Go Offline", style: TextStyle(color: Color(0xFF1a56db))),
                      ),
                    )
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16.0),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    _buildStatCard(Icons.star_border, "4.9", "Rating", Colors.green),
                    _buildStatCard(Icons.work_outline, "124", "Jobs", const Color(0xFF1a56db)),
                    _buildStatCard(Icons.verified_outlined, "98%", "Reliability", Colors.deepOrange),
                  ],
                ),
              ),
              const Padding(
                padding: EdgeInsets.all(16.0),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Text("Recent Requests", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                ),
              ),
              Expanded(
                child: _pendingJobs.isEmpty
                  ? const Center(child: Text("Waiting for new service requests...", style: TextStyle(color: Colors.grey)))
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
                          Column(
                            children: [
                              SizedBox(
                                width: double.infinity,
                                child: ElevatedButton.icon(
                                  onPressed: () {
                                    Navigator.push(context, MaterialPageRoute(
                                      builder: (_) => LiveChatScreen(
                                        bookingId: job['id'],
                                        userId: widget.providerId,
                                        userRole: "provider",
                                      )
                                    ));
                                  },
                                  icon: const Icon(Icons.chat),
                                  label: const Text("Open Live Chat"),
                                  style: ElevatedButton.styleFrom(backgroundColor: Colors.green, foregroundColor: Colors.white),
                                ),
                              ),
                              const SizedBox(height: 8),
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
                      ],
                    ),
                  ),
                );
              },
            ),
              ),
            ],
          ),
    );
  }

  Widget _buildStatCard(IconData icon, String value, String label, Color iconColor) {
    return Container(
      width: 100,
      padding: const EdgeInsets.symmetric(vertical: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade200),
        boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 4, offset: Offset(0, 2))],
      ),
      child: Column(
        children: [
          Icon(icon, color: iconColor),
          const SizedBox(height: 8),
          Text(value, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
          Text(label, style: const TextStyle(color: Colors.grey, fontSize: 12)),
        ],
      ),
    );
  }
}
