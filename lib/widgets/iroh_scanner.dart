import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

/// Full-screen QR scanner for an iroh pairing code. Pops with the first decoded
/// string (mobile_scanner: CameraX/ML Kit on Android). Shared by the add-server
/// iroh tab and the re-pair sheet.
class IrohScannerPage extends StatefulWidget {
  const IrohScannerPage({super.key});

  @override
  State<IrohScannerPage> createState() => _IrohScannerPageState();
}

class _IrohScannerPageState extends State<IrohScannerPage> {
  final MobileScannerController _controller = MobileScannerController();
  bool _handled = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _onDetect(BarcodeCapture capture) {
    if (_handled) return;
    final raw =
        capture.barcodes.isNotEmpty ? capture.barcodes.first.rawValue : null;
    if (raw != null && raw.isNotEmpty) {
      _handled = true;
      Navigator.of(context).pop(raw);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Scan pairing QR')),
      body: MobileScanner(controller: _controller, onDetect: _onDetect),
    );
  }
}
