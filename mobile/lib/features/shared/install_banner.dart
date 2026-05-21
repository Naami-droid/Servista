import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'web_utils.dart';

class InstallBanner extends StatefulWidget {
  const InstallBanner({Key? key}) : super(key: key);

  @override
  State<InstallBanner> createState() => _InstallBannerState();
}

class _InstallBannerState extends State<InstallBanner> {
  bool _showBanner = false;

  @override
  void initState() {
    super.initState();
    if (kIsWeb) {
      _showBanner = checkAppInstallable();

      registerInstallCallback(() {
        if (mounted) {
          setState(() {
            _showBanner = true;
          });
        }
      });
    }
  }

  void _triggerInstall() {
    if (kIsWeb) {
      triggerPWAInstall();
      setState(() {
        _showBanner = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!_showBanner) return const SizedBox.shrink();

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF1a56db), Color(0xFF3b82f6)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.15),
            blurRadius: 8,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: Row(
          children: [
            const Icon(Icons.install_mobile, color: Colors.white, size: 28),
            const SizedBox(width: 12),
            const Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    "Install Servista App",
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 15,
                    ),
                  ),
                  Text(
                    "Add to your home screen for a faster, offline-capable mobile experience.",
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            ElevatedButton(
              onPressed: _triggerInstall,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.white,
                foregroundColor: const Color(0xFF1a56db),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                minimumSize: Size.zero,
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
              child: const Text(
                "Install",
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
              ),
            ),
            IconButton(
              icon: const Icon(Icons.close, color: Colors.white, size: 20),
              onPressed: () {
                setState(() {
                  _showBanner = false;
                });
              },
            ),
          ],
        ),
      ),
    );
  }
}
