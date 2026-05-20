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
  bool _isActive = true;

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

  void _showNotifications() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) {
        final notifications = _pendingJobs.where((j) => j['status'] == 'PENDING').toList();
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
                  const Text("Notifications", style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(color: const Color(0xFF1a56db), borderRadius: BorderRadius.circular(12)),
                    child: Text("${notifications.length}", style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Expanded(
                child: notifications.isEmpty
                  ? const Center(child: Text("No new notifications", style: TextStyle(color: Colors.grey)))
                  : ListView.builder(
                      itemCount: notifications.length,
                      itemBuilder: (_, i) {
                        final job = notifications[i];
                        final req = job['request_data'] ?? {};
                        return Card(
                          margin: const EdgeInsets.only(bottom: 8),
                          child: ListTile(
                            leading: const CircleAvatar(
                              backgroundColor: Color(0xFF1a56db),
                              child: Icon(Icons.work, color: Colors.white),
                            ),
                            title: Text(req['service_type'] ?? 'New Request', style: const TextStyle(fontWeight: FontWeight.bold)),
                            subtitle: Text("📍 ${req['location'] ?? 'N/A'} · ${req['date'] ?? ''} ${req['time_preference'] ?? ''}"),
                            trailing: const Icon(Icons.chevron_right),
                            onTap: () => Navigator.pop(ctx),
                          ),
                        );
                      },
                    ),
              ),
            ],
          ),
        );
      },
    );
  }

  void _confirmCancel(String bookingId) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("Cancel Job?"),
        content: const Text("Cancelling will slightly lower your rating and reliability score. Are you sure?"),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("No, Keep")),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(ctx);
              await _respond(bookingId, "reject");
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white),
            child: const Text("Yes, Cancel"),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final pendingCount = _pendingJobs.where((j) => j['status'] == 'PENDING').length;

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
              const Text("Active", style: TextStyle(color: Colors.black87, fontSize: 12)),
              Switch(
                value: _isActive,
                onChanged: (v) => setState(() => _isActive = v),
                activeTrackColor: const Color(0xFF1a56db),
              ),
            ],
          ),
          Stack(
            children: [
              IconButton(
                icon: const Icon(Icons.notifications_outlined, color: Color(0xFF1a56db)),
                onPressed: _showNotifications,
              ),
              if (pendingCount > 0)
                Positioned(
                  right: 6, top: 6,
                  child: Container(
                    padding: const EdgeInsets.all(4),
                    decoration: const BoxDecoration(color: Colors.red, shape: BoxShape.circle),
                    child: Text("$pendingCount", style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold)),
                  ),
                ),
            ],
          ),
        ],
      ),
      backgroundColor: Colors.grey[50],
      body: _isLoading
        ? const Center(child: CircularProgressIndicator())
        : RefreshIndicator(
            onRefresh: _fetchJobs,
            child: SingleChildScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              child: Column(
                children: [
                  // Status Card
                  Container(
                    margin: const EdgeInsets.all(16),
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: _isActive
                          ? [const Color(0xFF3b82f6), const Color(0xFF1d4ed8)]
                          : [Colors.grey.shade400, Colors.grey.shade600],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Column(
                      children: [
                        const Text("PROVIDER STATUS", style: TextStyle(color: Colors.white70, fontSize: 12, fontWeight: FontWeight.bold, letterSpacing: 1.2)),
                        const SizedBox(height: 8),
                        Text(_isActive ? "Active & Ready" : "Offline", style: const TextStyle(color: Colors.white, fontSize: 32, fontWeight: FontWeight.bold)),
                        const SizedBox(height: 16),
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton(
                            onPressed: () => setState(() => _isActive = !_isActive),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.white,
                              foregroundColor: _isActive ? const Color(0xFF1a56db) : Colors.grey.shade700,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            ),
                            child: Text(_isActive ? "Go Offline" : "Go Online"),
                          ),
                        )
                      ],
                    ),
                  ),

                  // Stats Row
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16.0),
                    child: Row(
                      children: [
                        Expanded(child: _buildStatCard(Icons.star, "4.9", "Rating", Colors.amber)),
                        const SizedBox(width: 12),
                        Expanded(child: _buildStatCard(Icons.work_outline, "${_pendingJobs.length}", "Jobs", const Color(0xFF1a56db))),
                        const SizedBox(width: 12),
                        Expanded(child: _buildStatCard(Icons.verified, "98%", "Reliability", Colors.green)),
                      ],
                    ),
                  ),

                  // Recent Requests Header
                  Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text("Recent Requests", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                        Text("${_pendingJobs.length} total", style: const TextStyle(color: Colors.grey)),
                      ],
                    ),
                  ),

                  // Job Cards
                  if (!_isActive)
                    const Padding(
                      padding: EdgeInsets.all(32),
                      child: Column(
                        children: [
                          Icon(Icons.power_settings_new, size: 64, color: Colors.grey),
                          SizedBox(height: 16),
                          Text("You are offline", style: TextStyle(fontSize: 18, color: Colors.grey)),
                          Text("Toggle Active to start receiving requests", style: TextStyle(color: Colors.grey)),
                        ],
                      ),
                    )
                  else if (_pendingJobs.isEmpty)
                    const Padding(
                      padding: EdgeInsets.all(32.0),
                      child: Column(
                        children: [
                          Icon(Icons.inbox_outlined, size: 64, color: Colors.grey),
                          SizedBox(height: 16),
                          Text("No requests yet", style: TextStyle(fontSize: 18, color: Colors.grey)),
                          Text("Waiting for new service requests...", style: TextStyle(color: Colors.grey)),
                        ],
                      ),
                    )
                  else
                    ListView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      itemCount: _pendingJobs.length,
                      itemBuilder: (ctx, i) {
                        final job = _pendingJobs[i];
                        final req = job['request_data'] ?? {};
                        return Container(
                          margin: const EdgeInsets.only(bottom: 12),
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(16),
                            boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 6, offset: Offset(0, 2))],
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // Header
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Expanded(
                                    child: Text(req['service_type'] ?? 'Service Request',
                                      style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                                  ),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                    decoration: BoxDecoration(
                                      color: _statusColor(job['status']),
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: Text(
                                      _statusLabel(job['status']),
                                      style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 12),
                              // Details
                              Row(children: [
                                const Icon(Icons.location_on, size: 16, color: Colors.grey),
                                const SizedBox(width: 4),
                                Expanded(child: Text(req['location'] ?? 'Unknown Location', style: const TextStyle(color: Colors.grey))),
                              ]),
                              const SizedBox(height: 4),
                              Row(children: [
                                const Icon(Icons.access_time, size: 16, color: Colors.grey),
                                const SizedBox(width: 4),
                                Text("${req['date'] ?? 'N/A'} · ${req['time_preference'] ?? ''}", style: const TextStyle(color: Colors.grey)),
                              ]),

                              // Timer for pending jobs
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
                                        return const Text("⏱ Time expired", style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold));
                                      }
                                      return Row(
                                        children: [
                                          const Icon(Icons.timer, size: 16, color: Colors.red),
                                          const SizedBox(width: 4),
                                          Text(
                                            "Respond within: ${diff.inMinutes}:${(diff.inSeconds % 60).toString().padLeft(2, '0')}",
                                            style: const TextStyle(color: Colors.red, fontWeight: FontWeight.bold),
                                          ),
                                        ],
                                      );
                                    },
                                  ),
                                ),
                              const SizedBox(height: 16),

                              // Action Buttons by status
                              if (job['status'] == 'PENDING')
                                Row(
                                  children: [
                                    Expanded(
                                      child: OutlinedButton(
                                        onPressed: () => _respond(job['id'], "reject"),
                                        style: OutlinedButton.styleFrom(foregroundColor: Colors.red),
                                        child: const Text("Decline"),
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      flex: 2,
                                      child: ElevatedButton(
                                        onPressed: () => _respond(job['id'], "accept"),
                                        style: ElevatedButton.styleFrom(
                                          backgroundColor: const Color(0xFF1a56db),
                                          foregroundColor: Colors.white,
                                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                        ),
                                        child: const Text("Accept Job"),
                                      ),
                                    ),
                                  ],
                                )
                              else if (job['status'] == 'CONFIRMED')
                                Column(
                                  children: [
                                    Row(
                                      children: [
                                        Expanded(
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
                                            icon: const Icon(Icons.chat_bubble_outline, size: 18),
                                            label: const Text("Live Chat"),
                                            style: ElevatedButton.styleFrom(
                                              backgroundColor: const Color(0xFF1a56db),
                                              foregroundColor: Colors.white,
                                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                            ),
                                          ),
                                        ),
                                        const SizedBox(width: 8),
                                        Expanded(
                                          child: ElevatedButton.icon(
                                            onPressed: () => _respond(job['id'], "complete"),
                                            icon: const Icon(Icons.check_circle_outline, size: 18),
                                            label: const Text("Complete"),
                                            style: ElevatedButton.styleFrom(
                                              backgroundColor: Colors.green,
                                              foregroundColor: Colors.white,
                                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 8),
                                    SizedBox(
                                      width: double.infinity,
                                      child: OutlinedButton(
                                        onPressed: () => _confirmCancel(job['id']),
                                        style: OutlinedButton.styleFrom(foregroundColor: Colors.red),
                                        child: const Text("Cancel Job"),
                                      ),
                                    ),
                                  ],
                                ),
                            ],
                          ),
                        );
                      },
                    ),
                  const SizedBox(height: 24),
                ],
              ),
            ),
          ),
    );
  }

  Color _statusColor(String? status) {
    switch (status) {
      case 'CONFIRMED': return Colors.green;
      case 'COMPLETED': return Colors.blue;
      case 'REJECTED': return Colors.red;
      default: return Colors.orange;
    }
  }

  String _statusLabel(String? status) {
    switch (status) {
      case 'CONFIRMED': return 'CONFIRMED';
      case 'COMPLETED': return 'COMPLETED';
      case 'REJECTED': return 'CANCELLED';
      default: return 'NEW REQUEST';
    }
  }

  Widget _buildStatCard(IconData icon, String value, String label, Color iconColor) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 4, offset: Offset(0, 2))],
      ),
      child: Column(
        children: [
          Icon(icon, color: iconColor, size: 28),
          const SizedBox(height: 8),
          Text(value, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
          Text(label, style: const TextStyle(color: Colors.grey, fontSize: 12)),
        ],
      ),
    );
  }
}
