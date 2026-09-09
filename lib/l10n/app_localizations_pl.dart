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
  String get settingsLanguageSubtitle =>
      'Język wyświetlania aplikacji. „Domyślny systemu” podąża za ustawieniem urządzenia.';

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
  String get themeGraphite => 'Grafit';

  @override
  String get themeOnyx => 'Onyks';

  @override
  String get tapAddToQueue => 'Dodaj do kolejki';

  @override
  String get tapPlayFromHere => 'Odtwarzaj od tego miejsca';

  @override
  String get tapAppendAndJump => 'Dodaj i odtwórz';

  @override
  String get visualizerEngineMilkdrop => 'Milkdrop';

  @override
  String get visualizerEngineShaders => 'Shadery';

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
  String get lyricsTitle => 'Lyrics';

  @override
  String get lyricsEmpty => 'No lyrics found for this song';

  @override
  String get lyricsError => 'Couldn\'t load lyrics';

  @override
  String get lyricsRetry => 'Retry';

  @override
  String get eqTitle => 'Korektor';

  @override
  String get eqOnlyAndroid => 'Korektor jest dostępny tylko na Androidzie.';

  @override
  String get eqNeedsPlayback =>
      'Rozpocznij odtwarzanie utworu, aby skonfigurować korektor.\n\nNatywny korektor Androida inicjuje się wraz z sesją audio, dlatego do odczytania układu pasm potrzebne jest aktywne odtwarzanie.';

  @override
  String eqInitFailed(String error) {
    return 'Nie można zainicjować korektora:\n$error';
  }

  @override
  String get eqNoBands =>
      'Sterownik audio tego urządzenia nie zgłasza żadnych pasm korektora.';

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
  String get settingsSectionBrowse => 'Przeglądanie';

  @override
  String get settingsSectionAbout => 'O aplikacji';

  @override
  String get settingsTheme => 'Motyw';

  @override
  String get themeSubtitleVelvet =>
      'Granat i fiolet — charakterystyczny ciemny motyw.';

  @override
  String get themeSubtitleDark => 'Neutralny ciemny z bursztynowymi akcentami.';

  @override
  String get themeSubtitleLight =>
      'Jasne tło z ciemnym paskiem aplikacji i bursztynowymi akcentami — zgodny ze starszym, fabrycznym motywem.';

  @override
  String get themeSubtitleGraphite =>
      'Neutralne szarości z bursztynową linią akcentową.';

  @override
  String get themeSubtitleOnyx =>
      'Niebiesko-szare odcienie Łupka pod czarnym górnym paskiem, z bursztynową linią akcentową.';

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
      'Ten serwer nie ma włączonej transkodyzacji — jego utwory są przesyłane w oryginalnej jakości.';

  @override
  String get transcodeReloadQueue => 'Zastosuj do bieżącej kolejki';

  @override
  String get transcodeReloadQueueSubtitle =>
      'Gdy zmienisz ustawienia transkodyzacji — zaznaczone: przeładuj całą kolejkę teraz (odtwarzany utwór na chwilę się buforuje); odznaczone: zmieniają się tylko kolejne utwory, bieżący kończy się bez zmian.';

  @override
  String get settingsTapBehavior => 'Po dotknięciu utworu';

  @override
  String get settingsStartupPage => 'Ekran startowy';

  @override
  String get settingsStartupPageSubtitle =>
      'Otwórz aplikację w tym widoku przeglądarki; Wstecz wraca do przeglądarki.';

  @override
  String get tapSubtitleAddToQueue =>
      'Dotknięcie utworu dodaje go na koniec kolejki. Jeśli kolejka jest pusta, odtwarzanie rozpoczyna się automatycznie.';

  @override
  String get tapSubtitlePlayFromHere =>
      'Dotknięcie utworu zastępuje kolejkę utworami z bieżącego widoku i rozpoczyna odtwarzanie od dotkniętego utworu.';

  @override
  String get tapSubtitleAppendAndJump =>
      'Dotknięcie utworu dodaje go do kolejki i przeskakuje do niego odtwarzanie, przerywając to, co było odtwarzane.';

  @override
  String get settingsEqSubtitle =>
      'Dostrój basy, średnie i wysokie tony. Tylko na Androidzie.';

  @override
  String get settingsVisualizerEngine => 'Silnik wizualizatora';

  @override
  String get visualizerEngineSubtitleMilkdrop =>
      'Presety Milkdrop przez projectM (domyślnie). Bogatsze efekty, większe obciążenie GPU.';

  @override
  String get visualizerEngineSubtitleShaders =>
      'Shadery fragmentów w stylu Shadertoy. Lżejsze, modułowe — umieść pliki .glsl w assets/shaders/, aby rozszerzyć katalog.';

  @override
  String get settingsVisualizerSource => 'Źródło dźwięku wizualizatora';

  @override
  String get visualizerSourceSubtitleSynthesized =>
      'Domyślnie. Wizualizator reaguje tylko na taktowanie odtwarzania — nie wymaga uprawnienia do mikrofonu.';

  @override
  String get visualizerSourceSubtitleReal =>
      'Wizualizator reaguje na rzeczywiste wyjście dźwięku. Wymaga uprawnienia RECORD_AUDIO na Androidzie.';

  @override
  String get settingsAlbumGrid => 'Widok siatki albumów';

  @override
  String get settingsAlbumGridSubtitle =>
      'Pokazuj albumy jako siatkę kart z okładkami zamiast zwykłej listy.';

  @override
  String get settingsFileMetadata =>
      'Odczytuj metadane utworów w eksploratorze plików';

  @override
  String get settingsFileMetadataSubtitle =>
      'Pobieraj tytuł, wykonawcę i okładkę dla każdego utworu podczas przeglądania plików serwera. Wyłączenie pokazuje surowe nazwy plików (szybsze przy dużych folderach).';

  @override
  String get settingsLetterStrip => 'Próg paska liter';

  @override
  String get settingsLetterStripSubtitle =>
      'Pokazuj pasek szybkiego przewijania A–Z, gdy lista ma tyle elementów lub więcej. Poniżej tego rozmiaru pasek jest ukryty, a długie nazwy folderów/plików zawijają się do wielu wierszy zamiast być obcinane. Ustaw 0, aby zawsze pokazywać pasek.';

  @override
  String get settingsLetterStripSide => 'Strona paska';

  @override
  String get settingsLetterStripSideSubtitle =>
      'Przy której krawędzi znajduje się pasek A–Z.';

  @override
  String get settingsLetterStripLeft => 'Lewa';

  @override
  String get settingsLetterStripRight => 'Prawa';

  @override
  String get settingsReset => 'Przywróć ustawienia domyślne';

  @override
  String get settingsResetSubtitle =>
      'Przywróć wszystkie ustawienia na tym ekranie do wartości domyślnych. Nie wpływa to na serwery ani pobrane pliki.';

  @override
  String get settingsResetDone => 'Przywrócono ustawienia domyślne';

  @override
  String get realAudioDialogTitle => 'Użyć rzeczywistego dźwięku?';

  @override
  String get realAudioDialogBody =>
      'Tryb rzeczywistego dźwięku odczytuje przebieg muzyki odtwarzanej przez telefon, aby wizualizator mógł na niego reagować. Android wymaga do tego uprawnienia RECORD_AUDIO — aplikacja nie nagrywa ani nigdzie nie wysyła żadnego dźwięku. W każdej chwili możesz wrócić do dźwięku syntetycznego.';

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
    return 'Serwera „$name” nie ma już na Twojej liście serwerów. Dodaj go ponownie, aby udostępnić jego kolejkę.';
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
  String get fieldPasswordShow => 'Show password';

  @override
  String get fieldPasswordHide => 'Hide password';

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
  String get autoDjAddServerFirst => 'Najpierw dodaj serwer.';

  @override
  String get autoDjSectionServer => 'Serwer';

  @override
  String get autoDjSectionSources => 'Źródła';

  @override
  String get autoDjSectionContinuity => 'Ciągłość';

  @override
  String get autoDjSectionFilters => 'Filtry';

  @override
  String get autoDjMultiServerTitle => 'Odtwarzaj ze wszystkich serwerów';

  @override
  String get autoDjMultiServerSubtitle =>
      'Auto DJ wybiera ze wszystkich serwerów naraz, dopasowując się do brzmienia';

  @override
  String get autoDjMultiServerNeedsSonic =>
      'Wymaga włączenia Podobieństwa brzmienia poniżej';

  @override
  String get autoDjSectionShared => 'Sesja';

  @override
  String get autoDjSectionPerServer => 'Każda biblioteka';

  @override
  String get autoDjEditingServer => 'Ustawienia dla';

  @override
  String autoDjMultiServerAllIn(int count) {
    return 'Uczestniczy $count serwerów';
  }

  @override
  String autoDjMultiServerConnecting(int count) {
    return '$count wciąż się łączy';
  }

  @override
  String autoDjMultiServerSomeExcluded(int count, int total) {
    return 'Uczestniczy $count z $total serwerów — pozostałym brakuje discovery, zgodnego modelu osadzeń lub dostatecznie nowej wersji serwera';
  }

  @override
  String get autoDjSectionQueue => 'Kolejka';

  @override
  String get autoDjSongsPerFetchTitle => 'Utwory na jedno pobranie';

  @override
  String get autoDjSongsPerFetchSubtitle =>
      'Ile utworów Auto DJ dodaje do kolejki przy każdym uruchomieniu. Filtry ciągłości oceniają całą partię względem utworu granego w chwili pobrania.';

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
  String get autoDjBpmTitle => 'Ciągłość BPM';

  @override
  String get autoDjBpmSubtitle =>
      'Preferuj wybory w zakresie tempa bieżącego utworu. Uwzględnia równoważność połowy/podwojonego tempa.';

  @override
  String get autoDjTolerance => 'Tolerancja';

  @override
  String autoDjBpmTolerance(int bpm) {
    return '± $bpm BPM';
  }

  @override
  String get autoDjHarmonicTitle => 'Miksowanie harmoniczne';

  @override
  String get autoDjHarmonicSubtitle =>
      'Preferuj wybory w tonacjach dobrze pasujących do zablokowanego utworu (sąsiedzi na kole Camelota).';

  @override
  String get autoDjDurationTitle => 'Długość utworu';

  @override
  String get autoDjDurationSubtitle =>
      'Pomija interludia i długie miksy, wybierając tylko utwory o określonej długości';

  @override
  String get autoDjDurationRange => 'Długość';

  @override
  String get autoDjDurationAny => 'Dowolna długość';

  @override
  String autoDjDurationOver(String min) {
    return 'Powyżej $min';
  }

  @override
  String autoDjDurationUnder(String max) {
    return 'Poniżej $max';
  }

  @override
  String autoDjDurationBetween(String min, String max) {
    return 'Od $min do $max';
  }

  @override
  String get autoDjDurationAllowUnknown =>
      'Uwzględnij utwory o nieznanej długości';

  @override
  String get autoDjDurationAllowUnknownSub =>
      'Utwory, których długości serwer nie odczytał, są w przeciwnym razie pomijane';

  @override
  String get autoDjStatusOn => 'Auto DJ jest włączony';

  @override
  String get autoDjStatusOff => 'Auto DJ jest wyłączony';

  @override
  String get autoDjStatusOffDetail =>
      'Dotknij poniżej, aby rozpocząć. Zostanie użyta biblioteka bieżącego serwera.';

  @override
  String get autoDjStart => 'Uruchom Auto DJ';

  @override
  String get autoDjStop => 'Zatrzymaj Auto DJ';

  @override
  String autoDjStatusOnDetail(String url) {
    return 'Utwory są wybierane z $url, gdy kolejka się wyczerpuje.';
  }

  @override
  String get autoDjOneSourceRequired =>
      'Wymagane jest co najmniej jedno źródło.';

  @override
  String get autoDjMinRating => 'Minimalna ocena';

  @override
  String get autoDjMinRatingSubtitle =>
      'Wybieraj tylko utwory z tą oceną lub wyższą.';

  @override
  String get autoDjRatingAny => 'Dowolna';

  @override
  String get autoDjGenreTitle => 'Filtr gatunków';

  @override
  String get autoDjGenreSubtitle =>
      'Biała lista odtwarza tylko pasujące utwory; czarna lista je pomija.';

  @override
  String get autoDjWhitelist => 'Biała lista';

  @override
  String get autoDjBlacklist => 'Czarna lista';

  @override
  String get autoDjNoGenres =>
      'Nie wybrano gatunków. Dotknij „Wybierz gatunki”, aby wybrać.';

  @override
  String get autoDjPickGenres => 'Wybierz gatunki';

  @override
  String get autoDjGenreLoadError => 'Nie można wczytać gatunków';

  @override
  String get autoDjKeywordTitle => 'Filtr słów kluczowych';

  @override
  String get autoDjKeywordSubtitle =>
      'Pomijaj wybory, których tytuł, wykonawca, album lub ścieżka pliku zawiera którekolwiek z tych słów.';

  @override
  String get autoDjNoKeywords =>
      'Brak słów kluczowych. Dodaj słowa poniżej, aby rozpocząć filtrowanie.';

  @override
  String get autoDjKeywordHint => 'np. „live” lub „remix”';

  @override
  String get autoDjSearchGenres => 'Szukaj gatunków…';

  @override
  String get autoDjNoGenresOnServer =>
      'Nie znaleziono gatunków na tym serwerze.';

  @override
  String autoDjSelectedCount(int count) {
    return 'Wybrano: $count';
  }

  @override
  String autoDjNoGenresMatch(String query) {
    return 'Żaden gatunek nie pasuje do „$query”.';
  }

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
  String get searchCategoriesTooltip => 'What to search';

  @override
  String get searchCategoriesHeader => 'Search in';

  @override
  String get searchCategoryArtists => 'Artists';

  @override
  String get searchCategoryAlbums => 'Albums';

  @override
  String get searchCategorySongs => 'Songs';

  @override
  String get searchCategoryFiles => 'Files';

  @override
  String get searchCategoryLyrics => 'Lyrics';

  @override
  String searchSubheaderResults(String term) {
    return 'Results for “$term”';
  }

  @override
  String searchSubheaderCategories(String categories) {
    return 'Searching: $categories';
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
  String get visualizerTitle => 'Wizualizator';

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
  String get settingsVisualizerKnobs => 'Pokrętła strojenia wizualizatora';

  @override
  String get settingsVisualizerKnobsSubtitle =>
      'Pokazuj na żywo suwaki nad wizualizatorem, aby dostrajać reaktywność audio każdego shadera. Tylko silnik shaderów.';

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
  String get settingsCastQuality => 'Jakość wizualizatora przy przesyłaniu';

  @override
  String get settingsCastQualitySubtitle720 =>
      'Rozdzielczość, w jakiej wizualizator jest przesyłany do telewizora. 720p — najlżejsza dla telefonu.';

  @override
  String get settingsCastQualitySubtitle1080 =>
      'Rozdzielczość, w jakiej wizualizator jest przesyłany do telewizora. 1080p — ostra na każdym Chromecaście (domyślna).';

  @override
  String get settingsCastQualitySubtitle4k =>
      'Rozdzielczość, w jakiej wizualizator jest przesyłany do telewizora. 4K — wymaga Chromecasta 4K; znacznie większe obciążenie telefonu.';

  @override
  String get eqCasting =>
      'Korektor reguluje dźwięk na tym urządzeniu, więc jest niedostępny podczas przesyłania. Rozłącz, aby go użyć.';

  @override
  String get browserNothingToDownload =>
      'Brak czegokolwiek do pobrania na tej liście';

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
  String get browserEmptyList => 'Nothing here yet';

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
  String get storageAppLocal => 'Lokalna aplikacji';

  @override
  String get storagePermanent => 'Trwała';

  @override
  String get storageSdCard => 'Karta SD';

  @override
  String get storageSdSwitchTitle => 'Save to SD card';

  @override
  String get storageSdSwitchSubtitle =>
      'Stored in the SD card\'s app folder — no permission needed, but removed if you uninstall the app.';

  @override
  String get storageHelpAppLocal =>
      'Zapisywane wewnątrz aplikacji. Usuwane po odinstalowaniu lub wyczyszczeniu aplikacji.';

  @override
  String get storageHelpPermanent =>
      'Zapisywane w wybranym folderze. Zachowywane po odinstalowaniu aplikacji. Wymaga uprawnienia „Dostęp do wszystkich plików”.';

  @override
  String get storageHelpSdCard =>
      'Zapisywane w wybranym folderze na karcie SD. Może stać się niedostępne po wyjęciu karty. Niektóre urządzenia nie pozwalają aplikacjom zapisywać na kartach SD — jeśli wybór folderu wciąż się nie udaje, użyj opcji Trwała lub Lokalna aplikacji.';

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
  String get storageNoSubfolders => 'Brak podfolderów tutaj';

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
          'Tych $count pobranych plików serwera ($size) znajduje się na innym woluminie pamięci niż nowa lokalizacja. Wybierz, co zrobić:',
      many:
          'Tych $count pobranych plików serwera ($size) znajduje się na innym woluminie pamięci niż nowa lokalizacja. Wybierz, co zrobić:',
      few:
          'Te $count pobrane pliki serwera ($size) znajdują się na innym woluminie pamięci niż nowa lokalizacja. Wybierz, co zrobić:',
      one:
          'Ten 1 pobrany plik serwera ($size) znajduje się na innym woluminie pamięci niż nowa lokalizacja. Wybierz, co zrobić:',
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
      'Najpierw wybierz folder na karcie SD. Jeśli każdy folder jest odrzucany, Twoje urządzenie może nie pozwalać aplikacjom na zapis na karcie — użyj zamiast tego opcji Trwała lub Lokalna aplikacji.';

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
  String get castVisualizerSubtitle =>
      'Przesyłaj wizualizator do telewizora · tylko Chromecast';

  @override
  String get visualizerNoKnobs => 'Ten shader nie udostępnia żadnych pokręteł.';

  @override
  String get nowPlaying => 'Teraz odtwarzane';

  @override
  String get playerLayoutSmall => 'Mały';

  @override
  String get playerLayoutMedium => 'Średni';

  @override
  String get playerLayoutLarge => 'Duży';

  @override
  String get playerLayoutXl => 'XL';

  @override
  String get playerLayoutSmallDesc => 'Wąski pasek — maksymalna kolejka';

  @override
  String get playerLayoutMediumDesc => 'Baner — zrównoważony (domyślny)';

  @override
  String get playerLayoutLargeDesc => 'Kompaktowy — wyśrodkowana okładka';

  @override
  String get playerLayoutXlDesc => 'Wyróżniony — pełna okładka';

  @override
  String get queueNothingToDownloadEmpty =>
      'Kolejka jest pusta — nie ma czego pobrać';

  @override
  String get queueNothingToDownloadSaved =>
      'Nie ma czego pobrać — utwory są już zapisane';

  @override
  String get settingsAccentColor => 'Kolor akcentu';

  @override
  String get settingsAccentColorSubtitle =>
      'Kolor wyróżnienia używany w całej aplikacji.';

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
      'Quick Connect jest włączony na tym serwerze, ale nie udostępniono kodu parowania. Zaloguj się jako administrator lub poproś operatora o włączenie udostępniania kodu.';

  @override
  String get settingsResumeQueue => 'Wznów kolejkę po uruchomieniu';

  @override
  String get settingsResumeQueueSubtitle =>
      'Zapisuje kolejkę odtwarzania i pozycję oraz przywraca je po ponownym otwarciu aplikacji.';

  @override
  String get settingsOfflineQueue => 'Zachowaj kolejkę dostępną offline';

  @override
  String get settingsOfflineQueueSubtitle =>
      'Automatycznie pobiera utwory z kolejki na to urządzenie, aby odtwarzanie przetrwało utratę połączenia.';

  @override
  String get settingsOfflineQueueWifiOnly => 'Pobieraj tylko przez Wi-Fi';

  @override
  String get settingsOfflineQueueWifiOnlySubtitle =>
      'Czeka na połączenie Wi-Fi przed pobraniem utworów z kolejki.';

  @override
  String get settingsAutoDownloadCap => 'Auto-download limit';

  @override
  String get settingsAutoDownloadCapSubtitle =>
      'Zachowuje tyle utworów od aktualnie odtwarzanego; te, które zostają z tyłu, są usuwane.';

  @override
  String get settingsAutoDownloadCapSubtitleUnlimited =>
      'Zachowuje całą kolejkę (bez limitu).';

  @override
  String get settingsAutoDownloadCapUnlimited => 'Unlimited';

  @override
  String get settingsAutoDownloadCapField => 'Number of tracks';

  @override
  String get settingsAutoDownloadCapDialogBody =>
      'Ile utworów z kolejki pozostaje pobranych, licząc od aktualnie odtwarzanego. W miarę odtwarzania te, które zostają z tyłu, są usuwane. 0 = cała kolejka.';

  @override
  String get downloadWaitingWifi => 'Oczekiwanie na Wi-Fi';

  @override
  String get settingsRatingHalf => 'Oceny w połówkach gwiazdek';

  @override
  String get settingsRatingHalfSubtitle =>
      'Oceniaj utwory w krokach co pół gwiazdki (przytrzymaj gwiazdkę).';

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
      'Dzienniki pozostają na Twoim urządzeniu. Tokeny są ukrywane przed skopiowaniem lub udostępnieniem.';

  @override
  String get diagnosticsVerbose => 'Verbose logging';

  @override
  String get diagnosticsVerboseHint =>
      'Also logs high-frequency events like app focus changes. Only needed when diagnosing a playback issue.';

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
  String get importedShadersSettingsSubtitle =>
      'Dodaj własne pliki .glsl do rotacji silnika Shader.';

  @override
  String get importedShadersRescan => 'Przeskanuj folder ponownie';

  @override
  String get importedShadersDropHint =>
      'Umieść pliki .glsl w tym folderze, a następnie przeskanuj ponownie:';

  @override
  String get importedShadersCopyPath => 'Kopiuj ścieżkę';

  @override
  String get importedShadersReachableHint =>
      'Dostępny przez USB lub menedżer plików (w Android/data). Zaimportowane shadery dołączają do rotacji, gdy aktywny jest silnik Shader.';

  @override
  String get importedShadersRemove => 'Usuń';

  @override
  String get importedShadersEmptyTitle => 'Brak shaderów w folderze';

  @override
  String get importedShadersEmptyBody =>
      'Skopiuj pliki .glsl w stylu Shadertoy do powyższego folderu, a następnie dotknij Przeskanuj ponownie.';

  @override
  String get importedShadersInvalid =>
      'Może nie być prawidłowym shaderem — brak punktu wejścia mainImage/main.';

  @override
  String get importedShadersImportDownloads => 'Import .glsl from Downloads';

  @override
  String importedShadersDownloadsImported(int count) {
    return 'Imported $count shader(s) from Downloads';
  }

  @override
  String get importedShadersDownloadsNone => 'No new .glsl files in Downloads';

  @override
  String get importedShadersDownloadsNoPermission =>
      'Storage permission is needed to read Downloads';

  @override
  String get addServerTabUrl => 'Server URL';

  @override
  String get addServerTabQuickConnect => 'Quick Connect';

  @override
  String get irohPairingHeader => 'Connect with a pairing code';

  @override
  String get irohPairingBody =>
      'Enable Remote Access on the server, then paste its pairing code or scan the QR.';

  @override
  String get irohPairingCodeLabel => 'Pairing code';

  @override
  String get irohPairingCodeHint =>
      'Paste the code from the server Remote Access panel';

  @override
  String get irohShowPairingCode => 'Show pairing code';

  @override
  String get irohQrBody =>
      'Scan with the mStream app on another device to connect it to this server, or copy the code and paste it there.';

  @override
  String get irohQrCaution =>
      'Anyone with this code can connect to your server.';

  @override
  String get irohScanQr => 'Scan QR';

  @override
  String get irohPaste => 'Paste';

  @override
  String get irohTestConnection => 'Test connection';

  @override
  String get irohTesting => 'Testing…';

  @override
  String get irohScannerTitle => 'Scan pairing QR';

  @override
  String get irohQrAndroidOnly =>
      'QR scanning isn\'t available on this device.';

  @override
  String get irohAndroidOnly =>
      'Quick Connect isn\'t available on this device.';

  @override
  String get irohCameraPermission =>
      'Camera permission is needed to scan a code.';

  @override
  String get irohPasteFirst => 'Paste or scan a pairing code first.';

  @override
  String get irohTestFirst => 'Test the connection first.';

  @override
  String get irohTestConnected => 'Connected through the iroh tunnel';

  @override
  String irohTestConnectedVersion(String version) {
    return 'Connected through the iroh tunnel — mStream v$version';
  }

  @override
  String get irohPathSuffixDirect => ' · direct';

  @override
  String get irohPathSuffixRelay => ' · via relay';

  @override
  String get irohTunnelTimeout =>
      'Tunnel opened but the server did not respond in time.';

  @override
  String irohTunnelTestFailed(String error) {
    return 'Tunnel test failed: $error';
  }

  @override
  String get irohSignInHeader => 'Sign in';

  @override
  String get irohSigningIn => 'Signing in…';

  @override
  String get irohSignInSave => 'Sign in & save';

  @override
  String get irohSignInTimeout => 'Sign-in timed out.';

  @override
  String irohSignInFailed(String error) {
    return 'Sign-in failed: $error';
  }

  @override
  String irohSignInFailedHttp(int status) {
    return 'Sign-in failed (HTTP $status). Check your username and password.';
  }

  @override
  String get irohBannerConnecting => 'Connecting to server…';

  @override
  String get irohBannerReconnecting => 'Reconnecting to server…';

  @override
  String get irohBannerDisconnected => 'Disconnected from server.';

  @override
  String get irohBannerRelay => 'Connected via relay — slower path.';

  @override
  String get irohBannerRepair =>
      'Server pairing changed — re-pair to reconnect.';

  @override
  String get irohRepairAction => 'Re-pair';

  @override
  String get irohRetry => 'Retry';

  @override
  String get irohRepairTitle => 'Re-pair server';

  @override
  String get irohRepairBody =>
      'This server\'s pairing code changed (its secret was rotated). Paste or scan the new code from the server\'s Remote Access panel.';

  @override
  String get irohRepairFailed =>
      'Couldn\'t connect with that code — check it and try again.';

  @override
  String get irohPathDirect => 'Direct';

  @override
  String get irohPathRelay => 'Relay';

  @override
  String get irohCastUnavailable =>
      'Casting to external devices isn\'t available for peer-to-peer (iroh) servers — playback stays on this device.';

  @override
  String get irohShareUnavailable =>
      'Sharing isn\'t available for peer-to-peer (iroh) servers — they have no public URL to link to.';

  @override
  String get discoverTitle => 'Odkrywaj';

  @override
  String get discoverMatchedBySound => 'Dopasowane brzmieniem';

  @override
  String get discoverSimilarTracks => 'Podobne utwory';

  @override
  String get discoverSimilarArtists => 'Podobni artyści';

  @override
  String get discoverFromNetwork => 'Z sieci';

  @override
  String get discoverFromPeers => 'Od twoich peerów';

  @override
  String get discoverQueueAll => 'Dodaj wszystko do kolejki';

  @override
  String get discoverNewArtistsOnly => 'Tylko nowi artyści';

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
      'Brak danych z sieci — biblioteki peerów pobierają się w tle, gdy tylko zostaną wykryte inne serwery.';

  @override
  String get discoverNetworkNothingNew =>
      'Nic nowego dla tego utworu — sieć nie ma nieznanych dopasowań.';

  @override
  String get discoverPeersUnreachable =>
      'Twoje peery nie odpowiedziały — mogą być teraz offline.';

  @override
  String get discoverPeersNothingNew =>
      'Nic nowego dla tego utworu na serwerach twoich peerów.';

  @override
  String get autoDjSonicTitle => 'Podobieństwo brzmienia';

  @override
  String get autoDjSonicSubtitle =>
      'Wybiera tylko utwory brzmiące jak sesja, na podstawie analizy dźwięku na serwerze.';

  @override
  String get autoDjSonicUnavailable =>
      'Ten serwer nie ma danych odkrywania — wybór pozostaje losowy.';

  @override
  String get autoDjSonicNotReady =>
      'Odkrywanie jest włączone, ale skan nie dostarczył jeszcze danych — do tego czasu wybór pozostaje losowy.';

  @override
  String get autoDjSonicStrictness => 'Próg podobieństwa';

  @override
  String autoDjSonicStrictnessValue(int pct) {
    return '$pct% lub bliżej';
  }

  @override
  String get autoDjSonicSeedLabel => 'Utwór startowy';

  @override
  String get autoDjSonicSeedNone =>
      'Brak utworu startowego — sesję zakotwicza odtwarzany utwór.';

  @override
  String get autoDjSonicSeedBanner =>
      'Wybierz utwór startowy — stuknij dowolny utwór w bibliotece';

  @override
  String get autoDjSonicSeedSearchHint => 'Szukaj utworu…';

  @override
  String get autoDjSonicSeedRandom => 'Losowy utwór';

  @override
  String get autoDjSonicSeedRemove => 'Usuń utwór startowy';

  @override
  String get autoDjSonicSeedFailed => 'Nie udało się pobrać utworu z serwera.';

  @override
  String get autoDjSeedNoMatch =>
      'Żaden utwór nie pasuje do filtrów Auto DJ — spróbuj je poluzować';

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
  String get autoDjSonicAnchorLabel => 'Kotwica';

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
  String get pathScreenTitle => 'Ścieżka dźwiękowa';

  @override
  String get pathStartNotAnalyzed =>
      'Utwór startowy nie został jeszcze przeanalizowany — poczekaj na skan odkrywania lub wybierz inny.';

  @override
  String get pathEndNotAnalyzed =>
      'Utwór docelowy nie został jeszcze przeanalizowany — poczekaj na skan odkrywania lub wybierz inny.';

  @override
  String get pathStartSong => 'Utwór początkowy';

  @override
  String get pathEndSong => 'Utwór końcowy';

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
      'Wybierz utwór początkowy — stuknij dowolny utwór w bibliotece';

  @override
  String get pathPickBannerEnd =>
      'Wybierz utwór docelowy — stuknij dowolny utwór w bibliotece';

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
  String get setupVisualizerTitle => 'Prawdziwy dźwięk dla wizualizacji';

  @override
  String get setupVisualizerBody =>
      'Wizualizacja używa danych syntetycznych, dopóki ta opcja nie zostanie włączona.';

  @override
  String get setupVisualizerWarning =>
      'Włączenie tej opcji prosi o uprawnienie do mikrofonu — Android wymaga go od aplikacji, które dekodują strumień dźwięku urządzenia (a wizualizacja to robi).';

  @override
  String get setupPlaybackTitle => 'Gdy dotkniesz utworu';

  @override
  String get setupOfflineTitle => 'Zachowaj kolejkę offline';

  @override
  String get setupVisualizerNoMic =>
      'mStream nigdy nie używa Twojego mikrofonu.';

  @override
  String get playlistEmpty => 'Playlista jest pusta';

  @override
  String get trackRating => 'Ocena';

  @override
  String albumDiscNumber(int n) {
    return 'Płyta $n';
  }

  @override
  String get autoDjStartTitle => 'Od czego zacząć Auto DJ?';

  @override
  String get autoDjStartSubtitle =>
      'Kolejka jest pusta, więc DJ potrzebuje pierwszego utworu. Z kolejką po prostu podąża za tym, co już masz.';

  @override
  String get autoDjStartRandom => 'Zaskocz mnie';

  @override
  String get autoDjStartRandomSub =>
      'Wybierz losowy utwór z biblioteki i buduj od niego.';

  @override
  String get autoDjStartPick => 'Wybiorę sam';

  @override
  String get autoDjStartPickSub =>
      'Otwórz bibliotekę i wybierz pierwszy utwór samodzielnie.';

  @override
  String get autoDjStartRemember => 'Zapamiętaj';

  @override
  String get autoDjStartRememberSub =>
      'Pomiń to pytanie następnym razem i zawsze zaczynaj tak.';

  @override
  String get autoDjStartPickBanner =>
      'Wybierz pierwszy utwór — stuknij dowolny utwór w bibliotece';

  @override
  String get autoDjOnEmptyQueue => 'Przy pustej kolejce';

  @override
  String get autoDjOnEmptyQueueSub =>
      'Co robi Auto DJ, gdy włączysz go bez niczego w kolejce.';

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
  String get autoDjNeedsNewerServer =>
      'Ciągłość BPM, miksowanie harmoniczne i filtr gatunków wymagają nowszego serwera. Zaktualizuj, aby z nich korzystać.';

  @override
  String get autoDjSonicNeedsNewerServer =>
      'Wymaga serwera 6.15.2 lub nowszego';

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
  String get settingsTorrentAskSub =>
      'Gdy torrent zostanie otwarty w mStream, zaproponuj przekazanie go innej aplikacji';

  @override
  String get settingsTorrentDefaultTitle => 'Domyślna aplikacja dla torrentów';

  @override
  String get settingsTorrentDefaultSub =>
      'Otwiera ustawienia Androida, gdzie wybierzesz aplikację otwierającą torrenty i linki magnet';

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
    return 'via $parent';
  }

  @override
  String get browserFederatedReadOnly => 'Read-only server';

  @override
  String get browserFederatedReadOnlyNote =>
      'Playlists and ratings stay on your own';

  @override
  String get federatedShareUnavailable =>
      'Tracks on a shared server can\'t be shared from here — they live in someone else\'s library.';

  @override
  String get federatedForget => 'Forget';

  @override
  String get federatedHide => 'Hide from the picker';

  @override
  String get federatedShow => 'Show in the picker';

  @override
  String federatedNoLongerListed(String parent) {
    return 'No longer shared by $parent';
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
      'Komponent iroh nie ma kompilacji dla systemu/procesora tego serwera, więc punkt federacji nie może tu działać.';

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
  String get federationNotRunning => 'Punkt federacji nie działa';

  @override
  String get federationEndpointId => 'Identyfikator punktu';

  @override
  String get federationEndpointCopied => 'Skopiowano identyfikator punktu';

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
    return 'Zaoferowano $libraries';
  }

  @override
  String get federationRequestYouOfferedNothing => 'Niczego nie zaoferowano';

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
  String get federationPresets => 'Ustawienia gotowe';

  @override
  String get federationLimitStreamRate => 'Prędkość strumienia';

  @override
  String get federationLimitPerDay => 'Dziennie';

  @override
  String get federationLimitStreams => 'Strumienie jednocześnie';

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
  String get federationExpiresField => 'Wygasa za dni (0 = nigdy)';

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
      'Każdy, kto ma ten bilet, może czytać te biblioteki, dopóki nie zostanie użyty lub unieważniony. Wyślij go prywatnym kanałem — przejmuje go pierwszy serwer, który go użyje.';

  @override
  String get federationCopyTicket => 'Kopiuj bilet';

  @override
  String get federationTicketCopied => 'Skopiowano bilet';

  @override
  String get federationSendByText => 'Wyślij wiadomością…';

  @override
  String get federationTicketRevokeNote =>
      'Unieważnij w dowolnej chwili w sekcji Federacja. Jeśli znajomy przeinstalował serwer, „Zresetuj użycie” pozwoli użyć biletu ponownie.';

  @override
  String get federationTicketNotRunning =>
      'Punkt federacji nie działa, więc nie ma jeszcze biletu do wysłania. Włącz federację i wróć.';

  @override
  String federationShareMessage(String libraries, String ticket) {
    return 'Udostępniam ci moją bibliotekę muzyczną mStream — $libraries, tylko do odczytu. W aplikacji mStream otwórz Federacja → Dodaj serwer partnerski i wklej ten bilet:\n\n$ticket\n\nDziała raz — mogę go unieważnić w każdej chwili.';
  }

  @override
  String get federationShareSubject => 'Bilet federacji mStream';

  @override
  String get federationKeyClaimed => 'użyty';

  @override
  String get federationKeyNotClaimed => 'jeszcze nieużyty';

  @override
  String federationKeyTodayUsage(String amount) {
    return '$amount dzisiaj';
  }

  @override
  String federationKeyLastUsed(String ago) {
    return 'Ostatnio użyty $ago';
  }

  @override
  String get federationKeyNeverUsed => 'Nigdy nieużyty';

  @override
  String federationKeyClaimedAgo(String ago) {
    return 'Użyty $ago';
  }

  @override
  String get federationResetBinding => 'Zresetuj użycie';

  @override
  String get federationResetBindingNote =>
      'Znajomy przeinstalował serwer? Pozwól użyć biletu ponownie.';

  @override
  String get federationBindingReset => 'Bilet można użyć ponownie';

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
  String get federationDiscoverySection => 'Wykrywanie';

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
      'Potrzebny serwer, który odpowiada na dobór dźwiękowy';

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
      'Nie udało się zmienić ustawienia wykrywania.';

  @override
  String get agoJustNow => 'przed chwilą';

  @override
  String agoMinutes(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count min temu',
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
      few: '$count sąsiadów',
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
      other: 'do przeszukania, $count bibliotek',
      few: 'do przeszukania, $count biblioteki',
      one: 'do przeszukania, 1 biblioteka',
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
          'Otwiera Odkrywanie dla granego utworu · podpowiedzi z $count pobranych bibliotek',
      few:
          'Otwiera Odkrywanie dla granego utworu · podpowiedzi z $count pobranych bibliotek',
      one:
          'Otwiera Odkrywanie dla granego utworu · podpowiedzi z 1 pobranej biblioteki',
    );
    return '$_temp0';
  }

  @override
  String get p2pFindSimilarNothingPlaying =>
      'Najpierw coś odtwórz — Odkrywanie podąża za bieżącym utworem';

  @override
  String get p2pNewArtistsOnlySub =>
      'Ukryj podpowiedzi wykonawców, którzy już są w tej bibliotece';

  @override
  String get p2pServersYouFollow => 'Obserwowane serwery';

  @override
  String get p2pServersOnNetwork => 'Serwery w sieci';

  @override
  String get p2pNoServersYet =>
      'Nie usłyszano jeszcze żadnego serwera — dodaj jeden biletem znajomego albo daj gossipowi minutę.';

  @override
  String p2pHiddenIncompatible(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count serwerów ukrytych — niezgodny model',
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
      few: '$count seederów',
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
  String get p2pJoinTitle => 'Polecenia z bibliotek innych osób';

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
  String get p2pNotDownloadedSub => 'Pobierz, aby przeszukiwać ją z Odkrywania';

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
      'Sidecar jeszcze nie działa, więc nie ma jeszcze biletu do udostępnienia.';

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
  String get p2pCommunitySeeds => 'Seedy społeczności';

  @override
  String get p2pCommunitySeedsOn => 'Start przez publiczne serwery seed';

  @override
  String get p2pCommunitySeedsOff =>
      'Wyłączone — tylko zaprzyjaźnione serwery; ustawiane w konfiguracji serwera';

  @override
  String p2pBlockedServers(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count zablokowanych serwerów',
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
}
