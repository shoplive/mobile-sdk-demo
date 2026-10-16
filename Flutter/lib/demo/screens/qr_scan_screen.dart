import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

import '../data/qr_credentials.dart';
import '../l10n/demo_strings.dart';
import '../widgets/common.dart';

/// Scans a credentials QR code (the format the native test apps use) and pops with
/// a [QrCredentials]. A QR it cannot use keeps the camera open and says why.
///
/// Demo harness only — QR input is a convenience for testers, not part of the SDK
/// integration, so it lives outside `shoplive_integration/`.
class QrScanScreen extends StatefulWidget {
  const QrScanScreen({super.key});

  @override
  State<QrScanScreen> createState() => _QrScanScreenState();
}

class _QrScanScreenState extends State<QrScanScreen> {
  final MobileScannerController _scanner = MobileScannerController(formats: const [BarcodeFormat.qrCode]);
  String? _lastRaw;
  bool _rejected = false;
  bool _done = false;

  @override
  void dispose() {
    _scanner.dispose();
    super.dispose();
  }

  void _onDetect(BarcodeCapture capture) {
    if (_done) return;
    final raw = capture.barcodes.map((b) => b.rawValue).whereType<String>().firstOrNull;
    if (raw == null || raw == _lastRaw) return; // the same code is reported every frame
    _lastRaw = raw;
    final parsed = QrCredentials.parse(raw);
    if (parsed == null) {
      setState(() => _rejected = true);
      return;
    }
    _done = true;
    Navigator.of(context).pop(parsed);
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: Text(tr('qr_title'))),
    body: Stack(
      children: [
        MobileScanner(
          controller: _scanner,
          onDetect: _onDetect,
          errorBuilder:
              (context, error) => Center(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Tip(tr('qr_camera_error', [error.errorCode.name]), tone: TipTone.warn),
                ),
              ),
        ),
        // Viewfinder — a visual target only; the whole preview is scanned.
        Center(
          child: Container(
            width: 240,
            height: 240,
            decoration: BoxDecoration(
              border: Border.all(color: Colors.white, width: 3),
              borderRadius: BorderRadius.circular(16),
            ),
          ),
        ),
        Positioned(
          left: 16,
          right: 16,
          bottom: 32,
          child: Material(
            color: Theme.of(context).colorScheme.surface,
            borderRadius: BorderRadius.circular(12),
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Text(tr(_rejected ? 'qr_rejected' : 'qr_hint'), style: Theme.of(context).textTheme.bodySmall),
            ),
          ),
        ),
      ],
    ),
  );
}
