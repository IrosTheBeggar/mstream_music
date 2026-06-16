// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Russian (`ru`).
class AppLocalizationsRu extends AppLocalizations {
  AppLocalizationsRu([String locale = 'ru']) : super(locale);

  @override
  String get mainRemove => 'Убрать';

  @override
  String get playlistActionFailed =>
      'Не удалось сохранить плейлист — возможно, имя уже занято.';

  @override
  String get queueAddNext => 'Добавить следующим';

  @override
  String get queuePlayNow => 'Воспроизвести сейчас';

  @override
  String get queueAddToEnd => 'Добавить в конец очереди';

  @override
  String get shuffle => 'Перемешать';

  @override
  String get variousArtists => 'Разные исполнители';

  @override
  String get appTitle => 'mStream Music';

  @override
  String get settingsLanguage => 'Язык';

  @override
  String get languageSystemDefault => 'Системный по умолчанию';

  @override
  String get settingsLanguageSubtitle =>
      'Язык интерфейса приложения. «Системный по умолчанию» следует за настройками устройства.';

  @override
  String couldNotOpen(String url) {
    return 'Не удалось открыть $url';
  }

  @override
  String trackCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count треков',
      many: '$count треков',
      few: '$count трека',
      one: '$count трек',
      zero: 'Нет треков',
    );
    return '$_temp0';
  }

  @override
  String get reset => 'Сбросить';

  @override
  String get themeVelvet => 'Velvet';

  @override
  String get themeDark => 'Тёмная';

  @override
  String get themeLight => 'Светлая';

  @override
  String get tapAddToQueue => 'Добавить в очередь';

  @override
  String get tapPlayFromHere => 'Воспроизвести отсюда';

  @override
  String get tapAppendAndJump => 'Добавить и воспроизвести';

  @override
  String get visualizerEngineMilkdrop => 'Milkdrop';

  @override
  String get visualizerEngineShaders => 'Шейдеры';

  @override
  String get visualizerSourceSynthesized => 'Синтезированный';

  @override
  String get visualizerSourceReal => 'Реальный звук';

  @override
  String get downloadsTitle => 'Загрузки';

  @override
  String downloadProgress(String progress) {
    return 'прогресс: $progress%';
  }

  @override
  String get songInfoTitle => 'Сведения о треке';

  @override
  String get eqTitle => 'Эквалайзер';

  @override
  String get eqOnlyAndroid => 'Эквалайзер доступен только на Android.';

  @override
  String get eqNeedsPlayback =>
      'Запустите трек, чтобы настроить эквалайзер.\n\nНативный эквалайзер Android инициализируется вместе с аудиосессией, поэтому для считывания раскладки полос необходимо активное воспроизведение.';

  @override
  String eqInitFailed(String error) {
    return 'Не удалось инициализировать эквалайзер:\n$error';
  }

  @override
  String get eqNoBands =>
      'Аудиодрайвер этого устройства не сообщает о полосах эквалайзера.';

  @override
  String get eqEnabledOn => 'Включён — усиление применяется к воспроизведению';

  @override
  String get eqEnabledOff => 'Выключен — режим обхода';

  @override
  String get cancel => 'Отмена';

  @override
  String get continueLabel => 'Продолжить';

  @override
  String get openSettings => 'Открыть настройки';

  @override
  String get settingsTitle => 'Настройки';

  @override
  String get settingsSectionAppearance => 'Внешний вид';

  @override
  String get settingsSectionPlayback => 'Воспроизведение';

  @override
  String get settingsSectionBrowse => 'Обзор';

  @override
  String get settingsSectionAbout => 'О приложении';

  @override
  String get settingsTheme => 'Тема';

  @override
  String get themeSubtitleVelvet =>
      'Тёмно-синий и фиолетовый — фирменная тёмная тема.';

  @override
  String get themeSubtitleDark => 'Нейтральная тёмная с янтарными акцентами.';

  @override
  String get themeSubtitleLight =>
      'Светлый фон с тёмной панелью приложения и янтарными акцентами — совпадает с прежней темой.';

  @override
  String get settingsTranscode => 'Перекодировать звук';

  @override
  String get settingsTranscodeSubtitle =>
      'Транслировать перекодированную копию с сервера (файлы меньше, старт немного медленнее). При выключении воспроизводятся исходные файлы.';

  @override
  String get transcodeTitle => 'Перекодирование';

  @override
  String get transcodeCodec => 'Кодек';

  @override
  String get transcodeBitrate => 'Битрейт';

  @override
  String get transcodeAuto => 'По умолчанию сервера';

  @override
  String get transcodeUnavailable =>
      'На этом сервере транскодирование не включено — его треки воспроизводятся в оригинальном качестве.';

  @override
  String get transcodeReloadQueue => 'Применить к текущей очереди';

  @override
  String get transcodeReloadQueueSubtitle =>
      'При изменении настроек транскодирования — включено: перезагрузить всю очередь сейчас (текущий трек ненадолго буферизуется); выключено: меняются только следующие треки, текущий доигрывает без изменений.';

  @override
  String get settingsTapBehavior => 'При нажатии на трек';

  @override
  String get settingsStartupPage => 'Стартовый экран';

  @override
  String get settingsStartupPageSubtitle =>
      'Открывать приложение в этом разделе браузера; «Назад» возвращает к браузеру.';

  @override
  String get tapSubtitleAddToQueue =>
      'Нажатие на трек добавляет его в очередь. Если очередь пуста, воспроизведение начнётся автоматически.';

  @override
  String get tapSubtitlePlayFromHere =>
      'Нажатие на трек заменяет очередь треками из текущего вида и начинает воспроизведение с выбранного трека.';

  @override
  String get tapSubtitleAppendAndJump =>
      'Нажатие на трек добавляет его в очередь и переключает воспроизведение на него, прерывая то, что играло.';

  @override
  String get settingsEqSubtitle =>
      'Настройте низкие, средние и высокие частоты. Только на Android.';

  @override
  String get settingsVisualizerEngine => 'Движок визуализации';

  @override
  String get visualizerEngineSubtitleMilkdrop =>
      'Пресеты Milkdrop через projectM (по умолчанию). Более насыщенные эффекты, выше нагрузка на GPU.';

  @override
  String get visualizerEngineSubtitleShaders =>
      'Фрагментные шейдеры в стиле Shadertoy. Легче и модульнее — добавляйте файлы .glsl в assets/shaders/, чтобы расширить каталог.';

  @override
  String get settingsVisualizerSource => 'Источник звука визуализации';

  @override
  String get visualizerSourceSubtitleSynthesized =>
      'По умолчанию. Визуализация реагирует только на тайминг воспроизведения — разрешение на микрофон не требуется.';

  @override
  String get visualizerSourceSubtitleReal =>
      'Визуализация реагирует на реальный аудиовыход. Требуется разрешение RECORD_AUDIO на Android.';

  @override
  String get settingsAlbumGrid => 'Альбомы сеткой';

  @override
  String get settingsAlbumGridSubtitle =>
      'Показывать альбомы сеткой карточек с обложками вместо обычного списка.';

  @override
  String get settingsFileMetadata =>
      'Читать метаданные треков в проводнике файлов';

  @override
  String get settingsFileMetadataSubtitle =>
      'Получать название, исполнителя и обложку для каждого трека при просмотре файлов сервера. При выключении показываются исходные имена файлов (быстрее для больших папок).';

  @override
  String get settingsLetterStrip => 'Порог буквенной прокрутки';

  @override
  String get settingsLetterStripSubtitle =>
      'Показывать полосу быстрой прокрутки A–Z, когда в списке столько элементов или больше. Ниже этого размера полоса скрывается, а длинные имена папок и файлов переносятся на несколько строк вместо обрезки. Установите 0, чтобы полоса показывалась всегда.';

  @override
  String get settingsReset => 'Сбросить к значениям по умолчанию';

  @override
  String get settingsResetSubtitle =>
      'Восстановить все настройки на этом экране к значениям по умолчанию. Серверы и загрузки не затрагиваются.';

  @override
  String get settingsResetDone =>
      'Настройки восстановлены к значениям по умолчанию';

  @override
  String get realAudioDialogTitle => 'Использовать реальный звук?';

  @override
  String get realAudioDialogBody =>
      'Режим реального звука считывает форму волны музыки, которую воспроизводит телефон, чтобы визуализация могла реагировать на неё. Для этого Android требует разрешение RECORD_AUDIO — приложение никуда не записывает и не отправляет звук. Вы можете в любой момент вернуться к синтезированному режиму.';

  @override
  String get realAudioPermPermanentlyDenied =>
      'Разрешение отклонено навсегда. Включите его в системных настройках, чтобы использовать реальный звук.';

  @override
  String get realAudioPermDenied =>
      'Разрешение отклонено. Остаёмся на синтезированном звуке.';

  @override
  String get visualizerTapHint =>
      'Нажатие = следующий пресет · стрелка назад (вверху слева) или долгое нажатие для выхода';

  @override
  String get visualizerFailed => 'Не удалось запустить визуализацию';

  @override
  String get visualizerBringingUp => 'Запуск рендерера…';

  @override
  String get visualizerReady => 'Визуализация готова';

  @override
  String get visualizerBridgeFailed => 'Не удалось запустить мост';

  @override
  String visualizerAudioSourceLine(String source) {
    return 'Источник звука: $source';
  }

  @override
  String get visualizerTapToClose => 'Нажмите в любом месте, чтобы закрыть';

  @override
  String get visualizerUnsupported =>
      'Визуализация сейчас поддерживается только на Android.';

  @override
  String get aboutTitle => 'О приложении';

  @override
  String aboutBuiltBy(String name) {
    return 'Разработано $name';
  }

  @override
  String get linkDiscordSubtitle => 'Чат сообщества';

  @override
  String get linkGithubSubtitle => 'Исходный код сервера mStream';

  @override
  String get linkHomepageSubtitle => 'Домашняя страница проекта';

  @override
  String get aboutAttributions => 'Упоминания';

  @override
  String get aboutAttributionsSubtitle =>
      'Лицензия, упоминания авторов шейдеров и уведомления об открытом исходном коде.';

  @override
  String get ok => 'ОК';

  @override
  String get delete => 'Удалить';

  @override
  String get edit => 'Изменить';

  @override
  String get info => 'Сведения';

  @override
  String get makeDefault => 'Сделать основным';

  @override
  String get goBack => 'Назад';

  @override
  String get play => 'Воспроизвести';

  @override
  String get playAll => 'Воспроизвести всё';

  @override
  String get rename => 'Переименовать';

  @override
  String get create => 'Создать';

  @override
  String get copy => 'Копировать';

  @override
  String get done => 'Готово';

  @override
  String get copiedToClipboard => 'Скопировано в буфер обмена';

  @override
  String get attributionsTitle => 'Упоминания';

  @override
  String get attributionsSectionLicense => 'Лицензия';

  @override
  String get attributionsSectionShaders => 'Шейдеры визуализации';

  @override
  String get attributionsSectionLibraries => 'Нативные библиотеки';

  @override
  String get attributionsSectionEverythingElse => 'Всё остальное';

  @override
  String get attributionsLicenseBody =>
      'Свободное программное обеспечение под лицензией GNU General Public License v3.0. Вы можете использовать, изучать, распространять и изменять его на этих условиях.';

  @override
  String get attributionsPackages =>
      'Лицензии пакетов с открытым исходным кодом';

  @override
  String get attributionsPackagesSubtitle =>
      'Полные тексты лицензий для всех включённых пакетов Flutter/Dart.';

  @override
  String get manageServersTitle => 'Управление серверами';

  @override
  String get manageServerInfo => 'Сведения о сервере';

  @override
  String get manageServerDownloadFolder => 'Папка загрузок:';

  @override
  String get manageServerCopyPath => 'Копировать путь загрузки';

  @override
  String get manageServerPathCopied => 'Путь скопирован в буфер обмена';

  @override
  String get confirmRemoveServerTitle => 'Подтвердите удаление сервера';

  @override
  String get removeSyncedFiles =>
      'Удалить синхронизированные файлы с устройства?';

  @override
  String get playlistsTitle => 'Плейлисты';

  @override
  String get playlistsNew => 'Новый плейлист';

  @override
  String get playlistsEmptyTitle => 'Плейлистов пока нет';

  @override
  String get playlistsEmptyBody =>
      'Создайте плейлист кнопкой «Новый плейлист», затем заполните его свайпом «Добавить в плейлист» в очереди.';

  @override
  String get playlistNameHint => 'Название';

  @override
  String get playlistsRename => 'Переименовать плейлист';

  @override
  String get playlistFallbackTitle => 'Плейлист';

  @override
  String get playlistEmptyDetail =>
      'Плейлист пуст.\nДобавляйте треки через очередь.';

  @override
  String get shareEmptyTitle => 'Очередь пуста';

  @override
  String get shareEmptyBody =>
      'Добавьте треки в очередь перед тем, как делиться.';

  @override
  String get shareBlockedTitle => 'Не удаётся поделиться этой очередью';

  @override
  String get shareLocalOnlyBody =>
      'В очереди есть треки, которые находятся только на этом устройстве (ни на одном сервере). Поделиться можно, только когда все треки в очереди с одного сервера.';

  @override
  String shareMultiServerBody(int count, String names) {
    return 'В очереди смешаны треки с $count серверов ($names). Поделиться можно, только когда все треки с одного сервера.';
  }

  @override
  String shareServerGoneBody(String name) {
    return 'Сервера «$name» больше нет в вашем списке серверов. Добавьте его снова, чтобы поделиться его очередью.';
  }

  @override
  String get shareTitle => 'Поделиться плейлистом';

  @override
  String shareSongCount(int count, String url) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count треков',
      many: '$count треков',
      few: '$count трека',
      one: '$count трек',
    );
    return '$_temp0 с $url';
  }

  @override
  String get shareLinkExpires => 'Срок действия ссылки';

  @override
  String get shareExpireNever => 'Никогда';

  @override
  String get shareExpire1Day => 'Через 1 день';

  @override
  String get shareExpire7Days => 'Через 7 дней';

  @override
  String get shareExpire30Days => 'Через 30 дней';

  @override
  String get shareAction => 'Поделиться';

  @override
  String get shareDoneTitle => 'Плейлист отправлен';

  @override
  String get shareDoneBody =>
      'Любой, у кого есть эта ссылка, может воспроизвести очередь:';

  @override
  String get save => 'Сохранить';

  @override
  String get start => 'Запустить';

  @override
  String get addServerTitle => 'Добавить сервер';

  @override
  String get editServerTitle => 'Изменить сервер';

  @override
  String get fieldServerUrl => 'URL сервера';

  @override
  String get fieldPublicAccess => 'Публичный доступ';

  @override
  String get publicAccessSubtitle =>
      'Сервер общедоступен — имя пользователя и пароль не нужны.';

  @override
  String get fieldUsername => 'Имя пользователя';

  @override
  String get fieldPassword => 'Пароль';

  @override
  String get fieldSdCard => 'Загружать на SD-карту';

  @override
  String get sdCardSubtitle =>
      'Сохранять загруженную музыку на съёмную SD-карту вместо внутреннего хранилища.';

  @override
  String get testConnectionButton => 'Проверить подключение';

  @override
  String get testing => 'Проверка…';

  @override
  String get connecting => 'Подключение…';

  @override
  String get validatorUrlNeeded => 'Требуется URL сервера';

  @override
  String get validatorUrlParse => 'Не удаётся разобрать URL';

  @override
  String get testEnterUrl => 'Сначала введите URL сервера.';

  @override
  String get testParseUrl => 'Не удалось разобрать URL.';

  @override
  String get testCouldNotConnect =>
      'Не удалось подключиться. Проверьте URL и повторите попытку.';

  @override
  String get testTimedOut => 'Время ожидания подключения истекло.';

  @override
  String get connectFailedSnack =>
      'Не удалось подключиться к серверу. Проверьте URL и повторите попытку.';

  @override
  String get connectionSuccessful => 'Подключение установлено!';

  @override
  String get couldNotReachServer =>
      'Не удалось связаться с сервером. Если требуется вход, отключите «Публичный доступ» и добавьте учётные данные.';

  @override
  String get failedToLogin => 'Не удалось войти';

  @override
  String testConnected(String version) {
    return 'Подключено — mStream v$version';
  }

  @override
  String testConnectFailed(String error) {
    return 'Не удалось подключиться: $error';
  }

  @override
  String get sleepTimerTitle => 'Таймер сна';

  @override
  String get sleepTimerHint =>
      'Выберите интервал, после которого приостановить воспроизведение.';

  @override
  String get sleepTimerCustom => 'Свой';

  @override
  String get sleepTimerCustomHint => 'минуты (1–600)';

  @override
  String get sleepTimerCancel => 'Отменить таймер';

  @override
  String get sleepTimerInvalid => 'Введите число от 1 до 600 минут';

  @override
  String sleepTimerPausesIn(String time) {
    return 'Пауза через $time';
  }

  @override
  String sleepTimerMinutes(int minutes) {
    return '$minutes мин';
  }

  @override
  String sleepTimerSet(int minutes) {
    String _temp0 = intl.Intl.pluralLogic(
      minutes,
      locale: localeName,
      other: 'Таймер сна установлен на $minutes минут',
      many: 'Таймер сна установлен на $minutes минут',
      few: 'Таймер сна установлен на $minutes минуты',
      one: 'Таймер сна установлен на $minutes минуту',
    );
    return '$_temp0';
  }

  @override
  String get add => 'Добавить';

  @override
  String get autoDjTitle => 'Авто-DJ';

  @override
  String get autoDjAddServerFirst => 'Сначала добавьте сервер.';

  @override
  String get autoDjSectionServer => 'Сервер';

  @override
  String get autoDjSectionSources => 'Источники';

  @override
  String get autoDjSectionContinuity => 'Непрерывность';

  @override
  String get autoDjSectionFilters => 'Фильтры';

  @override
  String get autoDjBpmTitle => 'Непрерывность по BPM';

  @override
  String get autoDjBpmSubtitle =>
      'Предпочитать выбор в пределах темпового окна текущего трека. Учитывает эквивалентность половинного/двойного темпа.';

  @override
  String get autoDjTolerance => 'Допуск';

  @override
  String autoDjBpmTolerance(int bpm) {
    return '± $bpm BPM';
  }

  @override
  String get autoDjHarmonicTitle => 'Гармоническое сведение';

  @override
  String get autoDjHarmonicSubtitle =>
      'Предпочитать выбор в тональностях, хорошо сочетающихся с закреплённым треком (соседи по колесу Camelot).';

  @override
  String get autoDjStatusOn => 'Авто-DJ включён';

  @override
  String get autoDjStatusOff => 'Авто-DJ выключен';

  @override
  String get autoDjStatusOffDetail =>
      'Нажмите ниже, чтобы запустить. Будет использована библиотека текущего сервера.';

  @override
  String get autoDjStart => 'Запустить Авто-DJ';

  @override
  String get autoDjStop => 'Остановить Авто-DJ';

  @override
  String autoDjStatusOnDetail(String url) {
    return 'Треки выбираются из $url, когда очередь подходит к концу.';
  }

  @override
  String get autoDjActiveSource => 'Активный источник';

  @override
  String get autoDjActiveSourceTap =>
      'Активный источник — нажмите, чтобы сменить';

  @override
  String get autoDjSwitch => 'Сменить';

  @override
  String get autoDjOneSourceRequired => 'Требуется хотя бы один источник.';

  @override
  String get autoDjMinRating => 'Минимальная оценка';

  @override
  String get autoDjMinRatingSubtitle =>
      'Выбирать только треки с этой оценкой или выше.';

  @override
  String get autoDjRatingAny => 'Любая';

  @override
  String get autoDjGenreTitle => 'Фильтр по жанрам';

  @override
  String get autoDjGenreSubtitle =>
      'Белый список воспроизводит только подходящие треки; чёрный список пропускает их.';

  @override
  String get autoDjWhitelist => 'Белый список';

  @override
  String get autoDjBlacklist => 'Чёрный список';

  @override
  String get autoDjNoGenres =>
      'Жанры не выбраны. Нажмите «Выбрать жанры», чтобы выбрать.';

  @override
  String get autoDjPickGenres => 'Выбрать жанры';

  @override
  String get autoDjGenreLoadError => 'Не удалось загрузить жанры';

  @override
  String get autoDjKeywordTitle => 'Фильтр по ключевым словам';

  @override
  String get autoDjKeywordSubtitle =>
      'Пропускать выбор, в названии, исполнителе, альбоме или пути к файлу которого есть любое из этих слов.';

  @override
  String get autoDjNoKeywords =>
      'Ключевых слов нет. Добавьте слова ниже, чтобы начать фильтрацию.';

  @override
  String get autoDjKeywordHint => 'например, «live» или «remix»';

  @override
  String get autoDjSearchGenres => 'Поиск жанров…';

  @override
  String get autoDjNoGenresOnServer => 'На этом сервере жанры не найдены.';

  @override
  String autoDjSelectedCount(int count) {
    return 'Выбрано: $count';
  }

  @override
  String autoDjNoGenresMatch(String query) {
    return 'Нет жанров по запросу «$query».';
  }

  @override
  String get download => 'Скачать';

  @override
  String get addAll => 'Добавить всё';

  @override
  String get browserConfirmDeletePlaylist => 'Подтвердите удаление плейлиста';

  @override
  String get browserConfirmDeleteFolder => 'Подтвердите удаление папки';

  @override
  String get browserSearchHint => 'Поиск в базе данных';

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
      other: 'Начато $count загрузок',
      many: 'Начато $count загрузок',
      few: 'Начато $count загрузки',
      one: 'Начата $count загрузка',
    );
    return '$_temp0';
  }

  @override
  String browserSongsAdded(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count треков добавлено в очередь',
      many: '$count треков добавлено в очередь',
      few: '$count трека добавлено в очередь',
      one: '$count трек добавлен в очередь',
    );
    return '$_temp0';
  }

  @override
  String get tabBrowser => 'Обзор';

  @override
  String get tabQueue => 'Очередь';

  @override
  String get drawerTagline => 'Личный стриминг музыки';

  @override
  String get mainFailedToConnect => 'Не удалось подключиться к серверу';

  @override
  String get mainQueueEmpty => 'Очередь пуста';

  @override
  String get visualizerTitle => 'Визуализация';

  @override
  String get mainClearQueue => 'Очистить очередь';

  @override
  String get mainSync => 'Синхронизировать';

  @override
  String mainQueueCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count треков в очереди',
      many: '$count треков в очереди',
      few: '$count трека в очереди',
      one: '$count трек в очереди',
    );
    return '$_temp0';
  }

  @override
  String get autoDjEnabled => 'Авто-DJ включён';

  @override
  String get autoDjDisabled => 'Авто-DJ выключен';

  @override
  String autoDjEnabledFor(String url) {
    return 'Авто-DJ включён для $url';
  }

  @override
  String get addToPlaylistTitle => 'Добавить в плейлист';

  @override
  String get addToPlaylistEmpty =>
      'Плейлистов пока нет — нажмите +, чтобы создать.';

  @override
  String addedToPlaylist(String name) {
    return 'Добавлено в $name';
  }

  @override
  String get testConnectedSignedIn => 'Подключено — вход выполнен успешно.';

  @override
  String get testSignInFailed =>
      'Сервер доступен, но вход не удался — проверьте имя пользователя и пароль.';

  @override
  String get browserFileExplorer => 'Проводник файлов';

  @override
  String get browserLocalFiles => 'Локальные файлы';

  @override
  String get browserPlaylists => 'Плейлисты';

  @override
  String get browserAlbums => 'Альбомы';

  @override
  String get browserArtists => 'Исполнители';

  @override
  String get browserRecent => 'Недавние';

  @override
  String get browserRated => 'С оценкой';

  @override
  String get browserSearch => 'Поиск';

  @override
  String get browserWelcomeTitle => 'Добро пожаловать в mStream';

  @override
  String get browserWelcomeSubtitle => 'Нажмите здесь, чтобы добавить сервер';

  @override
  String get settingsVisualizerKnobs => 'Регуляторы настройки визуализации';

  @override
  String get settingsVisualizerKnobsSubtitle =>
      'Показывать живые ползунки поверх визуализации для подстройки реактивности звука каждого шейдера. Только для движка шейдеров.';

  @override
  String get visualizerTuningTitle => 'Настройка';

  @override
  String get close => 'Закрыть';

  @override
  String get migMoveStopped =>
      'Перемещение остановлено — недостаточно места или расположение недоступно.';

  @override
  String get migMoveComplete => 'Перемещение завершено';

  @override
  String migMoveCompleteSkipped(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other:
          'Перемещение завершено — пропущено $count файлов (не поддерживаются в месте назначения)',
      many:
          'Перемещение завершено — пропущено $count файлов (не поддерживаются в месте назначения)',
      few:
          'Перемещение завершено — пропущено $count файла (не поддерживаются в месте назначения)',
      one:
          'Перемещение завершено — пропущен $count файл (не поддерживается в месте назначения)',
    );
    return '$_temp0';
  }

  @override
  String migMoving(String progress) {
    return 'Перемещение загрузок… $progress — не закрывайте приложение';
  }

  @override
  String get migRetry => 'Повторить';

  @override
  String get queueDownloadAll => 'Скачать всё';

  @override
  String queueDownloadAllBody(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Для воспроизведения офлайн будет скачано $count треков.',
      many: 'Для воспроизведения офлайн будет скачано $count треков.',
      few: 'Для воспроизведения офлайн будет скачано $count трека.',
      one: 'Для воспроизведения офлайн будет скачан $count трек.',
    );
    return '$_temp0';
  }

  @override
  String get mainMore => 'Ещё';

  @override
  String get commonOn => 'Вкл.';

  @override
  String get commonOff => 'Выкл.';

  @override
  String get settingsCastQuality => 'Качество визуализации при трансляции';

  @override
  String get settingsCastQualitySubtitle720 =>
      'Разрешение, в котором визуализация транслируется на ТВ. 720p — наименьшая нагрузка на телефон.';

  @override
  String get settingsCastQualitySubtitle1080 =>
      'Разрешение, в котором визуализация транслируется на ТВ. 1080p — чётко на любом Chromecast (по умолчанию).';

  @override
  String get settingsCastQualitySubtitle4k =>
      'Разрешение, в котором визуализация транслируется на ТВ. 4K — нужен Chromecast с поддержкой 4K; гораздо большая нагрузка на телефон.';

  @override
  String get eqCasting =>
      'Эквалайзер регулирует звук на этом устройстве, поэтому он недоступен во время трансляции. Отключитесь, чтобы использовать его.';

  @override
  String get browserNothingToDownload => 'В этом списке нечего скачивать';

  @override
  String get browserDownloadAllTitle => 'Скачать всё';

  @override
  String browserDownloadAllConfirm(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Будет скачано $count файлов.',
      many: 'Будет скачано $count файлов.',
      few: 'Будет скачано $count файла.',
      one: 'Будет скачан $count файл.',
    );
    return '$_temp0';
  }

  @override
  String get browserCloseSearch => 'Закрыть поиск';

  @override
  String get browserSearchThisList => 'Поиск в этом списке';

  @override
  String get browserSearchList => 'Поиск в списке';

  @override
  String browserNoMatches(String query) {
    return 'Нет совпадений по запросу «$query»';
  }

  @override
  String get clear => 'Очистить';

  @override
  String get dlLocationUnavailable => 'Расположение загрузки недоступно';

  @override
  String get dlLocationUnavailableServer =>
      'Расположение загрузки недоступно для этого сервера.';

  @override
  String get dlFailed => 'Загрузка не удалась — проверьте подключение.';

  @override
  String get dlFatSkip =>
      'Некоторые треки нельзя сохранить на этой карте — их имена не поддерживаются. Вместо этого они транслируются.';

  @override
  String get dlServerGone => 'Этот сервер больше не настроен.';

  @override
  String get dlStorageUnavailable =>
      'Расположение хранилища недоступно — переподключите SD-карту или измените расположение хранилища этого сервера в разделе «Изменить сервер».';

  @override
  String get dlCouldNotStart =>
      'Не удалось начать загрузку — хранилище недоступно.';

  @override
  String get storageLocationLabel => 'Расположение хранилища';

  @override
  String get storageAppLocal => 'Локально в приложении';

  @override
  String get storagePermanent => 'Постоянное';

  @override
  String get storageSdCard => 'SD-карта';

  @override
  String get storageHelpAppLocal =>
      'Сохраняется внутри приложения. Удаляется при удалении приложения или очистке его данных.';

  @override
  String get storageHelpPermanent =>
      'Сохраняется в выбранную вами папку. Сохраняется при удалении приложения. Требуется «Доступ ко всем файлам».';

  @override
  String get storageHelpSdCard =>
      'Сохраняется в выбранную вами папку на SD-карте. Может стать недоступным, если карту извлечь. Некоторые устройства не позволяют приложениям записывать на SD-карты — если выбор папки постоянно не удаётся, используйте «Постоянное» или «Локально в приложении».';

  @override
  String get storageChooseFolder => 'Выбрать папку';

  @override
  String get storageNoFolderChosen => 'Папка ещё не выбрана';

  @override
  String get storageDownloadFolderLabel => 'Папка загрузок';

  @override
  String get storageDownloadFolderHint => 'имя папки';

  @override
  String get storageBrowse => 'Обзор';

  @override
  String get storageDownloadFolderHelp =>
      'Файлы скачиваются в каталог «media/<folder>» на этом устройстве. Повторное использование папки прежнего сервера сохраняет его скачанные треки при повторном добавлении утраченного сервера.';

  @override
  String get storageNoStorageAvailable => 'Хранилище недоступно';

  @override
  String get storageNoDownloadFolders =>
      'Существующие папки загрузок не найдены';

  @override
  String get storageExistingFolders => 'Существующие папки загрузок';

  @override
  String storageItemCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count элементов',
      many: '$count элементов',
      few: '$count элемента',
      one: '$count элемент',
    );
    return '$_temp0';
  }

  @override
  String get storageAllFilesAccess =>
      'Предоставьте «Доступ ко всем файлам», чтобы хранить загрузки постоянно, затем снова выберите режим.';

  @override
  String get storageSettings => 'Настройки';

  @override
  String get storageNoVolume => 'Не удалось найти том хранилища';

  @override
  String get storageNotWritable =>
      'В эту папку нельзя записывать — выберите другую.';

  @override
  String get storageNewFolder => 'Новая папка';

  @override
  String get storageFolderNameHint => 'Имя папки';

  @override
  String get storageCouldNotCreateFolder => 'Не удалось создать папку';

  @override
  String get storageNoSubfolders => 'Здесь нет вложенных папок';

  @override
  String get storageUseThisFolder => 'Использовать эту папку';

  @override
  String get storageMovedToNewFolder =>
      'Скачанные файлы перемещены в новую папку.';

  @override
  String get storageMoveAlreadyRunning =>
      'Перемещение уже выполняется — дайте ему сначала завершиться.';

  @override
  String get storageMigrateTitle => 'Другой том хранилища';

  @override
  String storageMigrateBody(int count, String size) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other:
          '$count скачанных файлов этого сервера ($size) находятся на другом томе хранилища, чем новое расположение. Выберите, что делать:',
      many:
          '$count скачанных файлов этого сервера ($size) находятся на другом томе хранилища, чем новое расположение. Выберите, что делать:',
      few:
          '$count скачанных файла этого сервера ($size) находятся на другом томе хранилища, чем новое расположение. Выберите, что делать:',
      one:
          '$count скачанный файл этого сервера ($size) находится на другом томе хранилища, чем новое расположение. Выберите, что делать:',
    );
    return '$_temp0';
  }

  @override
  String storageMigrateNoSpace(String free) {
    return 'Недостаточно свободного места в месте назначения (свободно $free). Перемещение может прерваться на середине — сначала освободите место.';
  }

  @override
  String get storageMigrateMove => 'Переместить их';

  @override
  String get storageMigrateMoveBody =>
      'Копировать в новое расположение в фоне, удаляя каждую старую копию по мере перемещения. Не закрывайте приложение, пока не завершится.';

  @override
  String get storageMigrateLeave => 'Оставить их';

  @override
  String get storageMigrateLeaveBody =>
      'Переключиться сейчас; старые загрузки останутся на месте и будут скачаны заново в новом расположении.';

  @override
  String get storageMigrateDelete => 'Удалить старые загрузки';

  @override
  String get storageMigrateDeleteBody =>
      'Переключиться сейчас и удалить старые файлы; они будут скачаны заново в новом расположении.';

  @override
  String get storageMovingBackground =>
      'Перемещение ваших загрузок в фоне — не закрывайте приложение.';

  @override
  String get storageChooseFolderFirst => 'Сначала выберите папку загрузок.';

  @override
  String get storageChooseSdFolderFirst =>
      'Сначала выберите папку на SD-карте. Если отклоняются все папки, возможно, ваше устройство не позволяет приложениям записывать на карту — используйте «Постоянное» или «Локально в приложении».';

  @override
  String get castPlayOn => 'Воспроизвести на';

  @override
  String get castPlayOnTooltip => 'Воспроизвести на…';

  @override
  String get castSearching => 'Поиск устройств для трансляции…';

  @override
  String get castNotSeeing =>
      'Не видите своё устройство? Убедитесь, что оно в той же сети Wi-Fi.';

  @override
  String get castVisualizer => 'Транслировать визуализацию';

  @override
  String get castVisualizerSubtitle =>
      'Транслировать визуализацию на ТВ · только Chromecast';

  @override
  String get visualizerNoKnobs => 'Этот шейдер не предоставляет регуляторов.';

  @override
  String get nowPlaying => 'Сейчас играет';

  @override
  String get playerLayoutSmall => 'Маленький';

  @override
  String get playerLayoutMedium => 'Средний';

  @override
  String get playerLayoutLarge => 'Большой';

  @override
  String get playerLayoutXl => 'XL';

  @override
  String get playerLayoutSmallDesc => 'Тонкая панель — максимум очереди';

  @override
  String get playerLayoutMediumDesc =>
      'Баннер — сбалансированный (по умолчанию)';

  @override
  String get playerLayoutLargeDesc => 'Компактный — обложка по центру';

  @override
  String get playerLayoutXlDesc => 'Крупный — полная обложка';

  @override
  String get queueNothingToDownloadEmpty => 'Очередь пуста — нечего скачивать';

  @override
  String get queueNothingToDownloadSaved =>
      'Нечего скачивать — треки уже сохранены';

  @override
  String get settingsAccentColor => 'Акцентный цвет';

  @override
  String get settingsAccentColorSubtitle =>
      'Цвет выделения, используемый во всём приложении.';

  @override
  String get accentThemeDefault => 'Из темы';

  @override
  String get accentCustom => 'Свой';

  @override
  String get settingsResumeQueue => 'Восстанавливать очередь при запуске';

  @override
  String get settingsResumeQueueSubtitle =>
      'Сохраняет очередь воспроизведения и позицию и восстанавливает их при повторном открытии приложения.';

  @override
  String get settingsRatingHalf => 'Оценки с половиной звезды';

  @override
  String get settingsRatingHalfSubtitle =>
      'Оценивать песни с шагом в ползвезды (долгое нажатие на звезду).';

  @override
  String get ratingTitle => 'Оценить';

  @override
  String get ratingFailed => 'Не удалось сохранить оценку';

  @override
  String get diagnosticsTitle => 'Диагностика';

  @override
  String get diagnosticsEnable => 'Включить журналирование';

  @override
  String get diagnosticsHint =>
      'Журналы хранятся на вашем устройстве. Токены скрываются перед копированием или отправкой.';

  @override
  String get diagnosticsCopy => 'Копировать';

  @override
  String get diagnosticsShare => 'Поделиться';

  @override
  String get diagnosticsClear => 'Очистить';

  @override
  String get diagnosticsCopied => 'Журналы скопированы в буфер обмена';

  @override
  String get diagnosticsEmpty => 'Журналов пока нет';

  @override
  String get storageAppExternal => 'Внешнее (приложение)';

  @override
  String get selfSignedTitle => 'Разрешить самоподписанный сертификат';

  @override
  String get selfSignedSubtitle =>
      'Пропускать проверку TLS для этого сервера. Включайте только в доверенной сети.';

  @override
  String get importedShadersTitle => 'Импортированные шейдеры';

  @override
  String get importedShadersSettingsSubtitle =>
      'Добавьте свои файлы .glsl в ротацию движка Shader.';

  @override
  String get importedShadersRescan => 'Пересканировать папку';

  @override
  String get importedShadersDropHint =>
      'Поместите файлы .glsl в эту папку, затем нажмите «Пересканировать»:';

  @override
  String get importedShadersCopyPath => 'Копировать путь';

  @override
  String get importedShadersReachableHint =>
      'Доступно по USB или через файловый менеджер (в Android/data). Импортированные шейдеры входят в ротацию, когда активен движок Shader.';

  @override
  String get importedShadersRemove => 'Удалить';

  @override
  String get importedShadersEmptyTitle => 'В папке пока нет шейдеров';

  @override
  String get importedShadersEmptyBody =>
      'Скопируйте файлы .glsl в стиле Shadertoy в папку выше, затем нажмите «Пересканировать».';

  @override
  String get importedShadersInvalid =>
      'Возможно, это недопустимый шейдер — нет точки входа mainImage/main.';

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
  String get adminLogOut => 'Выйти';

  @override
  String get adminConfigGroup => 'Конфигурация';

  @override
  String get adminDirectories => 'Каталоги';

  @override
  String get adminUsers => 'Пользователи';

  @override
  String get adminDLNA => 'DLNA';

  @override
  String get adminSubsonicAPI => 'Subsonic API';

  @override
  String get adminMP3Player => 'MP3-плеер';

  @override
  String get adminTorrent => 'Torrent';

  @override
  String get adminFederation => 'Федерация';

  @override
  String get adminServerGroup => 'Сервер';

  @override
  String get adminAbout => 'О программе';

  @override
  String get adminSettings => 'Настройки';

  @override
  String get adminDatabase => 'База данных';

  @override
  String get adminBackups => 'Резервные копии';

  @override
  String get adminTranscoding => 'Транскодирование';

  @override
  String get adminLogs => 'Журналы';

  @override
  String get adminAccess => 'Доступ администратора';

  @override
  String adminAppBarTitle(String label) {
    return 'mStream Admin · $label';
  }

  @override
  String get adminPanelTitle => 'mStream Admin';

  @override
  String get adminLoginErrorRequired => 'Укажите сервер и имя пользователя';

  @override
  String get adminLoginServerURL => 'URL сервера';

  @override
  String get adminLoginUsername => 'Имя пользователя';

  @override
  String get adminLoginPassword => 'Пароль';

  @override
  String get adminLoginSignIn => 'Войти';

  @override
  String get adminRetry => 'Повторить';

  @override
  String get adminSaved => 'Сохранено';

  @override
  String get adminSave => 'Сохранить';

  @override
  String get adminClose => 'Закрыть';

  @override
  String get adminPanelMenuItem => 'Панель администратора';

  @override
  String get adminNoLibrariesYetTitle => 'Библиотек пока нет';

  @override
  String get adminAddDirectoryHint =>
      'Добавьте каталог, чтобы начать сканирование музыки в библиотеку.';

  @override
  String get adminAddDirectoryButton => 'Добавить каталог';

  @override
  String adminRemoveDirectoryTitle(String name) {
    return 'Удалить «$name»?';
  }

  @override
  String get adminRemoveDirectoryWarning =>
      'Это удалит библиотеку и её отсканированные треки из базы данных. Файлы на диске останутся нетронутыми.';

  @override
  String get adminCancel => 'Отмена';

  @override
  String get adminRemove => 'Удалить';

  @override
  String get adminLibraryRemovedToast => 'Библиотека удалена';

  @override
  String get adminDirectoryPathLabel => 'Путь';

  @override
  String get adminDirectoryTypeLabel => 'Тип';

  @override
  String get adminFollowSymlinksTitle => 'Следовать по символическим ссылкам';

  @override
  String get adminFollowSymlinksSubtitle =>
      'Вступит в силу при следующем сканировании';

  @override
  String get adminPickFolderAndNameError => 'Выберите папку и введите имя';

  @override
  String get adminDirectoryAddedToast =>
      'Каталог добавлен — сканирование запущено';

  @override
  String get adminAddDirectoryDialogTitle => 'Добавить каталог';

  @override
  String get adminChooseFolderButton => 'Выбрать папку на сервере…';

  @override
  String get adminLibraryNameLabel => 'Имя библиотеки (vpath)';

  @override
  String get adminLibraryNameHelper => 'Буквы, цифры и дефисы';

  @override
  String get adminGrantAllUsersAccessTitle =>
      'Предоставить доступ всем пользователям';

  @override
  String get adminAudiobookLibraryTitle => 'Библиотека аудиокниг';

  @override
  String get adminAdd => 'Добавить';

  @override
  String get adminChooseFolderTitle => 'Выберите папку';

  @override
  String get adminSelectFolderButton => 'Выбрать эту папку';

  @override
  String get adminNoUsersTitle => 'Нет пользователей';

  @override
  String get adminNoUsersSubtitle =>
      'Без пользователей сервер работает в открытом/публичном режиме. Добавьте пользователя, чтобы требовать вход.';

  @override
  String get adminAddUserButton => 'Добавить пользователя';

  @override
  String get adminLibraryAccessDialogTitle => 'Доступ к библиотекам';

  @override
  String get adminLibraryAccessUpdatedToast => 'Доступ к библиотекам обновлён';

  @override
  String get adminSetSubsonicPasswordTitle => 'Задать пароль Subsonic';

  @override
  String get adminSetPasswordTitle => 'Задать пароль';

  @override
  String get adminPasswordUpdatedToast => 'Пароль обновлён';

  @override
  String adminDeleteUserTitle(String username) {
    return 'Удалить «$username»?';
  }

  @override
  String get adminDeleteUserWarning =>
      'Это безвозвратно удалит учётную запись пользователя.';

  @override
  String get adminDelete => 'Удалить';

  @override
  String get adminUserDeletedToast => 'Пользователь удалён';

  @override
  String get adminStatusPillLabel => 'admin';

  @override
  String get adminDeleteUserMenuItem => 'Удалить пользователя';

  @override
  String get adminNoLibraryAccessLabel => 'Нет доступа к библиотекам';

  @override
  String get adminLibrariesButton => 'Библиотеки';

  @override
  String get adminAdminToggleTitle => 'Админ';

  @override
  String get adminMakeDirsToggleTitle => 'Создавать каталоги';

  @override
  String get adminUploadToggleTitle => 'Загрузка';

  @override
  String get adminModifyFilesToggleTitle => 'Изменять файлы';

  @override
  String get adminServerAudioToggleTitle => 'Аудио на сервере';

  @override
  String get adminAddUserDialogTitle => 'Добавить пользователя';

  @override
  String get adminUsername => 'Имя пользователя';

  @override
  String get adminPassword => 'Пароль';

  @override
  String get adminSubsonicPasswordLabel => 'Пароль Subsonic (необязательно)';

  @override
  String get adminLibraryAccessHeader => 'Доступ к библиотекам';

  @override
  String get adminUsernamePasswordRequiredError =>
      'Укажите имя пользователя и пароль';

  @override
  String get adminUserCreatedToast => 'Пользователь создан';

  @override
  String get adminAdministratorToggleTitle => 'Администратор';

  @override
  String get adminAllowMakeDirectoriesTitle => 'Разрешить создание каталогов';

  @override
  String get adminAllowUploadTitle => 'Разрешить загрузку';

  @override
  String get adminAllowServerAudioTitle => 'Разрешить аудио на сервере';

  @override
  String get adminCreate => 'Создать';

  @override
  String get adminNoLibrariesConfigured => 'Библиотеки не настроены.';

  @override
  String get adminNewPasswordLabel => 'Новый пароль';

  @override
  String get adminLibraryTitle => 'Библиотека';

  @override
  String get adminTracksInDatabase => 'Треков в базе данных';

  @override
  String get adminScanAllButton => 'Сканировать всё';

  @override
  String get adminScanStarted => 'Сканирование запущено';

  @override
  String get adminForceRescan => 'Принудительное пересканирование';

  @override
  String get adminFullRescanStarted => 'Полное пересканирование запущено';

  @override
  String get adminCompressImages => 'Сжать изображения';

  @override
  String get adminImageCompressionStarted => 'Сжатие изображений запущено';

  @override
  String get adminScanOptions => 'Параметры сканирования';

  @override
  String get adminScanInterval => 'Интервал сканирования (часы, 0 = выкл.)';

  @override
  String get adminBootScanDelay =>
      'Задержка сканирования при запуске (секунды)';

  @override
  String get adminScanCommitInterval =>
      'Интервал фиксации при сканировании (1–1000)';

  @override
  String get adminScanThreads => 'Потоки сканирования (0 = авто)';

  @override
  String get adminSkipImageExtraction => 'Пропускать извлечение изображений';

  @override
  String get adminCompressEmbeddedImages => 'Сжимать встроенные изображения';

  @override
  String get adminGenerateWaveforms =>
      'Генерировать осциллограммы после сканирования';

  @override
  String get adminAnalyzeBpm =>
      'Анализ BPM/тональности (устарело, не работает)';

  @override
  String get adminAutomaticAlbumArt => 'Автоматическая обложка альбома';

  @override
  String get adminDownloadMissingAlbumArt =>
      'Загружать отсутствующие обложки альбомов';

  @override
  String get adminTargetLabel => 'Цель';

  @override
  String get adminMissingOnly => 'Только отсутствующие';

  @override
  String get adminAllAlbums => 'Все альбомы';

  @override
  String get adminAlbumsPerRun => 'Альбомов за запуск (1–10000)';

  @override
  String get adminAutoDownloadedArtWriteFolder =>
      'Автозагруженная обложка → записывать в папку';

  @override
  String get adminManualArtWriteFolder =>
      'Обложка вручную → записывать в папку';

  @override
  String get adminManualArtEmbedTag =>
      'Обложка вручную → встраивать в тег файла';

  @override
  String get adminArtServices => 'Сервисы обложек';

  @override
  String get adminArtServicesUpdated => 'Сервисы обложек обновлены';

  @override
  String get adminSharedPlaylists => 'Общие плейлисты';

  @override
  String get adminDeleteExpired => 'Удалить просроченные';

  @override
  String get adminExpiredSharesDeleted => 'Просроченные ссылки удалены';

  @override
  String get adminDeleteNeverExpiring => 'Удалить бессрочные';

  @override
  String get adminEternalSharesDeleted => 'Бессрочные ссылки удалены';

  @override
  String get adminNoSharedPlaylists => 'Нет общих плейлистов';

  @override
  String adminSharedPlaylistSubtitle(String user, int count, String expiry) {
    return 'от $user · $count треков · истекает $expiry';
  }

  @override
  String get adminShareDeleted => 'Ссылка удалена';

  @override
  String get adminNetwork => 'Сеть';

  @override
  String get adminNetworkSubtitle =>
      'Изменение этих параметров перезапускает сервер.';

  @override
  String get adminBindAddress => 'Адрес привязки';

  @override
  String get adminPort => 'Порт';

  @override
  String get adminTrustProxyHeaders => 'Доверять заголовкам прокси';

  @override
  String get adminTrustProxyHeadersSubtitle =>
      'Включите при работе за обратным прокси (X-Forwarded-*)';

  @override
  String get adminPermissions => 'Разрешения';

  @override
  String get adminAllowUploads => 'Разрешить загрузки';

  @override
  String get adminAllowMakingDirectories => 'Разрешить создание каталогов';

  @override
  String get adminAllowModifyingFiles => 'Разрешить изменение файлов';

  @override
  String get adminMaxRequestSize => 'Макс. размер запроса';

  @override
  String get adminMaxRequestSizeHelper => 'напр. 50MB или 512KB';

  @override
  String get adminHttpUi => 'HTTP и интерфейс';

  @override
  String get adminResponseCompression => 'Сжатие ответов';

  @override
  String get adminCompressionNone => 'Нет';

  @override
  String get adminCompressionGzip => 'gzip';

  @override
  String get adminCompressionBrotli => 'brotli';

  @override
  String get adminWebUi => 'Веб-интерфейс';

  @override
  String get adminUiDefault => 'По умолчанию';

  @override
  String get adminUiVelvet => 'Velvet';

  @override
  String get adminUiSubsonic => 'Subsonic';

  @override
  String get adminDatabaseTuning => 'Настройка базы данных';

  @override
  String get adminSqliteSynchronous => 'SQLite synchronous';

  @override
  String get adminSyncFull => 'FULL (safest)';

  @override
  String get adminSyncNormal => 'NORMAL (faster)';

  @override
  String get adminCacheSize => 'Размер кэша (МБ, 1–2048)';

  @override
  String get adminLogging => 'Журналирование';

  @override
  String get adminWriteLogsToDisk => 'Записывать журналы на диск';

  @override
  String get adminLogBufferSize =>
      'Размер буфера журнала (0–10000, 0 = отключено)';

  @override
  String get adminServerAudio => 'Аудио на сервере';

  @override
  String get adminAutoBootServerAudio =>
      'Автозапуск аудио на сервере (Rust-плеер)';

  @override
  String get adminRustPlayerPort => 'Порт Rust-плеера';

  @override
  String get adminActiveBackend => 'Активный бэкенд';

  @override
  String get adminPlayer => 'Плеер';

  @override
  String get adminDetectedCliPlayers => 'Обнаруженные CLI-плееры';

  @override
  String get adminNone => 'нет';

  @override
  String get adminReDetectPlayers => 'Повторно обнаружить плееры';

  @override
  String get adminReProbedCliPlayers => 'CLI-плееры обнаружены повторно';

  @override
  String get adminSslHttps => 'SSL / HTTPS';

  @override
  String get adminEnabled => 'Включено';

  @override
  String get adminDisabled => 'Отключено';

  @override
  String get adminReplaceCertificate => 'Заменить сертификат';

  @override
  String get adminSetCertificate => 'Задать сертификат';

  @override
  String get adminSetSslCertificateDialog => 'Задать сертификат SSL';

  @override
  String get adminCertificatePath => 'Путь к сертификату';

  @override
  String get adminKeyPath => 'Путь к ключу';

  @override
  String get adminSslConfigured =>
      'SSL настроен — перезагрузите для применения';

  @override
  String get adminRemoveSsl => 'Удалить SSL';

  @override
  String get adminSslRemoved => 'SSL удалён';

  @override
  String get adminSecurity => 'Безопасность';

  @override
  String get adminJwtSecretLast4 => 'Секрет JWT (последние 4)';

  @override
  String get adminRegenerateSecret => 'Перегенерировать секрет';

  @override
  String get adminSecretRegenerated =>
      'Секрет перегенерирован — все сессии сброшены';

  @override
  String get adminRegenerateJwtSecretDialog => 'Перегенерировать секрет JWT?';

  @override
  String get adminRegenerateJwtSecretDialogBody =>
      'Это сбросит все существующие входы (включая текущий). Всем потребуется войти заново.';

  @override
  String get adminRegenerateButton => 'Перегенерировать';

  @override
  String get adminAllNetworks => 'Все сети';

  @override
  String get adminLocalhostOnly => 'Только localhost';

  @override
  String get adminIpWhitelist => 'Белый список IP';

  @override
  String get adminNoneLockAdmin => 'Нет (заблокировать админ)';

  @override
  String get adminNetworkAccess => 'Сетевой доступ';

  @override
  String get adminNetworkAccessSubtitle =>
      'Ограничьте, из каких сетей доступен admin API.';

  @override
  String get adminMode => 'Режим';

  @override
  String get adminWhitelistedIps => 'IP / CIDR в белом списке';

  @override
  String get adminNoneYet => 'Пока нет';

  @override
  String get adminAddIpOrCidr => 'Добавить IP или CIDR';

  @override
  String get adminCidrExample => '192.168.1.0/24';

  @override
  String get adminApply => 'Применить';

  @override
  String get adminDangerZone => 'Опасная зона';

  @override
  String get adminLockAdminApi => 'Заблокировать admin API';

  @override
  String get adminLockAdminApiSubtitle =>
      'Отключить весь admin API. Отменить отсюда нельзя.';

  @override
  String get adminLockButton => 'Заблокировать';

  @override
  String get adminLockAdminApiDialog => 'Заблокировать admin API?';

  @override
  String get adminLockAdminApiDialogBody =>
      'Это отключит весь admin API /admin для всех. Отменить из этой панели будет нельзя — потребуется отредактировать файл конфигурации сервера и перезапустить его. Продолжить?';

  @override
  String get adminAdminApiLocked => 'Admin API заблокирован';

  @override
  String get adminAccessUpdated => 'Доступ администратора обновлён';

  @override
  String get adminTranscodingFFmpegTitle => 'FFmpeg';

  @override
  String get adminFFmpegStatusReady => 'Готов';

  @override
  String get adminFFmpegStatusNotDownloaded => 'Не загружен';

  @override
  String get adminFFmpegDownloadButton => 'Загрузить / обновить ffmpeg';

  @override
  String get adminFFmpegDownloadedToast => 'ffmpeg загружен';

  @override
  String get adminFFmpegAutoUpdateTitle => 'Автообновление ffmpeg';

  @override
  String get adminFFmpegAutoUpdateSubtitle =>
      'Автоматически поддерживать встроенный ffmpeg в актуальном состоянии';

  @override
  String get adminTranscodingDefaultsTitle => 'По умолчанию';

  @override
  String get adminDefaultCodecLabel => 'Кодек по умолчанию';

  @override
  String get adminDefaultBitrateLabel => 'Битрейт по умолчанию';

  @override
  String get adminLogsResumeButton => 'Возобновить';

  @override
  String get adminLogsPauseButton => 'Пауза';

  @override
  String get adminClear => 'Очистить';

  @override
  String get adminLogsAutoScrollTitle => 'Автопрокрутка';

  @override
  String adminLogsLineCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count строк',
      one: '1 строка',
    );
    return '$_temp0';
  }

  @override
  String get adminLogsDownloadZipButton => 'Скачать zip';

  @override
  String get adminLogsNoEntriesHint => 'Записей в журнале пока нет';

  @override
  String get adminDlnaModeDisabled => 'Отключено';

  @override
  String get adminSamePortAsHttp => 'Тот же порт, что и HTTP';

  @override
  String get adminSeparatePort => 'Отдельный порт';

  @override
  String get adminDlnaBrowseFlat => 'Плоский (все треки)';

  @override
  String get adminDlnaBrowseDirectories => 'Каталоги';

  @override
  String get adminDlnaBrowseArtist => 'По исполнителю';

  @override
  String get adminDlnaBrowseAlbum => 'По альбому';

  @override
  String get adminDlnaBrowseGenre => 'По жанру';

  @override
  String get adminDlnaServerTitle => 'Сервер';

  @override
  String get adminDlnaIdentityTitle => 'Идентификация';

  @override
  String get adminDlnaFriendlyNameLabel => 'Понятное имя';

  @override
  String get adminDlnaDeviceUuidLabel => 'UUID устройства';

  @override
  String get adminDlnaDeviceUuidHelper => 'Канонический GUID';

  @override
  String get adminDlnaBrowseLayoutTitle => 'Структура обзора';

  @override
  String get adminDlnaStructureLabel => 'Структура';

  @override
  String get adminMdnsLocalNetworkDiscoveryTitle =>
      'Обнаружение в локальной сети';

  @override
  String get adminMdnsLocalNetworkDiscoverySubtitle =>
      'Объявляет этот сервер как mDNS-сервис _mstream._tcp. Публикует только метаданные — не раскрывает данные библиотеки и не открывает новые маршруты.';

  @override
  String get adminMdnsEnableAdvertisingTitle => 'Включить объявление';

  @override
  String get adminMdnsFriendlyNameLabel => 'Понятное имя';

  @override
  String get adminMdnsFriendlyNameHelper =>
      'Пусто = вывести из имени хоста (макс. 63 байта)';

  @override
  String get adminMdnsInstanceIdLabel => 'ID экземпляра';

  @override
  String get adminSubsonicApiTitle => 'Subsonic API';

  @override
  String get adminTestConnection => 'Проверить соединение';

  @override
  String adminSubsonicTestSuccess(String version, String latency) {
    return 'OK · $version · $latency мс';
  }

  @override
  String adminSubsonicTestFailed(String reason) {
    return 'Ошибка: $reason';
  }

  @override
  String get adminStatus => 'Статус';

  @override
  String get adminMethodsImplemented => 'Реализовано методов';

  @override
  String get adminFullStub => 'Полные / заглушки';

  @override
  String get adminNowPlaying => 'Сейчас играет';

  @override
  String get adminNobody => 'никто';

  @override
  String get adminLyricsLrclib => 'Тексты (LRCLib)';

  @override
  String get adminLrclibFallback => 'Резервный LRCLib';

  @override
  String get adminWriteLrcSidecarFiles => 'Записывать файлы .lrc рядом';

  @override
  String get adminCache => 'Кэш';

  @override
  String get adminPurgeCache => 'Очистить кэш';

  @override
  String get adminLyricsCachePurged => 'Кэш текстов очищен';

  @override
  String get adminRetryFailed => 'Повторить неудачные';

  @override
  String get adminTransientLyricsEntriesCleared =>
      'Временные записи текстов очищены';

  @override
  String get adminJukebox => 'Jukebox';

  @override
  String get adminAvailable => 'Доступен';

  @override
  String get adminUnavailable => 'Недоступен';

  @override
  String get adminState => 'Состояние';

  @override
  String get adminPlaying => 'воспроизведение';

  @override
  String get adminPaused => 'пауза';

  @override
  String get adminIdle => 'бездействие';

  @override
  String get adminCurrent => 'Текущий';

  @override
  String get adminQueue => 'Очередь';

  @override
  String adminQueueTracks(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count треков',
      one: '1 трек',
    );
    return '$_temp0';
  }

  @override
  String get adminVolume => 'Громкость';

  @override
  String adminVolumePercent(int percent) {
    return '$percent%';
  }

  @override
  String get adminTokenAuthFailures => 'Сбои токен-авторизации';

  @override
  String get adminTokenAuthFailuresSubtitle =>
      'Клиенты, использующие токен-авторизацию без пароля Subsonic.';

  @override
  String get adminNoRecentFailures => 'Недавних сбоев нет';

  @override
  String get adminCleared => 'Очищено';

  @override
  String get adminMintApiKey => 'Создать API-ключ';

  @override
  String get adminMintApiKeySubtitle =>
      'Сгенерировать apiKey Subsonic для пользователя (показывается один раз).';

  @override
  String get adminKeyNameLabel => 'Имя / метка ключа';

  @override
  String get adminMintKey => 'Создать ключ';

  @override
  String get adminUsernameAndNameRequired => 'Требуется имя пользователя и имя';

  @override
  String get adminTorrentClient => 'Клиент';

  @override
  String get adminActiveClient => 'Активный клиент';

  @override
  String get adminTransmission => 'Transmission';

  @override
  String get adminQbittorrent => 'qBittorrent';

  @override
  String get adminDeluge => 'Deluge';

  @override
  String get adminEnabledFor => 'Включено для';

  @override
  String get adminAllUsers => 'Все пользователи';

  @override
  String get adminWhitelistedUsers => 'Пользователи из белого списка';

  @override
  String get adminHost => 'Хост';

  @override
  String get adminPasswordUnchangedIfBlank => 'не изменится, если пусто';

  @override
  String get adminRpcPath => 'Путь RPC';

  @override
  String get adminUseHttps => 'Использовать HTTPS';

  @override
  String get adminTest => 'Проверить';

  @override
  String adminReachable(String version) {
    return 'Доступен$version';
  }

  @override
  String adminConnectionFailed(String error) {
    return 'Ошибка: $error';
  }

  @override
  String get adminConnectAndSave => 'Подключить и сохранить';

  @override
  String adminSaveFailed(String error) {
    return 'Ошибка: $error';
  }

  @override
  String get adminConnectedAndSaved => 'Подключено и сохранено';

  @override
  String get adminDisconnect => 'Отключить';

  @override
  String get adminDisconnected => 'Отключено';

  @override
  String get adminConfigured => 'Настроен';

  @override
  String get adminNotConfigured => 'Не настроен';

  @override
  String get adminTorrents => 'Торренты';

  @override
  String get adminConnected => 'Подключён';

  @override
  String get adminNoTorrents => 'Нет торрентов';

  @override
  String get adminMstream => 'mStream';

  @override
  String get adminTorrentRemoved => 'Торрент удалён';

  @override
  String get adminLibraryDaemonPathMapping =>
      'Сопоставление путей библиотека → демон';

  @override
  String get adminLibraryDaemonPathMappingSubtitle =>
      'Сопоставляет каждую библиотеку с её путём, каким его видит торрент-демон.';

  @override
  String get adminAutoDetectAll => 'Определить всё автоматически';

  @override
  String get adminAutoDetectionComplete => 'Автоопределение завершено';

  @override
  String get adminVerified => 'проверено';

  @override
  String get adminUnverified => 'не проверено';

  @override
  String get adminSetManually => 'Задать вручную';

  @override
  String adminDaemonPathFor(String name) {
    return 'Путь демона для «$name»';
  }

  @override
  String get adminPathOnDaemonHost => 'Путь на хосте демона';

  @override
  String get adminVerifyAndSave => 'Проверить и сохранить';

  @override
  String get adminVpathVerified => 'Проверено';

  @override
  String get adminVpathSavedUnverified => 'Сохранено (не проверено)';

  @override
  String get adminDownloadPathTemplates => 'Шаблоны путей загрузки';

  @override
  String adminPathTemplateVars(String vars) {
    return 'Переменные: $vars';
  }

  @override
  String get adminNoLibraries => 'Нет библиотек';

  @override
  String adminSuggestedTemplate(String template) {
    return 'Рекомендуется: $template';
  }

  @override
  String get adminTemplateSaved => 'Шаблон сохранён';

  @override
  String get adminNoBackupDestinations => 'Нет назначений для резервных копий';

  @override
  String get adminBackupDestinationInfo =>
      'Добавьте назначение, чтобы зеркалировать библиотеку в другую папку.';

  @override
  String get adminAddDestination => 'Добавить назначение';

  @override
  String get adminAddLibraryFirst => 'Сначала добавьте библиотеку';

  @override
  String get adminBackupQueue => 'Очередь резервного копирования';

  @override
  String adminTasksQueued(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count задач в очереди',
      one: '1 задача в очереди',
    );
    return '$_temp0';
  }

  @override
  String adminBackingUp(String library) {
    return 'Резервное копирование: $library';
  }

  @override
  String get adminRunning => 'выполняется';

  @override
  String adminBackupStats(int done, String total, String stats) {
    return '$done файлов$total$stats';
  }

  @override
  String get adminBackupDisabled => 'отключено';

  @override
  String get adminDestination => 'Назначение';

  @override
  String get adminTrigger => 'Триггер';

  @override
  String adminDailyTriggerTime(String trigger, String hour) {
    return '$trigger в $hour:00';
  }

  @override
  String get adminRetention => 'Хранение';

  @override
  String adminRetentionDays(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count дней',
      one: '1 день',
    );
    return '$_temp0';
  }

  @override
  String get adminLastRun => 'Последний запуск';

  @override
  String adminLastRunStatus(String status, int files) {
    return '$status · скопировано $files';
  }

  @override
  String get adminRunNow => 'Запустить сейчас';

  @override
  String get adminBackupQueued => 'Резервная копия поставлена в очередь';

  @override
  String get adminAlreadyRunningSkipped => 'Уже выполняется — пропущено';

  @override
  String get adminHistory => 'История';

  @override
  String get adminEdit => 'Изменить';

  @override
  String get adminDestinationDeleted => 'Назначение удалено';

  @override
  String get adminBackupHistory => 'История резервного копирования';

  @override
  String get adminNoHistoryYet => 'Истории пока нет';

  @override
  String get adminEditDestination => 'Изменить назначение';

  @override
  String get adminAddBackupDestination => 'Добавить назначение резервной копии';

  @override
  String get adminDestinationPath => 'Путь назначения';

  @override
  String get adminBrowseServer => 'Обзор сервера';

  @override
  String get adminCheckPath => 'Проверить путь';

  @override
  String get adminTriggerField => 'Триггер';

  @override
  String get adminAfterEachScan => 'После каждого сканирования';

  @override
  String get adminDaily => 'Ежедневно';

  @override
  String get adminManualOnly => 'Только вручную';

  @override
  String get adminRunAtHour => 'Запускать в час: ';

  @override
  String get adminRetentionFieldLabel => 'Хранение (дни, 0 = хранить всё)';

  @override
  String get adminEnabledToggle => 'Включено';

  @override
  String get adminDestinationUpdated => 'Назначение обновлено';

  @override
  String get adminDestinationCreated => 'Назначение создано';

  @override
  String get adminPickLibrary => 'Выберите библиотеку';

  @override
  String get adminPickDestinationPath => 'Выберите путь назначения';

  @override
  String adminAboutTitle(String version) {
    return 'mStream v$version';
  }

  @override
  String get adminAboutPort => 'Порт';

  @override
  String get adminSSL => 'SSL';

  @override
  String get adminUI => 'Интерфейс';

  @override
  String get adminCompression => 'Сжатие';

  @override
  String get adminTrustProxy => 'Доверять прокси';

  @override
  String get adminYes => 'Да';

  @override
  String get adminNo => 'Нет';

  @override
  String get adminSecretLast4 => 'Секрет (последние 4)';

  @override
  String get adminUploads => 'Загрузки';

  @override
  String get adminMakeDirs => 'Создание каталогов';

  @override
  String get adminFileModify => 'Изменение файлов';

  @override
  String get adminSynchronous => 'Synchronous';

  @override
  String get adminCacheSizeLabel => 'Размер кэша';

  @override
  String adminCacheSizeMb(int size) {
    return '$size МБ';
  }

  @override
  String get adminFederationUnavailable => 'Недоступно';

  @override
  String get adminFederationDescription =>
      'Федерация перестраивается под новый подход к локальному резервному копированию и сейчас недоступна на сервере. Конечная точка остаётся подключённой, чтобы старые клиенты получали понятный статус, а не ошибку 404.';

  @override
  String get adminCheckStatus => 'Проверить статус';

  @override
  String get adminAllowed => 'Разрешено';

  @override
  String get adminBackupEnabled => 'включено';

  @override
  String get adminNotAvailable => 'Недоступно';

  @override
  String get adminNotMapped => 'не сопоставлено';

  @override
  String get adminExpiryNever => 'никогда';

  @override
  String get adminUnknownUser => 'неизвестно';
}
