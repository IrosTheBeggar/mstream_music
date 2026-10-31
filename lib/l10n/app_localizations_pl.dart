// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Polish (`pl`).
class AppLocalizationsPl extends AppLocalizations {
  AppLocalizationsPl([String locale = 'pl']) : super(locale);

  @override
  String get mainRemove => 'Usuń';

  @override
  String get playlistActionFailed =>
      'Nie udało się zapisać playlisty — nazwa może być już zajęta.';

  @override
  String get queueAddNext => 'Dodaj jako następny';

  @override
  String get queuePlayNow => 'Odtwórz teraz';

  @override
  String get queueAddToEnd => 'Dodaj na koniec kolejki';

  @override
  String get shuffle => 'Odtwarzanie losowe';

  @override
  String get variousArtists => 'Różni wykonawcy';

  @override
  String get appTitle => 'mStream Music';

  @override
  String get settingsLanguage => 'Język';

  @override
  String get languageSystemDefault => 'Domyślny systemu';

  @override
  String couldNotOpen(String url) {
    return 'Nie można otworzyć $url';
  }

  @override
  String trackCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count utworów',
      many: '$count utworów',
      few: '$count utwory',
      one: '1 utwór',
      zero: 'Brak utworów',
    );
    return '$_temp0';
  }

  @override
  String get reset => 'Resetuj';

  @override
  String get themeVelvet => 'Velvet';

  @override
  String get themeDark => 'Ciemny';

  @override
  String get themeLight => 'Jasny';

  @override
  String get tapAddToQueue => 'Dodaj do kolejki';

  @override
  String get tapPlayFromHere => 'Odtwarzaj od tego miejsca';

  @override
  String get tapAppendAndJump => 'Dodaj i odtwórz';

  @override
  String get visualizerSourceSynthesized => 'Syntetyczne';

  @override
  String get visualizerSourceReal => 'Rzeczywisty dźwięk';

  @override
  String get downloadsTitle => 'Pobrane';

  @override
  String downloadProgress(String progress) {
    return 'postęp: $progress%';
  }

  @override
  String get songInfoTitle => 'Informacje o utworze';

  @override
  String get lyricsTitle => 'Tekst utworu';

  @override
  String get lyricsEmpty => 'Nie znaleziono tekstu tego utworu';

  @override
  String get lyricsError => 'Nie udało się wczytać tekstu';

  @override
  String get lyricsRetry => 'Ponów';

  @override
  String get eqTitle => 'Korektor';

  @override
  String get eqOnlyAndroid => 'Korektor jest dostępny tylko na Androidzie.';

  @override
  String get eqNeedsPlayback =>
      'Korektor tego telefonu zgłasza swoje pasma dopiero podczas odtwarzania dźwięku. Zapisany preset zostanie zastosowany, gdy tylko się pojawią.';

  @override
  String eqInitFailed(String error) {
    return 'Nie można zainicjować korektora:\n$error';
  }

  @override
  String get eqNoBands =>
      'Sterownik audio tego urządzenia nie zgłasza żadnych pasm korektora.';

  @override
  String get eqPresetFlat => 'Płaski';

  @override
  String get eqPresetNormal => 'Normalny';

  @override
  String get eqPresetClassical => 'Klasyczna';

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
  String get eqPresetCustom => 'Własne';

  @override
  String get eqSaveAsPreset => 'Zapisz jako preset';

  @override
  String get eqSavePresetTitle => 'Zapisz preset';

  @override
  String get eqRenamePresetTitle => 'Zmień nazwę presetu';

  @override
  String get eqPresetNameLabel => 'Nazwa';

  @override
  String get eqSavePresetHint =>
      'Zapisany na tym telefonie, za wbudowanymi presetami. Przytrzymaj później jego chip, aby zmienić nazwę lub go usunąć.';

  @override
  String get eqReplacePreset => 'Zastąp';

  @override
  String get eqPresetNameTaken => 'Inny zapisany preset ma już tę nazwę.';

  @override
  String eqDeletePresetConfirm(String name) {
    return 'Usunąć „$name”?';
  }

  @override
  String get eqHoldToCompare => 'Przytrzymaj, aby porównać';

  @override
  String get eqHoldToCompareHint =>
      'Przytrzymaj, aby usłyszeć dźwięk bez korektora.';

  @override
  String get eqOptionsTitle => 'Opcje korektora';

  @override
  String get eqPreventClipping => 'Zapobiegaj przesterowaniu';

  @override
  String get eqPreventClippingHint =>
      'Ogranicza szczyty, gdy pasma są podbite.';

  @override
  String get eqShowValues => 'Zawsze pokazuj wartości pasm';

  @override
  String get eqShowValuesHint =>
      'Liczba nad każdym pasmem, nie tylko podczas przeciągania.';

  @override
  String get eqOutputsTitle => 'Wyjścia';

  @override
  String get eqOutputsRowOff => 'Wyłączone — jedna krzywa dla wszystkich wyjść';

  @override
  String eqOutputsNow(String name) {
    return 'Teraz: $name';
  }

  @override
  String get eqOutputsSwitch => 'Przełączaj automatycznie';

  @override
  String get eqOutputsSwitchHint =>
      'Gdy zmieni się wyjście, zastosowana zostanie jego krzywa. Przeciąganie na stronie korektora edytuje wyjście, które teraz gra.';

  @override
  String get eqOutputsRemembered => 'Zapamiętane wyjścia';

  @override
  String get eqOutputSpeaker => 'Głośnik telefonu';

  @override
  String get eqOutputWired => 'Słuchawki przewodowe';

  @override
  String get eqOutputUsb => 'Dźwięk USB';

  @override
  String get eqOutputHdmi => 'HDMI';

  @override
  String get eqOutputBluetooth => 'Bluetooth';

  @override
  String get eqOutputOther => 'Inne wyjście';

  @override
  String get eqOutputPlayingNow => 'teraz gra';

  @override
  String eqOutputLastUsed(String date) {
    return 'ostatnio $date';
  }

  @override
  String get eqOutputsEmpty =>
      'Wyjścia pojawiają się tutaj, gdy przez nie słuchasz.';

  @override
  String eqOutputForgetConfirm(String name) {
    return 'Zapomnieć „$name”? Przy następnym połączeniu pojawi się jako nowe wyjście.';
  }

  @override
  String get eqOutputForget => 'Zapomnij';

  @override
  String eqOutputPickPreset(String name) {
    return 'Preset dla $name';
  }

  @override
  String get eqOutputsHint =>
      'Dotknij wyjścia, aby wybrać jego preset. Przesuń je, aby zapomnieć.';

  @override
  String eqEnabledOnOutput(String name) {
    return 'Włączony — $name';
  }

  @override
  String get eqOutputNowPill => 'Teraz';

  @override
  String get eqNeedsPlaybackTitle =>
      'Rozpocznij utwór, aby skonfigurować pasma';

  @override
  String get eqPlayQueue => 'Odtwórz kolejkę';

  @override
  String eqPlayQueueHint(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count utworów',
      many: '$count utworów',
      few: '$count utwory',
      one: '1 utwór',
    );
    return 'Wznawia tam, gdzie skończyłeś · $_temp0';
  }

  @override
  String get eqDisabledHint => 'Włącz korektor, aby dostosować pasma.';

  @override
  String get eqEnabledOn => 'Włączony — wzmocnienia stosowane do odtwarzania';

  @override
  String get eqEnabledOff => 'Wyłączony — tryb obejścia';

  @override
  String get cancel => 'Anuluj';

  @override
  String get continueLabel => 'Kontynuuj';

  @override
  String get openSettings => 'Otwórz ustawienia';

  @override
  String get settingsTitle => 'Ustawienia';

  @override
  String get settingsSectionAppearance => 'Wygląd';

  @override
  String get settingsSectionPlayback => 'Odtwarzanie';

  @override
  String get settingsSectionBrowse => 'Biblioteka';

  @override
  String get settingsTheme => 'Motyw';

  @override
  String get settingsTranscode => 'Transkoduj dźwięk';

  @override
  String get settingsTranscodeSubtitle =>
      'Przesyłaj strumieniowo transkodowaną kopię z serwera (mniejsze pliki, nieco wolniejszy start). Wyłączenie odtwarza oryginalne pliki.';

  @override
  String get transcodeTitle => 'Transkodowanie';

  @override
  String get transcodeCodec => 'Kodek';

  @override
  String get transcodeBitrate => 'Przepływność';

  @override
  String get transcodeAuto => 'Domyślne serwera';

  @override
  String get transcodeUnavailable =>
      'Ten serwer nie ma włączonego transkodowania — jego utwory są przesyłane w oryginalnej jakości.';

  @override
  String get transcodeReloadQueue => 'Zastosuj do bieżącej kolejki';

  @override
  String get transcodeReloadQueueSubtitle =>
      'Gdy zmienisz ustawienia transkodowania — zaznaczone: przeładuj całą kolejkę teraz (odtwarzany utwór na chwilę buforuje się ponownie); odznaczone: zmieniają się tylko kolejne utwory, bieżący kończy się bez zmian.';

  @override
  String get settingsTapBehavior => 'Po dotknięciu utworu';

  @override
  String get settingsStartupPage => 'Ekran startowy';

  @override
  String get tapSubtitleAddToQueue => 'Dodaje go na koniec kolejki';

  @override
  String get tapSubtitlePlayFromHere =>
      'Zastępuje kolejkę i odtwarza od tego utworu';

  @override
  String get tapSubtitleAppendAndJump =>
      'Dodaje go na koniec kolejki i od razu odtwarza';

  @override
  String get settingsVisualizerSource => 'Źródło dźwięku';

  @override
  String get visualizerSourceSubtitleSynthesized => 'Nie wymaga uprawnień';

  @override
  String get visualizerSourceSubtitleReal =>
      'Wymaga uprawnienia do mikrofonu, ale nigdy go nie używa';

  @override
  String get settingsAlbumGrid => 'Siatka albumów';

  @override
  String get settingsFileMetadata => 'Dane utworów w Eksploratorze plików';

  @override
  String get settingsLetterStrip => 'Pasek A–Z';

  @override
  String get settingsLetterStripSide => 'Strona';

  @override
  String get settingsLetterStripLeft => 'Lewa';

  @override
  String get settingsLetterStripRight => 'Prawa';

  @override
  String get settingsReset => 'Resetuj ustawienia';

  @override
  String get settingsResetDone => 'Ustawienia zresetowane';

  @override
  String get realAudioDialogTitle => 'Użyć rzeczywistego dźwięku?';

  @override
  String get realAudioDialogBody =>
      'Aby reagować na odtwarzany utwór, wizualizator odczytuje wyjście audio samego mStream, a Android pozwala na to tylko z uprawnieniem do mikrofonu.';

  @override
  String get realAudioPermPermanentlyDenied =>
      'Uprawnienie trwale odrzucone. Włącz je w ustawieniach systemowych, aby używać rzeczywistego dźwięku.';

  @override
  String get realAudioPermDenied =>
      'Uprawnienie odrzucone. Pozostawiono dźwięk syntetyczny.';

  @override
  String get visualizerTapHint =>
      'Dotknięcie = następny preset · strzałka wstecz (lewy górny róg) lub przytrzymaj, aby wyjść';

  @override
  String get visualizerFailed => 'Nie udało się uruchomić wizualizatora';

  @override
  String get visualizerBringingUp => 'Uruchamianie renderera…';

  @override
  String get visualizerReady => 'Wizualizator gotowy';

  @override
  String get visualizerBridgeFailed => 'Nie udało się uruchomić mostka';

  @override
  String visualizerAudioSourceLine(String source) {
    return 'Źródło dźwięku: $source';
  }

  @override
  String get visualizerTapToClose => 'Dotknij dowolnego miejsca, aby zamknąć';

  @override
  String get visualizerClose => 'Zamknij wizualizator';

  @override
  String get visualizerPreviousPreset => 'Poprzedni preset';

  @override
  String get visualizerNextPreset => 'Następny preset';

  @override
  String get visualizerUnsupported =>
      'Wizualizator jest obecnie obsługiwany tylko na Androidzie.';

  @override
  String get aboutTitle => 'O aplikacji';

  @override
  String aboutBuiltBy(String name) {
    return 'Stworzone przez $name';
  }

  @override
  String get linkDiscordSubtitle => 'Czat społeczności';

  @override
  String get linkGithubSubtitle => 'Kod źródłowy serwera mStream';

  @override
  String get linkHomepageSubtitle => 'Strona projektu';

  @override
  String get aboutAttributions => 'Podziękowania';

  @override
  String get aboutAttributionsSubtitle =>
      'Licencja, podziękowania za shadery i informacje o oprogramowaniu open source.';

  @override
  String get aboutSponsor => 'Wesprzyj mStream';

  @override
  String get ok => 'OK';

  @override
  String get delete => 'Usuń';

  @override
  String get edit => 'Edytuj';

  @override
  String get info => 'Informacje';

  @override
  String get makeDefault => 'Ustaw jako domyślny';

  @override
  String get goBack => 'Wstecz';

  @override
  String get play => 'Odtwórz';

  @override
  String get playAll => 'Odtwórz wszystko';

  @override
  String get rename => 'Zmień nazwę';

  @override
  String get create => 'Utwórz';

  @override
  String get copy => 'Kopiuj';

  @override
  String get done => 'Gotowe';

  @override
  String get copiedToClipboard => 'Skopiowano do schowka';

  @override
  String get attributionsTitle => 'Podziękowania';

  @override
  String get attributionsSectionLicense => 'Licencja';

  @override
  String get attributionsSectionShaders => 'Shadery wizualizatora';

  @override
  String get attributionsSectionLibraries => 'Biblioteki natywne';

  @override
  String get attributionsSectionEverythingElse => 'Wszystko inne';

  @override
  String get attributionsLicenseBody =>
      'Wolne oprogramowanie na licencji GNU General Public License v3.0. Możesz go używać, badać, udostępniać i modyfikować na tych warunkach.';

  @override
  String get attributionsPackages => 'Licencje pakietów open source';

  @override
  String get attributionsPackagesSubtitle =>
      'Pełne teksty licencji wszystkich dołączonych pakietów Flutter/Dart.';

  @override
  String get manageServersTitle => 'Zarządzaj serwerami';

  @override
  String get manageServerInfo => 'Informacje o serwerze';

  @override
  String get manageServerDownloadFolder => 'Folder pobierania:';

  @override
  String get manageServerCopyPath => 'Kopiuj ścieżkę pobierania';

  @override
  String get manageServerPathCopied => 'Skopiowano ścieżkę do schowka';

  @override
  String get confirmRemoveServerTitle => 'Potwierdź usunięcie serwera';

  @override
  String get removeSyncedFiles => 'Usunąć zsynchronizowane pliki z urządzenia?';

  @override
  String get playlistsTitle => 'Playlisty';

  @override
  String get playlistsNew => 'Nowa playlista';

  @override
  String get playlistsEmptyTitle => 'Brak playlist';

  @override
  String get playlistsEmptyBody =>
      'Utwórz playlistę przyciskiem Nowa playlista, a następnie wypełnij ją gestem przesunięcia „Dodaj do playlisty” w kolejce.';

  @override
  String get playlistNameHint => 'Nazwa';

  @override
  String get playlistsRename => 'Zmień nazwę playlisty';

  @override
  String get playlistFallbackTitle => 'Playlista';

  @override
  String get playlistEmptyDetail =>
      'Playlista jest pusta.\nDodaj utwory z kolejki.';

  @override
  String get shareEmptyTitle => 'Pusta kolejka';

  @override
  String get shareEmptyBody => 'Dodaj utwory do kolejki przed udostępnieniem.';

  @override
  String get shareBlockedTitle => 'Nie można udostępnić tej kolejki';

  @override
  String get shareLocalOnlyBody =>
      'Kolejka zawiera utwory, które znajdują się tylko na tym urządzeniu (na żadnym serwerze). Udostępnianie działa tylko wtedy, gdy każdy utwór w kolejce pochodzi z jednego serwera.';

  @override
  String shareMultiServerBody(int count, String names) {
    return 'Kolejka miesza utwory z $count serwerów ($names). Udostępnianie działa tylko wtedy, gdy każdy utwór pochodzi z jednego serwera.';
  }

  @override
  String shareServerGoneBody(String name) {
    return 'Serwera „$name” nie ma już na twojej liście serwerów. Dodaj go ponownie, aby udostępnić jego kolejkę.';
  }

  @override
  String get shareTitle => 'Udostępnij playlistę';

  @override
  String shareSongCount(int count, String url) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count utworów',
      many: '$count utworów',
      few: '$count utwory',
      one: '1 utwór',
    );
    return '$_temp0 z $url';
  }

  @override
  String get shareLinkExpires => 'Link wygasa';

  @override
  String get shareExpireNever => 'Nigdy';

  @override
  String get shareExpire1Day => 'Po 1 dniu';

  @override
  String get shareExpire7Days => 'Po 7 dniach';

  @override
  String get shareExpire30Days => 'Po 30 dniach';

  @override
  String get shareAction => 'Udostępnij';

  @override
  String get shareDoneTitle => 'Playlista udostępniona';

  @override
  String get shareDoneBody => 'Każdy, kto ma ten link, może odtworzyć kolejkę:';

  @override
  String get save => 'Zapisz';

  @override
  String get start => 'Rozpocznij';

  @override
  String get addServerTitle => 'Dodaj serwer';

  @override
  String get editServerTitle => 'Edytuj serwer';

  @override
  String get fieldServerUrl => 'Adres URL serwera';

  @override
  String get fieldPublicAccess => 'Dostęp publiczny';

  @override
  String get publicAccessSubtitle =>
      'Serwer jest publicznie dostępny — nazwa użytkownika ani hasło nie są potrzebne.';

  @override
  String get fieldUsername => 'Nazwa użytkownika';

  @override
  String get fieldPassword => 'Hasło';

  @override
  String get fieldPasswordShow => 'Pokaż hasło';

  @override
  String get fieldPasswordHide => 'Ukryj hasło';

  @override
  String get fieldSdCard => 'Pobieraj na kartę SD';

  @override
  String get sdCardSubtitle =>
      'Zapisuj pobraną muzykę na wyjmowanej karcie SD zamiast w pamięci wewnętrznej.';

  @override
  String get testConnectionButton => 'Testuj połączenie';

  @override
  String get testing => 'Testowanie…';

  @override
  String get connecting => 'Łączenie…';

  @override
  String get validatorUrlNeeded => 'Adres URL serwera jest wymagany';

  @override
  String get validatorUrlParse => 'Nie można przetworzyć adresu URL';

  @override
  String get testEnterUrl => 'Najpierw wprowadź adres URL serwera.';

  @override
  String get testParseUrl => 'Nie można przetworzyć adresu URL.';

  @override
  String get testTimedOut => 'Przekroczono limit czasu połączenia.';

  @override
  String get connectionSuccessful => 'Połączenie udane!';

  @override
  String get couldNotReachServer =>
      'Nie można nawiązać połączenia z serwerem. Jeśli wymaga logowania, wyłącz „Dostęp publiczny” i dodaj dane logowania.';

  @override
  String get failedToLogin => 'Logowanie nie powiodło się';

  @override
  String testConnected(String version) {
    return 'Połączono — mStream v$version';
  }

  @override
  String testConnectFailed(String error) {
    return 'Nie można połączyć: $error';
  }

  @override
  String get sleepTimerTitle => 'Wyłącznik czasowy';

  @override
  String get sleepTimerHint => 'Wybierz czas, po którym wstrzymać odtwarzanie.';

  @override
  String get sleepTimerCustom => 'Niestandardowy';

  @override
  String get sleepTimerCustomHint => 'minuty (1–600)';

  @override
  String get sleepTimerCancel => 'Anuluj wyłącznik';

  @override
  String get sleepTimerInvalid => 'Wprowadź liczbę od 1 do 600 minut';

  @override
  String sleepTimerPausesIn(String time) {
    return 'Wstrzyma za $time';
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
      other: 'Ustawiono wyłącznik czasowy na $minutes minut',
      many: 'Ustawiono wyłącznik czasowy na $minutes minut',
      few: 'Ustawiono wyłącznik czasowy na $minutes minuty',
      one: 'Ustawiono wyłącznik czasowy na 1 minutę',
    );
    return '$_temp0';
  }

  @override
  String get add => 'Dodaj';

  @override
  String get autoDjTitle => 'Auto DJ';

  @override
  String autoDjSongsPerFetchValue(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count utworu',
      many: '$count utworów',
      few: '$count utwory',
      one: '1 utwór',
    );
    return '$_temp0';
  }

  @override
  String autoDjBpmTolerance(int bpm) {
    return '± $bpm BPM';
  }

  @override
  String get autoDjHarmonicTitle => 'Miksowanie harmoniczne';

  @override
  String get autoDjHarmonicHint => 'Następny utwór w pasującej tonacji';

  @override
  String get autoDjDurationRange => 'Długość';

  @override
  String get autoDjMoodTitle => 'Inteligentne filtry';

  @override
  String get autoDjGenreLoadError => 'Nie można wczytać gatunków';

  @override
  String get download => 'Pobierz';

  @override
  String get addAll => 'Dodaj wszystkie';

  @override
  String get browserMoreActions => 'Więcej akcji';

  @override
  String get browserConfirmDeletePlaylist => 'Potwierdź usunięcie playlisty';

  @override
  String get browserConfirmDeleteFolder => 'Potwierdź usunięcie folderu';

  @override
  String get browserSearchHint => 'Szukaj w bazie danych';

  @override
  String get searchCategoriesTooltip => 'Zakres wyszukiwania';

  @override
  String get searchCategoriesHeader => 'Szukaj w';

  @override
  String get searchCategoryArtists => 'Wykonawcy';

  @override
  String get searchCategoryAlbums => 'Albumy';

  @override
  String get searchCategorySongs => 'Utwory';

  @override
  String get searchCategoryFiles => 'Pliki';

  @override
  String get searchCategoryLyrics => 'Teksty';

  @override
  String searchSubheaderResults(String term) {
    return 'Wyniki dla „$term”';
  }

  @override
  String searchSubheaderCategories(String categories) {
    return 'Wyszukiwanie w: $categories';
  }

  @override
  String browserDownloadsStarted(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Rozpoczęto $count pobrań',
      many: 'Rozpoczęto $count pobrań',
      few: 'Rozpoczęto $count pobierania',
      one: 'Rozpoczęto 1 pobieranie',
    );
    return '$_temp0';
  }

  @override
  String browserSongsAdded(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Dodano $count utworów do kolejki',
      many: 'Dodano $count utworów do kolejki',
      few: 'Dodano $count utwory do kolejki',
      one: 'Dodano 1 utwór do kolejki',
    );
    return '$_temp0';
  }

  @override
  String get tabBrowser => 'Przeglądarka';

  @override
  String get tabQueue => 'Kolejka';

  @override
  String get drawerTagline => 'Osobiste strumieniowanie muzyki';

  @override
  String get mainFailedToConnect => 'Nie udało się połączyć z serwerem';

  @override
  String get mainQueueEmpty => 'Kolejka jest pusta';

  @override
  String get queueEmptyDjHint =>
      'Auto DJ jest włączony i potrzebuje pierwszego utworu.';

  @override
  String get queueEmptyDjRandom => 'Losowy utwór';

  @override
  String get queueEmptyDjChoose => 'Wybierz utwór';

  @override
  String get mainClearQueue => 'Wyczyść kolejkę';

  @override
  String get mainSync => 'Synchronizuj';

  @override
  String mainQueueCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count utworów',
      many: '$count utworów',
      few: '$count utwory',
      one: '1 utwór',
    );
    return '$_temp0';
  }

  @override
  String get autoDjEnabled => 'Auto DJ włączony';

  @override
  String get autoDjDisabled => 'Auto DJ wyłączony';

  @override
  String autoDjEnabledFor(String url) {
    return 'Auto DJ włączony dla $url';
  }

  @override
  String get addToPlaylistTitle => 'Dodaj do playlisty';

  @override
  String get addToPlaylistEmpty => 'Brak playlist — dotknij +, aby utworzyć.';

  @override
  String addedToPlaylist(String name) {
    return 'Dodano do $name';
  }

  @override
  String get testConnectedSignedIn => 'Połączono — zalogowano pomyślnie.';

  @override
  String get testSignInFailed =>
      'Nawiązano połączenie z serwerem, ale logowanie nie powiodło się — sprawdź nazwę użytkownika i hasło.';

  @override
  String get browserFileExplorer => 'Eksplorator plików';

  @override
  String get browserLocalFiles => 'Pliki lokalne';

  @override
  String get browserPlaylists => 'Playlisty';

  @override
  String get browserAlbums => 'Albumy';

  @override
  String get browserArtists => 'Wykonawcy';

  @override
  String get browserGenres => 'Gatunki';

  @override
  String get genreSourceTags => 'Tagi';

  @override
  String get genreSourceGenerated => 'Wygenerowane';

  @override
  String get genreSourceBoth => 'Oba';

  @override
  String get genreSourceMixed => 'Mieszane';

  @override
  String get genreSourceLabel => 'Źródło gatunków';

  @override
  String get moodFilters => 'Filtry';

  @override
  String get moodValenceGroup => 'Radosne, neutralne lub smutne';

  @override
  String get moodEnergyGroup => 'Spokojne, neutralne lub agresywne';

  @override
  String get moodVoiceGroup => 'Instrumentalne lub z wokalem';

  @override
  String get moodTagsGroup => 'Tagi';

  @override
  String get moodHappy => 'Radosne';

  @override
  String get moodNeutral => 'Neutralne';

  @override
  String get moodSad => 'Smutne';

  @override
  String get moodRelaxed => 'Spokojne';

  @override
  String get moodAggressive => 'Agresywne';

  @override
  String get moodInstrumental => 'Instrumentalne';

  @override
  String get moodVocals => 'Z wokalem';

  @override
  String get moodAcoustic => 'Akustyczne';

  @override
  String get moodParty => 'Imprezowe';

  @override
  String get moodDanceable => 'Taneczne';

  @override
  String get browserRecent => 'Ostatnie';

  @override
  String get browserRated => 'Ocenione';

  @override
  String get browserSectionLibrary => 'Biblioteka';

  @override
  String get browserSectionListen => 'Słuchaj';

  @override
  String get browserSectionNetwork => 'Sieć';

  @override
  String get browserSectionServer => 'Serwer';

  @override
  String get browserFederation => 'Federacja';

  @override
  String get browserAutoDjOn => 'Włączony';

  @override
  String get browserAutoDjOff => 'Wyłączony';

  @override
  String browserSharedLibraries(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count udostępnionych bibliotek',
      many: '$count udostępnionych bibliotek',
      few: '$count udostępnione biblioteki',
      one: '1 udostępniona biblioteka',
    );
    return '$_temp0';
  }

  @override
  String get browserSearch => 'Szukaj';

  @override
  String get browserWelcomeTitle => 'Witamy w mStream';

  @override
  String get browserWelcomeSubtitle => 'Dotknij tutaj, aby dodać serwer';

  @override
  String get settingsVisualizerKnobs => 'Suwaki strojenia';

  @override
  String get settingsVisualizerKnobsSubtitle => 'Tylko ShaderToy';

  @override
  String get visualizerTuningTitle => 'Strojenie';

  @override
  String get close => 'Zamknij';

  @override
  String get migMoveStopped =>
      'Przenoszenie zatrzymane — za mało miejsca lub lokalizacja jest niedostępna.';

  @override
  String get migMoveComplete => 'Przenoszenie zakończone';

  @override
  String migMoveCompleteSkipped(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other:
          'Przenoszenie zakończone — pominięto $count plików (nieobsługiwane w miejscu docelowym)',
      many:
          'Przenoszenie zakończone — pominięto $count plików (nieobsługiwane w miejscu docelowym)',
      few:
          'Przenoszenie zakończone — pominięto $count pliki (nieobsługiwane w miejscu docelowym)',
      one:
          'Przenoszenie zakończone — pominięto 1 plik (nieobsługiwany w miejscu docelowym)',
    );
    return '$_temp0';
  }

  @override
  String migMoving(String progress) {
    return 'Przenoszenie pobranych plików… $progress — nie zamykaj aplikacji';
  }

  @override
  String get migRetry => 'Ponów';

  @override
  String get queueDownloadAll => 'Pobierz wszystkie';

  @override
  String queueDownloadAllBody(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Zostanie pobranych $count utworów do odtwarzania offline.',
      many: 'Zostanie pobranych $count utworów do odtwarzania offline.',
      few: 'Zostaną pobrane $count utwory do odtwarzania offline.',
      one: 'Zostanie pobrany 1 utwór do odtwarzania offline.',
    );
    return '$_temp0';
  }

  @override
  String get mainMore => 'Więcej';

  @override
  String get commonOn => 'Włączone';

  @override
  String get commonOff => 'Wyłączone';

  @override
  String get settingsCastQualitySubtitle4k =>
      'Wymaga Chromecasta 4K; najbardziej obciąża telefon';

  @override
  String get eqCasting =>
      'Korektor reguluje dźwięk na tym urządzeniu, więc jest niedostępny podczas przesyłania. Rozłącz, aby go użyć.';

  @override
  String get browserNothingToDownload => 'Nie ma czego pobrać z tej listy';

  @override
  String get browserDownloadAllTitle => 'Pobierz wszystkie';

  @override
  String browserDownloadAllConfirm(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Zostanie pobranych $count plików.',
      many: 'Zostanie pobranych $count plików.',
      few: 'Zostaną pobrane $count pliki.',
      one: 'Zostanie pobrany 1 plik.',
    );
    return '$_temp0';
  }

  @override
  String get browserCloseSearch => 'Zamknij wyszukiwanie';

  @override
  String get browserSearchThisList => 'Szukaj na tej liście';

  @override
  String get browserSearchList => 'Szukaj na liście';

  @override
  String browserNoMatches(String query) {
    return 'Brak wyników dla „$query”';
  }

  @override
  String get clear => 'Wyczyść';

  @override
  String get dlLocationUnavailable => 'Lokalizacja pobierania niedostępna';

  @override
  String get dlLocationUnavailableServer =>
      'Lokalizacja pobierania niedostępna dla tego serwera.';

  @override
  String get dlFailed => 'Pobieranie nie powiodło się — sprawdź połączenie.';

  @override
  String get dlFatSkip =>
      'Niektórych utworów nie można zapisać na tej karcie — ich nazwy nie są obsługiwane. Zamiast tego są strumieniowane.';

  @override
  String get dlServerGone => 'Ten serwer nie jest już skonfigurowany.';

  @override
  String get dlStorageUnavailable =>
      'Lokalizacja pamięci niedostępna — podłącz ponownie kartę SD lub zmień lokalizację pamięci tego serwera w Edytuj serwer.';

  @override
  String get dlCouldNotStart =>
      'Nie można rozpocząć pobierania — pamięć niedostępna.';

  @override
  String get storageLocationLabel => 'Lokalizacja pamięci';

  @override
  String get storageAppLocal => 'Wewnątrz aplikacji';

  @override
  String get storagePermanent => 'Trwała';

  @override
  String get storageSdCard => 'Karta SD';

  @override
  String get storageSdSwitchTitle => 'Zapisuj na karcie SD';

  @override
  String get storageSdSwitchSubtitle =>
      'Zapisywane w folderze aplikacji na karcie SD — nie wymaga uprawnień, ale jest usuwane po odinstalowaniu aplikacji.';

  @override
  String get storageHelpAppLocal =>
      'Zapisywane wewnątrz aplikacji. Usuwane po odinstalowaniu lub wyczyszczeniu aplikacji.';

  @override
  String get storageHelpPermanent =>
      'Zapisywane w wybranym folderze. Zachowywane po odinstalowaniu aplikacji. Wymaga uprawnienia „Dostęp do wszystkich plików”.';

  @override
  String get storageHelpSdCard =>
      'Zapisywane w wybranym folderze na karcie SD. Może stać się niedostępne po wyjęciu karty. Niektóre urządzenia nie pozwalają aplikacjom zapisywać na kartach SD — jeśli wybór folderu wciąż się nie udaje, użyj opcji Trwała lub Wewnątrz aplikacji.';

  @override
  String get storageChooseFolder => 'Wybierz folder';

  @override
  String get storageNoFolderChosen => 'Nie wybrano jeszcze folderu';

  @override
  String get storageDownloadFolderLabel => 'Folder pobierania';

  @override
  String get storageDownloadFolderHint => 'nazwa folderu';

  @override
  String get storageBrowse => 'Przeglądaj';

  @override
  String get storageDownloadFolderHelp =>
      'Pliki są pobierane do katalogu „media/<folder>” na tym urządzeniu. Ponowne użycie folderu poprzedniego serwera zachowuje jego pobrane utwory po ponownym dodaniu utraconego serwera.';

  @override
  String get storageNoStorageAvailable => 'Brak dostępnej pamięci';

  @override
  String get storageNoDownloadFolders =>
      'Nie znaleziono istniejących folderów pobierania';

  @override
  String get storageExistingFolders => 'Istniejące foldery pobierania';

  @override
  String storageItemCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count elementów',
      many: '$count elementów',
      few: '$count elementy',
      one: '1 element',
    );
    return '$_temp0';
  }

  @override
  String get storageAllFilesAccess =>
      'Przyznaj uprawnienie „Dostęp do wszystkich plików”, aby trwale przechowywać pobrane pliki, a następnie wybierz tryb ponownie.';

  @override
  String get storageSettings => 'Ustawienia';

  @override
  String get storageNoVolume => 'Nie można zlokalizować woluminu pamięci';

  @override
  String get storageNotWritable =>
      'Ten folder nie pozwala na zapis — wybierz inny.';

  @override
  String get storageNewFolder => 'Nowy folder';

  @override
  String get storageFolderNameHint => 'Nazwa folderu';

  @override
  String get storageCouldNotCreateFolder => 'Nie można utworzyć folderu';

  @override
  String get storageNoSubfolders => 'Brak podfolderów';

  @override
  String get storageUseThisFolder => 'Użyj tego folderu';

  @override
  String get storageMovedToNewFolder =>
      'Przeniesiono pobrane pliki do nowego folderu.';

  @override
  String get storageMoveAlreadyRunning =>
      'Przenoszenie już trwa — poczekaj, aż się zakończy.';

  @override
  String get storageMigrateTitle => 'Inny wolumin pamięci';

  @override
  String storageMigrateBody(int count, String size) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other:
          '$count pobranych plików tego serwera ($size) znajduje się na innym woluminie pamięci niż nowa lokalizacja. Wybierz, co zrobić:',
      many:
          '$count pobranych plików tego serwera ($size) znajduje się na innym woluminie pamięci niż nowa lokalizacja. Wybierz, co zrobić:',
      few:
          '$count pobrane pliki tego serwera ($size) znajdują się na innym woluminie pamięci niż nowa lokalizacja. Wybierz, co zrobić:',
      one:
          '1 pobrany plik tego serwera ($size) znajduje się na innym woluminie pamięci niż nowa lokalizacja. Wybierz, co zrobić:',
    );
    return '$_temp0';
  }

  @override
  String storageMigrateNoSpace(String free) {
    return 'Za mało wolnego miejsca w miejscu docelowym (wolne: $free). Przenoszenie może się nie udać w połowie — najpierw zwolnij miejsce.';
  }

  @override
  String get storageMigrateMove => 'Przenieś je';

  @override
  String get storageMigrateMoveBody =>
      'Kopiuj do nowej lokalizacji w tle, usuwając kolejno każdą starą kopię. Nie zamykaj aplikacji, dopóki się nie zakończy.';

  @override
  String get storageMigrateLeave => 'Pozostaw je';

  @override
  String get storageMigrateLeaveBody =>
      'Przełącz teraz; stare pobrane pliki pozostają na miejscu i pobierają się ponownie w nowej lokalizacji.';

  @override
  String get storageMigrateDelete => 'Usuń stare pobrane pliki';

  @override
  String get storageMigrateDeleteBody =>
      'Przełącz teraz i usuń stare pliki; pobiorą się ponownie w nowej lokalizacji.';

  @override
  String get storageMovingBackground =>
      'Przenoszenie pobranych plików w tle — nie zamykaj aplikacji.';

  @override
  String get storageChooseFolderFirst => 'Najpierw wybierz folder pobierania.';

  @override
  String get storageChooseSdFolderFirst =>
      'Najpierw wybierz folder na karcie SD. Jeśli każdy folder jest odrzucany, twoje urządzenie może nie pozwalać aplikacjom na zapis na karcie — użyj zamiast tego opcji Trwała lub Wewnątrz aplikacji.';

  @override
  String get castPlayOn => 'Odtwórz na';

  @override
  String get castPlayOnTooltip => 'Odtwórz na…';

  @override
  String get castSearching => 'Wyszukiwanie urządzeń do przesyłania…';

  @override
  String get castNotSeeing =>
      'Nie widzisz swojego urządzenia? Upewnij się, że jest w tej samej sieci Wi-Fi.';

  @override
  String get castVisualizer => 'Prześlij wizualizator';

  @override
  String get castVisualizerSubtitle => 'Tylko Chromecast';

  @override
  String get castThisDevice => 'To urządzenie';

  @override
  String get visualizerNoKnobs => 'Ten shader nie ma suwaków.';

  @override
  String get nowPlaying => 'Teraz odtwarzane';

  @override
  String get settingsPlayerLayout => 'Układ ekranu Teraz odtwarzane';

  @override
  String get playerLayoutSmall => 'Mały';

  @override
  String get playerLayoutMedium => 'Średni';

  @override
  String get playerLayoutLarge => 'Duży';

  @override
  String get playerLayoutXl => 'XL';

  @override
  String get queueNothingToDownloadEmpty =>
      'Kolejka jest pusta — nie ma czego pobrać';

  @override
  String get queueNothingToDownloadSaved =>
      'Nie ma czego pobrać — utwory są już zapisane';

  @override
  String get settingsAccentColor => 'Kolor akcentu';

  @override
  String get accentThemeDefault => 'Domyślny motywu';

  @override
  String get accentCustom => 'Niestandardowy';

  @override
  String get lanOnYourNetwork => 'Serwery w twojej sieci lokalnej';

  @override
  String get lanSearching => 'Wyszukiwanie serwerów…';

  @override
  String get lanRefresh => 'Odśwież';

  @override
  String lanServerVersion(String version) {
    return 'mStream v$version';
  }

  @override
  String lanLoginTitle(String name) {
    return 'Zaloguj się do $name';
  }

  @override
  String get lanUnreachable => 'Nie można połączyć się z tym serwerem w sieci.';

  @override
  String get lanNoCode =>
      'Szybkie połączenie jest włączone na tym serwerze, ale nie udostępniono kodu parowania. Zaloguj się jako administrator lub poproś operatora o włączenie udostępniania kodu.';

  @override
  String get settingsResumeQueue => 'Wznów kolejkę po uruchomieniu';

  @override
  String get settingsOfflineQueue => 'Pobieraj kolejkę';

  @override
  String get settingsOfflineQueueSubtitle =>
      'Odtwarzanie trwa dalej po utracie połączenia.';

  @override
  String get settingsOfflineQueueWifiOnly => 'Tylko Wi-Fi';

  @override
  String get settingsAutoDownloadCap => 'Limit pobierania';

  @override
  String get settingsAutoDownloadCapUnlimited => 'Bez limitu';

  @override
  String get settingsAutoDownloadCapField => 'Utwory';

  @override
  String get settingsAutoDownloadCapDialogBody =>
      'Ile utworów ma pozostać pobranych, licząc od odtwarzanego. Starsze spoza tej liczby są usuwane, gdy dochodzą nowe.';

  @override
  String get downloadWaitingWifi => 'Oczekiwanie na Wi-Fi';

  @override
  String get settingsRatingHalf => 'Oceny w połówkach gwiazdek';

  @override
  String get settingsRatingHalfSubtitle => 'Przytrzymaj gwiazdkę';

  @override
  String get ratingTitle => 'Oceń';

  @override
  String get ratingFailed => 'Nie udało się zapisać oceny';

  @override
  String get diagnosticsTitle => 'Diagnostyka';

  @override
  String get diagnosticsEnable => 'Włącz rejestrowanie';

  @override
  String get diagnosticsHint =>
      'Dzienniki pozostają na twoim urządzeniu. Tokeny są ukrywane przed skopiowaniem lub udostępnieniem.';

  @override
  String get diagnosticsVerbose => 'Szczegółowe rejestrowanie';

  @override
  String get diagnosticsVerboseHint =>
      'Rejestruje także bardzo częste zdarzenia, np. zmiany fokusu aplikacji. Potrzebne tylko przy diagnozowaniu problemu z odtwarzaniem.';

  @override
  String get diagnosticsCopy => 'Kopiuj';

  @override
  String get diagnosticsShare => 'Udostępnij';

  @override
  String get diagnosticsClear => 'Wyczyść';

  @override
  String get diagnosticsCopied => 'Skopiowano dzienniki do schowka';

  @override
  String get diagnosticsEmpty => 'Brak dzienników';

  @override
  String get storageAppExternal => 'Aplikacja (zewn.)';

  @override
  String get storageAppSdCard => 'Karta SD aplikacji';

  @override
  String get selfSignedTitle => 'Zezwól na certyfikat samopodpisany';

  @override
  String get selfSignedSubtitle =>
      'Pomija weryfikację TLS dla tego serwera. Włączaj tylko w zaufanej sieci.';

  @override
  String get importedShadersTitle => 'Zaimportowane shadery';

  @override
  String get importedShadersRescan => 'Przeskanuj folder ponownie';

  @override
  String get importedShadersDropHint =>
      'Umieść pliki .glsl w tym folderze, a następnie przeskanuj ponownie:';

  @override
  String get importedShadersCopyPath => 'Kopiuj ścieżkę';

  @override
  String get importedShadersReachableHint =>
      'Dostępny przez USB. Usuwany po odinstalowaniu mStream.';

  @override
  String get importedShadersRemove => 'Usuń';

  @override
  String get importedShadersEmptyTitle => 'Brak shaderów';

  @override
  String get importedShadersEmptyBody =>
      'Skopiuj pliki .glsl w stylu Shadertoy do powyższego folderu, a następnie dotknij Przeskanuj ponownie.';

  @override
  String get importedShadersInvalid =>
      'Może nie działać: brak mainImage ani main';

  @override
  String get importedShadersImportDownloads =>
      'Importuj .glsl z folderu Pobrane';

  @override
  String importedShadersDownloadsImported(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Zaimportowano $count shaderów',
      many: 'Zaimportowano $count shaderów',
      few: 'Zaimportowano $count shadery',
      one: 'Zaimportowano $count shader',
    );
    return '$_temp0';
  }

  @override
  String get importedShadersDownloadsNone =>
      'Brak nowych plików .glsl w folderze Pobrane';

  @override
  String get importedShadersDownloadsNoPermission =>
      'Do odczytu folderu Pobrane potrzebne jest uprawnienie do pamięci';

  @override
  String get addServerTabUrl => 'Adres URL serwera';

  @override
  String get addServerTabQuickConnect => 'Szybkie połączenie';

  @override
  String get irohPairingHeader => 'Połącz za pomocą kodu parowania';

  @override
  String get irohPairingBody =>
      'Włącz „Remote Access” (zdalny dostęp) na serwerze, a następnie wklej jego kod parowania lub zeskanuj kod QR.';

  @override
  String get irohPairingCodeLabel => 'Kod parowania';

  @override
  String get irohPairingCodeHint =>
      'Wklej kod z panelu „Remote Access” serwera';

  @override
  String get irohShowPairingCode => 'Pokaż kod parowania';

  @override
  String get irohQrBody =>
      'Zeskanuj go aplikacją mStream na innym urządzeniu, aby połączyć je z tym serwerem, albo skopiuj kod i wklej go tam.';

  @override
  String get irohQrCaution =>
      'Każdy, kto ma ten kod, może połączyć się z twoim serwerem.';

  @override
  String get irohScanQr => 'Skanuj QR';

  @override
  String get irohPaste => 'Wklej';

  @override
  String get irohTestConnection => 'Testuj połączenie';

  @override
  String get irohTesting => 'Testowanie…';

  @override
  String get irohScannerTitle => 'Skanuj kod QR parowania';

  @override
  String get irohQrAndroidOnly =>
      'Skanowanie QR nie jest dostępne na tym urządzeniu.';

  @override
  String get irohAndroidOnly =>
      'Szybkie połączenie nie jest dostępne na tym urządzeniu.';

  @override
  String get irohCameraPermission =>
      'Do zeskanowania kodu potrzebne jest uprawnienie do aparatu.';

  @override
  String get irohPasteFirst => 'Najpierw wklej lub zeskanuj kod parowania.';

  @override
  String get irohTestFirst => 'Najpierw przetestuj połączenie.';

  @override
  String get irohTestConnected => 'Połączono przez tunel iroh';

  @override
  String irohTestConnectedVersion(String version) {
    return 'Połączono przez tunel iroh — mStream v$version';
  }

  @override
  String get irohPathSuffixDirect => ' · bezpośrednio';

  @override
  String get irohPathSuffixRelay => ' · przez przekaźnik';

  @override
  String get irohTunnelNoAnswer =>
      'The tunnel connected, but the server closed the request without answering. On the server, check the bind address and port mStream listens on (the tunnel reaches it at 127.0.0.1), then try again.';

  @override
  String get irohTunnelTimeout =>
      'Tunel został otwarty, ale serwer nie odpowiedział na czas.';

  @override
  String irohTunnelTestFailed(String error) {
    return 'Test tunelu nie powiódł się: $error';
  }

  @override
  String get irohSignInHeader => 'Zaloguj się';

  @override
  String get irohSigningIn => 'Logowanie…';

  @override
  String get irohSignInSave => 'Zaloguj i zapisz';

  @override
  String get irohSignInTimeout => 'Przekroczono czas logowania.';

  @override
  String irohSignInFailed(String error) {
    return 'Logowanie nie powiodło się: $error';
  }

  @override
  String irohSignInFailedHttp(int status) {
    return 'Logowanie nie powiodło się (HTTP $status). Sprawdź nazwę użytkownika i hasło.';
  }

  @override
  String get irohBannerConnecting => 'Łączenie z serwerem…';

  @override
  String get irohBannerReconnecting => 'Ponowne łączenie z serwerem…';

  @override
  String get irohBannerDisconnected => 'Rozłączono z serwerem.';

  @override
  String get irohBannerRelay =>
      'Połączono przez przekaźnik — wolniejsza ścieżka.';

  @override
  String get irohBannerRepair =>
      'Parowanie serwera się zmieniło — sparuj ponownie, aby się połączyć.';

  @override
  String get irohRepairAction => 'Sparuj ponownie';

  @override
  String get irohRetry => 'Ponów';

  @override
  String get irohRepairTitle => 'Sparuj serwer ponownie';

  @override
  String get irohRepairBody =>
      'Kod parowania tego serwera się zmienił (jego sekret został odnowiony). Wklej lub zeskanuj nowy kod z panelu „Remote Access” serwera.';

  @override
  String get irohRepairFailed =>
      'Nie udało się połączyć tym kodem — sprawdź go i spróbuj ponownie.';

  @override
  String get irohPathDirect => 'Bezpośrednio';

  @override
  String get irohPathRelay => 'Przekaźnik';

  @override
  String get irohCastUnavailable =>
      'Przesyłanie na urządzenia zewnętrzne nie jest dostępne dla serwerów peer-to-peer (iroh) — odtwarzanie pozostaje na tym urządzeniu.';

  @override
  String get irohShareUnavailable =>
      'Udostępnianie nie jest dostępne dla serwerów peer-to-peer (iroh) — nie mają publicznego adresu URL, do którego można linkować.';

  @override
  String get discoverTitle => 'Więcej podobnych';

  @override
  String get discoverPageTitle => 'Odkrywaj';

  @override
  String discoverPageWindowDays(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count dnia',
      many: '$count dni',
      few: '$count dni',
      one: '1 dzień',
    );
    return '$_temp0';
  }

  @override
  String get discoverPageWindowAll => 'Cały czas';

  @override
  String discoverPageWidened(String window) {
    return 'W ostatnich $window nic nie było, więc te pochodzą z wcześniej.';
  }

  @override
  String get discoverPageBasedOn => 'Na podstawie';

  @override
  String get discoverPageBasedOnLast => 'Na podstawie ostatnich';

  @override
  String get discoverPageBasedOnAllTime => 'Okres';

  @override
  String get discoverPageMoreOptions => 'Więcej opcji';

  @override
  String get discoverPageNewSeeds => 'Nowe utwory bazowe';

  @override
  String get discoverPageAlbumsLibrary => 'Albumy z twojej biblioteki';

  @override
  String discoverPageAlbumsPeer(String name) {
    return 'Albumy z serwera „$name”';
  }

  @override
  String get discoverPageAlbumsPeers => 'Albumy z połączonych serwerów';

  @override
  String get discoverPageSongsLibrary => 'Utwory z twojej biblioteki';

  @override
  String discoverPageSongsPeer(String name) {
    return 'Utwory z serwera „$name”';
  }

  @override
  String get discoverPageSongsPeers => 'Utwory z połączonych serwerów';

  @override
  String get discoverPageLibraryNothing =>
      'Nic nowego w twojej bibliotece nie brzmi jak te utwory.';

  @override
  String get discoverPagePeersQuiet => 'Na razie nic z połączonych serwerów.';

  @override
  String get discoverPagePeersFailed =>
      'Nie udało się połączyć z połączonymi serwerami.';

  @override
  String get discoverPageSaveAsPlaylist => 'Zapisz jako playlistę';

  @override
  String get discoverPageBrowseLibrary => 'Przeglądaj bibliotekę';

  @override
  String get discoverPageAgoToday => 'dzisiaj';

  @override
  String get discoverPageAgoYesterday => 'wczoraj';

  @override
  String discoverPageAgoMonths(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count miesiąca temu',
      many: '$count miesięcy temu',
      few: '$count miesiące temu',
      one: '1 miesiąc temu',
    );
    return '$_temp0';
  }

  @override
  String discoverPageAgoYears(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count roku temu',
      many: '$count lat temu',
      few: '$count lata temu',
      one: '1 rok temu',
    );
    return '$_temp0';
  }

  @override
  String get discoverPageRandomTitle =>
      'Przesłuchaj do końca kilka utworów, a ta strona pozna twój gust';

  @override
  String get discoverPageRandomBody =>
      'Odkrywaj opiera się na utworach słuchanych do końca. Pominięte nigdy się nie liczą. Zanim jakieś się pojawią, oto propozycje wokół losowego utworu z twojej biblioteki.';

  @override
  String get discoverPageAnotherPick => 'Inny utwór';

  @override
  String get discoverPageChooseSong => 'Wybierz utwór…';

  @override
  String get discoverPageError =>
      'Nie udało się wczytać Odkrywaj. Sprawdź połączenie i spróbuj ponownie.';

  @override
  String get discoverPageRetry => 'Spróbuj ponownie';

  @override
  String get discoverPagePickedHeader => 'Wybrane na tę wizytę';

  @override
  String get discoverPageRandomHeader => 'Losowy wybór';

  @override
  String get discoverPageDroppedHeader => 'Pominięte';

  @override
  String get discoverPageDroppedNote => 'włącz, aby przywrócić';

  @override
  String discoverPagePlayedTimes(int count) {
    return 'odtworzono $count×';
  }

  @override
  String get discoverPageListenedTo => 'przesłuchany';

  @override
  String get discoverPageNotAnalyzed => 'jeszcze nie przeanalizowany';

  @override
  String get discoverPageAddOwn => 'Dodaj własny';

  @override
  String get discoverPageAddOwnSub => 'utwór, którego chcesz więcej';

  @override
  String get discoverPagePickSong => 'Wybierz utwór…';

  @override
  String get discoverPagePickSongSub => 'przeszukaj bibliotekę lub wylosuj';

  @override
  String discoverPageUseThese(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Użyj tych $count',
      many: 'Użyj tych $count',
      few: 'Użyj tych $count',
      one: 'Użyj 1',
    );
    return '$_temp0';
  }

  @override
  String get discoverMatchedBySound => 'Dopasowane brzmieniem';

  @override
  String get discoverSimilarTracks => 'Podobne utwory';

  @override
  String get discoverSimilarArtists => 'Podobni wykonawcy';

  @override
  String get discoverFromNetwork => 'Z sieci';

  @override
  String get discoverFromPeers => 'Z serwerów partnerskich';

  @override
  String get discoverQueueAll => 'Dodaj wszystko do kolejki';

  @override
  String get discoverNewArtistsOnly => 'Tylko nowi wykonawcy';

  @override
  String get discoverNotAnalyzed =>
      'Ten utwór nie został jeszcze przeanalizowany — podobne utwory pojawią się, gdy skan odkrywania do niego dotrze.';

  @override
  String get discoverScanPendingTitle => 'Nic jeszcze nie przeanalizowano';

  @override
  String get discoverScanPendingBody =>
      'Na tym serwerze odkrywanie jest włączone, ale nie przeanalizowano jeszcze żadnej muzyki. Podobne utwory pojawią się, gdy skan odkrywania zostanie wykonany.';

  @override
  String get discoverCheckAgain => 'Sprawdź ponownie';

  @override
  String get discoverTurnedOff =>
      'Odkrywanie zostało wyłączone na tym serwerze.';

  @override
  String get pathScanPending =>
      'Ten serwer nie przeanalizował jeszcze żadnej muzyki, więc nie ma przez co poprowadzić ścieżki. Zadziała, gdy skan odkrywania zostanie wykonany.';

  @override
  String get discoverNothingFound => 'Nie znaleziono dopasowań.';

  @override
  String get discoverNoSeed => 'Odtwórz utwór, aby odkryć podobną muzykę.';

  @override
  String get discoverLeadCopied => 'Skopiowano — idź i znajdź!';

  @override
  String get discoverOpenMusicBrainz => 'Otwórz w MusicBrainz';

  @override
  String get discoverNetworkWarmingUp =>
      'Brak jeszcze danych z sieci — biblioteki innych serwerów pobierają się w tle, gdy tylko zostaną one wykryte.';

  @override
  String get discoverNetworkNothingNew =>
      'Nic nowego dla tego utworu — sieć nie ma nieznanych dopasowań.';

  @override
  String get discoverPeersUnreachable =>
      'Serwery partnerskie nie odpowiedziały — mogą być teraz offline.';

  @override
  String get discoverPeersNothingNew =>
      'Nic nowego dla tego utworu na twoich serwerach partnerskich.';

  @override
  String get autoDjSonicTitle => 'Podobieństwo brzmienia';

  @override
  String get autoDjSonicSeedLabel => 'Utwór startowy';

  @override
  String get autoDjSonicSeedNone =>
      'Brak utworu startowego — sesję zakotwicza odtwarzany utwór.';

  @override
  String get autoDjSonicSeedBanner =>
      'Wybierz utwór startowy — dotknij dowolnego utworu w bibliotece';

  @override
  String get autoDjSonicSeedSearchHint => 'Szukaj utworu…';

  @override
  String get autoDjSonicSeedRandom => 'Losowy utwór';

  @override
  String get autoDjSonicSeedRemove => 'Usuń utwór startowy';

  @override
  String get autoDjSonicSeedFailed => 'Nie udało się pobrać utworu';

  @override
  String get autoDjSeedNoMatch => 'Żaden utwór nie pasuje do filtrów';

  @override
  String get discoverFindSimilar => 'Znajdź podobne';

  @override
  String get discoverStartSession => 'Rozpocznij sesję dźwiękową';

  @override
  String get discoverStartSessionSubtitle =>
      'Niekończąca się muzyka brzmiąca jak ta — zastępuje kolejkę.';

  @override
  String get discoverStartSessionSubtitleRandom =>
      'Niekończąca się muzyka od losowego utworu startowego — zastępuje kolejkę.';

  @override
  String get discoverSessionStarted =>
      'Sesja dźwiękowa rozpoczęta — Auto DJ włączony.';

  @override
  String get autoDjSonicAnchorRolling => 'Podążaj za klimatem';

  @override
  String get autoDjSonicAnchorLocked => 'Trzymaj się utworu startowego';

  @override
  String get autoDjSonicAnchorRollingHint =>
      'Każdy utwór podąża za ostatnim brzmieniem sesji — może powoli ewoluować.';

  @override
  String get autoDjSonicAnchorLockedHint =>
      'Każdy utwór pozostaje blisko utworu startowego przez całą sesję.';

  @override
  String get trackAddToPlaylist => 'Dodaj do playlisty';

  @override
  String get trackAddToPlaylistFailed => 'Nie udało się dodać do playlisty.';

  @override
  String get discoverPlayPathTo => 'Odtwórz ścieżkę do…';

  @override
  String get pathScreenTitle => 'Ścieżka brzmieniowa';

  @override
  String get pathStartNotAnalyzed =>
      'Utwór początkowy nie został jeszcze przeanalizowany — poczekaj na skan odkrywania lub wybierz inny.';

  @override
  String get pathEndNotAnalyzed =>
      'Utwór docelowy nie został jeszcze przeanalizowany — poczekaj na skan odkrywania lub wybierz inny.';

  @override
  String get pathStartSong => 'Utwór początkowy';

  @override
  String get pathEndSong => 'Utwór docelowy';

  @override
  String get pathLength => 'Długość';

  @override
  String get pathRegenerate => 'Wygeneruj ponownie';

  @override
  String get pathSaveAsPlaylist => 'Zapisz jako playlistę';

  @override
  String get pathSetupHint =>
      'Wybierz utwór początkowy i docelowy — podróż między nimi wypełni się sama.';

  @override
  String get pathNotSet => 'Nie wybrano';

  @override
  String get pathUsePlaying => 'Użyj odtwarzanego utworu';

  @override
  String get pathSearchSong => 'Szukaj';

  @override
  String get pathBrowseLibrary => 'Przeglądaj bibliotekę';

  @override
  String get pathBuild => 'Utwórz podróż';

  @override
  String get pathStartOver => 'Zacznij od nowa';

  @override
  String get pathPickBannerStart =>
      'Wybierz utwór początkowy — dotknij dowolnego utworu w bibliotece';

  @override
  String get pathPickBannerEnd =>
      'Wybierz utwór docelowy — dotknij dowolnego utworu w bibliotece';

  @override
  String get pathNothingPlaying => 'Nic nie jest odtwarzane';

  @override
  String pathPickOnServer(String server) {
    return 'Wybierz utwór na $server';
  }

  @override
  String get welcomeTranslationNote =>
      'Ten język został przetłumaczony maszynowo i może brzmieć nienaturalnie.';

  @override
  String get welcomeTranslationCta => 'Pomóż tłumaczyć mStream';

  @override
  String get setupTitle => 'Szybka konfiguracja';

  @override
  String get setupSkip => 'Pomiń';

  @override
  String get setupNext => 'Dalej';

  @override
  String get setupFinish => 'Zakończ';

  @override
  String get setupBack => 'Wstecz';

  @override
  String get setupAccentTitle => 'Wybierz swój kolor';

  @override
  String get setupAccentBody =>
      'Kolor akcentu wyróżnia przyciski, suwaki i elementy sterowania odtwarzacza. Dotknij jednego, aby go wypróbować.';

  @override
  String get setupPlaybackTitle => 'Gdy dotkniesz utworu';

  @override
  String get setupOfflineTitle => 'Zachowaj kolejkę offline';

  @override
  String get realAudioNoMic => 'mStream nigdy nie używa twojego mikrofonu.';

  @override
  String get playlistEmpty => 'Playlista jest pusta';

  @override
  String get trackRating => 'Ocena';

  @override
  String albumDiscNumber(int n) {
    return 'Płyta $n';
  }

  @override
  String get autoDjStartPickBanner =>
      'Wybierz pierwszy utwór — dotknij dowolnego utworu w bibliotece';

  @override
  String get autoDjStartAskShort => 'Zapytaj';

  @override
  String serverVersionLabel(String version) {
    return 'Serwer v$version';
  }

  @override
  String get serverVersionUnknown => 'Nieznana wersja serwera';

  @override
  String get serverUpdateUrgent => 'Zaktualizuj serwer';

  @override
  String get serverUpdateAvailable => 'Dostępna aktualizacja serwera';

  @override
  String serverTooOldWarning(String version) {
    return 'Ten serwer ma wersję v$version. Niektóre funkcje wymagają v5.5 lub nowszej i będą niedostępne.';
  }

  @override
  String get torrentScreenTitle => 'Dodaj torrent';

  @override
  String get torrentNoServer => 'Nie skonfigurowano serwera.';

  @override
  String get torrentServerLabel => 'Serwer';

  @override
  String get torrentLibraryLabel => 'Biblioteka';

  @override
  String get torrentNoLibraries => 'Brak bibliotek na tym serwerze';

  @override
  String get torrentSourceLabel => 'Źródło';

  @override
  String get torrentChooseFile => 'Wybierz plik .torrent';

  @override
  String get torrentOr => 'lub';

  @override
  String get torrentMagnetLabel => 'Link magnet';

  @override
  String get torrentMagnetInvalid => 'Nieprawidłowy link magnet';

  @override
  String torrentNotATorrent(String name) {
    return '„$name” nie jest plikiem .torrent';
  }

  @override
  String get torrentOpenWith => 'Otwórz w innej aplikacji';

  @override
  String get torrentOpenWithNone =>
      'Żadna aplikacja na tym urządzeniu nie otworzy pliku .torrent';

  @override
  String get torrentOpenWithFailed =>
      'Nie udało się przekazać torrenta innej aplikacji';

  @override
  String get torrentIntentTitle => 'Otrzymano torrent';

  @override
  String get torrentIntentBody =>
      'Dodaj go do biblioteki na serwerze mStream albo przekaż innej aplikacji.';

  @override
  String get torrentIntentAdd => 'Dodaj do mStream';

  @override
  String get torrentIntentDontAsk =>
      'Zawsze dodawaj do mStream, nie pytaj ponownie';

  @override
  String get settingsTorrentAskTitle => 'Pytaj, co zrobić z torrentami';

  @override
  String get settingsTorrentDefaultTitle => 'Domyślna aplikacja dla torrentów';

  @override
  String get settingsTorrentDefaultSub => 'Otwiera ustawienia Androida';

  @override
  String get settingsTorrentDefaultFailed =>
      'Nie udało się otworzyć ustawień Androida';

  @override
  String get torrentAutoDetect => 'Wykryj metadane';

  @override
  String get torrentDetecting => 'Wykrywanie…';

  @override
  String get torrentDetectNoMetadata =>
      'Za mało metadanych — uzupełnij pola ręcznie';

  @override
  String get torrentDetected => 'Wykryto metadane';

  @override
  String get torrentDetectGuess => 'Przybliżone dopasowanie — sprawdź pola';

  @override
  String get torrentMetadataLabel => 'Metadane';

  @override
  String get torrentArtistLabel => 'Wykonawca';

  @override
  String get torrentAlbumLabel => 'Album';

  @override
  String get torrentYearLabel => 'Rok';

  @override
  String get torrentDestinationLabel => 'Miejsce docelowe';

  @override
  String get torrentPathLabel => 'Ścieżka w bibliotece';

  @override
  String torrentPreviewNoLibrary(String path) {
    return '‹brak biblioteki›/$path';
  }

  @override
  String get torrentPreviewContents => '‹zawartość torrenta›';

  @override
  String get torrentRenameRoot => 'Zmień nazwę głównego folderu torrenta';

  @override
  String get torrentRenameRootSub => 'Dopasuj do nazwy folderu docelowego';

  @override
  String get torrentForceFresh => 'Wymuś pobranie od nowa';

  @override
  String get torrentForceFreshSub =>
      'Nie sprawdzaj plików już obecnych na serwerze';

  @override
  String get torrentSubmit => 'Dodaj torrent';

  @override
  String get torrentSubmitting => 'Dodawanie…';

  @override
  String get torrentUnavailable => 'Torrenty są niedostępne na tym serwerze.';

  @override
  String get torrentPickLibrary => 'Wybierz bibliotekę';

  @override
  String get torrentOneSource =>
      'Podaj link magnet albo plik .torrent (jedno z dwojga)';

  @override
  String get torrentPathEmpty => 'Ścieżka docelowa jest pusta';

  @override
  String get torrentSeeded => 'Już na dysku — trwa seedowanie';

  @override
  String get torrentAlreadyInClient => 'Już w kliencie torrent';

  @override
  String get torrentInvalidFile => 'Nieprawidłowy plik torrent';

  @override
  String get torrentSeedCheckFailed =>
      'Nie udało się sprawdzić istniejących plików — pobieranie od nowa';

  @override
  String get torrentPartialTitle => 'Niektóre pliki już istnieją';

  @override
  String get torrentPartialBody =>
      'Wskaż torrentowi istniejącą kopię, aby ją seedować i pobrać tylko brakujące pliki.';

  @override
  String torrentPartialCount(String matched, String total) {
    return '$matched/$total plików tutaj';
  }

  @override
  String torrentPartialMissing(String missing) {
    return ' · $missing do pobrania';
  }

  @override
  String get torrentDownloadFresh => 'Pobierz mimo to od nowa';

  @override
  String get torrentMatchNoFolder =>
      'To dopasowanie nie ma nazwy folderu — użyj „Pobierz mimo to od nowa”';

  @override
  String torrentAdded(String name) {
    return 'Dodano „$name”';
  }

  @override
  String torrentDuplicate(String name) {
    return '„$name” jest już w kliencie';
  }

  @override
  String serverPickerVia(String parent) {
    return 'przez $parent';
  }

  @override
  String get browserFederatedReadOnly => 'Serwer tylko do odczytu';

  @override
  String get browserFederatedReadOnlyNote =>
      'Playlisty i oceny zostają na twoim serwerze';

  @override
  String get federatedShareUnavailable =>
      'Utworów z udostępnionego serwera nie można udostępnić stąd — należą do biblioteki kogoś innego.';

  @override
  String get federatedForget => 'Zapomnij';

  @override
  String get federatedHide => 'Ukryj w wyborze serwerów';

  @override
  String get federatedShow => 'Pokaż w wyborze serwerów';

  @override
  String federatedNoLongerListed(String parent) {
    return 'Już nieudostępniany przez $parent';
  }

  @override
  String get federationTitle => 'Federacja';

  @override
  String get federationStatusOn => 'Włączona · połączono z przekaźnikiem';

  @override
  String get federationStatusConnecting => 'Włączona · łączenie…';

  @override
  String get federationStatusOff => 'Wyłączona';

  @override
  String get federationStatusUnavailable => 'Niedostępna na tej platformie';

  @override
  String get federationSharedWithYou => 'Udostępnione tobie';

  @override
  String get federationRequestsSection => 'Prośby';

  @override
  String get federationYourSharedLibraries => 'Twoje udostępnione biblioteki';

  @override
  String get federationAddPeer => 'Dodaj serwer partnerski';

  @override
  String get federationShareLibrary => 'Udostępnij bibliotekę';

  @override
  String get federationNoPeersYet =>
      'Nikt jeszcze niczego nie udostępnia temu serwerowi.';

  @override
  String get federationNoKeysYet =>
      'Brak biletów — udostępnij bibliotekę, aby utworzyć bilet.';

  @override
  String get federationNoRequests =>
      'Brak próśb — serwery z sieci wykrywania mogą cię tu znaleźć.';

  @override
  String get federationClipboardTicket => 'Bilet w schowku';

  @override
  String federationTicketPreview(String name, String libraries) {
    return '$name · udostępnia $libraries';
  }

  @override
  String federationTicketPreviewNoLibraries(String name) {
    return '$name';
  }

  @override
  String get federationUnnamedServer => 'Serwer bez nazwy';

  @override
  String get federationAddPeerAction => 'Dodaj';

  @override
  String get federationPeerLive => 'online';

  @override
  String get federationPeerConnecting => 'łączenie…';

  @override
  String get federationPeerDirectTunnel => 'tunel bezpośredni';

  @override
  String federationPeerViaParent(String parent) {
    return 'przez $parent';
  }

  @override
  String federationPeerViaTunnel(String parent) {
    return 'przez tunel serwera $parent';
  }

  @override
  String get federationPeerMissing => 'już nieudostępniany';

  @override
  String get federationPeerHidden => 'ukryty w wyborze serwerów';

  @override
  String federationMemberNote(String server) {
    return 'Udostępnianiem zajmuje się administrator. Tworzenie biletów, dodawanie serwerów partnerskich i odpowiadanie na prośby o parowanie wymagają zalogowania jako administrator na $server — tego samego, które otwiera panel administratora.';
  }

  @override
  String get federationRestrictedNote =>
      'Ten serwer przyjmuje wywołania administracyjne tylko z własnej sieci. Połącz się z domu, aby zarządzać udostępnianiem tutaj.';

  @override
  String get federationDisabledNote =>
      'API administracyjne jest wyłączone na tym serwerze.';

  @override
  String get federationUnsupportedNote =>
      'Ten serwer jest za stary, aby zarządzać federacją z aplikacji. Zaktualizuj mStream.';

  @override
  String get federationLoadFailed => 'Nie udało się połączyć z serwerem.';

  @override
  String get federationRetry => 'Ponów';

  @override
  String get federationOffTitle => 'Udostępniaj biblioteki serwerom znajomych';

  @override
  String get federationOffBody =>
      'Sparuj dwa serwery mStream, aby słuchać nawzajem swojej muzyki. Wymienia się biletami — wyślij SMS-em, zeskanuj albo wklej.';

  @override
  String get federationOffPoint1Title =>
      'Tylko do odczytu, szyfrowanie end-to-end';

  @override
  String get federationOffPoint1Body =>
      'Playlisty i oceny nigdy nie opuszczają twojego serwera';

  @override
  String get federationOffPoint2Title => 'Bez przekierowania portów i DNS';

  @override
  String get federationOffPoint2Body =>
      'iroh znajduje drogę — bezpośrednio, gdy może, przez przekaźnik, gdy musi';

  @override
  String get federationOffPoint3Title => 'Bilety, które można unieważnić';

  @override
  String get federationOffPoint3Body =>
      'Każdy działa raz i można go odciąć w dowolnej chwili';

  @override
  String get federationOffAdminOnly =>
      'Włączyć to może tylko administrator serwera.';

  @override
  String federationOffMemberNote(String server) {
    return 'Federacja na $server jest wyłączona. Administrator może ją włączyć.';
  }

  @override
  String get federationTurnOn => 'Włącz federację';

  @override
  String get federationUnavailableNote =>
      'Komponent iroh nie ma kompilacji dla systemu/procesora tego serwera, więc punkt końcowy federacji nie może tu działać.';

  @override
  String get federationTurnedOn => 'Federacja jest włączona';

  @override
  String get federationTurnedOff => 'Federacja jest wyłączona';

  @override
  String get federationToggleFailed =>
      'Nie udało się zmienić ustawienia federacji.';

  @override
  String get federationSettingsTitle => 'Ustawienia federacji';

  @override
  String get federationSwitchSubtitle =>
      'Peer-to-peer, szyfrowanie end-to-end. Bez przekierowania portów, bez DNS.';

  @override
  String get federationStatusSection => 'Stan';

  @override
  String get federationConnectedRelay => 'Połączono z przekaźnikiem';

  @override
  String get federationNotRunning => 'Punkt końcowy nie działa';

  @override
  String get federationEndpointId => 'Identyfikator punktu końcowego';

  @override
  String get federationEndpointCopied =>
      'Skopiowano identyfikator punktu końcowego';

  @override
  String get federationPairingRequestsSection => 'Prośby o parowanie';

  @override
  String get federationRequestsInboxTitle =>
      'Przyjmuj prośby z sieci wykrywania';

  @override
  String get federationRequestsInboxSubtitle =>
      'Domyślnie wyłączone. Gdy wyłączone, nowe prośby są odrzucane na poziomie transportu; odpowiedzi na twoje własne prośby nadal docierają.';

  @override
  String get federationInboxFailed => 'Nie udało się zmienić skrzynki próśb.';

  @override
  String get federationDefaultsSection => 'Domyślne wartości nowych biletów';

  @override
  String get federationDefaultsNote =>
      'Z konfiguracji serwera — każdy bilet może je zmienić';

  @override
  String get federationOffWarning =>
      'Wyłączenie federacji zrywa wszystkie połączenia z serwerami partnerskimi i ukrywa twoje bilety do ponownego włączenia. Serwery partnerskie zachowują swoje bilety.';

  @override
  String federationRequestWantsToPair(String name) {
    return '$name chce się sparować';
  }

  @override
  String federationRequestToName(String name) {
    return 'Prośba do $name';
  }

  @override
  String federationRequestOffers(String libraries) {
    return 'Oferuje $libraries';
  }

  @override
  String get federationRequestOffersNothing => 'Niczego nie oferuje';

  @override
  String federationRequestYouOffered(String libraries) {
    return 'Oferujesz $libraries';
  }

  @override
  String get federationRequestYouOfferedNothing => 'Niczego nie oferujesz';

  @override
  String get federationReqSending => 'wysyłanie…';

  @override
  String get federationReqWaiting => 'oczekiwanie na odpowiedź';

  @override
  String get federationReqSharingBack => 'udostępnianie w zamian…';

  @override
  String get federationReqNeedsAnswer => 'wymaga twojej odpowiedzi';

  @override
  String get federationReqSendingTicket => 'wysyłanie twojego biletu…';

  @override
  String get federationReqWaitingShare => 'oczekiwanie na ich udostępnienie';

  @override
  String get federationReqDeclined => 'odrzucona';

  @override
  String get federationReqYouDeclined => 'odrzucona przez ciebie';

  @override
  String get federationReqInboxClosed => 'ich skrzynka jest zamknięta';

  @override
  String get federationReqFederated => 'sfederowano';

  @override
  String get federationReqWithdrawn => 'wycofana';

  @override
  String get federationReqExpired => 'wygasła';

  @override
  String get federationAccept => 'Akceptuj…';

  @override
  String get federationAcceptAndShare => 'Akceptuj i udostępnij';

  @override
  String get federationDecline => 'Odrzuć';

  @override
  String get federationCancelRequest => 'Wycofaj prośbę';

  @override
  String get federationDismiss => 'Usuń';

  @override
  String get federationRequestTitle => 'Prośba o parowanie';

  @override
  String federationRequestReceived(String ago) {
    return 'Otrzymano $ago przez sieć wykrywania';
  }

  @override
  String federationRequestSent(String ago) {
    return 'Wysłano $ago przez sieć wykrywania';
  }

  @override
  String get federationShareBack => 'Udostępnij w zamian';

  @override
  String get federationShareBackNote =>
      'Nic się nie zmienia, dopóki nie zaakceptujesz. Otrzymają dostęp tylko do odczytu do zaznaczonych bibliotek — co najmniej jednej.';

  @override
  String get federationTheirLimits => 'Ich limity';

  @override
  String get federationChange => 'Zmień';

  @override
  String get federationRequestIgnored =>
      'Prośby z tego serwera są ignorowane przez 7 dni';

  @override
  String get federationRequestAccepted => 'Prośba zaakceptowana';

  @override
  String get federationRequestDeclined => 'Prośba odrzucona';

  @override
  String get federationRequestCancelled => 'Prośba wycofana';

  @override
  String get federationRequestActionFailed =>
      'Nie udało się zaktualizować prośby.';

  @override
  String get federationTicketNameLabel => 'Dla kogo to jest?';

  @override
  String get federationTicketNameHint =>
      'Tylko ty widzisz tę nazwę — oznacza bilet na twojej liście.';

  @override
  String get federationLibrariesTheyCanRead => 'Biblioteki, które mogą czytać';

  @override
  String get federationLimitsSection => 'Limity';

  @override
  String get federationExactNumbers => 'Dokładne wartości';

  @override
  String get federationPresets => 'Gotowe ustawienia';

  @override
  String get federationLimitStreamRate => 'Prędkość strumienia';

  @override
  String get federationLimitPerDay => 'Dziennie';

  @override
  String get federationLimitStreams => 'Jednoczesne strumienie';

  @override
  String get federationLimitExpires => 'Wygasa';

  @override
  String get federationUnlimited => 'Bez limitu';

  @override
  String get federationNever => 'Nigdy';

  @override
  String federationDays(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count dni',
      many: '$count dni',
      few: '$count dni',
      one: '1 dzień',
    );
    return '$_temp0';
  }

  @override
  String get federationOneYear => '1 rok';

  @override
  String federationKbps(int n) {
    return '$n kb/s';
  }

  @override
  String federationMbps(int n) {
    return '$n Mb/s';
  }

  @override
  String federationMbPerDay(int n) {
    return '$n MB dziennie';
  }

  @override
  String federationGbPerDay(int n) {
    return '$n GB dziennie';
  }

  @override
  String federationStreamsCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count strumieni',
      many: '$count strumieni',
      few: '$count strumienie',
      one: '1 strumień',
    );
    return '$_temp0';
  }

  @override
  String get federationNeverExpires => 'nie wygasa';

  @override
  String federationExpiresIn(String when) {
    return 'wygasa $when';
  }

  @override
  String get federationExpired => 'wygasł';

  @override
  String federationInDays(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'za $count dni',
      many: 'za $count dni',
      few: 'za $count dni',
      one: 'za 1 dzień',
    );
    return '$_temp0';
  }

  @override
  String federationInHours(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'za $count godzin',
      many: 'za $count godzin',
      few: 'za $count godziny',
      one: 'za 1 godzinę',
    );
    return '$_temp0';
  }

  @override
  String get federationStreamRateField => 'Prędkość (kb/s, 0 = bez limitu)';

  @override
  String get federationPerDayField => 'Dzienny limit (MB, 0 = bez limitu)';

  @override
  String get federationStreamsField => 'Maks. strumieni (0 = bez limitu)';

  @override
  String get federationExpiresField => 'Ważność w dniach (0 = nigdy)';

  @override
  String get federationCreateTicket => 'Utwórz bilet';

  @override
  String get federationMintFailed => 'Nie udało się utworzyć biletu.';

  @override
  String get federationNoLibraries =>
      'Ten serwer nie ma bibliotek do udostępnienia.';

  @override
  String get federationTicketTitle => 'Twój bilet';

  @override
  String federationTicketFor(String name) {
    return 'Bilet dla $name';
  }

  @override
  String federationTicketReads(String libraries) {
    return 'Czyta $libraries';
  }

  @override
  String get federationTicketQrHint => 'W tym samym pokoju? Daj to zeskanować.';

  @override
  String get federationTicketWarning =>
      'Każdy, kto ma ten bilet, może czytać te biblioteki, dopóki nie zostanie zrealizowany lub unieważniony. Wyślij go prywatnym kanałem — przejmuje go pierwszy serwer, który go użyje.';

  @override
  String get federationCopyTicket => 'Kopiuj bilet';

  @override
  String get federationTicketCopied => 'Skopiowano bilet';

  @override
  String get federationSendByText => 'Wyślij wiadomością…';

  @override
  String get federationTicketRevokeNote =>
      'Unieważnij w dowolnej chwili w sekcji Federacja. Jeśli znajomy przeinstalował serwer, „Zresetuj realizację” pozwoli zrealizować bilet ponownie.';

  @override
  String get federationTicketNotRunning =>
      'Punkt końcowy federacji nie działa, więc nie ma jeszcze biletu do wysłania. Włącz federację i wróć.';

  @override
  String federationShareMessage(String libraries, String ticket) {
    return 'Udostępniam ci moją bibliotekę muzyczną mStream — $libraries, tylko do odczytu. W aplikacji mStream otwórz Federacja → Dodaj serwer partnerski i wklej ten bilet:\n\n$ticket\n\nDziała raz — mogę go unieważnić w każdej chwili.';
  }

  @override
  String get federationShareSubject => 'Bilet federacji mStream';

  @override
  String get federationKeyClaimed => 'zrealizowany';

  @override
  String get federationKeyNotClaimed => 'jeszcze niezrealizowany';

  @override
  String federationKeyTodayUsage(String amount) {
    return '$amount dzisiaj';
  }

  @override
  String federationKeyLastUsed(String ago) {
    return 'Ostatnio użyty $ago';
  }

  @override
  String get federationKeyNeverUsed => 'Nigdy nieużywany';

  @override
  String federationKeyClaimedAgo(String ago) {
    return 'Zrealizowany $ago';
  }

  @override
  String get federationResetBinding => 'Zresetuj realizację';

  @override
  String get federationResetBindingNote =>
      'Znajomy przeinstalował serwer? Pozwól zrealizować bilet ponownie.';

  @override
  String get federationBindingReset => 'Bilet można zrealizować ponownie';

  @override
  String get federationRevoke => 'Unieważnij';

  @override
  String federationRevokeConfirm(String name) {
    return 'Unieważnić ten bilet? $name od razu straci dostęp.';
  }

  @override
  String get federationRevoked => 'Bilet unieważniony';

  @override
  String get federationSaveLimits => 'Zapisz limity';

  @override
  String get federationLimitsSaved => 'Zapisano limity';

  @override
  String get federationLimitsFailed => 'Nie udało się zapisać limitów.';

  @override
  String get federationSend => 'Wyślij';

  @override
  String get federationKeyTitle => 'Udostępniona biblioteka';

  @override
  String federationActionFailed(String error) {
    return 'Nie udało się: $error';
  }

  @override
  String get federationTheirTicket => 'Ich bilet';

  @override
  String get federationScanQr => 'Zeskanuj kod QR';

  @override
  String get federationScannerTitle => 'Zeskanuj bilet federacji';

  @override
  String get federationPaste => 'Wklej';

  @override
  String get federationTicketPasted => 'Wklejono ze schowka.';

  @override
  String get federationNotATicket => 'To nie wygląda na bilet federacji.';

  @override
  String get federationTicketTooNew =>
      'Ten bilet pochodzi z nowszego mStream, niż rozumie ta aplikacja.';

  @override
  String get federationTicketExpiredNote => 'Ten bilet wygasł.';

  @override
  String get federationDisplayName => 'Wyświetlana nazwa';

  @override
  String get federationDisplayNameHint =>
      'Opcjonalnie — tak pojawi się w wyborze serwerów.';

  @override
  String federationSharesLibraries(String libraries) {
    return 'Udostępnia $libraries';
  }

  @override
  String get federationSharesUnknown => 'Bilet nie wymienia bibliotek';

  @override
  String federationValidUntil(String date) {
    return 'ważny do $date';
  }

  @override
  String federationAddPeerShowsUnder(String server) {
    return 'Pojawi się pod $server';
  }

  @override
  String federationAddPeerReadOnly(String branch, String name) {
    return 'Tylko do odczytu · $branch $name w wyborze serwerów';
  }

  @override
  String get federationAddPeerDials => 'Twój serwer łączy się z nim przez iroh';

  @override
  String get federationAddPeerEncrypted =>
      'Szyfrowanie end-to-end · bez przekierowania portów';

  @override
  String get federationAddPeerNoTicket =>
      'Nie masz jeszcze biletu? Poproś o przesłanie go wiadomością.';

  @override
  String federationPeerAdded(String name) {
    return 'Dodano $name';
  }

  @override
  String get federationAddPeerFailed =>
      'Nie udało się dodać serwera partnerskiego.';

  @override
  String get federationPeerAlreadyAdded =>
      'Ten bilet jest już dodany jako serwer partnerski.';

  @override
  String get federationLibrariesYouCanRead => 'Biblioteki, które możesz czytać';

  @override
  String get federationDiscoverySection => 'Odkrywanie';

  @override
  String get federationAskPeerSimilar => 'Pytaj ten serwer o podobną muzykę';

  @override
  String get federationAskPeerSimilarNote =>
      'Wysyła to, czego słuchasz — tylko do tego serwera.';

  @override
  String get federationAutoDjSection => 'Auto DJ';

  @override
  String get federationAutoDjParticipates =>
      'Bierze udział w wieloserwerowym Auto DJ';

  @override
  String get federationAutoDjParticipatesNote =>
      'Odpowiada własną biblioteką, gdy DJ jest włączony';

  @override
  String get federationAutoDjNotCandidate => 'Nie jest kandydatem do Auto DJ';

  @override
  String get federationAutoDjNotCandidateNote =>
      'Potrzebny serwer, który obsługuje dobór po brzmieniu';

  @override
  String get federationTest => 'Testuj';

  @override
  String get federationTesting => 'Testowanie…';

  @override
  String get federationTestOk => 'Osiągalny';

  @override
  String federationTestFailed(String error) {
    return 'Nie udało się połączyć: $error';
  }

  @override
  String federationCheckedAgo(String ago) {
    return 'Sprawdzono $ago';
  }

  @override
  String get federationNeverTested => 'Nigdy nietestowany';

  @override
  String federationLastSeen(String ago) {
    return 'Ostatnio widziany $ago';
  }

  @override
  String get federationBrowseLibrary => 'Przeglądaj tę bibliotekę';

  @override
  String get federationRemovePeer => 'Usuń serwer partnerski';

  @override
  String federationRemovePeerConfirm(String name) {
    return 'Usunąć $name? Utwory z niego w kolejce przestaną grać.';
  }

  @override
  String federationPeerRemoved(String name) {
    return 'Usunięto $name';
  }

  @override
  String get federationShowInPicker => 'Pokazuj w wyborze serwerów';

  @override
  String get federationShowInPickerNote =>
      'Ukryte serwery nadal odtwarzają to, co z nich dodano do kolejki.';

  @override
  String get federationPeerReadOnlyNote =>
      'Tylko do odczytu — playlisty i oceny zostają na twoim serwerze.';

  @override
  String get federationPeerLibrariesUnknown =>
      'Jeszcze niewczytane — otwórz go raz, aby pobrać jego biblioteki.';

  @override
  String get federationTransportDirect => 'Tunel bezpośredni z tego telefonu';

  @override
  String get federationTransportRelay => 'Przekaźnik w gotowości';

  @override
  String federationTransportViaParent(String parent) {
    return 'Przez $parent';
  }

  @override
  String federationTransportViaParentTunnel(String parent) {
    return 'Przez $parent jego tunelem';
  }

  @override
  String get federationDiscoveryFailed =>
      'Nie udało się zmienić ustawienia odkrywania.';

  @override
  String get agoJustNow => 'przed chwilą';

  @override
  String agoMinutes(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count min temu',
      many: '$count min temu',
      few: '$count min temu',
      one: '1 min temu',
    );
    return '$_temp0';
  }

  @override
  String agoHours(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count godz. temu',
      many: '$count godz. temu',
      few: '$count godz. temu',
      one: '1 godz. temu',
    );
    return '$_temp0';
  }

  @override
  String agoDays(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count dni temu',
      many: '$count dni temu',
      few: '$count dni temu',
      one: '1 dzień temu',
    );
    return '$_temp0';
  }

  @override
  String get browserP2pNetwork => 'Sieć P2P';

  @override
  String get browserP2pOn => 'Włączona';

  @override
  String get browserP2pOff => 'Wyłączona';

  @override
  String get p2pTitle => 'Sieć P2P';

  @override
  String get p2pStatusConnected => 'Połączono';

  @override
  String p2pNeighborsCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count sąsiadów',
      many: '$count sąsiadów',
      few: '$count sąsiedzi',
      one: '1 sąsiad',
    );
    return '$_temp0';
  }

  @override
  String p2pAnnouncingAs(String name) {
    return 'ogłaszany jako $name';
  }

  @override
  String get p2pStatusSearching => 'Dołączono · oczekiwanie na sąsiadów';

  @override
  String p2pStatusReconnecting(int n) {
    return 'Ponowne łączenie · próba $n';
  }

  @override
  String get p2pStatusNotJoined => 'Jeszcze nie dołączono';

  @override
  String get p2pStatusOff => 'Wyłączona';

  @override
  String get p2pStatusUnavailable => 'Niedostępna na tej platformie';

  @override
  String get p2pStatNeighbors => 'sąsiedzi w sieci';

  @override
  String get p2pStatNeighborsSub => 'aktywne łącza gossip';

  @override
  String get p2pStatKnown => 'znane serwery';

  @override
  String p2pStatKnownSub(int hidden, int blocked) {
    return '$hidden ukrytych · $blocked zablokowanych';
  }

  @override
  String get p2pStatHeld => 'przechowywane migawki';

  @override
  String p2pStatHeldOf(int held, int max) {
    return '$held z $max';
  }

  @override
  String p2pStatStorage(String used, String cap) {
    return '$used z $cap';
  }

  @override
  String get p2pStatTracks => 'utwory u innych';

  @override
  String p2pStatTracksSub(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'przeszukiwalne, $count bibliotek',
      many: 'przeszukiwalne, $count bibliotek',
      few: 'przeszukiwalne, $count biblioteki',
      one: 'przeszukiwalne, 1 biblioteka',
    );
    return '$_temp0';
  }

  @override
  String get p2pActivity => 'Aktywność';

  @override
  String get p2pActivitySubtitle => 'najnowsze na górze · tylko w pamięci';

  @override
  String get p2pActivityEmpty =>
      'Jeszcze nic — dołączenia do sieci, pobrania migawek, rotacja i odzyskiwanie pojawiają się tutaj na bieżąco.';

  @override
  String get p2pActivityNote => 'Pełna historia jest w dziennikach serwera.';

  @override
  String get p2pFromNetwork => 'Z sieci';

  @override
  String get p2pFindSimilar => 'Znajdź podobną muzykę w sieci';

  @override
  String p2pFindSimilarSub(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other:
          'Otwiera ekran Więcej podobnych dla granego utworu · podpowiedzi z $count pobranych bibliotek',
      many:
          'Otwiera ekran Więcej podobnych dla granego utworu · podpowiedzi z $count pobranych bibliotek',
      few:
          'Otwiera ekran Więcej podobnych dla granego utworu · podpowiedzi z $count pobranych bibliotek',
      one:
          'Otwiera ekran Więcej podobnych dla granego utworu · podpowiedzi z 1 pobranej biblioteki',
    );
    return '$_temp0';
  }

  @override
  String get p2pFindSimilarNothingPlaying =>
      'Najpierw coś odtwórz — ekran Więcej podobnych podąża za bieżącym utworem';

  @override
  String get p2pNewArtistsOnlySub =>
      'Ukryj podpowiedzi wykonawców, którzy już są w tej bibliotece';

  @override
  String get p2pServersYouFollow => 'Obserwowane serwery';

  @override
  String get p2pServersOnNetwork => 'Serwery w sieci';

  @override
  String get p2pNoServersYet =>
      'Nie usłyszano jeszcze żadnego serwera — dodaj jeden biletem znajomego albo daj sieci minutę.';

  @override
  String p2pHiddenIncompatible(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count serwerów ukrytych — niezgodny model',
      many: '$count serwerów ukrytych — niezgodny model',
      few: '$count serwery ukryte — niezgodny model',
      one: '1 serwer ukryty — niezgodny model',
    );
    return '$_temp0';
  }

  @override
  String get p2pShow => 'Pokaż';

  @override
  String get p2pHide => 'Ukryj';

  @override
  String get p2pBefriend => 'Dodaj zaprzyjaźniony serwer';

  @override
  String get p2pOnline => 'online';

  @override
  String p2pOfflineFor(String ago) {
    return 'offline $ago';
  }

  @override
  String p2pTracksCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count utworów',
      many: '$count utworów',
      few: '$count utwory',
      one: '1 utwór',
    );
    return '$_temp0';
  }

  @override
  String p2pSeedersCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count seederów',
      many: '$count seederów',
      few: '$count seederzy',
      one: '1 seeder',
    );
    return '$_temp0';
  }

  @override
  String get p2pChipDownloaded => 'pobrano';

  @override
  String get p2pChipUpdate => 'dostępna aktualizacja';

  @override
  String get p2pChipNotDownloaded => 'nie pobrano';

  @override
  String get p2pChipPinned => 'przypięto';

  @override
  String get p2pChipIncompatible => 'niezgodny model';

  @override
  String get p2pChipFederated => 'sfederowano';

  @override
  String get p2pChipTheyAsked => 'poprosili ciebie';

  @override
  String get p2pChipRequestSent => 'prośba wysłana';

  @override
  String get p2pSearchingTitle => 'Szukanie serwerów';

  @override
  String get p2pSearchingBody =>
      'Sieć składa się w około minutę. Ten ekran odświeża się sam.';

  @override
  String get p2pReconnectingTitle => 'Ponowne łączenie';

  @override
  String p2pReconnectingBody(int n) {
    return 'Sidecar padł i jest uruchamiany ponownie (próba $n) — nic nie trzeba robić.';
  }

  @override
  String get p2pJoinTitle => 'Rekomendacje z bibliotek innych osób';

  @override
  String get p2pWhatShared => 'Co jest udostępniane';

  @override
  String get p2pShared1 => 'Migawka z samych metadanych';

  @override
  String get p2pShared1Sub =>
      'Wykonawca, tytuł, długość, odciski dźwięku — nigdy pliki audio';

  @override
  String get p2pShared2 => 'Nazwa i opis twojego serwera';

  @override
  String get p2pShared2Sub =>
      'Widoczne dla wszystkich w sieci, domyślnie w publicznej sieci społeczności';

  @override
  String get p2pHowYouAppear => 'Jak cię widać';

  @override
  String get p2pServerName => 'Nazwa serwera';

  @override
  String get p2pServerNameHint =>
      '„mStream” obok 18 000 innych „mStream” to pierwsza rzecz do zmiany.';

  @override
  String get p2pDescription => 'Opis';

  @override
  String get p2pDescriptionHint => '180 znaków, opcjonalnie.';

  @override
  String get p2pAlsoAcceptRequests => 'Przyjmuj też prośby o federację';

  @override
  String get p2pAlsoAcceptRequestsSub =>
      'Zaproszenia do udostępniania bibliotek — nic nie jest udostępniane, dopóki nie zatwierdzisz każdego. Włącza federację.';

  @override
  String get p2pJoin => 'Dołącz do sieci';

  @override
  String get p2pJoining => 'Dołączanie…';

  @override
  String get p2pJoined => 'Dołączono do sieci wykrywania — daj sieci minutę.';

  @override
  String p2pJoinFailed(String error) {
    return 'Nie udało się dołączyć do sieci: $error';
  }

  @override
  String p2pInboxFailed(String error) {
    return 'Wykrywanie działa, ale skrzynka próśb nie wystartowała: $error';
  }

  @override
  String get p2pUnavailableNote =>
      'Nie znaleziono pliku p2p-sidecar dla tej platformy i nie ma wersji do pobrania — sieć jest niedostępna.';

  @override
  String get p2pWillDownloadNote =>
      'Sidecar nie jest jeszcze zainstalowany; dołączenie najpierw go pobierze.';

  @override
  String get p2pAdminOnlyNote => 'Dołączyć może tylko administrator serwera.';

  @override
  String p2pMemberOffNote(String server) {
    return 'Sieć wykrywania na $server jest wyłączona. Administrator może do niej dołączyć.';
  }

  @override
  String p2pMemberNote(String server) {
    return 'Dołączanie, zapraszanie i migawki to zadania administratora. Zaloguj się na $server jako administrator, aby zarządzać siecią tutaj.';
  }

  @override
  String get p2pSnapshotSection => 'Migawka';

  @override
  String p2pDownloadedSize(String size) {
    return 'Pobrano · $size';
  }

  @override
  String p2pSnapshotSeq(int seq) {
    return 'Migawka $seq';
  }

  @override
  String p2pNewerAnnounced(int seq) {
    return 'ogłoszono nowszą ($seq)';
  }

  @override
  String get p2pNotDownloaded => 'Nie pobrano';

  @override
  String get p2pNotDownloadedSub =>
      'Pobierz, aby przeszukiwać ją z ekranu Odkrywaj';

  @override
  String get p2pDownload => 'Pobierz';

  @override
  String get p2pUpdate => 'Aktualizuj';

  @override
  String get p2pDownloading => 'Pobieranie…';

  @override
  String get p2pDownloaded => 'Migawka pobrana';

  @override
  String p2pDownloadFailed(String error) {
    return 'Nie udało się pobrać migawki: $error';
  }

  @override
  String get p2pPin => 'Przypnij tę migawkę';

  @override
  String p2pPinSub(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other:
          'Rotacja zwalnia najrzadziej używane migawki po $count dniach; przypięta zostaje.',
      many:
          'Rotacja zwalnia najrzadziej używane migawki po $count dniach; przypięta zostaje.',
      few:
          'Rotacja zwalnia najrzadziej używane migawki po $count dniach; przypięta zostaje.',
      one:
          'Rotacja zwalnia najrzadziej używane migawki po 1 dniu; przypięta zostaje.',
    );
    return '$_temp0';
  }

  @override
  String get p2pPinSubNoRotation =>
      'Rotacja jest wyłączona; przypięta migawka przetrwa też brak miejsca.';

  @override
  String get p2pRemoveSnapshot => 'Usuń migawkę';

  @override
  String get p2pSnapshotRemoved => 'Migawka usunięta';

  @override
  String get p2pHeldSince => 'przechowywana od';

  @override
  String get p2pTracksLabel => 'utwory';

  @override
  String get p2pSeedersLabel => 'seederzy';

  @override
  String get p2pSeedersSub => 'udostępniają migawkę';

  @override
  String get p2pFederatedWithYou => 'Sfederowany z tobą';

  @override
  String get p2pFederatedWithYouSub =>
      'Otwórz Federację, aby zobaczyć, co czytacie u siebie nawzajem';

  @override
  String get p2pTheyAskedYou => 'Poprosili o federację';

  @override
  String get p2pTheyAskedYouSub => 'Rozpatrz prośbę w Federacji';

  @override
  String get p2pRequestSentTitle => 'Prośba wysłana';

  @override
  String get p2pRequestSentSub => 'Czekamy na odpowiedź · śledź w Federacji';

  @override
  String get p2pAskToFederate => 'Poproś o udostępnienie bibliotek';

  @override
  String get p2pAskToFederateSub =>
      'Wysyła prośbę przez sieć — na razie nic się nie zmienia';

  @override
  String get p2pOpen => 'Otwórz';

  @override
  String get p2pReview => 'Rozpatrz';

  @override
  String get p2pForget => 'Zapomnij ten serwer';

  @override
  String get p2pForgetSub =>
      'Offline i nic nie pobrano; wróci, gdy znów zostanie usłyszany';

  @override
  String p2pForgotten(String name) {
    return 'Zapomniano $name';
  }

  @override
  String get p2pBlockServer => 'Zablokuj serwer';

  @override
  String p2pBlockConfirm(String name) {
    return 'Zablokować $name? Jego ogłoszenia będą ignorowane, a migawka usunięta.';
  }

  @override
  String p2pBlocked(String name) {
    return 'Zablokowano $name';
  }

  @override
  String get p2pUnblock => 'Odblokuj';

  @override
  String get p2pUnblocked => 'Serwer odblokowany';

  @override
  String get p2pIncompatibleNote =>
      'Niezgodny model osadzeń — jego biblioteka nie zasili wyszukiwania podobnych na tym serwerze.';

  @override
  String get p2pCompatible => 'zgodny model';

  @override
  String get p2pModelUnknown => 'model nieznany';

  @override
  String get p2pNoDescription => 'Brak opisu.';

  @override
  String get p2pUnnamedServer => 'Serwer bez nazwy';

  @override
  String get p2pFederateTitle => 'Poproś o federację';

  @override
  String get p2pFederateNote =>
      'Wysyła prośbę przez sieć wykrywania. Teraz nie jest wymieniany żaden dostęp — zobaczą twoją nazwę, wiadomość i ofertę; biblioteki są udostępniane tylko, jeśli zaakceptują.';

  @override
  String get p2pMessage => 'Wiadomość';

  @override
  String p2pMessageHint(int n) {
    return 'Opcjonalnie · $n / 500';
  }

  @override
  String get p2pShareBackLibraries =>
      'Biblioteki, które udostępnisz w zamian, jeśli zaakceptują';

  @override
  String get p2pShareBackNote =>
      'Odznacz wszystko dla prośby jednostronnej — czytasz wtedy tylko ich biblioteki.';

  @override
  String get p2pSendRequest => 'Wyślij prośbę';

  @override
  String get p2pRequestSent => 'Prośba wysłana — śledź w Federacji';

  @override
  String p2pRequestFailed(String error) {
    return 'Nie udało się wysłać prośby: $error';
  }

  @override
  String get p2pTheirTicket => 'Ich bilet';

  @override
  String get p2pTheirTicketHint =>
      'Znajomy znajdzie swój w sekcji „Zaproś znajomego” na ekranie Sieć P2P.';

  @override
  String get p2pTicketPasted => 'Wklejono ze schowka.';

  @override
  String get p2pRememberFriend => 'Zapamiętaj tego znajomego';

  @override
  String get p2pRememberFriendSub =>
      'Zapisane w konfiguracji serwera, więc znajomość przetrwa restarty.';

  @override
  String get p2pJoinFriend => 'Dołącz';

  @override
  String get p2pJoinedFriend => 'Dołączono — sieć składa się w minutę';

  @override
  String p2pJoinFriendFailed(String error) {
    return 'Nie udało się dołączyć: $error';
  }

  @override
  String get p2pNotATicket => 'To nie wygląda na bilet punktu końcowego.';

  @override
  String get p2pScanQr => 'Zeskanuj kod QR';

  @override
  String get p2pScannerTitle => 'Zeskanuj bilet sieci';

  @override
  String get p2pInviteFriend => 'Zaproś znajomego';

  @override
  String p2pYourTicketNote(String name) {
    return 'Twój bilet — znajomy wkleja go tutaj na swoim telefonie, aby dodać $name. To adres, nie dane logowania.';
  }

  @override
  String get p2pTicketCopied => 'Skopiowano bilet';

  @override
  String p2pShareMessage(String ticket) {
    return 'Dodaj mój serwer mStream w sieci wykrywania — w aplikacji mStream otwórz Sieć P2P → Dodaj zaprzyjaźniony serwer i wklej ten bilet:\n\n$ticket';
  }

  @override
  String get p2pShareSubject => 'Bilet sieci wykrywania mStream';

  @override
  String get p2pTicketNotReady =>
      'Sidecar jeszcze nie działa, więc nie ma biletu do udostępnienia.';

  @override
  String get p2pSettingsTitle => 'Ustawienia sieci';

  @override
  String get p2pSwitchTitle => 'Sieć wykrywania';

  @override
  String get p2pSwitchSub =>
      'Ogłasza w sieci migawkę z samych metadanych. Wyłącz, aby opuścić sieć — zebrane dane zostają lokalnie.';

  @override
  String get p2pLeaveConfirm =>
      'Opuścić sieć wykrywania? Serwer przestanie ogłaszać i pobierać migawki. Lokalne odkrywanie działa dalej.';

  @override
  String get p2pLeave => 'Opuść';

  @override
  String get p2pLeft => 'Opuszczono sieć wykrywania';

  @override
  String p2pLeaveFailed(String error) {
    return 'Nie udało się opuścić sieci: $error';
  }

  @override
  String get p2pEditIdentity => 'Nazwa i opis';

  @override
  String get p2pIdentitySaved => 'Zapisano — ogłoszono w sieci';

  @override
  String p2pSaveFailed(String error) {
    return 'Nie udało się zapisać: $error';
  }

  @override
  String get p2pSnapshotsSection => 'Migawki';

  @override
  String get p2pAutoDownload => 'Automatyczne pobieranie do';

  @override
  String p2pServersCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count serwerów',
      many: '$count serwerów',
      few: '$count serwerów',
      one: '1 serwera',
    );
    return '$_temp0';
  }

  @override
  String get p2pStorageCap => 'Limit miejsca';

  @override
  String get p2pRotate => 'Rotacja pobrań';

  @override
  String get p2pForgetOffline => 'Zapominaj serwery offline';

  @override
  String get p2pMeshSection => 'Sieć';

  @override
  String get p2pCommunitySeeds => 'Serwery startowe społeczności';

  @override
  String get p2pCommunitySeedsOn => 'Rozruch przez publiczne serwery startowe';

  @override
  String get p2pCommunitySeedsOff =>
      'Wyłączone — tylko zaprzyjaźnione serwery; ustawiane w konfiguracji serwera';

  @override
  String p2pBlockedServers(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count zablokowanych serwerów',
      many: '$count zablokowanych serwerów',
      few: '$count zablokowane serwery',
      one: '1 zablokowany serwer',
      zero: 'Brak zablokowanych serwerów',
    );
    return '$_temp0';
  }

  @override
  String get p2pBlockedSub =>
      'Ogłoszenia ignorowane, migawki nigdy nie pobierane';

  @override
  String get p2pBlockedTitle => 'Zablokowane serwery';

  @override
  String get p2pSaved => 'Zapisano';

  @override
  String get p2pOff => 'Wył.';

  @override
  String get p2pSave => 'Zapisz';

  @override
  String get p2pSearchServers => 'Szukaj serwerów — nazwa lub opis';

  @override
  String federationInboxBanner(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count próśb o federację czeka',
      many: '$count próśb o federację czeka',
      few: '$count prośby o federację czekają',
      one: '1 prośba o federację czeka',
    );
    return '$_temp0';
  }

  @override
  String get federationInboxBannerSub =>
      'Dotknij, aby zaakceptować lub odrzucić';

  @override
  String federationInboxNotificationTitle(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Czeka $count próśb o federację',
      many: 'Czeka $count próśb o federację',
      few: 'Czekają $count prośby o federację',
      one: 'Czeka prośba o federację',
    );
    return '$_temp0';
  }

  @override
  String federationInboxNotificationBody(String server) {
    return 'Na $server. Otwórz, aby zaakceptować lub odrzucić.';
  }

  @override
  String get federationInboxChannelName => 'Prośby o federację';

  @override
  String get federationInboxChannelDescription =>
      'Na jednym z twoich serwerów pojawiła się prośba o udostępnienie bibliotek';

  @override
  String get federationNotifyTitle => 'Powiadamiaj o prośbach';

  @override
  String get federationNotifySubtitle =>
      'Powiadomienie na telefonie, gdy prośba przyjdzie, a aplikacja jest otwarta lub odtwarza';

  @override
  String get autoRecentlyPlayed => 'Ostatnio odtwarzane';

  @override
  String get settingsHistoryEnabled => 'Rejestruj odtworzenia';

  @override
  String get settingsHistorySend => 'Wysyłaj odtworzenia do serwerów';

  @override
  String get settingsHistoryClear => 'Wyczyść historię';

  @override
  String settingsHistoryClearConfirm(String size, int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other:
          'To usunie historię słuchania z tego telefonu ($size), w tym $count odtworzenia jeszcze niezsynchronizowane. Serwery zachowają swoją.',
      many:
          'To usunie historię słuchania z tego telefonu ($size), w tym $count odtworzeń jeszcze niezsynchronizowanych. Serwery zachowają swoją.',
      few:
          'To usunie historię słuchania z tego telefonu ($size), w tym $count odtworzenia jeszcze niezsynchronizowane. Serwery zachowają swoją.',
      one:
          'To usunie historię słuchania z tego telefonu ($size), w tym $count odtworzenie jeszcze niezsynchronizowane. Serwery zachowają swoją.',
      zero:
          'To usunie historię słuchania z tego telefonu ($size). Serwery zachowają swoją.',
    );
    return '$_temp0';
  }

  @override
  String get settingsHistoryCleared => 'Historia słuchania wyczyszczona';

  @override
  String songInfoServerPlays(num count, Object server) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count odtworzenia na $server',
      many: '$count odtworzeń na $server',
      few: '$count odtworzenia na $server',
      one: '1 odtworzenie na $server',
    );
    return '$_temp0';
  }

  @override
  String songInfoDevicePlays(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count odtworzenia na tym telefonie',
      many: '$count odtworzeń na tym telefonie',
      few: '$count odtworzenia na tym telefonie',
      one: '1 odtworzenie na tym telefonie',
    );
    return '$_temp0';
  }

  @override
  String songInfoLastPlayed(Object ago) {
    return 'ostatnio $ago';
  }

  @override
  String get listeningTitle => 'Statystyki słuchania';

  @override
  String get listeningScopeThisPhone => 'Ten telefon';

  @override
  String get listeningScopeSheetTitle => 'Co pokazać';

  @override
  String get listeningScopeSheetDevice =>
      'Co odtworzył ten telefon: każdy serwer, pliki lokalne, offline. Przechowywane na tym urządzeniu.';

  @override
  String get listeningScopeSheetServer =>
      'Twoje odtworzenia na tym serwerze z każdej aplikacji — odtwarzacza webowego, innych telefonów i tego telefonu po synchronizacji.';

  @override
  String get listeningScopeSheetLegacy =>
      'Brak statystyk słuchania — wymaga mStream 6.27 lub nowszego.';

  @override
  String listeningScopeSheetPeer(Object server) {
    return 'Liczone na $server: utwory peera liczą się tam, gdzie jest Twoje konto.';
  }

  @override
  String get listeningProvenanceDevice =>
      'Co odtworzył ten telefon, na każdym serwerze i z plików lokalnych. Przechowywane na tym urządzeniu.';

  @override
  String listeningProvenanceServer(Object server) {
    return 'Twoje odtworzenia na $server z każdej aplikacji, w tym utwory jego peerów.';
  }

  @override
  String listeningProvenancePeer(Object peer, Object server) {
    return 'Twoje odtworzenia utworów $peer, liczone na $server.';
  }

  @override
  String listeningProvenanceFallback(Object server) {
    return '$server nie odpowiedział — pokazane są odtworzenia tego telefonu na nim.';
  }

  @override
  String listeningProvenanceLegacy(Object server) {
    return '$server nie ma jeszcze statystyk słuchania (mStream 6.27+) — pokazane są odtworzenia tego telefonu na nim.';
  }

  @override
  String listeningUnsynced(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count odtworzenia jeszcze niezsynchronizowane',
      many: '$count odtworzeń jeszcze niezsynchronizowanych',
      few: '$count odtworzenia jeszcze niezsynchronizowane',
      one: '1 odtworzenie jeszcze niezsynchronizowane',
    );
    return '$_temp0';
  }

  @override
  String get listeningPeriodWeek => 'Ten tydzień';

  @override
  String get listeningPeriodMonth => 'Ten miesiąc';

  @override
  String get listeningPeriodQuarter => 'Ten kwartał';

  @override
  String get listeningPeriodYear => 'Ten rok';

  @override
  String get listeningPeriodAll => 'Cały czas';

  @override
  String get listeningTilePlays => 'Odtworzenia';

  @override
  String get listeningTileTime => 'Czas słuchania';

  @override
  String get listeningTileTracks => 'Utwory';

  @override
  String get listeningTileSkips => 'Pominięcia';

  @override
  String get listeningTileStreak => 'Seria';

  @override
  String get listeningTileSessions => 'Sesje';

  @override
  String listeningDays(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count dnia',
      many: '$count dni',
      few: '$count dni',
      one: '1 dzień',
    );
    return '$_temp0';
  }

  @override
  String get listeningTileSubCounted => 'zaliczone odtworzenia';

  @override
  String get listeningTileSubTracks => 'różnych utworów';

  @override
  String listeningTileSubSkips(Object pct) {
    return '$pct% rozpoczęć';
  }

  @override
  String listeningTileSubStreak(Object count) {
    return 'najdłuższa: $count';
  }

  @override
  String listeningTileSubSessions(Object duration) {
    return 'około $duration każda';
  }

  @override
  String get listeningWhenYouListen => 'Kiedy słuchasz';

  @override
  String listeningMostAround(Object hour) {
    return 'Najwięcej około $hour';
  }

  @override
  String get listeningTop => 'Top';

  @override
  String get listeningTopTracks => 'Utwory';

  @override
  String get listeningTopArtists => 'Wykonawcy';

  @override
  String get listeningTopAlbums => 'Albumy';

  @override
  String get listeningByPlays => 'Odtworzenia';

  @override
  String get listeningByTime => 'Czas';

  @override
  String listeningPlays(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count odtworzenia',
      many: '$count odtworzeń',
      few: '$count odtworzenia',
      one: '1 odtworzenie',
    );
    return '$_temp0';
  }

  @override
  String listeningTracksCount(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count utworu',
      many: '$count utworów',
      few: '$count utwory',
      one: '1 utwór',
    );
    return '$_temp0';
  }

  @override
  String get listeningRecent => 'Ostatnie odtworzenia';

  @override
  String get listeningLoadMore => 'Wczytaj więcej';

  @override
  String get listeningEmptyTitle => 'Brak odtworzeń';

  @override
  String get listeningEmptyDevice =>
      'Odtworzenia pojawiają się tutaj w miarę słuchania. Ten telefon prowadzi własny zapis; Twój serwer prowadzi Twój zapis ze wszystkich aplikacji.';

  @override
  String listeningEmptyServer(Object server) {
    return 'Do $server nic jeszcze nie zgłoszono. Odtworzenia z tego telefonu dotrą po synchronizacji.';
  }

  @override
  String get listeningEmptyPeriod => 'Nic w tym okresie.';

  @override
  String get listeningOutcomeCompleted => 'Ukończone';

  @override
  String get listeningOutcomeSkipped => 'Pominięte';

  @override
  String get listeningOutcomeStopped => 'Zatrzymane';

  @override
  String listeningOutcomeAt(Object outcome, Object position) {
    return '$outcome przy $position';
  }

  @override
  String get listeningNotCounted => 'niezaliczone';

  @override
  String listeningVia(Object peer) {
    return 'przez $peer';
  }

  @override
  String listeningRepeats(Object count) {
    return '×$count';
  }

  @override
  String get listeningLocalFile => 'Plik lokalny';

  @override
  String get listeningHistoryOff =>
      'Historia słuchania jest wyłączona. Włącz ją w ustawieniach, aby rejestrować odtworzenia na tym telefonie.';

  @override
  String listeningError(Object message) {
    return 'Nie udało się wczytać: $message';
  }

  @override
  String get listeningRetry => 'Ponów';

  @override
  String get listeningToday => 'Dzisiaj';

  @override
  String get listeningYesterday => 'Wczoraj';

  @override
  String get listeningPlaysPerDay => 'Odtworzenia dziennie';

  @override
  String get listeningPlaysPerMonth => 'Odtworzenia miesięcznie';

  @override
  String listeningMostOnDay(int count, String date) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Najwięcej $date: $count odtworzenia',
      many: 'Najwięcej $date: $count odtworzeń',
      few: 'Najwięcej $date: $count odtworzenia',
      one: 'Najwięcej $date: 1 odtworzenie',
    );
    return '$_temp0';
  }

  @override
  String listeningMostInMonth(int count, String month) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Najwięcej: $month — $count odtworzenia',
      many: 'Najwięcej: $month — $count odtworzeń',
      few: 'Najwięcej: $month — $count odtworzenia',
      one: 'Najwięcej: $month — 1 odtworzenie',
    );
    return '$_temp0';
  }

  @override
  String get settingsHomeWidget => 'Widżet ekranu głównego';

  @override
  String get settingsHomeWidgetSubtitleIos =>
      'Przytrzymaj ekran główny, dodaj widżet i wybierz mStream Music.';

  @override
  String get homeWidgetPickSize => 'Wybierz rozmiar';

  @override
  String get homeWidgetPinUnsupported =>
      'Ten launcher nie może dodawać widżetów stąd. Użyj jego własnego wyboru widżetów.';

  @override
  String discoverSheetPeerOnline(String name) {
    return '„$name” online';
  }

  @override
  String discoverSheetPeerNotAnswering(String name) {
    return '„$name” nie odpowiada';
  }

  @override
  String discoverSheetSongCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count utworu',
      many: '$count utworów',
      few: '$count utwory',
      one: '1 utwór',
    );
    return '$_temp0';
  }

  @override
  String discoverSheetAlbumCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count albumu',
      many: '$count albumów',
      few: '$count albumy',
      one: '1 album',
    );
    return '$_temp0';
  }

  @override
  String get discoverSheetNotInLibrary => 'nie ma w twojej bibliotece';

  @override
  String get discoverSheetInLibrary => 'jest w twojej bibliotece';

  @override
  String discoverSheetYouHaveAlbums(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'masz $count albumu',
      many: 'masz $count albumów',
      few: 'masz $count albumy',
      one: 'masz 1 album',
    );
    return '$_temp0';
  }

  @override
  String get discoverSheetOpenAlbum => 'Otwórz album';

  @override
  String get discoverSheetQueueAlbum => 'Dodaj album do kolejki';

  @override
  String get discoverSheetPlayAlbum => 'Odtwórz album';

  @override
  String get discoverSheetOpenArtist => 'Otwórz wykonawcę';

  @override
  String get discoverSheetListen => 'Słuchaj';

  @override
  String get discoverSheetKeepCopy => 'Zachowaj kopię';

  @override
  String get discoverSheetOpenElsewhere => 'Otwórz gdzie indziej';

  @override
  String discoverSheetBrowsePeer(String name) {
    return 'Przeglądaj „$name”';
  }

  @override
  String get discoverSheetDownloadToPhone => 'Pobierz na ten telefon';

  @override
  String get discoverSheetDownloadToPhoneSub =>
      'Do słuchania offline na tym urządzeniu';

  @override
  String discoverSheetAlbumFailed(String name) {
    return 'Nie udało się wczytać tego albumu z „$name”';
  }

  @override
  String discoverAlbumCardMore(String album) {
    return 'Więcej dla „$album”';
  }

  @override
  String get discoverKeepThisSong => 'Ten utwór';

  @override
  String get discoverKeepAlbum => 'Album';

  @override
  String get discoverKeepArtist => 'Wykonawca';

  @override
  String get discoverKeepWhat => 'Co zachować';

  @override
  String discoverKeepYouHave(int count) {
    return 'masz $count';
  }

  @override
  String discoverKeepOnlyMissing(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Tylko $count albumu, których nie masz',
      many: 'Tylko $count albumów, których nie masz',
      few: 'Tylko $count albumy, których nie masz',
      one: 'Tylko 1 album, którego nie masz',
    );
    return '$_temp0';
  }

  @override
  String get discoverKeepFilesGoTo => 'Pliki trafią do';

  @override
  String discoverKeepPathTooLong(int max) {
    return 'Ścieżka tej kopii przekroczyłaby $max znaków – więcej, niż przyjmuje serwer';
  }

  @override
  String get discoverKeepFolderPerAlbum => 'osobny folder na każdy album';

  @override
  String get discoverKeepChange => 'Zmień';

  @override
  String get discoverKeepChangeHint => 'Zmień miejsce zapisu kopii';

  @override
  String get discoverKeepAddSong => 'Dodaj utwór';

  @override
  String get discoverKeepAddAlbum => 'Dodaj album';

  @override
  String get discoverKeepAddEveryAlbum => 'Dodaj wszystkie albumy';

  @override
  String discoverKeepAddAlbums(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Dodaj $count albumu',
      many: 'Dodaj $count albumów',
      few: 'Dodaj $count albumy',
      one: 'Dodaj 1 album',
    );
    return '$_temp0';
  }

  @override
  String get discoverKeepAddMissing => 'Dodaj albumy, których nie masz';

  @override
  String get discoverKeepUploadsOff =>
      'Twoje konto nie może dodawać plików na ten serwer';

  @override
  String get discoverKeepNoLibrary =>
      'Żadna biblioteka na twoim serwerze nie przyjmuje nowych plików';

  @override
  String get discoverKeepStartFailed =>
      'Nie udało się połączyć z twoim serwerem. Spróbuj ponownie.';

  @override
  String get discoverKeepDestChanged =>
      'Miejsce zapisu plików zmieniło się od otwarcia. Sprawdź ścieżkę powyżej i dodaj ponownie.';

  @override
  String get discoverKeepDestChangedTryAgain =>
      'Miejsce zapisu plików zmieniło się od otwarcia. Sprawdź ścieżkę powyżej i spróbuj ponownie.';

  @override
  String discoverKeepRetryAddsTo(String path) {
    return 'Ponowienie trafi do $path, twojego obecnie zapisanego miejsca';
  }

  @override
  String discoverKeepAddAgainAddsTo(String path) {
    return 'Ponowne dodanie trafi do $path, twojego obecnie zapisanego miejsca';
  }

  @override
  String discoverKeepConfirmTitle(int count, String peer) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Skopiować $count albumu z „$peer”?',
      many: 'Skopiować $count albumów z „$peer”?',
      few: 'Skopiować $count albumy z „$peer”?',
      one: 'Skopiować 1 album z „$peer”?',
    );
    return '$_temp0';
  }

  @override
  String discoverKeepConfirmEveryTitle(String artist, String peer) {
    return 'Skopiować wszystkie albumy wykonawcy $artist z „$peer”?';
  }

  @override
  String discoverKeepConfirmBody(String path) {
    return 'Trafią na twój serwer do $path, osobny folder na każdy album. Utwory, które już masz, zostaną pominięte.';
  }

  @override
  String discoverKeepConfirmBodyFlat(String path) {
    return 'Trafią na twój serwer do $path. Utwory, które już masz, zostaną pominięte.';
  }

  @override
  String discoverKeepConfirmAction(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Skopiuj $count albumu',
      many: 'Skopiuj $count albumów',
      few: 'Skopiuj $count albumy',
      one: 'Skopiuj 1 album',
    );
    return '$_temp0';
  }

  @override
  String get discoverKeepConfirmEveryAction => 'Skopiuj wszystkie albumy';

  @override
  String get discoverJobQueued => 'Czeka na wolne miejsce';

  @override
  String get discoverJobQueuedSub => 'Ruszy samo';

  @override
  String get discoverJobCopying => 'Kopiowanie';

  @override
  String get discoverJobStarting => 'Uruchamianie…';

  @override
  String get discoverJobStopping => 'Zatrzymywanie…';

  @override
  String get discoverJobInCollection => 'W twojej kolekcji';

  @override
  String get discoverJobOwned => 'Już to masz';

  @override
  String get discoverJobOwnedSub => 'Twoja biblioteka ma już ten utwór';

  @override
  String get discoverJobSkipped => 'Pominięto · plik już tam jest';

  @override
  String discoverJobExistsSub(String path) {
    return 'Pod $path jest już plik · nic nie nadpisano';
  }

  @override
  String get discoverJobFailed => 'Kopiowanie nie powiodło się';

  @override
  String get discoverJobFailedSub => 'Kopiowanie nie zostało ukończone';

  @override
  String get discoverJobNothingCopiedLead => 'Nic nie skopiowano';

  @override
  String get discoverJobNothingCopied => 'nic nie skopiowano';

  @override
  String get discoverJobStopped => 'Zatrzymano';

  @override
  String discoverJobStoppedQuota(String peer) {
    return 'Zatrzymał je limit transferu „$peer”';
  }

  @override
  String discoverJobStoppedBusy(String peer) {
    return '„$peer” obsługuje teraz zbyt wiele strumieni';
  }

  @override
  String discoverJobStoppedPeer(String peer) {
    return '„$peer” przestał odpowiadać';
  }

  @override
  String discoverJobStoppedRefused(String peer) {
    return '„$peer” nie pozwala na kopie z kluczem twojego serwera';
  }

  @override
  String get discoverJobCancelledNothing => 'Zatrzymano · nic nie skopiowano';

  @override
  String discoverJobCancelledSome(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Zatrzymano · skopiowano $count',
      many: 'Zatrzymano · skopiowano $count',
      few: 'Zatrzymano · skopiowano $count',
      one: 'Zatrzymano · skopiowano 1',
    );
    return '$_temp0';
  }

  @override
  String get discoverJobCancelledSub => 'Anulowano';

  @override
  String discoverJobCancelledStay(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Anulowano · $count utworu zostaje w twojej kolekcji',
      many: 'Anulowano · $count utworów zostaje w twojej kolekcji',
      few: 'Anulowano · $count utwory zostają w twojej kolekcji',
      one: 'Anulowano · utwór zostaje w twojej kolekcji',
    );
    return '$_temp0';
  }

  @override
  String get discoverJobNothingAll => 'Masz już wszystko';

  @override
  String discoverJobNothingFrom(String peer) {
    return 'Nie ma nic do skopiowania z „$peer”';
  }

  @override
  String get discoverJobOnlyGuest => 'Brak ich własnych albumów do skopiowania';

  @override
  String discoverJobOnlyGuestSub(String artist, String peer) {
    return '$artist występuje na albumach z „$peer” tylko gościnnie';
  }

  @override
  String discoverJobFromOther(String peer) {
    return 'Kopiowanie z „$peer”';
  }

  @override
  String discoverJobComesBack(String action) {
    return '„$action” wróci, gdy ta kopia się skończy';
  }

  @override
  String get discoverJobDone => 'Zakończono';

  @override
  String discoverJobCopiedCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'skopiowano $count',
      many: 'skopiowano $count',
      few: 'skopiowano $count',
      one: 'skopiowano 1',
    );
    return '$_temp0';
  }

  @override
  String discoverJobOwnedCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count już masz',
      many: '$count już masz',
      few: '$count już masz',
      one: '1 już masz',
    );
    return '$_temp0';
  }

  @override
  String discoverJobFailedCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count nieudanego',
      many: '$count nieudanych',
      few: '$count nieudane',
      one: '1 nieudany',
    );
    return '$_temp0';
  }

  @override
  String discoverJobAlbumsFailed(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count albumu nieudanego',
      many: '$count albumów nieudanych',
      few: '$count albumy nieudane',
      one: '1 album nieudany',
    );
    return '$_temp0';
  }

  @override
  String discoverJobAlbumsLeftOut(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count albumu pominiętego',
      many: '$count albumów pominiętych',
      few: '$count albumy pominięte',
      one: '1 album pominięty',
    );
    return '$_temp0';
  }

  @override
  String get discoverJobRetry => 'Ponów';

  @override
  String get discoverJobAddAgain => 'Dodaj ponownie';

  @override
  String get discoverJobAddToQueue => 'Dodaj do kolejki';

  @override
  String get discoverMarkWaiting => 'czeka';

  @override
  String get discoverMarkCopying => 'kopiowanie…';

  @override
  String discoverMarkCopyingCount(int done, int total) {
    return 'kopiowanie $done z $total';
  }

  @override
  String get discoverMarkStopping => 'zatrzymywanie…';

  @override
  String get discoverMarkInCollection => 'w twojej kolekcji';

  @override
  String get discoverMarkAlreadyYours => 'już masz';

  @override
  String get discoverMarkStopped => 'zatrzymano';

  @override
  String get discoverMarkRefused => 'odmowa';

  @override
  String get discoverMarkFailed => 'nieudane';

  @override
  String get discoverMarkSkipped => 'pominięto';

  @override
  String discoverCopiesCopying(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Kopiowanie: $count',
      many: 'Kopiowanie: $count',
      few: 'Kopiowanie: $count',
      one: 'Kopiowanie: 1',
    );
    return '$_temp0';
  }

  @override
  String discoverCopiesFailed(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count nieudanej',
      many: '$count nieudanych',
      few: '$count nieudane',
      one: '1 nieudana',
    );
    return '$_temp0';
  }

  @override
  String discoverCopiesLabel(String summary) {
    return 'Kopie: $summary';
  }

  @override
  String get discoverCopiesTitle => 'Kopie';

  @override
  String get discoverCopiesSectionCopying => 'Kopiowanie';

  @override
  String get discoverCopiesSectionAttention => 'Zatrzymane lub nieudane';

  @override
  String get discoverCopiesSectionFinished => 'Właśnie zakończone';

  @override
  String get discoverCopiesClearFinished => 'Wyczyść zakończone';

  @override
  String get discoverCopiesEmpty => 'Nic się nie kopiuje';

  @override
  String get discoverCopiesEmptySub =>
      'Przytrzymaj utwór lub album z połączonego serwera w Odkrywaj, aby zachować kopię.';

  @override
  String get discoverCopiesOpenDiscover => 'Otwórz Odkrywaj';

  @override
  String get discoverCopiesLoadFailed => 'Nie udało się wczytać twoich kopii';

  @override
  String get discoverCopiesLoadFailedSub =>
      'Twój serwer nie odpowiedział. Kopie trwają tam dalej.';

  @override
  String get discoverCopiesLoading => 'Wczytywanie twoich kopii';

  @override
  String get discoverCopiesKindSong => 'Utwór';

  @override
  String get discoverCopiesKindAlbum => 'Album';

  @override
  String get discoverCopiesKindEvery => 'Wszystkie albumy';

  @override
  String get discoverCopiesKindMissing => 'To, czego nie masz';

  @override
  String discoverCopiesFrom(String peer) {
    return 'z „$peer”';
  }

  @override
  String discoverCopiesEveryAlbumBy(String artist) {
    return 'Wszystkie albumy wykonawcy $artist';
  }

  @override
  String discoverCopiesMissingOf(String artist) {
    return '$artist · albumy, których nie masz';
  }

  @override
  String get discoverCopiesAlreadyFinished =>
      'Już zakończone · nie ma czego anulować';

  @override
  String get discoverCopiesCancelFailed =>
      'Nie udało się anulować. Spróbuj ponownie.';

  @override
  String get discoverCopiesDestChanged =>
      'Nie udało się rozpocząć: miejsce zapisu plików się zmieniło — ponów z Zachowaj kopię';

  @override
  String discoverToastCopying(String title, String peer) {
    return 'Kopiowanie „$title” z „$peer”';
  }

  @override
  String discoverToastCopyingEvery(String artist, String peer) {
    return 'Kopiowanie wszystkich albumów wykonawcy $artist z „$peer”';
  }

  @override
  String discoverToastCopyingMissing(String artist, String peer) {
    return 'Kopiowanie z „$peer” albumów wykonawcy $artist, których nie masz';
  }

  @override
  String get discoverToastAdded => 'Dodano do twojej kolekcji';

  @override
  String get discoverToastAlreadyYours => 'Już jest w twojej bibliotece';

  @override
  String discoverToastFailed(String reason) {
    return 'Kopiowanie nie powiodło się: $reason';
  }

  @override
  String discoverToastStopped(String reason) {
    return 'Zatrzymano przedwcześnie: $reason';
  }

  @override
  String get discoverToastLinkFailed => 'Nie udało się otworzyć tego linku';

  @override
  String discoverToastSaved(String path) {
    return 'Zapisano · kopie trafią do $path';
  }

  @override
  String get discoverDestTitle => 'Gdzie trafiają kopie';

  @override
  String get discoverDestSub =>
      'Jedno ustawienie dla twojego konta · używa go każda kopia';

  @override
  String get discoverDestTagDefault => 'domyślne biblioteki';

  @override
  String get discoverDestTagYours => 'twoje';

  @override
  String discoverDestLandsAt(String title) {
    return '„$title” trafi do';
  }

  @override
  String get discoverDestFixLayout =>
      'Popraw układ, aby zobaczyć, gdzie trafią pliki';

  @override
  String discoverDestPathTooLong(int max) {
    return 'Ścieżka tego utworu przekroczyłaby $max znaków – więcej, niż przyjmuje serwer';
  }

  @override
  String get discoverDestLibrary => 'Biblioteka';

  @override
  String get discoverDestLayout => 'Układ';

  @override
  String get discoverDestPresetArtistAlbum => 'Wykonawca / Album';

  @override
  String get discoverDestPresetServer => 'Serwer / Wykonawca / Album';

  @override
  String get discoverDestPresetServerFolders =>
      'Te same foldery co na serwerze';

  @override
  String get discoverDestPresetLibrary => 'Układ biblioteki';

  @override
  String get discoverDestPresetCustom => 'Własny';

  @override
  String get discoverDestCustomSub => 'Wpisz własną ścieżkę';

  @override
  String get discoverDestCustomField => 'Własny układ';

  @override
  String discoverDestCustomHint(String example) {
    return 'np. Od znajomych lub $example';
  }

  @override
  String get discoverDestCustomHelp =>
      'Foldery oddzielaj znakiem /. Zmienne sortują kopie według wykonawcy, albumu…; stała nazwa umieszcza każdą kopię w tym samym folderze.';

  @override
  String get discoverDestCustomEmpty =>
      'Wpisz ścieżkę, aby zobaczyć, gdzie trafią pliki';

  @override
  String get discoverDestInsertArtist => 'Wstaw wykonawcę';

  @override
  String get discoverDestInsertAlbum => 'Wstaw album';

  @override
  String get discoverDestInsertYear => 'Wstaw rok';

  @override
  String get discoverDestInsertGenre => 'Wstaw gatunek';

  @override
  String get discoverDestInsertAlbumArtist => 'Wstaw wykonawcę albumu';

  @override
  String get discoverDestInsertPeer => 'Wstaw nazwę serwera';

  @override
  String get discoverDestInsertServerFolder => 'Wstaw folder z serwera';

  @override
  String discoverDestErrUnknownVar(String name, String vars) {
    return 'Nieznana zmienna $name. Użyj $vars.';
  }

  @override
  String discoverDestErrBraces(String example) {
    return 'Nawias klamrowy jest w złym miejscu — zmienne zapisuje się jak $example.';
  }

  @override
  String discoverDestErrBaseBraces(String folder) {
    return '„$folder” to folder ustawiony na innym urządzeniu, ale w układzie jest czytany jako zmienna. Zmień tu jego nazwę albo wybierz układ.';
  }

  @override
  String get discoverDestErrAbsolute =>
      'Układ nie może zaczynać się od / — zaczyna się w bibliotece.';

  @override
  String get discoverDestErrTraversal =>
      'Ścieżka nie może zawierać folderów „..”.';

  @override
  String get discoverDestErrEmpty =>
      'Nie powstaje żaden folder — dodaj nazwę lub zmienną.';

  @override
  String get discoverDestErrHome => 'Ścieżka nie może zawierać ~ ani \$HOME.';

  @override
  String get discoverDestErrGeneric => 'Tej ścieżki nie można użyć.';

  @override
  String get discoverDestErrDrive =>
      'Ścieżka nie może zawierać litery dysku, np. C:.';

  @override
  String discoverDestErrTooLong(int max) {
    return 'Układ może mieć najwyżej $max znaków.';
  }

  @override
  String get discoverDestErrControl =>
      'Ścieżka nie może zawierać tabulatorów ani innych znaków sterujących.';

  @override
  String discoverDestMissing(String vars) {
    return 'Brak wartości dla tego utworu, więc pominięte w ścieżce: $vars';
  }

  @override
  String get discoverDestGenreSlot => 'gatunek';

  @override
  String get discoverDestArtistSlot => 'wykonawca';

  @override
  String get discoverDestYearSlot => 'rok';

  @override
  String get discoverDestServerFolderSlot => 'folder z serwera';

  @override
  String discoverKeepSlotNote(int count, String slots) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other:
          '$slots pochodzą ze znaczników każdego utworu, więc te utwory mogą trafić do więcej niż jednego folderu.',
      many:
          '$slots pochodzą ze znaczników każdego utworu, więc te utwory mogą trafić do więcej niż jednego folderu.',
      few:
          '$slots pochodzą ze znaczników każdego utworu, więc te utwory mogą trafić do więcej niż jednego folderu.',
      one:
          '$slots pochodzi ze znaczników każdego utworu, więc te utwory mogą trafić do więcej niż jednego folderu.',
    );
    return '$_temp0';
  }

  @override
  String discoverKeepSlotNoteGenre(int count, String slots) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other:
          '$slots pochodzą ze znaczników każdego utworu, więc te utwory mogą trafić do więcej niż jednego folderu (dla utworu bez gatunku ten folder jest pomijany).',
      many:
          '$slots pochodzą ze znaczników każdego utworu, więc te utwory mogą trafić do więcej niż jednego folderu (dla utworu bez gatunku ten folder jest pomijany).',
      few:
          '$slots pochodzą ze znaczników każdego utworu, więc te utwory mogą trafić do więcej niż jednego folderu (dla utworu bez gatunku ten folder jest pomijany).',
      one:
          '$slots pochodzi ze znaczników każdego utworu, więc te utwory mogą trafić do więcej niż jednego folderu (dla utworu bez gatunku ten folder jest pomijany).',
    );
    return '$_temp0';
  }

  @override
  String discoverKeepSlotNoteSong(String slots) {
    return '$slots pochodzi ze znaczników utworu (dla utworu bez gatunku ten folder jest pomijany).';
  }

  @override
  String discoverKeepSlotNoteServer(String server) {
    return '$server zależy od tego, gdzie każdy utwór leży na serwerze, więc te utwory mogą trafić do więcej niż jednego folderu.';
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
          '$slots pochodzą ze znaczników każdego utworu, a $server z miejsca, w którym leży on na serwerze, więc te utwory mogą trafić do więcej niż jednego folderu.',
      many:
          '$slots pochodzą ze znaczników każdego utworu, a $server z miejsca, w którym leży on na serwerze, więc te utwory mogą trafić do więcej niż jednego folderu.',
      few:
          '$slots pochodzą ze znaczników każdego utworu, a $server z miejsca, w którym leży on na serwerze, więc te utwory mogą trafić do więcej niż jednego folderu.',
      one:
          '$slots pochodzi ze znaczników każdego utworu, a $server z miejsca, w którym leży on na serwerze, więc te utwory mogą trafić do więcej niż jednego folderu.',
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
          '$slots pochodzą ze znaczników każdego utworu, a $server z miejsca, w którym leży on na serwerze, więc te utwory mogą trafić do więcej niż jednego folderu (dla utworu bez gatunku ten folder jest pomijany).',
      many:
          '$slots pochodzą ze znaczników każdego utworu, a $server z miejsca, w którym leży on na serwerze, więc te utwory mogą trafić do więcej niż jednego folderu (dla utworu bez gatunku ten folder jest pomijany).',
      few:
          '$slots pochodzą ze znaczników każdego utworu, a $server z miejsca, w którym leży on na serwerze, więc te utwory mogą trafić do więcej niż jednego folderu (dla utworu bez gatunku ten folder jest pomijany).',
      one:
          '$slots pochodzi ze znaczników każdego utworu, a $server z miejsca, w którym leży on na serwerze, więc te utwory mogą trafić do więcej niż jednego folderu (dla utworu bez gatunku ten folder jest pomijany).',
    );
    return '$_temp0';
  }

  @override
  String get discoverDestUseDefault => 'Użyj domyślnych ustawień biblioteki';

  @override
  String get discoverDestSaving => 'Zapisywanie…';

  @override
  String get discoverDestLoadFailed =>
      'Nie udało się wczytać, gdzie trafiają kopie';

  @override
  String get discoverDestLoading =>
      'Wczytywanie miejsca, do którego trafiają kopie';

  @override
  String get discoverKeepFirstUse =>
      'Kopie trafiają na twój serwer, nie na ten telefon. Przed pierwszą sprawdź, gdzie trafią.';

  @override
  String get discoverElsewhereExact => 'Dokładne strony';

  @override
  String get discoverElsewhereSearch => 'Szukaj';

  @override
  String get discoverElsewhereMbRecording => 'Nagranie w MusicBrainz';

  @override
  String get discoverElsewhereMbReleaseGroup => 'Grupa wydań w MusicBrainz';

  @override
  String get discoverElsewhereMbIsrc => 'ISRC w MusicBrainz';

  @override
  String get discoverElsewhereEmpty => 'Brak linków do tego utworu';

  @override
  String get discoverElsewhereEmptySub =>
      'Nie ma identyfikatorów MusicBrainz ani tytułu czy wykonawcy do wyszukania.';

  @override
  String get discoverElsewhereFailed => 'Nie udało się teraz wyszukać linków';

  @override
  String get discoverElsewhereLoading => 'Wyszukiwanie linków';

  @override
  String get discoverElsewhereOpensOutside => 'Otwiera się poza aplikacją';

  @override
  String get visualizerMilkdropTitle => 'Wizualizator Milkdrop';

  @override
  String get visualizerShadertoyTitle => 'Wizualizator ShaderToy';

  @override
  String get realAudioSynthesizedNote =>
      'Bez tego uprawnienia wizualizator używa danych syntetycznych.';

  @override
  String get realAudioDontAskAgain => 'Nie pytaj ponownie';

  @override
  String get realAudioUseSynthesized => 'Użyj danych syntetycznych';

  @override
  String get realAudioUseReal => 'Użyj rzeczywistego dźwięku';

  @override
  String get queueSharePlaylist => 'Udostępnij playlistę';

  @override
  String get autoDjStopShort => 'Zatrzymaj';

  @override
  String get autoDjPlayFrom => 'Odtwarzaj z';

  @override
  String get autoDjAllServers => 'Wszystkie serwery';

  @override
  String autoDjServersTakingPart(int count, int total) {
    return '$count z $total';
  }

  @override
  String get autoDjFirstSong => 'Pierwszy utwór';

  @override
  String get autoDjFirstSongRandom => 'Losowy';

  @override
  String get autoDjFirstSongChoose => 'Wybierz';

  @override
  String get autoDjMustMatch => 'Musi pasować';

  @override
  String get autoDjPrefer => 'Preferuj';

  @override
  String autoDjPercent(int pct) {
    return '$pct%';
  }

  @override
  String get autoDjDrift => 'Dryfuj';

  @override
  String get autoDjStayClose => 'Trzymaj się blisko';

  @override
  String get autoDjGenres => 'Gatunki';

  @override
  String get autoDjGenresOnly => 'Tylko';

  @override
  String get autoDjGenresSkip => 'Pomiń';

  @override
  String autoDjGenresSkipValue(String genres) {
    return 'Bez $genres';
  }

  @override
  String get autoDjRating => 'Ocena';

  @override
  String autoDjRatingValue(String stars) {
    return '$stars★+';
  }

  @override
  String get autoDjAny => 'Bez znaczenia';

  @override
  String autoDjLengthOver(String min) {
    return '$min+';
  }

  @override
  String autoDjLengthUnder(String max) {
    return 'Poniżej $max';
  }

  @override
  String autoDjLengthBetween(String min, String max) {
    return '$min–$max';
  }

  @override
  String get autoDjIncludeUnknown => 'Uwzględnij nieznane';

  @override
  String get autoDjLengthShortest => 'Minimum';

  @override
  String get autoDjLengthLongest => 'Maksimum';

  @override
  String get autoDjWheelHours => 'godz.';

  @override
  String get autoDjTempo => 'Beatmatching';

  @override
  String get autoDjSkipWords => 'Pomijane słowa';

  @override
  String get autoDjBatch => 'Partia';

  @override
  String get autoDjVaries => 'Różnie';

  @override
  String autoDjMax(int count) {
    return 'maks. $count';
  }

  @override
  String autoDjNeedsServer(String version) {
    return 'Serwer $version+';
  }

  @override
  String get autoDjDiscoveryOff => 'Bez odkrywania';

  @override
  String get autoDjStillScanning => 'Trwa skanowanie';

  @override
  String get autoDjTooStrict => 'Zbyt ścisłe';

  @override
  String get autoDjNotOnPeers => 'Nie dla partnerów';

  @override
  String get autoDjNoMoodData => 'Brak danych nastroju';

  @override
  String get autoDjOtherModel => 'Inny model audio';

  @override
  String get autoDjUnreachable => 'Nieosiągalny';

  @override
  String get autoDjRemember => 'Zapamiętaj';

  @override
  String get autoDjGenresNone => 'Brak gatunków';

  @override
  String get autoDjNoMatches => 'Brak wyników';

  @override
  String get autoDjRecentlyPlayed => 'Ostatnio odtwarzane';

  @override
  String get autoDjFirstSongRecent => 'Ostatnie';

  @override
  String get browseLoadFailed =>
      'Couldn\'t load this from the server. Check the connection and try again.';

  @override
  String get settingsSectionVisualizer => 'Wizualizator';

  @override
  String get settingsOfflineQueueFooter =>
      'Dotyczy tylko pobierania kolejki. Utwory pobrane ręcznie zawsze zostają.';

  @override
  String settingsAutoDownloadCapValue(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count utworów',
      many: '$count utworów',
      few: '$count utwory',
      one: '$count utwór',
    );
    return '$_temp0';
  }

  @override
  String get settingsAutoDownloadCapHint => '0 = bez limitu';

  @override
  String get settingsStartupRecentHint => 'Ostatnio dodane';

  @override
  String settingsLetterStripValue(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count+ elementów',
      many: '$count+ elementów',
      few: '$count+ elementy',
      one: '$count+ element',
      zero: 'Zawsze',
    );
    return '$_temp0';
  }

  @override
  String get settingsLetterStripHint =>
      'Na listach A–Z. Krótsze listy zawijają długie nazwy.';

  @override
  String get settingsHistoryFooter =>
      'Serwery scrobblują do Last.fm, tylko jeśli masz tam połączone konto.';

  @override
  String get settingsHistoryEmpty => 'Pusta';

  @override
  String get settingsHistoryOffTitle => 'Przestać rejestrować odtworzenia?';

  @override
  String settingsHistoryOffBody(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other:
          'To usunie historię słuchania z tego telefonu, w tym $count odtworzenia jeszcze niezsynchronizowane. Serwery zachowają swoją.',
      many:
          'To usunie historię słuchania z tego telefonu, w tym $count odtworzeń jeszcze niezsynchronizowanych. Serwery zachowają swoją.',
      few:
          'To usunie historię słuchania z tego telefonu, w tym $count odtworzenia jeszcze niezsynchronizowane. Serwery zachowają swoją.',
      one:
          'To usunie historię słuchania z tego telefonu, w tym $count odtworzenie jeszcze niezsynchronizowane. Serwery zachowają swoją.',
      zero:
          'To usunie historię słuchania z tego telefonu. Serwery zachowają swoją.',
    );
    return '$_temp0';
  }

  @override
  String get settingsHistoryOffConfirm => 'Wyłącz';

  @override
  String get settingsHistoryClearTitle => 'Wyczyścić historię?';

  @override
  String get settingsResetTitle => 'Zresetować ustawienia?';

  @override
  String get settingsResetBody =>
      'Resetuje też Korektor, Transkodowanie i kilka opcji spoza Ustawień. Serwery, pobrane pliki, historia słuchania i zapisane presety zostają.';

  @override
  String get settingsResetBodyIos =>
      'Resetuje też Transkodowanie i kilka opcji spoza Ustawień. Serwery, pobrane pliki i historia słuchania zostają.';

  @override
  String get ytdlTitle => 'Add from YouTube';

  @override
  String ytdlHomeAdding(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Adding $count',
    );
    return '$_temp0';
  }

  @override
  String ytdlHomeAdded(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Added $count',
    );
    return '$_temp0';
  }

  @override
  String ytdlHomeFailed(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count failed',
    );
    return '$_temp0';
  }

  @override
  String get ytdlPasteHint => 'Paste a YouTube link';

  @override
  String get ytdlPasteFromClipboard => 'Paste from clipboard';

  @override
  String ytdlLandsIn(String path) {
    return 'Lands in $path';
  }

  @override
  String get ytdlLimits =>
      'One video per link · the server stops at 500 MB or after an hour · no live streams or playlists';

  @override
  String get ytdlEmptyTitle => 'Paste a link to add a song to your library.';

  @override
  String get ytdlEmptyWebApp =>
      'Songs added from the web app show up here too.';

  @override
  String ytdlLinkShortSent(String link) {
    return 'Short link: sent as $link';
  }

  @override
  String ytdlLinkSentAs(String link) {
    return 'Sent as $link';
  }

  @override
  String get ytdlLinkNotYoutube =>
      'That\'s not a YouTube link. Paste one from youtube.com or youtu.be.';

  @override
  String get ytdlLinkPlaylist =>
      'That\'s a playlist. Open one video in it and copy that link.';

  @override
  String get ytdlLinkInPlaylist => 'Just this video, not the playlist.';

  @override
  String get ytdlLinkLive =>
      'Live streams can\'t be saved. If this one has ended, it may still work.';

  @override
  String get ytdlLinkLiveOlder =>
      'This server doesn\'t stop live streams. Add this only if the stream has ended.';

  @override
  String get ytdlLookupReading => 'Reading the video…';

  @override
  String get ytdlLookupSlow => 'Still looking — YouTube can be slow.';

  @override
  String get ytdlLookupEnterYourself => 'Enter details yourself';

  @override
  String get ytdlLookupFailed =>
      'Couldn\'t read this video\'s details. It may be private, age-restricted or blocked for the server.';

  @override
  String get ytdlLookupTimedOut =>
      'The server took too long — it may still be setting up its downloader. Try again in a minute.';

  @override
  String get ytdlLookupEnterDetails => 'Enter details';

  @override
  String get ytdlLookupNoTags =>
      'No tags yet, so it goes into the library\'s top folder.';

  @override
  String get ytdlLookupFailedUsingYours =>
      'Couldn\'t read this video\'s details · Your details will be used.';

  @override
  String get ytdlLateFound => 'Details found for this video';

  @override
  String get ytdlLateUseThem => 'Use them';

  @override
  String get ytdlLateEditsStay => 'Your edits stay.';

  @override
  String get ytdlOffline =>
      'You\'re offline — the lookup runs when you\'re back.';

  @override
  String get ytdlYtdlpMissing =>
      'This server can\'t download from YouTube yet. Ask its admin to set up yt-dlp.';

  @override
  String get ytdlCardNoAlbum => 'No album';

  @override
  String get ytdlSourceMusic => 'Tags from YouTube Music';

  @override
  String get ytdlSourceSplit => 'Artist and title from the video title';

  @override
  String get ytdlSourceSplitAgrees =>
      'Artist and title from the video title · matches the artist YouTube lists';

  @override
  String get ytdlSourceChannel => 'Artist may be the channel name — check it';

  @override
  String ytdlCleanedFrom(String title) {
    return 'Cleaned from “$title”';
  }

  @override
  String get ytdlUndoAll => 'Undo all';

  @override
  String get ytdlEditTags => 'Edit tags';

  @override
  String get ytdlFieldTitle => 'Title';

  @override
  String get ytdlHelpMusic => 'From YouTube Music';

  @override
  String get ytdlHelpVideoTitle => 'From the video title';

  @override
  String get ytdlHelpVideoTitleCleaned => 'From the video title, cleaned';

  @override
  String get ytdlHelpYoutubeArtist => 'From YouTube\'s artist field';

  @override
  String get ytdlHelpYoutubeArtistCheck =>
      'From YouTube\'s artist field — check it';

  @override
  String ytdlHelpYoutubeArtistStripped(String removed) {
    return 'From YouTube\'s artist field, “$removed” removed — check it';
  }

  @override
  String get ytdlHelpEdited => 'Edited';

  @override
  String get ytdlBlankTitle => 'Blank: the file gets the video\'s own title.';

  @override
  String get ytdlBlankArtistMusic =>
      'Blank: the file keeps YouTube Music\'s artist.';

  @override
  String ytdlBlankArtistGuess(String name) {
    return 'Blank: the file gets YouTube\'s own artist guess, often the raw channel name (here “$name”).';
  }

  @override
  String get ytdlBlankArtistGuessUnnamed =>
      'Blank: the file gets YouTube\'s own artist guess, often the raw channel name.';

  @override
  String get ytdlBlankAlbumSingle => 'Leave blank for a single';

  @override
  String get ytdlBlankAlbumKeeps => 'Blank keeps YouTube\'s album tag';

  @override
  String get ytdlBlankYear => 'Blank: the file gets YouTube\'s upload year.';

  @override
  String get ytdlYearInvalid => 'A year is 4 digits, like 2001';

  @override
  String ytdlRestoreSplit(String separator) {
    return 'Split at $separator';
  }

  @override
  String ytdlOrYoutubeArtist(String name) {
    return 'Or YouTube\'s artist: $name';
  }

  @override
  String get ytdlSwap => 'Swap artist and title';

  @override
  String get ytdlSavesTo => 'Saves to';

  @override
  String get ytdlSavesHere => 'Saves here';

  @override
  String get ytdlNewTag => 'new';

  @override
  String get ytdlSampleFile => 'file';

  @override
  String get ytdlSampleFileStem => 'Video_title';

  @override
  String ytdlFileAbout(String name) {
    return 'about $name';
  }

  @override
  String ytdlFileAboutLettersDropped(String name) {
    return 'about $name · letters outside A–Z are dropped from file names';
  }

  @override
  String get ytdlCheckFailed => 'Couldn\'t check this folder';

  @override
  String get ytdlJustThisSong => 'Just this song';

  @override
  String get ytdlUndo => 'Undo';

  @override
  String ytdlClash(String name) {
    return 'Something like “$name” looks to be in this folder already. The server won\'t replace it, so this would likely fail.';
  }

  @override
  String get ytdlClashChangeFormat =>
      'Change format — a different format makes a different file';

  @override
  String ytdlClashOlder(String name) {
    return 'A file named “$name” is already in this folder. This server would re-tag that file instead of adding a new one.';
  }

  @override
  String get ytdlChangeFormat => 'Change format';

  @override
  String get ytdlAddToLibrary => 'Add to library';

  @override
  String get ytdlAddHere => 'Add here';

  @override
  String get ytdlAddAnyway => 'Add anyway';

  @override
  String get ytdlAlreadyAdding => 'Already adding to this folder';

  @override
  String get ytdlFormatMenuTitle => 'Best audio the video has, saved as';

  @override
  String ytdlFormatRemembered(String server) {
    return 'Remembered for $server';
  }

  @override
  String get ytdlFormatMp3Help => 'Plays everywhere';

  @override
  String get ytdlFormatM4aHelp => 'Good for Apple devices';

  @override
  String get ytdlFormatOpusHelp => 'Usually YouTube\'s own audio, no re-encode';

  @override
  String get ytdlFormatFlacHelp => 'Bigger, not better than the video\'s sound';

  @override
  String get ytdlFormatWavHelp => 'Biggest, no cover art';

  @override
  String get ytdlErrFfmpeg =>
      'The server can\'t convert audio right now. Try again later, or ask its admin.';

  @override
  String get ytdlErrUploadsOff =>
      'Your account can\'t add files to this server.';

  @override
  String ytdlErrLibraryGone(String library) {
    return 'You can\'t add files to “$library” any more. Pick another library.';
  }

  @override
  String ytdlErrLibraryGoneSheet(String library) {
    return 'You can\'t add files to “$library” any more.';
  }

  @override
  String get ytdlErrNoRoute => 'This server doesn\'t offer YouTube downloads.';

  @override
  String ytdlErrFormatOff(String format) {
    return 'This server doesn\'t save $format any more';
  }

  @override
  String get ytdlErrPickAnother => 'pick another';

  @override
  String get ytdlErrBadRequest =>
      'Something about this link didn\'t suit the server. Try again.';

  @override
  String get ytdlErrServer => 'Something went wrong on the server.';

  @override
  String ytdlErrOther(String message) {
    return 'The server said: “$message”';
  }

  @override
  String ytdlErrMkdir(String folder) {
    return 'Couldn\'t make the folder “$folder”.';
  }

  @override
  String get ytdlSectionAdding => 'Adding';

  @override
  String get ytdlSectionAddingNote =>
      'Runs on the server · can\'t be stopped from the app';

  @override
  String get ytdlSectionNeedsLook => 'Needs a look';

  @override
  String get ytdlSectionAdded => 'Added';

  @override
  String ytdlRowAdding(int minutes, String format) {
    String _temp0 = intl.Intl.pluralLogic(
      minutes,
      locale: localeName,
      other: 'Adding · $minutes min · $format',
    );
    return '$_temp0';
  }

  @override
  String get ytdlRowStartUnsure => 'Starting… the server hasn\'t answered yet';

  @override
  String get ytdlRowNotSureStarted => 'Not sure it started';

  @override
  String get ytdlRowNotFound => 'Not found on the server';

  @override
  String get ytdlRowClash =>
      'Failed · a file with this name looks to be there already. Nothing was replaced.';

  @override
  String get ytdlRowFailed =>
      'Failed · the server didn\'t say why. Common causes: a live stream, YouTube refusing the server, 500 MB, or an hour.';

  @override
  String get ytdlRowFailedOlder =>
      'Failed · the server didn\'t say why. YouTube may have refused the server.';

  @override
  String get ytdlRowNotSureFinished =>
      'Not sure it finished · it ended while the app was away and the server has no record of it';

  @override
  String get ytdlRowWaiting => 'Waiting for connection';

  @override
  String get ytdlRowFileMissing => 'File missing';

  @override
  String get ytdlRowHide => 'Hide from this list';

  @override
  String get ytdlRowChangeFormatRetry => 'Change format and retry';

  @override
  String get ytdlRowShowFolder => 'Show folder';

  @override
  String get ytdlRowShowInFolder => 'Show in folder';

  @override
  String get ytdlShowEarlier => 'Show earlier';

  @override
  String get ytdlWhereTitle => 'Where new songs land';

  @override
  String ytdlWhereSub(String server) {
    return 'Kept on this phone for $server · Discover copies keep their own setting.';
  }

  @override
  String ytdlWhereLandsAt(String title) {
    return '“$title” lands at';
  }

  @override
  String get ytdlWhereLandsAtSample => 'A song lands at';

  @override
  String get ytdlWhereSampleNote =>
      'Shown with sample words until you paste a link.';

  @override
  String ytdlWhereFileNote(String title) {
    return 'The file name comes from the video title; your library shows “$title”.';
  }

  @override
  String ytdlWhereAlwaysEmpty(String vars) {
    return 'Always empty for YouTube songs, so left out: $vars';
  }

  @override
  String get ytdlWhereSetByDiscover => 'Set by Discover';

  @override
  String get ytdlLayoutTop => 'Top of the library';

  @override
  String get ytdlLayoutTopSub => 'No folders';

  @override
  String get ytdlLayoutDiscover => 'Same as Discover';

  @override
  String get ytdlWhereUseForSong => 'Use for this song';

  @override
  String get ytdlWhereNoMkdir =>
      'Your account can\'t make folders, so only folders that already exist work. Top of the library always does.';

  @override
  String get ytdlCustomHelp =>
      'Use / between folders. There\'s no TITLE — the file name always comes from the video title.';

  @override
  String ytdlErrNeverVar(String name, String vars) {
    return '$name is always empty for YouTube songs. Use $vars.';
  }

  @override
  String get ytdlErrBadChars =>
      'A folder name can\'t contain : * ? \" < > or |.';

  @override
  String ytdlTrapEmpty(String folder) {
    return 'Nothing to fill this folder, so it\'s named “$folder”. Add an album and year, or pick another layout.';
  }

  @override
  String ytdlTrapNoYear(String folder) {
    return 'No year for this song, so the folder reads “$folder”. The file still gets YouTube\'s upload year as its tag.';
  }

  @override
  String ytdlTrapOther(String folder) {
    return 'A tag is empty, so the folder reads “$folder”. Fill in the tags, or pick another layout.';
  }

  @override
  String get ytdlTrapAddYear => 'Add a year';

  @override
  String ytdlNoMkdirNew(String folder) {
    return '“$folder” doesn\'t exist yet and your account can\'t make folders.';
  }

  @override
  String get ytdlNoMkdirUnchecked =>
      'Your account can\'t make folders and this folder couldn\'t be checked.';

  @override
  String ytdlSaveToInstead(String path) {
    return 'Save to $path instead';
  }

  @override
  String get ytdlChooseFolderLink => 'Choose a folder…';

  @override
  String get ytdlChooseTitle => 'Choose a folder';

  @override
  String get ytdlChooseSub =>
      'Your account can\'t make folders, so pick one that already exists.';

  @override
  String get ytdlChooseEmpty => 'No folders here.';

  @override
  String get ytdlExplorerEntry => 'Add from YouTube here';

  @override
  String ytdlSheetInto(String path) {
    return 'Into $path';
  }

  @override
  String get ytdlSortSubfolders => 'Sort into subfolders…';

  @override
  String get ytdlSubfoldersTitle => 'Sort into subfolders';

  @override
  String get ytdlSubfoldersHere => 'The folder you\'re in';

  @override
  String get ytdlSubfoldersRightHere => 'Right here';

  @override
  String get ytdlSubfoldersNone => 'No subfolders';

  @override
  String ytdlSubfoldersNew(int count, String folders) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count new folders will be made: $folders',
      one: '$count new folder will be made: $folders',
    );
    return '$_temp0';
  }

  @override
  String ytdlStripAdding(String title) {
    return 'Adding “$title”…';
  }

  @override
  String ytdlStripAddingCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Adding $count videos…',
      one: 'Adding $count video…',
    );
    return '$_temp0';
  }

  @override
  String get ytdlStripSeeAll => 'See all';

  @override
  String get ytdlStripDetails => 'Details';

  @override
  String ytdlToastAdded(String title, String path) {
    return 'Added “$title” to $path';
  }

  @override
  String ytdlCouldntAdd(String title) {
    return 'Couldn\'t add “$title”';
  }

  @override
  String ytdlToastSaved(String path) {
    return 'Saved · new songs land in $path';
  }

  @override
  String get ytdlToastHidden => 'Hidden. The server keeps going.';

  @override
  String get ytdlA11yLinkField => 'YouTube link';

  @override
  String get ytdlA11yClearLink => 'Clear link';

  @override
  String ytdlA11yFormat(String format) {
    return 'Format, $format';
  }

  @override
  String ytdlA11yPutBack(String fragment) {
    return 'Put back $fragment';
  }

  @override
  String get ytdlA11yUndoSplit => 'Undo the split at the dash';

  @override
  String get ytdlA11yUndoSplitColon => 'Undo the split at the colon';

  @override
  String ytdlA11yMoreFor(String title) {
    return 'More for $title';
  }

  @override
  String get ytdlA11yAdding => 'Adding';

  @override
  String get ytdlA11yNewFolder => 'a new folder';

  @override
  String ytdlCrumbThen(String previous, String next) {
    return '$previous, then $next';
  }

  @override
  String ytdlCrumbNew(String folder) {
    return '$folder, a new folder';
  }

  @override
  String ytdlCrumbFile(String path, String file) {
    return '$path, file $file';
  }

  @override
  String get ytdlCrumbEmptyBrackets => 'empty brackets';

  @override
  String ytdlCrumbWithEmptyBrackets(String folder) {
    return '$folder with empty brackets';
  }

  @override
  String ytdlA11yVarUsed(String name) {
    return '$name, used';
  }

  @override
  String get ytdlA11yInsertVariable => 'Insert a variable';

  @override
  String get ytdlA11yLocked => 'Locked';

  @override
  String get ytdlA11yFolderPath => 'Folder path';

  @override
  String ytdlA11yUpTo(String folder) {
    return 'Up to $folder';
  }

  @override
  String get ytdlA11yCover => 'Cover';

  @override
  String ytdlSummaryBy(String title, String artist) {
    return '$title, by $artist';
  }

  @override
  String ytdlSummaryAlbum(String album) {
    return 'album $album';
  }

  @override
  String get ytdlSummaryNoAlbum => 'no album';

  @override
  String ytdlSummary(String details, String source, String path) {
    return '$details. $source. Saves to $path.';
  }

  @override
  String get ytdlErrAddOffline =>
      'You\'re offline — try again when you\'re back.';

  @override
  String get ytdlHelpVideoRelease => 'From the video\'s release date';
}
