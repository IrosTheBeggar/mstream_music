import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../l10n/app_localizations.dart';
import '../theme/velvet_theme.dart';

/// Shows an iroh server's stored composite pairing code as a scannable QR
/// (plus copy-to-clipboard), so another device can pair without opening the
/// server's Remote Access panel. Renders the same string the panel's QR
/// encodes; it's a credential, so the sheet carries a caution line.
Future<void> showIrohPairingQrSheet(BuildContext context, String code) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: VelvetColors.surface,
    builder: (_) => _IrohPairingQrSheet(code: code),
  );
}

class _IrohPairingQrSheet extends StatelessWidget {
  const _IrohPairingQrSheet({required this.code});

  final String code;

  void _copy(BuildContext context) {
    Clipboard.setData(ClipboardData(text: code));
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(AppLocalizations.of(context).copiedToClipboard)));
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    // Pairing codes are long (ticket + secret), so the QR is dense — keep it
    // large, but inside the sheet width on narrow phones.
    final double qrSize =
        (MediaQuery.of(context).size.width - 104).clamp(160.0, 280.0);
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(l.irohPairingCodeLabel,
                style: TextStyle(
                    color: VelvetColors.textPrimary,
                    fontSize: 16,
                    fontWeight: FontWeight.w700)),
            const SizedBox(height: 6),
            Text(
              l.irohQrBody,
              style: TextStyle(color: VelvetColors.textSecondary, fontSize: 13),
            ),
            const SizedBox(height: 14),
            Center(
              // White field so the QR scans against the dark theme.
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius:
                      BorderRadius.circular(VelvetColors.radiusSmall),
                ),
                child: QrImageView(
                  data: code,
                  size: qrSize,
                  backgroundColor: Colors.white,
                ),
              ),
            ),
            const SizedBox(height: 12),
            Text(
              l.irohQrCaution,
              textAlign: TextAlign.center,
              style: TextStyle(color: VelvetColors.warning, fontSize: 12),
            ),
            const SizedBox(height: 14),
            OutlinedButton.icon(
              style: OutlinedButton.styleFrom(
                foregroundColor: VelvetColors.textPrimary,
                side: BorderSide(color: VelvetColors.border2),
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                    borderRadius:
                        BorderRadius.circular(VelvetColors.radiusSmall)),
              ),
              icon: const Icon(Icons.content_copy, size: 18),
              label: Text(l.copy),
              onPressed: () => _copy(context),
            ),
          ],
        ),
      ),
    );
  }
}
