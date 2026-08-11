import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

class BarcodeScanScreen extends StatefulWidget {
  const BarcodeScanScreen({required this.onResult, super.key});

  final ValueChanged<String> onResult;

  @override
  State<BarcodeScanScreen> createState() => _BarcodeScanScreenState();
}

class _BarcodeScanScreenState extends State<BarcodeScanScreen> {
  final _controller = MobileScannerController();
  bool _handled = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _onDetect(BarcodeCapture capture) {
    if (_handled) return;
    final raw = capture.barcodes
        .where((barcode) => barcode.rawValue != null)
        .map((barcode) => barcode.rawValue!)
        .firstOrNull;
    if (raw == null) return;

    _handled = true;
    widget.onResult(raw);
    Navigator.of(context).pop(raw);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Scan a barcode')),
      body: Stack(
        children: [
          MobileScanner(
            controller: _controller,
            onDetect: _onDetect,
            errorBuilder: (context, error, child) {
              return const Center(
                child: Text(
                  'The camera is not available. Enable camera permission and '
                  'try again.',
                ),
              );
            },
          ),
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: Container(
              color: Theme.of(context).colorScheme.surface,
              padding: const EdgeInsets.all(16),
              child: Text(
                'Point the camera at an EAN or UPC barcode.',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodyMedium,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
