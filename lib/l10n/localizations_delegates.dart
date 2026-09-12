// Hand-written (NOT gen-l10n output): the delegate list every MaterialApp in
// the app mounts. Use this, never AppLocalizations.localizationsDelegates on
// its own.
//
// The generated list carries flutter_localizations' delegates, which serve
// package:flutter/material's MaterialLocalizations. The UI is built on
// package:material_ui, whose MaterialLocalizations is a DIFFERENT type with
// its own global delegate. Without it, material_ui's MaterialApp falls back to
// DefaultMaterialLocalizations — English only — so on any other device
// language every MaterialLocalizations.of(context) lookup (the drawer tooltip,
// TextField, TabBar, dialogs…) threw "No MaterialLocalizations found": the
// release-build grey screen of #169. cupertino_ui has the same split for the
// CupertinoLocalizations its adaptive widgets read on iOS.
import 'package:cupertino_ui/cupertino_ui.dart'
    show GlobalCupertinoLocalizations;
import 'package:flutter/widgets.dart';
import 'package:material_ui/material_ui.dart' show GlobalMaterialLocalizations;

import 'app_localizations.dart';

const List<LocalizationsDelegate<dynamic>> appLocalizationsDelegates = [
  ...AppLocalizations.localizationsDelegates,
  GlobalMaterialLocalizations.delegate,
  GlobalCupertinoLocalizations.delegate,
];

/// The locales to hand MaterialApp: English first, then the rest in their
/// generated order.
///
/// AppLocalizations.supportedLocales is generated alphabetically (de, en, es,
/// …), and Flutter's locale resolution falls back to the FIRST supported
/// locale when none of the device's languages is supported — so a Dutch or
/// Swedish phone used to get a German UI. English is the source language and
/// the only one every string exists in, so it is the fallback.
final List<Locale> appSupportedLocales = List.unmodifiable(<Locale>[
  const Locale('en'),
  ...AppLocalizations.supportedLocales.where((l) => l.languageCode != 'en'),
]);
