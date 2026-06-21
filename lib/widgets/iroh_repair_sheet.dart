import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:permission_handler/permission_handler.dart';

import '../singletons/server_list.dart';
import '../theme/velvet_theme.dart';
import 'iroh_scanner.dart';

/// Re-pair the active iroh server after its connect secret was rotated: paste or
/// scan a fresh pairing code, then restart the tunnel with it. The status banner
/// reflects the outcome (reconnecting → connected, or still re-pair if wrong).
Future<void> showIrohRepairSheet(BuildContext context) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: VelvetColors.surface,
    builder: (_) => const _IrohRepairSheet(),
  );
}

class _IrohRepairSheet extends StatefulWidget {
  const _IrohRepairSheet();

  @override
  State<_IrohRepairSheet> createState() => _IrohRepairSheetState();
}

class _IrohRepairSheetState extends State<_IrohRepairSheet> {
  final TextEditingController _ctrl = TextEditingController();
  bool _busy = false;

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  Future<void> _paste() async {
    final data = await Clipboard.getData(Clipboard.kTextPlain);
    final text = data?.text?.trim();
    if (text != null && text.isNotEmpty) setState(() => _ctrl.text = text);
  }

  Future<void> _scan() async {
    final status = await Permission.camera.request();
    if (!status.isGranted) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text('Camera permission is needed to scan a code.')));
      }
      return;
    }
    if (!mounted) return;
    final code = await Navigator.of(context)
        .push<String>(MaterialPageRoute(builder: (_) => const IrohScannerPage()));
    if (code != null && code.trim().isNotEmpty && mounted) {
      setState(() => _ctrl.text = code.trim());
    }
  }

  Future<void> _repair() async {
    final code = _ctrl.text.trim();
    if (code.isEmpty) return;
    setState(() => _busy = true);
    await ServerManager().repairIrohPairingCode(code);
    if (mounted) Navigator.of(context).pop();
  }

  ButtonStyle get _outlined => OutlinedButton.styleFrom(
        foregroundColor: VelvetColors.textPrimary,
        side: BorderSide(color: VelvetColors.border2),
        padding: const EdgeInsets.symmetric(vertical: 14),
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(VelvetColors.radiusSmall)),
      );

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: EdgeInsets.fromLTRB(
            20, 16, 20, 16 + MediaQuery.of(context).viewInsets.bottom),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('Re-pair server',
                style: TextStyle(
                    color: VelvetColors.textPrimary,
                    fontSize: 16,
                    fontWeight: FontWeight.w700)),
            const SizedBox(height: 6),
            Text(
              'This server\'s pairing code changed (its secret was rotated). Paste '
              'or scan the new code from the server\'s Remote Access panel.',
              style: TextStyle(color: VelvetColors.textSecondary, fontSize: 13),
            ),
            const SizedBox(height: 14),
            TextField(
              controller: _ctrl,
              minLines: 2,
              maxLines: 4,
              autocorrect: false,
              enableSuggestions: false,
              enabled: !_busy,
              style: TextStyle(color: VelvetColors.textPrimary, fontSize: 13),
              decoration: const InputDecoration(
                labelText: 'Pairing code',
                prefixIcon: Icon(Icons.vpn_key_outlined),
              ),
            ),
            const SizedBox(height: 10),
            Row(children: [
              Expanded(
                child: OutlinedButton.icon(
                  style: _outlined,
                  icon: const Icon(Icons.qr_code_scanner, size: 18),
                  label: const Text('Scan QR'),
                  onPressed: _busy ? null : _scan,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: OutlinedButton.icon(
                  style: _outlined,
                  icon: const Icon(Icons.content_paste, size: 18),
                  label: const Text('Paste'),
                  onPressed: _busy ? null : _paste,
                ),
              ),
            ]),
            const SizedBox(height: 14),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: VelvetColors.primary,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                    borderRadius:
                        BorderRadius.circular(VelvetColors.radiusSmall)),
              ),
              onPressed: _busy ? null : _repair,
              child: _busy
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor: AlwaysStoppedAnimation(Colors.white)))
                  : const Text('Re-pair'),
            ),
          ],
        ),
      ),
    );
  }
}
