import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

import '../../l10n/l10n.dart';
import '../../logic/custom_level.dart';

/// Scans a level QR code with the camera and closes with its tubes.
///
/// Only Decant level codes are accepted; any other QR code shows a hint and
/// scanning carries on. The camera image never leaves the phone.
class QrScanScreen extends StatefulWidget {
  const QrScanScreen({super.key});

  /// The first Decant level among scanned QR values, or null.
  static List<List<int>>? levelIn(Iterable<String?> values) {
    for (final value in values) {
      if (value == null) continue;
      final tubes = CustomLevel.decode(value);
      if (tubes != null) return tubes;
    }
    return null;
  }

  @override
  State<QrScanScreen> createState() => _QrScanScreenState();
}

class _QrScanScreenState extends State<QrScanScreen> {
  final _controller = MobileScannerController(
    formats: const [BarcodeFormat.qrCode],
    detectionSpeed: DetectionSpeed.noDuplicates,
  );
  bool _wrongCode = false;
  bool _done = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _onDetect(BarcodeCapture capture) {
    if (_done) return;
    final tubes = QrScanScreen.levelIn(capture.barcodes.map((b) => b.rawValue));
    if (tubes != null) {
      _done = true;
      Navigator.of(context).pop(tubes);
      return;
    }
    if (!_wrongCode) setState(() => _wrongCode = true);
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        fit: StackFit.expand,
        children: [
          MobileScanner(
            controller: _controller,
            onDetect: _onDetect,
            errorBuilder: (context, error) => _ScanError(
              message:
                  error.errorCode == MobileScannerErrorCode.permissionDenied
                      ? l.scanNoPermission
                      : l.scanUnavailable,
            ),
          ),
          const IgnorePointer(child: _Viewfinder()),
          SafeArea(
            child: Column(
              children: [
                Align(
                  alignment: Alignment.centerLeft,
                  child: IconButton(
                    tooltip: MaterialLocalizations.of(context).closeButtonLabel,
                    icon: const Icon(Icons.close_rounded, color: Colors.white),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ),
                const Spacer(),
                Padding(
                  padding: const EdgeInsets.fromLTRB(32, 0, 32, 32),
                  child: Text(
                    _wrongCode ? l.scanWrongCode : l.scanHelp,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      shadows: [Shadow(blurRadius: 8)],
                    ),
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

/// A rounded square guide over the dimmed camera view.
class _Viewfinder extends StatelessWidget {
  const _Viewfinder();

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, box) {
        final side = (box.biggest.shortestSide * 0.68).clamp(160.0, 320.0);
        return Center(
          child: Container(
            width: side,
            height: side,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(28),
              border: Border.all(color: Colors.white, width: 3),
              boxShadow: const [
                // A huge spread darkens everything outside the square.
                BoxShadow(color: Color(0x88000000), spreadRadius: 2000),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _ScanError extends StatelessWidget {
  final String message;

  const _ScanError({required this.message});

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: Colors.black,
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.no_photography_rounded,
                color: Colors.white70,
                size: 48,
              ),
              const SizedBox(height: 16),
              Text(
                message,
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.white, fontSize: 15),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
