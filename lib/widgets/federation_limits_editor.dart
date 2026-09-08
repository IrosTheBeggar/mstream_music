import 'package:material_ui/material_ui.dart';

import '../l10n/app_localizations.dart';
import '../theme/velvet_theme.dart';
import '../util/federation_admin_api.dart';
import 'federation_widgets.dart';

/// What the editor produces: the caps plus an expiry — [expiresAt] null
/// means never. [expiryChanged] says whether the user touched the expiry
/// at all, so a key edit can leave an untouched expiry alone (the limits
/// route treats an absent field as "unchanged" and null as "never").
class FederationLimitsDraft {
  final FederationLimits limits;
  final DateTime? expiresAt;
  final bool expiryChanged;
  const FederationLimitsDraft(this.limits, this.expiresAt, this.expiryChanged);
}

/// The limits block of the mint / accept / edit forms: preset chips per
/// cap (the webapp's four number boxes, as choices), with "Exact numbers"
/// flipping to numeric fields for anything the presets do not cover. A
/// value that is not a preset shows as its own selected chip, so an
/// edited key opens on what it has.
class FederationLimitsEditor extends StatefulWidget {
  final FederationLimits initial;
  final DateTime? initialExpiry;
  final ValueChanged<FederationLimitsDraft> onChanged;
  final bool first;
  const FederationLimitsEditor({
    super.key,
    required this.initial,
    this.initialExpiry,
    required this.onChanged,
    this.first = false,
  });

  @override
  State<FederationLimitsEditor> createState() => _FederationLimitsEditorState();
}

class _FederationLimitsEditorState extends State<FederationLimitsEditor> {
  static const _rates = [0, 320, 1000, 8000];
  static const _daily = [0, 500, 2048, 10240];
  static const _streams = [1, 3, 5, 0];
  static const _days = [0, 7, 30, 365];

  late FederationLimits _limits;
  DateTime? _expiresAt;
  bool _expiryChanged = false;
  bool _exact = false;
  late final TextEditingController _rateCtrl;
  late final TextEditingController _dailyCtrl;
  late final TextEditingController _streamsCtrl;
  late final TextEditingController _daysCtrl;

  @override
  void initState() {
    super.initState();
    _limits = widget.initial;
    _expiresAt = widget.initialExpiry;
    _rateCtrl = TextEditingController(text: '${_limits.streamKbps}');
    _dailyCtrl = TextEditingController(text: '${_limits.dailyMb}');
    _streamsCtrl = TextEditingController(text: '${_limits.maxStreams}');
    _daysCtrl = TextEditingController(text: '${_daysLeft() ?? 0}');
  }

  @override
  void dispose() {
    _rateCtrl.dispose();
    _dailyCtrl.dispose();
    _streamsCtrl.dispose();
    _daysCtrl.dispose();
    super.dispose();
  }

  int? _daysLeft() {
    final e = _expiresAt;
    if (e == null) return null;
    final d = e.difference(DateTime.now()).inHours;
    return d <= 0 ? 0 : ((d + 23) ~/ 24);
  }

  void _emit() =>
      widget.onChanged(FederationLimitsDraft(_limits, _expiresAt, _expiryChanged));

  void _setExpiryDays(int days) {
    _expiryChanged = true;
    _expiresAt = days <= 0 ? null : DateTime.now().add(Duration(days: days));
    _daysCtrl.text = '$days';
  }

  /// Chip labels for [presets] plus, when [value] is not one of them, a
  /// trailing chip for the value itself; returns (labels, selected index).
  (List<String>, int) _chips(
      List<int> presets, int value, String Function(int) fmt) {
    final labels = [for (final p in presets) fmt(p)];
    var idx = presets.indexOf(value);
    if (idx < 0) {
      labels.add(fmt(value));
      idx = labels.length - 1;
    }
    return (labels, idx);
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final days = _daysLeft();
    final (rateLabels, rateIdx) =
        _chips(_rates, _limits.streamKbps, (v) => fmtStreamRate(l, v));
    final (dailyLabels, dailyIdx) =
        _chips(_daily, _limits.dailyMb, (v) => fmtDaily(l, v));
    final (streamLabels, streamIdx) =
        _chips(_streams, _limits.maxStreams, (v) => fmtStreams(l, v));
    final (dayLabels, dayIdx) = _chips(_days, days ?? 0, (v) {
      if (v <= 0) return l.federationNever;
      if (v == 365) return l.federationOneYear;
      return l.federationDays(v);
    });
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        FedSection(
          l.federationLimitsSection,
          first: widget.first,
          trailing: InkWell(
            onTap: () => setState(() => _exact = !_exact),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
              child: Text(_exact ? l.federationPresets : l.federationExactNumbers,
                  style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: VelvetColors.primary)),
            ),
          ),
        ),
        if (_exact)
          FedCard(children: [
            _numberField(_rateCtrl, l.federationStreamRateField,
                (v) => _limits = _limits.copyWith(streamKbps: v)),
            _numberField(_dailyCtrl, l.federationPerDayField,
                (v) => _limits = _limits.copyWith(dailyMb: v)),
            _numberField(_streamsCtrl, l.federationStreamsField,
                (v) => _limits = _limits.copyWith(maxStreams: v)),
            _numberField(_daysCtrl, l.federationExpiresField, _setExpiryDays),
          ])
        else
          FedCard(children: [
            FedChipRow(
              label: l.federationLimitStreamRate,
              options: rateLabels,
              selected: rateIdx,
              onSelected: (i) => setState(() {
                if (i < _rates.length) {
                  _limits = _limits.copyWith(streamKbps: _rates[i]);
                  _rateCtrl.text = '${_rates[i]}';
                }
                _emit();
              }),
            ),
            FedChipRow(
              label: l.federationLimitPerDay,
              options: dailyLabels,
              selected: dailyIdx,
              onSelected: (i) => setState(() {
                if (i < _daily.length) {
                  _limits = _limits.copyWith(dailyMb: _daily[i]);
                  _dailyCtrl.text = '${_daily[i]}';
                }
                _emit();
              }),
            ),
            FedChipRow(
              label: l.federationLimitStreams,
              options: streamLabels,
              selected: streamIdx,
              onSelected: (i) => setState(() {
                if (i < _streams.length) {
                  _limits = _limits.copyWith(maxStreams: _streams[i]);
                  _streamsCtrl.text = '${_streams[i]}';
                }
                _emit();
              }),
            ),
            FedChipRow(
              label: l.federationLimitExpires,
              options: dayLabels,
              selected: dayIdx,
              onSelected: (i) => setState(() {
                if (i < _days.length) _setExpiryDays(_days[i]);
                _emit();
              }),
            ),
          ]),
      ],
    );
  }

  Widget _numberField(
      TextEditingController ctrl, String label, void Function(int) apply) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 8, 14, 8),
      child: TextField(
        controller: ctrl,
        keyboardType: TextInputType.number,
        style: TextStyle(color: VelvetColors.textPrimary),
        decoration: fedInputDecoration(label),
        onChanged: (s) {
          final v = int.tryParse(s.trim());
          if (v == null || v < 0) return;
          setState(() {
            apply(v);
            _emit();
          });
        },
      ),
    );
  }
}
