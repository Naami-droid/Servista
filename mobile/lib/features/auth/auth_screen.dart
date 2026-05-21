import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../data/services/api_service.dart';
import '../customer/chat_screen.dart';
import '../provider/provider_dashboard.dart';

class AuthScreen extends StatefulWidget {
  const AuthScreen({Key? key}) : super(key: key);

  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> {
  final _emailController = TextEditingController(text: "mrnaami2004+customer@gmail.com");
  final _passwordController = TextEditingController(text: "password123");
  bool _isProvider = false;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final savedUrl = prefs.getString('api_base_url');
      if (savedUrl != null && savedUrl.isNotEmpty) {
        if (savedUrl.contains('10.8.1.68') || savedUrl.contains('localhost') || savedUrl.contains('127.0.0.1')) {
          // Reset to production URL
          await prefs.setString('api_base_url', ApiService.baseUrl);
        } else {
          ApiService.baseUrl = savedUrl;
        }
      }
    } catch (e) {
      print("Failed to load settings: $e");
    }
  }

  void _login() async {
    final email = _emailController.text.trim();
    final password = _passwordController.text.trim();
    if (email.isEmpty || password.isEmpty) return;
    final url = ApiService.baseUrl;

    setState(() => _isLoading = true);

    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('api_base_url', url);
      ApiService.baseUrl = url;

      final role = _isProvider ? "provider" : "customer";
      await ApiService.login(email, password, role);
      
      if (!mounted) return;
      
      if (_isProvider) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => ProviderDashboard(providerId: "ALL")),
        );
      } else {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => const ChatScreen()),
        );
      }

    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.toString())),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      resizeToAvoidBottomInset: true,
      appBar: AppBar(
        title: const Text("Servista AI Service App", style: TextStyle(color: Colors.black87, fontWeight: FontWeight.bold, fontSize: 18)),
        centerTitle: true,
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(icon: const Icon(Icons.menu, color: Colors.black54), onPressed: () {}),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            children: [
              Container(
                width: double.infinity,
                height: 250,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF3b82f6), Color(0xFF1d4ed8)],
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                  ),
                  borderRadius: BorderRadius.circular(24),
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      width: 80,
                      height: 80,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: const Stack(
                        alignment: Alignment.center,
                        children: [
                          Text("N", style: TextStyle(fontSize: 48, fontWeight: FontWeight.bold, color: Color(0xFF1a56db))),
                          Positioned(
                            top: 12,
                            right: 12,
                            child: CircleAvatar(radius: 6, backgroundColor: Colors.greenAccent),
                          )
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                    const Text("Servista", style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: Colors.white)),
                  ],
                ),
              ),
              const SizedBox(height: 32),

              TextField(
                controller: _emailController,
                style: const TextStyle(fontSize: 16, color: Colors.black87),
                decoration: InputDecoration(
                  labelText: "Email",
                  labelStyle: const TextStyle(color: Colors.black54),
                  prefixIcon: const Icon(Icons.email_outlined, color: Color(0xFF1a56db)),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: Color(0xFFDDE3EE)),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: Color(0xFF1a56db), width: 2),
                  ),
                  filled: true,
                  fillColor: Colors.white,
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _passwordController,
                obscureText: true,
                style: const TextStyle(fontSize: 16, color: Colors.black87),
                decoration: InputDecoration(
                  labelText: "Password",
                  labelStyle: const TextStyle(color: Colors.black54),
                  prefixIcon: const Icon(Icons.lock_outline, color: Color(0xFF1a56db)),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: Color(0xFFDDE3EE)),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: Color(0xFF1a56db), width: 2),
                  ),
                  filled: true,
                  fillColor: Colors.white,
                ),
              ),
              const SizedBox(height: 16),
              SwitchListTile(
                title: const Text("Login as Service Provider"),
                value: _isProvider,
                activeThumbColor: const Color(0xFF1a56db),
                onChanged: (val) {
                  setState(() {
                    _isProvider = val;
                    if (val) {
                      _emailController.text = "mrnaami2004+provider1@gmail.com";
                    } else {
                      _emailController.text = "mrnaami2004+customer@gmail.com";
                    }
                  });
                },
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton(
                  onPressed: _isLoading ? null : _login,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF1a56db),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
                  ),
                  child: _isLoading 
                      ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                      : const Text("Sign In", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
