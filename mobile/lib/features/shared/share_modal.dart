import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter/foundation.dart';
import 'web_utils.dart';

class ShareModal extends StatelessWidget {
  const ShareModal({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    // Dynamically retrieve the current app URL, fallback to Vercel production URL if native
    final String shareUrl = kIsWeb 
        ? Uri.base.toString() 
        : "https://servista-ai.vercel.app";
        
    final String qrApiUrl = "https://api.qrserver.com/v1/create-qr-code/?size=250x250&data=${Uri.encodeComponent(shareUrl)}";

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  "Share Servista",
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Color(0xFF1a56db)),
                ),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.pop(context),
                )
              ],
            ),
            const SizedBox(height: 16),
            const Text(
              "Scan this QR code on any Android device to instantly open and install the app.",
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey, fontSize: 14),
            ),
            const SizedBox(height: 24),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.grey.shade50,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.grey.shade200),
              ),
              child: Image.network(
                qrApiUrl,
                width: 200,
                height: 200,
                loadingBuilder: (context, child, loadingProgress) {
                  if (loadingProgress == null) return child;
                  return const SizedBox(
                    width: 200,
                    height: 200,
                    child: Center(
                      child: CircularProgressIndicator(color: Color(0xFF1a56db)),
                    ),
                  );
                },
                errorBuilder: (context, error, stackTrace) {
                  return const SizedBox(
                    width: 200,
                    height: 200,
                    child: Center(
                      child: Icon(Icons.qr_code_scanner, size: 64, color: Colors.grey),
                    ),
                  );
                },
              ),
            ),
            const SizedBox(height: 16),
            SelectableText(
              shareUrl,
              textAlign: TextAlign.center,
              style: const TextStyle(fontWeight: FontWeight.w500, fontSize: 13),
            ),
            const SizedBox(height: 24),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () {
                      Clipboard.setData(ClipboardData(text: shareUrl));
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text("📋 Link copied to clipboard!"),
                          backgroundColor: Colors.green,
                        ),
                      );
                    },
                    icon: const Icon(Icons.copy, size: 18),
                    label: const Text("Copy Link"),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: const Color(0xFF1a56db),
                      side: const BorderSide(color: Color(0xFF1a56db)),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () {
                      _handleNativeShare(context, shareUrl);
                    },
                    icon: const Icon(Icons.share, size: 18),
                    label: const Text("Share Link"),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF1a56db),
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _handleNativeShare(BuildContext context, String shareUrl) {
    if (kIsWeb) {
      try {
        final bool shared = shareApp(
          'Servista AI',
          'Scan and install Servista - AI Service Finder!',
          shareUrl,
        );
        if (shared) return;
      } catch (e) {
        print("Web native share failed: $e");
      }
    }
    
    // Fallback to clipboard
    Clipboard.setData(ClipboardData(text: shareUrl));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text("📋 Web Share not supported. Link copied to clipboard instead!"),
        backgroundColor: Colors.blue,
      ),
    );
  }
}
