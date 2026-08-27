import 'package:material_ui/material_ui.dart';

import '../theme/velvet_theme.dart';

/// A read-only pill stating one fact about a track — its key, its tempo, that
/// it has words.
///
/// Shared so a song looks the same wherever you meet it: the track sheet shows
/// these under the title, the now-playing header shows the same set beside the
/// rating. [compact] is the header's size — the sheet has room to breathe, a
/// header line next to 13px stars does not.
Widget factBadge(IconData icon, String label, {bool compact = false}) =>
    Container(
      padding: EdgeInsets.symmetric(
          horizontal: compact ? 8 : 11, vertical: compact ? 4 : 8),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: VelvetColors.border),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon,
              size: compact ? 12 : 14, color: VelvetColors.textTertiary),
          SizedBox(width: compact ? 4 : 6),
          Text(
            label,
            style: TextStyle(
              color: VelvetColors.textSecondary,
              fontSize: compact ? 11 : 12.5,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
