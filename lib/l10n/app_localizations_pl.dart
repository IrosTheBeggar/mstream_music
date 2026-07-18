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
  String get autoDjActiveSource => 'Aktywne źródło';

  @override
  String get autoDjActiveSourceTap =>
      'Aktywne źródło — dotknij, aby przełączyć';

  @override
  String get autoDjSwitch => 'Przełącz';

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
      other: '$count utworów w kolejce',
      many: '$count utworów w kolejce',
      few: '$count utwory w kolejce',
      one: '1 utwór w kolejce',
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
      'Keep the newest this many auto-downloads; older ones no longer in your queue are removed.';

  @override
  String get settingsAutoDownloadCapSubtitleUnlimited =>
      'Keep every auto-downloaded track (no limit).';

  @override
  String get settingsAutoDownloadCapUnlimited => 'Unlimited';

  @override
  String get settingsAutoDownloadCapField => 'Number of tracks';

  @override
  String get settingsAutoDownloadCapDialogBody =>
      'Automatically downloaded tracks kept for offline play. When you go over, the oldest ones that aren\'t in your queue are deleted. Set to 0 to keep everything.';

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
  String get irohConnectHeader => 'Connect peer-to-peer';

  @override
  String get irohPairingHeader => 'Connect with a pairing code';

  @override
  String get irohConnectBody =>
      'Reach your server from anywhere — no port-forwarding, DNS, or public IP needed.';

  @override
  String get irohPairingBody =>
      'Enable Remote Access on the server, then paste its pairing code or scan the QR.';

  @override
  String get irohOneServerLimit =>
      'Only one peer-to-peer (iroh) server is supported. Remove the existing one to connect a different server.';

  @override
  String get irohPairingCodeLabel => 'Pairing code';

  @override
  String get irohPairingCodeHint =>
      'Paste the code from the server Remote Access panel';

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
  String get serverBadgeBuiltIn => 'Built-in';

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
}
