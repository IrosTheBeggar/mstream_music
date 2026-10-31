// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for French (`fr`).
class AppLocalizationsFr extends AppLocalizations {
  AppLocalizationsFr([String locale = 'fr']) : super(locale);

  @override
  String get mainRemove => 'Retirer';

  @override
  String get playlistActionFailed =>
      'Impossible d\'enregistrer la liste de lecture : ce nom est peut-être déjà utilisé.';

  @override
  String get queueAddNext => 'Ajouter à la suite';

  @override
  String get queuePlayNow => 'Lire maintenant';

  @override
  String get queueAddToEnd => 'Ajouter à la fin de la file';

  @override
  String get shuffle => 'Aléatoire';

  @override
  String get variousArtists => 'Artistes divers';

  @override
  String get appTitle => 'mStream Music';

  @override
  String get settingsLanguage => 'Langue';

  @override
  String get languageSystemDefault => 'Langue du système';

  @override
  String couldNotOpen(String url) {
    return 'Impossible d\'ouvrir $url';
  }

  @override
  String trackCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count morceaux',
      one: '$count morceau',
      zero: 'Aucun morceau',
    );
    return '$_temp0';
  }

  @override
  String get reset => 'Réinitialiser';

  @override
  String get themeVelvet => 'Velvet';

  @override
  String get themeDark => 'Sombre';

  @override
  String get themeLight => 'Clair';

  @override
  String get tapAddToQueue => 'Ajouter à la file';

  @override
  String get tapPlayFromHere => 'Lire à partir d\'ici';

  @override
  String get tapAppendAndJump => 'Ajouter et lire';

  @override
  String get visualizerSourceSynthesized => 'Synthétisé';

  @override
  String get visualizerSourceReal => 'Audio réel';

  @override
  String get downloadsTitle => 'Téléchargements';

  @override
  String downloadProgress(String progress) {
    return 'progression : $progress %';
  }

  @override
  String get songInfoTitle => 'Infos du morceau';

  @override
  String get lyricsTitle => 'Paroles';

  @override
  String get lyricsEmpty => 'Aucunes paroles trouvées pour ce morceau';

  @override
  String get lyricsError => 'Impossible de charger les paroles';

  @override
  String get lyricsRetry => 'Réessayer';

  @override
  String get eqTitle => 'Égaliseur';

  @override
  String get eqOnlyAndroid => 'L\'égaliseur n\'est disponible que sur Android.';

  @override
  String get eqNeedsPlayback =>
      'L\'égaliseur de ce téléphone n\'indique ses bandes qu\'une fois l\'audio en lecture. Votre préréglage enregistré s\'applique dès qu\'elles apparaissent.';

  @override
  String eqInitFailed(String error) {
    return 'Impossible d\'initialiser l\'égaliseur :\n$error';
  }

  @override
  String get eqNoBands =>
      'Aucune bande d\'égaliseur signalée par le pilote audio de cet appareil.';

  @override
  String get eqPresetFlat => 'Plat';

  @override
  String get eqPresetNormal => 'Normal';

  @override
  String get eqPresetClassical => 'Classique';

  @override
  String get eqPresetDance => 'Dance';

  @override
  String get eqPresetFolk => 'Folk';

  @override
  String get eqPresetHeavyMetal => 'Heavy metal';

  @override
  String get eqPresetHipHop => 'Hip-hop';

  @override
  String get eqPresetJazz => 'Jazz';

  @override
  String get eqPresetPop => 'Pop';

  @override
  String get eqPresetRock => 'Rock';

  @override
  String get eqPresetCustom => 'Personnalisé';

  @override
  String get eqSaveAsPreset => 'Enregistrer comme préréglage';

  @override
  String get eqSavePresetTitle => 'Enregistrer le préréglage';

  @override
  String get eqRenamePresetTitle => 'Renommer le préréglage';

  @override
  String get eqPresetNameLabel => 'Nom';

  @override
  String get eqSavePresetHint =>
      'Enregistré sur ce téléphone, après les préréglages intégrés. Appuyez longuement sur sa puce plus tard pour le renommer ou le supprimer.';

  @override
  String get eqReplacePreset => 'Remplacer';

  @override
  String get eqPresetNameTaken =>
      'Un autre préréglage enregistré porte déjà ce nom.';

  @override
  String eqDeletePresetConfirm(String name) {
    return 'Supprimer « $name » ?';
  }

  @override
  String get eqHoldToCompare => 'Maintenir pour comparer';

  @override
  String get eqHoldToCompareHint =>
      'Maintenez appuyé pour entendre le son sans l\'égaliseur.';

  @override
  String get eqOptionsTitle => 'Options de l\'égaliseur';

  @override
  String get eqPreventClipping => 'Éviter la saturation';

  @override
  String get eqPreventClippingHint =>
      'Limite les crêtes quand des bandes sont amplifiées.';

  @override
  String get eqShowValues => 'Toujours afficher les valeurs des bandes';

  @override
  String get eqShowValuesHint =>
      'Un nombre au-dessus de chaque bande, pas seulement pendant le glissement.';

  @override
  String get eqOutputsTitle => 'Sorties';

  @override
  String get eqOutputsRowOff =>
      'Désactivé — une courbe pour toutes les sorties';

  @override
  String eqOutputsNow(String name) {
    return '$name en ce moment';
  }

  @override
  String get eqOutputsSwitch => 'Changer automatiquement';

  @override
  String get eqOutputsSwitchHint =>
      'Quand la sortie change, sa courbe est appliquée. Glisser sur la page Égaliseur modifie la sortie en cours de lecture.';

  @override
  String get eqOutputsRemembered => 'Sorties mémorisées';

  @override
  String get eqOutputSpeaker => 'Haut-parleur du téléphone';

  @override
  String get eqOutputWired => 'Casque filaire';

  @override
  String get eqOutputUsb => 'Audio USB';

  @override
  String get eqOutputHdmi => 'HDMI';

  @override
  String get eqOutputBluetooth => 'Bluetooth';

  @override
  String get eqOutputOther => 'Autre sortie';

  @override
  String get eqOutputPlayingNow => 'en cours de lecture';

  @override
  String eqOutputLastUsed(String date) {
    return 'dernière utilisation $date';
  }

  @override
  String get eqOutputsEmpty =>
      'Les sorties apparaissent ici au fil de vos écoutes.';

  @override
  String eqOutputForgetConfirm(String name) {
    return 'Oublier « $name » ? Elle réapparaîtra comme nouvelle sortie à sa prochaine connexion.';
  }

  @override
  String get eqOutputForget => 'Oublier';

  @override
  String eqOutputPickPreset(String name) {
    return 'Préréglage pour $name';
  }

  @override
  String get eqOutputsHint =>
      'Touchez une sortie pour choisir son préréglage. Balayez-la pour l\'oublier.';

  @override
  String eqEnabledOnOutput(String name) {
    return 'Activé — $name';
  }

  @override
  String get eqOutputNowPill => 'Maintenant';

  @override
  String get eqNeedsPlaybackTitle =>
      'Lancez un morceau pour configurer les bandes';

  @override
  String get eqPlayQueue => 'Lire la file d\'attente';

  @override
  String eqPlayQueueHint(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count morceaux',
      one: '$count morceau',
    );
    return 'Reprend là où vous en étiez · $_temp0';
  }

  @override
  String get eqDisabledHint => 'Activez l\'égaliseur pour régler les bandes.';

  @override
  String get eqEnabledOn => 'Activé — gains appliqués à la lecture';

  @override
  String get eqEnabledOff => 'Désactivé — mode contournement';

  @override
  String get cancel => 'Annuler';

  @override
  String get continueLabel => 'Continuer';

  @override
  String get openSettings => 'Ouvrir les paramètres';

  @override
  String get settingsTitle => 'Paramètres';

  @override
  String get settingsSectionAppearance => 'Apparence';

  @override
  String get settingsSectionPlayback => 'Lecture';

  @override
  String get settingsSectionBrowse => 'Bibliothèque';

  @override
  String get settingsTheme => 'Thème';

  @override
  String get settingsTranscode => 'Transcoder l\'audio';

  @override
  String get settingsTranscodeSubtitle =>
      'Diffuser une copie transcodée depuis le serveur (fichiers plus légers, démarrage un peu plus lent). Désactivé, lit les fichiers d\'origine.';

  @override
  String get transcodeTitle => 'Transcodage';

  @override
  String get transcodeCodec => 'Codec';

  @override
  String get transcodeBitrate => 'Débit binaire';

  @override
  String get transcodeAuto => 'Valeur par défaut du serveur';

  @override
  String get transcodeUnavailable =>
      'Ce serveur n\'a pas le transcodage activé — ses morceaux sont diffusés en qualité d\'origine.';

  @override
  String get transcodeReloadQueue => 'Appliquer à la file actuelle';

  @override
  String get transcodeReloadQueueSubtitle =>
      'Quand vous modifiez les paramètres de transcodage — coché : recharger toute la file maintenant (le morceau en cours se remet brièvement en mémoire tampon) ; décoché : seuls les morceaux à venir changent, celui en cours se termine tel quel.';

  @override
  String get settingsTapBehavior => 'Lorsque vous touchez un morceau';

  @override
  String get settingsStartupPage => 'Écran de démarrage';

  @override
  String get tapSubtitleAddToQueue => 'L\'ajoute à la fin de la file';

  @override
  String get tapSubtitlePlayFromHere =>
      'Remplace la file et lit à partir de ce morceau';

  @override
  String get tapSubtitleAppendAndJump =>
      'L\'ajoute à la fin de la file et le lit tout de suite';

  @override
  String get settingsVisualizerSource => 'Source audio';

  @override
  String get visualizerSourceSubtitleSynthesized =>
      'Aucune autorisation requise';

  @override
  String get visualizerSourceSubtitleReal =>
      'Nécessite l\'autorisation du micro, sans jamais utiliser le micro';

  @override
  String get settingsAlbumGrid => 'Albums en grille';

  @override
  String get settingsFileMetadata =>
      'Infos des morceaux dans l\'explorateur de fichiers';

  @override
  String get settingsLetterStrip => 'Barre A–Z';

  @override
  String get settingsLetterStripSide => 'Côté';

  @override
  String get settingsLetterStripLeft => 'Gauche';

  @override
  String get settingsLetterStripRight => 'Droite';

  @override
  String get settingsReset => 'Réinitialiser les paramètres';

  @override
  String get settingsResetDone => 'Paramètres réinitialisés';

  @override
  String get realAudioDialogTitle => 'Utiliser l\'audio réel ?';

  @override
  String get realAudioDialogBody =>
      'Pour réagir au morceau en cours de lecture, le visualiseur lit la sortie audio de mStream lui-même, ce qu\'Android ne permet qu\'avec l\'autorisation du micro.';

  @override
  String get realAudioPermPermanentlyDenied =>
      'Autorisation définitivement refusée. Activez-la dans les paramètres système pour utiliser l\'audio réel.';

  @override
  String get realAudioPermDenied =>
      'Autorisation refusée. Maintien de l\'audio synthétisé.';

  @override
  String get visualizerTapHint =>
      'Toucher = préréglage suivant · flèche retour (en haut à gauche) ou appui long pour quitter';

  @override
  String get visualizerFailed => 'Échec du démarrage du visualiseur';

  @override
  String get visualizerBringingUp => 'Démarrage du moteur de rendu…';

  @override
  String get visualizerReady => 'Visualiseur prêt';

  @override
  String get visualizerBridgeFailed => 'Échec du démarrage du pont';

  @override
  String visualizerAudioSourceLine(String source) {
    return 'Source audio : $source';
  }

  @override
  String get visualizerTapToClose => 'Touchez n\'importe où pour fermer';

  @override
  String get visualizerClose => 'Fermer le visualiseur';

  @override
  String get visualizerPreviousPreset => 'Préréglage précédent';

  @override
  String get visualizerNextPreset => 'Préréglage suivant';

  @override
  String get visualizerUnsupported =>
      'Le visualiseur n\'est actuellement pris en charge que sur Android.';

  @override
  String get aboutTitle => 'À propos';

  @override
  String aboutBuiltBy(String name) {
    return 'Créé par $name';
  }

  @override
  String get linkDiscordSubtitle => 'Discussion communautaire';

  @override
  String get linkGithubSubtitle => 'Code source du serveur mStream';

  @override
  String get linkHomepageSubtitle => 'Page d\'accueil du projet';

  @override
  String get aboutAttributions => 'Attributions';

  @override
  String get aboutAttributionsSubtitle =>
      'Licence, crédits des shaders et mentions open source.';

  @override
  String get aboutSponsor => 'Soutenir mStream';

  @override
  String get ok => 'OK';

  @override
  String get delete => 'Supprimer';

  @override
  String get edit => 'Modifier';

  @override
  String get info => 'Infos';

  @override
  String get makeDefault => 'Définir par défaut';

  @override
  String get goBack => 'Retour';

  @override
  String get play => 'Lire';

  @override
  String get playAll => 'Tout lire';

  @override
  String get rename => 'Renommer';

  @override
  String get create => 'Créer';

  @override
  String get copy => 'Copier';

  @override
  String get done => 'Terminé';

  @override
  String get copiedToClipboard => 'Copié dans le presse-papiers';

  @override
  String get attributionsTitle => 'Attributions';

  @override
  String get attributionsSectionLicense => 'Licence';

  @override
  String get attributionsSectionShaders => 'Shaders du visualiseur';

  @override
  String get attributionsSectionLibraries => 'Bibliothèques natives';

  @override
  String get attributionsSectionEverythingElse => 'Tout le reste';

  @override
  String get attributionsLicenseBody =>
      'Logiciel libre sous la GNU General Public License v3.0. Vous pouvez l\'utiliser, l\'étudier, le partager et le modifier selon ces conditions.';

  @override
  String get attributionsPackages => 'Licences des paquets open source';

  @override
  String get attributionsPackagesSubtitle =>
      'Textes complets des licences de tous les paquets Flutter/Dart inclus.';

  @override
  String get manageServersTitle => 'Gérer les serveurs';

  @override
  String get manageServerInfo => 'Infos du serveur';

  @override
  String get manageServerDownloadFolder => 'Dossier de téléchargement :';

  @override
  String get manageServerCopyPath => 'Copier le chemin de téléchargement';

  @override
  String get manageServerPathCopied => 'Chemin copié dans le presse-papiers';

  @override
  String get confirmRemoveServerTitle => 'Confirmer la suppression du serveur';

  @override
  String get removeSyncedFiles =>
      'Supprimer les fichiers synchronisés de l\'appareil ?';

  @override
  String get playlistsTitle => 'Listes de lecture';

  @override
  String get playlistsNew => 'Nouvelle liste de lecture';

  @override
  String get playlistsEmptyTitle => 'Aucune liste de lecture';

  @override
  String get playlistsEmptyBody =>
      'Créez-en une avec le bouton Nouvelle liste de lecture, puis utilisez l\'action de balayage Ajouter à la liste de lecture de la file pour la remplir.';

  @override
  String get playlistNameHint => 'Nom';

  @override
  String get playlistsRename => 'Renommer la liste de lecture';

  @override
  String get playlistFallbackTitle => 'Liste de lecture';

  @override
  String get playlistEmptyDetail =>
      'La liste de lecture est vide.\nAjoutez des morceaux depuis la file.';

  @override
  String get shareEmptyTitle => 'File vide';

  @override
  String get shareEmptyBody =>
      'Ajoutez des morceaux à la file avant de partager.';

  @override
  String get shareBlockedTitle => 'Impossible de partager cette file';

  @override
  String get shareLocalOnlyBody =>
      'La file contient des morceaux qui sont uniquement sur cet appareil (sur aucun serveur). Le partage ne fonctionne que lorsque tous les morceaux de la file proviennent d\'un seul serveur.';

  @override
  String shareMultiServerBody(int count, String names) {
    return 'La file mélange des morceaux de $count serveurs ($names). Le partage ne fonctionne que lorsque tous les morceaux proviennent d\'un seul serveur.';
  }

  @override
  String shareServerGoneBody(String name) {
    return 'Le serveur « $name » ne figure plus dans votre liste de serveurs. Rajoutez-le pour partager sa file.';
  }

  @override
  String get shareTitle => 'Partager la liste de lecture';

  @override
  String shareSongCount(int count, String url) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count morceaux',
      one: '$count morceau',
    );
    return '$_temp0 de $url';
  }

  @override
  String get shareLinkExpires => 'Le lien expire';

  @override
  String get shareExpireNever => 'Jamais';

  @override
  String get shareExpire1Day => 'Après 1 jour';

  @override
  String get shareExpire7Days => 'Après 7 jours';

  @override
  String get shareExpire30Days => 'Après 30 jours';

  @override
  String get shareAction => 'Partager';

  @override
  String get shareDoneTitle => 'Liste de lecture partagée';

  @override
  String get shareDoneBody =>
      'Toute personne disposant de ce lien peut lire la file :';

  @override
  String get save => 'Enregistrer';

  @override
  String get start => 'Démarrer';

  @override
  String get addServerTitle => 'Ajouter un serveur';

  @override
  String get editServerTitle => 'Modifier le serveur';

  @override
  String get fieldServerUrl => 'URL du serveur';

  @override
  String get fieldPublicAccess => 'Accès public';

  @override
  String get publicAccessSubtitle =>
      'Le serveur est accessible publiquement — aucun nom d\'utilisateur ni mot de passe requis.';

  @override
  String get fieldUsername => 'Nom d\'utilisateur';

  @override
  String get fieldPassword => 'Mot de passe';

  @override
  String get fieldPasswordShow => 'Afficher le mot de passe';

  @override
  String get fieldPasswordHide => 'Masquer le mot de passe';

  @override
  String get fieldSdCard => 'Télécharger sur la carte SD';

  @override
  String get sdCardSubtitle =>
      'Enregistrer la musique téléchargée sur la carte SD amovible plutôt que dans le stockage interne.';

  @override
  String get testConnectionButton => 'Tester la connexion';

  @override
  String get testing => 'Test en cours…';

  @override
  String get connecting => 'Connexion…';

  @override
  String get validatorUrlNeeded => 'L\'URL du serveur est requise';

  @override
  String get validatorUrlParse => 'Impossible d\'analyser l\'URL';

  @override
  String get testEnterUrl => 'Saisissez d\'abord une URL de serveur.';

  @override
  String get testParseUrl => 'Impossible d\'analyser l\'URL.';

  @override
  String get testTimedOut => 'Délai de connexion dépassé.';

  @override
  String get connectionSuccessful => 'Connexion réussie !';

  @override
  String get couldNotReachServer =>
      'Impossible de joindre le serveur. S\'il nécessite une connexion, désactivez « Accès public » et ajoutez vos identifiants.';

  @override
  String get failedToLogin => 'Échec de la connexion';

  @override
  String testConnected(String version) {
    return 'Connecté — mStream v$version';
  }

  @override
  String testConnectFailed(String error) {
    return 'Connexion impossible : $error';
  }

  @override
  String get sleepTimerTitle => 'Minuterie de veille';

  @override
  String get sleepTimerHint =>
      'Choisissez une durée après laquelle mettre la lecture en pause.';

  @override
  String get sleepTimerCustom => 'Personnalisé';

  @override
  String get sleepTimerCustomHint => 'minutes (1–600)';

  @override
  String get sleepTimerCancel => 'Annuler la minuterie';

  @override
  String get sleepTimerInvalid => 'Saisissez un nombre entre 1 et 600 minutes';

  @override
  String sleepTimerPausesIn(String time) {
    return 'Pause dans $time';
  }

  @override
  String sleepTimerMinutes(int minutes) {
    return '$minutes min';
  }

  @override
  String sleepTimerSet(int minutes) {
    String _temp0 = intl.Intl.pluralLogic(
      minutes,
      locale: localeName,
      other: 'Minuterie de veille réglée sur $minutes minutes',
      one: 'Minuterie de veille réglée sur $minutes minute',
    );
    return '$_temp0';
  }

  @override
  String get add => 'Ajouter';

  @override
  String get autoDjTitle => 'Auto DJ';

  @override
  String autoDjSongsPerFetchValue(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count morceaux',
      one: '$count morceau',
    );
    return '$_temp0';
  }

  @override
  String autoDjBpmTolerance(int bpm) {
    return '± $bpm BPM';
  }

  @override
  String get autoDjHarmonicTitle => 'Mixage harmonique';

  @override
  String get autoDjHarmonicHint =>
      'Morceau suivant dans une tonalité compatible';

  @override
  String get autoDjDurationRange => 'Durée';

  @override
  String get autoDjMoodTitle => 'Filtres intelligents';

  @override
  String get autoDjGenreLoadError => 'Impossible de charger les genres';

  @override
  String get download => 'Télécharger';

  @override
  String get addAll => 'Tout ajouter';

  @override
  String get browserMoreActions => 'Plus d\'actions';

  @override
  String get browserConfirmDeletePlaylist =>
      'Confirmer la suppression de la liste de lecture';

  @override
  String get browserConfirmDeleteFolder =>
      'Confirmer la suppression du dossier';

  @override
  String get browserSearchHint => 'Rechercher dans la base de données';

  @override
  String get searchCategoriesTooltip => 'Où rechercher';

  @override
  String get searchCategoriesHeader => 'Rechercher dans';

  @override
  String get searchCategoryArtists => 'Artistes';

  @override
  String get searchCategoryAlbums => 'Albums';

  @override
  String get searchCategorySongs => 'Morceaux';

  @override
  String get searchCategoryFiles => 'Fichiers';

  @override
  String get searchCategoryLyrics => 'Paroles';

  @override
  String searchSubheaderResults(String term) {
    return 'Résultats pour « $term »';
  }

  @override
  String searchSubheaderCategories(String categories) {
    return 'Recherche dans : $categories';
  }

  @override
  String browserDownloadsStarted(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count téléchargements démarrés',
      one: '$count téléchargement démarré',
    );
    return '$_temp0';
  }

  @override
  String browserSongsAdded(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count morceaux ajoutés à la file',
      one: '$count morceau ajouté à la file',
    );
    return '$_temp0';
  }

  @override
  String get tabBrowser => 'Explorateur';

  @override
  String get tabQueue => 'File';

  @override
  String get drawerTagline => 'Streaming musical personnel';

  @override
  String get mainFailedToConnect => 'Échec de la connexion au serveur';

  @override
  String get mainQueueEmpty => 'La file est vide';

  @override
  String get queueEmptyDjHint =>
      'Auto DJ est activé et a besoin d\'un premier morceau.';

  @override
  String get queueEmptyDjRandom => 'Morceau au hasard';

  @override
  String get queueEmptyDjChoose => 'Choisir un morceau';

  @override
  String get mainClearQueue => 'Vider la file';

  @override
  String get mainSync => 'Synchroniser';

  @override
  String mainQueueCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count morceaux',
      one: '$count morceau',
    );
    return '$_temp0';
  }

  @override
  String get autoDjEnabled => 'Auto DJ activé';

  @override
  String get autoDjDisabled => 'Auto DJ désactivé';

  @override
  String autoDjEnabledFor(String url) {
    return 'Auto DJ activé pour $url';
  }

  @override
  String get addToPlaylistTitle => 'Ajouter à la liste de lecture';

  @override
  String get addToPlaylistEmpty =>
      'Aucune liste de lecture — touchez + pour en créer une.';

  @override
  String addedToPlaylist(String name) {
    return 'Ajouté à $name';
  }

  @override
  String get testConnectedSignedIn => 'Connecté — connexion réussie.';

  @override
  String get testSignInFailed =>
      'Serveur joint, mais la connexion a échoué — vérifiez votre nom d\'utilisateur et votre mot de passe.';

  @override
  String get browserFileExplorer => 'Explorateur de fichiers';

  @override
  String get browserLocalFiles => 'Fichiers locaux';

  @override
  String get browserPlaylists => 'Listes de lecture';

  @override
  String get browserAlbums => 'Albums';

  @override
  String get browserArtists => 'Artistes';

  @override
  String get browserGenres => 'Genres';

  @override
  String get genreSourceTags => 'Tags';

  @override
  String get genreSourceGenerated => 'Générés';

  @override
  String get genreSourceBoth => 'Les deux';

  @override
  String get genreSourceMixed => 'Mixte';

  @override
  String get genreSourceLabel => 'Origine des genres';

  @override
  String get moodFilters => 'Filtres';

  @override
  String get moodValenceGroup => 'Joyeux, neutre ou triste';

  @override
  String get moodEnergyGroup => 'Détendu, neutre ou agressif';

  @override
  String get moodVoiceGroup => 'Instrumental ou chant';

  @override
  String get moodTagsGroup => 'Étiquettes';

  @override
  String get moodHappy => 'Joyeux';

  @override
  String get moodNeutral => 'Neutre';

  @override
  String get moodSad => 'Triste';

  @override
  String get moodRelaxed => 'Détendu';

  @override
  String get moodAggressive => 'Agressif';

  @override
  String get moodInstrumental => 'Instrumental';

  @override
  String get moodVocals => 'Chant';

  @override
  String get moodAcoustic => 'Acoustique';

  @override
  String get moodParty => 'Fête';

  @override
  String get moodDanceable => 'Dansant';

  @override
  String get moodStrict => 'Strict';

  @override
  String get moodStandard => 'Standard';

  @override
  String get moodLoose => 'Souple';

  @override
  String get moodStrictnessGroup => 'Strict, standard ou souple';

  @override
  String get moodSort => 'Trier';

  @override
  String get moodSortRating => 'Note';

  @override
  String get moodSortNewest => 'Plus récents';

  @override
  String get moodSortMatch => 'Correspondance';

  @override
  String get browserRecent => 'Récents';

  @override
  String get browserRated => 'Notés';

  @override
  String get browserSectionLibrary => 'Bibliothèque';

  @override
  String get browserSectionListen => 'Écouter';

  @override
  String get browserSectionNetwork => 'Réseau';

  @override
  String get browserSectionServer => 'Serveur';

  @override
  String get browserFederation => 'Fédération';

  @override
  String get browserAutoDjOn => 'Activé';

  @override
  String get browserAutoDjOff => 'Désactivé';

  @override
  String browserSharedLibraries(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count bibliothèques partagées',
      one: '$count bibliothèque partagée',
    );
    return '$_temp0';
  }

  @override
  String get browserSearch => 'Rechercher';

  @override
  String get browserWelcomeTitle => 'Bienvenue sur mStream';

  @override
  String get browserWelcomeSubtitle => 'Touchez ici pour ajouter un serveur';

  @override
  String get settingsVisualizerKnobs => 'Curseurs de réglage';

  @override
  String get settingsVisualizerKnobsSubtitle => 'ShaderToy uniquement';

  @override
  String get visualizerTuningTitle => 'Réglage';

  @override
  String get close => 'Fermer';

  @override
  String get migMoveStopped =>
      'Déplacement interrompu — espace insuffisant ou emplacement indisponible.';

  @override
  String get migMoveComplete => 'Déplacement terminé';

  @override
  String migMoveCompleteSkipped(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other:
          'Déplacement terminé — $count fichiers ignorés (non pris en charge sur la destination)',
      one:
          'Déplacement terminé — $count fichier ignoré (non pris en charge sur la destination)',
    );
    return '$_temp0';
  }

  @override
  String migMoving(String progress) {
    return 'Déplacement des téléchargements… $progress — gardez l\'application ouverte';
  }

  @override
  String get migRetry => 'Réessayer';

  @override
  String get queueDownloadAll => 'Tout télécharger';

  @override
  String queueDownloadAllBody(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count morceaux seront téléchargés pour une lecture hors ligne.',
      one: '$count morceau sera téléchargé pour une lecture hors ligne.',
    );
    return '$_temp0';
  }

  @override
  String get mainMore => 'Plus';

  @override
  String get commonOn => 'Activé';

  @override
  String get commonOff => 'Désactivé';

  @override
  String get settingsCastQualitySubtitle4k =>
      'Nécessite un Chromecast 4K ; le plus gourmand pour le téléphone';

  @override
  String get eqCasting =>
      'L\'égaliseur ajuste l\'audio sur cet appareil, il est donc indisponible pendant la diffusion. Arrêtez la diffusion pour l\'utiliser.';

  @override
  String get browserNothingToDownload => 'Rien à télécharger dans cette liste';

  @override
  String get browserDownloadAllTitle => 'Tout télécharger';

  @override
  String browserDownloadAllConfirm(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count fichiers seront téléchargés.',
      one: '$count fichier sera téléchargé.',
    );
    return '$_temp0';
  }

  @override
  String get browserCloseSearch => 'Fermer la recherche';

  @override
  String get browserSearchThisList => 'Rechercher dans cette liste';

  @override
  String get browserSearchList => 'Rechercher dans la liste';

  @override
  String browserNoMatches(String query) {
    return 'Aucun résultat pour « $query »';
  }

  @override
  String get clear => 'Effacer';

  @override
  String get dlLocationUnavailable =>
      'Emplacement de téléchargement indisponible';

  @override
  String get dlLocationUnavailableServer =>
      'Emplacement de téléchargement indisponible pour ce serveur.';

  @override
  String get dlFailed =>
      'Un téléchargement a échoué — vérifiez votre connexion.';

  @override
  String get dlFatSkip =>
      'Certains morceaux ne peuvent pas être enregistrés sur cette carte — leurs noms ne sont pas pris en charge. Ils sont diffusés à la place.';

  @override
  String get dlServerGone => 'Ce serveur n\'est plus configuré.';

  @override
  String get dlStorageUnavailable =>
      'Emplacement de stockage indisponible — reconnectez la carte SD ou modifiez l\'emplacement de stockage de ce serveur dans Modifier le serveur.';

  @override
  String get dlCouldNotStart =>
      'Impossible de démarrer le téléchargement — stockage indisponible.';

  @override
  String get storageLocationLabel => 'Emplacement de stockage';

  @override
  String get storageAppLocal => 'Local à l\'application';

  @override
  String get storagePermanent => 'Permanent';

  @override
  String get storageSdCard => 'Carte SD';

  @override
  String get storageSdSwitchTitle => 'Enregistrer sur la carte SD';

  @override
  String get storageSdSwitchSubtitle =>
      'Enregistré dans le dossier de l\'application sur la carte SD — aucune autorisation requise, mais supprimé si vous désinstallez l\'application.';

  @override
  String get storageHelpAppLocal =>
      'Enregistré dans l\'application. Supprimé lorsque vous désinstallez ou videz l\'application.';

  @override
  String get storageHelpPermanent =>
      'Enregistré dans un dossier de votre choix. Conservé après la désinstallation de l\'application. Nécessite « Accès à tous les fichiers ».';

  @override
  String get storageHelpSdCard =>
      'Enregistré dans un dossier de la carte SD que vous choisissez. Peut devenir indisponible si la carte est retirée. Certains appareils n\'autorisent pas les applications à écrire sur les cartes SD — si la sélection du dossier échoue sans cesse, utilisez Permanent ou Local à l\'application.';

  @override
  String get storageChooseFolder => 'Choisir un dossier';

  @override
  String get storageNoFolderChosen => 'Aucun dossier choisi pour l\'instant';

  @override
  String get storageDownloadFolderLabel => 'Dossier de téléchargement';

  @override
  String get storageDownloadFolderHint => 'nom du dossier';

  @override
  String get storageBrowse => 'Parcourir';

  @override
  String get storageDownloadFolderHelp =>
      'Les fichiers se téléchargent dans un dossier « media/<folder> » sur cet appareil. Réutiliser le dossier d\'un serveur précédent conserve ses morceaux téléchargés lorsque vous rajoutez un serveur perdu.';

  @override
  String get storageNoStorageAvailable => 'Aucun stockage disponible';

  @override
  String get storageNoDownloadFolders =>
      'Aucun dossier de téléchargement existant trouvé';

  @override
  String get storageExistingFolders => 'Dossiers de téléchargement existants';

  @override
  String storageItemCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count éléments',
      one: '$count élément',
    );
    return '$_temp0';
  }

  @override
  String get storageAllFilesAccess =>
      'Accordez l\'« Accès à tous les fichiers » pour stocker les téléchargements de façon permanente, puis choisissez à nouveau le mode.';

  @override
  String get storageSettings => 'Paramètres';

  @override
  String get storageNoVolume => 'Impossible de localiser un volume de stockage';

  @override
  String get storageNotWritable =>
      'Ce dossier n\'est pas accessible en écriture — choisissez-en un autre.';

  @override
  String get storageNewFolder => 'Nouveau dossier';

  @override
  String get storageFolderNameHint => 'Nom du dossier';

  @override
  String get storageCouldNotCreateFolder => 'Impossible de créer le dossier';

  @override
  String get storageNoSubfolders => 'Aucun sous-dossier ici';

  @override
  String get storageUseThisFolder => 'Utiliser ce dossier';

  @override
  String get storageMovedToNewFolder =>
      'Fichiers téléchargés déplacés vers le nouveau dossier.';

  @override
  String get storageMoveAlreadyRunning =>
      'Un déplacement est déjà en cours — laissez-le se terminer d\'abord.';

  @override
  String get storageMigrateTitle => 'Volume de stockage différent';

  @override
  String storageMigrateBody(int count, String size) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other:
          'Les $count fichiers téléchargés de ce serveur ($size) se trouvent sur un volume de stockage différent du nouvel emplacement. Choisissez ce qu\'il faut faire :',
      one:
          'Le fichier téléchargé de ce serveur ($size) se trouve sur un volume de stockage différent du nouvel emplacement. Choisissez ce qu\'il faut faire :',
    );
    return '$_temp0';
  }

  @override
  String storageMigrateNoSpace(String free) {
    return 'Espace libre insuffisant à la destination ($free libres). Un déplacement risque d\'échouer en cours de route — libérez d\'abord de l\'espace.';
  }

  @override
  String get storageMigrateMove => 'Les déplacer';

  @override
  String get storageMigrateMoveBody =>
      'Copier vers le nouvel emplacement en arrière-plan, en supprimant chaque ancienne copie au fur et à mesure. Gardez l\'application ouverte jusqu\'à la fin.';

  @override
  String get storageMigrateLeave => 'Les laisser';

  @override
  String get storageMigrateLeaveBody =>
      'Changer maintenant ; les anciens téléchargements restent où ils sont et seront retéléchargés au nouvel emplacement.';

  @override
  String get storageMigrateDelete => 'Supprimer les anciens téléchargements';

  @override
  String get storageMigrateDeleteBody =>
      'Changer maintenant et supprimer les anciens fichiers ; ils seront retéléchargés au nouvel emplacement.';

  @override
  String get storageMovingBackground =>
      'Déplacement de vos téléchargements en arrière-plan — gardez l\'application ouverte.';

  @override
  String get storageChooseFolderFirst =>
      'Choisissez d\'abord un dossier de téléchargement.';

  @override
  String get storageChooseSdFolderFirst =>
      'Choisissez d\'abord un dossier sur la carte SD. Si chaque dossier est rejeté, votre appareil n\'autorise peut-être pas les applications à écrire sur la carte — utilisez Permanent ou Local à l\'application à la place.';

  @override
  String get castPlayOn => 'Diffuser sur';

  @override
  String get castPlayOnTooltip => 'Diffuser sur…';

  @override
  String get castSearching => 'Recherche d\'appareils de diffusion…';

  @override
  String get castNotSeeing =>
      'Vous ne voyez pas votre appareil ? Vérifiez qu\'il est sur le même réseau Wi-Fi.';

  @override
  String get castVisualizer => 'Diffuser le visualiseur';

  @override
  String get castVisualizerSubtitle => 'Chromecast uniquement';

  @override
  String get castThisDevice => 'Cet appareil';

  @override
  String get visualizerNoKnobs => 'Ce shader n\'a aucun curseur.';

  @override
  String get nowPlaying => 'Lecture en cours';

  @override
  String get settingsPlayerLayout => 'Disposition de la lecture en cours';

  @override
  String get playerLayoutSmall => 'Petit';

  @override
  String get playerLayoutMedium => 'Moyen';

  @override
  String get playerLayoutLarge => 'Grand';

  @override
  String get playerLayoutXl => 'XL';

  @override
  String get queueNothingToDownloadEmpty =>
      'La file est vide — rien à télécharger';

  @override
  String get queueNothingToDownloadSaved =>
      'Rien à télécharger — les morceaux sont déjà enregistrés';

  @override
  String get settingsAccentColor => 'Couleur d\'accent';

  @override
  String get accentThemeDefault => 'Couleur par défaut du thème';

  @override
  String get accentCustom => 'Personnalisé';

  @override
  String get lanOnYourNetwork => 'Serveurs sur votre réseau local';

  @override
  String get lanSearching => 'Recherche de serveurs…';

  @override
  String get lanRefresh => 'Actualiser';

  @override
  String lanServerVersion(String version) {
    return 'mStream v$version';
  }

  @override
  String lanLoginTitle(String name) {
    return 'Connexion à $name';
  }

  @override
  String get lanUnreachable =>
      'Impossible de joindre ce serveur sur le réseau.';

  @override
  String get lanNoCode =>
      'La connexion rapide est activée sur ce serveur, mais aucun code d\'appairage n\'a été partagé. Connectez-vous en tant qu\'admin ou demandez à l\'opérateur d\'activer le partage du code.';

  @override
  String get settingsResumeQueue => 'Reprendre la file au démarrage';

  @override
  String get settingsOfflineQueue => 'Télécharger la file';

  @override
  String get settingsOfflineQueueSubtitle =>
      'La lecture continue si la connexion est coupée.';

  @override
  String get settingsOfflineQueueWifiOnly => 'Wi-Fi uniquement';

  @override
  String get settingsAutoDownloadCap => 'Limite de téléchargement';

  @override
  String get settingsAutoDownloadCapUnlimited => 'Illimité';

  @override
  String get settingsAutoDownloadCapField => 'Morceaux';

  @override
  String get settingsAutoDownloadCapDialogBody =>
      'Combien de morceaux garder téléchargés, à partir de celui en cours. Au-delà, les plus anciens sont supprimés quand de nouveaux arrivent.';

  @override
  String get downloadWaitingWifi => 'En attente du Wi-Fi';

  @override
  String get settingsRatingHalf => 'Notes en demi-étoiles';

  @override
  String get settingsRatingHalfSubtitle => 'Appui long sur une étoile';

  @override
  String get ratingTitle => 'Noter';

  @override
  String get ratingFailed => 'Note non enregistrée';

  @override
  String get diagnosticsTitle => 'Diagnostics';

  @override
  String get diagnosticsEnable => 'Activer la journalisation';

  @override
  String get diagnosticsHint =>
      'Les journaux restent sur votre appareil. Les jetons sont masqués avant copie ou partage.';

  @override
  String get diagnosticsVerbose => 'Journalisation détaillée';

  @override
  String get diagnosticsVerboseHint =>
      'Journalise aussi les événements très fréquents, comme les changements de focus de l\'application. Utile uniquement pour diagnostiquer un problème de lecture.';

  @override
  String get diagnosticsCopy => 'Copier';

  @override
  String get diagnosticsShare => 'Partager';

  @override
  String get diagnosticsClear => 'Effacer';

  @override
  String get diagnosticsCopied => 'Journaux copiés dans le presse-papiers';

  @override
  String get diagnosticsEmpty => 'Aucun journal pour l\'instant';

  @override
  String get storageAppExternal => 'Externe (application)';

  @override
  String get storageAppSdCard => 'Carte SD (application)';

  @override
  String get selfSignedTitle => 'Autoriser le certificat auto-signé';

  @override
  String get selfSignedSubtitle =>
      'Ignorer la validation TLS pour ce serveur. À n\'activer que sur un réseau de confiance.';

  @override
  String get importedShadersTitle => 'Shaders importés';

  @override
  String get importedShadersRescan => 'Réanalyser le dossier';

  @override
  String get importedShadersDropHint =>
      'Déposez des fichiers .glsl dans ce dossier, puis Réanalyser :';

  @override
  String get importedShadersCopyPath => 'Copier le chemin';

  @override
  String get importedShadersReachableHint =>
      'Accessible via USB. Désinstaller mStream le supprime.';

  @override
  String get importedShadersRemove => 'Supprimer';

  @override
  String get importedShadersEmptyTitle => 'Pas encore de shader';

  @override
  String get importedShadersEmptyBody =>
      'Copiez des fichiers .glsl de style Shadertoy dans le dossier ci-dessus, puis touchez Réanalyser.';

  @override
  String get importedShadersInvalid =>
      'Peut ne pas fonctionner : ni mainImage ni main';

  @override
  String get importedShadersImportDownloads =>
      'Importer des .glsl depuis Téléchargements';

  @override
  String importedShadersDownloadsImported(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count shaders importés',
      one: '$count shader importé',
    );
    return '$_temp0';
  }

  @override
  String get importedShadersDownloadsNone =>
      'Aucun nouveau fichier .glsl dans Téléchargements';

  @override
  String get importedShadersDownloadsNoPermission =>
      'L\'autorisation de stockage est nécessaire pour lire Téléchargements';

  @override
  String get addServerTabUrl => 'URL du serveur';

  @override
  String get addServerTabQuickConnect => 'Connexion rapide';

  @override
  String get irohPairingHeader => 'Se connecter avec un code d\'appairage';

  @override
  String get irohPairingBody =>
      'Activez « Remote Access » (accès distant) sur le serveur, puis collez son code d\'appairage ou scannez le QR.';

  @override
  String get irohPairingCodeLabel => 'Code d\'appairage';

  @override
  String get irohPairingCodeHint =>
      'Collez le code depuis le panneau « Remote Access » du serveur';

  @override
  String get irohShowPairingCode => 'Afficher le code d\'appairage';

  @override
  String get irohQrBody =>
      'Scannez-le avec l\'application mStream sur un autre appareil pour le connecter à ce serveur, ou copiez le code et collez-le là-bas.';

  @override
  String get irohQrCaution =>
      'Toute personne disposant de ce code peut se connecter à votre serveur.';

  @override
  String get irohScanQr => 'Scanner le QR';

  @override
  String get irohPaste => 'Coller';

  @override
  String get irohTestConnection => 'Tester la connexion';

  @override
  String get irohTesting => 'Test en cours…';

  @override
  String get irohScannerTitle => 'Scanner le QR d\'appairage';

  @override
  String get irohQrAndroidOnly =>
      'Le scan de QR n\'est pas disponible sur cet appareil.';

  @override
  String get irohAndroidOnly =>
      'La connexion rapide n\'est pas disponible sur cet appareil.';

  @override
  String get irohCameraPermission =>
      'L\'autorisation d\'accès à la caméra est nécessaire pour scanner un code.';

  @override
  String get irohPasteFirst =>
      'Collez ou scannez d\'abord un code d\'appairage.';

  @override
  String get irohTestFirst => 'Testez d\'abord la connexion.';

  @override
  String get irohTestConnected => 'Connecté via le tunnel iroh';

  @override
  String irohTestConnectedVersion(String version) {
    return 'Connecté via le tunnel iroh — mStream v$version';
  }

  @override
  String get irohPathSuffixDirect => ' · directe';

  @override
  String get irohPathSuffixRelay => ' · via relais';

  @override
  String get irohTunnelNoAnswer =>
      'The tunnel connected, but the server closed the request without answering. On the server, check the bind address and port mStream listens on (the tunnel reaches it at 127.0.0.1), then try again.';

  @override
  String get irohTunnelTimeout =>
      'Tunnel ouvert, mais le serveur n\'a pas répondu à temps.';

  @override
  String irohTunnelTestFailed(String error) {
    return 'Échec du test du tunnel : $error';
  }

  @override
  String get irohSignInHeader => 'Se connecter';

  @override
  String get irohSigningIn => 'Connexion en cours…';

  @override
  String get irohSignInSave => 'Se connecter et enregistrer';

  @override
  String get irohSignInTimeout => 'Délai de connexion dépassé.';

  @override
  String irohSignInFailed(String error) {
    return 'Échec de la connexion : $error';
  }

  @override
  String irohSignInFailedHttp(int status) {
    return 'Échec de la connexion (HTTP $status). Vérifiez votre nom d\'utilisateur et votre mot de passe.';
  }

  @override
  String get irohBannerConnecting => 'Connexion au serveur…';

  @override
  String get irohBannerReconnecting => 'Reconnexion au serveur…';

  @override
  String get irohBannerDisconnected => 'Déconnecté du serveur.';

  @override
  String get irohBannerRelay => 'Connecté via un relais — chemin plus lent.';

  @override
  String get irohBannerRepair =>
      'L\'appairage du serveur a changé — réappairez pour vous reconnecter.';

  @override
  String get irohRepairAction => 'Réappairer';

  @override
  String get irohRetry => 'Réessayer';

  @override
  String get irohRepairTitle => 'Réappairer le serveur';

  @override
  String get irohRepairBody =>
      'Le code d\'appairage de ce serveur a changé (son secret a été renouvelé). Collez ou scannez le nouveau code depuis le panneau « Remote Access » du serveur.';

  @override
  String get irohRepairFailed =>
      'Connexion impossible avec ce code — vérifiez-le et réessayez.';

  @override
  String get irohPathDirect => 'Directe';

  @override
  String get irohPathRelay => 'Relais';

  @override
  String get irohCastUnavailable =>
      'La diffusion vers des appareils externes n\'est pas disponible pour les serveurs pair-à-pair (iroh) — la lecture reste sur cet appareil.';

  @override
  String get irohShareUnavailable =>
      'Le partage n\'est pas disponible pour les serveurs pair-à-pair (iroh) — ils n\'ont pas d\'URL publique vers laquelle pointer.';

  @override
  String get discoverTitle => 'Dans le même style';

  @override
  String get discoverPageTitle => 'Découvrir';

  @override
  String discoverPageWindowDays(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count jours',
      one: '$count jour',
    );
    return '$_temp0';
  }

  @override
  String get discoverPageWindowAll => 'Toujours';

  @override
  String discoverPageWidened(String window) {
    return 'Rien sur les derniers $window : ceux-ci viennent de plus loin.';
  }

  @override
  String get discoverPageBasedOn => 'D’après';

  @override
  String get discoverPageBasedOnLast => 'D’après les derniers';

  @override
  String get discoverPageBasedOnAllTime => 'Période';

  @override
  String get discoverPageMoreOptions => 'Plus d’options';

  @override
  String get discoverPageNewSeeds => 'Nouveaux morceaux de départ';

  @override
  String get discoverPageAlbumsLibrary => 'Albums de votre bibliothèque';

  @override
  String discoverPageAlbumsPeer(String name) {
    return 'Albums de $name';
  }

  @override
  String get discoverPageAlbumsPeers => 'Albums des serveurs connectés';

  @override
  String get discoverPageSongsLibrary => 'Morceaux de votre bibliothèque';

  @override
  String discoverPageSongsPeer(String name) {
    return 'Morceaux de $name';
  }

  @override
  String get discoverPageSongsPeers => 'Morceaux des serveurs connectés';

  @override
  String get discoverPageLibraryNothing =>
      'Rien de nouveau dans votre bibliothèque ne ressemble à ces morceaux.';

  @override
  String get discoverPagePeersQuiet =>
      'Rien de vos serveurs connectés pour le moment.';

  @override
  String get discoverPagePeersFailed =>
      'Impossible de joindre vos serveurs connectés.';

  @override
  String get discoverPageSaveAsPlaylist => 'Enregistrer comme liste de lecture';

  @override
  String get discoverPageBrowseLibrary => 'Parcourir votre bibliothèque';

  @override
  String get discoverPageAgoToday => 'aujourd’hui';

  @override
  String get discoverPageAgoYesterday => 'hier';

  @override
  String discoverPageAgoMonths(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'il y a $count mois',
      one: 'il y a $count mois',
    );
    return '$_temp0';
  }

  @override
  String discoverPageAgoYears(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'il y a $count ans',
      one: 'il y a $count an',
    );
    return '$_temp0';
  }

  @override
  String get discoverPageRandomTitle =>
      'Écoutez quelques morceaux jusqu’au bout et cette page apprendra vos goûts';

  @override
  String get discoverPageRandomBody =>
      'Découvrir s’appuie sur les morceaux que vous écoutez jusqu’au bout. Les morceaux passés ne comptent jamais. En attendant, voici des suggestions autour d’un morceau tiré au hasard de votre bibliothèque.';

  @override
  String get discoverPageAnotherPick => 'Un autre';

  @override
  String get discoverPageChooseSong => 'Choisir un morceau…';

  @override
  String get discoverPageError =>
      'Impossible de charger Découvrir. Vérifiez la connexion et réessayez.';

  @override
  String get discoverPageRetry => 'Réessayer';

  @override
  String get discoverPagePickedHeader => 'Choisis pour cette visite';

  @override
  String get discoverPageRandomHeader => 'Choix au hasard';

  @override
  String get discoverPageDroppedHeader => 'Écartés';

  @override
  String get discoverPageDroppedNote => 'réactivez-en un pour le reprendre';

  @override
  String discoverPagePlayedTimes(int count) {
    return 'écouté $count×';
  }

  @override
  String get discoverPageListenedTo => 'écouté';

  @override
  String get discoverPageNotAnalyzed => 'pas encore analysé';

  @override
  String get discoverPageAddOwn => 'Ajoutez le vôtre';

  @override
  String get discoverPageAddOwnSub => 'un morceau dont vous voulez plus';

  @override
  String get discoverPagePickSong => 'Choisir un morceau…';

  @override
  String get discoverPagePickSongSub =>
      'cherchez dans votre bibliothèque ou prenez-en un au hasard';

  @override
  String discoverPageUseThese(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Utiliser ces $count',
      one: 'Utiliser ce morceau ($count)',
    );
    return '$_temp0';
  }

  @override
  String get discoverMatchedBySound => 'Correspondances sonores';

  @override
  String get discoverSimilarTracks => 'Morceaux similaires';

  @override
  String get discoverSimilarArtists => 'Artistes similaires';

  @override
  String get discoverFromNetwork => 'Depuis le réseau';

  @override
  String get discoverFromPeers => 'De vos pairs';

  @override
  String get discoverQueueAll => 'Tout ajouter à la file';

  @override
  String get discoverNewArtistsOnly => 'Nouveaux artistes uniquement';

  @override
  String get discoverNotAnalyzed =>
      'Ce morceau n\'a pas encore été analysé — les morceaux similaires apparaîtront quand l\'analyse de découverte l\'aura traité.';

  @override
  String get discoverScanPendingTitle => 'Rien n\'a encore été analysé';

  @override
  String get discoverScanPendingBody =>
      'La découverte est activée sur ce serveur, mais aucune musique n\'a encore été analysée. Les morceaux similaires apparaîtront une fois l\'analyse de découverte effectuée.';

  @override
  String get discoverCheckAgain => 'Vérifier à nouveau';

  @override
  String get discoverTurnedOff =>
      'La découverte a été désactivée sur ce serveur.';

  @override
  String get pathScanPending =>
      'Ce serveur n\'a encore analysé aucune musique, il n\'y a donc rien pour tracer un chemin. Cela fonctionnera une fois l\'analyse de découverte effectuée.';

  @override
  String get discoverNothingFound => 'Aucune correspondance trouvée.';

  @override
  String get discoverNoSeed =>
      'Lancez un morceau pour découvrir de la musique similaire.';

  @override
  String get discoverLeadCopied => 'Copié — bonne recherche !';

  @override
  String get discoverOpenMusicBrainz => 'Ouvrir sur MusicBrainz';

  @override
  String get discoverNetworkWarmingUp =>
      'Pas encore de données réseau — les bibliothèques des pairs se téléchargent en arrière-plan dès que d\'autres serveurs sont détectés.';

  @override
  String get discoverNetworkNothingNew =>
      'Rien de nouveau pour ce morceau — le réseau n\'a aucune correspondance inconnue.';

  @override
  String get discoverPeersUnreachable =>
      'Vos pairs n\'ont pas répondu — ils sont peut-être hors ligne en ce moment.';

  @override
  String get discoverPeersNothingNew =>
      'Rien de nouveau pour ce morceau sur les serveurs de vos pairs.';

  @override
  String get autoDjSonicTitle => 'Similarité sonore';

  @override
  String get autoDjSonicSeedLabel => 'Morceau de départ';

  @override
  String get autoDjSonicSeedNone =>
      'Aucun morceau de départ — le morceau en cours ancre la session.';

  @override
  String get autoDjSonicSeedBanner =>
      'Choisissez le morceau de départ — touchez un morceau n\'importe où dans la bibliothèque';

  @override
  String get autoDjSonicSeedSearchHint => 'Rechercher un morceau…';

  @override
  String get autoDjSonicSeedRandom => 'Morceau aléatoire';

  @override
  String get autoDjSonicSeedRemove => 'Retirer le morceau de départ';

  @override
  String get autoDjSonicSeedFailed => 'Impossible d\'obtenir un morceau';

  @override
  String get autoDjSeedNoMatch => 'Aucun morceau ne correspond à vos filtres';

  @override
  String get discoverFindSimilar => 'Trouver des morceaux similaires';

  @override
  String get discoverStartSession => 'Lancer une session sonore';

  @override
  String get discoverStartSessionSubtitle =>
      'De la musique sans fin qui sonne comme ce morceau — remplace votre file.';

  @override
  String get discoverStartSessionSubtitleRandom =>
      'De la musique sans fin à partir d\'un morceau de départ aléatoire — remplace votre file.';

  @override
  String get discoverSessionStarted =>
      'Session sonore lancée — Auto DJ activé.';

  @override
  String get autoDjSonicAnchorRolling => 'Suivre l\'ambiance';

  @override
  String get autoDjSonicAnchorLocked => 'Rester sur le morceau de départ';

  @override
  String get autoDjSonicAnchorRollingHint =>
      'Chaque morceau suit le son récent de la session — elle peut évoluer lentement.';

  @override
  String get autoDjSonicAnchorLockedHint =>
      'Chaque morceau reste proche du morceau de départ pendant toute la session.';

  @override
  String get trackAddToPlaylist => 'Ajouter à la liste de lecture';

  @override
  String get trackAddToPlaylistFailed =>
      'Impossible d\'ajouter à la liste de lecture.';

  @override
  String get discoverPlayPathTo => 'Lancer un chemin sonore vers…';

  @override
  String get pathScreenTitle => 'Chemin sonore';

  @override
  String get pathStartNotAnalyzed =>
      'Le morceau de départ n\'a pas encore été analysé — attendez l\'analyse de découverte ou choisissez-en un autre.';

  @override
  String get pathEndNotAnalyzed =>
      'Le morceau d\'arrivée n\'a pas encore été analysé — attendez l\'analyse de découverte ou choisissez-en un autre.';

  @override
  String get pathStartSong => 'Morceau de départ';

  @override
  String get pathEndSong => 'Morceau d\'arrivée';

  @override
  String get pathLength => 'Longueur';

  @override
  String get pathRegenerate => 'Régénérer';

  @override
  String get pathSaveAsPlaylist => 'Enregistrer comme liste de lecture';

  @override
  String get pathSetupHint =>
      'Choisissez un morceau de départ et un morceau d\'arrivée — le voyage entre les deux se remplit tout seul.';

  @override
  String get pathNotSet => 'Non défini';

  @override
  String get pathUsePlaying => 'Utiliser le morceau en cours';

  @override
  String get pathSearchSong => 'Rechercher';

  @override
  String get pathBrowseLibrary => 'Parcourir la bibliothèque';

  @override
  String get pathBuild => 'Créer le voyage';

  @override
  String get pathStartOver => 'Recommencer';

  @override
  String get pathPickBannerStart =>
      'Choisissez le morceau de départ — touchez un morceau n\'importe où dans la bibliothèque';

  @override
  String get pathPickBannerEnd =>
      'Choisissez le morceau d\'arrivée — touchez un morceau n\'importe où dans la bibliothèque';

  @override
  String get pathNothingPlaying => 'Aucune lecture en cours';

  @override
  String pathPickOnServer(String server) {
    return 'Choisissez un morceau sur $server';
  }

  @override
  String get welcomeTranslationNote =>
      'Cette langue a été traduite automatiquement et peut sembler maladroite.';

  @override
  String get welcomeTranslationCta => 'Aidez à traduire mStream';

  @override
  String get setupTitle => 'Configuration rapide';

  @override
  String get setupSkip => 'Ignorer';

  @override
  String get setupNext => 'Suivant';

  @override
  String get setupFinish => 'Terminer';

  @override
  String get setupBack => 'Retour';

  @override
  String get setupAccentTitle => 'Choisissez votre couleur';

  @override
  String get setupAccentBody =>
      'La couleur d\'accent met en valeur les boutons, les curseurs et les commandes du lecteur. Touchez-en une pour l\'essayer.';

  @override
  String get setupPlaybackTitle => 'Quand vous touchez un morceau';

  @override
  String get setupOfflineTitle => 'Gardez votre file disponible hors ligne';

  @override
  String get realAudioNoMic => 'mStream n\'utilise jamais votre micro.';

  @override
  String get playlistEmpty => 'La liste de lecture est vide';

  @override
  String get trackRating => 'Note';

  @override
  String albumDiscNumber(int n) {
    return 'Disque $n';
  }

  @override
  String get autoDjStartPickBanner =>
      'Choisissez le premier morceau — touchez un morceau n\'importe où dans la bibliothèque';

  @override
  String get autoDjStartAskShort => 'Demander';

  @override
  String serverVersionLabel(String version) {
    return 'Serveur v$version';
  }

  @override
  String get serverVersionUnknown => 'Version du serveur inconnue';

  @override
  String get serverUpdateUrgent => 'Mettez à jour votre serveur';

  @override
  String get serverUpdateAvailable => 'Mise à jour du serveur disponible';

  @override
  String serverTooOldWarning(String version) {
    return 'Ce serveur est en v$version. Certaines fonctionnalités nécessitent la v5.5 ou une version plus récente et seront indisponibles.';
  }

  @override
  String get torrentScreenTitle => 'Ajouter un torrent';

  @override
  String get torrentNoServer => 'Aucun serveur configuré.';

  @override
  String get torrentServerLabel => 'Serveur';

  @override
  String get torrentLibraryLabel => 'Bibliothèque';

  @override
  String get torrentNoLibraries => 'Aucune bibliothèque sur ce serveur';

  @override
  String get torrentSourceLabel => 'Source';

  @override
  String get torrentChooseFile => 'Choisir un fichier .torrent';

  @override
  String get torrentOr => 'ou';

  @override
  String get torrentMagnetLabel => 'Lien magnet';

  @override
  String get torrentMagnetInvalid => 'Lien magnet non valide';

  @override
  String torrentNotATorrent(String name) {
    return '« $name » n\'est pas un fichier .torrent';
  }

  @override
  String get torrentOpenWith => 'Ouvrir dans une autre application';

  @override
  String get torrentOpenWithNone =>
      'Aucune application de cet appareil ne peut ouvrir un fichier .torrent';

  @override
  String get torrentOpenWithFailed =>
      'Impossible de transmettre le torrent à une autre application';

  @override
  String get torrentIntentTitle => 'Torrent reçu';

  @override
  String get torrentIntentBody =>
      'Ajoutez-le à une bibliothèque de votre serveur mStream, ou confiez-le à une autre application.';

  @override
  String get torrentIntentAdd => 'Ajouter à mStream';

  @override
  String get torrentIntentDontAsk =>
      'Toujours ajouter à mStream, ne plus demander';

  @override
  String get settingsTorrentAskTitle => 'Demander quoi faire des torrents';

  @override
  String get settingsTorrentDefaultTitle =>
      'Application par défaut pour les torrents';

  @override
  String get settingsTorrentDefaultSub => 'Ouvre les paramètres Android';

  @override
  String get settingsTorrentDefaultFailed =>
      'Impossible d\'ouvrir les paramètres Android';

  @override
  String get torrentAutoDetect => 'Détecter les métadonnées';

  @override
  String get torrentDetecting => 'Détection…';

  @override
  String get torrentDetectNoMetadata =>
      'Métadonnées insuffisantes — remplissez les champs à la main';

  @override
  String get torrentDetected => 'Métadonnées détectées';

  @override
  String get torrentDetectGuess =>
      'Estimation approximative — vérifiez les champs';

  @override
  String get torrentMetadataLabel => 'Métadonnées';

  @override
  String get torrentArtistLabel => 'Artiste';

  @override
  String get torrentAlbumLabel => 'Album';

  @override
  String get torrentYearLabel => 'Année';

  @override
  String get torrentDestinationLabel => 'Destination';

  @override
  String get torrentPathLabel => 'Chemin dans la bibliothèque';

  @override
  String torrentPreviewNoLibrary(String path) {
    return '‹aucune bibliothèque›/$path';
  }

  @override
  String get torrentPreviewContents => '‹contenu du torrent›';

  @override
  String get torrentRenameRoot => 'Renommer le dossier racine du torrent';

  @override
  String get torrentRenameRootSub =>
      'L\'aligner sur le nom du dossier de destination';

  @override
  String get torrentForceFresh => 'Forcer un téléchargement complet';

  @override
  String get torrentForceFreshSub =>
      'Ne pas vérifier les fichiers déjà sur le serveur';

  @override
  String get torrentSubmit => 'Ajouter le torrent';

  @override
  String get torrentSubmitting => 'Ajout…';

  @override
  String get torrentUnavailable =>
      'Les torrents ne sont pas disponibles sur ce serveur.';

  @override
  String get torrentPickLibrary => 'Choisissez une bibliothèque';

  @override
  String get torrentOneSource =>
      'Ajoutez un lien magnet ou un fichier .torrent (un seul)';

  @override
  String get torrentPathEmpty => 'Le chemin de destination est vide';

  @override
  String get torrentSeeded => 'Déjà sur le disque — partage en cours';

  @override
  String get torrentAlreadyInClient => 'Déjà dans le client torrent';

  @override
  String get torrentInvalidFile => 'Fichier torrent invalide';

  @override
  String get torrentSeedCheckFailed =>
      'Impossible de vérifier les fichiers existants — téléchargement complet';

  @override
  String get torrentPartialTitle => 'Certains fichiers existent déjà';

  @override
  String get torrentPartialBody =>
      'Pointez le torrent vers une copie existante pour la partager et ne télécharger que ce qui manque.';

  @override
  String torrentPartialCount(String matched, String total) {
    return '$matched/$total fichiers ici';
  }

  @override
  String torrentPartialMissing(String missing) {
    return ' · $missing à télécharger';
  }

  @override
  String get torrentDownloadFresh => 'Télécharger quand même';

  @override
  String get torrentMatchNoFolder =>
      'Cette correspondance n\'a pas de nom de dossier — utilisez « Télécharger quand même »';

  @override
  String torrentAdded(String name) {
    return '« $name » ajouté';
  }

  @override
  String torrentDuplicate(String name) {
    return '« $name » est déjà dans le client';
  }

  @override
  String serverPickerVia(String parent) {
    return 'via $parent';
  }

  @override
  String get browserFederatedReadOnly => 'Serveur en lecture seule';

  @override
  String get browserFederatedReadOnlyNote =>
      'Les listes de lecture et les notes restent sur votre propre serveur';

  @override
  String get federatedShareUnavailable =>
      'Les morceaux d\'un serveur partagé ne peuvent pas être partagés d\'ici — ils sont dans la bibliothèque de quelqu\'un d\'autre.';

  @override
  String get federatedForget => 'Oublier';

  @override
  String get federatedHide => 'Masquer dans le sélecteur';

  @override
  String get federatedShow => 'Afficher dans le sélecteur';

  @override
  String federatedNoLongerListed(String parent) {
    return 'Plus partagé par $parent';
  }

  @override
  String get federationTitle => 'Fédération';

  @override
  String get federationStatusOn => 'Activée · connectée au relais';

  @override
  String get federationStatusConnecting => 'Activée · connexion…';

  @override
  String get federationStatusOff => 'Désactivée';

  @override
  String get federationStatusUnavailable => 'Indisponible sur cette plateforme';

  @override
  String get federationSharedWithYou => 'Partagé avec vous';

  @override
  String get federationRequestsSection => 'Demandes';

  @override
  String get federationYourSharedLibraries => 'Vos bibliothèques partagées';

  @override
  String get federationAddPeer => 'Ajouter un pair';

  @override
  String get federationShareLibrary => 'Partager une bibliothèque';

  @override
  String get federationNoPeersYet =>
      'Rien n\'est encore partagé avec ce serveur.';

  @override
  String get federationNoKeysYet =>
      'Pas encore de ticket — partagez une bibliothèque pour en créer un.';

  @override
  String get federationNoRequests =>
      'Pas encore de demande — les serveurs du réseau de découverte peuvent vous trouver ici.';

  @override
  String get federationClipboardTicket => 'Ticket dans le presse-papiers';

  @override
  String federationTicketPreview(String name, String libraries) {
    return '$name · partage $libraries';
  }

  @override
  String federationTicketPreviewNoLibraries(String name) {
    return '$name';
  }

  @override
  String get federationUnnamedServer => 'Serveur sans nom';

  @override
  String get federationAddPeerAction => 'Ajouter le pair';

  @override
  String get federationPeerLive => 'en ligne';

  @override
  String get federationPeerConnecting => 'connexion…';

  @override
  String get federationPeerDirectTunnel => 'tunnel direct';

  @override
  String federationPeerViaParent(String parent) {
    return 'via $parent';
  }

  @override
  String federationPeerViaTunnel(String parent) {
    return 'via le tunnel de $parent';
  }

  @override
  String get federationPeerMissing => 'plus partagé';

  @override
  String get federationPeerHidden => 'masqué dans le sélecteur';

  @override
  String federationMemberNote(String server) {
    return 'Le partage est réservé à l\'administrateur. Créer des tickets, ajouter des pairs et répondre aux demandes d\'appairage demandent une connexion administrateur sur $server — la même qui ouvre le panneau d\'administration.';
  }

  @override
  String get federationRestrictedNote =>
      'Ce serveur n\'accepte les appels d\'administration que depuis son propre réseau. Connectez-vous depuis chez vous pour gérer le partage ici.';

  @override
  String get federationDisabledNote =>
      'L\'API d\'administration est désactivée sur ce serveur.';

  @override
  String get federationUnsupportedNote =>
      'Ce serveur est trop ancien pour gérer la fédération depuis l\'application. Mettez mStream à jour.';

  @override
  String get federationLoadFailed => 'Impossible de joindre le serveur.';

  @override
  String get federationRetry => 'Réessayer';

  @override
  String get federationOffTitle =>
      'Partagez des bibliothèques avec les serveurs de vos amis';

  @override
  String get federationOffBody =>
      'Appairez deux serveurs mStream pour écouter la musique l\'un de l\'autre. On échange des tickets — envoyés par message, scannés ou collés.';

  @override
  String get federationOffPoint1Title =>
      'Lecture seule, chiffré de bout en bout';

  @override
  String get federationOffPoint1Body =>
      'Les listes de lecture et les notes ne quittent jamais votre serveur';

  @override
  String get federationOffPoint2Title => 'Ni redirection de port ni DNS';

  @override
  String get federationOffPoint2Body =>
      'iroh trouve le chemin — en direct quand c\'est possible, via un relais sinon';

  @override
  String get federationOffPoint3Title => 'Des tickets révocables';

  @override
  String get federationOffPoint3Body =>
      'Chacun ne sert qu\'une fois et peut être coupé à tout moment';

  @override
  String get federationOffAdminOnly =>
      'Seul l\'administrateur du serveur peut l\'activer.';

  @override
  String federationOffMemberNote(String server) {
    return 'La fédération est désactivée sur $server. Son administrateur peut l\'activer.';
  }

  @override
  String get federationTurnOn => 'Activer la fédération';

  @override
  String get federationUnavailableNote =>
      'Le composant iroh n\'a pas de version pour le système/processeur de ce serveur, le point de terminaison de fédération ne peut donc pas tourner ici.';

  @override
  String get federationTurnedOn => 'La fédération est activée';

  @override
  String get federationTurnedOff => 'La fédération est désactivée';

  @override
  String get federationToggleFailed =>
      'Impossible de modifier le paramètre de fédération.';

  @override
  String get federationSettingsTitle => 'Paramètres de fédération';

  @override
  String get federationSwitchSubtitle =>
      'Pair-à-pair, chiffré de bout en bout. Ni redirection de port ni DNS.';

  @override
  String get federationStatusSection => 'État';

  @override
  String get federationConnectedRelay => 'Connecté au relais';

  @override
  String get federationNotRunning => 'Point de terminaison arrêté';

  @override
  String get federationEndpointId => 'Identifiant du point de terminaison';

  @override
  String get federationEndpointCopied =>
      'Identifiant du point de terminaison copié';

  @override
  String get federationPairingRequestsSection => 'Demandes d\'appairage';

  @override
  String get federationRequestsInboxTitle =>
      'Accepter les demandes du réseau de découverte';

  @override
  String get federationRequestsInboxSubtitle =>
      'Désactivé par défaut. Quand c\'est désactivé, les nouvelles demandes sont refusées au niveau du transport ; les réponses à vos propres demandes arrivent toujours.';

  @override
  String get federationInboxFailed =>
      'Impossible de modifier la boîte de réception des demandes.';

  @override
  String get federationDefaultsSection =>
      'Valeurs par défaut des nouveaux tickets';

  @override
  String get federationDefaultsNote =>
      'Issues de la configuration du serveur — chaque ticket peut les changer';

  @override
  String get federationOffWarning =>
      'Désactiver la fédération coupe tous les ponts vers les pairs et masque vos tickets jusqu\'à la réactivation. Les pairs gardent leurs tickets.';

  @override
  String federationRequestWantsToPair(String name) {
    return '$name veut s\'appairer';
  }

  @override
  String federationRequestToName(String name) {
    return 'Demande à $name';
  }

  @override
  String federationRequestOffers(String libraries) {
    return 'Propose $libraries';
  }

  @override
  String get federationRequestOffersNothing => 'Ne propose rien';

  @override
  String federationRequestYouOffered(String libraries) {
    return 'Vous avez proposé $libraries';
  }

  @override
  String get federationRequestYouOfferedNothing => 'Vous n\'avez rien proposé';

  @override
  String get federationReqSending => 'envoi…';

  @override
  String get federationReqWaiting => 'en attente de leur réponse';

  @override
  String get federationReqSharingBack => 'partage en retour…';

  @override
  String get federationReqNeedsAnswer => 'attend votre réponse';

  @override
  String get federationReqSendingTicket => 'envoi de votre ticket…';

  @override
  String get federationReqWaitingShare => 'en attente de leur partage';

  @override
  String get federationReqDeclined => 'refusée';

  @override
  String get federationReqYouDeclined => 'refusée par vous';

  @override
  String get federationReqInboxClosed => 'leur boîte de réception est fermée';

  @override
  String get federationReqFederated => 'fédérée';

  @override
  String get federationReqWithdrawn => 'retirée';

  @override
  String get federationReqExpired => 'expirée';

  @override
  String get federationAccept => 'Accepter…';

  @override
  String get federationAcceptAndShare => 'Accepter et partager';

  @override
  String get federationDecline => 'Refuser';

  @override
  String get federationCancelRequest => 'Annuler la demande';

  @override
  String get federationDismiss => 'Ignorer';

  @override
  String get federationRequestTitle => 'Demande d\'appairage';

  @override
  String federationRequestReceived(String ago) {
    return 'Reçue $ago par le réseau de découverte';
  }

  @override
  String federationRequestSent(String ago) {
    return 'Envoyée $ago par le réseau de découverte';
  }

  @override
  String get federationShareBack => 'Partager en retour';

  @override
  String get federationShareBackNote =>
      'Rien n\'est échangé tant que vous n\'acceptez pas. Ils auront un accès en lecture seule aux bibliothèques que vous cochez — au moins une.';

  @override
  String get federationTheirLimits => 'Leurs limites';

  @override
  String get federationChange => 'Modifier';

  @override
  String get federationRequestIgnored =>
      'Les demandes de ce serveur sont ignorées pendant 7 jours';

  @override
  String get federationRequestAccepted => 'Demande acceptée';

  @override
  String get federationRequestDeclined => 'Demande refusée';

  @override
  String get federationRequestCancelled => 'Demande retirée';

  @override
  String get federationRequestActionFailed =>
      'Impossible de mettre à jour la demande.';

  @override
  String get federationTicketNameLabel => 'Pour qui est-ce ?';

  @override
  String get federationTicketNameHint =>
      'Vous seul voyez ce nom — il étiquette le ticket dans votre liste.';

  @override
  String get federationLibrariesTheyCanRead =>
      'Bibliothèques qu\'ils peuvent lire';

  @override
  String get federationLimitsSection => 'Limites';

  @override
  String get federationExactNumbers => 'Valeurs exactes';

  @override
  String get federationPresets => 'Préréglages';

  @override
  String get federationLimitStreamRate => 'Débit de lecture';

  @override
  String get federationLimitPerDay => 'Par jour';

  @override
  String get federationLimitStreams => 'Flux simultanés';

  @override
  String get federationLimitExpires => 'Expire';

  @override
  String get federationUnlimited => 'Illimité';

  @override
  String get federationNever => 'Jamais';

  @override
  String federationDays(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count jours',
      one: '$count jour',
    );
    return '$_temp0';
  }

  @override
  String get federationOneYear => '1 an';

  @override
  String federationKbps(int n) {
    return '$n kbit/s';
  }

  @override
  String federationMbps(int n) {
    return '$n Mbit/s';
  }

  @override
  String federationMbPerDay(int n) {
    return '$n Mo par jour';
  }

  @override
  String federationGbPerDay(int n) {
    return '$n Go par jour';
  }

  @override
  String federationStreamsCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count flux',
      one: '$count flux',
    );
    return '$_temp0';
  }

  @override
  String get federationNeverExpires => 'n\'expire jamais';

  @override
  String federationExpiresIn(String when) {
    return 'expire $when';
  }

  @override
  String get federationExpired => 'expiré';

  @override
  String federationInDays(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'dans $count jours',
      one: 'dans $count jour',
    );
    return '$_temp0';
  }

  @override
  String federationInHours(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'dans $count heures',
      one: 'dans $count heure',
    );
    return '$_temp0';
  }

  @override
  String get federationStreamRateField => 'Débit (kbit/s, 0 = illimité)';

  @override
  String get federationPerDayField => 'Quota journalier (Mo, 0 = illimité)';

  @override
  String get federationStreamsField => 'Flux max. (0 = illimité)';

  @override
  String get federationExpiresField => 'Expire dans (jours, 0 = jamais)';

  @override
  String get federationCreateTicket => 'Créer le ticket';

  @override
  String get federationMintFailed => 'Impossible de créer le ticket.';

  @override
  String get federationNoLibraries =>
      'Ce serveur n\'a aucune bibliothèque à partager.';

  @override
  String get federationTicketTitle => 'Votre ticket';

  @override
  String federationTicketFor(String name) {
    return 'Ticket pour $name';
  }

  @override
  String federationTicketReads(String libraries) {
    return 'Lit $libraries';
  }

  @override
  String get federationTicketQrHint =>
      'Dans la même pièce ? Faites-le scanner.';

  @override
  String get federationTicketWarning =>
      'Quiconque détient ce ticket peut lire ces bibliothèques jusqu\'à ce qu\'il soit utilisé ou révoqué. Envoyez-le par un canal privé — le premier serveur qui l\'utilise se l\'approprie.';

  @override
  String get federationCopyTicket => 'Copier le ticket';

  @override
  String get federationTicketCopied => 'Ticket copié';

  @override
  String get federationSendByText => 'Envoyer par message…';

  @override
  String get federationTicketRevokeNote =>
      'Révoquez-le à tout moment depuis Fédération. En cas de réinstallation, « Réinitialiser l\'utilisation » permet de réutiliser le ticket.';

  @override
  String get federationTicketNotRunning =>
      'Le point de terminaison de fédération est arrêté, il n\'y a donc pas encore de ticket à envoyer. Activez la fédération et revenez.';

  @override
  String federationShareMessage(String libraries, String ticket) {
    return 'Je partage avec toi ma bibliothèque musicale mStream — $libraries, en lecture seule. Dans l\'application mStream, ouvre Fédération → Ajouter un pair et colle ce ticket :\n\n$ticket\n\nIl ne sert qu\'une fois — je peux le révoquer à tout moment.';
  }

  @override
  String get federationShareSubject => 'Ticket de fédération mStream';

  @override
  String get federationKeyClaimed => 'utilisé';

  @override
  String get federationKeyNotClaimed => 'pas encore utilisé';

  @override
  String federationKeyTodayUsage(String amount) {
    return '$amount aujourd\'hui';
  }

  @override
  String federationKeyLastUsed(String ago) {
    return 'Dernière utilisation $ago';
  }

  @override
  String get federationKeyNeverUsed => 'Jamais utilisé';

  @override
  String federationKeyClaimedAgo(String ago) {
    return 'Utilisé $ago';
  }

  @override
  String get federationResetBinding => 'Réinitialiser l\'utilisation';

  @override
  String get federationResetBindingNote =>
      'Réinstallation chez l\'ami ? Permet de réutiliser le ticket.';

  @override
  String get federationBindingReset => 'Le ticket peut être réutilisé';

  @override
  String get federationRevoke => 'Révoquer';

  @override
  String federationRevokeConfirm(String name) {
    return 'Révoquer ce ticket ? $name perd l\'accès immédiatement.';
  }

  @override
  String get federationRevoked => 'Ticket révoqué';

  @override
  String get federationSaveLimits => 'Enregistrer les limites';

  @override
  String get federationLimitsSaved => 'Limites enregistrées';

  @override
  String get federationLimitsFailed => 'Impossible d\'enregistrer les limites.';

  @override
  String get federationSend => 'Envoyer';

  @override
  String get federationKeyTitle => 'Bibliothèque partagée';

  @override
  String federationActionFailed(String error) {
    return 'Ça n\'a pas marché : $error';
  }

  @override
  String get federationTheirTicket => 'Leur ticket';

  @override
  String get federationScanQr => 'Scanner un code QR';

  @override
  String get federationScannerTitle => 'Scanner un ticket de fédération';

  @override
  String get federationPaste => 'Coller';

  @override
  String get federationTicketPasted => 'Collé depuis le presse-papiers.';

  @override
  String get federationNotATicket =>
      'Ceci ne ressemble pas à un ticket de fédération.';

  @override
  String get federationTicketTooNew =>
      'Ce ticket vient d\'un mStream plus récent que ce que cette application comprend.';

  @override
  String get federationTicketExpiredNote => 'Ce ticket a expiré.';

  @override
  String get federationDisplayName => 'Nom affiché';

  @override
  String get federationDisplayNameHint =>
      'Facultatif — tel qu\'il apparaît dans votre sélecteur de serveurs.';

  @override
  String federationSharesLibraries(String libraries) {
    return 'Partage $libraries';
  }

  @override
  String get federationSharesUnknown =>
      'Bibliothèques non indiquées sur le ticket';

  @override
  String federationValidUntil(String date) {
    return 'valide jusqu\'au $date';
  }

  @override
  String federationAddPeerShowsUnder(String server) {
    return 'Apparaît sous $server';
  }

  @override
  String federationAddPeerReadOnly(String branch, String name) {
    return 'Lecture seule · $branch $name dans le sélecteur';
  }

  @override
  String get federationAddPeerDials => 'Votre serveur le joint via iroh';

  @override
  String get federationAddPeerEncrypted =>
      'Chiffré de bout en bout · sans redirection de port';

  @override
  String get federationAddPeerNoTicket =>
      'Pas encore de ticket ? Demandez qu\'on vous en envoie un par message.';

  @override
  String federationPeerAdded(String name) {
    return '$name ajouté';
  }

  @override
  String get federationAddPeerFailed => 'Impossible d\'ajouter le pair.';

  @override
  String get federationPeerAlreadyAdded =>
      'Ce ticket est déjà ajouté comme pair.';

  @override
  String get federationLibrariesYouCanRead =>
      'Bibliothèques que vous pouvez lire';

  @override
  String get federationDiscoverySection => 'Découverte';

  @override
  String get federationAskPeerSimilar =>
      'Demander de la musique similaire à ce pair';

  @override
  String get federationAskPeerSimilarNote =>
      'Envoie ce que vous écoutez — à ce pair seulement.';

  @override
  String get federationAutoDjSection => 'Auto DJ';

  @override
  String get federationAutoDjParticipates =>
      'Participe à l\'Auto DJ multi-serveur';

  @override
  String get federationAutoDjParticipatesNote =>
      'Répond avec sa propre bibliothèque quand le DJ est actif';

  @override
  String get federationAutoDjNotCandidate => 'Pas candidat à l\'Auto DJ';

  @override
  String get federationAutoDjNotCandidateNote =>
      'Il faut un serveur capable de répondre aux sélections sonores';

  @override
  String get federationTest => 'Tester';

  @override
  String get federationTesting => 'Test…';

  @override
  String get federationTestOk => 'Joignable';

  @override
  String federationTestFailed(String error) {
    return 'Injoignable : $error';
  }

  @override
  String federationCheckedAgo(String ago) {
    return 'Vérifié $ago';
  }

  @override
  String get federationNeverTested => 'Jamais testé';

  @override
  String federationLastSeen(String ago) {
    return 'Vu pour la dernière fois $ago';
  }

  @override
  String get federationBrowseLibrary => 'Parcourir cette bibliothèque';

  @override
  String get federationRemovePeer => 'Retirer le pair';

  @override
  String federationRemovePeerConfirm(String name) {
    return 'Retirer $name ? Les morceaux en file venant de ce pair s\'arrêteront.';
  }

  @override
  String federationPeerRemoved(String name) {
    return '$name retiré';
  }

  @override
  String get federationShowInPicker => 'Afficher dans le sélecteur de serveurs';

  @override
  String get federationShowInPickerNote =>
      'Les pairs masqués continuent de lire ce que vous avez mis en file depuis eux.';

  @override
  String get federationPeerReadOnlyNote =>
      'Lecture seule — les listes de lecture et les notes restent sur votre propre serveur.';

  @override
  String get federationPeerLibrariesUnknown =>
      'Pas encore listé — ouvrez-le une fois pour charger ses bibliothèques.';

  @override
  String get federationTransportDirect => 'Tunnel direct depuis ce téléphone';

  @override
  String get federationTransportRelay => 'Relais en attente';

  @override
  String federationTransportViaParent(String parent) {
    return 'Via $parent';
  }

  @override
  String federationTransportViaParentTunnel(String parent) {
    return 'Via $parent par son tunnel';
  }

  @override
  String get federationDiscoveryFailed =>
      'Impossible de modifier le paramètre de découverte.';

  @override
  String get agoJustNow => 'à l\'instant';

  @override
  String agoMinutes(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'il y a $count min',
      one: 'il y a $count min',
    );
    return '$_temp0';
  }

  @override
  String agoHours(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'il y a $count h',
      one: 'il y a $count h',
    );
    return '$_temp0';
  }

  @override
  String agoDays(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'il y a $count jours',
      one: 'il y a $count jour',
    );
    return '$_temp0';
  }

  @override
  String get browserP2pNetwork => 'Réseau P2P';

  @override
  String get browserP2pOn => 'Activé';

  @override
  String get browserP2pOff => 'Désactivé';

  @override
  String get p2pTitle => 'Réseau P2P';

  @override
  String get p2pStatusConnected => 'Connecté';

  @override
  String p2pNeighborsCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count voisins',
      one: '$count voisin',
    );
    return '$_temp0';
  }

  @override
  String p2pAnnouncingAs(String name) {
    return 's\'annonce comme $name';
  }

  @override
  String get p2pStatusSearching => 'Rejoint · en attente de voisins';

  @override
  String p2pStatusReconnecting(int n) {
    return 'Reconnexion · tentative $n';
  }

  @override
  String get p2pStatusNotJoined => 'Pas encore rejoint';

  @override
  String get p2pStatusOff => 'Désactivé';

  @override
  String get p2pStatusUnavailable => 'Indisponible sur cette plateforme';

  @override
  String get p2pStatNeighbors => 'voisins du maillage';

  @override
  String get p2pStatNeighborsSub => 'liens gossip actifs';

  @override
  String get p2pStatKnown => 'serveurs connus';

  @override
  String p2pStatKnownSub(int hidden, int blocked) {
    return '$hidden masqués · $blocked bloqués';
  }

  @override
  String get p2pStatHeld => 'instantanés conservés';

  @override
  String p2pStatHeldOf(int held, int max) {
    return '$held sur $max';
  }

  @override
  String p2pStatStorage(String used, String cap) {
    return '$used sur $cap';
  }

  @override
  String get p2pStatTracks => 'morceaux des pairs';

  @override
  String p2pStatTracksSub(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'consultables, $count bibliothèques',
      one: 'consultables, $count bibliothèque',
    );
    return '$_temp0';
  }

  @override
  String get p2pActivity => 'Activité';

  @override
  String get p2pActivitySubtitle =>
      'plus récent en premier · en mémoire seulement';

  @override
  String get p2pActivityEmpty =>
      'Rien pour l\'instant — les entrées dans le maillage, les téléchargements d\'instantanés, la rotation et les reprises s\'affichent ici au fil de l\'eau.';

  @override
  String get p2pActivityNote =>
      'L\'historique complet est dans les journaux du serveur.';

  @override
  String get p2pFromNetwork => 'Depuis le réseau';

  @override
  String get p2pFindSimilar => 'Trouver de la musique similaire sur le réseau';

  @override
  String p2pFindSimilarSub(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other:
          'Ouvre « Dans le même style » pour le morceau en cours · suggestions issues de $count bibliothèques téléchargées',
      one:
          'Ouvre « Dans le même style » pour le morceau en cours · suggestions issues de $count bibliothèque téléchargée',
    );
    return '$_temp0';
  }

  @override
  String get p2pFindSimilarNothingPlaying =>
      'Lancez d\'abord une lecture — « Dans le même style » suit le morceau en cours';

  @override
  String get p2pNewArtistsOnlySub =>
      'Masquer les suggestions d\'artistes déjà présents dans cette bibliothèque';

  @override
  String get p2pServersYouFollow => 'Serveurs suivis';

  @override
  String get p2pServersOnNetwork => 'Serveurs sur le réseau';

  @override
  String get p2pNoServersYet =>
      'Aucun serveur entendu pour l\'instant — ajoutez-en un avec le ticket d\'un ami, ou laissez une minute au gossip.';

  @override
  String p2pHiddenIncompatible(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count serveurs masqués — modèle incompatible',
      one: '$count serveur masqué — modèle incompatible',
    );
    return '$_temp0';
  }

  @override
  String get p2pShow => 'Afficher';

  @override
  String get p2pHide => 'Masquer';

  @override
  String get p2pBefriend => 'Ajouter un serveur ami';

  @override
  String get p2pOnline => 'en ligne';

  @override
  String p2pOfflineFor(String ago) {
    return 'hors ligne $ago';
  }

  @override
  String p2pTracksCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count morceaux',
      one: '$count morceau',
    );
    return '$_temp0';
  }

  @override
  String p2pSeedersCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count seeders',
      one: '$count seeder',
    );
    return '$_temp0';
  }

  @override
  String get p2pChipDownloaded => 'téléchargé';

  @override
  String get p2pChipUpdate => 'mise à jour disponible';

  @override
  String get p2pChipNotDownloaded => 'non téléchargé';

  @override
  String get p2pChipPinned => 'épinglé';

  @override
  String get p2pChipIncompatible => 'modèle incompatible';

  @override
  String get p2pChipFederated => 'fédéré';

  @override
  String get p2pChipTheyAsked => 'ils vous ont demandé';

  @override
  String get p2pChipRequestSent => 'demande envoyée';

  @override
  String get p2pSearchingTitle => 'Recherche de pairs';

  @override
  String get p2pSearchingBody =>
      'Le maillage se tisse en une minute environ. Cet écran se met à jour tout seul.';

  @override
  String get p2pReconnectingTitle => 'Reconnexion';

  @override
  String p2pReconnectingBody(int n) {
    return 'Le sidecar s\'est arrêté et est relancé (tentative $n) — rien à faire.';
  }

  @override
  String get p2pJoinTitle =>
      'Des recommandations issues des bibliothèques des autres';

  @override
  String get p2pWhatShared => 'Ce qui est partagé';

  @override
  String get p2pShared1 => 'Un instantané de métadonnées seulement';

  @override
  String get p2pShared1Sub =>
      'Artiste, titre, durée, empreintes sonores — jamais de fichiers audio';

  @override
  String get p2pShared2 => 'Le nom et la description de votre serveur';

  @override
  String get p2pShared2Sub =>
      'Visibles par tous sur le réseau, par défaut le réseau communautaire public';

  @override
  String get p2pHowYouAppear => 'Comment vous apparaissez';

  @override
  String get p2pServerName => 'Nom du serveur';

  @override
  String get p2pServerNameHint =>
      '« mStream » à côté de 18 000 autres mStream, c\'est la première chose à changer.';

  @override
  String get p2pDescription => 'Description';

  @override
  String get p2pDescriptionHint => '180 caractères, facultatif.';

  @override
  String get p2pAlsoAcceptRequests =>
      'Accepter aussi les demandes de fédération';

  @override
  String get p2pAlsoAcceptRequestsSub =>
      'Des invitations à partager des bibliothèques — rien n\'est partagé tant que vous n\'approuvez pas chacune. Active la fédération.';

  @override
  String get p2pJoin => 'Rejoindre le réseau';

  @override
  String get p2pJoining => 'Connexion…';

  @override
  String get p2pJoined =>
      'Réseau de découverte rejoint — laissez une minute au maillage.';

  @override
  String p2pJoinFailed(String error) {
    return 'Impossible de rejoindre le réseau : $error';
  }

  @override
  String p2pInboxFailed(String error) {
    return 'La découverte est active, mais la boîte de réception des demandes n\'a pas démarré : $error';
  }

  @override
  String get p2pUnavailableNote =>
      'Le binaire p2p-sidecar est introuvable pour cette plateforme et aucune version n\'est téléchargeable — le réseau est indisponible.';

  @override
  String get p2pWillDownloadNote =>
      'Le sidecar n\'est pas encore installé ; il sera téléchargé au moment de rejoindre le réseau.';

  @override
  String get p2pAdminOnlyNote =>
      'Seul l\'administrateur du serveur peut rejoindre le réseau.';

  @override
  String p2pMemberOffNote(String server) {
    return 'Le réseau de découverte est désactivé sur $server. Son administrateur peut le rejoindre.';
  }

  @override
  String p2pMemberNote(String server) {
    return 'Rejoindre, inviter et gérer les instantanés sont réservés à l\'administrateur. Connectez-vous à $server comme administrateur pour gérer le réseau ici.';
  }

  @override
  String get p2pSnapshotSection => 'Instantané';

  @override
  String p2pDownloadedSize(String size) {
    return 'Téléchargé · $size';
  }

  @override
  String p2pSnapshotSeq(int seq) {
    return 'Instantané $seq';
  }

  @override
  String p2pNewerAnnounced(int seq) {
    return 'un plus récent ($seq) est annoncé';
  }

  @override
  String get p2pNotDownloaded => 'Non téléchargé';

  @override
  String get p2pNotDownloadedSub =>
      'Téléchargez-le pour le chercher depuis Découvrir';

  @override
  String get p2pDownload => 'Télécharger';

  @override
  String get p2pUpdate => 'Mettre à jour';

  @override
  String get p2pDownloading => 'Téléchargement…';

  @override
  String get p2pDownloaded => 'Instantané téléchargé';

  @override
  String p2pDownloadFailed(String error) {
    return 'Impossible de télécharger l\'instantané : $error';
  }

  @override
  String get p2pPin => 'Épingler cet instantané';

  @override
  String p2pPinSub(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other:
          'La rotation libère les instantanés les moins utilisés après $count jours ; un instantané épinglé reste.',
      one:
          'La rotation libère les instantanés les moins utilisés après $count jour ; un instantané épinglé reste.',
    );
    return '$_temp0';
  }

  @override
  String get p2pPinSubNoRotation =>
      'La rotation est désactivée ; un instantané épinglé survit aussi au manque de place.';

  @override
  String get p2pRemoveSnapshot => 'Retirer l\'instantané';

  @override
  String get p2pSnapshotRemoved => 'Instantané retiré';

  @override
  String get p2pHeldSince => 'conservé depuis';

  @override
  String get p2pTracksLabel => 'morceaux';

  @override
  String get p2pSeedersLabel => 'seeders';

  @override
  String get p2pSeedersSub => 'servent l\'instantané';

  @override
  String get p2pFederatedWithYou => 'Fédéré avec vous';

  @override
  String get p2pFederatedWithYouSub =>
      'Ouvrez Fédération pour voir ce que vous lisez l\'un chez l\'autre';

  @override
  String get p2pTheyAskedYou => 'Ils ont demandé à fédérer';

  @override
  String get p2pTheyAskedYouSub => 'Examinez la demande dans Fédération';

  @override
  String get p2pRequestSentTitle => 'Demande envoyée';

  @override
  String get p2pRequestSentSub =>
      'En attente de leur réponse · à suivre dans Fédération';

  @override
  String get p2pAskToFederate => 'Demander à partager des bibliothèques';

  @override
  String get p2pAskToFederateSub =>
      'Envoie une demande sur le réseau — rien n\'est échangé pour l\'instant';

  @override
  String get p2pOpen => 'Ouvrir';

  @override
  String get p2pReview => 'Examiner';

  @override
  String get p2pForget => 'Oublier ce serveur';

  @override
  String get p2pForgetSub =>
      'Hors ligne et rien de téléchargé ; il revient s\'il est de nouveau entendu';

  @override
  String p2pForgotten(String name) {
    return '$name oublié';
  }

  @override
  String get p2pBlockServer => 'Bloquer le serveur';

  @override
  String p2pBlockConfirm(String name) {
    return 'Bloquer $name ? Ses annonces sont ignorées et son instantané retiré.';
  }

  @override
  String p2pBlocked(String name) {
    return '$name bloqué';
  }

  @override
  String get p2pUnblock => 'Débloquer';

  @override
  String get p2pUnblocked => 'Serveur débloqué';

  @override
  String get p2pIncompatibleNote =>
      'Modèle d\'empreintes incompatible — sa bibliothèque ne peut pas alimenter la recherche de morceaux similaires de ce serveur.';

  @override
  String get p2pCompatible => 'modèle compatible';

  @override
  String get p2pModelUnknown => 'modèle inconnu';

  @override
  String get p2pNoDescription => 'Pas de description.';

  @override
  String get p2pUnnamedServer => 'Serveur sans nom';

  @override
  String get p2pFederateTitle => 'Demander à fédérer';

  @override
  String get p2pFederateNote =>
      'Envoie une demande sur le réseau de découverte. Aucun accès n\'est échangé maintenant — ils voient votre nom, votre message et votre offre ; les bibliothèques ne sont partagées que s\'ils acceptent.';

  @override
  String get p2pMessage => 'Message';

  @override
  String p2pMessageHint(int n) {
    return 'Facultatif · $n / 500';
  }

  @override
  String get p2pShareBackLibraries =>
      'Bibliothèques que vous partagerez en retour s\'ils acceptent';

  @override
  String get p2pShareBackNote =>
      'Décochez tout pour une demande à sens unique — vous ne feriez que lire les leurs.';

  @override
  String get p2pSendRequest => 'Envoyer la demande';

  @override
  String get p2pRequestSent => 'Demande envoyée — à suivre dans Fédération';

  @override
  String p2pRequestFailed(String error) {
    return 'Impossible d\'envoyer la demande : $error';
  }

  @override
  String get p2pTheirTicket => 'Leur ticket';

  @override
  String get p2pTheirTicketHint =>
      'Un ami trouve le sien sous « Inviter un ami » sur son écran Réseau P2P.';

  @override
  String get p2pTicketPasted => 'Collé depuis le presse-papiers.';

  @override
  String get p2pRememberFriend => 'Se souvenir de cet ami';

  @override
  String get p2pRememberFriendSub =>
      'Enregistré dans la configuration du serveur pour que l\'amitié survive aux redémarrages.';

  @override
  String get p2pJoinFriend => 'Rejoindre';

  @override
  String get p2pJoinedFriend => 'Rejoint — le maillage se tisse en une minute';

  @override
  String p2pJoinFriendFailed(String error) {
    return 'Impossible de rejoindre : $error';
  }

  @override
  String get p2pNotATicket =>
      'Ceci ne ressemble pas à un ticket de point de terminaison.';

  @override
  String get p2pScanQr => 'Scanner un code QR';

  @override
  String get p2pScannerTitle => 'Scanner un ticket réseau';

  @override
  String get p2pInviteFriend => 'Inviter un ami';

  @override
  String p2pYourTicketNote(String name) {
    return 'Votre ticket — un ami le colle ici sur son téléphone pour ajouter $name. C\'est une adresse, pas une clé d\'accès.';
  }

  @override
  String get p2pTicketCopied => 'Ticket copié';

  @override
  String p2pShareMessage(String ticket) {
    return 'Ajoute mon serveur mStream sur le réseau de découverte — dans l\'application mStream, ouvre Réseau P2P → Ajouter un serveur ami et colle ce ticket :\n\n$ticket';
  }

  @override
  String get p2pShareSubject => 'Ticket réseau de découverte mStream';

  @override
  String get p2pTicketNotReady =>
      'Le sidecar ne tourne pas encore, il n\'y a donc aucun ticket à partager.';

  @override
  String get p2pSettingsTitle => 'Paramètres du réseau';

  @override
  String get p2pSwitchTitle => 'Réseau de découverte';

  @override
  String get p2pSwitchSub =>
      'Annonce sur le réseau un instantané ne contenant que des métadonnées. Désactivez pour quitter — les données collectées restent locales.';

  @override
  String get p2pLeaveConfirm =>
      'Quitter le réseau de découverte ? Votre serveur cesse d\'annoncer et de télécharger des instantanés. La découverte locale continue de fonctionner.';

  @override
  String get p2pLeave => 'Quitter';

  @override
  String get p2pLeft => 'Réseau de découverte quitté';

  @override
  String p2pLeaveFailed(String error) {
    return 'Impossible de quitter le réseau : $error';
  }

  @override
  String get p2pEditIdentity => 'Nom et description';

  @override
  String get p2pIdentitySaved => 'Enregistré — annoncé sur le réseau';

  @override
  String p2pSaveFailed(String error) {
    return 'Impossible d\'enregistrer : $error';
  }

  @override
  String get p2pSnapshotsSection => 'Instantanés';

  @override
  String get p2pAutoDownload => 'Téléchargement auto jusqu\'à';

  @override
  String p2pServersCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count serveurs',
      one: '$count serveur',
    );
    return '$_temp0';
  }

  @override
  String get p2pStorageCap => 'Plafond de stockage';

  @override
  String get p2pRotate => 'Rotation des téléchargements';

  @override
  String get p2pForgetOffline => 'Oublier les serveurs hors ligne';

  @override
  String get p2pMeshSection => 'Maillage';

  @override
  String get p2pCommunitySeeds => 'Seeds communautaires';

  @override
  String get p2pCommunitySeedsOn => 'Amorçage via les serveurs seed publics';

  @override
  String get p2pCommunitySeedsOff =>
      'Désactivé — serveurs amis seulement ; se règle dans la configuration du serveur';

  @override
  String p2pBlockedServers(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count serveurs bloqués',
      one: '$count serveur bloqué',
      zero: 'Aucun serveur bloqué',
    );
    return '$_temp0';
  }

  @override
  String get p2pBlockedSub =>
      'Annonces ignorées, instantanés jamais téléchargés';

  @override
  String get p2pBlockedTitle => 'Serveurs bloqués';

  @override
  String get p2pSaved => 'Enregistré';

  @override
  String get p2pOff => 'Désactivé';

  @override
  String get p2pSave => 'Enregistrer';

  @override
  String get p2pSearchServers => 'Rechercher des serveurs — nom ou description';

  @override
  String federationInboxBanner(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count demandes de fédération en attente',
      one: '$count demande de fédération en attente',
    );
    return '$_temp0';
  }

  @override
  String get federationInboxBannerSub => 'Touchez pour accepter ou refuser';

  @override
  String federationInboxNotificationTitle(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count demandes de fédération sont en attente',
      one: 'Une demande de fédération est en attente',
    );
    return '$_temp0';
  }

  @override
  String federationInboxNotificationBody(String server) {
    return 'Sur $server. Ouvrez pour accepter ou refuser.';
  }

  @override
  String get federationInboxChannelName => 'Demandes de fédération';

  @override
  String get federationInboxChannelDescription =>
      'Une demande de partage de bibliothèques est arrivée sur l\'un de vos serveurs';

  @override
  String get federationNotifyTitle => 'M\'avertir des demandes';

  @override
  String get federationNotifySubtitle =>
      'Une notification sur le téléphone quand une demande arrive pendant que l\'application est ouverte ou en lecture';

  @override
  String get autoRecentlyPlayed => 'Écoutés récemment';

  @override
  String get settingsHistoryEnabled => 'Enregistrer les lectures';

  @override
  String get settingsHistorySend => 'Envoyer les lectures aux serveurs';

  @override
  String get settingsHistoryClear => 'Effacer l\'historique';

  @override
  String settingsHistoryClearConfirm(String size, int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other:
          'Cela supprime l\'historique d\'écoute de ce téléphone ($size), dont $count lectures pas encore synchronisées. Les serveurs gardent le leur.',
      one:
          'Cela supprime l\'historique d\'écoute de ce téléphone ($size), dont $count lecture pas encore synchronisée. Les serveurs gardent le leur.',
      zero:
          'Cela supprime l\'historique d\'écoute de ce téléphone ($size). Les serveurs gardent le leur.',
    );
    return '$_temp0';
  }

  @override
  String get settingsHistoryCleared => 'Historique d\'écoute effacé';

  @override
  String songInfoServerPlays(num count, Object server) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count lectures sur $server',
      one: '$count lecture sur $server',
    );
    return '$_temp0';
  }

  @override
  String songInfoDevicePlays(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count lectures sur ce téléphone',
      one: '$count lecture sur ce téléphone',
    );
    return '$_temp0';
  }

  @override
  String songInfoLastPlayed(Object ago) {
    return 'dernière écoute $ago';
  }

  @override
  String get listeningTitle => 'Statistiques d\'écoute';

  @override
  String get listeningScopeThisPhone => 'Ce téléphone';

  @override
  String get listeningScopeSheetTitle => 'Quoi afficher';

  @override
  String get listeningScopeSheetDevice =>
      'Ce que ce téléphone a lu : chaque serveur, les fichiers locaux, hors ligne. Conservé sur cet appareil.';

  @override
  String get listeningScopeSheetServer =>
      'Vos lectures sur ce serveur depuis toutes les applications : le lecteur web, d\'autres téléphones, et ce téléphone une fois synchronisé.';

  @override
  String get listeningScopeSheetLegacy =>
      'Pas encore de statistiques d\'écoute : nécessite mStream 6.27 ou plus récent.';

  @override
  String listeningScopeSheetPeer(Object server) {
    return 'Comptés sur $server : les morceaux d\'un pair comptent là où vit votre compte.';
  }

  @override
  String get listeningProvenanceDevice =>
      'Ce que ce téléphone a lu, sur chaque serveur et pour les fichiers locaux. Conservé sur cet appareil.';

  @override
  String listeningProvenanceServer(Object server) {
    return 'Vos lectures sur $server depuis toutes les applications, y compris les morceaux de ses pairs.';
  }

  @override
  String listeningProvenancePeer(Object peer, Object server) {
    return 'Vos lectures des morceaux de $peer, comptées sur $server.';
  }

  @override
  String listeningProvenanceFallback(Object server) {
    return '$server n\'a pas répondu : affichage des lectures de ce téléphone sur ce serveur.';
  }

  @override
  String listeningProvenanceLegacy(Object server) {
    return '$server n\'a pas encore de statistiques d\'écoute (mStream 6.27+) : affichage des lectures de ce téléphone sur ce serveur.';
  }

  @override
  String listeningUnsynced(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count lectures pas encore synchronisées',
      one: '$count lecture pas encore synchronisée',
    );
    return '$_temp0';
  }

  @override
  String get listeningPeriodWeek => 'Cette semaine';

  @override
  String get listeningPeriodMonth => 'Ce mois-ci';

  @override
  String get listeningPeriodQuarter => 'Ce trimestre';

  @override
  String get listeningPeriodYear => 'Cette année';

  @override
  String get listeningPeriodAll => 'Depuis le début';

  @override
  String get listeningTilePlays => 'Lectures';

  @override
  String get listeningTileTime => 'Temps d\'écoute';

  @override
  String get listeningTileTracks => 'Morceaux';

  @override
  String get listeningTileSkips => 'Ignorées';

  @override
  String get listeningTileStreak => 'Série';

  @override
  String get listeningTileSessions => 'Séances';

  @override
  String listeningDays(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count jours',
      one: '$count jour',
    );
    return '$_temp0';
  }

  @override
  String get listeningTileSubCounted => 'lectures comptées';

  @override
  String get listeningTileSubTracks => 'morceaux différents';

  @override
  String listeningTileSubSkips(Object pct) {
    return '$pct % des démarrages';
  }

  @override
  String listeningTileSubStreak(Object count) {
    return 'record : $count';
  }

  @override
  String listeningTileSubSessions(Object duration) {
    return 'environ $duration chacune';
  }

  @override
  String get listeningWhenYouListen => 'Quand vous écoutez';

  @override
  String listeningMostAround(Object hour) {
    return 'Surtout vers $hour';
  }

  @override
  String get listeningTop => 'Top';

  @override
  String get listeningTopTracks => 'Morceaux';

  @override
  String get listeningTopArtists => 'Artistes';

  @override
  String get listeningTopAlbums => 'Albums';

  @override
  String get listeningByPlays => 'Lectures';

  @override
  String get listeningByTime => 'Temps';

  @override
  String listeningPlays(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count lectures',
      one: '$count lecture',
    );
    return '$_temp0';
  }

  @override
  String listeningTracksCount(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count morceaux',
      one: '$count morceau',
    );
    return '$_temp0';
  }

  @override
  String get listeningRecent => 'Lectures récentes';

  @override
  String get listeningLoadMore => 'Charger plus';

  @override
  String get listeningEmptyTitle => 'Aucune lecture pour l\'instant';

  @override
  String get listeningEmptyDevice =>
      'Les lectures apparaissent ici au fil de vos écoutes. Ce téléphone tient son propre historique ; votre serveur tient le vôtre pour toutes les applications.';

  @override
  String listeningEmptyServer(Object server) {
    return 'Rien n\'a encore été signalé à $server. Les lectures de ce téléphone arriveront une fois synchronisées.';
  }

  @override
  String get listeningEmptyPeriod => 'Rien sur cette période.';

  @override
  String get listeningOutcomeCompleted => 'Terminée';

  @override
  String get listeningOutcomeSkipped => 'Ignorée';

  @override
  String get listeningOutcomeStopped => 'Arrêtée';

  @override
  String listeningOutcomeAt(Object outcome, Object position) {
    return '$outcome à $position';
  }

  @override
  String get listeningNotCounted => 'non comptée';

  @override
  String listeningVia(Object peer) {
    return 'via $peer';
  }

  @override
  String listeningRepeats(Object count) {
    return '×$count';
  }

  @override
  String get listeningLocalFile => 'Fichier local';

  @override
  String get listeningHistoryOff =>
      'L\'historique d\'écoute est désactivé. Activez-le dans les paramètres pour enregistrer les lectures sur ce téléphone.';

  @override
  String listeningError(Object message) {
    return 'Chargement impossible : $message';
  }

  @override
  String get listeningRetry => 'Réessayer';

  @override
  String get listeningToday => 'Aujourd\'hui';

  @override
  String get listeningYesterday => 'Hier';

  @override
  String get listeningPlaysPerDay => 'Lectures par jour';

  @override
  String get listeningPlaysPerMonth => 'Lectures par mois';

  @override
  String listeningMostOnDay(int count, String date) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Le plus le $date : $count lectures',
      one: 'Le plus le $date : $count lecture',
    );
    return '$_temp0';
  }

  @override
  String listeningMostInMonth(int count, String month) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Le plus en $month : $count lectures',
      one: 'Le plus en $month : $count lecture',
    );
    return '$_temp0';
  }

  @override
  String get settingsHomeWidget => 'Widget d\'écran d\'accueil';

  @override
  String get settingsHomeWidgetSubtitleIos =>
      'Appuyez longuement sur l\'écran d\'accueil, ajoutez un widget et choisissez mStream Music.';

  @override
  String get homeWidgetPickSize => 'Choisissez une taille';

  @override
  String get homeWidgetPinUnsupported =>
      'Ce lanceur ne peut pas ajouter de widgets d\'ici. Utilisez son propre sélecteur de widgets.';

  @override
  String discoverSheetPeerOnline(String name) {
    return '$name en ligne';
  }

  @override
  String discoverSheetPeerNotAnswering(String name) {
    return '$name ne répond pas';
  }

  @override
  String discoverSheetSongCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count morceaux',
      one: '$count morceau',
    );
    return '$_temp0';
  }

  @override
  String discoverSheetAlbumCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count albums',
      one: '$count album',
    );
    return '$_temp0';
  }

  @override
  String get discoverSheetNotInLibrary => 'absent de votre bibliothèque';

  @override
  String get discoverSheetInLibrary => 'dans votre bibliothèque';

  @override
  String discoverSheetYouHaveAlbums(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'vous avez $count albums',
      one: 'vous avez $count album',
    );
    return '$_temp0';
  }

  @override
  String get discoverSheetOpenAlbum => 'Ouvrir l’album';

  @override
  String get discoverSheetQueueAlbum => 'Ajouter l’album à la file';

  @override
  String get discoverSheetPlayAlbum => 'Lire l’album';

  @override
  String get discoverSheetOpenArtist => 'Ouvrir l’artiste';

  @override
  String get discoverSheetListen => 'Écouter';

  @override
  String get discoverSheetKeepCopy => 'Garder une copie';

  @override
  String get discoverSheetOpenElsewhere => 'Ouvrir ailleurs';

  @override
  String discoverSheetBrowsePeer(String name) {
    return 'Parcourir $name';
  }

  @override
  String get discoverSheetDownloadToPhone => 'Télécharger sur ce téléphone';

  @override
  String get discoverSheetDownloadToPhoneSub =>
      'Pour écouter hors ligne sur cet appareil';

  @override
  String discoverSheetAlbumFailed(String name) {
    return 'Impossible de charger cet album depuis $name';
  }

  @override
  String discoverAlbumCardMore(String album) {
    return 'Plus d’options pour $album';
  }

  @override
  String get discoverKeepThisSong => 'Ce morceau';

  @override
  String get discoverKeepAlbum => 'Album';

  @override
  String get discoverKeepArtist => 'Artiste';

  @override
  String get discoverKeepWhat => 'Que garder';

  @override
  String discoverKeepYouHave(int count) {
    return 'vous en avez $count';
  }

  @override
  String discoverKeepOnlyMissing(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Seulement les $count albums que vous n’avez pas',
      one: 'Seulement l’album que vous n’avez pas',
    );
    return '$_temp0';
  }

  @override
  String get discoverKeepFilesGoTo => 'Les fichiers vont dans';

  @override
  String discoverKeepPathTooLong(int max) {
    return 'Le chemin de cette copie dépasserait $max caractères, plus que ce que le serveur accepte';
  }

  @override
  String get discoverKeepFolderPerAlbum => 'un dossier par album';

  @override
  String get discoverKeepChange => 'Modifier';

  @override
  String get discoverKeepChangeHint => 'Modifier l’emplacement des copies';

  @override
  String get discoverKeepAddSong => 'Ajouter le morceau';

  @override
  String get discoverKeepAddAlbum => 'Ajouter l’album';

  @override
  String get discoverKeepAddEveryAlbum => 'Ajouter tous les albums';

  @override
  String discoverKeepAddAlbums(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Ajouter $count albums',
      one: 'Ajouter $count album',
    );
    return '$_temp0';
  }

  @override
  String get discoverKeepAddMissing => 'Ajouter les albums que vous n’avez pas';

  @override
  String get discoverKeepUploadsOff =>
      'Votre compte ne peut pas ajouter de fichiers à ce serveur';

  @override
  String get discoverKeepNoLibrary =>
      'Aucune bibliothèque de votre serveur n’accepte de nouveaux fichiers';

  @override
  String get discoverKeepStartFailed =>
      'Impossible de joindre votre serveur. Réessayez.';

  @override
  String get discoverKeepDestChanged =>
      'L’emplacement des fichiers a changé depuis l’ouverture. Vérifiez le chemin ci-dessus et ajoutez à nouveau.';

  @override
  String get discoverKeepDestChangedTryAgain =>
      'L’emplacement des fichiers a changé depuis l’ouverture. Vérifiez le chemin ci-dessus et réessayez.';

  @override
  String discoverKeepRetryAddsTo(String path) {
    return 'Réessayer range dans $path, votre emplacement enregistré actuel';
  }

  @override
  String discoverKeepAddAgainAddsTo(String path) {
    return 'Ajouter à nouveau range dans $path, votre emplacement enregistré actuel';
  }

  @override
  String discoverKeepConfirmTitle(int count, String peer) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Copier $count albums depuis $peer ?',
      one: 'Copier $count album depuis $peer ?',
    );
    return '$_temp0';
  }

  @override
  String discoverKeepConfirmEveryTitle(String artist, String peer) {
    return 'Copier tous les albums de $artist depuis $peer ?';
  }

  @override
  String discoverKeepConfirmBody(String path) {
    return 'Ils arrivent sur votre serveur dans $path, un dossier par album. Les morceaux que vous avez déjà sont ignorés.';
  }

  @override
  String discoverKeepConfirmBodyFlat(String path) {
    return 'Ils arrivent sur votre serveur dans $path. Les morceaux que vous avez déjà sont ignorés.';
  }

  @override
  String discoverKeepConfirmAction(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Copier $count albums',
      one: 'Copier $count album',
    );
    return '$_temp0';
  }

  @override
  String get discoverKeepConfirmEveryAction => 'Copier tous les albums';

  @override
  String get discoverJobQueued => 'En attente d’une place libre';

  @override
  String get discoverJobQueuedSub => 'Démarre toute seule';

  @override
  String get discoverJobCopying => 'Copie en cours';

  @override
  String get discoverJobStarting => 'Démarrage…';

  @override
  String get discoverJobStopping => 'Arrêt en cours…';

  @override
  String get discoverJobInCollection => 'Dans votre collection';

  @override
  String get discoverJobOwned => 'Déjà à vous';

  @override
  String get discoverJobOwnedSub => 'Votre bibliothèque a déjà ce morceau';

  @override
  String get discoverJobSkipped => 'Ignoré · un fichier est déjà là';

  @override
  String discoverJobExistsSub(String path) {
    return 'Un fichier existe déjà dans $path · rien n’a été écrasé';
  }

  @override
  String get discoverJobFailed => 'Échec de la copie';

  @override
  String get discoverJobFailedSub => 'La copie n’a pas abouti';

  @override
  String get discoverJobNothingCopiedLead => 'Rien n’a été copié';

  @override
  String get discoverJobNothingCopied => 'rien n’a été copié';

  @override
  String get discoverJobStopped => 'Arrêté';

  @override
  String discoverJobStoppedQuota(String peer) {
    return 'La limite de transfert de $peer l’a arrêtée';
  }

  @override
  String discoverJobStoppedBusy(String peer) {
    return '$peer diffuse trop de flux en ce moment';
  }

  @override
  String discoverJobStoppedPeer(String peer) {
    return '$peer n’est plus joignable';
  }

  @override
  String discoverJobStoppedRefused(String peer) {
    return '$peer n’autorise pas les copies avec la clé de votre serveur';
  }

  @override
  String get discoverJobCancelledNothing => 'Arrêté · rien n’a été copié';

  @override
  String discoverJobCancelledSome(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Arrêté · $count copiés',
      one: 'Arrêté · $count copié',
    );
    return '$_temp0';
  }

  @override
  String get discoverJobCancelledSub => 'Vous l’avez annulée';

  @override
  String discoverJobCancelledStay(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other:
          'Vous l’avez annulée · les $count morceaux restent dans votre collection',
      one: 'Vous l’avez annulée · le morceau reste dans votre collection',
    );
    return '$_temp0';
  }

  @override
  String get discoverJobNothingAll => 'Vous avez déjà tout';

  @override
  String discoverJobNothingFrom(String peer) {
    return 'Rien à copier depuis $peer';
  }

  @override
  String get discoverJobOnlyGuest => 'Rien d’eux à copier';

  @override
  String discoverJobOnlyGuestSub(String artist, String peer) {
    return '$artist n’apparaît qu’en invité sur les albums de $peer';
  }

  @override
  String discoverJobFromOther(String peer) {
    return 'Copie depuis $peer';
  }

  @override
  String discoverJobComesBack(String action) {
    return '« $action » revient à la fin de cette copie';
  }

  @override
  String get discoverJobDone => 'Terminé';

  @override
  String discoverJobCopiedCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count copiés',
      one: '$count copié',
    );
    return '$_temp0';
  }

  @override
  String discoverJobOwnedCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count déjà à vous',
      one: '$count déjà à vous',
    );
    return '$_temp0';
  }

  @override
  String discoverJobFailedCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count en échec',
      one: '$count en échec',
    );
    return '$_temp0';
  }

  @override
  String discoverJobAlbumsFailed(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count albums en échec',
      one: '$count album en échec',
    );
    return '$_temp0';
  }

  @override
  String discoverJobAlbumsLeftOut(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count albums laissés de côté',
      one: '$count album laissé de côté',
    );
    return '$_temp0';
  }

  @override
  String get discoverJobRetry => 'Réessayer';

  @override
  String get discoverJobAddAgain => 'Ajouter à nouveau';

  @override
  String get discoverJobAddToQueue => 'Ajouter à la file';

  @override
  String get discoverMarkWaiting => 'en attente';

  @override
  String get discoverMarkCopying => 'copie…';

  @override
  String discoverMarkCopyingCount(int done, int total) {
    return 'copie $done sur $total';
  }

  @override
  String get discoverMarkStopping => 'arrêt…';

  @override
  String get discoverMarkInCollection => 'dans votre collection';

  @override
  String get discoverMarkAlreadyYours => 'déjà à vous';

  @override
  String get discoverMarkStopped => 'arrêté';

  @override
  String get discoverMarkRefused => 'refusé';

  @override
  String get discoverMarkFailed => 'échec';

  @override
  String get discoverMarkSkipped => 'ignoré';

  @override
  String discoverCopiesCopying(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count en copie',
      one: '$count en copie',
    );
    return '$_temp0';
  }

  @override
  String discoverCopiesFailed(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count en échec',
      one: '$count en échec',
    );
    return '$_temp0';
  }

  @override
  String discoverCopiesLabel(String summary) {
    return 'Copies : $summary';
  }

  @override
  String get discoverCopiesTitle => 'Copies';

  @override
  String get discoverCopiesSectionCopying => 'En cours';

  @override
  String get discoverCopiesSectionAttention => 'Arrêtées ou en échec';

  @override
  String get discoverCopiesSectionFinished => 'Tout juste terminées';

  @override
  String get discoverCopiesClearFinished => 'Effacer les terminées';

  @override
  String get discoverCopiesEmpty => 'Aucune copie en cours';

  @override
  String get discoverCopiesEmptySub =>
      'Appuyez longuement sur un morceau ou un album d’un serveur connecté dans Découvrir pour en garder une copie.';

  @override
  String get discoverCopiesOpenDiscover => 'Ouvrir Découvrir';

  @override
  String get discoverCopiesLoadFailed => 'Impossible de charger vos copies';

  @override
  String get discoverCopiesLoadFailedSub =>
      'Votre serveur n’a pas répondu. Les copies continuent là-bas.';

  @override
  String get discoverCopiesLoading => 'Chargement de vos copies';

  @override
  String get discoverCopiesKindSong => 'Morceau';

  @override
  String get discoverCopiesKindAlbum => 'Album';

  @override
  String get discoverCopiesKindEvery => 'Tous les albums';

  @override
  String get discoverCopiesKindMissing => 'Ce qui vous manque';

  @override
  String discoverCopiesFrom(String peer) {
    return 'depuis $peer';
  }

  @override
  String discoverCopiesEveryAlbumBy(String artist) {
    return 'Tous les albums de $artist';
  }

  @override
  String discoverCopiesMissingOf(String artist) {
    return '$artist · albums que vous n’avez pas';
  }

  @override
  String get discoverCopiesAlreadyFinished => 'Déjà terminée · rien à annuler';

  @override
  String get discoverCopiesCancelFailed => 'Impossible d’annuler. Réessayez.';

  @override
  String get discoverCopiesDestChanged =>
      'Impossible de démarrer : l’emplacement des fichiers a changé — réessayez depuis Garder une copie';

  @override
  String discoverToastCopying(String title, String peer) {
    return 'Copie de $title depuis $peer';
  }

  @override
  String discoverToastCopyingEvery(String artist, String peer) {
    return 'Copie de tous les albums de $artist depuis $peer';
  }

  @override
  String discoverToastCopyingMissing(String artist, String peer) {
    return 'Copie depuis $peer des albums de $artist que vous n’avez pas';
  }

  @override
  String get discoverToastAdded => 'Ajouté à votre collection';

  @override
  String get discoverToastAlreadyYours => 'Déjà dans votre bibliothèque';

  @override
  String discoverToastFailed(String reason) {
    return 'Échec de la copie : $reason';
  }

  @override
  String discoverToastStopped(String reason) {
    return 'Arrêtée avant la fin : $reason';
  }

  @override
  String get discoverToastLinkFailed => 'Impossible d’ouvrir ce lien';

  @override
  String discoverToastSaved(String path) {
    return 'Enregistré · les copies vont dans $path';
  }

  @override
  String get discoverDestTitle => 'Où arrivent les copies';

  @override
  String get discoverDestSub =>
      'Un réglage pour votre compte · chaque copie l’utilise';

  @override
  String get discoverDestTagDefault => 'par défaut de la bibliothèque';

  @override
  String get discoverDestTagYours => 'le vôtre';

  @override
  String discoverDestLandsAt(String title) {
    return '$title arrive dans';
  }

  @override
  String get discoverDestFixLayout =>
      'Corrigez la disposition pour voir où arrivent les fichiers';

  @override
  String discoverDestPathTooLong(int max) {
    return 'Le chemin de ce morceau dépasserait $max caractères, plus que ce que le serveur accepte';
  }

  @override
  String get discoverDestLibrary => 'Bibliothèque';

  @override
  String get discoverDestLayout => 'Disposition';

  @override
  String get discoverDestPresetArtistAlbum => 'Artiste / Album';

  @override
  String get discoverDestPresetServer => 'Serveur / Artiste / Album';

  @override
  String get discoverDestPresetServerFolders =>
      'Mêmes dossiers que sur le serveur';

  @override
  String get discoverDestPresetLibrary => 'Disposition de la bibliothèque';

  @override
  String get discoverDestPresetCustom => 'Personnalisée';

  @override
  String get discoverDestCustomSub => 'Saisissez votre propre chemin';

  @override
  String get discoverDestCustomField => 'Disposition personnalisée';

  @override
  String discoverDestCustomHint(String example) {
    return 'ex. De mes amis ou $example';
  }

  @override
  String get discoverDestCustomHelp =>
      'Séparez les dossiers par /. Les variables classent les copies par artiste, album… ; un nom fixe met toutes les copies dans le même dossier.';

  @override
  String get discoverDestCustomEmpty =>
      'Saisissez un chemin pour voir où arrivent les fichiers';

  @override
  String get discoverDestInsertArtist => 'Insérer l’artiste';

  @override
  String get discoverDestInsertAlbum => 'Insérer l’album';

  @override
  String get discoverDestInsertYear => 'Insérer l’année';

  @override
  String get discoverDestInsertGenre => 'Insérer le genre';

  @override
  String get discoverDestInsertAlbumArtist => 'Insérer l’artiste de l’album';

  @override
  String get discoverDestInsertPeer => 'Insérer le nom du serveur';

  @override
  String get discoverDestInsertServerFolder => 'Insérer le dossier du serveur';

  @override
  String discoverDestErrUnknownVar(String name, String vars) {
    return 'Variable inconnue $name. Utilisez $vars.';
  }

  @override
  String discoverDestErrBraces(String example) {
    return 'Une accolade est mal placée : les variables s’écrivent comme $example.';
  }

  @override
  String discoverDestErrBaseBraces(String folder) {
    return '« $folder » est un dossier défini sur un autre appareil, mais dans une disposition il se lit comme une variable. Renommez-le ici ou choisissez une disposition.';
  }

  @override
  String get discoverDestErrAbsolute =>
      'Une disposition ne peut pas commencer par / : elle part de la bibliothèque.';

  @override
  String get discoverDestErrTraversal =>
      'Un chemin ne peut pas contenir de dossier « .. ».';

  @override
  String get discoverDestErrEmpty =>
      'Cela ne crée aucun dossier : ajoutez un nom ou une variable.';

  @override
  String get discoverDestErrHome =>
      'Un chemin ne peut contenir ni ~ ni \$HOME.';

  @override
  String get discoverDestErrGeneric => 'Ce chemin ne peut pas être utilisé.';

  @override
  String get discoverDestErrDrive =>
      'Un chemin ne peut pas utiliser une lettre de lecteur comme C:.';

  @override
  String discoverDestErrTooLong(int max) {
    return 'Une disposition peut compter au plus $max caractères.';
  }

  @override
  String get discoverDestErrControl =>
      'Un chemin ne peut pas contenir de tabulations ni d’autres caractères de contrôle.';

  @override
  String discoverDestMissing(String vars) {
    return 'Sans valeur pour ce morceau, donc absent du chemin : $vars';
  }

  @override
  String get discoverDestGenreSlot => 'genre';

  @override
  String get discoverDestArtistSlot => 'artiste';

  @override
  String get discoverDestYearSlot => 'année';

  @override
  String get discoverDestServerFolderSlot => 'dossier du serveur';

  @override
  String discoverKeepSlotNote(int count, String slots) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other:
          '$slots viennent des étiquettes de chaque morceau, donc ces morceaux peuvent arriver dans plusieurs dossiers.',
      one:
          '$slots vient des étiquettes de chaque morceau, donc ces morceaux peuvent arriver dans plusieurs dossiers.',
    );
    return '$_temp0';
  }

  @override
  String discoverKeepSlotNoteGenre(int count, String slots) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other:
          '$slots viennent des étiquettes de chaque morceau, donc ces morceaux peuvent arriver dans plusieurs dossiers (ce dossier est omis pour un morceau sans genre).',
      one:
          '$slots vient des étiquettes de chaque morceau, donc ces morceaux peuvent arriver dans plusieurs dossiers (ce dossier est omis pour un morceau sans genre).',
    );
    return '$_temp0';
  }

  @override
  String discoverKeepSlotNoteSong(String slots) {
    return '$slots vient des étiquettes du morceau (ce dossier est omis pour un morceau sans genre).';
  }

  @override
  String discoverKeepSlotNoteServer(String server) {
    return '$server vient de l\'emplacement de chaque morceau sur le serveur, donc ces morceaux peuvent arriver dans plusieurs dossiers.';
  }

  @override
  String discoverKeepSlotNoteServerTags(
    int count,
    String slots,
    String server,
  ) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other:
          '$slots viennent des étiquettes de chaque morceau et $server de son emplacement sur le serveur, donc ces morceaux peuvent arriver dans plusieurs dossiers.',
      one:
          '$slots vient des étiquettes de chaque morceau et $server de son emplacement sur le serveur, donc ces morceaux peuvent arriver dans plusieurs dossiers.',
    );
    return '$_temp0';
  }

  @override
  String discoverKeepSlotNoteServerTagsGenre(
    int count,
    String slots,
    String server,
  ) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other:
          '$slots viennent des étiquettes de chaque morceau et $server de son emplacement sur le serveur, donc ces morceaux peuvent arriver dans plusieurs dossiers (ce dossier est omis pour un morceau sans genre).',
      one:
          '$slots vient des étiquettes de chaque morceau et $server de son emplacement sur le serveur, donc ces morceaux peuvent arriver dans plusieurs dossiers (ce dossier est omis pour un morceau sans genre).',
    );
    return '$_temp0';
  }

  @override
  String get discoverDestUseDefault =>
      'Utiliser le réglage par défaut de la bibliothèque';

  @override
  String get discoverDestSaving => 'Enregistrement…';

  @override
  String get discoverDestLoadFailed =>
      'Impossible de charger l’emplacement des copies';

  @override
  String get discoverDestLoading => 'Chargement de l’emplacement des copies';

  @override
  String get discoverKeepFirstUse =>
      'Les copies vont sur votre serveur, pas sur ce téléphone. Vérifiez où elles arrivent avant la première.';

  @override
  String get discoverElsewhereExact => 'Pages exactes';

  @override
  String get discoverElsewhereSearch => 'Recherche';

  @override
  String get discoverElsewhereMbRecording => 'Enregistrement MusicBrainz';

  @override
  String get discoverElsewhereMbReleaseGroup =>
      'Groupe de parutions MusicBrainz';

  @override
  String get discoverElsewhereMbIsrc => 'ISRC MusicBrainz';

  @override
  String get discoverElsewhereEmpty => 'Aucun lien pour ce morceau';

  @override
  String get discoverElsewhereEmptySub =>
      'Il n’a pas d’identifiants MusicBrainz, ni titre ou artiste à rechercher.';

  @override
  String get discoverElsewhereFailed =>
      'Impossible de rechercher des liens pour le moment';

  @override
  String get discoverElsewhereLoading => 'Recherche des liens';

  @override
  String get discoverElsewhereOpensOutside => 'S’ouvre hors de l’app';

  @override
  String get visualizerMilkdropTitle => 'Visualiseur Milkdrop';

  @override
  String get visualizerShadertoyTitle => 'Visualiseur ShaderToy';

  @override
  String get realAudioSynthesizedNote =>
      'Sans cette autorisation, le visualiseur utilise des données synthétisées.';

  @override
  String get realAudioDontAskAgain => 'Ne plus demander';

  @override
  String get realAudioUseSynthesized => 'Utiliser des données synthétisées';

  @override
  String get realAudioUseReal => 'Utiliser l\'audio réel';

  @override
  String get queueSharePlaylist => 'Partager la liste de lecture';

  @override
  String get autoDjStopShort => 'Arrêter';

  @override
  String get autoDjPlayFrom => 'Lire depuis';

  @override
  String get autoDjAllServers => 'Tous les serveurs';

  @override
  String autoDjServersTakingPart(int count, int total) {
    return '$count sur $total';
  }

  @override
  String get autoDjQuickSettings => 'Paramètres rapides d’Auto DJ';

  @override
  String get autoDjAllSettings => 'Tous les paramètres d’Auto DJ';

  @override
  String autoDjServerCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count serveurs',
      one: '$count serveur',
    );
    return '$_temp0';
  }

  @override
  String get autoDjFirstSong => 'Premier morceau';

  @override
  String get autoDjFirstSongRandom => 'Aléatoire';

  @override
  String get autoDjFirstSongChoose => 'Choisir';

  @override
  String get autoDjMustMatch => 'Doit correspondre';

  @override
  String get autoDjPrefer => 'Préférer';

  @override
  String autoDjPercent(int pct) {
    return '$pct %';
  }

  @override
  String get autoDjDrift => 'Dériver';

  @override
  String get autoDjStayClose => 'Rester proche';

  @override
  String get autoDjGenres => 'Genres';

  @override
  String get autoDjGenresOnly => 'Uniquement';

  @override
  String get autoDjGenresSkip => 'Exclure';

  @override
  String autoDjGenresSkipValue(String genres) {
    return 'Sans $genres';
  }

  @override
  String get autoDjRating => 'Note';

  @override
  String autoDjRatingValue(String stars) {
    return '$stars★+';
  }

  @override
  String get autoDjAny => 'Indifférent';

  @override
  String autoDjLengthOver(String min) {
    return '$min+';
  }

  @override
  String autoDjLengthUnder(String max) {
    return 'Moins de $max';
  }

  @override
  String autoDjLengthBetween(String min, String max) {
    return '$min–$max';
  }

  @override
  String get autoDjIncludeUnknown => 'Inclure les inconnues';

  @override
  String get autoDjLengthShortest => 'Minimum';

  @override
  String get autoDjLengthLongest => 'Maximum';

  @override
  String get autoDjWheelHours => 'h';

  @override
  String get autoDjTempo => 'Beatmatching';

  @override
  String get autoDjSkipWords => 'Mots exclus';

  @override
  String get autoDjBatch => 'Lot';

  @override
  String get autoDjVaries => 'Variable';

  @override
  String autoDjMax(int count) {
    return '$count max';
  }

  @override
  String autoDjNeedsServer(String version) {
    return 'Serveur $version+';
  }

  @override
  String get autoDjDiscoveryOff => 'Sans découverte';

  @override
  String get autoDjStillScanning => 'Analyse en cours';

  @override
  String get autoDjTooStrict => 'Trop strict';

  @override
  String get autoDjNotOnPeers => 'Pas sur les pairs';

  @override
  String get autoDjNoMoodData => 'Pas de données d\'ambiance';

  @override
  String get autoDjOtherModel => 'Autre modèle audio';

  @override
  String get autoDjUnreachable => 'Injoignable';

  @override
  String get autoDjRemember => 'Mémoriser';

  @override
  String get autoDjGenresNone => 'Aucun genre';

  @override
  String get autoDjNoMatches => 'Aucun résultat';

  @override
  String get autoDjRecentlyPlayed => 'Écoutés récemment';

  @override
  String get autoDjFirstSongRecent => 'Récents';

  @override
  String get browseLoadFailed =>
      'Couldn\'t load this from the server. Check the connection and try again.';

  @override
  String get settingsSectionVisualizer => 'Visualiseur';

  @override
  String get settingsOfflineQueueFooter =>
      'Ne concerne que la file. Vos propres téléchargements sont toujours conservés.';

  @override
  String settingsAutoDownloadCapValue(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count morceaux',
      one: '$count morceau',
    );
    return '$_temp0';
  }

  @override
  String get settingsAutoDownloadCapHint => '0 = illimité';

  @override
  String get settingsStartupRecentHint => 'Ajoutés récemment';

  @override
  String settingsLetterStripValue(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count+ éléments',
      one: '$count+ élément',
      zero: 'Toujours',
    );
    return '$_temp0';
  }

  @override
  String get settingsLetterStripHint =>
      'Sur les listes A–Z. Sous ce seuil, les noms longs passent à la ligne.';

  @override
  String get settingsHistoryFooter =>
      'Les serveurs ne scrobblent vers Last.fm que si vous y avez lié un compte.';

  @override
  String get settingsHistoryEmpty => 'Vide';

  @override
  String get settingsHistoryOffTitle => 'Arrêter d\'enregistrer les lectures ?';

  @override
  String settingsHistoryOffBody(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other:
          'Cela supprime l\'historique d\'écoute de ce téléphone, dont $count lectures pas encore synchronisées. Les serveurs gardent le leur.',
      one:
          'Cela supprime l\'historique d\'écoute de ce téléphone, dont $count lecture pas encore synchronisée. Les serveurs gardent le leur.',
      zero:
          'Cela supprime l\'historique d\'écoute de ce téléphone. Les serveurs gardent le leur.',
    );
    return '$_temp0';
  }

  @override
  String get settingsHistoryOffConfirm => 'Désactiver';

  @override
  String get settingsHistoryClearTitle => 'Effacer l\'historique ?';

  @override
  String get settingsResetTitle => 'Réinitialiser les paramètres ?';

  @override
  String get settingsResetBody =>
      'Réinitialise aussi l\'égaliseur, le transcodage et quelques options hors des paramètres. Serveurs, téléchargements, historique d\'écoute et préréglages enregistrés sont conservés.';

  @override
  String get settingsResetBodyIos =>
      'Réinitialise aussi le transcodage et quelques options hors des paramètres. Serveurs, téléchargements et historique d\'écoute sont conservés.';
}
