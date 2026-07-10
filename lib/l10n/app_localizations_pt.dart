// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Portuguese (`pt`).
class AppLocalizationsPt extends AppLocalizations {
  AppLocalizationsPt([String locale = 'pt']) : super(locale);

  @override
  String get tabExplore => 'Explorar';

  @override
  String get tabAdd => 'Adicionar';

  @override
  String get tabAccount => 'Conta';

  @override
  String get profileSettingsTitle => 'Definições';

  @override
  String get profileSettingsSubtitle => 'Idioma e locais do seu interesse';

  @override
  String get profileSettingsLanguageLabel => 'Idioma';

  @override
  String get profileSettingsLanguageDescription =>
      'Escolha um idioma ou use o do dispositivo.';

  @override
  String get profileLanguageSystemDefault =>
      'Automático (inglês se não for compatível)';

  @override
  String get profileLoadErrorDefault => 'Não foi possível carregar o perfil.';

  @override
  String get profileRefreshPage => 'Atualizar página';

  @override
  String get profileRetry => 'Tentar novamente';

  @override
  String get profileSignInTitle => 'Inicie sessão para aceder à sua conta';

  @override
  String get profileSignInSubtitle =>
      'Inicie sessão para gerir os seus spots e avaliar locais.';

  @override
  String get profileSignInButton => 'Iniciar sessão';

  @override
  String get profileOrDivider => 'OU';

  @override
  String get profileCreateAccount => 'Criar uma conta';

  @override
  String get profileDefaultDisplayName => 'Utilizador';

  @override
  String get profileViewEditSubtitle => 'Ver e editar o seu perfil';

  @override
  String get notificationsTitle => 'Notificações';

  @override
  String get notificationsSubtitle =>
      'Novos spots por perto, planos de treino, check-ins e outras novidades para si';

  @override
  String get notificationsEmptyTitle => 'Ainda está calmo por aqui';

  @override
  String get notificationsEmptyBody =>
      'Quando alguém adicionar um spot por perto, planear treino onde treinas ou fizer check-in por perto, verás aqui.';

  @override
  String get notificationsLoadError =>
      'Não foi possível carregar as tuas notificações. Verifica a ligação e tenta novamente.';

  @override
  String get notificationsRetry => 'Tentar novamente';

  @override
  String get notificationsOpenFailedSnackbar =>
      'Não foi possível abrir esta notificação. Tenta mais tarde.';

  @override
  String get notificationsMarkAllRead => 'Marcar todas como lidas';

  @override
  String get notificationsMarkAllReadFailed =>
      'Não foi possível marcar todas como lidas. Tenta novamente.';

  @override
  String get notificationsMarkAsReadFailed =>
      'Não foi possível marcar como lida. Tenta novamente.';

  @override
  String get notificationsMarkAsUnreadFailed =>
      'Não foi possível marcar como não lida. Tenta novamente.';

  @override
  String get notificationsMarkAsUnreadHint =>
      'Mantém premido para marcar como não lida';

  @override
  String get notificationsMarkAsReadHint =>
      'Mantém premido para marcar como lida';

  @override
  String get notificationsShowAll => 'Mostrar todas';

  @override
  String get notificationsUnreadOnly => 'Só não lidas';

  @override
  String get notificationsEmptyFilteredTitle => 'Estás em dia';

  @override
  String get notificationsEmptyFilteredBody =>
      'Não há notificações por ler neste momento.';

  @override
  String get notificationsTimeUnknown => 'Recentemente';

  @override
  String notificationsOpenSemantic(String title) {
    return 'Abrir notificação: $title';
  }

  @override
  String get notificationsActorSomeone => 'Alguém';

  @override
  String get notificationsSpotUntitled => 'Spot sem nome';

  @override
  String notificationNearbyNewSpotTitle(String spotName) {
    return 'Novo spot por perto: $spotName';
  }

  @override
  String notificationNearbyNewSpotBody(String actorName) {
    return '$actorName adicionou um novo spot de parkour perto de um dos teus locais guardados.';
  }

  @override
  String notificationNearbyCheckInTitle(String actorName, String spotName) {
    return '$actorName está a treinar agora em $spotName';
  }

  @override
  String get notificationNearbyCheckInBody =>
      'Acabou de fazer check-in neste spot.';

  @override
  String notificationNearbyTrainingPlanTitle(
    String actorName,
    String spotName,
  ) {
    return '$actorName planeou treino em $spotName';
  }

  @override
  String get notificationNearbyTrainingPlanBody =>
      'Partilharam uma janela de treino pública perto de uma das suas localizações guardadas.';

  @override
  String notificationTrainingPlanCheckInReminderTitle(String spotName) {
    return 'Hora de fazer check-in em $spotName';
  }

  @override
  String get notificationTrainingPlanCheckInReminderBody =>
      'O teu treino planeado já começou. Toca para fazer check-in.';

  @override
  String get profileModeratorSectionTitle => 'Moderador';

  @override
  String get profileModeratorToolsTitle => 'Ferramentas de moderação';

  @override
  String get profileModeratorToolsSubtitle =>
      'Rever e resolver relatórios de spots';

  @override
  String get profileAdminSectionTitle => 'Administrador';

  @override
  String get profileAdminToolsTitle => 'Ferramentas de administração';

  @override
  String get profileAdminToolsSubtitle =>
      'Gerir fontes e tarefas administrativas';

  @override
  String get profileSignOut => 'Terminar sessão';

  @override
  String get profileSignOutMessage =>
      'Tem a certeza de que quer terminar a sessão?';

  @override
  String get profileCancel => 'Cancelar';

  @override
  String get profileLocationAlertsTitle => 'Alertas de localização';

  @override
  String get profileNotificationSettingsTitle => 'Definições de notificações';

  @override
  String get profilePushNotificationsThisDeviceTitle =>
      'Notificações push neste navegador/dispositivo';

  @override
  String get profilePushNotificationsUnsupported =>
      'As notificações push não são suportadas neste navegador.';

  @override
  String get profilePushNotificationsLoading =>
      'A verificar o estado das notificações push neste dispositivo…';

  @override
  String get profilePushNotificationsPermissionDenied =>
      'A permissão push está bloqueada nas definições do navegador para este site.';

  @override
  String get profilePushNotificationsPermissionNotDetermined =>
      'Ativa isto para pedir permissão e subscrever este navegador.';

  @override
  String get profilePushNotificationsEnabled =>
      'Este navegador está subscrito e pode receber alertas push.';

  @override
  String get profilePushNotificationsPermissionGrantedButOff =>
      'A permissão foi concedida, mas este navegador não está subscrito de momento.';

  @override
  String get profilePushNotificationsUnknown =>
      'O estado push não está disponível agora. Tenta novamente em breve.';

  @override
  String get profilePushNotificationsError =>
      'Não foi possível atualizar as notificações push neste navegador. Tenta novamente.';

  @override
  String get profileLocationAlertsDescription =>
      'Controle que locais são usados para alertas nas proximidades, incluindo check-ins, novos spots, planos de treino e eventos futuros.';

  @override
  String get profileLocationAlertsShareLastKnownTitle =>
      'Utilizar a última localização conhecida';

  @override
  String get profileLocationAlertsShareLastKnownSubtitle =>
      'Guarde a última localização conhecida do seu dispositivo na nuvem para corresponder alertas nas proximidades.';

  @override
  String get profileLocationAlertsNotifyNewSpotsTitle =>
      'Notificar sobre novos spots nas proximidades';

  @override
  String get profileLocationAlertsNotifyNewSpotsSubtitle =>
      'Receba uma notificação na app quando alguém adicionar um spot a cerca de 5 km de um local guardado ativo ou da sua última localização conhecida.';

  @override
  String get profileLocationAlertsNotifyNearbyCheckInsTitle =>
      'Notificar sobre check-ins nas proximidades';

  @override
  String get profileLocationAlertsNotifyNearbyCheckInsSubtitle =>
      'Receba uma notificação na app quando alguém fizer check-in num spot a cerca de 5 km de um local guardado ativo ou da sua última localização conhecida.';

  @override
  String get profileLocationAlertsNotifyTrainingPlansTitle =>
      'Notificar sobre planos de treino por perto';

  @override
  String get profileLocationAlertsNotifyTrainingPlansSubtitle =>
      'Receba uma notificação na app quando alguém partilhar um plano de treino público num spot a cerca de 5 km de um local guardado ativo ou da sua última localização conhecida.';

  @override
  String get profileTrainingPlanCheckInReminderTitle =>
      'Lembrar-me de fazer check-in nas sessões planeadas';

  @override
  String get profileTrainingPlanCheckInReminderSubtitle =>
      'Recebe um lembrete na app quando a tua sessão planeada já começou e ainda não fizeste check-in nesse spot.';

  @override
  String get profileLocationAlertsSavedLocationsTitle =>
      'Os meus locais de interesse';

  @override
  String get profileLocationAlertsAddLocationButton => 'Adicionar';

  @override
  String get profileLocationAlertsNoLocationsEnabledWarning =>
      'Não receberá notificações baseadas na localização até ativar «Utilizar a última localização conhecida» ou, pelo menos, um local guardado.';

  @override
  String get profileLocationAlertsEmptyState =>
      'Ainda não tem locais guardados. Adicione sítios como Casa ou Trabalho.';

  @override
  String get profileLocationAlertsDefaultLabel => 'Local guardado';

  @override
  String get profileLocationAlertsDisableTooltip => 'Desativar';

  @override
  String get profileLocationAlertsEnableTooltip => 'Ativar';

  @override
  String get profileLocationAlertsEditTooltip => 'Editar';

  @override
  String get profileLocationAlertsDeleteTooltip => 'Eliminar';

  @override
  String get profileLocationAlertsDeleteTitle => 'Eliminar local guardado?';

  @override
  String profileLocationAlertsDeleteMessage(String label) {
    return 'Tem a certeza de que quer eliminar $label?';
  }

  @override
  String get profileLocationAlertsDeleteConfirmButton => 'Eliminar';

  @override
  String get profileLocationAlertsDialogAddTitle => 'Adicionar local';

  @override
  String get profileLocationAlertsDialogEditTitle => 'Editar local';

  @override
  String get profileLocationAlertsLabelFieldLabel => 'Nome';

  @override
  String get profileLocationAlertsLabelFieldPlaceholder => 'Casa';

  @override
  String get profileLocationAlertsEnabledLabel => 'Ativo';

  @override
  String get profileLocationAlertsLabelRequired => 'Introduza um nome';

  @override
  String get profileLocationAlertsLocationRequired =>
      'Escolha uma localização no mapa';

  @override
  String get profileAboutIntro =>
      'Parkour·Spot é uma aplicação comunitária para descobrir e partilhar spots de parkour e freerunning em todo o mundo. Queremos tornar simples encontrar bons locais—onde quer que treines.';

  @override
  String get profileReadMore => 'Ler mais';

  @override
  String get profileAboutStoryBeforeName => 'Criada por ';

  @override
  String get profileAboutStoryAfterName =>
      ' a partir da comunidade de parkour de Utrecht, a app reúne conhecimento local de mapas urbanos e regionais existentes—estejam no Facebook, Instagram, sites ou apps antigas—para que bons dados de spots não se percam.';

  @override
  String get profileAboutMapMission =>
      'Este é o teu mapa. Adiciona novos spots, avalia os existentes e enriquece as fichas com detalhes. Quanto mais contribuímos, mais forte fica o conhecimento partilhado da comunidade.';

  @override
  String get profileAboutPrinciplesHeader => 'Os nossos princípios:';

  @override
  String get profileAboutPrincipleTransparency =>
      '• Transparência: podes explorar a app sem conta, e cada spot mostra que fontes externas contribuíram.';

  @override
  String get profileAboutPrinciplePortability =>
      '• Portabilidade: estamos a criar ferramentas de exportação para os dados de spots serem usados fora da app.';

  @override
  String get profileAboutPrincipleOpenSource =>
      '• Código aberto: a app é da comunidade, não depende de uma só pessoa.';

  @override
  String get profileAboutEnjoy =>
      'Boa descoberta e partilha de spots com Parkour.spot. Dúvidas ou ideias? Toca em contacto—adoramos ouvir-te.';

  @override
  String get profileCreditsBy => 'Grandes contribuições de ';

  @override
  String get profileCreditsDaphneArt => ' (arte), ';

  @override
  String get profileCreditsComma => ', ';

  @override
  String get profileCreditsEnd => ' e muitos outros.';

  @override
  String get profileViewSourceCode => 'Ver código-fonte';

  @override
  String get profileContactUs => 'Contacto';

  @override
  String get profileReportIssue => 'Reportar um problema';

  @override
  String get profileHelpTranslate => 'Ajude a traduzir a aplicação';

  @override
  String get profileInstallBannerTitle => 'Instalar a app Parkour·Spot';

  @override
  String get profileInstallBannerSubtitle =>
      'Experiência completa da aplicação';

  @override
  String get profileInstallDialogTitle => 'Instalar Parkour·Spot';

  @override
  String profileInstallIntro(String device) {
    return 'Para instalar o Parkour·Spot no seu $device:';
  }

  @override
  String get profileInstallDeviceIphone => 'iPhone';

  @override
  String get profileInstallDeviceAndroid => 'dispositivo Android';

  @override
  String get profileInstallIosStep1 =>
      'Toque no botão Partilhar na parte inferior do ecrã';

  @override
  String get profileInstallIosStep2 =>
      'Desça e toque em «Adicionar ao ecrã principal»';

  @override
  String get profileInstallIosStep3 =>
      'Toque em «Adicionar» no canto superior direito';

