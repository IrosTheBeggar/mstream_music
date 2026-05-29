import 'package:flutter/material.dart';
import 'package:rxdart/rxdart.dart';

import '../media/cast_target.dart';
import '../singletons/cast_manager.dart';
import '../theme/velvet_theme.dart';

/// Bottom sheet for choosing where audio plays ("This device" or a discovered
/// renderer). Discovery runs only while the sheet is open (battery-friendly).
class CastPickerSheet extends StatefulWidget {
  @override
  State<CastPickerSheet> createState() => _CastPickerSheetState();
}

class _CastPickerSheetState extends State<CastPickerSheet> {
  @override
  void initState() {
    super.initState();
    // Scan only while the picker is visible.
    CastManager().startDiscovery();
  }

  @override
  void dispose() {
    CastManager().stopDiscovery();
    super.dispose();
  }

  IconData _iconFor(CastTargetKind kind) {
    switch (kind) {
      case CastTargetKind.local:
        return Icons.smartphone;
      case CastTargetKind.dlna:
        return Icons.speaker;
      case CastTargetKind.chromecast:
        return Icons.cast;
    }
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.cast, color: VelvetColors.primary),
                const SizedBox(width: 10),
                Text(
                  'Play on',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                    color: VelvetColors.textPrimary,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            StreamBuilder<(List<CastTarget>, CastTarget)>(
              stream: Rx.combineLatest2(
                CastManager().targetsStream,
                CastManager().activeTargetStream,
                (List<CastTarget> targets, CastTarget active) =>
                    (targets, active),
              ),
              initialData: (CastManager().targets, CastManager().activeTarget),
              builder: (context, snapshot) {
                final (targets, active) = snapshot.data!;
                return Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    for (final t in targets)
                      _TargetRow(
                        target: t,
                        selected: t == active,
                        icon: _iconFor(t.kind),
                        onTap: () {
                          CastManager().selectTarget(t);
                          Navigator.of(context).pop();
                        },
                      ),
                  ],
                );
              },
            ),
            // The "searching…" hint only appears once discovery backends are
            // registered (Phase 3+). Until then the list is just this device.
            if (CastManager().hasDiscoverers) ...[
              const SizedBox(height: 12),
              Row(
                children: [
                  SizedBox(
                    width: 14,
                    height: 14,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor:
                          AlwaysStoppedAnimation(VelvetColors.textSecondary),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Text(
                    'Searching for cast devices…',
                    style: TextStyle(
                      fontSize: 12,
                      color: VelvetColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _TargetRow extends StatelessWidget {
  final CastTarget target;
  final bool selected;
  final IconData icon;
  final VoidCallback onTap;
  const _TargetRow({
    required this.target,
    required this.selected,
    required this.icon,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: Icon(
        icon,
        color: selected ? VelvetColors.primary : VelvetColors.textSecondary,
      ),
      title: Text(
        target.name,
        style: TextStyle(
          color: selected ? VelvetColors.primary : VelvetColors.textPrimary,
          fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
        ),
      ),
      trailing:
          selected ? Icon(Icons.check, color: VelvetColors.primary) : null,
      onTap: onTap,
    );
  }
}
