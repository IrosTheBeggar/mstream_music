// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Portuguese (`pt`).
class AppLocalizationsPt extends AppLocalizations {
  AppLocalizationsPt([String locale = 'pt']) : super(locale);

  @override
  String get mainRemove => 'Remover';

  @override
  String get playlistActionFailed =>
      'Não foi possível guardar a playlist — o nome pode já estar em uso.';

  @override
  String get queueAddNext => 'Adicionar a seguir';

  @override
  String get queuePlayNow => 'Reproduzir agora';

  @override
  String get queueAddToEnd => 'Adicionar ao fim da fila';

  @override
  String get shuffle => 'Aleatório';

  @override
  String get variousArtists => 'Vários artistas';

  @override
  String get appTitle => 'mStream Music';

  @override
  String get settingsLanguage => 'Idioma';

  @override
  String get languageSystemDefault => 'Padrão do sistema';

  @override
  String get settingsLanguageSubtitle =>
      'O idioma de exibição do app. \"Padrão do sistema\" segue o seu dispositivo.';

  @override
  String couldNotOpen(String url) {
    return 'Não foi possível abrir $url';
  }

  @override
  String trackCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count faixas',
      one: '1 faixa',
      zero: 'Nenhuma faixa',
    );
    return '$_temp0';
  }

  @override
  String get reset => 'Redefinir';

  @override
  String get themeVelvet => 'Velvet';

  @override
  String get themeDark => 'Escuro';

  @override
  String get themeLight => 'Claro';

  @override
  String get tapAddToQueue => 'Adicionar à fila';

  @override
  String get tapPlayFromHere => 'Tocar a partir daqui';

  @override
  String get tapAppendAndJump => 'Adicionar e tocar';

  @override
  String get visualizerEngineMilkdrop => 'Milkdrop';

  @override
  String get visualizerEngineShaders => 'Shaders';

  @override
  String get visualizerSourceSynthesized => 'Sintetizado';

  @override
  String get visualizerSourceReal => 'Áudio real';

  @override
  String get downloadsTitle => 'Downloads';

  @override
  String downloadProgress(String progress) {
    return 'progresso: $progress%';
  }

  @override
  String get songInfoTitle => 'Informações da música';

  @override
  String get lyricsTitle => 'Lyrics';

  @override
  String get lyricsEmpty => 'No lyrics found for this song';

  @override
  String get lyricsError => 'Couldn\'t load lyrics';

  @override
  String get lyricsRetry => 'Retry';

  @override
  String get eqTitle => 'Equalizador';

  @override
  String get eqOnlyAndroid => 'O equalizador só está disponível no Android.';

  @override
  String get eqNeedsPlayback =>
      'Inicie uma música para configurar o equalizador.\n\nO equalizador nativo do Android é inicializado junto com a sessão de áudio, então é preciso ter a reprodução ativa antes de conseguir ler o layout das bandas.';

  @override
  String eqInitFailed(String error) {
    return 'Não foi possível inicializar o equalizador:\n$error';
  }

  @override
  String get eqNoBands =>
      'Nenhuma banda de equalização informada pelo driver de áudio deste dispositivo.';

  @override
  String get eqDisabledHint => 'Ative o equalizador para ajustar as bandas.';

  @override
  String get eqEnabledOn => 'Ligado — ganhos aplicados à reprodução';

  @override
  String get eqEnabledOff => 'Desligado — modo bypass';

  @override
  String get cancel => 'Cancelar';

  @override
  String get continueLabel => 'Continuar';

  @override
  String get openSettings => 'Abrir configurações';

  @override
  String get settingsTitle => 'Configurações';

  @override
  String get settingsSectionAppearance => 'Aparência';

  @override
  String get settingsSectionPlayback => 'Reprodução';

  @override
  String get settingsSectionBrowse => 'Navegar';

  @override
  String get settingsSectionAbout => 'Sobre';

  @override
  String get settingsTheme => 'Tema';

  @override
  String get themeSubtitleVelvet =>
      'Azul-marinho e roxo — o tema escuro característico.';

  @override
  String get themeSubtitleDark => 'Escuro neutro com detalhes em âmbar.';

  @override
  String get themeSubtitleLight =>
      'Corpo claro com barra superior escura e detalhes em âmbar — combina com o tema antigo.';

  @override
  String get settingsTranscode => 'Transcodificar áudio';

  @override
  String get settingsTranscodeSubtitle =>
      'Transmite uma cópia transcodificada do servidor (arquivos menores, início um pouco mais lento). Desligado, toca os arquivos originais.';

  @override
  String get transcodeTitle => 'Transcodificação';

  @override
  String get transcodeCodec => 'Codec';

  @override
  String get transcodeBitrate => 'Taxa de bits';

  @override
  String get transcodeAuto => 'Padrão do servidor';

  @override
  String get transcodeUnavailable =>
      'Este servidor não tem a transcodificação ativada — as suas faixas são transmitidas na qualidade original.';

  @override
  String get transcodeReloadQueue => 'Aplicar à fila atual';

  @override
  String get transcodeReloadQueueSubtitle =>
      'Ao alterar as definições de transcodificação — marcado: recarregar toda a fila agora (a faixa em reprodução faz buffer por instantes); desmarcado: só mudam as faixas seguintes, a atual termina sem alterações.';

  @override
  String get settingsTapBehavior => 'Ao tocar em uma música';

  @override
  String get settingsStartupPage => 'Tela inicial';

  @override
  String get settingsStartupPageSubtitle =>
      'Abrir o app nesta visualização do navegador; Voltar retorna ao navegador.';

  @override
  String get tapSubtitleAddToQueue =>
      'Tocar em uma música a adiciona à fila. Se a fila estiver vazia, a reprodução começa automaticamente.';

  @override
  String get tapSubtitlePlayFromHere =>
      'Tocar em uma música substitui a fila pelas músicas da visualização atual e inicia a reprodução pela música tocada.';

  @override
  String get tapSubtitleAppendAndJump =>
      'Tocar em uma música a adiciona à fila e pula a reprodução para ela, interrompendo o que estava tocando.';

  @override
  String get settingsEqSubtitle =>
      'Ajuste graves, médios e agudos. Apenas no Android.';

  @override
  String get settingsVisualizerEngine => 'Motor do visualizador';

  @override
  String get visualizerEngineSubtitleMilkdrop =>
      'Predefinições do Milkdrop via projectM (padrão). Efeitos mais ricos, mais pesados para a GPU.';

  @override
  String get visualizerEngineSubtitleShaders =>
      'Shaders de fragmento no estilo Shadertoy. Mais leves e modulares — coloque arquivos .glsl em assets/shaders/ para ampliar o catálogo.';

  @override
  String get settingsVisualizerSource => 'Fonte de áudio do visualizador';

  @override
  String get visualizerSourceSubtitleSynthesized =>
      'Padrão. O visualizador reage apenas ao tempo da reprodução — não exige permissão de microfone.';

  @override
  String get visualizerSourceSubtitleReal =>
      'O visualizador reage à saída de áudio real. Exige a permissão RECORD_AUDIO no Android.';

  @override
  String get settingsAlbumGrid => 'Visualização em grade de álbuns';

  @override
  String get settingsAlbumGridSubtitle =>
      'Mostra os álbuns como uma grade de cartões com capas em vez de uma lista simples.';

  @override
  String get settingsFileMetadata =>
      'Ler metadados das músicas no explorador de arquivos';

  @override
  String get settingsFileMetadataSubtitle =>
      'Busca título, artista e capa de cada música ao navegar pelos arquivos do servidor. Desligado, mostra os nomes brutos dos arquivos (mais rápido em pastas enormes).';

  @override
  String get settingsLetterStrip => 'Limite do scrubber de letras';

  @override
  String get settingsLetterStripSubtitle =>
      'Mostra a barra de navegação rápida A-Z quando uma lista tiver esta quantidade de itens ou mais. Abaixo disso, a barra fica oculta e nomes longos de pastas/arquivos quebram em várias linhas em vez de serem cortados. Defina 0 para sempre mostrar a barra.';

  @override
  String get settingsLetterStripSide => 'Lado da barra';

  @override
  String get settingsLetterStripSideSubtitle =>
      'Em que extremidade fica a barra A–Z.';

  @override
  String get settingsLetterStripLeft => 'Esquerda';

  @override
  String get settingsLetterStripRight => 'Direita';

  @override
  String get settingsReset => 'Restaurar padrões';

  @override
  String get settingsResetSubtitle =>
      'Restaura todas as configurações desta tela aos valores padrão. Servidores e downloads não são afetados.';

  @override
  String get settingsResetDone => 'Configurações restauradas aos padrões';

  @override
  String get realAudioDialogTitle => 'Usar áudio real?';

  @override
  String get realAudioDialogBody =>
      'O modo de áudio real lê a forma de onda da música que o seu celular está tocando para que o visualizador possa reagir a ela. O Android exige a permissão RECORD_AUDIO para isso — o app não grava nem envia áudio a lugar nenhum. Você pode voltar para o sintetizado a qualquer momento.';

  @override
  String get realAudioPermPermanentlyDenied =>
      'Permissão negada permanentemente. Ative-a nas configurações do sistema para usar áudio real.';

  @override
  String get realAudioPermDenied =>
      'Permissão negada. Mantendo o áudio sintetizado.';

  @override
  String get visualizerTapHint =>
      'Toque = próxima predefinição · pressione e segure para fechar';

  @override
  String get visualizerFailed => 'Falha ao iniciar o visualizador';

  @override
  String get visualizerBringingUp => 'Inicializando o renderizador…';

  @override
  String get visualizerReady => 'Visualizador pronto';

  @override
  String get visualizerBridgeFailed => 'Falha ao iniciar a ponte';

  @override
  String visualizerAudioSourceLine(String source) {
    return 'Fonte de áudio: $source';
  }

  @override
  String get visualizerTapToClose => 'Toque em qualquer lugar para fechar';

  @override
  String get visualizerUnsupported =>
      'O visualizador só é compatível com o Android no momento.';

  @override
  String get aboutTitle => 'Sobre';

  @override
  String aboutBuiltBy(String name) {
    return 'Criado por $name';
  }

  @override
  String get linkDiscordSubtitle => 'Bate-papo da comunidade';

  @override
  String get linkGithubSubtitle => 'Código-fonte do servidor mStream';

  @override
  String get linkHomepageSubtitle => 'Página do projeto';

  @override
  String get aboutAttributions => 'Créditos';

  @override
  String get aboutAttributionsSubtitle =>
      'Licença, créditos de shaders e avisos de código aberto.';

  @override
  String get aboutSponsor => 'Apoiar o mStream';

  @override
  String get ok => 'OK';

  @override
  String get delete => 'Excluir';

  @override
  String get edit => 'Editar';

  @override
  String get info => 'Informações';

  @override
  String get makeDefault => 'Tornar padrão';

  @override
  String get goBack => 'Voltar';

  @override
  String get play => 'Tocar';

  @override
  String get playAll => 'Tocar tudo';

  @override
  String get rename => 'Renomear';

  @override
  String get create => 'Criar';

  @override
  String get copy => 'Copiar';

  @override
  String get done => 'Concluído';

  @override
  String get copiedToClipboard => 'Copiado para a área de transferência';

  @override
  String get attributionsTitle => 'Créditos';

  @override
  String get attributionsSectionLicense => 'Licença';

  @override
  String get attributionsSectionShaders => 'Shaders do visualizador';

  @override
  String get attributionsSectionLibraries => 'Bibliotecas nativas';

  @override
  String get attributionsSectionEverythingElse => 'Tudo o mais';

  @override
  String get attributionsLicenseBody =>
      'Software livre sob a GNU General Public License v3.0. Você pode usá-lo, estudá-lo, compartilhá-lo e modificá-lo sob esses termos.';

  @override
  String get attributionsPackages => 'Licenças de pacotes de código aberto';

  @override
  String get attributionsPackagesSubtitle =>
      'Textos completos das licenças de todos os pacotes Flutter/Dart incluídos.';

  @override
  String get manageServersTitle => 'Gerenciar servidores';

  @override
  String get manageServerInfo => 'Informações do servidor';

  @override
  String get manageServerDownloadFolder => 'Pasta de download:';

  @override
  String get manageServerCopyPath => 'Copiar caminho de download';

  @override
  String get manageServerPathCopied =>
      'Caminho copiado para a área de transferência';

  @override
  String get confirmRemoveServerTitle => 'Confirmar remoção do servidor';

  @override
  String get removeSyncedFiles =>
      'Remover arquivos sincronizados do dispositivo?';

  @override
  String get playlistsTitle => 'Playlists';

  @override
  String get playlistsNew => 'Nova playlist';

  @override
  String get playlistsEmptyTitle => 'Nenhuma playlist ainda';

  @override
  String get playlistsEmptyBody =>
      'Crie uma com o botão Nova playlist e depois use o gesto de deslizar Adicionar à playlist na fila para preenchê-la.';

  @override
  String get playlistNameHint => 'Nome';

  @override
  String get playlistsRename => 'Renomear playlist';

  @override
  String get playlistFallbackTitle => 'Playlist';

  @override
  String get playlistEmptyDetail =>
      'A playlist está vazia.\nAdicione faixas pela fila.';

  @override
  String get shareEmptyTitle => 'Fila vazia';

  @override
  String get shareEmptyBody => 'Adicione músicas à fila antes de compartilhar.';

  @override
  String get shareBlockedTitle => 'Não é possível compartilhar esta fila';

  @override
  String get shareLocalOnlyBody =>
      'A fila contém músicas que estão apenas neste dispositivo (não em nenhum servidor). O compartilhamento só funciona quando todas as músicas da fila vêm de um único servidor.';

  @override
  String shareMultiServerBody(int count, String names) {
    return 'A fila mistura músicas de $count servidores ($names). O compartilhamento só funciona quando todas as músicas vêm de um único servidor.';
  }

  @override
  String shareServerGoneBody(String name) {
    return 'O servidor \"$name\" não está mais na sua lista de servidores. Adicione-o novamente para compartilhar a fila dele.';
  }

  @override
  String get shareTitle => 'Compartilhar playlist';

  @override
  String shareSongCount(int count, String url) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count músicas',
      one: '1 música',
    );
    return '$_temp0 de $url';
  }

  @override
  String get shareLinkExpires => 'O link expira';

  @override
  String get shareExpireNever => 'Nunca';

  @override
  String get shareExpire1Day => 'Após 1 dia';

  @override
  String get shareExpire7Days => 'Após 7 dias';

  @override
  String get shareExpire30Days => 'Após 30 dias';

  @override
  String get shareAction => 'Compartilhar';

  @override
  String get shareDoneTitle => 'Playlist compartilhada';

  @override
  String get shareDoneBody =>
      'Qualquer pessoa com este link pode tocar a fila:';

  @override
  String get save => 'Salvar';

  @override
  String get start => 'Iniciar';

  @override
  String get addServerTitle => 'Adicionar servidor';

  @override
  String get editServerTitle => 'Editar servidor';

  @override
  String get fieldServerUrl => 'URL do servidor';

  @override
  String get fieldPublicAccess => 'Acesso público';

  @override
  String get publicAccessSubtitle =>
      'O servidor é acessível publicamente — não é preciso usuário nem senha.';

  @override
  String get fieldUsername => 'Usuário';

  @override
  String get fieldPassword => 'Senha';

  @override
  String get fieldSdCard => 'Baixar para o cartão SD';

  @override
  String get sdCardSubtitle =>
      'Salva a música baixada no cartão SD removível em vez do armazenamento interno.';

  @override
  String get testConnectionButton => 'Testar conexão';

  @override
  String get testing => 'Testando…';

  @override
  String get connecting => 'Conectando…';

  @override
  String get validatorUrlNeeded => 'A URL do servidor é necessária';

  @override
  String get validatorUrlParse => 'Não foi possível interpretar a URL';

  @override
  String get testEnterUrl => 'Informe uma URL de servidor primeiro.';

  @override
  String get testParseUrl => 'Não foi possível interpretar a URL.';

  @override
  String get testTimedOut => 'Tempo de conexão esgotado.';

  @override
  String get connectionSuccessful => 'Conexão bem-sucedida!';

  @override
  String get couldNotReachServer =>
      'Não foi possível acessar o servidor. Se ele exigir login, desative o \"Acesso público\" e adicione as credenciais.';

  @override
  String get failedToLogin => 'Falha ao fazer login';

  @override
  String testConnected(String version) {
    return 'Conectado — mStream v$version';
  }

  @override
  String testConnectFailed(String error) {
    return 'Não foi possível conectar: $error';
  }

  @override
  String get sleepTimerTitle => 'Temporizador para dormir';

  @override
  String get sleepTimerHint =>
      'Escolha uma duração para pausar a reprodução depois.';

  @override
  String get sleepTimerCustom => 'Personalizado';

  @override
  String get sleepTimerCustomHint => 'minutos (1–600)';

  @override
  String get sleepTimerCancel => 'Cancelar temporizador';

  @override
  String get sleepTimerInvalid => 'Informe um número entre 1 e 600 minutos';

  @override
  String sleepTimerPausesIn(String time) {
    return 'Pausa em $time';
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
      other: 'Temporizador definido para $minutes minutos',
      one: 'Temporizador definido para 1 minuto',
    );
    return '$_temp0';
  }

  @override
  String get add => 'Adicionar';

  @override
  String get autoDjTitle => 'Auto DJ';

  @override
  String get autoDjAddServerFirst => 'Adicione um servidor primeiro.';

  @override
  String get autoDjSectionServer => 'Servidor';

  @override
  String get autoDjSectionSources => 'Fontes';

  @override
  String get autoDjSectionContinuity => 'Continuidade';

  @override
  String get autoDjSectionFilters => 'Filtros';

  @override
  String get autoDjBpmTitle => 'Continuidade de BPM';

  @override
  String get autoDjBpmSubtitle =>
      'Prefere escolhas dentro de uma faixa de andamento da música atual. Considera a equivalência de meio/dobro de andamento.';

  @override
  String get autoDjTolerance => 'Tolerância';

  @override
  String autoDjBpmTolerance(int bpm) {
    return '± $bpm BPM';
  }

  @override
  String get autoDjHarmonicTitle => 'Mixagem harmônica';

  @override
  String get autoDjHarmonicSubtitle =>
      'Prefere escolhas em tons que combinam bem com a música travada (vizinhos na roda Camelot).';

  @override
  String get autoDjDurationTitle => 'Duração da faixa';

  @override
  String get autoDjDurationSubtitle =>
      'Ignora interlúdios e mixes longos, escolhendo apenas faixas dentro de uma faixa de duração';

  @override
  String get autoDjDurationRange => 'Duração';

  @override
  String get autoDjDurationAny => 'Qualquer duração';

  @override
  String autoDjDurationOver(String min) {
    return 'Acima de $min';
  }

  @override
  String autoDjDurationUnder(String max) {
    return 'Abaixo de $max';
  }

  @override
  String autoDjDurationBetween(String min, String max) {
    return 'De $min a $max';
  }

  @override
  String get autoDjDurationAllowUnknown =>
      'Incluir faixas de duração desconhecida';

  @override
  String get autoDjDurationAllowUnknownSub =>
      'Faixas cuja duração seu servidor não leu são ignoradas caso contrário';

  @override
  String get autoDjStatusOn => 'O Auto DJ está ligado';

  @override
  String get autoDjStatusOff => 'O Auto DJ está desligado';

  @override
  String get autoDjStatusOffDetail =>
      'Toque abaixo para iniciar. A biblioteca do servidor atual será usada.';

  @override
  String get autoDjStart => 'Iniciar Auto DJ';

  @override
  String get autoDjStop => 'Parar Auto DJ';

  @override
  String autoDjStatusOnDetail(String url) {
    return 'As músicas são escolhidas de $url quando a fila fica curta.';
  }

  @override
  String get autoDjOneSourceRequired => 'É necessária pelo menos uma fonte.';

  @override
  String get autoDjMinRating => 'Avaliação mínima';

  @override
  String get autoDjMinRatingSubtitle =>
      'Escolhe apenas músicas com esta avaliação ou superior.';

  @override
  String get autoDjRatingAny => 'Qualquer';

  @override
  String get autoDjGenreTitle => 'Filtro de gênero';

  @override
  String get autoDjGenreSubtitle =>
      'A lista de permissões toca só faixas correspondentes; a lista de bloqueios as ignora.';

  @override
  String get autoDjWhitelist => 'Lista de permissões';

  @override
  String get autoDjBlacklist => 'Lista de bloqueios';

  @override
  String get autoDjNoGenres =>
      'Nenhum gênero selecionado. Toque em \"Escolher gêneros\" para selecionar.';

  @override
  String get autoDjPickGenres => 'Escolher gêneros';

  @override
  String get autoDjGenreLoadError => 'Não foi possível carregar os gêneros';

  @override
  String get autoDjKeywordTitle => 'Filtro de palavras-chave';

  @override
  String get autoDjKeywordSubtitle =>
      'Ignora escolhas cujo título, artista, álbum ou caminho contenha qualquer uma destas palavras.';

  @override
  String get autoDjNoKeywords =>
      'Nenhuma palavra-chave. Adicione palavras abaixo para começar a filtrar.';

  @override
  String get autoDjKeywordHint => 'ex.: \"live\" ou \"remix\"';

  @override
  String get autoDjSearchGenres => 'Pesquisar gêneros…';

  @override
  String get autoDjNoGenresOnServer =>
      'Nenhum gênero encontrado neste servidor.';

  @override
  String autoDjSelectedCount(int count) {
    return '$count selecionado(s)';
  }

  @override
  String autoDjNoGenresMatch(String query) {
    return 'Nenhum gênero corresponde a \"$query\".';
  }

  @override
  String get download => 'Baixar';

  @override
  String get addAll => 'Adicionar tudo';

  @override
  String get browserMoreActions => 'Mais ações';

  @override
  String get browserConfirmDeletePlaylist => 'Confirmar exclusão da playlist';

  @override
  String get browserConfirmDeleteFolder => 'Confirmar exclusão da pasta';

  @override
  String get browserSearchHint => 'Pesquisar no banco de dados';

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
      other: '$count downloads iniciados',
      one: '1 download iniciado',
    );
    return '$_temp0';
  }

  @override
  String browserSongsAdded(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count músicas adicionadas à fila',
      one: '1 música adicionada à fila',
    );
    return '$_temp0';
  }

  @override
  String get tabBrowser => 'Navegador';

  @override
  String get tabQueue => 'Fila';

  @override
  String get drawerTagline => 'Streaming pessoal de música';

  @override
  String get mainFailedToConnect => 'Falha ao conectar ao servidor';

  @override
  String get mainQueueEmpty => 'A fila está vazia';

  @override
  String get visualizerTitle => 'Visualizador';

  @override
  String get mainClearQueue => 'Limpar fila';

  @override
  String get mainSync => 'Sincronizar';

  @override
  String mainQueueCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count faixas',
      one: '1 faixa',
    );
    return '$_temp0';
  }

  @override
  String get autoDjEnabled => 'Auto DJ ativado';

  @override
  String get autoDjDisabled => 'Auto DJ desativado';

  @override
  String autoDjEnabledFor(String url) {
    return 'Auto DJ ativado para $url';
  }

  @override
  String get addToPlaylistTitle => 'Adicionar à playlist';

  @override
  String get addToPlaylistEmpty =>
      'Nenhuma playlist ainda — toque em + para criar uma.';

  @override
  String addedToPlaylist(String name) {
    return 'Adicionado a $name';
  }

  @override
  String get testConnectedSignedIn => 'Conectado — login efetuado com sucesso.';

  @override
  String get testSignInFailed =>
      'Servidor acessível, mas o login falhou — verifique seu usuário e senha.';

  @override
  String get browserFileExplorer => 'Explorador de arquivos';

  @override
  String get browserLocalFiles => 'Arquivos locais';

  @override
  String get browserPlaylists => 'Playlists';

  @override
  String get browserAlbums => 'Álbuns';

  @override
  String get browserArtists => 'Artistas';

  @override
  String get browserRecent => 'Recentes';

  @override
  String get browserRated => 'Avaliadas';

  @override
  String get browserSearch => 'Pesquisar';

  @override
  String get browserWelcomeTitle => 'Bem-vindo ao mStream';

  @override
  String get browserWelcomeSubtitle => 'Toque aqui para adicionar um servidor';

  @override
  String get settingsVisualizerKnobs => 'Controles de ajuste do visualizador';

  @override
  String get settingsVisualizerKnobsSubtitle =>
      'Mostra controles deslizantes sobre o visualizador para ajustar a reatividade de áudio de cada shader. Apenas no motor de shaders.';

  @override
  String get visualizerTuningTitle => 'Ajuste';

  @override
  String get close => 'Fechar';

  @override
  String get migMoveStopped =>
      'Movimentação interrompida — espaço insuficiente ou o local está indisponível.';

  @override
  String get migMoveComplete => 'Movimentação concluída';

  @override
  String migMoveCompleteSkipped(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other:
          'Movimentação concluída — $count arquivos ignorados (sem suporte no destino)',
      one:
          'Movimentação concluída — 1 arquivo ignorado (sem suporte no destino)',
    );
    return '$_temp0';
  }

  @override
  String migMoving(String progress) {
    return 'Movendo downloads… $progress — mantenha o app aberto';
  }

  @override
  String get migRetry => 'Tentar novamente';

  @override
  String get queueDownloadAll => 'Baixar tudo';

  @override
  String queueDownloadAllBody(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count faixas serão baixadas para reprodução offline.',
      one: '1 faixa será baixada para reprodução offline.',
    );
    return '$_temp0';
  }

  @override
  String get mainMore => 'Mais';

  @override
  String get commonOn => 'Ligado';

  @override
  String get commonOff => 'Desligado';

  @override
  String get settingsCastQuality => 'Qualidade do visualizador na transmissão';

  @override
  String get settingsCastQualitySubtitle720 =>
      'Resolução em que o visualizador é transmitido para a TV. 720p — a mais leve para o celular.';

  @override
  String get settingsCastQualitySubtitle1080 =>
      'Resolução em que o visualizador é transmitido para a TV. 1080p — nítida em qualquer Chromecast (padrão).';

  @override
  String get settingsCastQualitySubtitle4k =>
      'Resolução em que o visualizador é transmitido para a TV. 4K — exige um Chromecast 4K; muito mais pesada para o celular.';

  @override
  String get eqCasting =>
      'O equalizador ajusta o áudio neste dispositivo, então fica indisponível durante a transmissão. Desconecte para usá-lo.';

  @override
  String get browserNothingToDownload => 'Nada para baixar nesta lista';

  @override
  String get browserDownloadAllTitle => 'Baixar tudo';

  @override
  String browserDownloadAllConfirm(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count arquivos serão baixados.',
      one: '1 arquivo será baixado.',
    );
    return '$_temp0';
  }

  @override
  String get browserCloseSearch => 'Fechar pesquisa';

  @override
  String get browserSearchThisList => 'Pesquisar nesta lista';

  @override
  String get browserSearchList => 'Pesquisar na lista';

  @override
  String browserNoMatches(String query) {
    return 'Nenhum resultado para \"$query\"';
  }

  @override
  String get clear => 'Limpar';

  @override
  String get dlLocationUnavailable => 'Local de download indisponível';

  @override
  String get dlLocationUnavailableServer =>
      'Local de download indisponível para este servidor.';

  @override
  String get dlFailed => 'Um download falhou — verifique sua conexão.';

  @override
  String get dlFatSkip =>
      'Algumas faixas não podem ser salvas neste cartão — os nomes delas não são compatíveis. Em vez disso, são transmitidas.';

  @override
  String get dlServerGone => 'Esse servidor não está mais configurado.';

  @override
  String get dlStorageUnavailable =>
      'Local de armazenamento indisponível — reconecte o cartão SD ou altere o local de armazenamento deste servidor em Editar servidor.';

  @override
  String get dlCouldNotStart =>
      'Não foi possível iniciar o download — armazenamento indisponível.';

  @override
  String get storageLocationLabel => 'Local de armazenamento';

  @override
  String get storageAppLocal => 'Local do app';

  @override
  String get storagePermanent => 'Permanente';

  @override
  String get storageSdCard => 'Cartão SD';

  @override
  String get storageSdSwitchTitle => 'Save to SD card';

  @override
  String get storageSdSwitchSubtitle =>
      'Stored in the SD card\'s app folder — no permission needed, but removed if you uninstall the app.';

  @override
  String get storageHelpAppLocal =>
      'Salvo dentro do app. Excluído ao desinstalar ou limpar o app.';

  @override
  String get storageHelpPermanent =>
      'Salvo em uma pasta que você escolher. Permanece após desinstalar o app. Exige o \"Acesso a todos os arquivos\".';

  @override
  String get storageHelpSdCard =>
      'Salvo em uma pasta do cartão SD que você escolher. Pode ficar indisponível se o cartão for removido. Alguns dispositivos não permitem que apps gravem em cartões SD — se a seleção de pasta continuar falhando, use Permanente ou Local do app.';

  @override
  String get storageChooseFolder => 'Escolher pasta';

  @override
  String get storageNoFolderChosen => 'Nenhuma pasta escolhida ainda';

  @override
  String get storageDownloadFolderLabel => 'Pasta de download';

  @override
  String get storageDownloadFolderHint => 'nome da pasta';

  @override
  String get storageBrowse => 'Procurar';

  @override
  String get storageDownloadFolderHelp =>
      'Os arquivos são baixados em um diretório \'media/<folder>\' neste dispositivo. Reutilizar a pasta de um servidor anterior mantém as músicas baixadas dele quando você readiciona um servidor perdido.';

  @override
  String get storageNoStorageAvailable => 'Nenhum armazenamento disponível';

  @override
  String get storageNoDownloadFolders =>
      'Nenhuma pasta de download existente encontrada';

  @override
  String get storageExistingFolders => 'Pastas de download existentes';

  @override
  String storageItemCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count itens',
      one: '1 item',
    );
    return '$_temp0';
  }

  @override
  String get storageAllFilesAccess =>
      'Conceda o \"Acesso a todos os arquivos\" para armazenar downloads permanentemente e depois escolha o modo novamente.';

  @override
  String get storageSettings => 'Configurações';

  @override
  String get storageNoVolume =>
      'Não foi possível localizar um volume de armazenamento';

  @override
  String get storageNotWritable =>
      'Essa pasta não permite gravação — escolha outra.';

  @override
  String get storageNewFolder => 'Nova pasta';

  @override
  String get storageFolderNameHint => 'Nome da pasta';

  @override
  String get storageCouldNotCreateFolder => 'Não foi possível criar a pasta';

  @override
  String get storageNoSubfolders => 'Nenhuma subpasta aqui';

  @override
  String get storageUseThisFolder => 'Usar esta pasta';

  @override
  String get storageMovedToNewFolder =>
      'Arquivos baixados movidos para a nova pasta.';

  @override
  String get storageMoveAlreadyRunning =>
      'Uma movimentação já está em andamento — deixe-a terminar primeiro.';

  @override
  String get storageMigrateTitle => 'Volume de armazenamento diferente';

  @override
  String storageMigrateBody(int count, String size) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other:
          'Os $count arquivos baixados deste servidor ($size) estão em um volume de armazenamento diferente do novo local. Escolha o que fazer:',
      one:
          'O 1 arquivo baixado deste servidor ($size) está em um volume de armazenamento diferente do novo local. Escolha o que fazer:',
    );
    return '$_temp0';
  }

  @override
  String storageMigrateNoSpace(String free) {
    return 'Espaço livre insuficiente no destino ($free livres). A movimentação pode falhar no meio — libere espaço primeiro.';
  }

  @override
  String get storageMigrateMove => 'Mover';

  @override
  String get storageMigrateMoveBody =>
      'Copia para o novo local em segundo plano, excluindo cada cópia antiga conforme avança. Mantenha o app aberto até concluir.';

  @override
  String get storageMigrateLeave => 'Manter onde estão';

  @override
  String get storageMigrateLeaveBody =>
      'Troca agora; os downloads antigos permanecem onde estão e são baixados novamente no novo local.';

  @override
  String get storageMigrateDelete => 'Excluir downloads antigos';

  @override
  String get storageMigrateDeleteBody =>
      'Troca agora e remove os arquivos antigos; eles serão baixados novamente no novo local.';

  @override
  String get storageMovingBackground =>
      'Movendo seus downloads em segundo plano — mantenha o app aberto.';

  @override
  String get storageChooseFolderFirst =>
      'Escolha uma pasta de download primeiro.';

  @override
  String get storageChooseSdFolderFirst =>
      'Escolha uma pasta no cartão SD primeiro. Se todas as pastas forem rejeitadas, talvez seu dispositivo não permita que apps gravem no cartão — use Permanente ou Local do app.';

  @override
  String get castPlayOn => 'Tocar em';

  @override
  String get castPlayOnTooltip => 'Tocar em…';

  @override
  String get castSearching => 'Procurando dispositivos de transmissão…';

  @override
  String get castNotSeeing =>
      'Não está vendo seu dispositivo? Verifique se ele está na mesma rede Wi-Fi.';

  @override
  String get castVisualizer => 'Transmitir o visualizador';

  @override
  String get castVisualizerSubtitle =>
      'Transmite o visualizador para a TV · apenas Chromecast';

  @override
  String get visualizerNoKnobs => 'Este shader não expõe nenhum controle.';

  @override
  String get nowPlaying => 'Tocando agora';

  @override
  String get playerLayoutSmall => 'Pequeno';

  @override
  String get playerLayoutMedium => 'Médio';

  @override
  String get playerLayoutLarge => 'Grande';

  @override
  String get playerLayoutXl => 'XL';

  @override
  String get playerLayoutSmallDesc => 'Barra fina — fila máxima';

  @override
  String get playerLayoutMediumDesc => 'Banner — equilibrado (padrão)';

  @override
  String get playerLayoutLargeDesc => 'Compacto — capa centralizada';

  @override
  String get playerLayoutXlDesc => 'Destaque — capa completa';

  @override
  String get queueNothingToDownloadEmpty =>
      'A fila está vazia — nada para baixar';

  @override
  String get queueNothingToDownloadSaved =>
      'Nada para baixar — as faixas já estão salvas';

  @override
  String get settingsAccentColor => 'Cor de destaque';

  @override
  String get settingsAccentColorSubtitle =>
      'A cor de destaque usada em todo o aplicativo.';

  @override
  String get accentThemeDefault => 'Padrão do tema';

  @override
  String get accentCustom => 'Personalizado';

  @override
  String get lanOnYourNetwork => 'Servidores na sua rede local';

  @override
  String get lanSearching => 'Procurando servidores…';

  @override
  String get lanRefresh => 'Atualizar';

  @override
  String lanServerVersion(String version) {
    return 'mStream v$version';
  }

  @override
  String lanLoginTitle(String name) {
    return 'Entrar em $name';
  }

  @override
  String get lanUnreachable =>
      'Não foi possível alcançar este servidor na rede.';

  @override
  String get lanNoCode =>
      'O Quick Connect está ativado neste servidor, mas ele não compartilhou um código de pareamento. Entre como administrador ou peça ao operador para ativar o compartilhamento do código.';

  @override
  String get settingsResumeQueue => 'Retomar a fila ao iniciar';

  @override
  String get settingsResumeQueueSubtitle =>
      'Salva a fila de reprodução e sua posição e as restaura ao reabrir o app.';

  @override
  String get settingsOfflineQueue => 'Manter a fila disponível offline';

  @override
  String get settingsOfflineQueueSubtitle =>
      'Baixa automaticamente as faixas da fila para este dispositivo, para que a reprodução sobreviva à perda de conexão.';

  @override
  String get settingsOfflineQueueWifiOnly => 'Baixar somente por Wi-Fi';

  @override
  String get settingsOfflineQueueWifiOnlySubtitle =>
      'Aguarda uma conexão Wi-Fi antes de baixar as faixas da fila.';

  @override
  String get settingsAutoDownloadCap => 'Auto-download limit';

  @override
  String get settingsAutoDownloadCapSubtitle =>
      'Guarda esta quantidade de músicas a partir da atual; as que ficam para trás são removidas.';

  @override
  String get settingsAutoDownloadCapSubtitleUnlimited =>
      'Guarda a fila inteira (sem limite).';

  @override
  String get settingsAutoDownloadCapUnlimited => 'Unlimited';

  @override
  String get settingsAutoDownloadCapField => 'Number of tracks';

  @override
  String get settingsAutoDownloadCapDialogBody =>
      'Quantas músicas da fila permanecem baixadas, contando a partir da atual. Conforme a reprodução avança, as que ficam para trás são excluídas. 0 para a fila inteira.';

  @override
  String get downloadWaitingWifi => 'Aguardando Wi-Fi';

  @override
  String get settingsRatingHalf => 'Avaliações de meia estrela';

  @override
  String get settingsRatingHalfSubtitle =>
      'Avalie músicas em passos de meia estrela (mantenha uma estrela pressionada).';

  @override
  String get ratingTitle => 'Avaliar';

  @override
  String get ratingFailed => 'Não foi possível salvar a avaliação';

  @override
  String get diagnosticsTitle => 'Diagnóstico';

  @override
  String get diagnosticsEnable => 'Ativar registro';

  @override
  String get diagnosticsHint =>
      'Os registros ficam no seu dispositivo. Os tokens são ocultados antes de copiar ou compartilhar.';

  @override
  String get diagnosticsVerbose => 'Verbose logging';

  @override
  String get diagnosticsVerboseHint =>
      'Also logs high-frequency events like app focus changes. Only needed when diagnosing a playback issue.';

  @override
  String get diagnosticsCopy => 'Copiar';

  @override
  String get diagnosticsShare => 'Compartilhar';

  @override
  String get diagnosticsClear => 'Limpar';

  @override
  String get diagnosticsCopied =>
      'Registros copiados para a área de transferência';

  @override
  String get diagnosticsEmpty => 'Ainda não há registros';

  @override
  String get storageAppExternal => 'App externo';

  @override
  String get storageAppSdCard => 'Cartão SD do app';

  @override
  String get selfSignedTitle => 'Permitir certificado autoassinado';

  @override
  String get selfSignedSubtitle =>
      'Ignora a validação TLS deste servidor. Ative apenas em uma rede confiável.';

  @override
  String get importedShadersTitle => 'Shaders importados';

  @override
  String get importedShadersSettingsSubtitle =>
      'Adicione os seus próprios arquivos .glsl à rotação do motor Shader.';

  @override
  String get importedShadersRescan => 'Reanalisar pasta';

  @override
  String get importedShadersDropHint =>
      'Coloque arquivos .glsl nesta pasta e depois Reanalisar:';

  @override
  String get importedShadersCopyPath => 'Copiar caminho';

  @override
  String get importedShadersReachableHint =>
      'Acessível via USB ou um gerenciador de arquivos (em Android/data). Os shaders importados entram na rotação quando o motor Shader está ativo.';

  @override
  String get importedShadersRemove => 'Remover';

  @override
  String get importedShadersEmptyTitle => 'Nenhum shader na pasta ainda';

  @override
  String get importedShadersEmptyBody =>
      'Copie arquivos .glsl no estilo Shadertoy para a pasta acima e depois toque em Reanalisar.';

  @override
  String get importedShadersInvalid =>
      'Pode não ser um shader válido — sem ponto de entrada mainImage/main.';

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
  String get irohOneServerLimit =>
      'Only one peer-to-peer (iroh) server is supported. Remove the existing one to connect a different server.';

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
  String get discoverTitle => 'Descobrir';

  @override
  String get discoverMatchedBySound => 'Combinações por som';

  @override
  String get discoverSimilarTracks => 'Faixas semelhantes';

  @override
  String get discoverSimilarArtists => 'Artistas semelhantes';

  @override
  String get discoverFromNetwork => 'Da rede';

  @override
  String get discoverFromPeers => 'Dos seus pares';

  @override
  String get discoverQueueAll => 'Adicionar tudo à fila';

  @override
  String get discoverNewArtistsOnly => 'Apenas artistas novos';

  @override
  String get discoverNotAnalyzed =>
      'Esta música ainda não foi analisada — músicas semelhantes aparecem quando a análise de descoberta chegar a ela.';

  @override
  String get discoverScanPendingTitle => 'Ainda não há nada analisado';

  @override
  String get discoverScanPendingBody =>
      'Este servidor tem a descoberta ativada, mas ainda não analisou nenhuma música. As músicas semelhantes aparecem depois de a análise de descoberta ser executada.';

  @override
  String get discoverCheckAgain => 'Verificar novamente';

  @override
  String get discoverTurnedOff => 'A descoberta foi desativada neste servidor.';

  @override
  String get pathScanPending =>
      'Este servidor ainda não analisou nenhuma música, por isso não há nada por onde traçar um percurso. Funciona depois de a análise de descoberta ser executada.';

  @override
  String get discoverNothingFound => 'Nenhuma correspondência encontrada.';

  @override
  String get discoverNoSeed =>
      'Toque uma música para descobrir músicas semelhantes.';

  @override
  String get discoverLeadCopied => 'Copiado — vá procurar!';

  @override
  String get discoverOpenMusicBrainz => 'Abrir no MusicBrainz';

  @override
  String get discoverNetworkWarmingUp =>
      'Ainda não há dados da rede — as bibliotecas dos pares são baixadas em segundo plano quando outros servidores são detectados.';

  @override
  String get discoverNetworkNothingNew =>
      'Nada de novo para esta música — a rede não tem correspondências desconhecidas.';

  @override
  String get discoverPeersUnreachable =>
      'Seus pares não responderam — eles podem estar offline agora.';

  @override
  String get discoverPeersNothingNew =>
      'Nada de novo para esta música nos servidores dos seus pares.';

  @override
  String get autoDjSonicTitle => 'Semelhança sonora';

  @override
  String get autoDjSonicSubtitle =>
      'Escolhe apenas músicas que soam como a sessão, usando a análise de áudio do servidor.';

  @override
  String get autoDjSonicUnavailable =>
      'Este servidor não tem dados de descoberta — a seleção continua aleatória.';

  @override
  String get autoDjSonicStrictness => 'Limite de semelhança';

  @override
  String autoDjSonicStrictnessValue(int pct) {
    return '$pct% ou mais próximo';
  }

  @override
  String get autoDjSonicSeedLabel => 'Música semente';

  @override
  String get autoDjSonicSeedNone =>
      'Sem semente — a música em reprodução ancora a sessão.';

  @override
  String get autoDjSonicSeedBanner =>
      'Escolha a música semente — toque em uma faixa em qualquer lugar da biblioteca';

  @override
  String get autoDjSonicSeedSearchHint => 'Buscar uma música…';

  @override
  String get autoDjSonicSeedRandom => 'Música aleatória';

  @override
  String get autoDjSonicSeedRemove => 'Remover música semente';

  @override
  String get autoDjSonicSeedFailed =>
      'Não foi possível obter uma música do servidor.';

  @override
  String get autoDjSeedNoMatch =>
      'Nenhuma música corresponde aos seus filtros do Auto DJ — tente afrouxá-los';

  @override
  String get discoverFindSimilar => 'Encontrar semelhantes';

  @override
  String get discoverStartSession => 'Iniciar uma sessão sonora';

  @override
  String get discoverStartSessionSubtitle =>
      'Música sem fim que soa como esta — substitui sua fila.';

  @override
  String get discoverStartSessionSubtitleRandom =>
      'Música sem fim a partir de uma música inicial aleatória — substitui sua fila.';

  @override
  String get discoverSessionStarted =>
      'Sessão sonora iniciada — Auto DJ ativado.';

  @override
  String get autoDjSonicAnchorLabel => 'Âncora';

  @override
  String get autoDjSonicAnchorRolling => 'Seguir o clima';

  @override
  String get autoDjSonicAnchorLocked => 'Manter a semente';

  @override
  String get autoDjSonicAnchorRollingHint =>
      'Cada música segue o som recente da sessão — pode evoluir aos poucos.';

  @override
  String get autoDjSonicAnchorLockedHint =>
      'Cada música fica próxima da música semente durante toda a sessão.';

  @override
  String get trackAddToPlaylist => 'Adicionar à playlist';

  @override
  String get trackAddToPlaylistFailed =>
      'Não foi possível adicionar à playlist.';

  @override
  String get discoverPlayPathTo => 'Tocar um caminho até…';

  @override
  String get pathScreenTitle => 'Caminho sonoro';

  @override
  String get pathStartNotAnalyzed =>
      'A música inicial ainda não foi analisada — aguarde a análise de descoberta ou escolha outra.';

  @override
  String get pathEndNotAnalyzed =>
      'A música de destino ainda não foi analisada — aguarde a análise de descoberta ou escolha outra.';

  @override
  String get pathStartSong => 'Música inicial';

  @override
  String get pathEndSong => 'Música final';

  @override
  String get pathLength => 'Comprimento';

  @override
  String get pathRegenerate => 'Gerar novamente';

  @override
  String get pathSaveAsPlaylist => 'Salvar como playlist';

  @override
  String get pathSetupHint =>
      'Escolha uma música de início e uma de destino — a jornada entre elas se preenche sozinha.';

  @override
  String get pathNotSet => 'Não definido';

  @override
  String get pathUsePlaying => 'Usar a música em reprodução';

  @override
  String get pathSearchSong => 'Buscar';

  @override
  String get pathBrowseLibrary => 'Explorar biblioteca';

  @override
  String get pathBuild => 'Criar a jornada';

  @override
  String get pathStartOver => 'Começar de novo';

  @override
  String get pathPickBannerStart =>
      'Escolha a música de início — toque em uma faixa em qualquer lugar da biblioteca';

  @override
  String get pathPickBannerEnd =>
      'Escolha a música de destino — toque em uma faixa em qualquer lugar da biblioteca';

  @override
  String get pathNothingPlaying => 'Nada está tocando';

  @override
  String pathPickOnServer(String server) {
    return 'Escolha uma faixa em $server';
  }

  @override
  String get welcomeTranslationNote =>
      'Este idioma foi traduzido automaticamente e pode soar estranho.';

  @override
  String get welcomeTranslationCta => 'Ajude a traduzir o mStream';

  @override
  String get setupTitle => 'Configuração rápida';

  @override
  String get setupSkip => 'Pular';

  @override
  String get setupNext => 'Avançar';

  @override
  String get setupFinish => 'Concluir';

  @override
  String get setupBack => 'Voltar';

  @override
  String get setupAccentTitle => 'Escolha sua cor';

  @override
  String get setupAccentBody =>
      'A cor de destaque realça botões, controles deslizantes e os controles do player. Toque em uma para experimentar.';

  @override
  String get setupVisualizerTitle => 'Áudio real para o visualizador';

  @override
  String get setupVisualizerBody =>
      'O visualizador usa dados sintetizados até que isto seja ativado.';

  @override
  String get setupVisualizerWarning =>
      'Ativar isso pede a permissão de microfone: o Android a exige de apps que decodificam o fluxo de áudio do dispositivo (que é o que o visualizador faz).';

  @override
  String get setupPlaybackTitle => 'Ao tocar em uma música';

  @override
  String get setupOfflineTitle => 'Mantenha sua fila offline';

  @override
  String get setupVisualizerNoMic => 'O mStream nunca usa seu microfone.';

  @override
  String get playlistEmpty => 'A playlist está vazia';

  @override
  String get trackRating => 'Avaliação';

  @override
  String albumDiscNumber(int n) {
    return 'Disco $n';
  }

  @override
  String get autoDjStartTitle => 'Começar o Auto DJ com o quê?';

  @override
  String get autoDjStartSubtitle =>
      'Não há nada na fila, então o DJ precisa de uma primeira música. Com fila, ele apenas segue o que já existe.';

  @override
  String get autoDjStartRandom => 'Surpreenda-me';

  @override
  String get autoDjStartRandomSub =>
      'Escolher uma música aleatória da biblioteca e construir a partir dela.';

  @override
  String get autoDjStartPick => 'Eu escolho';

  @override
  String get autoDjStartPickSub =>
      'Abrir a biblioteca e escolher a primeira música você mesmo.';

  @override
  String get autoDjStartRemember => 'Lembrar disto';

  @override
  String get autoDjStartRememberSub =>
      'Pular esta pergunta na próxima vez e sempre começar assim.';

  @override
  String get autoDjStartPickBanner =>
      'Escolha a primeira música — toque em uma faixa em qualquer lugar da biblioteca';

  @override
  String get autoDjOnEmptyQueue => 'Com a fila vazia';

  @override
  String get autoDjOnEmptyQueueSub =>
      'O que o Auto DJ faz quando você o liga sem nada na fila.';

  @override
  String get autoDjStartAskShort => 'Perguntar';

  @override
  String serverVersionLabel(String version) {
    return 'Servidor v$version';
  }

  @override
  String get serverVersionUnknown => 'Versão do servidor desconhecida';

  @override
  String get serverUpdateUrgent => 'Atualize seu servidor';

  @override
  String get serverUpdateAvailable => 'Atualização de servidor disponível';

  @override
  String serverTooOldWarning(String version) {
    return 'Este servidor é a versão v$version. Alguns recursos exigem v5.5 ou mais recente e ficarão indisponíveis.';
  }

  @override
  String get autoDjNeedsNewerServer =>
      'Continuidade de BPM, mixagem harmônica e filtro de gêneros exigem um servidor mais recente. Atualize para obtê-los.';

  @override
  String get autoDjSonicNeedsNewerServer =>
      'Requer servidor 6.15.2 ou mais recente';

  @override
  String get torrentScreenTitle => 'Adicionar torrent';

  @override
  String get torrentNoServer => 'Nenhum servidor configurado.';

  @override
  String get torrentServerLabel => 'Servidor';

  @override
  String get torrentLibraryLabel => 'Biblioteca';

  @override
  String get torrentNoLibraries => 'Nenhuma biblioteca neste servidor';

  @override
  String get torrentSourceLabel => 'Origem';

  @override
  String get torrentChooseFile => 'Escolher arquivo .torrent';

  @override
  String get torrentOr => 'ou';

  @override
  String get torrentMagnetLabel => 'Link magnet';

  @override
  String get torrentMagnetInvalid => 'Link magnet inválido';

  @override
  String torrentNotATorrent(String name) {
    return '“$name” não é um arquivo .torrent';
  }

  @override
  String get torrentOpenWith => 'Abrir em outro aplicativo';

  @override
  String get torrentOpenWithNone =>
      'Nenhum aplicativo neste dispositivo pode abrir um arquivo .torrent';

  @override
  String get torrentOpenWithFailed =>
      'Não foi possível passar o torrent para outro aplicativo';

  @override
  String get torrentIntentTitle => 'Torrent recebido';

  @override
  String get torrentIntentBody =>
      'Adicione-o a uma biblioteca no seu servidor mStream ou passe-o para outro aplicativo.';

  @override
  String get torrentIntentAdd => 'Adicionar ao mStream';

  @override
  String get torrentIntentDontAsk =>
      'Sempre adicionar ao mStream, não perguntar novamente';

  @override
  String get settingsTorrentAskTitle => 'Perguntar o que fazer com torrents';

  @override
  String get settingsTorrentAskSub =>
      'Quando um torrent for aberto com o mStream, oferecer passá-lo para outro aplicativo';

  @override
  String get settingsTorrentDefaultTitle => 'Aplicativo padrão para torrents';

  @override
  String get settingsTorrentDefaultSub =>
      'Abre as configurações do Android, onde você escolhe qual aplicativo abre torrents e links magnet';

  @override
  String get settingsTorrentDefaultFailed =>
      'Não foi possível abrir as configurações do Android';

  @override
  String get torrentAutoDetect => 'Detectar metadados';

  @override
  String get torrentDetecting => 'Detectando…';

  @override
  String get torrentDetectNoMetadata =>
      'Metadados insuficientes — preencha os campos manualmente';

  @override
  String get torrentDetected => 'Metadados detectados';

  @override
  String get torrentDetectGuess =>
      'Estimativa aproximada — verifique os campos';

  @override
  String get torrentMetadataLabel => 'Metadados';

  @override
  String get torrentArtistLabel => 'Artista';

  @override
  String get torrentAlbumLabel => 'Álbum';

  @override
  String get torrentYearLabel => 'Ano';

  @override
  String get torrentDestinationLabel => 'Destino';

  @override
  String get torrentPathLabel => 'Caminho na biblioteca';

  @override
  String torrentPreviewNoLibrary(String path) {
    return '‹sem biblioteca›/$path';
  }

  @override
  String get torrentPreviewContents => '‹conteúdo do torrent›';

  @override
  String get torrentRenameRoot => 'Renomear a pasta raiz do torrent';

  @override
  String get torrentRenameRootSub => 'Igualar ao nome da pasta de destino';

  @override
  String get torrentForceFresh => 'Forçar download do zero';

  @override
  String get torrentForceFreshSub => 'Não verificar arquivos já no servidor';

  @override
  String get torrentSubmit => 'Adicionar torrent';

  @override
  String get torrentSubmitting => 'Adicionando…';

  @override
  String get torrentUnavailable =>
      'Torrents não estão disponíveis neste servidor.';

  @override
  String get torrentPickLibrary => 'Escolha uma biblioteca';

  @override
  String get torrentOneSource =>
      'Adicione um link magnet ou um arquivo .torrent (apenas um)';

  @override
  String get torrentPathEmpty => 'O caminho de destino está vazio';

  @override
  String get torrentSeeded => 'Já está no disco — semeando agora';

  @override
  String get torrentAlreadyInClient => 'Já está no cliente de torrents';

  @override
  String get torrentInvalidFile => 'Arquivo torrent inválido';

  @override
  String get torrentSeedCheckFailed =>
      'Não foi possível verificar arquivos existentes — baixando do zero';

  @override
  String get torrentPartialTitle => 'Alguns arquivos já existem';

  @override
  String get torrentPartialBody =>
      'Aponte o torrent para uma cópia existente para semeá-la e baixar só o que falta.';

  @override
  String torrentPartialCount(String matched, String total) {
    return '$matched/$total arquivos aqui';
  }

  @override
  String torrentPartialMissing(String missing) {
    return ' · $missing a baixar';
  }

  @override
  String get torrentDownloadFresh => 'Baixar do zero mesmo assim';

  @override
  String get torrentMatchNoFolder =>
      'Essa correspondência não tem nome de pasta — use \'Baixar do zero mesmo assim\'';

  @override
  String torrentAdded(String name) {
    return '\"$name\" adicionado';
  }

  @override
  String torrentDuplicate(String name) {
    return '\"$name\" já está no cliente';
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
  String get federatedAutoDjUnavailable =>
      'Auto DJ can\'t run on a shared server. Switch to one of your own servers first.';

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
  String get adminLogOut => 'Sair';

  @override
  String get adminConfigGroup => 'Configuração';

  @override
  String get adminDirectories => 'Diretórios';

  @override
  String get adminUsers => 'Utilizadores';

  @override
  String get adminDLNA => 'DLNA';

  @override
  String get adminTorrent => 'Torrent';

  @override
  String get adminFederation => 'Federação';

  @override
  String get adminServerGroup => 'Servidor';

  @override
  String get adminAbout => 'Acerca';

  @override
  String get adminSettings => 'Definições';

  @override
  String get adminDatabase => 'Base de dados';

  @override
  String get adminBackups => 'Cópias de segurança';

  @override
  String get adminTranscoding => 'Transcodificação';

  @override
  String get adminLogs => 'Registos';

  @override
  String get adminAccess => 'Acesso de administrador';

  @override
  String adminAppBarTitle(String label) {
    return 'mStream Admin · $label';
  }

  @override
  String get adminPanelTitle => 'mStream Admin';

  @override
  String get adminLoginErrorRequired =>
      'Servidor e nome de utilizador são obrigatórios';

  @override
  String get adminLoginServerURL => 'URL do servidor';

  @override
  String get adminLoginUsername => 'Nome de utilizador';

  @override
  String get adminLoginPassword => 'Palavra-passe';

  @override
  String get adminLoginSignIn => 'Iniciar sessão';

  @override
  String get adminRetry => 'Tentar novamente';

  @override
  String get adminSaved => 'Guardado';

  @override
  String get adminSave => 'Guardar';

  @override
  String get adminClose => 'Fechar';

  @override
  String get adminPanelMenuItem => 'Painel de administração';

  @override
  String get adminNoLibrariesYetTitle => 'Ainda sem bibliotecas';

  @override
  String get adminAddDirectoryHint =>
      'Adicione um diretório para começar a analisar música para a biblioteca.';

  @override
  String get adminAddDirectoryButton => 'Adicionar diretório';

  @override
  String adminRemoveDirectoryTitle(String name) {
    return 'Remover $name?';
  }

  @override
  String get adminRemoveDirectoryWarning =>
      'Isto remove a biblioteca e as faixas analisadas da base de dados. Os ficheiros no disco não são afetados.';

  @override
  String get adminCancel => 'Cancelar';

  @override
  String get adminRemove => 'Remover';

  @override
  String get adminLibraryRemovedToast => 'Biblioteca removida';

  @override
  String get adminDirectoryPathLabel => 'Caminho';

  @override
  String get adminDirectoryTypeLabel => 'Tipo';

  @override
  String get adminFollowSymlinksTitle => 'Seguir ligações simbólicas';

  @override
  String get adminFollowSymlinksSubtitle => 'Aplica-se na próxima análise';

  @override
  String get adminPickFolderAndNameError =>
      'Escolha uma pasta e introduza um nome';

  @override
  String get adminDirectoryAddedToast =>
      'Diretório adicionado — análise iniciada';

  @override
  String get adminAddDirectoryDialogTitle => 'Adicionar diretório';

  @override
  String get adminChooseFolderButton => 'Escolher pasta no servidor…';

  @override
  String get adminLibraryNameLabel => 'Nome da biblioteca (vpath)';

  @override
  String get adminLibraryNameHelper => 'Letras, números e hífenes';

  @override
  String get adminGrantAllUsersAccessTitle =>
      'Conceder acesso a todos os utilizadores';

  @override
  String get adminAdd => 'Adicionar';

  @override
  String get adminChooseFolderTitle => 'Escolher uma pasta';

  @override
  String get adminSelectFolderButton => 'Selecionar esta pasta';

  @override
  String get adminNoUsersTitle => 'Sem utilizadores';

  @override
  String get adminNoUsersSubtitle =>
      'Sem utilizadores, o servidor funciona em modo aberto/público. Adicione um para exigir início de sessão.';

  @override
  String get adminAddUserButton => 'Adicionar utilizador';

  @override
  String get adminLibraryAccessDialogTitle => 'Acesso à biblioteca';

  @override
  String get adminLibraryAccessUpdatedToast => 'Acesso à biblioteca atualizado';

  @override
  String get adminSetPasswordTitle => 'Definir palavra-passe';

  @override
  String get adminPasswordUpdatedToast => 'Palavra-passe atualizada';

  @override
  String adminDeleteUserTitle(String username) {
    return 'Eliminar $username?';
  }

  @override
  String get adminDeleteUserWarning =>
      'Isto remove permanentemente a conta de utilizador.';

  @override
  String get adminDelete => 'Eliminar';

  @override
  String get adminUserDeletedToast => 'Utilizador eliminado';

  @override
  String get adminStatusPillLabel => 'admin';

  @override
  String get adminDeleteUserMenuItem => 'Eliminar utilizador';

  @override
  String get adminNoLibraryAccessLabel => 'Sem acesso a bibliotecas';

  @override
  String get adminLibrariesButton => 'Bibliotecas';

  @override
  String get adminAdminToggleTitle => 'Administrador';

  @override
  String get adminMakeDirsToggleTitle => 'Criar pastas';

  @override
  String get adminUploadToggleTitle => 'Carregar';

  @override
  String get adminModifyFilesToggleTitle => 'Modificar ficheiros';

  @override
  String get adminServerAudioToggleTitle => 'Áudio do servidor';

  @override
  String get adminAddUserDialogTitle => 'Adicionar utilizador';

  @override
  String get adminUsername => 'Nome de utilizador';

  @override
  String get adminPassword => 'Palavra-passe';

  @override
  String get adminLibraryAccessHeader => 'Acesso à biblioteca';

  @override
  String get adminUsernamePasswordRequiredError =>
      'Nome de utilizador e palavra-passe são obrigatórios';

  @override
  String get adminUserCreatedToast => 'Utilizador criado';

  @override
  String get adminAdministratorToggleTitle => 'Administrador';

  @override
  String get adminAllowMakeDirectoriesTitle => 'Permitir criar pastas';

  @override
  String get adminAllowUploadTitle => 'Permitir carregamentos';

  @override
  String get adminAllowServerAudioTitle => 'Permitir áudio do servidor';

  @override
  String get adminCreate => 'Criar';

  @override
  String get adminNoLibrariesConfigured => 'Nenhuma biblioteca configurada.';

  @override
  String get adminNewPasswordLabel => 'Nova palavra-passe';

  @override
  String get adminLibraryTitle => 'Biblioteca';

  @override
  String get adminTracksInDatabase => 'Faixas na base de dados';

  @override
  String get adminScanAllButton => 'Analisar tudo';

  @override
  String get adminScanStarted => 'Análise iniciada';

  @override
  String get adminForceRescan => 'Forçar reanálise';

  @override
  String get adminFullRescanStarted => 'Reanálise completa iniciada';

  @override
  String get adminCompressImages => 'Comprimir imagens';

  @override
  String get adminImageCompressionStarted => 'Compressão de imagens iniciada';

  @override
  String get adminScanOptions => 'Opções de análise';

  @override
  String get adminScanInterval =>
      'Intervalo de análise (horas, 0 = desativado)';

  @override
  String get adminBootScanDelay => 'Atraso da análise no arranque (segundos)';

  @override
  String get adminScanCommitInterval =>
      'Intervalo de gravação da análise (1–1000)';

  @override
  String get adminScanThreads => 'Threads de análise (0 = automático)';

  @override
  String get adminSkipImageExtraction => 'Ignorar extração de imagens';

  @override
  String get adminCompressEmbeddedImages => 'Comprimir imagens incorporadas';

  @override
  String get adminGenerateWaveforms => 'Gerar formas de onda após a análise';

  @override
  String get adminAnalyzeBpm => 'Analisar BPM/tom (obsoleto, sem efeito)';

  @override
  String get adminAutomaticAlbumArt => 'Capa de álbum automática';

  @override
  String get adminDownloadMissingAlbumArt =>
      'Transferir capas de álbum em falta';

  @override
  String get adminTargetLabel => 'Alvo';

  @override
  String get adminMissingOnly => 'Apenas em falta';

  @override
  String get adminAllAlbums => 'Todos os álbuns';

  @override
  String get adminAlbumsPerRun => 'Álbuns por execução (1–10000)';

  @override
  String get adminAutoDownloadedArtWriteFolder =>
      'Capa transferida automaticamente → gravar na pasta';

  @override
  String get adminManualArtWriteFolder =>
      'Capa definida manualmente → gravar na pasta';

  @override
  String get adminManualArtEmbedTag =>
      'Capa definida manualmente → incorporar na etiqueta do ficheiro';

  @override
  String get adminArtServices => 'Serviços de capas';

  @override
  String get adminArtServicesUpdated => 'Serviços de capas atualizados';

  @override
  String get adminSharedPlaylists => 'Listas partilhadas';

  @override
  String get adminDeleteExpired => 'Eliminar expiradas';

  @override
  String get adminExpiredSharesDeleted => 'Partilhas expiradas eliminadas';

  @override
  String get adminDeleteNeverExpiring => 'Eliminar sem expiração';

  @override
  String get adminEternalSharesDeleted => 'Partilhas permanentes eliminadas';

  @override
  String get adminNoSharedPlaylists => 'Sem listas partilhadas';

  @override
  String adminSharedPlaylistSubtitle(String user, int count, String expiry) {
    return 'por $user · $count faixas · expira a $expiry';
  }

  @override
  String get adminShareDeleted => 'Partilha eliminada';

  @override
  String get adminNetwork => 'Rede';

  @override
  String get adminNetworkSubtitle =>
      'Alterar isto reinicia suavemente o servidor.';

  @override
  String get adminBindAddress => 'Endereço de associação';

  @override
  String get adminPort => 'Porta';

  @override
  String get adminTrustProxyHeaders => 'Confiar nos cabeçalhos de proxy';

  @override
  String get adminTrustProxyHeadersSubtitle =>
      'Ative quando estiver atrás de um proxy reverso (X-Forwarded-*)';

  @override
  String get adminPermissions => 'Permissões';

  @override
  String get adminAllowUploads => 'Permitir carregamentos';

  @override
  String get adminAllowMakingDirectories => 'Permitir criar pastas';

  @override
  String get adminAllowModifyingFiles => 'Permitir modificar ficheiros';

  @override
  String get adminMaxRequestSize => 'Tamanho máximo do pedido';

  @override
  String get adminMaxRequestSizeHelper => 'p. ex. 50MB ou 512KB';

  @override
  String get adminHttpUi => 'HTTP e IU';

  @override
  String get adminResponseCompression => 'Compressão da resposta';

  @override
  String get adminCompressionNone => 'Nenhuma';

  @override
  String get adminCompressionGzip => 'gzip';

  @override
  String get adminCompressionBrotli => 'brotli';

  @override
  String get adminWebUi => 'IU Web';

  @override
  String get adminUiDefault => 'Predefinida';

  @override
  String get adminUiVelvet => 'Velvet';

  @override
  String get adminDatabaseTuning => 'Otimização da base de dados';

  @override
  String get adminSqliteSynchronous => 'SQLite synchronous';

  @override
  String get adminSyncFull => 'FULL (safest)';

  @override
  String get adminSyncNormal => 'NORMAL (faster)';

  @override
  String get adminCacheSize => 'Tamanho da cache (MB, 1–2048)';

  @override
  String get adminLogging => 'Registo';

  @override
  String get adminWriteLogsToDisk => 'Gravar registos no disco';

  @override
  String get adminLogBufferSize => 'Tamanho do buffer de registo';

  @override
  String get adminLogBufferSizeHelper => '0–10000, 0 = desativado';

  @override
  String get adminServerAudio => 'Áudio do servidor';

  @override
  String get adminAutoBootServerAudio =>
      'Iniciar automaticamente o áudio do servidor (leitor Rust)';

  @override
  String get adminRustPlayerPort => 'Porta do leitor Rust';

  @override
  String get adminActiveBackend => 'Backend ativo';

  @override
  String get adminPlayer => 'Leitor';

  @override
  String get adminDetectedCliPlayers => 'Leitores CLI detetados';

  @override
  String get adminNone => 'nenhum';

  @override
  String get adminReDetectPlayers => 'Voltar a detetar leitores';

  @override
  String get adminReProbedCliPlayers => 'Leitores CLI reverificados';

  @override
  String get adminSslHttps => 'SSL / HTTPS';

  @override
  String get adminEnabled => 'Ativado';

  @override
  String get adminDisabled => 'Desativado';

  @override
  String get adminReplaceCertificate => 'Substituir certificado';

  @override
  String get adminSetCertificate => 'Definir certificado';

  @override
  String get adminSetSslCertificateDialog => 'Definir certificado SSL';

  @override
  String get adminCertificatePath => 'Caminho do certificado';

  @override
  String get adminKeyPath => 'Caminho da chave';

  @override
  String get adminSslConfigured => 'SSL configurado — reinicie para aplicar';

  @override
  String get adminRemoveSsl => 'Remover SSL';

  @override
  String get adminSslRemoved => 'SSL removido';

  @override
  String get adminSecurity => 'Segurança';

  @override
  String get adminJwtSecretLast4 => 'Segredo JWT (últimos 4)';

  @override
  String get adminRegenerateSecret => 'Regenerar segredo';

  @override
  String get adminSecretRegenerated =>
      'Segredo regenerado — todas as sessões invalidadas';

  @override
  String get adminRegenerateJwtSecretDialog => 'Regenerar segredo JWT?';

  @override
  String get adminRegenerateJwtSecretDialogBody =>
      'Isto invalida todos os inícios de sessão existentes (incluindo este). Todos terão de iniciar sessão novamente.';

  @override
  String get adminRegenerateButton => 'Regenerar';

  @override
  String get adminAllNetworks => 'Todas as redes';

  @override
  String get adminLocalhostOnly => 'Apenas localhost';

  @override
  String get adminIpWhitelist => 'Lista de IP permitidos';

  @override
  String get adminNoneLockAdmin => 'Nenhum (bloquear admin)';

  @override
  String get adminNetworkAccess => 'Acesso à rede';

  @override
  String get adminNetworkAccessSubtitle =>
      'Restringir quais as redes que podem aceder à API de administração.';

  @override
  String get adminMode => 'Modo';

  @override
  String get adminWhitelistedIps => 'IP / CIDR permitidos';

  @override
  String get adminNoneYet => 'Ainda nenhum';

  @override
  String get adminAddIpOrCidr => 'Adicionar IP ou CIDR';

  @override
  String get adminCidrExample => '192.168.1.0/24';

  @override
  String get adminApply => 'Aplicar';

  @override
  String get adminDangerZone => 'Zona de perigo';

  @override
  String get adminLockAdminApi => 'Bloquear API de administração';

  @override
  String get adminLockAdminApiSubtitle =>
      'Desativa toda a API de administração. Não pode ser anulado a partir daqui.';

  @override
  String get adminLockButton => 'Bloquear';

  @override
  String get adminLockAdminApiDialog => 'Bloquear a API de administração?';

  @override
  String get adminLockAdminApiDialogBody =>
      'Isto desativa toda a API /admin para todos. Não conseguirá anular esta ação a partir deste painel — requer editar o ficheiro de configuração do servidor e reiniciar. Continuar?';

  @override
  String get adminAdminApiLocked => 'API de administração bloqueada';

  @override
  String get adminAccessUpdated => 'Acesso de administrador atualizado';

  @override
  String get adminTranscodingFFmpegTitle => 'FFmpeg';

  @override
  String get adminFFmpegStatusReady => 'Pronto';

  @override
  String get adminFFmpegStatusNotDownloaded => 'Não transferido';

  @override
  String get adminFFmpegDownloadButton => 'Transferir / atualizar ffmpeg';

  @override
  String get adminFFmpegDownloadedToast => 'ffmpeg transferido';

  @override
  String get adminFFmpegAutoUpdateTitle => 'Atualizar ffmpeg automaticamente';

  @override
  String get adminFFmpegAutoUpdateSubtitle =>
      'Manter o ffmpeg incluído atualizado automaticamente';

  @override
  String get adminTranscodingDefaultsTitle => 'Predefinições';

  @override
  String get adminDefaultCodecLabel => 'Codec predefinido';

  @override
  String get adminDefaultBitrateLabel => 'Bitrate predefinido';

  @override
  String get adminLogsResumeButton => 'Retomar';

  @override
  String get adminLogsPauseButton => 'Pausar';

  @override
  String get adminClear => 'Limpar';

  @override
  String get adminLogsAutoScrollTitle => 'Deslocamento automático';

  @override
  String adminLogsLineCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count linhas',
      one: '1 linha',
    );
    return '$_temp0';
  }

  @override
  String get adminLogsDownloadZipButton => 'Transferir zip';

  @override
  String get adminLogsNoEntriesHint => 'Ainda sem entradas de registo';

  @override
  String get adminDlnaModeDisabled => 'Desativado';

  @override
  String get adminSamePortAsHttp => 'Mesma porta que o HTTP';

  @override
  String get adminSeparatePort => 'Porta separada';

  @override
  String get adminDlnaBrowseFlat => 'Plano (todas as faixas)';

  @override
  String get adminDlnaBrowseDirectories => 'Diretórios';

  @override
  String get adminDlnaBrowseArtist => 'Por artista';

  @override
  String get adminDlnaBrowseAlbum => 'Por álbum';

  @override
  String get adminDlnaBrowseGenre => 'Por género';

  @override
  String get adminDlnaServerTitle => 'Servidor';

  @override
  String get adminDlnaIdentityTitle => 'Identidade';

  @override
  String get adminDlnaFriendlyNameLabel => 'Nome amigável';

  @override
  String get adminDlnaDeviceUuidLabel => 'UUID do dispositivo';

  @override
  String get adminDlnaDeviceUuidHelper => 'GUID canónico';

  @override
  String get adminDlnaBrowseLayoutTitle => 'Disposição de navegação';

  @override
  String get adminDlnaStructureLabel => 'Estrutura';

  @override
  String get adminTestConnection => 'Testar ligação';

  @override
  String get adminKeyNameLabel => 'Nome / etiqueta da chave';

  @override
  String get adminMintKey => 'Gerar chave';

  @override
  String get adminTorrentClient => 'Cliente';

  @override
  String get adminActiveClient => 'Cliente ativo';

  @override
  String get adminTransmission => 'Transmission';

  @override
  String get adminQbittorrent => 'qBittorrent';

  @override
  String get adminDeluge => 'Deluge';

  @override
  String get adminEnabledFor => 'Ativado para';

  @override
  String get adminAllUsers => 'Todos os utilizadores';

  @override
  String get adminWhitelistedUsers => 'Utilizadores permitidos';

  @override
  String get adminHost => 'Anfitrião';

  @override
  String get adminPasswordUnchangedIfBlank => 'inalterada se vazia';

  @override
  String get adminRpcPath => 'Caminho RPC';

  @override
  String get adminUseHttps => 'Usar HTTPS';

  @override
  String get adminTest => 'Testar';

  @override
  String adminReachable(String version) {
    return 'Acessível$version';
  }

  @override
  String adminConnectionFailed(String error) {
    return 'Falhou: $error';
  }

  @override
  String get adminConnectAndSave => 'Ligar e guardar';

  @override
  String adminSaveFailed(String error) {
    return 'Falhou: $error';
  }

  @override
  String get adminConnectedAndSaved => 'Ligado e guardado';

  @override
  String get adminDisconnect => 'Desligar';

  @override
  String get adminDisconnected => 'Desligado';

  @override
  String get adminConfigured => 'Configurado';

  @override
  String get adminNotConfigured => 'Não configurado';

  @override
  String get adminTorrents => 'Torrents';

  @override
  String get adminConnected => 'Ligado';

  @override
  String get adminNoTorrents => 'Sem torrents';

  @override
  String get adminMstream => 'mStream';

  @override
  String get adminTorrentRemoved => 'Torrent removido';

  @override
  String get adminLibraryDaemonPathMapping =>
      'Mapeamento de caminho biblioteca → daemon';

  @override
  String get adminLibraryDaemonPathMappingSubtitle =>
      'Mapeia cada biblioteca para o caminho que o daemon de torrent vê.';

  @override
  String get adminAutoDetectAll => 'Detetar tudo automaticamente';

  @override
  String get adminAutoDetectionComplete => 'Deteção automática concluída';

  @override
  String get adminVerified => 'verificado';

  @override
  String get adminUnverified => 'não verificado';

  @override
  String get adminSetManually => 'Definir manualmente';

  @override
  String adminDaemonPathFor(String name) {
    return 'Caminho do daemon para \"$name\"';
  }

  @override
  String get adminPathOnDaemonHost => 'Caminho no anfitrião do daemon';

  @override
  String get adminVerifyAndSave => 'Verificar e guardar';

  @override
  String get adminVpathVerified => 'Verificado';

  @override
  String get adminVpathSavedUnverified => 'Guardado (não verificado)';

  @override
  String get adminDownloadPathTemplates =>
      'Modelos de caminho de transferência';

  @override
  String adminPathTemplateVars(String vars) {
    return 'Variáveis: $vars';
  }

  @override
  String get adminNoLibraries => 'Sem bibliotecas';

  @override
  String adminSuggestedTemplate(String template) {
    return 'Sugerido: $template';
  }

  @override
  String get adminTemplateSaved => 'Modelo guardado';

  @override
  String get adminNoBackupDestinations => 'Sem destinos de cópia de segurança';

  @override
  String get adminBackupDestinationInfo =>
      'Adicione um destino para espelhar uma biblioteca noutra pasta.';

  @override
  String get adminAddDestination => 'Adicionar destino';

  @override
  String get adminAddLibraryFirst => 'Adicione primeiro uma biblioteca';

  @override
  String get adminBackupQueue => 'Fila de cópias de segurança';

  @override
  String adminTasksQueued(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count tarefas em fila',
      one: '1 tarefa em fila',
    );
    return '$_temp0';
  }

  @override
  String adminBackingUp(String library) {
    return 'A fazer cópia de: $library';
  }

  @override
  String get adminRunning => 'em execução';

  @override
  String adminBackupStats(int done, String total, String stats) {
    return '$done ficheiros$total$stats';
  }

  @override
  String get adminBackupDisabled => 'desativado';

  @override
  String get adminDestination => 'Destino';

  @override
  String get adminTrigger => 'Acionador';

  @override
  String adminDailyTriggerTime(String trigger, String hour) {
    return '$trigger às $hour:00';
  }

  @override
  String get adminRetention => 'Retenção';

  @override
  String adminRetentionDays(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count dias',
      one: '1 dia',
    );
    return '$_temp0';
  }

  @override
  String get adminLastRun => 'Última execução';

  @override
  String adminLastRunStatus(String status, int files) {
    return '$status · $files copiados';
  }

  @override
  String get adminRunNow => 'Executar agora';

  @override
  String get adminBackupQueued => 'Cópia de segurança em fila';

  @override
  String get adminAlreadyRunningSkipped => 'Já em execução — ignorado';

  @override
  String get adminHistory => 'Histórico';

  @override
  String get adminEdit => 'Editar';

  @override
  String get adminDestinationDeleted => 'Destino eliminado';

  @override
  String get adminBackupHistory => 'Histórico de cópias de segurança';

  @override
  String get adminNoHistoryYet => 'Ainda sem histórico';

  @override
  String get adminEditDestination => 'Editar destino';

  @override
  String get adminAddBackupDestination =>
      'Adicionar destino de cópia de segurança';

  @override
  String get adminDestinationPath => 'Caminho do destino';

  @override
  String get adminBrowseServer => 'Procurar no servidor';

  @override
  String get adminCheckPath => 'Verificar caminho';

  @override
  String get adminTriggerField => 'Acionador';

  @override
  String get adminAfterEachScan => 'Após cada análise';

  @override
  String get adminDaily => 'Diariamente';

  @override
  String get adminManualOnly => 'Apenas manual';

  @override
  String get adminRunAtHour => 'Executar à hora: ';

  @override
  String get adminRetentionFieldLabel => 'Retenção (dias, 0 = manter tudo)';

  @override
  String get adminEnabledToggle => 'Ativado';

  @override
  String get adminDestinationUpdated => 'Destino atualizado';

  @override
  String get adminDestinationCreated => 'Destino criado';

  @override
  String get adminPickLibrary => 'Escolha uma biblioteca';

  @override
  String get adminPickDestinationPath => 'Escolha um caminho de destino';

  @override
  String adminAboutTitle(String version) {
    return 'mStream v$version';
  }

  @override
  String get adminAboutPort => 'Porta';

  @override
  String get adminSSL => 'SSL';

  @override
  String get adminUI => 'IU';

  @override
  String get adminCompression => 'Compressão';

  @override
  String get adminTrustProxy => 'Confiar no proxy';

  @override
  String get adminYes => 'Sim';

  @override
  String get adminNo => 'Não';

  @override
  String get adminSecretLast4 => 'Segredo (últimos 4)';

  @override
  String get adminUploads => 'Carregamentos';

  @override
  String get adminMakeDirs => 'Criar pastas';

  @override
  String get adminFileModify => 'Modificar ficheiros';

  @override
  String get adminSynchronous => 'Synchronous';

  @override
  String get adminCacheSizeLabel => 'Tamanho da cache';

  @override
  String adminCacheSizeMb(int size) {
    return '$size MB';
  }

  @override
  String get adminFederationDescription =>
      'Emparelhe com outros servidores mStream: emita chaves para que leiam as suas bibliotecas ou adicione os tickets deles para ler as deles.';

  @override
  String get adminAllowed => 'Permitido';

  @override
  String get adminBackupEnabled => 'ativado';

  @override
  String get adminNotAvailable => 'Indisponível';

  @override
  String get adminNotMapped => 'não mapeado';

  @override
  String get adminExpiryNever => 'nunca';

  @override
  String get adminUnknownUser => 'desconhecido';

  @override
  String get adminFederationEnableTitle => 'Ativar federação';

  @override
  String get adminFederationEnableSubtitle =>
      'Permitir que este servidor se emparelhe com outros servidores mStream';

  @override
  String get adminFederationEndpointId => 'ID do endpoint';

  @override
  String get adminFederationRelay => 'Relé';

  @override
  String get adminFederationOnline => 'Online';

  @override
  String get adminFederationOffline => 'Offline';

  @override
  String get adminFederationStopped => 'Parado';

  @override
  String get adminFederationUnsupportedTitle => 'Não suportado aqui';

  @override
  String get adminFederationUnsupportedBody =>
      'Esta compilação não tem um endpoint de federação para a sua plataforma, portanto não pode ser executada aqui.';

  @override
  String get adminFederationCopy => 'Copiar';

  @override
  String get adminFederationCopied => 'Copiado';

  @override
  String get adminFederationKeysTitle => 'Chaves emitidas';

  @override
  String get adminFederationKeysSubtitle =>
      'Credenciais que outros servidores usam para ler deste';

  @override
  String get adminFederationNoKeys => 'Ainda não há chaves emitidas';

  @override
  String get adminFederationMintTitle => 'Emitir uma chave';

  @override
  String get adminFederationCopyTicket => 'Mostrar ticket';

  @override
  String get adminFederationTicketTitle => 'Ticket';

  @override
  String get adminFederationTicketBody =>
      'Entregue isto ao administrador do outro servidor. É mostrado apenas uma vez.';

  @override
  String get adminFederationNoTicket =>
      'Não há ticket disponível para esta chave';

  @override
  String get adminFederationEditLimits => 'Editar limites';

  @override
  String get adminFederationLimitsTitle => 'Limites';

  @override
  String get adminFederationLimitsSaved => 'Limites guardados';

  @override
  String get adminFederationStreamKbps => 'Teto de fluxo (kbps)';

  @override
  String get adminFederationDailyMb => 'Limite diário (MB)';

  @override
  String get adminFederationMaxStreams => 'Fluxos simultâneos';

  @override
  String get adminFederationUnlimitedHint => '0 significa ilimitado';

  @override
  String get adminFederationUnlimited => 'ilimitado';

  @override
  String adminFederationKbps(int kbps) {
    return '$kbps kbps';
  }

  @override
  String adminFederationMbPerDay(int mb) {
    return '$mb MB/dia';
  }

  @override
  String adminFederationStreams(int count) {
    return '$count fluxos';
  }

  @override
  String adminFederationUsageToday(String used) {
    return 'Hoje: $used';
  }

  @override
  String get adminFederationExpired => 'Expirada';

  @override
  String get adminFederationBound => 'vinculada';

  @override
  String get adminFederationUnbound => 'sem vínculo';

  @override
  String get adminFederationResetBinding => 'Repor vínculo';

  @override
  String get adminFederationResetBindingDone => 'Vínculo reposto';

  @override
  String get adminFederationRevoke => 'Revogar';

  @override
  String adminFederationRevokeTitle(String name) {
    return 'Revogar $name?';
  }

  @override
  String get adminFederationRevokeBody =>
      'Quaisquer fluxos que estejam a usar esta chave são cortados imediatamente.';

  @override
  String get adminFederationRevoked => 'Chave revogada';

  @override
  String get adminFederationPeersTitle => 'Servidores que lê';

  @override
  String get adminFederationPeersSubtitle =>
      'Servidores que lhe deram um ticket e dos quais pode ler';

  @override
  String get adminFederationNoPeers => 'Ainda não há pares adicionados';

  @override
  String get adminFederationAddPeer => 'Adicionar par';

  @override
  String get adminFederationAddPeerBody =>
      'Cole o ticket que o outro servidor lhe deu. Contém o endereço e a chave de acesso.';

  @override
  String get adminFederationTicketLabel => 'Ticket';

  @override
  String get adminFederationPeerNameLabel => 'Nome (opcional)';

  @override
  String get adminFederationPeerAdded => 'Par adicionado';

  @override
  String get adminFederationPeerRemoved => 'Par removido';

  @override
  String adminFederationRemovePeerTitle(String name) {
    return 'Remover $name?';
  }

  @override
  String get adminFederationTestOk => 'Par acessível';

  @override
  String adminFederationLastSeen(String when) {
    return 'Visto pela última vez $when';
  }

  @override
  String get adminFederationNeverSeen => 'Nunca acessível';

  @override
  String get adminFederationUseDiscovery => 'Enviar consultas de descoberta';

  @override
  String get adminFederationUseDiscoverySubtitle =>
      'Partilha com este par o que está a ouvir';
}