  @override
  String get profileInstallIosStep4 => 'A app aparecerá no ecrã principal!';

  @override
  String get profileInstallAndroidStep1 =>
      'Toque no menu Mais (⋯) no canto superior direito';

  @override
  String get profileInstallAndroidStep2 =>
      'Toque em «Adicionar ao ecrã inicial»';

  @override
  String get profileInstallAndroidStep3 => 'Toque em «Instalar aplicação»';

  @override
  String get profileInstallAndroidStep4 => 'A app aparecerá no ecrã inicial!';

  @override
  String get profileInstallGotIt => 'Percebi';

  @override
  String get exploreMetaDefaultTitle => 'Parkour·Spot';

  @override
  String get exploreMetaDefaultDescription =>
      'Descobre, mapeia e partilha os melhores spots de parkour no mundo com fotos da comunidade, avaliações e dicas locais para o teu próximo treino.';

  @override
  String exploreMetaTitleCityCountry(String city, String country) {
    return 'Melhores spots de parkour em $city, $country';
  }

  @override
  String exploreMetaDescriptionCityCountry(String city, String country) {
    return 'Descobre os melhores spots de parkour em $city, $country. Encontra locais de treino, partilha os teus favoritos e conecta-te à comunidade.';
  }

  @override
  String exploreMetaTitleCountry(String country) {
    return 'Melhores spots de parkour em $country';
  }

  @override
  String exploreMetaDescriptionCountry(String country) {
    return 'Descobre os melhores spots de parkour em $country. Encontra locais de treino, partilha os teus favoritos e conecta-te à comunidade.';
  }

  @override
  String get exploreAddSpotTitle => 'Adicionar novo spot';

  @override
  String get exploreAddSpotSubtitle =>
      'Partilha os teus spots de parkour favoritos com a comunidade';

  @override
  String get exploreSignInToAddSpot =>
      'Inicia sessão para adicionar spots e eventos';

  @override
  String get exploreSignInToAddSubtitle =>
      'Contribui com novos spots ou submete propostas de eventos para revisão dos moderadores.';

  @override
  String get addHubHeading => 'O que queres adicionar?';

  @override
  String get addHubSubtitle => 'Partilha o que sabes no mapa da comunidade.';

  @override
  String get addHubSpotTitle => 'Adicionar spot';

  @override
  String get addHubSpotDescription =>
      'Coloca um pin, adiciona fotos e põe um novo spot de treino no mapa.';

  @override
  String get addHubSpotPublishBadge => 'No mapa de imediato';

  @override
  String get addHubSpotButton => 'Criar spot';

  @override
  String get addHubEventTitle => 'Adicionar novo evento';

  @override
  String get addHubEventDescription =>
      'Propõe um jam, encontro ou sessão para outros encontrarem.';

  @override
  String get addHubEventModerationBadge => 'Revisto pelos moderadores';

  @override
  String get addHubEventButton => 'Adicionar novo evento';

  @override
  String get addHubSignInTitle => 'Inicia sessão para contribuir';

  @override
  String get addHubSignInSubtitle =>
      'Conta gratuita. Adiciona spots ao mapa ou propõe eventos para a comunidade.';

  @override
  String get exploreLoadingProfile => 'A carregar o teu perfil…';

  @override
  String get exploreSearchHint => 'Pesquisar localização ou spot…';

  @override
  String get explorePickerTitleLocation => 'Escolher localização';

  @override
  String get explorePickerTitleSpots => 'Escolher spot';

  @override
  String get explorePickerTitleEvents => 'Escolher evento';

  @override
  String get explorePickerTitleSpotsAndEvents => 'Escolher spot ou evento';

  @override
  String get explorePickerSearchHintEvents =>
      'Pesquisar localização ou evento…';

  @override
  String get explorePickerSearchHintLocation => 'Pesquisar localização…';

  @override
  String get explorePickerConfirmSelect => 'Selecionar';

  @override
  String get explorePickerConfirmAdd => 'Adicionar';

  @override
  String get explorePickerAlreadyAdded => 'Adicionado';

  @override
  String explorePickerDone(int count) {
    return 'Concluído ($count)';
  }

  @override
  String get explorePickerLoading => 'A carregar mapa…';

  @override
  String get exploreFilterBy => 'Filtrar por';

  @override
  String get exploreFilterAmenities => 'Comodidades';

  @override
  String get exploreFilterSources => 'Fontes';

  @override
  String get exploreSpotAccessTitle => 'Acesso ao spot';

  @override
  String get exploreSpotAccessSubtitle => 'Filtrar spots por nível de acesso';

  @override
  String get exploreFilterAny => 'Qualquer';

  @override
  String get exploreSpotFacilitiesTitle => 'Instalações do spot';

  @override
  String get exploreSpotFacilitiesSubtitle =>
      'Mostrar spots com estas comodidades';

  @override
  String get exploreAttributesTitle => 'Com qualquer um destes atributos';

  @override
  String get exploreAttributesSubtitle =>
      'Filtrar spots que tenham qualquer uma das competências ou funcionalidades selecionadas';

  @override
  String get exploreGoodForSegment => 'Bom para';

  @override
  String get exploreSpotFeaturesSegment => 'Características do spot';

  @override
  String get exploreSpotSourceLabel => 'Fonte do spot';

  @override
  String get exploreSourcesLoadError => 'Falha ao carregar fontes';

  @override
  String get exploreAllSources => 'Todas as fontes';

  @override
  String get exploreParkourSpotNative => 'Parkour·Spot (nativo)';

  @override
  String get exploreAllFolders => 'Todas as pastas';

  @override
  String exploreLocationError(String error) {
    return 'Erro ao obter localização: $error';
  }

  @override
  String get exploreCurrentLocationSnackbar => 'Esta é a tua localização atual';

  @override
  String get exploreCloseTooltip => 'Fechar';

  @override
  String get exploreClearSearchTooltip => 'Limpar';

  @override
  String get exploreFiltersTooltip => 'Filtros';

  @override
  String get exploreFindingLocation => 'A localizar…';

  @override
  String get exploreAddSpotHereTitle => 'Adicionar spot neste local?';

  @override
  String exploreMapRankedTotalBar(int total) {
    return '$total spots';
  }

