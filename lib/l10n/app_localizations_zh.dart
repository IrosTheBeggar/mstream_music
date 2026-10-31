// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Chinese (`zh`).
class AppLocalizationsZh extends AppLocalizations {
  AppLocalizationsZh([String locale = 'zh']) : super(locale);

  @override
  String get mainRemove => '移除';

  @override
  String get playlistActionFailed => '无法保存播放列表 — 该名称可能已被使用。';

  @override
  String get queueAddNext => '添加为下一首';

  @override
  String get queuePlayNow => '立即播放';

  @override
  String get queueAddToEnd => '添加到队列末尾';

  @override
  String get shuffle => '随机播放';

  @override
  String get variousArtists => '群星';

  @override
  String get appTitle => 'mStream Music';

  @override
  String get settingsLanguage => '语言';

  @override
  String get languageSystemDefault => '跟随系统';

  @override
  String couldNotOpen(String url) {
    return '无法打开 $url';
  }

  @override
  String trackCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count 首曲目',
      zero: '没有曲目',
    );
    return '$_temp0';
  }

  @override
  String get reset => '重置';

  @override
  String get themeVelvet => 'Velvet';

  @override
  String get themeDark => '深色';

  @override
  String get themeLight => '浅色';

  @override
  String get tapAddToQueue => '添加到队列';

  @override
  String get tapPlayFromHere => '从此处播放';

  @override
  String get tapAppendAndJump => '添加并播放';

  @override
  String get visualizerSourceSynthesized => '合成';

  @override
  String get visualizerSourceReal => '真实音频';

  @override
  String get downloadsTitle => '下载';

  @override
  String downloadProgress(String progress) {
    return '进度：$progress%';
  }

  @override
  String get songInfoTitle => '歌曲信息';

  @override
  String get lyricsTitle => '歌词';

  @override
  String get lyricsEmpty => '未找到这首歌曲的歌词';

  @override
  String get lyricsError => '无法加载歌词';

  @override
  String get lyricsRetry => '重试';

  @override
  String get eqTitle => '均衡器';

  @override
  String get eqOnlyAndroid => '均衡器仅在 Android 上可用。';

  @override
  String get eqNeedsPlayback => '本机的均衡器只有在播放音频时才会报告频段。频段出现后，会立即应用你保存的预设。';

  @override
  String eqInitFailed(String error) {
    return '无法初始化均衡器：\n$error';
  }

  @override
  String get eqNoBands => '此设备的音频驱动未报告任何均衡器频段。';

  @override
  String get eqPresetFlat => '平坦';

  @override
  String get eqPresetNormal => '普通';

  @override
  String get eqPresetClassical => '古典';

  @override
  String get eqPresetDance => '舞曲';

  @override
  String get eqPresetFolk => '民谣';

  @override
  String get eqPresetHeavyMetal => '重金属';

  @override
  String get eqPresetHipHop => '嘻哈';

  @override
  String get eqPresetJazz => '爵士';

  @override
  String get eqPresetPop => '流行';

  @override
  String get eqPresetRock => '摇滚';

  @override
  String get eqPresetCustom => '自定义';

  @override
  String get eqSaveAsPreset => '保存为预设';

  @override
  String get eqSavePresetTitle => '保存预设';

  @override
  String get eqRenamePresetTitle => '重命名预设';

  @override
  String get eqPresetNameLabel => '名称';

  @override
  String get eqSavePresetHint => '保存在本机上，排在内置预设之后。之后长按它的标签即可重命名或删除。';

  @override
  String get eqReplacePreset => '替换';

  @override
  String get eqPresetNameTaken => '另一个已保存的预设已使用此名称。';

  @override
  String eqDeletePresetConfirm(String name) {
    return '删除“$name”？';
  }

  @override
  String get eqHoldToCompare => '按住对比';

  @override
  String get eqHoldToCompareHint => '按住即可聆听不经均衡器处理的声音。';

  @override
  String get eqOptionsTitle => '均衡器选项';

  @override
  String get eqPreventClipping => '防止削波';

  @override
  String get eqPreventClippingHint => '在频段被提升时限制峰值。';

  @override
  String get eqShowValues => '始终显示频段数值';

  @override
  String get eqShowValuesHint => '在每个频段上方显示数值，而不只是拖动时。';

  @override
  String get eqOutputsTitle => '输出设备';

  @override
  String get eqOutputsRowOff => '已关闭 — 所有输出设备共用一条曲线';

  @override
  String eqOutputsNow(String name) {
    return '当前：$name';
  }

  @override
  String get eqOutputsSwitch => '自动切换';

  @override
  String get eqOutputsSwitchHint => '输出设备变化时，会应用它的曲线。在均衡器页面拖动，编辑的是正在播放的输出设备。';

  @override
  String get eqOutputsRemembered => '已记住的输出设备';

  @override
  String get eqOutputSpeaker => '手机扬声器';

  @override
  String get eqOutputWired => '有线耳机';

  @override
  String get eqOutputUsb => 'USB 音频';

  @override
  String get eqOutputHdmi => 'HDMI';

  @override
  String get eqOutputBluetooth => '蓝牙';

  @override
  String get eqOutputOther => '其他输出设备';

  @override
  String get eqOutputPlayingNow => '正在播放';

  @override
  String eqOutputLastUsed(String date) {
    return '上次使用 $date';
  }

  @override
  String get eqOutputsEmpty => '用某个输出设备听过后，它会出现在这里。';

  @override
  String eqOutputForgetConfirm(String name) {
    return '忘记“$name”？下次连接时它会作为新设备再次出现。';
  }

  @override
  String get eqOutputForget => '忘记';

  @override
  String eqOutputPickPreset(String name) {
    return '$name 的预设';
  }

  @override
  String get eqOutputsHint => '点按输出设备可选择其预设。向左滑动可忘记它。';

  @override
  String eqEnabledOnOutput(String name) {
    return '已开启 — $name';
  }

  @override
  String get eqOutputNowPill => '当前';

  @override
  String get eqNeedsPlaybackTitle => '播放一首歌曲即可设置频段';

  @override
  String get eqPlayQueue => '播放队列';

  @override
  String eqPlayQueueHint(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count 首歌曲',
    );
    return '从上次停下的地方继续 · $_temp0';
  }

  @override
  String get eqDisabledHint => '开启均衡器以调整频段。';

  @override
  String get eqEnabledOn => '开启 — 增益已应用到播放';

  @override
  String get eqEnabledOff => '关闭 — 旁路模式';

  @override
  String get cancel => '取消';

  @override
  String get continueLabel => '继续';

  @override
  String get openSettings => '打开设置';

  @override
  String get settingsTitle => '设置';

  @override
  String get settingsSectionAppearance => '外观';

  @override
  String get settingsSectionPlayback => '播放';

  @override
  String get settingsSectionBrowse => '曲库';

  @override
  String get settingsTheme => '主题';

  @override
  String get settingsTranscode => '音频转码';

  @override
  String get settingsTranscodeSubtitle =>
      '从服务器以转码副本进行流式播放（文件更小，启动略慢）。关闭时播放原始文件。';

  @override
  String get transcodeTitle => '转码';

  @override
  String get transcodeCodec => '编解码器';

  @override
  String get transcodeBitrate => '比特率';

  @override
  String get transcodeAuto => '服务器默认';

  @override
  String get transcodeUnavailable => '此服务器未启用转码，其曲目将以原始质量流式传输。';

  @override
  String get transcodeReloadQueue => '应用到当前队列';

  @override
  String get transcodeReloadQueueSubtitle =>
      '更改转码设置时 — 勾选：立即重新加载整个队列（正在播放的曲目会短暂缓冲）；取消勾选：仅更改后续曲目，当前曲目将按原样播放完毕。';

  @override
  String get settingsTapBehavior => '点击歌曲时';

  @override
  String get settingsStartupPage => '启动页面';

  @override
  String get tapSubtitleAddToQueue => '添加到队列末尾';

  @override
  String get tapSubtitlePlayFromHere => '替换队列并从这首歌开始播放';

  @override
  String get tapSubtitleAppendAndJump => '添加到队列末尾并立即播放';

  @override
  String get settingsVisualizerSource => '音频来源';

  @override
  String get visualizerSourceSubtitleSynthesized => '无需权限';

  @override
  String get visualizerSourceSubtitleReal => '需要麦克风权限，但绝不会使用麦克风';

  @override
  String get settingsAlbumGrid => '专辑网格';

  @override
  String get settingsFileMetadata => '文件浏览器中的歌曲信息';

  @override
  String get settingsLetterStrip => '字母滚动条';

  @override
  String get settingsLetterStripSide => '位置';

  @override
  String get settingsLetterStripLeft => '左侧';

  @override
  String get settingsLetterStripRight => '右侧';

  @override
  String get settingsReset => '重置设置';

  @override
  String get settingsResetDone => '设置已重置';

  @override
  String get realAudioDialogTitle => '使用真实音频？';

  @override
  String get realAudioDialogBody =>
      '为了随正在播放的歌曲做出反应，可视化效果会读取 mStream 自身的音频输出，而 Android 只有在获得麦克风权限后才允许这样做。';

  @override
  String get realAudioPermPermanentlyDenied => '权限已被永久拒绝。请在系统设置中启用它以使用真实音频。';

  @override
  String get realAudioPermDenied => '权限被拒绝。将继续使用合成音频。';

  @override
  String get visualizerTapHint => '点击 = 下一个预设 · 左上角返回箭头或长按可退出';

  @override
  String get visualizerFailed => '可视化启动失败';

  @override
  String get visualizerBringingUp => '正在启动渲染器…';

  @override
  String get visualizerReady => '可视化已就绪';

  @override
  String get visualizerBridgeFailed => '桥接启动失败';

  @override
  String visualizerAudioSourceLine(String source) {
    return '音频来源：$source';
  }

  @override
  String get visualizerTapToClose => '点击任意位置关闭';

  @override
  String get visualizerClose => '关闭可视化';

  @override
  String get visualizerPreviousPreset => '上一个预设';

  @override
  String get visualizerNextPreset => '下一个预设';

  @override
  String get visualizerUnsupported => '可视化目前仅支持 Android。';

  @override
  String get aboutTitle => '关于';

  @override
  String aboutBuiltBy(String name) {
    return '由 $name 开发';
  }

  @override
  String get linkDiscordSubtitle => '社区聊天';

  @override
  String get linkGithubSubtitle => 'mStream 服务器源代码';

  @override
  String get linkHomepageSubtitle => '项目主页';

  @override
  String get aboutAttributions => '致谢';

  @override
  String get aboutAttributionsSubtitle => '许可证、着色器致谢和开源声明。';

  @override
  String get aboutSponsor => '赞助 mStream';

  @override
  String get ok => '确定';

  @override
  String get delete => '删除';

  @override
  String get edit => '编辑';

  @override
  String get info => '信息';

  @override
  String get makeDefault => '设为默认';

  @override
  String get goBack => '返回';

  @override
  String get play => '播放';

  @override
  String get playAll => '全部播放';

  @override
  String get rename => '重命名';

  @override
  String get create => '创建';

  @override
  String get copy => '复制';

  @override
  String get done => '完成';

  @override
  String get copiedToClipboard => '已复制到剪贴板';

  @override
  String get attributionsTitle => '致谢';

  @override
  String get attributionsSectionLicense => '许可证';

  @override
  String get attributionsSectionShaders => '可视化着色器';

  @override
  String get attributionsSectionLibraries => '原生库';

  @override
  String get attributionsSectionEverythingElse => '其他';

  @override
  String get attributionsLicenseBody =>
      '依据 GNU 通用公共许可证 v3.0（GPL v3.0）发布的自由软件。你可以在该许可证条款下使用、研究、分享和修改它。';

  @override
  String get attributionsPackages => '开源软件包许可证';

  @override
  String get attributionsPackagesSubtitle => '所有捆绑的 Flutter/Dart 软件包的完整许可证文本。';

  @override
  String get manageServersTitle => '管理服务器';

  @override
  String get manageServerInfo => '服务器信息';

  @override
  String get manageServerDownloadFolder => '下载文件夹：';

  @override
  String get manageServerCopyPath => '复制下载路径';

  @override
  String get manageServerPathCopied => '路径已复制到剪贴板';

  @override
  String get confirmRemoveServerTitle => '确认移除服务器';

  @override
  String get removeSyncedFiles => '从设备中移除已同步的文件？';

  @override
  String get playlistsTitle => '播放列表';

  @override
  String get playlistsNew => '新建播放列表';

  @override
  String get playlistsEmptyTitle => '还没有播放列表';

  @override
  String get playlistsEmptyBody =>
      '使用“新建播放列表”按钮创建一个，然后在队列中使用“添加到播放列表”滑动操作来填充它。';

  @override
  String get playlistNameHint => '名称';

  @override
  String get playlistsRename => '重命名播放列表';

  @override
  String get playlistFallbackTitle => '播放列表';

  @override
  String get playlistEmptyDetail => '播放列表为空。\n通过队列添加曲目。';

  @override
  String get shareEmptyTitle => '队列为空';

  @override
  String get shareEmptyBody => '分享前请先向队列添加歌曲。';

  @override
  String get shareBlockedTitle => '无法分享此队列';

  @override
  String get shareLocalOnlyBody =>
      '队列中包含仅存在于此设备上的歌曲（不在任何服务器上）。仅当队列中的每首歌曲都来自同一服务器时才能分享。';

  @override
  String shareMultiServerBody(int count, String names) {
    return '队列中混合了来自 $count 个服务器（$names）的歌曲。仅当所有歌曲都来自同一服务器时才能分享。';
  }

  @override
  String shareServerGoneBody(String name) {
    return '服务器“$name”已不在你的服务器列表中。请重新添加它以分享其队列。';
  }

  @override
  String get shareTitle => '分享播放列表';

  @override
  String shareSongCount(int count, String url) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '来自 $url 的 $count 首歌曲',
    );
    return '$_temp0';
  }

  @override
  String get shareLinkExpires => '链接过期时间';

  @override
  String get shareExpireNever => '永不';

  @override
  String get shareExpire1Day => '1 天后';

  @override
  String get shareExpire7Days => '7 天后';

  @override
  String get shareExpire30Days => '30 天后';

  @override
  String get shareAction => '分享';

  @override
  String get shareDoneTitle => '播放列表已分享';

  @override
  String get shareDoneBody => '任何拥有此链接的人都可以播放该队列：';

  @override
  String get save => '保存';

  @override
  String get start => '开始';

  @override
  String get addServerTitle => '添加服务器';

  @override
  String get editServerTitle => '编辑服务器';

  @override
  String get fieldServerUrl => '服务器地址';

  @override
  String get fieldPublicAccess => '公开访问';

  @override
  String get publicAccessSubtitle => '服务器可公开访问 — 无需用户名或密码。';

  @override
  String get fieldUsername => '用户名';

  @override
  String get fieldPassword => '密码';

  @override
  String get fieldPasswordShow => '显示密码';

  @override
  String get fieldPasswordHide => '隐藏密码';

  @override
  String get fieldSdCard => '下载到 SD 卡';

  @override
  String get sdCardSubtitle => '将下载的音乐保存到可移动 SD 卡，而非内部存储。';

  @override
  String get testConnectionButton => '测试连接';

  @override
  String get testing => '正在测试…';

  @override
  String get connecting => '正在连接…';

  @override
  String get validatorUrlNeeded => '需要服务器地址';

  @override
  String get validatorUrlParse => '无法解析地址';

  @override
  String get testEnterUrl => '请先输入服务器地址。';

  @override
  String get testParseUrl => '无法解析地址。';

  @override
  String get testTimedOut => '连接超时。';

  @override
  String get connectionSuccessful => '连接成功！';

  @override
  String get couldNotReachServer => '无法访问服务器。如果需要登录，请关闭“公开访问”并添加凭据。';

  @override
  String get failedToLogin => '登录失败';

  @override
  String testConnected(String version) {
    return '已连接 — mStream v$version';
  }

  @override
  String testConnectFailed(String error) {
    return '无法连接：$error';
  }

  @override
  String get sleepTimerTitle => '睡眠定时器';

  @override
  String get sleepTimerHint => '选择多长时间后暂停播放。';

  @override
  String get sleepTimerCustom => '自定义';

  @override
  String get sleepTimerCustomHint => '分钟（1–600）';

  @override
  String get sleepTimerCancel => '取消定时器';

  @override
  String get sleepTimerInvalid => '请输入 1 到 600 之间的分钟数';

  @override
  String sleepTimerPausesIn(String time) {
    return '将在 $time 后暂停';
  }

  @override
  String sleepTimerMinutes(int minutes) {
    return '$minutes 分钟';
  }

  @override
  String sleepTimerSet(int minutes) {
    String _temp0 = intl.Intl.pluralLogic(
      minutes,
      locale: localeName,
      other: '睡眠定时器已设为 $minutes 分钟',
    );
    return '$_temp0';
  }

  @override
  String get add => '添加';

  @override
  String get autoDjTitle => 'Auto DJ';

  @override
  String autoDjSongsPerFetchValue(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count 首歌',
      one: '1 首歌',
    );
    return '$_temp0';
  }

  @override
  String autoDjBpmTolerance(int bpm) {
    return '± $bpm BPM';
  }

  @override
  String get autoDjHarmonicTitle => '和声混音';

  @override
  String get autoDjHarmonicHint => '下一首选调性相合的歌曲';

  @override
  String get autoDjDurationRange => '时长';

  @override
  String get autoDjMoodTitle => '智能筛选';

  @override
  String get autoDjGenreLoadError => '无法加载流派';

  @override
  String get download => '下载';

  @override
  String get addAll => '全部添加';

  @override
  String get browserMoreActions => '更多操作';

  @override
  String get browserConfirmDeletePlaylist => '确认删除播放列表';

  @override
  String get browserConfirmDeleteFolder => '确认删除文件夹';

  @override
  String get browserSearchHint => '搜索数据库';

  @override
  String get searchCategoriesTooltip => '选择搜索范围';

  @override
  String get searchCategoriesHeader => '搜索范围';

  @override
  String get searchCategoryArtists => '艺术家';

  @override
  String get searchCategoryAlbums => '专辑';

  @override
  String get searchCategorySongs => '歌曲';

  @override
  String get searchCategoryFiles => '文件';

  @override
  String get searchCategoryLyrics => '歌词';

  @override
  String searchSubheaderResults(String term) {
    return '“$term”的搜索结果';
  }

  @override
  String searchSubheaderCategories(String categories) {
    return '搜索范围：$categories';
  }

  @override
  String browserDownloadsStarted(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '已开始 $count 项下载',
    );
    return '$_temp0';
  }

  @override
  String browserSongsAdded(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '已将 $count 首歌曲添加到队列',
    );
    return '$_temp0';
  }

  @override
  String get tabBrowser => '浏览';

  @override
  String get tabQueue => '队列';

  @override
  String get drawerTagline => '个人音乐流媒体';

  @override
  String get mainFailedToConnect => '连接服务器失败';

  @override
  String get mainQueueEmpty => '队列为空';

  @override
  String get queueEmptyDjHint => 'Auto DJ 已开启，需要一首起始曲目。';

  @override
  String get queueEmptyDjRandom => '随机选一首';

  @override
  String get queueEmptyDjChoose => '选择曲目';

  @override
  String get mainClearQueue => '清空队列';

  @override
  String get mainSync => '同步';

  @override
  String mainQueueCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count 首曲目',
    );
    return '$_temp0';
  }

  @override
  String get autoDjEnabled => 'Auto DJ 已开启';

  @override
  String get autoDjDisabled => 'Auto DJ 已关闭';

  @override
  String autoDjEnabledFor(String url) {
    return '已为 $url 开启 Auto DJ';
  }

  @override
  String get addToPlaylistTitle => '添加到播放列表';

  @override
  String get addToPlaylistEmpty => '还没有播放列表 — 点击 + 创建一个。';

  @override
  String addedToPlaylist(String name) {
    return '已添加到 $name';
  }

  @override
  String get testConnectedSignedIn => '已连接 — 登录成功。';

  @override
  String get testSignInFailed => '已连接到服务器，但登录失败 — 请检查用户名和密码。';

  @override
  String get browserFileExplorer => '文件浏览器';

  @override
  String get browserLocalFiles => '本地文件';

  @override
  String get browserPlaylists => '播放列表';

  @override
  String get browserAlbums => '专辑';

  @override
  String get browserArtists => '艺术家';

  @override
  String get browserGenres => '流派';

  @override
  String get genreSourceTags => '标签';

  @override
  String get genreSourceGenerated => '自动生成';

  @override
  String get genreSourceBoth => '全部';

  @override
  String get genreSourceMixed => '混合';

  @override
  String get genreSourceLabel => '流派来源';

  @override
  String get moodFilters => '筛选';

  @override
  String get moodValenceGroup => '欢快、中性或悲伤';

  @override
  String get moodEnergyGroup => '放松、中性或激烈';

  @override
  String get moodVoiceGroup => '纯音乐或人声';

  @override
  String get moodTagsGroup => '标签';

  @override
  String get moodHappy => '欢快';

  @override
  String get moodNeutral => '中性';

  @override
  String get moodSad => '悲伤';

  @override
  String get moodRelaxed => '放松';

  @override
  String get moodAggressive => '激烈';

  @override
  String get moodInstrumental => '纯音乐';

  @override
  String get moodVocals => '人声';

  @override
  String get moodAcoustic => '原声';

  @override
  String get moodParty => '派对';

  @override
  String get moodDanceable => '适合跳舞';

  @override
  String get browserRecent => '最近添加';

  @override
  String get browserRated => '已评分';

  @override
  String get browserSectionLibrary => '曲库';

  @override
  String get browserSectionListen => '聆听';

  @override
  String get browserSectionNetwork => '网络';

  @override
  String get browserSectionServer => '服务器';

  @override
  String get browserFederation => '联合';

  @override
  String get browserAutoDjOn => '已开启';

  @override
  String get browserAutoDjOff => '已关闭';

  @override
  String browserSharedLibraries(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count 个共享曲库',
    );
    return '$_temp0';
  }

  @override
  String get browserSearch => '搜索';

  @override
  String get browserWelcomeTitle => '欢迎使用 mStream';

  @override
  String get browserWelcomeSubtitle => '点击这里添加服务器';

  @override
  String get settingsVisualizerKnobs => '调节滑块';

  @override
  String get settingsVisualizerKnobsSubtitle => '仅限 ShaderToy';

  @override
  String get visualizerTuningTitle => '调节';

  @override
  String get close => '关闭';

  @override
  String get migMoveStopped => '移动已停止 — 空间不足，或该位置不可用。';

  @override
  String get migMoveComplete => '移动完成';

  @override
  String migMoveCompleteSkipped(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '移动完成 — 已跳过 $count 个文件（目标位置不支持）',
    );
    return '$_temp0';
  }

  @override
  String migMoving(String progress) {
    return '正在移动下载… $progress — 请保持应用打开';
  }

  @override
  String get migRetry => '重试';

  @override
  String get queueDownloadAll => '全部下载';

  @override
  String queueDownloadAllBody(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '将下载 $count 首曲目以供离线播放。',
    );
    return '$_temp0';
  }

  @override
  String get mainMore => '更多';

  @override
  String get commonOn => '开启';

  @override
  String get commonOff => '关闭';

  @override
  String get settingsCastQualitySubtitle4k => '需要 4K Chromecast；对手机负担最重';

  @override
  String get eqCasting => '均衡器调节的是本设备上的音频，因此投放期间不可用。请断开连接以使用它。';

  @override
  String get browserNothingToDownload => '此列表中没有可下载的内容';

  @override
  String get browserDownloadAllTitle => '全部下载';

  @override
  String browserDownloadAllConfirm(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '将下载 $count 个文件。',
    );
    return '$_temp0';
  }

  @override
  String get browserCloseSearch => '关闭搜索';

  @override
  String get browserSearchThisList => '搜索此列表';

  @override
  String get browserSearchList => '搜索列表';

  @override
  String browserNoMatches(String query) {
    return '没有与“$query”匹配的结果';
  }

  @override
  String get clear => '清除';

  @override
  String get dlLocationUnavailable => '下载位置不可用';

  @override
  String get dlLocationUnavailableServer => '此服务器的下载位置不可用。';

  @override
  String get dlFailed => '下载失败 — 请检查你的网络连接。';

  @override
  String get dlFatSkip => '部分曲目无法保存到此卡上 — 它们的名称不受支持。将改为流式播放。';

  @override
  String get dlServerGone => '该服务器已不在配置中。';

  @override
  String get dlStorageUnavailable =>
      '存储位置不可用 — 请重新连接 SD 卡，或在“编辑服务器”中更改此服务器的存储位置。';

  @override
  String get dlCouldNotStart => '无法开始下载 — 存储不可用。';

  @override
  String get storageLocationLabel => '存储位置';

  @override
  String get storageAppLocal => '应用内部';

  @override
  String get storagePermanent => '永久';

  @override
  String get storageSdCard => 'SD 卡';

  @override
  String get storageSdSwitchTitle => '保存到 SD 卡';

  @override
  String get storageSdSwitchSubtitle => '保存在 SD 卡的应用文件夹中 — 无需权限，但卸载应用时会被删除。';

  @override
  String get storageHelpAppLocal => '保存在应用内部。卸载或清除应用时会被删除。';

  @override
  String get storageHelpPermanent => '保存到你选择的文件夹。卸载应用后仍会保留。需要“所有文件访问权限”。';

  @override
  String get storageHelpSdCard =>
      '保存到你在 SD 卡上选择的文件夹。移除卡后可能变得不可用。部分设备不允许应用写入 SD 卡 — 如果文件夹选择持续失败，请使用“永久”或“应用内部”。';

  @override
  String get storageChooseFolder => '选择文件夹';

  @override
  String get storageNoFolderChosen => '尚未选择文件夹';

  @override
  String get storageDownloadFolderLabel => '下载文件夹';

  @override
  String get storageDownloadFolderHint => '文件夹名称';

  @override
  String get storageBrowse => '浏览';

  @override
  String get storageDownloadFolderHelp =>
      '文件将下载到此设备上的“media/<folder>”目录。重新使用先前服务器的文件夹，可在你重新添加丢失的服务器时保留其已下载的歌曲。';

  @override
  String get storageNoStorageAvailable => '没有可用的存储';

  @override
  String get storageNoDownloadFolders => '未找到现有的下载文件夹';

  @override
  String get storageExistingFolders => '现有下载文件夹';

  @override
  String storageItemCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count 个项目',
    );
    return '$_temp0';
  }

  @override
  String get storageAllFilesAccess => '授予“所有文件访问权限”以永久存储下载内容，然后再次选择该模式。';

  @override
  String get storageSettings => '设置';

  @override
  String get storageNoVolume => '无法定位存储卷';

  @override
  String get storageNotWritable => '该文件夹不可写 — 请选择其他文件夹。';

  @override
  String get storageNewFolder => '新建文件夹';

  @override
  String get storageFolderNameHint => '文件夹名称';

  @override
  String get storageCouldNotCreateFolder => '无法创建文件夹';

  @override
  String get storageNoSubfolders => '此处没有子文件夹';

  @override
  String get storageUseThisFolder => '使用此文件夹';

  @override
  String get storageMovedToNewFolder => '已将下载的文件移动到新文件夹。';

  @override
  String get storageMoveAlreadyRunning => '已有一项移动正在进行 — 请先让它完成。';

  @override
  String get storageMigrateTitle => '不同的存储卷';

  @override
  String storageMigrateBody(int count, String size) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '此服务器已下载的 $count 个文件（$size）与新位置位于不同的存储卷上。请选择如何处理：',
    );
    return '$_temp0';
  }

  @override
  String storageMigrateNoSpace(String free) {
    return '目标位置可用空间不足（剩余 $free）。移动可能中途失败 — 请先释放空间。';
  }

  @override
  String get storageMigrateMove => '移动它们';

  @override
  String get storageMigrateMoveBody => '在后台复制到新位置，并随复制进度逐个删除旧副本。请保持应用打开直至完成。';

  @override
  String get storageMigrateLeave => '保留它们';

  @override
  String get storageMigrateLeaveBody => '立即切换；旧的下载内容保持原位，并在新位置重新下载。';

  @override
  String get storageMigrateDelete => '删除旧的下载内容';

  @override
  String get storageMigrateDeleteBody => '立即切换并移除旧文件；它们将在新位置重新下载。';

  @override
  String get storageMovingBackground => '正在后台移动你的下载内容 — 请保持应用打开。';

  @override
  String get storageChooseFolderFirst => '请先选择一个下载文件夹。';

  @override
  String get storageChooseSdFolderFirst =>
      '请先在 SD 卡上选择一个文件夹。如果每个文件夹都被拒绝，你的设备可能不允许应用写入该卡 — 请改用“永久”或“应用内部”。';

  @override
  String get castPlayOn => '投放到';

  @override
  String get castPlayOnTooltip => '投放到…';

  @override
  String get castSearching => '正在搜索投放设备…';

  @override
  String get castNotSeeing => '没看到你的设备？请确认它连接的是同一个 Wi-Fi。';

  @override
  String get castVisualizer => '投放可视化';

  @override
  String get castVisualizerSubtitle => '仅限 Chromecast';

  @override
  String get castThisDevice => '此设备';

  @override
  String get visualizerNoKnobs => '此着色器没有滑块。';

  @override
  String get nowPlaying => '正在播放';

  @override
  String get settingsPlayerLayout => '正在播放布局';

  @override
  String get playerLayoutSmall => '小';

  @override
  String get playerLayoutMedium => '中';

  @override
  String get playerLayoutLarge => '大';

  @override
  String get playerLayoutXl => 'XL';

  @override
  String get queueNothingToDownloadEmpty => '队列为空 — 没有可下载的内容';

  @override
  String get queueNothingToDownloadSaved => '没有可下载的内容 — 曲目已保存';

  @override
  String get settingsAccentColor => '强调色';

  @override
  String get accentThemeDefault => '主题默认';

  @override
  String get accentCustom => '自定义';

  @override
  String get lanOnYourNetwork => '本地网络中的服务器';

  @override
  String get lanSearching => '正在搜索服务器…';

  @override
  String get lanRefresh => '刷新';

  @override
  String lanServerVersion(String version) {
    return 'mStream v$version';
  }

  @override
  String lanLoginTitle(String name) {
    return '登录 $name';
  }

  @override
  String get lanUnreachable => '无法在网络中连接到此服务器。';

  @override
  String get lanNoCode => '此服务器已开启快速连接，但未共享配对码。请以管理员身份登录，或请服务器运营者启用配对码共享。';

  @override
  String get settingsResumeQueue => '启动时恢复播放队列';

  @override
  String get settingsOfflineQueue => '下载播放队列';

  @override
  String get settingsOfflineQueueSubtitle => '断开连接时也能继续播放。';

  @override
  String get settingsOfflineQueueWifiOnly => '仅限 Wi-Fi';

  @override
  String get settingsAutoDownloadCap => '下载上限';

  @override
  String get settingsAutoDownloadCapUnlimited => '不限';

  @override
  String get settingsAutoDownloadCapField => '歌曲数';

  @override
  String get settingsAutoDownloadCapDialogBody =>
      '从正在播放的歌曲算起，保留多少首已下载的歌曲。有新歌曲下载时，超出范围的旧歌曲会被删除。';

  @override
  String get downloadWaitingWifi => '等待 Wi-Fi';

  @override
  String get settingsRatingHalf => '半星评分';

  @override
  String get settingsRatingHalfSubtitle => '长按星标';

  @override
  String get ratingTitle => '评分';

  @override
  String get ratingFailed => '无法保存评分';

  @override
  String get diagnosticsTitle => '诊断';

  @override
  String get diagnosticsEnable => '启用日志记录';

  @override
  String get diagnosticsHint => '日志仅保存在你的设备上。复制或分享前会隐藏令牌。';

  @override
  String get diagnosticsVerbose => '详细日志';

  @override
  String get diagnosticsVerboseHint => '同时记录应用焦点变化等高频事件。仅在诊断播放问题时需要。';

  @override
  String get diagnosticsCopy => '复制';

  @override
  String get diagnosticsShare => '分享';

  @override
  String get diagnosticsClear => '清除';

  @override
  String get diagnosticsCopied => '日志已复制到剪贴板';

  @override
  String get diagnosticsEmpty => '暂无日志';

  @override
  String get storageAppExternal => '应用外部';

  @override
  String get storageAppSdCard => '应用 SD 卡';

  @override
  String get selfSignedTitle => '允许自签名证书';

  @override
  String get selfSignedSubtitle => '跳过此服务器的 TLS 验证。仅在可信网络中启用。';

  @override
  String get importedShadersTitle => '导入的着色器';

  @override
  String get importedShadersRescan => '重新扫描文件夹';

  @override
  String get importedShadersDropHint => '将 .glsl 文件放入此文件夹，然后重新扫描：';

  @override
  String get importedShadersCopyPath => '复制路径';

  @override
  String get importedShadersReachableHint => '可通过 USB 访问。卸载 mStream 会删除此文件夹。';

  @override
  String get importedShadersRemove => '删除';

  @override
  String get importedShadersEmptyTitle => '还没有着色器';

  @override
  String get importedShadersEmptyBody =>
      '将 Shadertoy 风格的 .glsl 文件复制到上方文件夹，然后点击重新扫描。';

  @override
  String get importedShadersInvalid => '可能无法运行：没有 mainImage 或 main';

  @override
  String get importedShadersImportDownloads => '从“下载”导入 .glsl';

  @override
  String importedShadersDownloadsImported(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '已导入 $count 个着色器',
    );
    return '$_temp0';
  }

  @override
  String get importedShadersDownloadsNone => '“下载”中没有新的 .glsl 文件';

  @override
  String get importedShadersDownloadsNoPermission => '读取“下载”需要存储权限';

  @override
  String get addServerTabUrl => '服务器地址';

  @override
  String get addServerTabQuickConnect => '快速连接';

  @override
  String get irohPairingHeader => '使用配对码连接';

  @override
  String get irohPairingBody => '在服务器上启用“Remote Access”（远程访问），然后粘贴其配对码或扫描二维码。';

  @override
  String get irohPairingCodeLabel => '配对码';

  @override
  String get irohPairingCodeHint => '粘贴服务器“Remote Access”面板中的配对码';

  @override
  String get irohShowPairingCode => '显示配对码';

  @override
  String get irohQrBody => '在另一台设备上用 mStream 应用扫描以连接到此服务器，或复制配对码并在那里粘贴。';

  @override
  String get irohQrCaution => '任何拥有此配对码的人都可以连接到你的服务器。';

  @override
  String get irohScanQr => '扫描二维码';

  @override
  String get irohPaste => '粘贴';

  @override
  String get irohTestConnection => '测试连接';

  @override
  String get irohTesting => '正在测试…';

  @override
  String get irohScannerTitle => '扫描配对二维码';

  @override
  String get irohQrAndroidOnly => '此设备不支持扫描二维码。';

  @override
  String get irohAndroidOnly => '此设备不支持快速连接。';

  @override
  String get irohCameraPermission => '扫描二维码需要相机权限。';

  @override
  String get irohPasteFirst => '请先粘贴或扫描配对码。';

  @override
  String get irohTestFirst => '请先测试连接。';

  @override
  String get irohTestConnected => '已通过 iroh 隧道连接';

  @override
  String irohTestConnectedVersion(String version) {
    return '已通过 iroh 隧道连接 — mStream v$version';
  }

  @override
  String get irohPathSuffixDirect => ' · 直连';

  @override
  String get irohPathSuffixRelay => ' · 经中继';

  @override
  String get irohTunnelNoAnswer =>
      'The tunnel connected, but the server closed the request without answering. On the server, check the bind address and port mStream listens on (the tunnel reaches it at 127.0.0.1), then try again.';

  @override
  String get irohTunnelTimeout => '隧道已打开，但服务器未及时响应。';

  @override
  String irohTunnelTestFailed(String error) {
    return '隧道测试失败：$error';
  }

  @override
  String get irohSignInHeader => '登录';

  @override
  String get irohSigningIn => '正在登录…';

  @override
  String get irohSignInSave => '登录并保存';

  @override
  String get irohSignInTimeout => '登录超时。';

  @override
  String irohSignInFailed(String error) {
    return '登录失败：$error';
  }

  @override
  String irohSignInFailedHttp(int status) {
    return '登录失败（HTTP $status）。请检查用户名和密码。';
  }

  @override
  String get irohBannerConnecting => '正在连接服务器…';

  @override
  String get irohBannerReconnecting => '正在重新连接服务器…';

  @override
  String get irohBannerDisconnected => '已与服务器断开连接。';

  @override
  String get irohBannerRelay => '已通过中继连接 — 路径较慢。';

  @override
  String get irohBannerRepair => '服务器配对已更改 — 请重新配对以重新连接。';

  @override
  String get irohRepairAction => '重新配对';

  @override
  String get irohRetry => '重试';

  @override
  String get irohRepairTitle => '重新配对服务器';

  @override
  String get irohRepairBody =>
      '此服务器的配对码已更改（其密钥已轮换）。请从服务器的“Remote Access”面板粘贴或扫描新的配对码。';

  @override
  String get irohRepairFailed => '无法使用该配对码连接 — 请检查后重试。';

  @override
  String get irohPathDirect => '直连';

  @override
  String get irohPathRelay => '中继';

  @override
  String get irohCastUnavailable => '点对点（iroh）服务器不支持投放到外部设备 — 播放将保留在此设备上。';

  @override
  String get irohShareUnavailable => '点对点（iroh）服务器不支持分享 — 它们没有可链接的公开地址。';

  @override
  String get discoverTitle => '更多类似';

  @override
  String get discoverPageTitle => '发现';

  @override
  String discoverPageWindowDays(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count 天',
    );
    return '$_temp0';
  }

  @override
  String get discoverPageWindowAll => '全部时间';

  @override
  String discoverPageWidened(String window) {
    return '最近 $window 内没有记录，所以这些来自更早之前。';
  }

  @override
  String get discoverPageBasedOn => '依据';

  @override
  String get discoverPageBasedOnLast => '统计范围';

  @override
  String get discoverPageBasedOnAllTime => '统计范围';

  @override
  String get discoverPageMoreOptions => '更多选项';

  @override
  String get discoverPageNewSeeds => '换一批依据歌曲';

  @override
  String get discoverPageAlbumsLibrary => '来自你曲库的专辑';

  @override
  String discoverPageAlbumsPeer(String name) {
    return '来自 $name 的专辑';
  }

  @override
  String get discoverPageAlbumsPeers => '来自已连接服务器的专辑';

  @override
  String get discoverPageSongsLibrary => '来自你曲库的歌曲';

  @override
  String discoverPageSongsPeer(String name) {
    return '来自 $name 的歌曲';
  }

  @override
  String get discoverPageSongsPeers => '来自已连接服务器的歌曲';

  @override
  String get discoverPageLibraryNothing => '曲库中没有听起来像这些歌的新歌。';

  @override
  String get discoverPagePeersQuiet => '已连接的服务器暂时没有内容。';

  @override
  String get discoverPagePeersFailed => '无法访问已连接的服务器。';

  @override
  String get discoverPageSaveAsPlaylist => '保存为播放列表';

  @override
  String get discoverPageBrowseLibrary => '浏览曲库';

  @override
  String get discoverPageAgoToday => '今天';

  @override
  String get discoverPageAgoYesterday => '昨天';

  @override
  String discoverPageAgoMonths(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count 个月前',
    );
    return '$_temp0';
  }

  @override
  String discoverPageAgoYears(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count 年前',
    );
    return '$_temp0';
  }

  @override
  String get discoverPageRandomTitle => '听完几首歌，这个页面就会了解你的口味';

  @override
  String get discoverPageRandomBody =>
      '“发现”根据你听完的歌来推荐，跳过的歌不算。在有这样的歌之前，这里是围绕曲库中一首随机歌曲的推荐。';

  @override
  String get discoverPageAnotherPick => '换一首';

  @override
  String get discoverPageChooseSong => '选择一首歌…';

  @override
  String get discoverPageError => '无法加载“发现”。请检查连接后重试。';

  @override
  String get discoverPageRetry => '重试';

  @override
  String get discoverPagePickedHeader => '本次选择';

  @override
  String get discoverPageRandomHeader => '随机挑选';

  @override
  String get discoverPageDroppedHeader => '已排除';

  @override
  String get discoverPageDroppedNote => '打开即可恢复';

  @override
  String discoverPagePlayedTimes(int count) {
    return '播放 $count 次';
  }

  @override
  String get discoverPageListenedTo => '听过';

  @override
  String get discoverPageNotAnalyzed => '尚未分析';

  @override
  String get discoverPageAddOwn => '自己添加';

  @override
  String get discoverPageAddOwnSub => '想多听类似的歌';

  @override
  String get discoverPagePickSong => '选一首歌…';

  @override
  String get discoverPagePickSongSub => '搜索曲库，或随机选一首';

  @override
  String discoverPageUseThese(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '使用这 $count 首',
    );
    return '$_temp0';
  }

  @override
  String get discoverMatchedBySound => '按声音匹配';

  @override
  String get discoverSimilarTracks => '相似歌曲';

  @override
  String get discoverSimilarArtists => '相似艺术家';

  @override
  String get discoverFromNetwork => '来自网络';

  @override
  String get discoverFromPeers => '来自对等服务器';

  @override
  String get discoverQueueAll => '全部加入队列';

  @override
  String get discoverNewArtistsOnly => '仅新艺术家';

  @override
  String get discoverNotAnalyzed => '这首歌尚未分析 — 发现扫描处理后会显示相似歌曲。';

  @override
  String get discoverScanPendingTitle => '尚未分析任何内容';

  @override
  String get discoverScanPendingBody =>
      '此服务器已启用发现功能，但尚未分析任何音乐。发现扫描完成后即可看到相似歌曲。';

  @override
  String get discoverCheckAgain => '重新检查';

  @override
  String get discoverTurnedOff => '此服务器已关闭发现功能。';

  @override
  String get pathScanPending => '此服务器尚未分析任何音乐，因此没有可用于构建路径的曲目。发现扫描完成后即可使用。';

  @override
  String get discoverNothingFound => '未找到匹配项。';

  @override
  String get discoverNoSeed => '播放一首歌曲以发现相似音乐。';

  @override
  String get discoverLeadCopied => '已复制 — 去找找吧！';

  @override
  String get discoverOpenMusicBrainz => '在 MusicBrainz 中打开';

  @override
  String get discoverNetworkWarmingUp => '暂无网络数据 — 发现其他服务器后，对等服务器的曲库会在后台下载。';

  @override
  String get discoverNetworkNothingNew => '这首歌没有新发现 — 网络中没有你尚未拥有的匹配歌曲。';

  @override
  String get discoverPeersUnreachable => '对等服务器没有响应 — 它们现在可能离线。';

  @override
  String get discoverPeersNothingNew => '对等服务器上没有这首歌的新发现。';

  @override
  String get autoDjSonicTitle => '声音相似度';

  @override
  String get autoDjSonicSeedLabel => '种子歌曲';

  @override
  String get autoDjSonicSeedNone => '未设置 — 以正在播放的歌曲作为会话基准。';

  @override
  String get autoDjSonicSeedBanner => '选择种子歌曲 — 在曲库中点击任意曲目';

  @override
  String get autoDjSonicSeedSearchHint => '搜索歌曲…';

  @override
  String get autoDjSonicSeedRandom => '随机歌曲';

  @override
  String get autoDjSonicSeedRemove => '移除种子歌曲';

  @override
  String get autoDjSonicSeedFailed => '无法获取歌曲';

  @override
  String get autoDjSeedNoMatch => '没有符合筛选条件的歌曲';

  @override
  String get discoverFindSimilar => '查找相似歌曲';

  @override
  String get discoverStartSession => '开始声音会话';

  @override
  String get discoverStartSessionSubtitle => '无尽播放与此相似的音乐 — 将替换当前队列。';

  @override
  String get discoverStartSessionSubtitleRandom => '从随机歌曲开始无尽播放 — 将替换当前队列。';

  @override
  String get discoverSessionStarted => '声音会话已开始 — Auto DJ 已开启。';

  @override
  String get autoDjSonicAnchorRolling => '跟随氛围';

  @override
  String get autoDjSonicAnchorLocked => '固定在种子歌曲';

  @override
  String get autoDjSonicAnchorRollingHint => '每首歌都跟随会话最近的声音 — 会缓慢演变。';

  @override
  String get autoDjSonicAnchorLockedHint => '整个会话中每首歌都保持接近种子歌曲。';

  @override
  String get trackAddToPlaylist => '添加到播放列表';

  @override
  String get trackAddToPlaylistFailed => '无法添加到播放列表。';

  @override
  String get discoverPlayPathTo => '播放一条通往…的路径';

  @override
  String get pathScreenTitle => '声音路径';

  @override
  String get pathStartNotAnalyzed => '起点歌曲尚未分析 — 请等待发现扫描或选择其他歌曲。';

  @override
  String get pathEndNotAnalyzed => '终点歌曲尚未分析 — 请等待发现扫描或选择其他歌曲。';

  @override
  String get pathStartSong => '起点歌曲';

  @override
  String get pathEndSong => '终点歌曲';

  @override
  String get pathLength => '长度';

  @override
  String get pathRegenerate => '重新生成';

  @override
  String get pathSaveAsPlaylist => '保存为播放列表';

  @override
  String get pathSetupHint => '选择起点和终点歌曲 — 两者之间的旅程会自动填充。';

  @override
  String get pathNotSet => '未设置';

  @override
  String get pathUsePlaying => '使用正在播放的歌曲';

  @override
  String get pathSearchSong => '搜索';

  @override
  String get pathBrowseLibrary => '浏览曲库';

  @override
  String get pathBuild => '生成旅程';

  @override
  String get pathStartOver => '重新开始';

  @override
  String get pathPickBannerStart => '选择起点歌曲 — 在曲库中点击任意曲目';

  @override
  String get pathPickBannerEnd => '选择终点歌曲 — 在曲库中点击任意曲目';

  @override
  String get pathNothingPlaying => '当前没有播放内容';

  @override
  String pathPickOnServer(String server) {
    return '请选择 $server 上的曲目';
  }

  @override
  String get welcomeTranslationNote => '此语言为机器翻译，表述可能不够自然。';

  @override
  String get welcomeTranslationCta => '帮助翻译 mStream';

  @override
  String get setupTitle => '快速设置';

  @override
  String get setupSkip => '跳过';

  @override
  String get setupNext => '下一步';

  @override
  String get setupFinish => '完成';

  @override
  String get setupBack => '上一步';

  @override
  String get setupAccentTitle => '选择你的颜色';

  @override
  String get setupAccentBody => '强调色会用于按钮、滑块和播放器控件。点击任意一个即可试用。';

  @override
  String get setupPlaybackTitle => '点击歌曲时';

  @override
  String get setupOfflineTitle => '离线保留播放队列';

  @override
  String get realAudioNoMic => 'mStream 绝不会使用你的麦克风。';

  @override
  String get playlistEmpty => '播放列表为空';

  @override
  String get trackRating => '评分';

  @override
  String albumDiscNumber(int n) {
    return '第 $n 张碟';
  }

  @override
  String get autoDjStartPickBanner => '选择起始歌曲 — 在曲库中点击任意曲目';

  @override
  String get autoDjStartAskShort => '询问';

  @override
  String serverVersionLabel(String version) {
    return '服务器 v$version';
  }

  @override
  String get serverVersionUnknown => '服务器版本未知';

  @override
  String get serverUpdateUrgent => '请更新服务器';

  @override
  String get serverUpdateAvailable => '有可用的服务器更新';

  @override
  String serverTooOldWarning(String version) {
    return '此服务器版本为 v$version。部分功能需要 v5.5 或更高版本，将不可用。';
  }

  @override
  String get torrentScreenTitle => '添加种子';

  @override
  String get torrentNoServer => '尚未配置服务器。';

  @override
  String get torrentServerLabel => '服务器';

  @override
  String get torrentLibraryLabel => '曲库';

  @override
  String get torrentNoLibraries => '此服务器上没有曲库';

  @override
  String get torrentSourceLabel => '来源';

  @override
  String get torrentChooseFile => '选择 .torrent 文件';

  @override
  String get torrentOr => '或';

  @override
  String get torrentMagnetLabel => '磁力链接';

  @override
  String get torrentMagnetInvalid => '磁力链接无效';

  @override
  String torrentNotATorrent(String name) {
    return '“$name”不是 .torrent 文件';
  }

  @override
  String get torrentOpenWith => '在其他应用中打开';

  @override
  String get torrentOpenWithNone => '此设备上没有应用可以打开 .torrent 文件';

  @override
  String get torrentOpenWithFailed => '无法将种子文件交给其他应用';

  @override
  String get torrentIntentTitle => '已接收种子';

  @override
  String get torrentIntentBody => '将其添加到 mStream 服务器上的曲库，或交给其他应用处理。';

  @override
  String get torrentIntentAdd => '添加到 mStream';

  @override
  String get torrentIntentDontAsk => '始终添加到 mStream，不再询问';

  @override
  String get settingsTorrentAskTitle => '询问如何处理种子文件';

  @override
  String get settingsTorrentDefaultTitle => '种子文件的默认应用';

  @override
  String get settingsTorrentDefaultSub => '打开 Android 设置';

  @override
  String get settingsTorrentDefaultFailed => '无法打开 Android 设置';

  @override
  String get torrentAutoDetect => '自动检测元数据';

  @override
  String get torrentDetecting => '检测中…';

  @override
  String get torrentDetectNoMetadata => '元数据不足 — 请手动填写';

  @override
  String get torrentDetected => '已检测到元数据';

  @override
  String get torrentDetectGuess => '推测结果 — 请核对各字段';

  @override
  String get torrentMetadataLabel => '元数据';

  @override
  String get torrentArtistLabel => '艺术家';

  @override
  String get torrentAlbumLabel => '专辑';

  @override
  String get torrentYearLabel => '年份';

  @override
  String get torrentDestinationLabel => '目标位置';

  @override
  String get torrentPathLabel => '曲库内路径';

  @override
  String torrentPreviewNoLibrary(String path) {
    return '‹未选曲库›/$path';
  }

  @override
  String get torrentPreviewContents => '‹种子内容›';

  @override
  String get torrentRenameRoot => '重命名种子根文件夹';

  @override
  String get torrentRenameRootSub => '与目标文件夹名保持一致';

  @override
  String get torrentForceFresh => '强制重新下载';

  @override
  String get torrentForceFreshSub => '不检查服务器上已有的文件';

  @override
  String get torrentSubmit => '添加种子';

  @override
  String get torrentSubmitting => '添加中…';

  @override
  String get torrentUnavailable => '此服务器不支持种子。';

  @override
  String get torrentPickLibrary => '请选择曲库';

  @override
  String get torrentOneSource => '请提供磁力链接或 .torrent 文件（二选一）';

  @override
  String get torrentPathEmpty => '目标路径为空';

  @override
  String get torrentSeeded => '已在磁盘上 — 正在做种';

  @override
  String get torrentAlreadyInClient => '已在种子客户端中';

  @override
  String get torrentInvalidFile => '无效的种子文件';

  @override
  String get torrentSeedCheckFailed => '无法检查已有文件 — 将重新下载';

  @override
  String get torrentPartialTitle => '部分文件已存在';

  @override
  String get torrentPartialBody => '将种子指向已有副本进行做种，只下载缺少的文件。';

  @override
  String torrentPartialCount(String matched, String total) {
    return '此处有 $matched/$total 个文件';
  }

  @override
  String torrentPartialMissing(String missing) {
    return ' · 还需下载 $missing 个';
  }

  @override
  String get torrentDownloadFresh => '仍然重新下载';

  @override
  String get torrentMatchNoFolder => '该匹配没有文件夹名 — 请改用“仍然重新下载”';

  @override
  String torrentAdded(String name) {
    return '已添加“$name”';
  }

  @override
  String torrentDuplicate(String name) {
    return '“$name”已在客户端中';
  }

  @override
  String serverPickerVia(String parent) {
    return '经由 $parent';
  }

  @override
  String get browserFederatedReadOnly => '只读服务器';

  @override
  String get browserFederatedReadOnlyNote => '播放列表和评分保留在你自己的服务器上';

  @override
  String get federatedShareUnavailable => '共享服务器上的歌曲无法从这里分享 — 它们位于他人的曲库中。';

  @override
  String get federatedForget => '忘记';

  @override
  String get federatedHide => '在选择器中隐藏';

  @override
  String get federatedShow => '在选择器中显示';

  @override
  String federatedNoLongerListed(String parent) {
    return '$parent 已停止共享';
  }

  @override
  String get federationTitle => '联合';

  @override
  String get federationStatusOn => '已开启 · 已连接中继';

  @override
  String get federationStatusConnecting => '已开启 · 连接中…';

  @override
  String get federationStatusOff => '已关闭';

  @override
  String get federationStatusUnavailable => '此平台不可用';

  @override
  String get federationSharedWithYou => '与你共享的';

  @override
  String get federationRequestsSection => '请求';

  @override
  String get federationYourSharedLibraries => '你共享的曲库';

  @override
  String get federationAddPeer => '添加对等服务器';

  @override
  String get federationShareLibrary => '共享曲库';

  @override
  String get federationNoPeersYet => '还没有人与此服务器共享任何内容。';

  @override
  String get federationNoKeysYet => '还没有票据 — 共享一个曲库来创建票据。';

  @override
  String get federationNoRequests => '还没有请求 — 发现网络中的服务器可以在这里找到你。';

  @override
  String get federationClipboardTicket => '剪贴板中有票据';

  @override
  String federationTicketPreview(String name, String libraries) {
    return '$name · 共享 $libraries';
  }

  @override
  String federationTicketPreviewNoLibraries(String name) {
    return '$name';
  }

  @override
  String get federationUnnamedServer => '未命名服务器';

  @override
  String get federationAddPeerAction => '添加';

  @override
  String get federationPeerLive => '在线';

  @override
  String get federationPeerConnecting => '连接中…';

  @override
  String get federationPeerDirectTunnel => '直连隧道';

  @override
  String federationPeerViaParent(String parent) {
    return '经由 $parent';
  }

  @override
  String federationPeerViaTunnel(String parent) {
    return '经由 $parent 的隧道';
  }

  @override
  String get federationPeerMissing => '已停止共享';

  @override
  String get federationPeerHidden => '已在选择器中隐藏';

  @override
  String federationMemberNote(String server) {
    return '共享由管理员负责。创建票据、添加对等服务器和回复配对请求都需要以管理员身份登录 $server — 与打开管理面板所用的登录相同。';
  }

  @override
  String get federationRestrictedNote => '此服务器只接受来自其自身网络的管理调用。请在家中连接以在此管理共享。';

  @override
  String get federationDisabledNote => '此服务器已关闭管理 API。';

  @override
  String get federationUnsupportedNote => '此服务器版本过旧，无法从应用中管理联合。请更新 mStream。';

  @override
  String get federationLoadFailed => '无法连接服务器。';

  @override
  String get federationRetry => '重试';

  @override
  String get federationOffTitle => '与朋友的服务器共享曲库';

  @override
  String get federationOffBody =>
      '配对两台 mStream 服务器，互相收听对方的音乐。交换的是票据 — 用短信发送、扫码或粘贴。';

  @override
  String get federationOffPoint1Title => '只读，端到端加密';

  @override
  String get federationOffPoint1Body => '播放列表和评分永远不会离开你的服务器';

  @override
  String get federationOffPoint2Title => '无需端口转发或 DNS';

  @override
  String get federationOffPoint2Body => 'iroh 会找到路径 — 能直连就直连，需要时走中继';

  @override
  String get federationOffPoint3Title => '可撤销的票据';

  @override
  String get federationOffPoint3Body => '每张只能兑换一次，随时可以切断';

  @override
  String get federationOffAdminOnly => '只有服务器管理员能开启。';

  @override
  String federationOffMemberNote(String server) {
    return '$server 上的联合已关闭。其管理员可以开启。';
  }

  @override
  String get federationTurnOn => '开启联合';

  @override
  String get federationUnavailableNote =>
      'iroh 组件没有适用于此服务器操作系统/CPU 的构建，联合端点无法在这里运行。';

  @override
  String get federationTurnedOn => '联合已开启';

  @override
  String get federationTurnedOff => '联合已关闭';

  @override
  String get federationToggleFailed => '无法更新联合设置。';

  @override
  String get federationSettingsTitle => '联合设置';

  @override
  String get federationSwitchSubtitle => '点对点，端到端加密。无需端口转发，无需 DNS。';

  @override
  String get federationStatusSection => '状态';

  @override
  String get federationConnectedRelay => '已连接中继';

  @override
  String get federationNotRunning => '端点未运行';

  @override
  String get federationEndpointId => '端点 ID';

  @override
  String get federationEndpointCopied => '已复制端点 ID';

  @override
  String get federationPairingRequestsSection => '配对请求';

  @override
  String get federationRequestsInboxTitle => '接受来自发现网络的请求';

  @override
  String get federationRequestsInboxSubtitle =>
      '默认关闭。关闭时，新请求会在传输层被拒绝；你自己发出的请求的回复仍会送达。';

  @override
  String get federationInboxFailed => '无法更新请求收件箱。';

  @override
  String get federationDefaultsSection => '新票据的默认值';

  @override
  String get federationDefaultsNote => '来自服务器配置 — 每张票据都可以更改';

  @override
  String get federationOffWarning =>
      '关闭联合会断开所有对等连接，并隐藏你的票据直到重新开启。对等服务器会保留它们的票据。';

  @override
  String federationRequestWantsToPair(String name) {
    return '$name 想要配对';
  }

  @override
  String federationRequestToName(String name) {
    return '发给 $name 的请求';
  }

  @override
  String federationRequestOffers(String libraries) {
    return '提供 $libraries';
  }

  @override
  String get federationRequestOffersNothing => '未提供任何曲库';

  @override
  String federationRequestYouOffered(String libraries) {
    return '你提供了 $libraries';
  }

  @override
  String get federationRequestYouOfferedNothing => '你未提供任何曲库';

  @override
  String get federationReqSending => '发送中…';

  @override
  String get federationReqWaiting => '等待对方';

  @override
  String get federationReqSharingBack => '正在回共享…';

  @override
  String get federationReqNeedsAnswer => '需要你的回复';

  @override
  String get federationReqSendingTicket => '正在发送你的票据…';

  @override
  String get federationReqWaitingShare => '等待对方共享';

  @override
  String get federationReqDeclined => '已被拒绝';

  @override
  String get federationReqYouDeclined => '你已拒绝';

  @override
  String get federationReqInboxClosed => '对方收件箱已关闭';

  @override
  String get federationReqFederated => '已联合';

  @override
  String get federationReqWithdrawn => '已撤回';

  @override
  String get federationReqExpired => '已过期';

  @override
  String get federationAccept => '接受…';

  @override
  String get federationAcceptAndShare => '接受并共享';

  @override
  String get federationDecline => '拒绝';

  @override
  String get federationCancelRequest => '撤回请求';

  @override
  String get federationDismiss => '移除';

  @override
  String get federationRequestTitle => '配对请求';

  @override
  String federationRequestReceived(String ago) {
    return '$ago通过发现网络收到';
  }

  @override
  String federationRequestSent(String ago) {
    return '$ago通过发现网络发出';
  }

  @override
  String get federationShareBack => '回共享';

  @override
  String get federationShareBackNote => '接受之前不会有任何变化。对方将获得你勾选的曲库（至少一个）的只读访问权限。';

  @override
  String get federationTheirLimits => '对方的限制';

  @override
  String get federationChange => '更改';

  @override
  String get federationRequestIgnored => '来自此服务器的请求将被忽略 7 天';

  @override
  String get federationRequestAccepted => '已接受请求';

  @override
  String get federationRequestDeclined => '已拒绝请求';

  @override
  String get federationRequestCancelled => '已撤回请求';

  @override
  String get federationRequestActionFailed => '无法更新请求。';

  @override
  String get federationTicketNameLabel => '这是给谁的？';

  @override
  String get federationTicketNameHint => '只有你能看到这个名字 — 它用来在列表中标记票据。';

  @override
  String get federationLibrariesTheyCanRead => '对方可读取的曲库';

  @override
  String get federationLimitsSection => '限制';

  @override
  String get federationExactNumbers => '精确数值';

  @override
  String get federationPresets => '预设';

  @override
  String get federationLimitStreamRate => '码率';

  @override
  String get federationLimitPerDay => '每日';

  @override
  String get federationLimitStreams => '并发流数';

  @override
  String get federationLimitExpires => '有效期';

  @override
  String get federationUnlimited => '不限';

  @override
  String get federationNever => '永不';

  @override
  String federationDays(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count 天',
    );
    return '$_temp0';
  }

  @override
  String get federationOneYear => '1 年';

  @override
  String federationKbps(int n) {
    return '$n kbps';
  }

  @override
  String federationMbps(int n) {
    return '$n Mbps';
  }

  @override
  String federationMbPerDay(int n) {
    return '每日 $n MB';
  }

  @override
  String federationGbPerDay(int n) {
    return '每日 $n GB';
  }

  @override
  String federationStreamsCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count 路并发流',
    );
    return '$_temp0';
  }

  @override
  String get federationNeverExpires => '永不过期';

  @override
  String federationExpiresIn(String when) {
    return '$when过期';
  }

  @override
  String get federationExpired => '已过期';

  @override
  String federationInDays(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count 天后',
    );
    return '$_temp0';
  }

  @override
  String federationInHours(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count 小时后',
    );
    return '$_temp0';
  }

  @override
  String get federationStreamRateField => '码率（kbps，0 = 不限）';

  @override
  String get federationPerDayField => '每日配额（MB，0 = 不限）';

  @override
  String get federationStreamsField => '最大并发流数（0 = 不限）';

  @override
  String get federationExpiresField => '有效天数（0 = 永不过期）';

  @override
  String get federationCreateTicket => '创建票据';

  @override
  String get federationMintFailed => '无法创建票据。';

  @override
  String get federationNoLibraries => '此服务器没有可共享的曲库。';

  @override
  String get federationTicketTitle => '你的票据';

  @override
  String federationTicketFor(String name) {
    return '给 $name 的票据';
  }

  @override
  String federationTicketReads(String libraries) {
    return '可读取 $libraries';
  }

  @override
  String get federationTicketQrHint => '在同一个房间？让对方扫描这个。';

  @override
  String get federationTicketWarning =>
      '持有此票据的任何人都能读取这些曲库，直到它被兑换或撤销。请通过私密渠道发送 — 第一个使用它的服务器将完成兑换。';

  @override
  String get federationCopyTicket => '复制票据';

  @override
  String get federationTicketCopied => '已复制票据';

  @override
  String get federationSendByText => '用短信发送…';

  @override
  String get federationTicketRevokeNote =>
      '随时可在“联合”中撤销。如果对方重装了，“重置兑换”可让票据再次被兑换。';

  @override
  String get federationTicketNotRunning => '联合端点未运行，所以还没有可发送的票据。开启联合后再回来。';

  @override
  String federationShareMessage(String libraries, String ticket) {
    return '我把我的 mStream 音乐曲库共享给你 — $libraries，只读。在 mStream 应用中打开“联合 → 添加对等服务器”，粘贴这张票据：\n\n$ticket\n\n它只能用一次 — 我随时可以撤销。';
  }

  @override
  String get federationShareSubject => 'mStream 联合票据';

  @override
  String get federationKeyClaimed => '已兑换';

  @override
  String get federationKeyNotClaimed => '尚未兑换';

  @override
  String federationKeyTodayUsage(String amount) {
    return '今日 $amount';
  }

  @override
  String federationKeyLastUsed(String ago) {
    return '上次使用：$ago';
  }

  @override
  String get federationKeyNeverUsed => '从未使用';

  @override
  String federationKeyClaimedAgo(String ago) {
    return '$ago兑换';
  }

  @override
  String get federationResetBinding => '重置兑换';

  @override
  String get federationResetBindingNote => '对方重装了？让票据可以再次兑换。';

  @override
  String get federationBindingReset => '票据可以再次兑换了';

  @override
  String get federationRevoke => '撤销';

  @override
  String federationRevokeConfirm(String name) {
    return '撤销这张票据？$name 将立即失去访问权限。';
  }

  @override
  String get federationRevoked => '已撤销票据';

  @override
  String get federationSaveLimits => '保存限制';

  @override
  String get federationLimitsSaved => '已保存限制';

  @override
  String get federationLimitsFailed => '无法保存限制。';

  @override
  String get federationSend => '发送';

  @override
  String get federationKeyTitle => '共享的曲库';

  @override
  String federationActionFailed(String error) {
    return '操作失败：$error';
  }

  @override
  String get federationTheirTicket => '对方的票据';

  @override
  String get federationScanQr => '扫描二维码';

  @override
  String get federationScannerTitle => '扫描联合票据';

  @override
  String get federationPaste => '粘贴';

  @override
  String get federationTicketPasted => '已从剪贴板粘贴。';

  @override
  String get federationNotATicket => '这看起来不像联合票据。';

  @override
  String get federationTicketTooNew => '这张票据来自比本应用更新的 mStream 版本。';

  @override
  String get federationTicketExpiredNote => '这张票据已过期。';

  @override
  String get federationDisplayName => '显示名称';

  @override
  String get federationDisplayNameHint => '可选 — 在服务器选择器中的显示方式。';

  @override
  String federationSharesLibraries(String libraries) {
    return '共享 $libraries';
  }

  @override
  String get federationSharesUnknown => '票据中未列出曲库';

  @override
  String federationValidUntil(String date) {
    return '有效期至 $date';
  }

  @override
  String federationAddPeerShowsUnder(String server) {
    return '将显示在 $server 之下';
  }

  @override
  String federationAddPeerReadOnly(String branch, String name) {
    return '只读 · 在选择器中显示为 $branch $name';
  }

  @override
  String get federationAddPeerDials => '你的服务器通过 iroh 连接它';

  @override
  String get federationAddPeerEncrypted => '端到端加密 · 无需端口转发';

  @override
  String get federationAddPeerNoTicket => '还没有票据？让对方用短信发一张给你。';

  @override
  String federationPeerAdded(String name) {
    return '已添加 $name';
  }

  @override
  String get federationAddPeerFailed => '无法添加对等服务器。';

  @override
  String get federationPeerAlreadyAdded => '这张票据已作为对等服务器添加。';

  @override
  String get federationLibrariesYouCanRead => '你可以读取的曲库';

  @override
  String get federationDiscoverySection => '发现';

  @override
  String get federationAskPeerSimilar => '向此对等服务器询问相似音乐';

  @override
  String get federationAskPeerSimilarNote => '会发送你正在听的内容 — 仅发给此对等服务器。';

  @override
  String get federationAutoDjSection => 'Auto DJ';

  @override
  String get federationAutoDjParticipates => '参与多服务器 Auto DJ';

  @override
  String get federationAutoDjParticipatesNote => 'DJ 开启时用它自己的曲库作答';

  @override
  String get federationAutoDjNotCandidate => '不是 Auto DJ 候选';

  @override
  String get federationAutoDjNotCandidateNote => '需要能回应声音相似度选曲的服务器';

  @override
  String get federationTest => '测试';

  @override
  String get federationTesting => '测试中…';

  @override
  String get federationTestOk => '可达';

  @override
  String federationTestFailed(String error) {
    return '无法连接：$error';
  }

  @override
  String federationCheckedAgo(String ago) {
    return '$ago检查过';
  }

  @override
  String get federationNeverTested => '从未测试';

  @override
  String federationLastSeen(String ago) {
    return '上次在线：$ago';
  }

  @override
  String get federationBrowseLibrary => '浏览此曲库';

  @override
  String get federationRemovePeer => '移除对等服务器';

  @override
  String federationRemovePeerConfirm(String name) {
    return '移除 $name？从它加入队列的曲目将停止播放。';
  }

  @override
  String federationPeerRemoved(String name) {
    return '已移除 $name';
  }

  @override
  String get federationShowInPicker => '在服务器选择器中显示';

  @override
  String get federationShowInPickerNote => '隐藏的对等服务器仍会播放你从它们加入队列的内容。';

  @override
  String get federationPeerReadOnlyNote => '只读 — 播放列表和评分保留在你自己的服务器上。';

  @override
  String get federationPeerLibrariesUnknown => '尚未列出 — 打开一次以加载它的曲库。';

  @override
  String get federationTransportDirect => '从此手机直连的隧道';

  @override
  String get federationTransportRelay => '中继待命';

  @override
  String federationTransportViaParent(String parent) {
    return '经由 $parent';
  }

  @override
  String federationTransportViaParentTunnel(String parent) {
    return '经由 $parent 的隧道';
  }

  @override
  String get federationDiscoveryFailed => '无法更新发现设置。';

  @override
  String get agoJustNow => '刚刚';

  @override
  String agoMinutes(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count 分钟前',
    );
    return '$_temp0';
  }

  @override
  String agoHours(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count 小时前',
    );
    return '$_temp0';
  }

  @override
  String agoDays(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count 天前',
    );
    return '$_temp0';
  }

  @override
  String get browserP2pNetwork => 'P2P 网络';

  @override
  String get browserP2pOn => '已开启';

  @override
  String get browserP2pOff => '已关闭';

  @override
  String get p2pTitle => 'P2P 网络';

  @override
  String get p2pStatusConnected => '已连接';

  @override
  String p2pNeighborsCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count 个邻居',
    );
    return '$_temp0';
  }

  @override
  String p2pAnnouncingAs(String name) {
    return '以 $name 的名义公布';
  }

  @override
  String get p2pStatusSearching => '已加入 · 等待邻居';

  @override
  String p2pStatusReconnecting(int n) {
    return '重新连接中 · 第 $n 次';
  }

  @override
  String get p2pStatusNotJoined => '尚未加入';

  @override
  String get p2pStatusOff => '已关闭';

  @override
  String get p2pStatusUnavailable => '此平台不可用';

  @override
  String get p2pStatNeighbors => '网状网络邻居';

  @override
  String get p2pStatNeighborsSub => '活跃的 gossip 协议连接';

  @override
  String get p2pStatKnown => '已知服务器';

  @override
  String p2pStatKnownSub(int hidden, int blocked) {
    return '$hidden 个已隐藏 · $blocked 个已屏蔽';
  }

  @override
  String get p2pStatHeld => '已保存的快照';

  @override
  String p2pStatHeldOf(int held, int max) {
    return '$held / $max';
  }

  @override
  String p2pStatStorage(String used, String cap) {
    return '$used / $cap';
  }

  @override
  String get p2pStatTracks => '对等服务器曲目';

  @override
  String p2pStatTracksSub(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '可搜索，$count 个曲库',
    );
    return '$_temp0';
  }

  @override
  String get p2pActivity => '活动';

  @override
  String get p2pActivitySubtitle => '最新在前 · 仅保存在内存中';

  @override
  String get p2pActivityEmpty => '还没有内容 — 加入网状网络、获取快照、轮换和恢复等事件会在发生时显示在这里。';

  @override
  String get p2pActivityNote => '完整历史记录在服务器日志中。';

  @override
  String get p2pFromNetwork => '来自网络';

  @override
  String get p2pFindSimilar => '在网络中寻找相似音乐';

  @override
  String p2pFindSimilarSub(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '为正在播放的曲目打开“更多类似” · 来自 $count 个已下载曲库的线索',
    );
    return '$_temp0';
  }

  @override
  String get p2pFindSimilarNothingPlaying => '请先播放一首歌 — “更多类似”会跟随当前曲目';

  @override
  String get p2pNewArtistsOnlySub => '隐藏此曲库中已有艺术家的线索';

  @override
  String get p2pServersYouFollow => '你关注的服务器';

  @override
  String get p2pServersOnNetwork => '网络上的服务器';

  @override
  String get p2pNoServersYet => '还没有发现任何服务器 — 用朋友的票据添加一个，或者等 gossip 协议传播一分钟。';

  @override
  String p2pHiddenIncompatible(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '已隐藏 $count 个服务器 — 模型不兼容',
    );
    return '$_temp0';
  }

  @override
  String get p2pShow => '显示';

  @override
  String get p2pHide => '隐藏';

  @override
  String get p2pBefriend => '添加好友服务器';

  @override
  String get p2pOnline => '在线';

  @override
  String p2pOfflineFor(String ago) {
    return '$ago离线';
  }

  @override
  String p2pTracksCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count 首曲目',
    );
    return '$_temp0';
  }

  @override
  String p2pSeedersCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count 个做种者',
    );
    return '$_temp0';
  }

  @override
  String get p2pChipDownloaded => '已下载';

  @override
  String get p2pChipUpdate => '有更新';

  @override
  String get p2pChipNotDownloaded => '未下载';

  @override
  String get p2pChipPinned => '已固定';

  @override
  String get p2pChipIncompatible => '模型不兼容';

  @override
  String get p2pChipFederated => '已联合';

  @override
  String get p2pChipTheyAsked => '对方已向你发出请求';

  @override
  String get p2pChipRequestSent => '已发送请求';

  @override
  String get p2pSearchingTitle => '正在寻找对等服务器';

  @override
  String get p2pSearchingBody => '网状网络大约需要一分钟形成。此屏幕会自动更新。';

  @override
  String get p2pReconnectingTitle => '重新连接中';

  @override
  String p2pReconnectingBody(int n) {
    return 'P2P 辅助进程（sidecar）已退出，正在重新启动（第 $n 次） — 无需操作。';
  }

  @override
  String get p2pJoinTitle => '来自他人曲库的推荐';

  @override
  String get p2pWhatShared => '共享的内容';

  @override
  String get p2pShared1 => '仅含元数据的快照';

  @override
  String get p2pShared1Sub => '艺术家、标题、时长、声音指纹 — 绝不包含音频文件';

  @override
  String get p2pShared2 => '你服务器的名称和描述';

  @override
  String get p2pShared2Sub => '网络上所有人可见，默认公布到公共社区网络';

  @override
  String get p2pHowYouAppear => '你的显示方式';

  @override
  String get p2pServerName => '服务器名称';

  @override
  String get p2pServerNameHint => '网络上已有 18,000 个叫“mStream”的服务器，这个名字是最先该改的。';

  @override
  String get p2pDescription => '描述';

  @override
  String get p2pDescriptionHint => '最多 180 个字符，可选。';

  @override
  String get p2pAlsoAcceptRequests => '同时接受联合请求';

  @override
  String get p2pAlsoAcceptRequestsSub => '共享曲库的邀请 — 每一个都需要你批准后才会共享。会开启联合。';

  @override
  String get p2pJoin => '加入网络';

  @override
  String get p2pJoining => '加入中…';

  @override
  String get p2pJoined => '已加入发现网络 — 给网状网络一分钟时间。';

  @override
  String p2pJoinFailed(String error) {
    return '无法加入网络：$error';
  }

  @override
  String p2pInboxFailed(String error) {
    return '发现功能已开启，但请求收件箱未能启动：$error';
  }

  @override
  String get p2pUnavailableNote =>
      '未找到此平台的 p2p-sidecar 二进制文件，也没有可下载的版本 — 网络不可用。';

  @override
  String get p2pWillDownloadNote => 'P2P 辅助进程（sidecar）尚未安装；加入时会先下载。';

  @override
  String get p2pAdminOnlyNote => '只有服务器管理员可以加入。';

  @override
  String p2pMemberOffNote(String server) {
    return '$server 上的发现网络已关闭。其管理员可以加入。';
  }

  @override
  String p2pMemberNote(String server) {
    return '加入、邀请和快照管理由管理员负责。以管理员身份登录 $server 即可在这里管理网络。';
  }

  @override
  String get p2pSnapshotSection => '快照';

  @override
  String p2pDownloadedSize(String size) {
    return '已下载 · $size';
  }

  @override
  String p2pSnapshotSeq(int seq) {
    return '快照 $seq';
  }

  @override
  String p2pNewerAnnounced(int seq) {
    return '已公布更新的版本（$seq）';
  }

  @override
  String get p2pNotDownloaded => '未下载';

  @override
  String get p2pNotDownloadedSub => '下载后即可在“发现”中搜索';

  @override
  String get p2pDownload => '下载';

  @override
  String get p2pUpdate => '更新';

  @override
  String get p2pDownloading => '下载中…';

  @override
  String get p2pDownloaded => '快照已下载';

  @override
  String p2pDownloadFailed(String error) {
    return '无法下载快照：$error';
  }

  @override
  String get p2pPin => '固定此快照';

  @override
  String p2pPinSub(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '轮换会在 $count 天后释放最少使用的快照；固定的快照会保留。',
    );
    return '$_temp0';
  }

  @override
  String get p2pPinSubNoRotation => '轮换已关闭；固定的快照在空间不足时也会保留。';

  @override
  String get p2pRemoveSnapshot => '移除快照';

  @override
  String get p2pSnapshotRemoved => '快照已移除';

  @override
  String get p2pHeldSince => '保存自';

  @override
  String get p2pTracksLabel => '曲目';

  @override
  String get p2pSeedersLabel => '做种者';

  @override
  String get p2pSeedersSub => '正在提供快照';

  @override
  String get p2pFederatedWithYou => '已与你联合';

  @override
  String get p2pFederatedWithYouSub => '打开“联合”查看你们互相读取的内容';

  @override
  String get p2pTheyAskedYou => '对方请求联合';

  @override
  String get p2pTheyAskedYouSub => '在“联合”中查看请求';

  @override
  String get p2pRequestSentTitle => '请求已发送';

  @override
  String get p2pRequestSentSub => '等待对方 · 在“联合”中跟踪';

  @override
  String get p2pAskToFederate => '请求共享曲库';

  @override
  String get p2pAskToFederateSub => '通过网络发送请求 — 现在不会有任何变化';

  @override
  String get p2pOpen => '打开';

  @override
  String get p2pReview => '查看';

  @override
  String get p2pForget => '忘记此服务器';

  @override
  String get p2pForgetSub => '已离线且未下载任何内容；再次发现时会重新出现';

  @override
  String p2pForgotten(String name) {
    return '已忘记 $name';
  }

  @override
  String get p2pBlockServer => '屏蔽服务器';

  @override
  String p2pBlockConfirm(String name) {
    return '屏蔽 $name？将忽略其公布并移除其快照。';
  }

  @override
  String p2pBlocked(String name) {
    return '已屏蔽 $name';
  }

  @override
  String get p2pUnblock => '取消屏蔽';

  @override
  String get p2pUnblocked => '已取消屏蔽服务器';

  @override
  String get p2pIncompatibleNote => '嵌入模型不兼容 — 其曲库无法用于此服务器的相似搜索。';

  @override
  String get p2pCompatible => '模型兼容';

  @override
  String get p2pModelUnknown => '模型未知';

  @override
  String get p2pNoDescription => '没有描述。';

  @override
  String get p2pUnnamedServer => '未命名服务器';

  @override
  String get p2pFederateTitle => '请求联合';

  @override
  String get p2pFederateNote =>
      '通过发现网络发送请求。现在不会交换任何访问权限 — 对方会看到你的名称、消息和提供的内容；只有对方接受后才会共享曲库。';

  @override
  String get p2pMessage => '消息';

  @override
  String p2pMessageHint(int n) {
    return '可选 · $n / 500';
  }

  @override
  String get p2pShareBackLibraries => '对方接受后你将回共享的曲库';

  @override
  String get p2pShareBackNote => '全部取消勾选则为单向请求 — 你只读取对方的曲库。';

  @override
  String get p2pSendRequest => '发送请求';

  @override
  String get p2pRequestSent => '请求已发送 — 在“联合”中跟踪';

  @override
  String p2pRequestFailed(String error) {
    return '无法发送请求：$error';
  }

  @override
  String get p2pTheirTicket => '对方的票据';

  @override
  String get p2pTheirTicketHint => '朋友可以在其 P2P 网络屏幕的“邀请朋友”下找到自己的票据。';

  @override
  String get p2pTicketPasted => '已从剪贴板粘贴。';

  @override
  String get p2pRememberFriend => '记住此朋友';

  @override
  String get p2pRememberFriendSub => '保存到服务器配置中，重启后友谊依然保留。';

  @override
  String get p2pJoinFriend => '加入';

  @override
  String get p2pJoinedFriend => '已加入 — 网状网络会在一分钟内形成';

  @override
  String p2pJoinFriendFailed(String error) {
    return '无法加入：$error';
  }

  @override
  String get p2pNotATicket => '这看起来不像端点票据。';

  @override
  String get p2pScanQr => '扫描二维码';

  @override
  String get p2pScannerTitle => '扫描网络票据';

  @override
  String get p2pInviteFriend => '邀请朋友';

  @override
  String p2pYourTicketNote(String name) {
    return '你的票据 — 朋友在手机上粘贴到这里即可添加 $name。这是一个地址，不是凭据。';
  }

  @override
  String get p2pTicketCopied => '已复制票据';

  @override
  String p2pShareMessage(String ticket) {
    return '在发现网络上添加我的 mStream 服务器 — 在 mStream 应用中打开“P2P 网络 → 添加好友服务器”并粘贴这张票据：\n\n$ticket';
  }

  @override
  String get p2pShareSubject => 'mStream 发现网络票据';

  @override
  String get p2pTicketNotReady => 'P2P 辅助进程（sidecar）尚未运行，所以还没有可分享的票据。';

  @override
  String get p2pSettingsTitle => '网络设置';

  @override
  String get p2pSwitchTitle => '发现网络';

  @override
  String get p2pSwitchSub => '向网络公布仅含元数据的快照。关闭即退出 — 收集的数据保留在本地。';

  @override
  String get p2pLeaveConfirm => '退出发现网络？你的服务器将停止公布和下载快照。本地发现功能继续可用。';

  @override
  String get p2pLeave => '退出';

  @override
  String get p2pLeft => '已退出发现网络';

  @override
  String p2pLeaveFailed(String error) {
    return '无法退出网络：$error';
  }

  @override
  String get p2pEditIdentity => '名称和描述';

  @override
  String get p2pIdentitySaved => '已保存 — 已向网络公布';

  @override
  String p2pSaveFailed(String error) {
    return '无法保存：$error';
  }

  @override
  String get p2pSnapshotsSection => '快照';

  @override
  String get p2pAutoDownload => '自动下载上限';

  @override
  String p2pServersCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count 个服务器',
    );
    return '$_temp0';
  }

  @override
  String get p2pStorageCap => '存储上限';

  @override
  String get p2pRotate => '轮换下载';

  @override
  String get p2pForgetOffline => '忘记离线服务器';

  @override
  String get p2pMeshSection => '网状网络';

  @override
  String get p2pCommunitySeeds => '社区种子';

  @override
  String get p2pCommunitySeedsOn => '通过公共种子服务器引导';

  @override
  String get p2pCommunitySeedsOff => '已关闭 — 仅好友服务器；在服务器配置中设置';

  @override
  String p2pBlockedServers(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count 个已屏蔽的服务器',
      zero: '没有已屏蔽的服务器',
    );
    return '$_temp0';
  }

  @override
  String get p2pBlockedSub => '忽略其公布，绝不获取其快照';

  @override
  String get p2pBlockedTitle => '已屏蔽的服务器';

  @override
  String get p2pSaved => '已保存';

  @override
  String get p2pOff => '关闭';

  @override
  String get p2pSave => '保存';

  @override
  String get p2pSearchServers => '搜索服务器 — 名称或描述';

  @override
  String federationInboxBanner(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count 个联合请求待处理',
    );
    return '$_temp0';
  }

  @override
  String get federationInboxBannerSub => '点击以接受或拒绝';

  @override
  String federationInboxNotificationTitle(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '有 $count 个联合请求待处理',
    );
    return '$_temp0';
  }

  @override
  String federationInboxNotificationBody(String server) {
    return '在 $server 上。打开以接受或拒绝。';
  }

  @override
  String get federationInboxChannelName => '联合请求';

  @override
  String get federationInboxChannelDescription => '你的某台服务器收到了共享曲库的请求';

  @override
  String get federationNotifyTitle => '有请求时通知我';

  @override
  String get federationNotifySubtitle => '应用打开或播放时收到请求，会在手机上发出通知';

  @override
  String get autoRecentlyPlayed => '最近播放';

  @override
  String get settingsHistoryEnabled => '记录播放';

  @override
  String get settingsHistorySend => '将播放发送到服务器';

  @override
  String get settingsHistoryClear => '清除记录';

  @override
  String settingsHistoryClearConfirm(String size, int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '这将删除这部手机的收听记录（$size），包括 $count 次尚未同步的播放。服务器上的记录会保留。',
      zero: '这将删除这部手机的收听记录（$size）。服务器上的记录会保留。',
    );
    return '$_temp0';
  }

  @override
  String get settingsHistoryCleared => '收听记录已清除';

  @override
  String songInfoServerPlays(num count, Object server) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '在 $server 播放 $count 次',
    );
    return '$_temp0';
  }

  @override
  String songInfoDevicePlays(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '在这部手机上播放 $count 次',
    );
    return '$_temp0';
  }

  @override
  String songInfoLastPlayed(Object ago) {
    return '上次 $ago';
  }

  @override
  String get listeningTitle => '收听统计';

  @override
  String get listeningScopeThisPhone => '这部手机';

  @override
  String get listeningScopeSheetTitle => '显示内容';

  @override
  String get listeningScopeSheetDevice => '这部手机播放过的内容：所有服务器、本地文件，包括离线。保存在本机。';

  @override
  String get listeningScopeSheetServer =>
      '你在此服务器上的播放，来自所有应用：网页播放器、其他手机，以及同步后的这部手机。';

  @override
  String get listeningScopeSheetLegacy => '尚无收听统计 — 需要 mStream 6.27 或更高版本。';

  @override
  String listeningScopeSheetPeer(Object server) {
    return '在 $server 上计数：伙伴服务器的曲目在你的账号所在的服务器上计数。';
  }

  @override
  String get listeningProvenanceDevice => '这部手机播放过的内容，包括所有服务器和本地文件。保存在本机。';

  @override
  String listeningProvenanceServer(Object server) {
    return '你在 $server 上的播放，来自所有应用，包括其伙伴服务器的曲目。';
  }

  @override
  String listeningProvenancePeer(Object peer, Object server) {
    return '你对 $peer 曲目的播放，在 $server 上计数。';
  }

  @override
  String listeningProvenanceFallback(Object server) {
    return '$server 没有响应 — 显示这部手机在其上的播放。';
  }

  @override
  String listeningProvenanceLegacy(Object server) {
    return '$server 尚无收听统计（mStream 6.27+）— 显示这部手机在其上的播放。';
  }

  @override
  String listeningUnsynced(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count 次播放尚未同步',
    );
    return '$_temp0';
  }

  @override
  String get listeningPeriodWeek => '本周';

  @override
  String get listeningPeriodMonth => '本月';

  @override
  String get listeningPeriodQuarter => '本季度';

  @override
  String get listeningPeriodYear => '今年';

  @override
  String get listeningPeriodAll => '全部时间';

  @override
  String get listeningTilePlays => '播放';

  @override
  String get listeningTileTime => '收听时长';

  @override
  String get listeningTileTracks => '曲目';

  @override
  String get listeningTileSkips => '跳过';

  @override
  String get listeningTileStreak => '连续天数';

  @override
  String get listeningTileSessions => '会话';

  @override
  String listeningDays(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count 天',
    );
    return '$_temp0';
  }

  @override
  String get listeningTileSubCounted => '计入的播放';

  @override
  String get listeningTileSubTracks => '不同曲目';

  @override
  String listeningTileSubSkips(Object pct) {
    return '占开始播放的 $pct%';
  }

  @override
  String listeningTileSubStreak(Object count) {
    return '最长 $count';
  }

  @override
  String listeningTileSubSessions(Object duration) {
    return '每次约 $duration';
  }

  @override
  String get listeningWhenYouListen => '收听时段';

  @override
  String listeningMostAround(Object hour) {
    return '$hour 前后最多';
  }

  @override
  String get listeningTop => '排行';

  @override
  String get listeningTopTracks => '曲目';

  @override
  String get listeningTopArtists => '艺术家';

  @override
  String get listeningTopAlbums => '专辑';

  @override
  String get listeningByPlays => '播放';

  @override
  String get listeningByTime => '时长';

  @override
  String listeningPlays(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count 次播放',
    );
    return '$_temp0';
  }

  @override
  String listeningTracksCount(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count 首曲目',
    );
    return '$_temp0';
  }

  @override
  String get listeningRecent => '最近播放';

  @override
  String get listeningLoadMore => '加载更多';

  @override
  String get listeningEmptyTitle => '还没有播放记录';

  @override
  String get listeningEmptyDevice =>
      '收听时播放记录会出现在这里。这部手机保存自己的记录；你的服务器保存你在所有应用中的记录。';

  @override
  String listeningEmptyServer(Object server) {
    return '尚未向 $server 报告任何播放。这部手机的播放会在同步后到达。';
  }

  @override
  String get listeningEmptyPeriod => '本时段没有内容。';

  @override
  String get listeningOutcomeCompleted => '已播完';

  @override
  String get listeningOutcomeSkipped => '已跳过';

  @override
  String get listeningOutcomeStopped => '已停止';

  @override
  String listeningOutcomeAt(Object outcome, Object position) {
    return '在 $position $outcome';
  }

  @override
  String get listeningNotCounted => '未计入';

  @override
  String listeningVia(Object peer) {
    return '通过 $peer';
  }

  @override
  String listeningRepeats(Object count) {
    return '×$count';
  }

  @override
  String get listeningLocalFile => '本地文件';

  @override
  String get listeningHistoryOff => '收听记录已关闭。在设置中打开后，这部手机的播放才会被记录。';

  @override
  String listeningError(Object message) {
    return '无法加载：$message';
  }

  @override
  String get listeningRetry => '重试';

  @override
  String get listeningToday => '今天';

  @override
  String get listeningYesterday => '昨天';

  @override
  String get listeningPlaysPerDay => '每日播放次数';

  @override
  String get listeningPlaysPerMonth => '每月播放次数';

  @override
  String listeningMostOnDay(int count, String date) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '最多在 $date：$count 次播放',
    );
    return '$_temp0';
  }

  @override
  String listeningMostInMonth(int count, String month) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '最多在 $month：$count 次播放',
    );
    return '$_temp0';
  }

  @override
  String get settingsHomeWidget => '主屏幕小组件';

  @override
  String get settingsHomeWidgetSubtitleIos => '长按主屏幕，添加小组件并选择 mStream Music。';

  @override
  String get homeWidgetPickSize => '选择尺寸';

  @override
  String get homeWidgetPinUnsupported => '此启动器无法从这里添加小组件，请使用它自带的小组件选择器。';

  @override
  String discoverSheetPeerOnline(String name) {
    return '$name 在线';
  }

  @override
  String discoverSheetPeerNotAnswering(String name) {
    return '$name 无响应';
  }

  @override
  String discoverSheetSongCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count 首歌曲',
    );
    return '$_temp0';
  }

  @override
  String discoverSheetAlbumCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count 张专辑',
    );
    return '$_temp0';
  }

  @override
  String get discoverSheetNotInLibrary => '不在你的曲库中';

  @override
  String get discoverSheetInLibrary => '已在你的曲库中';

  @override
  String discoverSheetYouHaveAlbums(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '你有 $count 张',
    );
    return '$_temp0';
  }

  @override
  String get discoverSheetOpenAlbum => '打开专辑';

  @override
  String get discoverSheetQueueAlbum => '将专辑加入队列';

  @override
  String get discoverSheetPlayAlbum => '播放专辑';

  @override
  String get discoverSheetOpenArtist => '打开艺人';

  @override
  String get discoverSheetListen => '收听';

  @override
  String get discoverSheetKeepCopy => '保留副本';

  @override
  String get discoverSheetOpenElsewhere => '在别处打开';

  @override
  String discoverSheetBrowsePeer(String name) {
    return '浏览 $name';
  }

  @override
  String get discoverSheetDownloadToPhone => '下载到这部手机';

  @override
  String get discoverSheetDownloadToPhoneSub => '用于在此设备上离线播放';

  @override
  String discoverSheetAlbumFailed(String name) {
    return '无法从 $name 加载此专辑';
  }

  @override
  String discoverAlbumCardMore(String album) {
    return '$album 的更多操作';
  }

  @override
  String get discoverKeepThisSong => '这首歌';

  @override
  String get discoverKeepAlbum => '专辑';

  @override
  String get discoverKeepArtist => '艺人';

  @override
  String get discoverKeepWhat => '保留内容';

  @override
  String discoverKeepYouHave(int count) {
    return '你有 $count';
  }

  @override
  String discoverKeepOnlyMissing(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '只要你没有的 $count 张',
    );
    return '$_temp0';
  }

  @override
  String get discoverKeepFilesGoTo => '文件保存到';

  @override
  String discoverKeepPathTooLong(int max) {
    return '这份副本的路径将超过 $max 个字符，超出服务器的上限';
  }

  @override
  String get discoverKeepFolderPerAlbum => '每张专辑一个文件夹';

  @override
  String get discoverKeepChange => '更改';

  @override
  String get discoverKeepChangeHint => '更改副本的保存位置';

  @override
  String get discoverKeepAddSong => '添加歌曲';

  @override
  String get discoverKeepAddAlbum => '添加专辑';

  @override
  String get discoverKeepAddEveryAlbum => '添加全部专辑';

  @override
  String discoverKeepAddAlbums(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '添加 $count 张专辑',
    );
    return '$_temp0';
  }

  @override
  String get discoverKeepAddMissing => '添加你没有的专辑';

  @override
  String get discoverKeepUploadsOff => '你的账户无法向此服务器添加文件';

  @override
  String get discoverKeepNoLibrary => '你的服务器上没有可接收新文件的曲库';

  @override
  String get discoverKeepStartFailed => '无法连接到你的服务器，请重试。';

  @override
  String get discoverKeepDestChanged => '打开后文件存放位置已变。请检查上方路径后重新添加。';

  @override
  String get discoverKeepDestChangedTryAgain => '打开后文件存放位置已变。请检查上方路径后重试。';

  @override
  String discoverKeepRetryAddsTo(String path) {
    return '重试将存放到 $path，即你现在保存的位置';
  }

  @override
  String discoverKeepAddAgainAddsTo(String path) {
    return '重新添加将存放到 $path，即你现在保存的位置';
  }

  @override
  String discoverKeepConfirmTitle(int count, String peer) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '要从 $peer 复制 $count 张专辑吗？',
    );
    return '$_temp0';
  }

  @override
  String discoverKeepConfirmEveryTitle(String artist, String peer) {
    return '要从 $peer 复制 $artist 的全部专辑吗？';
  }

  @override
  String discoverKeepConfirmBody(String path) {
    return '它们会存放到你服务器上的 $path，每张专辑一个文件夹。你已有的歌曲会被跳过。';
  }

  @override
  String discoverKeepConfirmBodyFlat(String path) {
    return '它们会存放到你服务器上的 $path。你已有的歌曲会被跳过。';
  }

  @override
  String discoverKeepConfirmAction(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '复制 $count 张专辑',
    );
    return '$_temp0';
  }

  @override
  String get discoverKeepConfirmEveryAction => '复制全部专辑';

  @override
  String get discoverJobQueued => '正在等待空闲位置';

  @override
  String get discoverJobQueuedSub => '会自动开始';

  @override
  String get discoverJobCopying => '正在复制';

  @override
  String get discoverJobStarting => '正在开始…';

  @override
  String get discoverJobStopping => '正在停止…';

  @override
  String get discoverJobInCollection => '已在你的收藏中';

  @override
  String get discoverJobOwned => '你已拥有';

  @override
  String get discoverJobOwnedSub => '你的曲库已有这首歌';

  @override
  String get discoverJobSkipped => '已跳过 · 该位置已有文件';

  @override
  String discoverJobExistsSub(String path) {
    return '$path 已有文件 · 未覆盖任何内容';
  }

  @override
  String get discoverJobFailed => '复制失败';

  @override
  String get discoverJobFailedSub => '复制未完成';

  @override
  String get discoverJobNothingCopiedLead => '未复制任何内容';

  @override
  String get discoverJobNothingCopied => '未复制任何内容';

  @override
  String get discoverJobStopped => '已停止';

  @override
  String discoverJobStoppedQuota(String peer) {
    return '$peer 的传输限额使其停止';
  }

  @override
  String discoverJobStoppedBusy(String peer) {
    return '$peer 当前的串流太多';
  }

  @override
  String discoverJobStoppedPeer(String peer) {
    return '$peer 已断开';
  }

  @override
  String discoverJobStoppedRefused(String peer) {
    return '$peer 不允许使用你服务器的密钥进行复制';
  }

  @override
  String get discoverJobCancelledNothing => '已停止 · 未复制任何内容';

  @override
  String discoverJobCancelledSome(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '已停止 · 已复制 $count 首',
    );
    return '$_temp0';
  }

  @override
  String get discoverJobCancelledSub => '你已取消';

  @override
  String discoverJobCancelledStay(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '你已取消 · $count 首歌曲保留在你的收藏中',
    );
    return '$_temp0';
  }

  @override
  String get discoverJobNothingAll => '你已全部拥有';

  @override
  String discoverJobNothingFrom(String peer) {
    return '没有可从 $peer 复制的内容';
  }

  @override
  String get discoverJobOnlyGuest => '没有其本人的作品可复制';

  @override
  String discoverJobOnlyGuestSub(String artist, String peer) {
    return '$artist 只是以嘉宾身份出现在 $peer 的专辑中';
  }

  @override
  String discoverJobFromOther(String peer) {
    return '正在从 $peer 复制';
  }

  @override
  String discoverJobComesBack(String action) {
    return '该复制结束后，“$action”会重新出现';
  }

  @override
  String get discoverJobDone => '已完成';

  @override
  String discoverJobCopiedCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '已复制 $count 首',
    );
    return '$_temp0';
  }

  @override
  String discoverJobOwnedCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count 首你已拥有',
    );
    return '$_temp0';
  }

  @override
  String discoverJobFailedCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count 首失败',
    );
    return '$_temp0';
  }

  @override
  String discoverJobAlbumsFailed(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count 张专辑失败',
    );
    return '$_temp0';
  }

  @override
  String discoverJobAlbumsLeftOut(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '略过 $count 张专辑',
    );
    return '$_temp0';
  }

  @override
  String get discoverJobRetry => '重试';

  @override
  String get discoverJobAddAgain => '重新添加';

  @override
  String get discoverJobAddToQueue => '添加到队列';

  @override
  String get discoverMarkWaiting => '等待中';

  @override
  String get discoverMarkCopying => '复制中…';

  @override
  String discoverMarkCopyingCount(int done, int total) {
    return '复制中 $done/$total';
  }

  @override
  String get discoverMarkStopping => '停止中…';

  @override
  String get discoverMarkInCollection => '已在收藏中';

  @override
  String get discoverMarkAlreadyYours => '已拥有';

  @override
  String get discoverMarkStopped => '已停止';

  @override
  String get discoverMarkRefused => '被拒绝';

  @override
  String get discoverMarkFailed => '失败';

  @override
  String get discoverMarkSkipped => '已跳过';

  @override
  String discoverCopiesCopying(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '正在复制 $count 项',
    );
    return '$_temp0';
  }

  @override
  String discoverCopiesFailed(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count 项失败',
    );
    return '$_temp0';
  }

  @override
  String discoverCopiesLabel(String summary) {
    return '副本：$summary';
  }

  @override
  String get discoverCopiesTitle => '副本';

  @override
  String get discoverCopiesSectionCopying => '正在复制';

  @override
  String get discoverCopiesSectionAttention => '已停止或失败';

  @override
  String get discoverCopiesSectionFinished => '刚刚完成';

  @override
  String get discoverCopiesClearFinished => '清除已完成';

  @override
  String get discoverCopiesEmpty => '没有正在复制的内容';

  @override
  String get discoverCopiesEmptySub => '在“发现”中长按已连接服务器的歌曲或专辑，即可保留副本。';

  @override
  String get discoverCopiesOpenDiscover => '打开“发现”';

  @override
  String get discoverCopiesLoadFailed => '无法加载你的副本';

  @override
  String get discoverCopiesLoadFailedSub => '你的服务器没有响应。复制仍在服务器上进行。';

  @override
  String get discoverCopiesLoading => '正在加载你的副本';

  @override
  String get discoverCopiesKindSong => '歌曲';

  @override
  String get discoverCopiesKindAlbum => '专辑';

  @override
  String get discoverCopiesKindEvery => '全部专辑';

  @override
  String get discoverCopiesKindMissing => '你缺少的';

  @override
  String discoverCopiesFrom(String peer) {
    return '来自 $peer';
  }

  @override
  String discoverCopiesEveryAlbumBy(String artist) {
    return '$artist 的全部专辑';
  }

  @override
  String discoverCopiesMissingOf(String artist) {
    return '$artist · 你没有的专辑';
  }

  @override
  String get discoverCopiesAlreadyFinished => '已经完成 · 无需取消';

  @override
  String get discoverCopiesCancelFailed => '无法取消，请重试。';

  @override
  String get discoverCopiesDestChanged => '无法开始：文件存放位置已变 — 请从“保留副本”重试';

  @override
  String discoverToastCopying(String title, String peer) {
    return '正在从 $peer 复制 $title';
  }

  @override
  String discoverToastCopyingEvery(String artist, String peer) {
    return '正在从 $peer 复制 $artist 的全部专辑';
  }

  @override
  String discoverToastCopyingMissing(String artist, String peer) {
    return '正在从 $peer 复制你没有的 $artist 专辑';
  }

  @override
  String get discoverToastAdded => '已添加到你的收藏';

  @override
  String get discoverToastAlreadyYours => '已在你的曲库中';

  @override
  String discoverToastFailed(String reason) {
    return '复制失败：$reason';
  }

  @override
  String discoverToastStopped(String reason) {
    return '提前停止：$reason';
  }

  @override
  String get discoverToastLinkFailed => '无法打开该链接';

  @override
  String discoverToastSaved(String path) {
    return '已保存 · 副本将存放到 $path';
  }

  @override
  String get discoverDestTitle => '副本存放位置';

  @override
  String get discoverDestSub => '账户的统一设置 · 所有副本都使用它';

  @override
  String get discoverDestTagDefault => '曲库默认';

  @override
  String get discoverDestTagYours => '你的';

  @override
  String discoverDestLandsAt(String title) {
    return '$title 将存放到';
  }

  @override
  String get discoverDestFixLayout => '修正布局即可查看文件存放位置';

  @override
  String discoverDestPathTooLong(int max) {
    return '这首歌的路径将超过 $max 个字符，超出服务器的上限';
  }

  @override
  String get discoverDestLibrary => '曲库';

  @override
  String get discoverDestLayout => '布局';

  @override
  String get discoverDestPresetArtistAlbum => '艺人 / 专辑';

  @override
  String get discoverDestPresetServer => '服务器 / 艺人 / 专辑';

  @override
  String get discoverDestPresetServerFolders => '与服务器相同的文件夹';

  @override
  String get discoverDestPresetLibrary => '曲库布局';

  @override
  String get discoverDestPresetCustom => '自定义';

  @override
  String get discoverDestCustomSub => '自己输入路径';

  @override
  String get discoverDestCustomField => '自定义布局';

  @override
  String discoverDestCustomHint(String example) {
    return '例如 朋友分享 或 $example';
  }

  @override
  String get discoverDestCustomHelp =>
      '用 / 分隔文件夹。变量按艺人、专辑等整理副本；固定名称会把所有副本放进同一个文件夹。';

  @override
  String get discoverDestCustomEmpty => '输入路径即可查看文件存放位置';

  @override
  String get discoverDestInsertArtist => '插入艺人';

  @override
  String get discoverDestInsertAlbum => '插入专辑';

  @override
  String get discoverDestInsertYear => '插入年份';

  @override
  String get discoverDestInsertGenre => '插入流派';

  @override
  String get discoverDestInsertAlbumArtist => '插入专辑艺人';

  @override
  String get discoverDestInsertPeer => '插入服务器名称';

  @override
  String get discoverDestInsertServerFolder => '插入服务器文件夹';

  @override
  String discoverDestErrUnknownVar(String name, String vars) {
    return '未知变量 $name。请使用 $vars。';
  }

  @override
  String discoverDestErrBraces(String example) {
    return '花括号位置不对——变量应写成 $example。';
  }

  @override
  String discoverDestErrBaseBraces(String folder) {
    return '“$folder”是在其他设备上设置的文件夹，但在布局中会被当作变量。请在这里重命名，或选择一种布局。';
  }

  @override
  String get discoverDestErrAbsolute => '布局不能以 / 开头——它从曲库内开始。';

  @override
  String get discoverDestErrTraversal => '路径不能包含“..”文件夹。';

  @override
  String get discoverDestErrEmpty => '这样不会生成任何文件夹——请添加名称或变量。';

  @override
  String get discoverDestErrHome => '路径不能包含 ~ 或 \$HOME。';

  @override
  String get discoverDestErrGeneric => '无法使用此路径。';

  @override
  String get discoverDestErrDrive => '路径不能使用 C: 这样的盘符。';

  @override
  String discoverDestErrTooLong(int max) {
    return '布局最多 $max 个字符。';
  }

  @override
  String get discoverDestErrControl => '路径不能包含制表符或其他控制字符。';

  @override
  String discoverDestMissing(String vars) {
    return '这首歌没有该值，因此不计入路径：$vars';
  }

  @override
  String get discoverDestGenreSlot => '流派';

  @override
  String get discoverDestArtistSlot => '艺人';

  @override
  String get discoverDestYearSlot => '年份';

  @override
  String get discoverDestServerFolderSlot => '服务器文件夹';

  @override
  String discoverKeepSlotNote(int count, String slots) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$slots 取自每首歌自己的标签，因此这些歌可能会放进不止一个文件夹。',
    );
    return '$_temp0';
  }

  @override
  String discoverKeepSlotNoteGenre(int count, String slots) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$slots 取自每首歌自己的标签，因此这些歌可能会放进不止一个文件夹（没有流派的歌会省去该文件夹）。',
    );
    return '$_temp0';
  }

  @override
  String discoverKeepSlotNoteSong(String slots) {
    return '$slots 取自这首歌自己的标签（没有流派的歌会省去该文件夹）。';
  }

  @override
  String discoverKeepSlotNoteServer(String server) {
    return '$server 取决于每首歌在服务器上的位置，因此这些歌可能会放进不止一个文件夹。';
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
      other: '$slots 取自每首歌自己的标签，$server 取决于它在服务器上的位置，因此这些歌可能会放进不止一个文件夹。',
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
          '$slots 取自每首歌自己的标签，$server 取决于它在服务器上的位置，因此这些歌可能会放进不止一个文件夹（没有流派的歌会省去该文件夹）。',
    );
    return '$_temp0';
  }

  @override
  String get discoverDestUseDefault => '使用曲库默认设置';

  @override
  String get discoverDestSaving => '正在保存…';

  @override
  String get discoverDestLoadFailed => '无法加载副本存放位置';

  @override
  String get discoverDestLoading => '正在加载副本存放位置';

  @override
  String get discoverKeepFirstUse => '副本会存放到你的服务器，而不是这部手机。第一次复制前请先确认存放位置。';

  @override
  String get discoverElsewhereExact => '精确页面';

  @override
  String get discoverElsewhereSearch => '搜索';

  @override
  String get discoverElsewhereMbRecording => 'MusicBrainz 录音';

  @override
  String get discoverElsewhereMbReleaseGroup => 'MusicBrainz 发行组';

  @override
  String get discoverElsewhereMbIsrc => 'MusicBrainz ISRC';

  @override
  String get discoverElsewhereEmpty => '这首歌没有链接';

  @override
  String get discoverElsewhereEmptySub => '它没有 MusicBrainz ID，也没有可搜索的标题或艺人。';

  @override
  String get discoverElsewhereFailed => '暂时无法查找链接';

  @override
  String get discoverElsewhereLoading => '正在查找链接';

  @override
  String get discoverElsewhereOpensOutside => '在应用外打开';

  @override
  String get visualizerMilkdropTitle => 'Milkdrop 可视化';

  @override
  String get visualizerShadertoyTitle => 'ShaderToy 可视化';

  @override
  String get realAudioSynthesizedNote => '未获得权限时，可视化效果将使用合成数据。';

  @override
  String get realAudioDontAskAgain => '不再询问';

  @override
  String get realAudioUseSynthesized => '使用合成数据';

  @override
  String get realAudioUseReal => '使用真实音频';

  @override
  String get queueSharePlaylist => '分享播放列表';

  @override
  String get autoDjStopShort => '停止';

  @override
  String get autoDjPlayFrom => '播放来源';

  @override
  String get autoDjAllServers => '所有服务器';

  @override
  String autoDjServersTakingPart(int count, int total) {
    return '$count/$total';
  }

  @override
  String get autoDjFirstSong => '第一首';

  @override
  String get autoDjFirstSongRandom => '随机';

  @override
  String get autoDjFirstSongChoose => '选择';

  @override
  String get autoDjMustMatch => '必须符合';

  @override
  String get autoDjPrefer => '偏好';

  @override
  String autoDjPercent(int pct) {
    return '$pct%';
  }

  @override
  String get autoDjDrift => '随流漂移';

  @override
  String get autoDjStayClose => '保持接近';

  @override
  String get autoDjGenres => '流派';

  @override
  String get autoDjGenresOnly => '仅限';

  @override
  String get autoDjGenresSkip => '排除';

  @override
  String autoDjGenresSkipValue(String genres) {
    return '排除 $genres';
  }

  @override
  String get autoDjRating => '评分';

  @override
  String autoDjRatingValue(String stars) {
    return '$stars★及以上';
  }

  @override
  String get autoDjAny => '不限';

  @override
  String autoDjLengthOver(String min) {
    return '$min 以上';
  }

  @override
  String autoDjLengthUnder(String max) {
    return '$max 以内';
  }

  @override
  String autoDjLengthBetween(String min, String max) {
    return '$min–$max';
  }

  @override
  String get autoDjIncludeUnknown => '包括未知';

  @override
  String get autoDjLengthShortest => '最短';

  @override
  String get autoDjLengthLongest => '最长';

  @override
  String get autoDjWheelHours => '小时';

  @override
  String get autoDjTempo => '节拍匹配';

  @override
  String get autoDjSkipWords => '排除词';

  @override
  String get autoDjBatch => '批量';

  @override
  String get autoDjVaries => '各不相同';

  @override
  String autoDjMax(int count) {
    return '最多 $count';
  }

  @override
  String autoDjNeedsServer(String version) {
    return '服务器 $version+';
  }

  @override
  String get autoDjDiscoveryOff => '发现已关闭';

  @override
  String get autoDjStillScanning => '仍在扫描';

  @override
  String get autoDjTooStrict => '过于严格';

  @override
  String get autoDjNotOnPeers => '对等服务器不可用';

  @override
  String get autoDjNoMoodData => '无氛围数据';

  @override
  String get autoDjOtherModel => '音频模型不同';

  @override
  String get autoDjUnreachable => '无法连接';

  @override
  String get autoDjRemember => '记住';

  @override
  String get autoDjGenresNone => '没有流派';

  @override
  String get autoDjNoMatches => '无匹配';

  @override
  String get autoDjRecentlyPlayed => '最近播放';

  @override
  String get autoDjFirstSongRecent => '最近播放';

  @override
  String get browseLoadFailed =>
      'Couldn\'t load this from the server. Check the connection and try again.';

  @override
  String get settingsSectionVisualizer => '可视化';

  @override
  String get settingsOfflineQueueFooter => '仅针对播放队列的下载。你自己下载的歌曲始终保留。';

  @override
  String settingsAutoDownloadCapValue(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count 首歌曲',
    );
    return '$_temp0';
  }

  @override
  String get settingsAutoDownloadCapHint => '0 = 不限';

  @override
  String get settingsStartupRecentHint => '新加入曲库的歌曲';

  @override
  String settingsLetterStripValue(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count+ 项',
      zero: '始终显示',
    );
    return '$_temp0';
  }

  @override
  String get settingsLetterStripHint => '用于 A–Z 列表。较短的列表则改为长名称换行。';

  @override
  String get settingsHistoryFooter => '只有在服务器上关联了账号，服务器才会向 Last.fm 提交播放。';

  @override
  String get settingsHistoryEmpty => '无记录';

  @override
  String get settingsHistoryOffTitle => '停止记录播放？';

  @override
  String settingsHistoryOffBody(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '这将删除这部手机的收听记录，包括 $count 次尚未同步的播放。服务器上的记录会保留。',
      zero: '这将删除这部手机的收听记录。服务器上的记录会保留。',
    );
    return '$_temp0';
  }

  @override
  String get settingsHistoryOffConfirm => '关闭';

  @override
  String get settingsHistoryClearTitle => '清除记录？';

  @override
  String get settingsResetTitle => '重置设置？';

  @override
  String get settingsResetBody =>
      '同时会重置均衡器、转码，以及设置页面以外的少数选项。服务器、下载内容、收听记录和已保存的预设不受影响。';

  @override
  String get settingsResetBodyIos => '同时会重置转码，以及设置页面以外的少数选项。服务器、下载内容和收听记录不受影响。';

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