  @override
  String exploreMapSpotsFoundLine(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count spots encontrados',
      one: '1 spot encontrado',
    );
    return '$_temp0';
  }

  @override
  String exploreMapBestShownParenthetical(int count) {
    return ' ($count melhores mostrados)';
  }

  @override
  String get exploreMapListModeSpots => 'Spots';

  @override
  String get exploreMapListModeEvents => 'Eventos';

  @override
  String get exploreNoEventsArea => 'Nenhum evento nesta área';

  @override
  String get exploreNoEventsAreaHint => 'Mova o mapa ou volte mais tarde';

  @override
  String get spotCardUpcomingEventBadge => 'Evento';

  @override
  String get exploreEventLocate => 'Localizar';

  @override
  String get exploreNoSpotsSearch => 'Nenhum spot encontrado';

  @override
  String get exploreNoSpotsArea => 'Nenhum spot nesta área';

  @override
  String get exploreNoSpotsSearchHint => 'Tenta ajustar os termos de pesquisa';

  @override
  String get exploreNoSpotsMapHint => 'Move o mapa para explorar outras áreas';

  @override
  String get exploreRefreshMapTooltip => 'Atualizar spots na vista atual';

  @override
  String get exploreSwitchToMap => 'Ver mapa';

  @override
  String get exploreSwitchToSatellite => 'Ver satélite';

  @override
  String get exploreLocationPermissionDenied =>
      'Permissão de localização recusada';

  @override
  String get exploreCenterOnMyLocation => 'Centrar na minha localização';

  @override
  String get exploreFiltersDialogTitle => 'Filtros';

  @override
  String get exploreClearFilters => 'Limpar';

  @override
  String get exploreApplyFilters => 'Aplicar';

  @override
  String exploreSpotCountShort(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count spots',
      one: '1 spot',
    );
    return '$_temp0';
  }

  @override
  String get explorePwaBannerInstall => 'Instalar';

  @override
  String get addSpotPickImagesFailed =>
      'Não foi possível escolher as imagens. Tenta novamente.';

  @override
  String get addSpotTakePhotoFailed =>
      'Não foi possível tirar a foto. Tenta novamente.';

  @override
  String get addSpotNeedPhoto => 'Carrega pelo menos uma foto do spot';

  @override
  String get addSpotNeedLocation =>
      'Espera pela localização ou escolhe um ponto no mapa';

  @override
  String addSpotCreateError(String error) {
    return 'Erro ao criar o spot: $error';
  }

  @override
  String get addSpotNameLabel => 'Nome do spot *';

  @override
  String get addSpotNameRequired => 'Introduz um nome para o spot';

  @override
  String get addSpotDescriptionLabel => 'Descrição *';

  @override
  String get addSpotDescriptionRequired => 'Introduz uma descrição';

  @override
  String get addSpotDescriptionMinLength =>
      'A descrição deve ter pelo menos 10 caracteres';

  @override
  String get addSpotCreating => 'A criar spot…';

  @override
  String get addSpotCreateButton => 'Criar spot';

  @override
  String get addSpotLocationSectionTitle => 'Escolher localização do spot';

  @override
  String get addSpotGettingLocation => 'A obter a tua localização…';

  @override
  String get addSpotLocationNotAvailable => 'Localização indisponível';

  @override
  String get addSpotPickLocationHint => 'Escolher localização';

  @override
  String get addSpotImagesSectionTitle => 'Escolher imagens do spot';

  @override
  String get addSpotGalleryButton => 'Galeria';

  @override
  String get addSpotCameraButton => 'Câmara';

  @override
  String get addSpotGoodForTitle => 'Bom para';

  @override
  String get addSpotGoodForSubtitle =>
      'Que competências de parkour se podem treinar aqui?';

  @override
  String get addSpotFeaturesTitle => 'Características do spot';

  @override
  String get addSpotFeaturesSubtitle =>
      'Que características físicas tem este spot?';

  @override
  String get addSpotAccessTitle => 'Acesso ao spot';

  @override
  String get addSpotAccessSubtitle => 'Qual é o nível de acesso a este spot?';

  @override
  String get addSpotFacilitiesFormTitle => 'Instalações do spot';

  @override
  String get addSpotFacilitiesSubtitle => 'Que comodidades existem neste spot?';

  @override
  String get addSpotLongPressHintSkill =>
      'Pressiona longamente numa competência para mais informações';

  @override
  String get addSpotLongPressHintFeature =>
      'Pressiona longamente numa característica para mais informações';

  @override
  String get addSpotLongPressHintFacility =>
      'Pressiona longamente numa instalação para mais informações';

  @override
  String get addSpotPickLocationAppBarTitle => 'Escolher localização';

  @override
  String get addSpotTipLongPressMobile =>
      'Dica: também podes adicionar spots a partir do mapa Explorar com toque longo num local.';

  @override
  String get addSpotTipRightClickDesktop =>
      'Dica: também podes adicionar spots a partir do mapa Explorar com clique direito num local.';

  @override
  String get addEventTipLongPressMobile =>
      'Dica: também podes adicionar eventos a partir do mapa Explorar com toque longo num local.';

  @override
  String get addEventTipRightClickDesktop =>
      'Dica: também podes adicionar eventos a partir do mapa Explorar com clique direito num local.';

  @override
  String get addSpotUseThisLocation => 'Usar esta localização';

  @override
  String get addSpotDirectionsTooltip => 'Direções';

  @override
  String get addSpotGettingAddress => 'A obter morada…';

  @override
  String get addEventTitle => 'Adicionar novo evento';

  @override
  String get addEventModerationNotice =>
      'As propostas de eventos são revistas pelos moderadores antes de se tornarem públicas.';

  @override
  String get addEventTitleLabel => 'Título do evento *';

  @override
  String get addEventTitleRequired => 'O título é obrigatório.';

  @override
  String get addEventTitleTooLong => 'O título é demasiado longo.';

  @override
  String get addEventDescriptionLabel => 'Descrição (opcional)';

  @override
  String get addEventDescriptionTooLong => 'A descrição é demasiado longa.';

  @override
  String get addEventWebsiteLabel => 'URL do site (opcional)';

  @override
  String get addEventWebsiteHint => 'https://example.com';

  @override
  String get addEventPhotosSectionTitle => 'Escolher imagens do evento';

  @override
  String get addEventAllDay => 'Evento de dia inteiro';

  @override
  String get addEventTimezoneLabel => 'Fuso horário';

  @override
  String get addEventStartLabel => 'Início';

  @override
  String get addEventEndLabel => 'Fim (opcional)';

  @override
  String get addEventEndNotSet => 'Não definido';

  @override
  String get addEventClearEndTooltip => 'Limpar fim';

  @override
  String get addEventSchedulePickStartDate => 'Escolher data de início';

  @override
  String get addEventSchedulePickStartTime => 'Escolher hora de início';

  @override
  String get addEventSchedulePickEndDateOptional =>
      'Escolher data de fim (opcional)';

  @override
  String get addEventSchedulePickEndTimeOptional =>
      'Escolher hora de fim (opcional)';

  @override
  String get addEventScheduleSkipEnd => 'Ignorar';

  @override
  String get addEventScheduleLabel => 'Datas';

  @override
  String get addEventLinkingSectionTitle => 'Ligação';

  @override
  String get addEventWhereSectionTitle => 'Escolher localização do evento';

  @override
  String get addEventWhenSectionTitle => 'Escolher horário do evento';

  @override
  String get addEventAddressNeedsResolve =>
      'Toca no ícone de pesquisa ao lado da morada para confirmar, ou escolhe uma localização no mapa.';

  @override
  String get addEventLinkSpotButton => 'Associar spot';

  @override
  String addEventLinkedSpotLabel(String name) {
    return 'Spot: $name';
  }

  @override
  String addEventLinkedSpotListLabel(String name) {
    return 'Lista de spots: $name';
  }

  @override
  String get addEventLocationNotSet => 'Localização não definida';

  @override
  String get addEventExactLocationSet => 'Localização exata definida';

  @override
  String get addEventLocationSectionTitle => 'Localização';

  @override
  String get addEventLocationSectionHint =>
      'Adiciona um ou mais spots e/ou uma localização exata do evento.';

  @override
  String get addEventAddressLabel => 'Endereço exato (opcional)';

  @override
  String get addEventAddressHint => 'Rua, número, cidade';

  @override
  String get addEventUseAddressButton => 'Usar endereço';

  @override
  String get addEventPickLocationButton => 'Escolher no mapa';

  @override
  String get addEventClearAddressTooltip => 'Limpar endereço';

  @override
  String get addEventAddressRequiredToResolve =>
      'Introduz um endereço para procurar.';

  @override
  String get addEventAddressNotFound =>
      'Não foi possível encontrar coordenadas para este endereço.';

  @override
  String get addEventPickLocationHint =>
      'Escolhe uma localização no mapa (opcional quando spot/lista está ligado).';

  @override
  String get addEventClearLocationTooltip => 'Limpar localização';

  @override
  String get addEventPickLocationTooltip => 'Escolher localização';

  @override
  String addEventApproxCoordinates(String latitude, String longitude) {
    return 'Aprox. $latitude, $longitude';
  }

  @override
  String get addEventSubmitting => 'A submeter…';

  @override
  String get addEventSubmitButton => 'Submeter para revisão';

  @override
  String get addEventWebsiteInvalid =>
      'O URL do site deve ser um URL http(s) válido.';

  @override
  String get addEventEndBeforeStart =>
      'A hora de fim não pode ser anterior à hora de início.';

  @override
  String get addEventNeedLocationOrLink =>
      'Adiciona uma localização no mapa ou liga um spot antes de submeter.';

  @override
  String addEventMaxPhotos(int count) {
    return 'No máximo $count fotos permitidas.';
  }

  @override
  String get addEventUploadPhotosFailed =>
      'Não foi possível carregar as fotos. Tenta novamente.';

  @override
  String get addEventSubmitFailed =>
      'Não foi possível submeter a proposta de evento.';

  @override
  String get addEventSubmitSuccess => 'Evento submetido à fila de moderação.';

  @override
  String get noImagesYet => 'Ainda sem imagens';

  @override
  String get spotCardNoDescription => 'Ainda sem descrição';

  @override
  String get spotCardPartOfPrefix => 'Parte de ';

  @override
  String get spotCardRemoveFromListTooltip => 'Remover da lista';

  @override
  String get spotCardCopiedToClipboard =>
      'Spot copiado para a área de transferência!';

  @override
  String spotCardShareFailed(String error) {
    return 'Não foi possível partilhar o spot: $error';
  }

  @override
  String get spotCardRemovedFromSource => 'Removido da fonte';

  @override
  String get spotCheckInUnnamedPerson => 'Esta pessoa';

  @override
  String spotCheckInTooltipPublic(String name, String time) {
    return '$name está aqui agora até $time';
  }

  @override
  String spotCheckInTooltipPrivate(String time) {
    return 'Estás aqui agora até $time — só tu vês este check-in';
  }

  @override
  String spotTrainingPlanTooltipPublic(String name, String timeRange) {
    return '$name planeia treinar aqui $timeRange';
  }

  @override
  String spotTrainingPlanTooltipPrivate(String timeRange) {
    return 'Planeias treinar aqui $timeRange — só tu vês este plano';
  }

  @override
  String spotTrainingPlanTooltipPublicUntil(String name, String untilTime) {
    return '$name planeia treinar aqui até $untilTime';
  }

  @override
  String spotTrainingPlanTooltipPrivateUntil(String untilTime) {
    return 'Planeias treinar aqui até $untilTime — só tu vês este plano';
  }

  @override
  String get spotDetailRouteErrorLoading => 'Erro ao carregar o spot';

  @override
  String get spotDetailRouteTryAgainLater => 'Tenta novamente mais tarde';

  @override
  String get spotDetailRouteNotFound => 'Spot não encontrado';

  @override
  String get spotDetailRouteGoToExplore => 'Ir para Explorar';

  @override
  String get spotDetailCheckInVerifyFailed =>
      'Não foi possível verificar os teus check-ins';

  @override
  String get spotDetailCheckInEndPreviousFailed =>
      'Não foi possível terminar o check-in anterior';

  @override
  String get spotDetailCheckInSuccess => 'Fizeste check-in';

  @override
  String get spotDetailCheckInFailed => 'Check-in falhou';

  @override
  String get spotDetailCheckInRemoved => 'Check-in removido';

  @override
  String get spotDetailCheckInDeleteFailed =>
      'Não foi possível eliminar o check-in';

  @override
  String get spotDetailCheckInUpdated => 'Check-in atualizado';

  @override
  String get spotDetailCheckInUpdateFailed =>
      'Não foi possível atualizar o check-in';

  @override
  String get spotDetailCheckInFabTooltipSignIn =>
      'Inicia sessão para fazer check-in';

  @override
  String get spotDetailCheckInFabTooltipEdit => 'Editar check-in';

  @override
  String get spotDetailCheckInFabTooltipCheckIn => 'Check-in';

  @override
  String spotDetailSpotCreatedOnDateBy(String date) {
    return 'Spot criado $date por ';
  }

  @override
  String get spotDetailSpotCreatedBy => 'Spot criado por ';

  @override
  String get spotDetailUnknownSource => 'Fonte desconhecida';

  @override
  String spotDetailSpotImportedOnDateFrom(String date) {
    return 'Spot importado $date de ';
  }

  @override
  String get spotDetailSpotImportedFrom => 'Spot importado de ';

  @override
  String get spotDetailFromFolder => ' da pasta ';

  @override
  String get spotDetailImprovedByAfterComma => ', melhorado por ';

  @override
  String get spotDetailImprovedByAfterAnd => ' e melhorado por ';

  @override
  String get spotDetailUnknownUser => 'Desconhecido';

  @override
  String get spotDetailListJoinAnd => ' e ';

  @override
  String get spotDetailListJoinComma => ', ';

  @override
  String spotDetailLastUpdatedAfterCommaAnd(String date) {
    return ', e atualizado pela última vez $date.';
  }

  @override
  String spotDetailLastUpdatedAfterAnd(String date) {
    return ' e atualizado pela última vez $date.';
  }

  @override
  String get spotDetailDateToday => 'hoje';

  @override
  String get spotDetailDateYesterday => 'ontem';

  @override
  String get communityDateTomorrow => 'amanhã';

  @override
  String communityActivityTrainSameDay(
    String startTime,
    String endTime,
    String day,
  ) {
    return 'Das $startTime às $endTime $day';
  }

  @override
  String communityActivityTrainSpan(
    String startTime,
    String startDay,
    String endTime,
    String endDay,
  ) {
    return 'De $startTime $startDay a $endTime $endDay';
  }

  @override
  String get communityShareSpotFallbackName => 'este spot';

  @override
  String communityShareCheckInNarrative(String spotName, String untilPhrase) {
    return 'Estou a treinar em $spotName até cerca de $untilPhrase';
  }

  @override
  String communityShareTrainingPlanNarrative(
    String spotName,
    String relativeDay,
    String startTime,
  ) {
    return 'Planeio treinar em $spotName $relativeDay a partir das $startTime';
  }

  @override
  String get communityActivityShareCopiedToClipboard =>
      'Mensagem copiada para a área de transferência!';

  @override
  String communityActivityShareFailed(String error) {
    return 'Não foi possível partilhar: $error';
  }

  @override
  String spotDetailDateDaysAgo(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Há $count dias',
      one: 'Há 1 dia',
    );
    return '$_temp0';
  }

  @override
  String spotDetailDateWeeksAgo(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Há $count semanas',
      one: 'Há 1 semana',
    );
    return '$_temp0';
  }

  @override
  String spotDetailDateMonthsAgo(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Há $count meses',
      one: 'Há 1 mês',
    );
    return '$_temp0';
  }

  @override
  String spotDetailDateYearsAgo(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Há $count anos',
      one: 'Há 1 ano',
    );
    return '$_temp0';
  }

  @override
  String spotDetailCopySpotFailed(String error) {
    return 'Não foi possível copiar o spot: $error';
  }

  @override
  String get spotDetailAddressCopiedToClipboard =>
      'Morada copiada para a área de transferência!';

  @override
  String spotDetailCopyAddressFailed(String error) {
    return 'Não foi possível copiar a morada: $error';
  }

  @override
  String spotDetailOpenMapsFailed(String error) {
    return 'Não foi possível abrir a app de mapas: $error';
  }

  @override
  String get spotDetailMoreActionsTooltip => 'Mais ações';

  @override
  String get spotDetailMenuLogin => 'Iniciar sessão';

  @override
  String get spotDetailMenuLoginSubtitle => 'Inicia sessão para continuar';

  @override
  String get spotDetailMenuFlagDuplicate => 'Marcar como duplicado';

  @override
  String get spotDetailMenuFlagDuplicateSubtitleYes =>
      'Este spot é um duplicado';

  @override
  String get spotDetailMenuFlagDuplicateSubtitleNo =>
      'Já marcado como duplicado';

  @override
  String get spotDetailMenuSuggestPhoto => 'Sugerir foto';

  @override
  String get spotDetailMenuSuggestPhotoSubtitleYes =>
      'Enviar fotos para este spot';

  @override
  String get spotDetailMenuSuggestPhotoSubtitleNo =>
      'Não é possível sugerir fotos em duplicados';

  @override
  String get spotDetailMenuSuggestEdit => 'Sugerir edição';

  @override
  String get spotDetailMenuSuggestEditSubtitleYes =>
      'Propor alterações a este spot';

  @override
  String get spotDetailMenuSuggestEditSubtitleNo =>
      'Não é possível sugerir edições em duplicados';

  @override
  String get spotDetailMenuReportSpot => 'Reportar spot';

  @override
  String get spotDetailMenuReportSpotSubtitle => 'Ajuda-nos a rever este spot';

  @override
  String get spotDetailMenuEditSpot => 'Editar spot';

  @override
  String get spotDetailMenuEditSpotSubtitleNative =>
      'Cria primeiro um spot nativo';

  @override
  String get spotDetailMenuEditSpotSubtitleMod => 'Apenas moderadores';

  @override
  String get spotDetailMenuMarkDuplicate => 'Marcar como duplicado';

  @override
  String get spotDetailMenuMarkDuplicateSubtitleDup =>
      'Já marcado como duplicado';

  @override
  String get spotDetailMenuMarkDuplicateSubtitleMod => 'Apenas moderadores';

  @override
  String get spotDetailMenuRemoveDuplicateStatus => 'Remover duplicado';

  @override
  String get spotDetailMenuRemoveDuplicateSubtitle =>
      'Restaurar listagem original';

  @override
  String get spotDetailMenuCreateNative => 'Criar spot nativo';

  @override
  String get spotDetailMenuCreateNativeSubtitle => 'Copiar de fonte externa';

  @override
  String get spotDetailMenuCreateEvent => 'Criar evento';

  @override
  String get spotDetailMenuCreateEventSubtitle => 'Neste spot';

  @override
  String get spotDetailMenuHideSpot => 'Ocultar spot';

  @override
  String get spotDetailMenuHideSpotSubtitle => 'Ocultar do público';

  @override
  String get spotDetailMenuUnhideSpot => 'Mostrar spot';

  @override
  String get spotDetailMenuUnhideSpotSubtitle => 'Mostrar na app';

  @override
  String get spotDetailMenuDeleteSpot => 'Eliminar spot';

  @override
  String get spotDetailMenuDeleteSubtitleAdmin => 'Apenas administradores';

  @override
  String get spotDetailMenuTriggerResize => 'Redimensionar imagem';

  @override
  String get spotDetailMenuTriggerResizeSubtitle =>
      'Recriar versões redimensionadas';

  @override
  String get spotDetailMenuImageUrls => 'Visão geral de URLs de imagem';

  @override
  String get spotDetailMenuImageUrlsSubtitle =>
      'Original, redimensionada e URLs da API';

  @override
  String adminImageUrlsDialogTitle(String entityLabel) {
    return 'URLs de imagem — $entityLabel';
  }

  @override
  String get adminImageUrlsEmpty => 'Nenhuma imagem para mostrar.';

  @override
  String adminImageUrlsImageIndex(int index, int total) {
    return 'Imagem $index de $total';
  }

  @override
  String get adminImageUrlsLabelFirestore => 'Firestore (original)';

  @override
  String get adminImageUrlsLabel1200x1200 => '1200×1200 esperado';

  @override
  String get adminImageUrlsLabel1200x630 => '1200×630 esperado';

  @override
  String get adminImageUrlsLabelActualDownload =>
      'URL de download redimensionada';

  @override
  String get adminImageUrlsLabelSpotsApi => 'URL API Spots';

  @override
  String get adminImageUrlsStatusExists => 'Existe';

  @override
  String get adminImageUrlsStatusMissing => 'Em falta';

  @override
  String get adminImageUrlsStatusNotApplicable =>
      'Não é uma imagem redimensionável do Firebase Storage.';

  @override
  String get adminImageUrlsPreviewOriginal => 'Original';

  @override
  String get adminImageUrlsPreview1200 => '1200×1200';

  @override
  String get adminImageUrlsPreview630 => '1200×630';

  @override
  String get adminImageUrlsCopyRow => 'Copiar URL';

  @override
  String get adminImageUrlsCopyAll => 'Copiar tudo';

  @override
  String get adminImageUrlsCopiedToClipboard =>
      'Copiado para a área de transferência';

  @override
  String get adminImageUrlsApiFootnote =>
      'A API spots devolve a URL da API mesmo sem ficheiro redimensionado; os clientes podem receber 404 até o resize terminar.';

  @override
  String get adminImageUrlsEventApiFootnote =>
      'Não há API de eventos. A URL API Spots usa a mesma transformação 1200×1200 que imageUrls dos spots.';

  @override
  String get spotDetailExternalSourceCannotEdit =>
      'Spots de fontes externas não podem ser editados. Cria primeiro um spot nativo com «Marcar como duplicado» → «Criar spot nativo».';

  @override
  String get spotDetailOk => 'OK';

  @override
  String get spotDetailUnableEditNow =>
      'Este spot não pode ser editado de momento.';

  @override
  String get spotDetailOnlyAdminsDelete =>
      'Apenas administradores podem eliminar spots.';

  @override
  String get spotDetailResizeAllHaveVersions =>
      'Todas as imagens já têm versões redimensionadas';

  @override
  String spotDetailResizeSummary(
    int triggered,
    int verified,
    String failedPart,
  ) {
    return 'Redimensionar: $triggered iniciados, $verified verificados$failedPart';
  }

  @override
  String spotDetailResizeFailedPart(int failed) {
    return ', $failed falhados';
  }

  @override
  String spotDetailResizeTriggerFailed(String error) {
    return 'Não foi possível iniciar o redimensionamento: $error';
  }

  @override
  String get spotDetailUnableFlagDuplicate =>
      'Não é possível marcar este spot como duplicado de momento.';

  @override
  String get spotDetailThanksDuplicateReport =>
      'Obrigado! O teu relatório de duplicado foi enviado.';

  @override
  String get spotDetailUnableSuggestPhotos =>
      'Não é possível sugerir fotos para este spot de momento.';

  @override
  String get spotDetailCannotSuggestPhotosDuplicate =>
      'Não é possível sugerir fotos em spots duplicados.';

  @override
  String get spotDetailThanksPhotoSuggestion =>
      'Obrigado! A tua sugestão de fotos foi enviada para revisão.';

  @override
  String get spotDetailUnableSuggestEdits =>
      'Não é possível sugerir edições para este spot de momento.';

  @override
  String get spotDetailCannotSuggestEditsDuplicate =>
      'Não é possível sugerir edições em spots duplicados.';

  @override
  String get spotDetailThanksEditSuggestion =>
      'Obrigado! A tua sugestão de edição foi enviada para revisão.';

  @override
  String get spotDetailUnableReportNow =>
      'Não é possível reportar este spot de momento.';

  @override
  String get spotDetailThanksReportSubmitted =>
      'Obrigado! O teu relatório foi enviado.';

  @override
  String get spotDetailUnableAddToList =>
      'Não é possível adicionar este spot a uma lista de momento.';

  @override
  String get spotDetailNoSpotListsAccess =>
      'Não tens acesso às listas de spots.';

  @override
  String get spotDetailListCreatedAndAdded => 'Lista criada e spot adicionado!';

  @override
  String get spotDetailSpotAddedToList => 'Spot adicionado à lista!';

  @override
  String get spotDetailEditReportTooltip => 'Editar e reportar';

  @override
  String get spotDetailShareTooltip => 'Partilhar';

  @override
  String get spotDetailQuickActionSave => 'Guardar';

  @override
  String get spotDetailQuickActionEdit => 'Editar';

  @override
  String get spotDetailQuickActionShare => 'Partilhar';

  @override
  String get spotDetailQuickActionRate => 'Avaliar';

  @override
  String get spotDetailRatingTooltip =>
      'Classificação da comunidade e as tuas estrelas';

  @override
  String get spotDetailPresenceHereNow => 'Aqui agora';

  @override
  String get spotDetailCommunitySectionTitle => 'Comunidade';

  @override
  String get spotDetailCommunitySectionSubtitle =>
      'Vê quem está a treinar ou planeia treinar aqui, e partilha a tua sessão.';

  @override
  String get spotDetailCommunityNobodyHere =>
      'Ainda ninguém fez check-in. Faz check-in para mostrares que estás aqui.';

  @override
  String get spotDetailCommunityNobodyHereShort => 'Ainda ninguém aqui.';

  @override
  String get spotDetailCommunityNobodySocialShort =>
      'Ninguém aqui nem com plano ainda.';

  @override
  String get spotDetailCommunityActivityLoadError =>
      'Não foi possível carregar a atividade.';

  @override
  String get spotDetailCommunityActivityEmpty => 'Nada para mostrar agora.';

  @override
  String get spotDetailCommunityViewAll => 'Ver todos';

  @override
  String get spotDetailCommunityCheckInButton => 'Check-in';

  @override
  String get spotDetailCommunityEditCheckInButton => 'Editar check-in';

  @override
  String get spotDetailCommunitySignInToCheckInButton =>
      'Inicia sessão para fazer check-in';

  @override
  String get spotDetailCommunityPlanningVisitButton => 'Planear treino';

  @override
  String get spotDetailCommunityPlanningVisitTooltip =>
      'Define quando vais treinar aqui.';

  @override
  String get spotDetailCommunityCheckInButtonTooltip =>
      'Mostra a outros que estás aqui agora.';

  @override
  String get spotDetailCommunityEditCheckInButtonTooltip =>
      'Atualizar o teu check-in.';

  @override
  String get spotDetailCommunitySignInToCheckInButtonTooltip =>
      'Inicia sessão para fazer check-in.';

  @override
  String get spotDetailCommunityPlanningToTrain => 'A planear treinar';

  @override
  String get spotDetailCommunityNobodyPlanningShort => 'Ainda sem planos.';

  @override
  String get spotDetailCommunitySignInToPlanButton =>
      'Inicia sessão para planear';

  @override
  String get spotDetailCommunityEditTrainingPlanButton => 'Editar plano';

  @override
  String get spotCheckInDialogTitle => 'Check-in';

  @override
  String get spotCheckInDialogTitleEdit => 'Editar check-in';

  @override
  String get spotCheckInDialogIntroNew =>
      'Indica que estás a treinar aqui e mais ou menos até quando. Se partilhares em público, apareces na comunidade deste spot até à hora de fim.';

  @override
  String get spotCheckInDialogIntroEdit =>
      'Altera chegada e fim, quem pode ver o check-in e a tua nota.';

  @override
  String get spotCheckInDialogSharePublic => 'Partilhar publicamente';

  @override
  String get spotCheckInDialogShareSub =>
      'Desliga para só tu veres este check-in.';

  @override
  String get spotCheckInDialogLabelArrived => 'Chegada';

  @override
  String get spotCheckInDialogLabelHereUntil => 'Aqui até';

  @override
  String get spotCheckInDialogLabelUntil => 'Até';

  @override
  String get spotCheckInDialogStillHere => 'Ainda aqui';

  @override
  String get spotCheckInDialogEndNow => 'Terminar agora';

  @override
  String get spotCheckInDialogCancel => 'Cancelar';

  @override
  String get spotCheckInDialogSave => 'Guardar';

  @override
  String get spotCheckInDialogDelete => 'Eliminar';

  @override
  String get spotCheckInDialogConfirmDeleteTitle => 'Eliminar check-in?';

  @override
  String get spotCheckInDialogConfirmDeleteBody =>
      'Remove esta visita do teu histórico. Não retira o spot da tua lista de sítios visitados.';

  @override
  String get spotCheckInDialogExtendBannerText =>
      'Tens um check-in recente expirado aqui.';

  @override
  String get spotCheckInDialogExtendInstead => 'Prolongar esse check-in';

  @override
  String spotCheckInDialogActiveElsewhereAtNamed(String spotName) {
    return 'Estás com check-in em $spotName. Fazer check-in aqui termina esse check-in.';
  }

  @override
  String get spotCheckInDialogActiveElsewhereUnnamed =>
      'Estás com check-in noutro spot. Fazer check-in aqui termina esse check-in.';

  @override
  String get spotCheckInDialogActiveElsewhereMultiple =>
      'Tens check-ins ativos noutros spots. Fazer check-in aqui termina esses check-ins.';

  @override
  String get spotCheckInDialogNudgeEarlier => '15 minutos antes';

  @override
  String get spotCheckInDialogNudgeLater => '15 minutos depois';

  @override
  String get spotCheckInDialogTrainingPlanConversionBanner =>
      'Ao guardar, o teu plano é substituído por este check-in. A hora de fim planeada fica pré-preenchida abaixo.';

  @override
  String get spotDetailSessionNoteLabel => 'Nota (opcional)';

  @override
  String get spotDetailSessionNoteHint => 'ex.: skills ou exercícios';

  @override
  String get spotTrainingPlanDialogTitle => 'Planear treino aqui';

  @override
  String get spotTrainingPlanDialogTitleEdit => 'Editar plano de treino';

  @override
  String get spotTrainingPlanDialogCheckInCtaBody =>
      'Já estás aqui? Faz check-in para os outros saberem que chegaste.';

  @override
  String get spotTrainingPlanDialogCheckInCtaBodyEarly =>
      'Já chegaste? Faz check-in para os outros saberem.';

  @override
  String get spotTrainingPlanDialogCheckInCtaButton => 'Check-in';

  @override
  String get spotTrainingPlanDialogBody =>
      'Define quando começas e terminas. Os planos públicos aparecem na comunidade deste spot junto de outras pessoas que partilham.';

  @override
  String get spotTrainingPlanDialogSharePublic => 'Partilhar publicamente';

  @override
  String get spotTrainingPlanDialogShareSub =>
      'Desliga para só tu veres o plano.';

  @override
  String get spotTrainingPlanDialogStartLabel => 'Começa';

  @override
  String get spotTrainingPlanDialogEndLabel => 'Termina';

  @override
  String get spotTrainingPlanDialogSave => 'Guardar';

  @override
  String get spotTrainingPlanDialogCancel => 'Cancelar';

  @override
  String get spotTrainingPlanDialogDelete => 'Remover plano';

  @override
  String get spotTrainingPlanDialogDeleteTitle => 'Remover este plano?';

  @override
  String get spotTrainingPlanDialogDeleteBody =>
      'Podes criar um novo plano a qualquer momento.';

  @override
  String get spotTrainingPlanValidationOrder =>
      'A hora de fim deve ser depois do início.';

  @override
  String get spotTrainingPlanValidationMinDuration => 'Mínimo 15 minutos.';

  @override
  String get spotTrainingPlanValidationMaxDuration => 'No máximo 12 horas.';

  @override
  String get spotTrainingPlanValidationStartTooFar =>
      'O início não pode ser daqui a mais de 30 dias.';

  @override
  String get spotTrainingPlanValidationEndNotFuture =>
      'A hora de fim deve estar no futuro.';

  @override
  String get spotTrainingPlanValidationInvalid =>
      'Intervalo de tempo inválido.';

  @override
  String get spotDetailTrainingPlanSaved => 'Plano de treino guardado';

  @override
  String get spotDetailTrainingPlanUpdated => 'Plano de treino atualizado';

  @override
  String get spotDetailTrainingPlanFailed => 'Não foi possível guardar o plano';

  @override
  String get spotDetailTrainingPlanRemoved => 'Plano de treino removido';

  @override
  String get spotDetailTrainingPlanDeleteFailed =>
      'Não foi possível remover o plano';

  @override
  String get spotTrainingPlanListDialogTitle => 'A planear treinar';

  @override
  String get spotTrainingPlanListDialogSubtitle =>
      'Pessoas com plano público para este spot.';

  @override
  String get spotTrainingPlanListDialogClose => 'Fechar';

  @override
  String get spotTrainingPlanListEmpty => 'Ainda sem planos públicos.';

  @override
  String get spotTrainingPlanListLoadError =>
      'Não foi possível carregar os planos';

  @override
  String get spotTrainingPlanEditMine => 'Editar plano';

  @override
  String get spotTrainingPlanJoin => 'Juntar-se';

  @override
  String get spotTrainingPlanOnlyYou => 'Só tu';

  @override
  String get spotTrainingPlanUnnamedPerson => 'Alguém';

  @override
  String spotTrainingPlanTimeRange(String start, String end) {
    return '$start – $end';
  }

  @override
  String get spotDetailHiddenBanner =>
      'Este spot está oculto ao público. Provavelmente já não existe ou não cumpre as nossas regras. Não aparecerá nas pesquisas nem no mapa.';

  @override
  String spotDetailSourceRemovedBanner(String source) {
    return 'Este spot já não está listado em $source. Os dados podem estar desatualizados—confirma antes de visitares.';
  }

  @override
  String get spotDetailSourceRemovedUnknownSource => 'a fonte original';

  @override
  String get spotDetailSectionFeatures => 'Características';

  @override
  String get spotDetailSectionAccess => 'Acesso';

  @override
  String get spotDetailSectionFacilities => 'Instalações';

  @override
  String spotDetailJumpflixFetchFailed(String error) {
    return 'Falha ao obter Jumpflix: $error';
  }

  @override
  String get spotDetailBrandYoutube => 'YouTube';

  @override
  String get spotDetailBrandJumpflix => 'Jumpflix';

  @override
  String get spotDetailBrandAsSeenIn => 'Como em';

  @override
  String get spotDetailLoading => 'A carregar…';

  @override
  String get spotDetailLoadingYourRating => 'A carregar a tua avaliação…';

  @override
  String get spotDetailRateThisSpot => 'Avaliar este spot';

  @override
  String get spotDetailHeaderNoRatingsYet => 'Ainda sem avaliações';

  @override
  String get spotDetailCouldNotLoadProfile =>
      'Não foi possível carregar o teu perfil.';

  @override
  String get spotDetailRefreshPageToRate => 'Atualiza a página para avaliar.';

  @override
  String get spotDetailSignInToRateTitle =>
      'Inicia sessão para avaliar este spot';

  @override
  String get spotDetailSignInToRateSubtitle =>
      'Inicia sessão para avaliar este spot e ajudar outros.';

  @override
  String get spotDetailSignInButton => 'Iniciar sessão';

  @override
  String get spotDetailCreateAccountButton => 'Criar conta';

  @override
  String get spotDetailMapSwitchToMap => 'Ver mapa';

  @override
  String get spotDetailMapSwitchToSatellite => 'Ver satélite';

  @override
  String get spotDetailMapLocateOnMap => 'Ver no mapa';

  @override
  String get spotDetailDuplicateOf => 'Duplicado de';

  @override
  String get spotDetailOriginalSpotFallback => 'Spot original';

  @override
  String get spotDetailAlsoBasedOn => 'Também baseado em';

  @override
  String spotDetailGalleryPageIndicator(int current, int total) {
    return '$current / $total';
  }

  @override
  String get spotDetailSaveMenuTooltip => 'Guardar spot';

  @override
  String get spotDetailSaveMenuSignInTitle =>
      'Inicia sessão para guardar spots';

  @override
  String get spotDetailSaveMenuSignInBody =>
      'Adiciona este spot a «Quero visitar», «Já estive» ou às tuas listas. Inicia sessão ou cria uma conta gratuita.';

  @override
  String get spotDetailSaveMenuLogInOrCreate => 'Iniciar sessão ou criar conta';

  @override
  String get spotDetailSaveTooltipUpdating => 'A atualizar…';

  @override
  String get spotDetailSaveTooltipWantToVisit => 'Guardado: Quero visitar';

  @override
  String get spotDetailSaveTooltipBeenHere => 'Guardado: Já estive';

  @override
  String get spotDetailSaveTooltipGeneric => 'Guardar spot';

  @override
  String get spotDetailRemovedFromWantToVisit => 'Removido de Quero visitar';

  @override
  String get spotDetailFailedToRemove => 'Falha ao remover';

  @override
  String get spotDetailAddedToWantToVisit => 'Adicionado a Quero visitar';

  @override
  String get spotDetailFailedToAdd => 'Falha ao adicionar';

  @override
  String get spotDetailRemovedFromBeenHere => 'Removido de Já estive';

  @override
  String get spotDetailAddedToBeenHere => 'Adicionado a Já estive';

  @override
  String get spotDetailWantToVisit => 'Quero visitar';

  @override
  String get spotDetailBeenHere => 'Já estive';

  @override
  String get spotDetailViewFullListTooltip => 'Ver lista completa';

  @override
  String get spotDetailAddToCustomList => 'Adicionar a lista própria';

  @override
  String get spotDetailAddToCustomListSubtitle => 'Escolhe ou cria uma lista';

  @override
  String get spotDetailListNameEmpty => 'O nome da lista não pode estar vazio';

  @override
  String get spotDetailFailedAddToListGeneric =>
      'Não foi possível adicionar o spot à lista';

  @override
  String get spotDetailFailedCreateList => 'Não foi possível criar a lista';

  @override
  String get spotDetailFailedAddToSomeLists =>
      'Não foi possível adicionar o spot a algumas listas';

  @override
  String spotDetailAddToListTitle(String name) {
    return 'Adicionar a $name';
  }

  @override
  String get spotDetailSelectSections => 'Selecionar secções:';

  @override
  String spotDetailSectionEntryCount(int count) {
    return 'Secção ($count spots)';
  }

  @override
  String get spotDetailAddToNewSection => 'Adicionar a nova secção';

  @override
  String get spotDetailSectionNameOptional => 'Nome da secção (opcional)';

  @override
  String get spotDetailNoteOptional => 'Nota (opcional)';

  @override
  String get spotDetailSkip => 'Ignorar';

  @override
  String get spotDetailAdd => 'Adicionar';

  @override
  String get spotDetailAddToListDialogTitle => 'Adicionar à lista';

  @override
  String get spotDetailAlreadyInLists => 'Já está nestas listas:';

  @override
  String get spotDetailNoListsYet =>
      'Ainda não tens listas. Cria uma para começar!';

  @override
  String get spotDetailSelectListsPrompt =>
      'Seleciona as listas a adicionar este spot:';

  @override
  String get spotDetailCreateNewList => 'Criar lista nova';

  @override
  String get spotDetailListNameLabel => 'Nome da lista';

  @override
  String get spotDetailListNameHint => 'ex.: Os meus spots favoritos';

  @override
  String get spotDetailListDescriptionLabel => 'Descrição (opcional)';

  @override
  String get spotDetailListDescriptionHint =>
      'Adiciona uma descrição para esta lista';

  @override
  String get spotDetailVisibilityLabel => 'Visibilidade';

  @override
  String get spotDetailCreateAndAdd => 'Criar e adicionar';

  @override
  String get spotDetailReportDuplicateTitle => 'Reportar spot duplicado';

  @override
  String get spotDetailReportDuplicateIntro =>
      'Seleciona o spot do qual este é duplicado.';

  @override
  String get spotDetailEmailInvalid => 'Introduz um e-mail válido.';

  @override
  String get spotDetailEmailRequired => 'Introduz um e-mail.';

  @override
  String get spotDetailSubmitReport => 'Enviar relatório';

  @override
  String get spotDetailReportThisSpotTitle => 'Reportar este spot';

  @override
  String spotDetailReportIntro(String name) {
    return 'Diz-nos o que está errado com $name. Os moderadores vão rever o relatório.';
  }

  @override
  String get spotDetailReportWhatWrong => 'O que está a acontecer?';

  @override
  String get spotDetailReportCategoryLabel => 'Escolhe uma categoria';

  @override
  String get spotDetailReportCategoryHint =>
      'Escolhe uma categoria de relatório';

  @override
  String get spotDetailReportDescribeIssue => 'Descreve o problema';

  @override
  String get spotDetailReportDescribeIssueHint =>
      'Diz-nos o que não corresponde à realidade';

  @override
  String get spotDetailReportAdditionalDetails => 'Detalhes adicionais';

  @override
  String get spotDetailReportAdditionalDetailsHint =>
      'Mais alguma coisa que devamos saber?';

  @override
  String get spotDetailReportEmailLabel => 'E-mail';

  @override
  String get spotDetailReportEmailHelper =>
      'Só te contactamos sobre este relatório.';

  @override
  String spotDetailReportReachOutAt(String email) {
    return 'Se precisarmos de mais informações, contactamos-te em $email.';
  }

  @override
  String get spotDetailReportReachOutAccount =>
      'Se precisarmos de mais informações, usamos o e-mail da tua conta.';

  @override
  String get spotDetailReportCategoryOtherDescribe =>
      'Descreve o problema ao escolheres «Outro».';

  @override
  String get spotDetailReportCategoryRequired => 'Escolhe uma categoria.';

  @override
  String get spotDetailReportSendFailed =>
      'Não foi possível enviar o relatório. Tenta novamente.';

  @override
  String get spotDetailReportCategoryClosed => 'Spot fechado ou removido';

  @override
  String get spotDetailReportCategoryInaccurate =>
      'Localização ou dados parecem incorretos';

  @override
  String get spotDetailReportCategoryUnsafe => 'Condições inseguras';

  @override
  String get spotDetailReportCategoryNotASpot => 'Não é um spot';

  @override
  String get spotDetailReportCategoryOther => 'Outro';

  @override
  String get spotDetailReportCategoryClosedDesc =>
      'O spot foi fechado, demolido ou removido de forma permanente e já não é acessível. Dá mais detalhes abaixo.';

  @override
  String get spotDetailReportCategoryInaccurateDesc =>
      'Algo neste spot parece errado: o pin, o nome, a descrição ou a morada podem estar incorretos. Usa isto quando não sabes qual é a informação correta. Descreve abaixo o que parece incorreto. Se sabes o que alterar, usa «Sugerir edição» no menu do spot.';

  @override
  String get spotDetailReportCategoryUnsafeDesc =>
      'O spot tornou-se perigoso (estrutura, ambiente, etc.). Explica abaixo o que é inseguro.';

  @override
  String get spotDetailReportCategoryNotASpotDesc =>
      'Apenas para casos objetivos: spam, locais inválidos (ex. mar), residências privadas, cidades inteiras ou entradas claramente inválidas. Para opiniões sobre qualidade, usa a avaliação. Explica por que não é um spot.';

  @override
  String get spotDetailReportCategoryOtherDesc =>
      'Qualquer outro problema. Descreve no campo abaixo.';

  @override
  String get spotDetailMarkDuplicateTitle => 'Marcar como duplicado';

  @override
  String get spotDetailMarkDuplicateBody =>
      'Tens a certeza de que queres marcar este spot como duplicado? Podes reverter mais tarde.';

  @override
  String get spotDetailMarkDuplicateAddToOriginal =>
      'Escolhe o que adicionar ao spot original:';

  @override
  String get spotDetailMarkDuplicatePhotos => 'Fotos';

  @override
  String get spotDetailMarkDuplicateYoutube => 'Ligações do YouTube';

  @override
  String get spotDetailMarkDuplicateOverwrite =>
      'Escolhe o que substituir no spot original (se definido):';

  @override
  String get spotDetailMarkDuplicateName => 'Nome';

  @override
  String get spotDetailMarkDuplicateDescription => 'Descrição';

  @override
  String get spotDetailMarkDuplicateLocation => 'Localização';

  @override
  String get spotDetailMarkDuplicateSpotAttributes => 'Atributos do spot';

  @override
  String get spotDetailConfirm => 'Confirmar';

  @override
  String get spotDetailPickImagesFailed =>
      'Não foi possível escolher imagens. Tenta novamente.';

  @override
  String get spotDetailSelectAtLeastOnePhoto => 'Seleciona pelo menos uma foto';

  @override
  String get spotDetailSuggestPhotosTitle => 'Sugerir fotos';

  @override
  String get spotDetailSuggestPhotosIntro =>
      'Envia fotos para adicionar a este spot. Os moderadores revêem antes de publicar.';

  @override
  String get spotDetailSelectPhotos => 'Selecionar fotos';

  @override
  String get spotDetailPickPhotos => 'Escolher fotos';

  @override
  String get spotDetailAdditionalDetailsOptional =>
      'Detalhes adicionais (opcional)';

  @override
  String get spotDetailAdditionalDetailsHint =>
      'Mais informação sobre estas fotos…';

  @override
  String get spotDetailSuggestPhotosEmailHelper =>
      'Só te contactamos sobre esta sugestão.';

  @override
  String get spotDetailSuggestPhotosSubmitFailed =>
      'Não foi possível enviar a sugestão de fotos. Tenta novamente.';

  @override
  String spotDetailSuggestPhotosSubmitError(String error) {
    return 'Erro ao enviar sugestão de fotos: $error';
  }

  @override
  String get spotDetailSuggestEditTitle => 'Sugerir edição';

  @override
  String get spotDetailSuggestEditIntro =>
      'Propõe alterações a este spot. Os moderadores revêem as sugestões.';

  @override
  String get spotDetailSuggestEditSuggestChange =>
      'Sugere pelo menos uma alteração.';

  @override
  String get spotDetailSuggestEditSubmitFailed =>
      'Não foi possível enviar a sugestão de edição. Tenta novamente.';

  @override
  String spotDetailSuggestEditSubmitError(String error) {
    return 'Erro ao enviar sugestão de edição: $error';
  }

  @override
  String get spotDetailGeocoding => 'Geocodificação…';

  @override
  String get spotDetailChangeLocationPicked =>
      'Alterar localização (escolhida)';

  @override
  String get spotDetailPickLocationOnMap =>
      'Escolher outra localização no mapa';

  @override
  String get spotDetailFieldTitle => 'Título';

  @override
  String get spotDetailFieldTitleHint => 'Título do spot';

  @override
  String get spotDetailFieldDescription => 'Descrição';

  @override
  String get spotDetailFieldDescriptionHint => 'Descrição do spot';

  @override
  String get spotDetailFieldSpotAttributes => 'Atributos do spot';

  @override
  String get spotDetailSuggestEditEmailHelper =>
      'Só te contactamos sobre esta sugestão.';

  @override
  String get spotDetailMustBeLoggedInToRate =>
      'Tens de ter sessão iniciada para avaliar spots';

  @override
  String spotDetailRatingSubmitted(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Avaliação de $count estrelas enviada!',
      one: 'Avaliação de 1 estrela enviada!',
    );
    return '$_temp0';
  }

  @override
  String get spotDetailRatingSubmitFailed =>
      'Não foi possível enviar a avaliação. Tenta novamente.';

  @override
  String spotDetailRatingSubmitError(String error) {
    return 'Erro ao enviar avaliação: $error';
  }

  @override
  String get spotDetailNotExternalSource =>
      'Este spot não vem de uma fonte externa.';

  @override
  String get spotDetailMustBeLoggedInCreateNative =>
      'Tens de ter sessão iniciada para criar um spot nativo.';

  @override
  String get spotDetailCreateNativeDialogTitle => 'Criar spot nativo';

  @override
  String get spotDetailCreateNativeDialogBody =>
      'Será criado um spot nativo com base neste e o spot atual será marcado como duplicado. Todos os dados (nome, descrição, localização, fotos, ligações YouTube, atributos) serão copiados.\n\nNota: os administradores podem remover spots e ligações de duplicado se necessário.';

  @override
  String get spotDetailCreateButton => 'Criar';

  @override
  String get spotDetailUnableCreateNativeNow =>
      'Não é possível criar um spot nativo de momento.';

  @override
  String get spotDetailFailedCreateNativeSpot =>
      'Não foi possível criar o spot nativo';

  @override
  String get spotDetailNativeCreatedDuplicateMarked =>
      'Spot nativo criado e spot atual marcado como duplicado.';

  @override
  String get spotDetailFailedMarkDuplicateGeneric =>
      'Não foi possível marcar como duplicado';

  @override
  String spotDetailErrorCreatingNativeSpot(String error) {
    return 'Erro ao criar spot nativo: $error';
  }

  @override
  String get spotDetailUnableMarkDuplicateNow =>
      'Não é possível marcar este spot como duplicado de momento.';

  @override
  String get spotDetailAlreadyMarkedDuplicate =>
      'Este spot já está marcado como duplicado.';

  @override
  String get spotDetailSpotMarkedDuplicateSuccess =>
      'Spot marcado como duplicado.';

  @override
  String spotDetailErrorMarkingDuplicateSpot(String error) {
    return 'Erro ao marcar como duplicado: $error';
  }

  @override
  String get spotDetailModeratorsOnlyHideUnhide =>
      'Apenas moderadores podem ocultar ou mostrar spots.';

  @override
  String get spotDetailHideSpotTitle => 'Ocultar spot';

  @override
  String get spotDetailUnhideSpotTitle => 'Mostrar spot';

  @override
  String get spotDetailHideSpotMessage =>
      'O spot deixa de ser visível ao público. Não aparece nas pesquisas nem no mapa, mas os dados são guardados e podem ser mostrados depois.';

  @override
  String get spotDetailUnhideSpotMessage =>
      'O spot volta a ser público e aparece nas pesquisas e no mapa.';

  @override
  String get spotDetailActionHide => 'Ocultar';

  @override
  String get spotDetailActionUnhide => 'Mostrar';

  @override
  String get spotDetailUnableHideUnhideNow =>
      'Não é possível ocultar ou mostrar este spot de momento.';

  @override
  String get spotDetailSpotHiddenSuccess => 'Spot ocultado.';

  @override
  String get spotDetailSpotUnhiddenSuccess => 'Spot visível novamente.';

  @override
  String get spotDetailFailedHideSpot => 'Não foi possível ocultar o spot';

  @override
  String get spotDetailFailedUnhideSpot => 'Não foi possível mostrar o spot';

  @override
  String spotDetailErrorHidingSpot(String error) {
    return 'Erro ao ocultar: $error';
  }

  @override
  String spotDetailErrorUnhidingSpot(String error) {
    return 'Erro ao mostrar: $error';
  }

  @override
  String get spotDetailNotMarkedAsDuplicate =>
      'Este spot não está marcado como duplicado.';

  @override
  String get spotDetailModeratorsOnlyRemoveDuplicateStatus =>
      'Apenas moderadores podem remover o estado de duplicado.';

  @override
  String get spotDetailRemoveDuplicateDialogBody =>
      'O estado de duplicado será removido; o spot deixa de ser considerado duplicado.\n\nContinuar?';

  @override
  String get spotDetailRemoveButton => 'Remover';

  @override
  String get spotDetailUnableRemoveDuplicateStatusNow =>
      'Não é possível remover o estado de duplicado de momento.';

  @override
  String get spotDetailDuplicateStatusRemovedSuccess =>
      'Estado de duplicado removido.';

  @override
  String get spotDetailFailedRemoveDuplicateStatusGeneric =>
      'Não foi possível remover o estado de duplicado';

  @override
  String spotDetailErrorRemovingDuplicateStatus(String error) {
    return 'Erro ao remover estado de duplicado: $error';
  }

  @override
  String get spotDetailCheckingLinkedData => 'A verificar dados ligados…';

  @override
  String get spotDetailDeleteSpotDialogTitle => 'Eliminar spot';

  @override
  String get spotDetailDeleteSpotConfirmMessage =>
      'Tens a certeza de que queres eliminar este spot? Esta ação não pode ser anulada.';

  @override
  String get spotDetailLinkedDataHeading => 'Este spot tem dados ligados:';

  @override
  String spotDetailLinkedRatingsLine(int count) {
    return '• Avaliações: $count';
  }

  @override
  String spotDetailLinkedReportsLine(int count) {
    return '• Relatórios: $count';
  }

  @override
  String spotDetailLinkedDuplicatesLine(int count) {
    return '• Spots duplicados: $count';
  }

  @override
  String get spotDetailResolveLinksBeforeDelete =>
      'Resolve estas ligações antes de eliminar o spot.';

  @override
  String get spotDetailSpotDeletedSuccess => 'Spot eliminado.';

  @override
  String get spotDetailFailedDeleteSpot => 'Não foi possível eliminar o spot';

  @override
  String spotDetailErrorDeletingSpot(String error) {
    return 'Erro ao eliminar o spot: $error';
  }

  @override
  String get spotDetailFlagDuplicateDialogTitle => 'Marcar como duplicado';

  @override
  String get spotDetailFlagDuplicateIntro =>
      'Este spot parece um duplicado de outro. Seleciona o spot original abaixo.';

  @override
  String get spotDetailFlagDuplicateWhichQuestion => 'De que spot é duplicado?';

  @override
  String get spotDetailDuplicateSearchHint =>
      'Cola o URL do spot ou introduz o ID';

  @override
  String get spotDetailSearch => 'Pesquisar';

  @override
  String get spotDetailNearbySpotsWithin50m =>
      'Spots próximos (num raio de ~50 m)';

  @override
  String get spotDetailFoundSpot => 'Spot encontrado';

  @override
  String spotDetailSpotIdLabel(String id) {
    return 'ID do spot: $id';
  }

  @override
  String get spotDetailRemoveSelectionTooltip => 'Remover seleção';

  @override
  String get spotDetailImageFailedToLoad =>
      'Não foi possível carregar a imagem';

  @override
  String get spotDetailClose => 'Fechar';

  @override
  String spotDetailExpandMoreCount(int count) {
    return 'mais $count';
  }

  @override
  String get spotDetailSubmit => 'Enviar';

  @override
  String get spotDetailDuplicateReportSelectRequired =>
      'Seleciona o spot do qual este é duplicado.';

  @override
  String get spotDetailDuplicateSearchEmpty => 'Introduz um ID ou URL do spot';

  @override
  String get spotDetailDuplicateInvalidUrl => 'ID ou URL do spot inválidos';

  @override
  String get spotDetailDuplicateCannotSelectSelf =>
      'Um spot não pode ser duplicado de si próprio';

  @override
  String get spotDetailDuplicateSpotNotFound => 'Spot não encontrado';

  @override
  String spotDetailDuplicateFailedLoadSpot(String error) {
    return 'Não foi possível carregar o spot: $error';
  }

  @override
  String get sourceDetailsLoadingSource => 'A carregar fonte...';

  @override
  String get sourceDetailsErrorTitle => 'Erro';

  @override
  String get sourceDetailsNotFound => 'Fonte não encontrada';

  @override
  String get sourceDetailsTotalSpots => 'Total de spots';

  @override
  String get sourceDetailsFolders => 'Pastas';

  @override
  String get sourceDetailsGoToSource => 'Ir para a fonte';

  @override
  String get sourceDetailsAdded => 'Adicionado';

  @override
  String get sourceDetailsLastImported => 'Última importação';

  @override
  String sourceDetailsRelativeDaysAgo(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Há $count dias',
      one: 'Há 1 dia',
    );
    return '$_temp0';
  }

  @override
  String sourceDetailsRelativeHoursAgo(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Há $count horas',
      one: 'Há 1 hora',
    );
    return '$_temp0';
  }

  @override
  String sourceDetailsRelativeMinutesAgo(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Há $count minutos',
      one: 'Há 1 minuto',
    );
    return '$_temp0';
  }

  @override
  String get sourceDetailsRelativeJustNow => 'Agora mesmo';

  @override
  String get eventSourceDetailsLoadingSource =>
      'A carregar fonte de eventos...';

  @override
  String get eventSourceDetailsTotalEvents => 'Total de eventos';

  @override
  String exploreEventCountShort(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count eventos',
      one: '1 evento',
    );
    return '$_temp0';
  }

  @override
  String spotTrackingSignInToViewList(String listName) {
    return 'Inicia sessão para ver a tua lista «$listName»';
  }

  @override
  String spotTrackingNoSpotsInList(String listName) {
    return 'Sem spots em $listName';
  }

  @override
  String get spotListSaveTooltipSaveList => 'Guardar lista';

  @override
  String get spotListSaveTooltipSavedList => 'Lista guardada';

  @override
  String get spotListSaveSignInTitle => 'Inicia sessão para guardar listas';

  @override
  String get spotListSaveSignInBody =>
      'Guarda a lista de spots de outra pessoa no teu perfil para poderes abri-la novamente mais tarde.';

  @override
  String get spotListSaveSavedToProfile => 'Lista guardada no teu perfil';

  @override
  String get spotListSaveCouldNotSaveList => 'Não foi possível guardar a lista';

  @override
  String get spotListSaveRemovedFromSavedLists =>
      'Removida das listas guardadas';

  @override
  String get spotListSaveCouldNotRemoveList =>
      'Não foi possível remover a lista';

  @override
  String get spotListSaveActionSaveList => 'Guardar lista';

  @override
  String get spotListSaveActionRemoveFromSaved => 'Remover das guardadas';

  @override
  String get spotListSaveActionViewSavedLists => 'Ver listas guardadas';

  @override
  String get spotListDetailListNotFoundOrNotAccessible =>
      'Lista não encontrada ou sem acesso';

  @override
  String get spotListDetailDeleteListTitle => 'Eliminar lista';

  @override
  String spotListDetailDeleteListConfirmation(String name) {
    return 'Tens a certeza de que queres eliminar \"$name\"? Esta ação não pode ser anulada.';
  }

  @override
  String get spotListDetailDeleteAction => 'Eliminar';

  @override
  String get spotListDetailListDeleted => 'Lista eliminada';

  @override
  String get spotListDetailFailedToDeleteList =>
      'Não foi possível eliminar a lista';

  @override
  String get spotListDetailNoSpotsInThisList => 'Sem spots nesta lista';

  @override
  String get spotListDetailEditListTitle => 'Editar lista';

  @override
  String get spotListDetailMoreInfoLinkLabel =>
      'Ligação com mais informação (opcional)';

  @override
  String get spotListDetailMoreInfoLinkHint => 'https://…';

  @override
  String get spotListDetailMoreInfoLinkHelper =>
      'Uma página na web com mais informação sobre esta lista';

  @override
  String get spotListDetailMoreInfoLinkValidationError =>
      'A ligação com mais informação tem de ser um URL válido (http ou https), por exemplo example.com ou https://example.com/pagina';

  @override
  String get spotListDetailSave => 'Guardar';

  @override
  String get spotListDetailListUpdated => 'Lista atualizada';

  @override
  String get spotListDetailFailedToUpdateList =>
      'Não foi possível atualizar a lista';

  @override
  String get spotListDetailVisibilityPublicList => 'Lista pública';

  @override
  String get spotListDetailVisibilityUnlistedList => 'Lista não listada';

  @override
  String get spotListDetailVisibilityPrivateList => 'Lista privada';

  @override
  String get spotListDetailCouldNotOpenProfile =>
      'Não foi possível abrir o perfil';

  @override
  String spotListDetailCreatedPart(String visibility, String date) {
    return '$visibility criada $date';
  }

  @override
  String get spotListDetailCreatedBySuffix => ' por ';

  @override
  String spotListDetailLastUpdatedPart(String date) {
    return ', e atualizada pela última vez $date.';
  }

  @override
  String get spotListDetailMoreInformationOn => 'Mais informação em ';

  @override
  String get detailExternalLinkCaption => 'Mais informação';

  @override
  String detailExternalLinkOpenSemantics(String host) {
    return 'Abrir $host';
  }

  @override
  String get spotListDetailCopiedToClipboard =>
      'Lista copiada para a área de transferência!';

  @override
  String spotListDetailCopyFailed(String error) {
    return 'Não foi possível copiar a lista: $error';
  }

  @override
  String get spotListDetailHighlightListOnMap => 'Destacar lista no mapa';

  @override
  String get spotListDetailEditListTooltip => 'Editar lista';

  @override
  String get spotListDetailMenuListSettings => 'Definições da lista';

  @override
  String get spotListDetailMenuOrganizeList => 'Organizar lista';

  @override
  String get spotListDetailMenuDeleteList => 'Eliminar lista';

  @override
  String get spotListDetailPageTitle => 'Lista de spots';

  @override
  String get spotListDetailListNotFound => 'Lista não encontrada';

  @override
  String spotListDetailMetaDescriptionFallback(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count spots de parkour',
      one: '1 spot de parkour',
    );
    return 'Uma lista curada de $_temp0 no Parkour·Spot';
  }

  @override
  String get detailUpcomingEventLabel => 'Próximo evento';

  @override
  String get detailUpcomingEventOpen => 'Abrir';

  @override
  String get publicProfilePageTitle => 'Perfil';

  @override
  String get publicProfileShareProfileTooltip => 'Partilhar perfil';

  @override
  String get publicProfileErrorLoadingProfile => 'Erro ao carregar perfil';

  @override
  String get publicProfilePleaseTryAgainLater => 'Tenta novamente mais tarde';

  @override
  String publicProfileMetaDescription(String name, String defaultDescription) {
    return 'Vê os spots e listas de parkour de $name no Parkour·Spot — $defaultDescription';
  }

  @override
  String get publicProfileProfileNotFound => 'Perfil não encontrado';

  @override
  String get publicProfileNotFoundOrPrivate =>
      'Este perfil não existe ou é privado.';

  @override
  String publicProfileMemberSince(String date) {
    return 'Membro desde $date';
  }

  @override
  String get publicProfileEditProfileTooltip => 'Editar perfil';

  @override
  String get publicProfileSpotTracking => 'Seguimento de spots';

  @override
  String get publicProfileNoSpotsYet => 'Ainda sem spots';

  @override
  String get publicProfileAddSpotsFromSpotDetailPages =>
      'Adiciona spots a partir das páginas de detalhe do spot';

  @override
  String get publicProfileBeenTo => 'Já visitados';

  @override
  String get publicProfileMyCheckIns => 'A minha atividade de treino';

  @override
  String get publicProfileMyCheckInsSubtitle =>
      'Os teus próximos planos e o teu histórico de check-ins';

  @override
  String get myCheckInsSignInPrompt =>
      'Inicia sessão para ver os teus check-ins e planos de treino';

  @override
  String get myCheckInsLoadMore => 'Carregar mais';

  @override
  String get myCheckInsEmptyTitle => 'Ainda sem visitas nem planos';

  @override
  String get myCheckInsEmptyDescription =>
      'Abre um spot para fazer check-in ou planear treino. Até à hora de fim que definires, outras pessoas podem ver-te como «aqui agora» nesse spot, a menos que mantenhas privado.';

  @override
  String get myCheckInsIntro =>
      'Os planos de treino mostram as sessões futuras que planeaste em spots. Um check-in regista uma visita — quando chegaste e até quando esperas ficar. As entradas públicas podem mostrar-te num spot até à hora final; as privadas só tu vês.';

  @override
  String get myCheckInsUpcomingPlansTitle => 'Treino a seguir';

  @override
  String get myCheckInsPastCheckInsTitle => 'Check-ins';

  @override
  String get myCheckInsNoCheckInsYet => 'Ainda sem check-ins registados.';

  @override
  String get myCheckInsCheckInsLoadFailed =>
      'Não foi possível carregar os check-ins.';

  @override
  String get myCheckInsSpotFallback => 'Spot';

  @override
  String get myCheckInsPrivateOnlyYou => 'Privado — só tu podes ver isto';

  @override
  String myCheckInsDurationDaysShort(int count) {
    return '${count}d';
  }

  @override
  String myCheckInsDurationHoursShort(int count) {
    return '${count}h';
  }

  @override
  String myCheckInsDurationMinutesShort(int count) {
    return '${count}m';
  }

  @override
  String get publicProfileSpotLists => 'Listas de spots';

  @override
  String get publicProfileYours => 'Tuas';

  @override
  String get publicProfileCreateYourFirstList => 'Cria a tua primeira lista';

  @override
  String get publicProfileSaved => 'Guardadas';

  @override
  String get publicProfilePublicSpotLists => 'Listas públicas de spots';

  @override
  String get publicProfileNoSavedListsYet => 'Ainda sem listas guardadas';

  @override
  String get publicProfileSaveListsHint =>
      'Guarda listas que encontrares nas páginas de listas de outros utilizadores';

  @override
  String get publicProfileSavedListsUnavailable =>
      'As tuas listas guardadas já não estão disponíveis ou foram removidas.';

  @override
  String get publicProfileListCreatedSuccessfully => 'Lista criada com sucesso';

  @override
  String get publicProfileChangeProfilePicture => 'Alterar foto de perfil';

  @override
  String get publicProfileChooseFromGallery => 'Escolher da galeria';

  @override
  String get publicProfileTakePhoto => 'Tirar foto';

  @override
  String get publicProfileRemovePicture => 'Remover foto';

  @override
  String publicProfileErrorPickingImage(String error) {
    return 'Erro ao escolher imagem: $error';
  }

  @override
  String publicProfileErrorTakingPhoto(String error) {
    return 'Erro ao tirar foto: $error';
  }

  @override
  String get publicProfileProcessingImage => 'A processar imagem...';

  @override
  String get publicProfileReadingImage => 'A ler imagem...';

  @override
  String get publicProfileUploading => 'A carregar...';

  @override
  String get publicProfileFinishing => 'A finalizar...';

  @override
  String get publicProfileUpdatingProfile => 'A atualizar perfil...';

  @override
  String get publicProfileProfilePictureUpdatedSuccessfully =>
      'Foto de perfil atualizada com sucesso';

  @override
  String get publicProfileFailedToUpdateProfilePicture =>
      'Não foi possível atualizar a foto de perfil';

  @override
  String publicProfileErrorUploadingProfilePicture(String error) {
    return 'Erro ao carregar foto de perfil: $error';
  }

  @override
  String get publicProfileRemoveProfilePicture => 'Remover foto de perfil';

  @override
  String get publicProfileRemoveProfilePictureConfirmation =>
      'Tens a certeza de que queres remover a tua foto de perfil?';

  @override
  String get publicProfileProfilePictureRemovedSuccessfully =>
      'Foto de perfil removida com sucesso';

  @override
  String get publicProfileFailedToRemoveProfilePicture =>
      'Não foi possível remover a foto de perfil';

  @override
  String publicProfileErrorRemovingProfilePicture(String error) {
    return 'Erro ao remover foto de perfil: $error';
  }

  @override
  String get publicProfileProfileCopiedToClipboard =>
      'Perfil copiado para a área de transferência!';

  @override
  String publicProfileFailedToCopyProfile(String error) {
    return 'Não foi possível copiar o perfil: $error';
  }

  @override
  String get publicProfileStatsSpots => 'Spots';

  @override
  String get publicProfileStatsRatings => 'Avaliações';

  @override
  String get publicProfileSettingsTitle => 'Definições do perfil';

  @override
  String get publicProfileEmailLabel => 'E-mail';

  @override
  String get publicProfileEmailNotShownHint =>
      'O teu e-mail não é mostrado publicamente.';

  @override
  String get publicProfileDisplayNameLabel => 'Nome de exibição';

  @override
  String get publicProfileNoDisplayNameSet => 'Sem nome de exibição definido';

  @override
  String get publicProfileEditAction => 'Editar';

  @override
  String get publicProfileDisplayNameHint => 'Introduz o teu nome';

  @override
  String publicProfileDisplayNameHelper(int max) {
    return 'Como o teu nome é mostrado aos outros';
  }

  @override
  String publicProfileDisplayNameMaxLengthError(int max) {
    return 'O nome de exibição deve ter no máximo 50 caracteres';
  }

  @override
  String get publicProfileDisplayNameUpdated => 'Nome de exibição atualizado';

  @override
  String get publicProfileDisplayNameRemoved => 'Nome de exibição removido';

  @override
  String get publicProfileDisplayNameUpdateFailed =>
      'Não foi possível atualizar o nome de exibição';

  @override
  String get publicProfileSaveAction => 'Guardar';

  @override
  String get publicProfileUsernameLabel => 'Nome de utilizador';

  @override
  String get publicProfileNoUsernameSet => 'Sem nome de utilizador definido';

  @override
  String get publicProfileUsernameHint => 'Introduz um nome de utilizador';

  @override
  String get publicProfileUsernameHelper =>
      'Único e usado no URL do teu perfil';

  @override
  String get publicProfileUsernameEmpty =>
      'O nome de utilizador não pode estar vazio';

  @override
  String get publicProfileUsernameTaken =>
      'Esse nome de utilizador já está em uso';

  @override
  String get publicProfileUsernameUpdated => 'Nome de utilizador atualizado';

  @override
  String get publicProfileUsernameUpdateFailed =>
      'Não foi possível atualizar o nome de utilizador';

  @override
  String get publicProfileInstagramLabel => 'Instagram';

  @override
  String get publicProfileNoInstagramSet => 'Sem Instagram definido';

  @override
  String get publicProfileAddAction => 'Adicionar';

  @override
  String get publicProfileInstagramLinkLabel => 'Ligação do Instagram';

  @override
  String get publicProfileInstagramLinkHint => 'https://instagram.com/teunome';

  @override
  String get publicProfileInstagramLinkHelper =>
      'URL completo para o teu perfil de Instagram';

  @override
  String get publicProfileInstagramInvalid =>
      'Introduz um URL válido de Instagram';

  @override
  String get publicProfileInstagramRemoved => 'Ligação do Instagram removida';

  @override
  String get publicProfileInstagramUpdated => 'Ligação do Instagram atualizada';

  @override
  String get publicProfileInstagramUpdateFailed =>
      'Não foi possível atualizar a ligação do Instagram';

  @override
  String get publicProfilePrivacyTitle => 'Privacidade';

  @override
  String get publicProfilePrivacyPublicLabel => 'Perfil público';

  @override
  String get publicProfilePrivacyPrivateLabel => 'Perfil privado';

  @override
  String get publicProfilePrivacyPublicDescription =>
      'Qualquer pessoa pode ver o teu perfil e listas públicas.';

  @override
  String get publicProfilePrivacyPrivateDescription =>
      'Só tu podes ver o teu perfil.';

  @override
  String get publicProfilePrivacyNowPublic => 'O teu perfil é agora público';

  @override
  String get publicProfilePrivacyNowPrivate => 'O teu perfil é agora privado';

  @override
  String get publicProfileFailedToUpdateProfilePrivacy =>
      'Não foi possível atualizar a privacidade do perfil';

  @override
  String get eventDetailRouteErrorLoading => 'Erro ao carregar o evento';

  @override
  String get eventDetailRouteTryAgainLater => 'Tente novamente mais tarde';

  @override
  String get eventDetailRouteNotFound => 'Evento não encontrado';

  @override
  String get eventDetailRouteGoToExplore => 'Ir para Explorar';

  @override
  String get eventDetailStartsLabel => 'Início';

  @override
  String get eventDetailEndsLabel => 'Termina';

  @override
  String get eventDetailLocationLabel => 'Localização';

  @override
  String get eventDetailOpenInMaps => 'Abrir no mapa';

  @override
  String get eventDetailLinkedSpotsLabel => 'Spots ligados';

  @override
  String get eventDetailNoLinkedSpots => 'Nenhum spot ligado encontrado.';

  @override
  String get eventDetailLinkedSpotListsLabel => 'Listas de spots ligadas';

  @override
  String get eventDetailNoLinkedSpotLists =>
      'Nenhuma lista de spots ligada encontrada.';

  @override
  String get eventDetailEventSpotsLabel => 'Spots deste evento';

  @override
  String get eventDetailNoEventSpots =>
      'Lista de spots do evento não encontrada.';

  @override
  String get eventDetailEventSpotListViewAll => 'Ver lista de spots';

  @override
  String get eventDetailEventSpotListSeeOnMap => 'Ver no mapa';

  @override
  String eventDetailEventSpotListMoreSpots(int count) {
    return '+ $count mais';
  }

  @override
  String get eventDetailEventSpotLocationsLabel => 'Locais do evento';

  @override
  String get eventDetailNoEventSpotLocations =>
      'Spots do evento não encontrados.';

  @override
  String get eventDetailEventSpotViewDetails => 'Ver spot';

  @override
  String get adminEventEditTitle => 'Editar evento';

  @override
  String get adminEventEditSave => 'Guardar alterações';

  @override
  String get adminEventExternalSyncWarningTitle =>
      'Evento de calendário externo';

  @override
  String get adminEventExternalSyncWarningBody =>
      'A próxima sincronização pode substituir título, horário, descrição e local do feed externo. Spots e listas ligados são geridos aqui e não são apagados na sincronização.';

  @override
  String get adminEventLinkedSpotListsTitle => 'Listas de spots ligadas';

  @override
  String get adminEventAddSpotList => 'Adicionar lista';

  @override
  String get adminEventNoLinkedSpotLists => 'Ainda sem listas selecionadas';

  @override
  String get adminSpotListSelectionTitle => 'Selecionar lista de spots';

  @override
  String get adminSpotListSelectionInputLabel => 'ID da lista ou URL';

  @override
  String get adminSpotListSelectionInputHint =>
      'id-lista ou https://parkour.spot/list/…';

  @override
  String get adminSpotListSelectionLookup => 'Procurar';

  @override
  String get adminSpotListSelectionSelect => 'Selecionar';

  @override
  String get adminSpotListSelectionInvalidInput =>
      'Introduza um ID de lista ou URL /list/…';

  @override
  String get adminSpotListSelectionNotFound =>
      'Lista não encontrada ou inacessível';

  @override
  String get adminSpotListSelectionPrivateList =>
      'Listas privadas não podem ser ligadas a eventos';

  @override
  String get adminSpotListSelectionLoadFailed =>
      'Não foi possível carregar a lista';

  @override
  String adminSpotListSelectionFoundSubtitle(String visibility, int count) {
    return '$visibility · $count spots';
  }

  @override
  String get eventDetailAdminEditEvent => 'Editar evento';

  @override
  String get eventDetailMenuEditEventSubtitleNative =>
      'Cria primeiro um evento nativo';

  @override
  String get eventDetailMenuEditEventSubtitleMod => 'Apenas moderador';

  @override
  String get eventDetailExternalSourceCannotEdit =>
      'Eventos de fontes externas não podem ser editados. Cria primeiro um evento nativo com «Marcar como duplicado» → «Criar evento nativo».';

  @override
  String get eventDetailSourceLabel => 'Fonte';

  @override
  String get eventDetailAdminMenuTooltip => 'Admin';

  @override
  String get eventDetailStaffMenuTooltip => 'Equipa';

  @override
  String get eventDetailMenuCreateNative => 'Criar evento nativo';

  @override
  String get eventDetailMenuCreateNativeSubtitle => 'Copiar de fonte externa';

  @override
  String get eventDetailMenuSuggestPhotoSubtitleYes =>
      'Enviar fotos para este evento';

  @override
  String get eventDetailMenuSuggestPhotoSubtitleNo =>
      'Indisponível para duplicados';

  @override
  String get eventDetailMenuSuggestEditSubtitleYes =>
      'Propor alterações a este evento';

  @override
  String get eventDetailMenuSuggestEditSubtitleNo =>
      'Indisponível para duplicados';

  @override
  String get eventDetailMenuSuggestBlockedUnavailable => 'Indisponível agora';

  @override
  String get eventDetailCreateNativeDialogTitle => 'Criar evento nativo';

  @override
  String get eventDetailCreateNativeDialogBody =>
      'Isto criará um novo evento nativo com base neste evento e marcará o evento atual como duplicado. Os dados do evento (título, descrição, horário, localização, imagens, site e spots ligados) serão copiados para o novo evento nativo.';

  @override
  String get eventDetailNotExternalSource =>
      'Este evento não é de uma fonte externa.';

  @override
  String get eventDetailMustBeLoggedInCreateNative =>
      'Tem de iniciar sessão para criar um evento nativo.';

  @override
  String get eventDetailUnableCreateNativeNow =>
      'Não é possível criar um evento nativo agora.';

  @override
  String get eventDetailFailedCreateNative => 'Falha ao criar evento nativo';

  @override
  String get eventDetailNativeCreatedDuplicateMarked =>
      'Evento nativo criado e evento atual marcado como duplicado.';

  @override
  String get eventDetailMarkDuplicateNativeOnlyHint =>
      'Só eventos nativos podem ser selecionados. Para criar um evento nativo a partir de um evento externo, use \"Criar evento nativo\" no menu do evento.';

  @override
  String eventDetailEventCreatedOnDateBy(String date) {
    return 'Evento criado $date por ';
  }

  @override
  String get eventDetailEventCreatedBy => 'Evento criado por ';

  @override
  String eventDetailEventCreatedOnDate(String date) {
    return 'Evento criado $date';
  }

  @override
  String eventDetailEventImportedOnDateFrom(String date) {
    return 'Evento importado $date de ';
  }

  @override
  String get eventDetailEventImportedFrom => 'Evento importado de ';

  @override
  String get eventDetailOriginalEventFallback => 'Evento original';

  @override
  String get eventDetailDuplicateBannerTitle => 'Entrada duplicada';

  @override
  String get eventDetailDuplicateBannerBody =>
      'Esta entrada está marcada como duplicado. Abre o evento principal para ver os detalhes canónicos.';

  @override
  String get eventDetailLinkedDuplicatesHeading => 'Entradas duplicadas';

  @override
  String get eventDetailMarkDuplicateStaffOnly =>
      'Só a equipa pode gerir duplicados de eventos.';

  @override
  String get eventDetailMenuHideEvent => 'Ocultar evento';

  @override
  String get eventDetailMenuHideEventSubtitle => 'Ocultar do público';

  @override
  String get eventDetailMenuUnhideEvent => 'Mostrar evento';

  @override
  String get eventDetailMenuUnhideEventSubtitle =>
      'Voltar a mostrar ao público';

  @override
  String get eventDetailHiddenBanner =>
      'Este evento está oculto ao público. Provavelmente já não existe ou não cumpre as nossas regras. Não aparecerá nas pesquisas nem no mapa.';

  @override
  String get eventDetailModeratorsOnlyHideUnhide =>
      'Só moderadores podem ocultar ou mostrar eventos.';

  @override
  String get eventDetailHideEventTitle => 'Ocultar evento';

  @override
  String get eventDetailUnhideEventTitle => 'Mostrar evento';

  @override
  String get eventDetailHideEventMessage =>
      'O evento deixa de ser visível ao público. Não aparece nas pesquisas nem no mapa, mas os dados são guardados e podem ser mostrados depois.';

  @override
  String get eventDetailUnhideEventMessage =>
      'O evento volta a ser público e aparece novamente nas pesquisas e no mapa.';

  @override
  String get eventDetailUnableHideUnhideNow =>
      'Não é possível ocultar ou mostrar este evento agora.';

  @override
  String get eventDetailEventHiddenSuccess => 'Evento ocultado com sucesso.';

  @override
  String get eventDetailEventUnhiddenSuccess => 'Evento mostrado com sucesso.';

  @override
  String get eventDetailFailedHideEvent => 'Falha ao ocultar evento';

  @override
  String get eventDetailFailedUnhideEvent => 'Falha ao mostrar evento';

  @override
  String get eventDetailMarkDuplicatePickNativeTitle =>
      'Marcar como duplicado de evento nativo';

  @override
  String get eventDetailMarkDuplicateSearchHint => 'Nome do evento, URL ou ID';

  @override
  String get eventDetailMarkDuplicateNotFoundOrInvalid =>
      'Escolhe um evento da lista ou introduz um ID válido ou um link /event/….';

  @override
  String get eventDetailMarkDuplicateTargetNotNative =>
      'Esse evento não é um evento nativo parkour.spot. Só eventos nativos podem ser o original.';

  @override
  String get eventDetailMarkDuplicateTargetIsDuplicate =>
      'Esse evento já está marcado como duplicado de outro evento.';

  @override
  String get eventDetailMarkDuplicateUseButton => 'Usar este evento';

  @override
  String get eventDetailMarkDuplicateSuggestionsHeader =>
      'Eventos nativos nestas datas';

  @override
  String get eventDetailMarkDuplicateNoSuggestions =>
      'Nenhum evento nativo encontrado numa semana das datas deste evento.';

  @override
  String eventDetailMarkDuplicateConfirmBody(String title) {
    return 'Marcar este evento como duplicado de «$title»?';
  }

  @override
  String get eventDetailMarkDuplicateSuccess =>
      'Evento marcado como duplicado.';

  @override
  String get eventDetailRemoveDuplicateConfirmBody =>
      'Remover o estado de duplicado deste evento? Deixará de apontar para outro evento como original.';

  @override
  String get eventDetailRemoveDuplicateSuccess =>
      'Estado de duplicado removido.';

  @override
  String get eventDetailCopiedToClipboard =>
      'Evento copiado para a área de transferência!';

  @override
  String eventDetailShareFailed(String error) {
    return 'Falha ao partilhar evento: $error';
  }

  @override
  String get eventDetailQuickActionSuggestPhoto => 'Sugerir foto';

  @override
  String get eventDetailQuickActionSuggestEdit => 'Sugerir edição';

  @override
  String get eventDetailUnableSuggestNow =>
      'Não é possível sugerir alterações para este evento neste momento.';

  @override
  String get eventDetailCannotSuggestForDuplicate =>
      'Não é possível sugerir alterações para eventos duplicados.';

  @override
  String get eventDetailCannotSuggestForExternal =>
      'Não é possível sugerir alterações para eventos de fontes externas. Cria primeiro um evento nativo.';

  @override
  String get eventDetailThanksPhotoSuggestion =>
      'Obrigado! A tua sugestão de fotos foi enviada para revisão.';

  @override
  String get eventDetailThanksEditSuggestion =>
      'Obrigado! A tua sugestão de edição foi enviada para revisão.';

  @override
  String get eventDetailMenuFlagDuplicate => 'Marcar como duplicado';

  @override
  String get eventDetailMenuFlagDuplicateSubtitleYes =>
      'Este evento é um duplicado';

  @override
  String get eventDetailMenuFlagDuplicateSubtitleNo =>
      'Já marcado como duplicado';

  @override
  String get eventDetailFlagDuplicateDialogTitle => 'Marcar como duplicado';

  @override
  String get eventDetailFlagDuplicateIntro =>
      'Este evento parece um duplicado de outro. Seleciona o evento original abaixo.';

  @override
  String get eventDetailFlagDuplicateWhichQuestion =>
      'De que evento é duplicado?';

  @override
  String get eventDetailFlagDuplicateSuggestionsHeader =>
      'Eventos nestas datas';

  @override
  String get eventDetailThanksDuplicateSuggestion =>
      'Obrigado! A tua sugestão de duplicado foi enviada para revisão.';

  @override
  String get eventDetailUnableFlagDuplicate =>
      'Não é possível marcar este evento como duplicado de momento.';

  @override
  String get eventDetailDuplicateReportSelectRequired =>
      'Seleciona o evento original.';

  @override
  String get eventReportQueueDuplicateSuggestion => 'Sugestão de duplicado';

  @override
  String get eventReportQueueApproveDuplicate => 'Aprovar ligação de duplicado';

  @override
  String get eventReportQueueOpenOriginalEvent =>
      'Abrir evento original sugerido';

  @override
  String get eventDuplicateApprovalExternalOriginalHint =>
      'O utilizador sugeriu um evento de uma fonte externa. Escolhe o evento nativo parkour.spot como original canónico.';

  @override
  String get eventDuplicateApprovalPickNativeTitle =>
      'Escolhe o evento nativo como original canónico.';

  @override
  String get eventDetailSuggestPhotosTitle => 'Sugerir fotos';

  @override
  String get eventDetailSuggestPhotosIntro =>
      'Carrega fotos para este evento. Os moderadores vão rever a tua sugestão.';

  @override
  String get eventDetailSuggestPhotosPickRequired =>
      'Adiciona pelo menos uma foto.';

  @override
  String get eventDetailSuggestPhotosSubmitFailed =>
      'Não foi possível enviar a sugestão de fotos. Tenta novamente.';

  @override
  String eventDetailSuggestPhotosSubmitError(String error) {
    return 'Erro ao enviar sugestão de fotos: $error';
  }

  @override
  String get eventDetailSuggestEditTitle => 'Sugerir edição';

  @override
  String get eventDetailSuggestEditIntro =>
      'Propõe atualizações para este evento. Os moderadores vão rever a tua sugestão.';

  @override
  String get eventDetailSuggestEditNoChanges =>
      'Sugere pelo menos uma alteração.';

  @override
  String get eventDetailSuggestEditSubmitFailed =>
      'Não foi possível enviar a sugestão de edição. Tenta novamente.';

  @override
  String eventDetailSuggestEditSubmitError(String error) {
    return 'Erro ao enviar sugestão de edição: $error';
  }

  @override
  String get eventSuggestionApprovalTitle => 'Rever sugestão de evento';

  @override
  String get eventSuggestionCannotApproveExternalTitle =>
      'Não é possível aprovar a sugestão';

  @override
  String eventSuggestionCannotApproveExternalBody(String sourceName) {
    return 'O evento selecionado provém de uma fonte externa ($sourceName). As sugestões só podem ser aprovadas para eventos nativos.\n\nPara aprovar esta sugestão, cria primeiro um evento nativo a partir do menu do evento.';
  }

  @override
  String get eventSuggestionCannotApproveDuplicateTitle =>
      'Não é possível aprovar a sugestão';

  @override
  String get eventSuggestionCannotApproveDuplicateBody =>
      'O evento selecionado é um duplicado de outro evento. As sugestões só podem ser aprovadas para o evento original nativo.\n\nSeleciona o evento original abaixo.';

  @override
  String get eventSuggestionTargetEventLabel => 'Evento alvo';

  @override
  String eventSuggestionCurrentEventLabel(String title) {
    return 'Evento reportado: $title';
  }

  @override
  String eventSuggestionOriginalEventLabel(String title) {
    return 'Evento original: $title';
  }

  @override
  String eventSuggestionReportedEventDuplicateSubtitle(String title) {
    return 'O evento reportado (duplicado de $title)';
  }

  @override
  String eventSuggestionReportedEventExternalSubtitle(String sourceName) {
    return 'O evento reportado (de $sourceName)';
  }

  @override
  String get eventSuggestionReportedEventSubtitle => 'O evento reportado';

  @override
  String eventSuggestionOriginalEventExternalSubtitle(String sourceName) {
    return 'O evento original (de $sourceName)';
  }

  @override
  String get eventSuggestionOriginalEventRecommendedSubtitle =>
      'O evento original (recomendado)';

  @override
  String get eventSuggestionModeratorNotesLabel => 'Comentário (opcional)';

  @override
  String get eventSuggestionModeratorNotesHint =>
      'Documenta por que motivo aprovaste ou rejeitaste esta sugestão…';

  @override
  String get eventSuggestionApproveButton => 'Aprovar sugestão';

  @override
  String get eventSuggestionApprovalFailed =>
      'Não foi possível aprovar esta sugestão de evento.';

  @override
  String eventSuggestionApprovalSuccess(String eventId) {
    return 'Aprovada e aplicada ao evento $eventId.';
  }

  @override
  String get eventSuggestionChangedFieldsTitle => 'Alterações sugeridas';

  @override
  String get eventSuggestionLocationRemoved => 'Remover localização';

  @override
  String eventSuggestionLinkedSpotsCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count spots associados',
      one: '1 spot associado',
      zero: 'Sem spots associados',
    );
    return '$_temp0';
  }
}
