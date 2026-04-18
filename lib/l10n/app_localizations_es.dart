// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Spanish Castilian (`es`).
class AppLocalizationsEs extends AppLocalizations {
  AppLocalizationsEs([String locale = 'es']) : super(locale);

  @override
  String get tabExplore => 'Explorar';

  @override
  String get tabAddSpot => 'Añadir spot';

  @override
  String get tabAccount => 'Cuenta';

  @override
  String get profileSettingsTitle => 'Ajustes';

  @override
  String get profileSettingsSubtitle => 'Idioma y lugares de tu interés';

  @override
  String get profileSettingsLanguageLabel => 'Idioma';

  @override
  String get profileSettingsLanguageDescription =>
      'Elige un idioma o usa el de tu dispositivo.';

  @override
  String get profileLanguageSystemDefault => 'Idioma del dispositivo';

  @override
  String get profileLoadErrorDefault => 'No se pudo cargar el perfil.';

  @override
  String get profileRefreshPage => 'Actualizar página';

  @override
  String get profileRetry => 'Reintentar';

  @override
  String get profileSignInTitle => 'Inicia sesión para acceder a tu cuenta';

  @override
  String get profileSignInSubtitle =>
      'Inicia sesión para gestionar tus spots y valorar lugares.';

  @override
  String get profileSignInButton => 'Iniciar sesión';

  @override
  String get profileOrDivider => 'O';

  @override
  String get profileCreateAccount => 'Crear una cuenta';

  @override
  String get profileDefaultDisplayName => 'Usuario';

  @override
  String get profileViewEditSubtitle => 'Ver y editar tu perfil';

  @override
  String get notificationsTitle => 'Notificaciones';

  @override
  String get notificationsSubtitle =>
      'Spots nuevos cerca, gente entrenando y otras novedades para ti';

  @override
  String get notificationsEmptyTitle => 'Por aquí está tranquilo';

  @override
  String get notificationsEmptyBody =>
      'Cuando alguien añada un spot cerca o haga check-in donde entrenas, lo verás aquí.';

  @override
  String get notificationsLoadError =>
      'No pudimos cargar tus notificaciones. Comprueba la conexión e inténtalo de nuevo.';

  @override
  String get notificationsRetry => 'Reintentar';

  @override
  String get notificationsOpenFailedSnackbar =>
      'No se pudo abrir esta notificación. Inténtalo más tarde.';

  @override
  String get notificationsMarkAllRead => 'Marcar todas como leídas';

  @override
  String get notificationsMarkAllReadFailed =>
      'No se pudieron marcar todas como leídas. Inténtalo de nuevo.';

  @override
  String get notificationsMarkAsReadFailed =>
      'No se pudo marcar como leída. Inténtalo de nuevo.';

  @override
  String get notificationsMarkAsUnreadFailed =>
      'No se pudo marcar como no leída. Inténtalo de nuevo.';

  @override
  String get notificationsMarkAsUnreadHint =>
      'Mantén pulsado para marcar como no leída';

  @override
  String get notificationsMarkAsReadHint =>
      'Mantén pulsado para marcar como leída';

  @override
  String get notificationsShowAll => 'Mostrar todas';

  @override
  String get notificationsUnreadOnly => 'Solo no leídas';

  @override
  String get notificationsEmptyFilteredTitle => 'Estás al día';

  @override
  String get notificationsEmptyFilteredBody =>
      'No hay notificaciones sin leer ahora mismo.';

  @override
  String get notificationsTimeUnknown => 'Recientemente';

  @override
  String notificationsOpenSemantic(String title) {
    return 'Abrir notificación: $title';
  }

  @override
  String get notificationsActorSomeone => 'Alguien';

  @override
  String get notificationsSpotUntitled => 'Spot sin título';

  @override
  String notificationNearbyNewSpotTitle(String spotName) {
    return 'Nuevo spot cerca: $spotName';
  }

  @override
  String notificationNearbyNewSpotBody(String actorName) {
    return '$actorName ha añadido un nuevo spot de parkour cerca de uno de tus lugares guardados.';
  }

  @override
  String notificationNearbyCheckInTitle(String actorName, String spotName) {
    return '$actorName está entrenando ahora en $spotName';
  }

  @override
  String get notificationNearbyCheckInBody =>
      'Acaba de hacer check-in en este spot.';

  @override
  String get profileModeratorSectionTitle => 'Moderador';

  @override
  String get profileModeratorToolsTitle => 'Herramientas de moderación';

  @override
  String get profileModeratorToolsSubtitle =>
      'Revisar y resolver informes de spots';

  @override
  String get profileAdminSectionTitle => 'Administrador';

  @override
  String get profileAdminToolsTitle => 'Herramientas de administración';

  @override
  String get profileAdminToolsSubtitle =>
      'Gestionar fuentes y tareas administrativas';

  @override
  String get profileSignOut => 'Cerrar sesión';

  @override
  String get profileSignOutMessage => '¿Seguro que quieres cerrar sesión?';

  @override
  String get profileCancel => 'Cancelar';

  @override
  String get profileLocationAlertsTitle => 'Alertas de ubicación';

  @override
  String get profileNotificationSettingsTitle =>
      'Configuración de notificaciones';

  @override
  String get profileLocationAlertsDescription =>
      'Controla qué ubicaciones se usan para alertas cercanas, como check-ins, spots nuevos y futuros eventos.';

  @override
  String get profileLocationAlertsShareLastKnownTitle =>
      'Usar la última ubicación conocida';

  @override
  String get profileLocationAlertsShareLastKnownSubtitle =>
      'Guarda la última ubicación conocida de tu dispositivo en la nube para que coincidan las alertas cercanas.';

  @override
  String get profileLocationAlertsNotifyNewSpotsTitle =>
      'Avisarme sobre spots nuevos cerca';

  @override
  String get profileLocationAlertsNotifyNewSpotsSubtitle =>
      'Recibe una notificación en la app cuando alguien añade un spot a unos 5 km de un lugar guardado activo o de tu última ubicación conocida.';

  @override
  String get profileLocationAlertsNotifyNearbyCheckInsTitle =>
      'Avisarme sobre check-ins cercanos';

  @override
  String get profileLocationAlertsNotifyNearbyCheckInsSubtitle =>
      'Recibe una notificación en la app cuando alguien haga check-in en un spot a unos 5 km de un lugar guardado activo o de tu última ubicación conocida.';

  @override
  String get profileLocationAlertsSavedLocationsTitle =>
      'Mis lugares de interés';

  @override
  String get profileLocationAlertsAddLocationButton => 'Añadir';

  @override
  String get profileLocationAlertsNoLocationsEnabledWarning =>
      'No recibirás notificaciones basadas en la ubicación hasta que actives «Usar la última ubicación conocida» o al menos un lugar guardado.';

  @override
  String get profileLocationAlertsEmptyState =>
      'Aún no hay lugares guardados. Añade sitios como Casa o Trabajo.';

  @override
  String get profileLocationAlertsDefaultLabel => 'Lugar guardado';

  @override
  String get profileLocationAlertsDisableTooltip => 'Desactivar';

  @override
  String get profileLocationAlertsEnableTooltip => 'Activar';

  @override
  String get profileLocationAlertsEditTooltip => 'Editar';

  @override
  String get profileLocationAlertsDeleteTooltip => 'Eliminar';

  @override
  String get profileLocationAlertsDeleteTitle => '¿Eliminar lugar guardado?';

  @override
  String profileLocationAlertsDeleteMessage(String label) {
    return '¿Seguro que quieres eliminar $label?';
  }

  @override
  String get profileLocationAlertsDeleteConfirmButton => 'Eliminar';

  @override
  String get profileLocationAlertsDialogAddTitle => 'Añadir lugar';

  @override
  String get profileLocationAlertsDialogEditTitle => 'Editar lugar';

  @override
  String get profileLocationAlertsLabelFieldLabel => 'Etiqueta';

  @override
  String get profileLocationAlertsLabelFieldPlaceholder => 'Casa';

  @override
  String get profileLocationAlertsEnabledLabel => 'Activado';

  @override
  String get profileLocationAlertsLabelRequired => 'Introduce una etiqueta';

  @override
  String get profileLocationAlertsLocationRequired =>
      'Elige una ubicación en el mapa';

  @override
  String get profileAboutIntro =>
      'Parkour·Spot es una aplicación comunitaria para descubrir y compartir spots de parkour y freerunning en todo el mundo. Queremos que sea fácil encontrar buenos lugares para entrenar.';

  @override
  String get profileReadMore => 'Leer más';

  @override
  String get profileAboutStoryBeforeName => 'Iniciada por ';

  @override
  String get profileAboutStoryAfterName =>
      ' desde la comunidad de parkour de Utrecht, la app reúne conocimiento local de mapas urbanos y regionales existentes—ya estuvieran en Facebook, Instagram, webs o apps retiradas—para que los buenos datos de spots no se pierdan.';

  @override
  String get profileAboutMapMission =>
      'Este es tu mapa. Añade nuevos spots, valora los existentes y enriquece las fichas con detalles. Cuanto más contribuimos, más fuerte es el conocimiento compartido de la comunidad.';

  @override
  String get profileAboutPrinciplesHeader => 'Nuestros principios:';

  @override
  String get profileAboutPrincipleTransparency =>
      '• Transparencia: puedes explorar la app sin cuenta, y cada spot muestra qué fuentes externas han contribuido.';

  @override
  String get profileAboutPrinciplePortability =>
      '• Portabilidad: estamos creando herramientas de exportación para que los datos de spots se usen más allá de la app.';

  @override
  String get profileAboutPrincipleOpenSource =>
      '• Código abierto: la app es de la comunidad, no depende de una sola persona.';

  @override
  String get profileAboutEnjoy =>
      'Disfruta descubriendo y compartiendo spots con Parkour.spot. ¿Preguntas o ideas? Toca contacto—nos encantará saber de ti.';

  @override
  String get profileCreditsBy => 'Grandes contribuciones de ';

  @override
  String get profileCreditsDaphneArt => ' (arte), ';

  @override
  String get profileCreditsComma => ', ';

  @override
  String get profileCreditsEnd => ' y muchas otras personas.';

  @override
  String get profileViewSourceCode => 'Ver código fuente';

  @override
  String get profileContactUs => 'Contacto';

  @override
  String get profileReportIssue => 'Informar de un problema';

  @override
  String get profileHelpTranslate => 'Ayuda a traducir la app';

  @override
  String get profileInstallBannerTitle => 'Instala la app Parkour·Spot';

  @override
  String get profileInstallBannerSubtitle => 'Obtén la experiencia completa';

  @override
  String get profileInstallDialogTitle => 'Instalar Parkour·Spot';

  @override
  String profileInstallIntro(String device) {
    return 'Para instalar Parkour·Spot en tu $device:';
  }

  @override
  String get profileInstallDeviceIphone => 'iPhone';

  @override
  String get profileInstallDeviceAndroid => 'dispositivo Android';

  @override
  String get profileInstallIosStep1 =>
      'Toca el botón Compartir en la parte inferior de la pantalla';

  @override
  String get profileInstallIosStep2 =>
      'Desplázate y toca «Añadir a la pantalla de inicio»';

  @override
  String get profileInstallIosStep3 =>
      'Toca «Añadir» en la esquina superior derecha';

  @override
  String get profileInstallIosStep4 =>
      '¡La app aparecerá en tu pantalla de inicio!';

  @override
  String get profileInstallAndroidStep1 =>
      'Toca el menú Más (⋯) arriba a la derecha';

  @override
  String get profileInstallAndroidStep2 =>
      'Toca «Añadir a la pantalla de inicio»';

  @override
  String get profileInstallAndroidStep3 => 'Toca «Instalar aplicación»';

  @override
  String get profileInstallAndroidStep4 =>
      '¡La app aparecerá en tu pantalla de inicio!';

  @override
  String get profileInstallGotIt => 'Entendido';

  @override
  String get exploreMetaDefaultTitle => 'Parkour·Spot';

  @override
  String get exploreMetaDefaultDescription =>
      'Descubre, mapea y comparte los mejores spots de parkour en todo el mundo con fotos de la comunidad, valoraciones y consejos locales para tu próximo entrenamiento.';

  @override
  String exploreMetaTitleCityCountry(String city, String country) {
    return 'Mejores spots de parkour en $city, $country';
  }

  @override
  String exploreMetaDescriptionCityCountry(String city, String country) {
    return 'Descubre los mejores spots de parkour en $city, $country. Encuentra lugares para entrenar, comparte tus favoritos y conecta con la comunidad.';
  }

  @override
  String exploreMetaTitleCountry(String country) {
    return 'Mejores spots de parkour en $country';
  }

  @override
  String exploreMetaDescriptionCountry(String country) {
    return 'Descubre los mejores spots de parkour en $country. Encuentra lugares para entrenar, comparte tus favoritos y conecta con la comunidad.';
  }

  @override
  String get exploreAddSpotTitle => 'Añadir nuevo spot';

  @override
  String get exploreAddSpotSubtitle =>
      'Comparte tus spots de parkour favoritos con la comunidad';

  @override
  String get exploreSignInToAddSpot => 'Inicia sesión para añadir un spot';

  @override
  String get exploreLoadingProfile => 'Cargando tu perfil…';

  @override
  String get exploreSearchHint => 'Buscar ubicación o spot…';

  @override
  String get exploreFilterBy => 'Filtrar por';

  @override
  String get exploreFilterAmenities => 'Servicios';

  @override
  String get exploreFilterSources => 'Fuentes';

  @override
  String get exploreSpotAccessTitle => 'Acceso al spot';

  @override
  String get exploreSpotAccessSubtitle => 'Filtra spots por nivel de acceso';

  @override
  String get exploreFilterAny => 'Cualquiera';

  @override
  String get exploreSpotFacilitiesTitle => 'Instalaciones del spot';

  @override
  String get exploreSpotFacilitiesSubtitle =>
      'Mostrar spots con estas comodidades';

  @override
  String get exploreAttributesTitle => 'Con cualquiera de estos atributos';

  @override
  String get exploreAttributesSubtitle =>
      'Filtra spots que tengan alguna de las habilidades o características seleccionadas';

  @override
  String get exploreGoodForSegment => 'Ideal para';

  @override
  String get exploreSpotFeaturesSegment => 'Características del spot';

  @override
  String get exploreSpotSourceLabel => 'Fuente del spot';

  @override
  String get exploreSourcesLoadError => 'No se pudieron cargar las fuentes';

  @override
  String get exploreAllSources => 'Todas las fuentes';

  @override
  String get exploreParkourSpotNative => 'Parkour·Spot (nativo)';

  @override
  String get exploreAllFolders => 'Todas las carpetas';

  @override
  String exploreLocationError(String error) {
    return 'Error al obtener la ubicación: $error';
  }

  @override
  String get exploreCurrentLocationSnackbar => 'Esta es tu ubicación actual';

  @override
  String get exploreCloseTooltip => 'Cerrar';

  @override
  String get exploreClearSearchTooltip => 'Borrar';

  @override
  String get exploreFiltersTooltip => 'Filtros';

  @override
  String get exploreFindingLocation => 'Buscando ubicación…';

  @override
  String get exploreAddSpotHereTitle => '¿Añadir un spot en esta ubicación?';

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
    return ' ($count mejores mostrados)';
  }

  @override
  String get exploreNoSpotsSearch => 'No se encontraron spots';

  @override
  String get exploreNoSpotsArea => 'No hay spots en esta zona';

  @override
  String get exploreNoSpotsSearchHint =>
      'Prueba a ajustar los términos de búsqueda';

  @override
  String get exploreNoSpotsMapHint => 'Mueve el mapa para explorar otras zonas';

  @override
  String get exploreRefreshMapTooltip => 'Actualizar spots en la vista actual';

  @override
  String get exploreSwitchToMap => 'Ver mapa';

  @override
  String get exploreSwitchToSatellite => 'Ver satélite';

  @override
  String get exploreLocationPermissionDenied => 'Permiso de ubicación denegado';

  @override
  String get exploreCenterOnMyLocation => 'Centrar en mi ubicación';

  @override
  String get exploreFiltersDialogTitle => 'Filtros';

  @override
  String get exploreClearFilters => 'Borrar';

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
      'No se pudieron elegir las imágenes. Inténtalo de nuevo.';

  @override
  String get addSpotTakePhotoFailed =>
      'No se pudo hacer la foto. Inténtalo de nuevo.';

  @override
  String get addSpotNeedPhoto => 'Sube al menos una foto del spot';

  @override
  String get addSpotNeedLocation =>
      'Espera a que se determine la ubicación o elige un punto en el mapa';

  @override
  String addSpotCreateError(String error) {
    return 'Error al crear el spot: $error';
  }

  @override
  String get addSpotNameLabel => 'Nombre del spot *';

  @override
  String get addSpotNameRequired => 'Introduce un nombre para el spot';

  @override
  String get addSpotDescriptionLabel => 'Descripción *';

  @override
  String get addSpotDescriptionRequired => 'Introduce una descripción';

  @override
  String get addSpotDescriptionMinLength =>
      'La descripción debe tener al menos 10 caracteres';

  @override
  String get addSpotCreating => 'Creando spot…';

  @override
  String get addSpotCreateButton => 'Crear spot';

  @override
  String get addSpotLocationSectionTitle => 'Elige la ubicación del spot';

  @override
  String get addSpotGettingLocation => 'Obteniendo tu ubicación…';

  @override
  String get addSpotLocationNotAvailable => 'Ubicación no disponible';

  @override
  String get addSpotPickLocationHint => 'Elegir ubicación';

  @override
  String get addSpotImagesSectionTitle => 'Elige imágenes del spot';

  @override
  String get addSpotGalleryButton => 'Galería';

  @override
  String get addSpotCameraButton => 'Cámara';

  @override
  String get addSpotGoodForTitle => 'Ideal para';

  @override
  String get addSpotGoodForSubtitle =>
      '¿Qué habilidades de parkour se pueden practicar aquí?';

  @override
  String get addSpotFeaturesTitle => 'Características del spot';

  @override
  String get addSpotFeaturesSubtitle =>
      '¿Qué características físicas tiene este spot?';

  @override
  String get addSpotAccessTitle => 'Acceso al spot';

  @override
  String get addSpotAccessSubtitle =>
      '¿Cuál es el nivel de acceso a este spot?';

  @override
  String get addSpotFacilitiesFormTitle => 'Instalaciones del spot';

  @override
  String get addSpotFacilitiesSubtitle => '¿Qué servicios hay en este spot?';

  @override
  String get addSpotLongPressHintSkill =>
      'Mantén pulsada una habilidad para más información';

  @override
  String get addSpotLongPressHintFeature =>
      'Mantén pulsada una característica para más información';

  @override
  String get addSpotLongPressHintFacility =>
      'Mantén pulsada una instalación para más información';

  @override
  String get addSpotPickLocationAppBarTitle => 'Elegir ubicación';

  @override
  String get addSpotTipLongPressMobile =>
      'Consejo: también puedes añadir spots desde el mapa Explorar manteniendo pulsado un lugar.';

  @override
  String get addSpotTipRightClickDesktop =>
      'Consejo: también puedes añadir spots desde el mapa Explorar haciendo clic derecho en un lugar.';

  @override
  String get addSpotUseThisLocation => 'Usar esta ubicación';

  @override
  String get addSpotDirectionsTooltip => 'Indicaciones';

  @override
  String get addSpotGettingAddress => 'Obteniendo dirección…';

  @override
  String get spotCardNoImages => 'Sin imágenes';

  @override
  String get spotCardNoDescription => 'Aún sin descripción';

  @override
  String get spotCardPartOfPrefix => 'Parte de ';

  @override
  String get spotCardRemoveFromListTooltip => 'Quitar de la lista';

  @override
  String get spotCardCopiedToClipboard => '¡Spot copiado al portapapeles!';

  @override
  String spotCardShareFailed(String error) {
    return 'No se pudo compartir el spot: $error';
  }

  @override
  String spotCardShareClipboardText(String name, String url) {
    return '$name 👉 $url';
  }

  @override
  String get spotCardRemovedFromSource => 'Eliminado de la fuente';

  @override
  String get spotCheckInUnnamedPerson => 'Esta persona';

  @override
  String spotCheckInTooltipPublic(String name, String time) {
    return '$name está aquí ahora hasta las $time';
  }

  @override
  String spotCheckInTooltipPrivate(String time) {
    return 'Estás aquí ahora hasta las $time — solo tú ves este check-in';
  }

  @override
  String spotTrainingPlanTooltipPublic(String name, String timeRange) {
    return '$name planea entrenar aquí $timeRange';
  }

  @override
  String spotTrainingPlanTooltipPrivate(String timeRange) {
    return 'Planeas entrenar aquí $timeRange — solo tú ves este plan';
  }

  @override
  String get spotDetailRouteErrorLoading => 'Error al cargar el spot';

  @override
  String get spotDetailRouteTryAgainLater => 'Inténtalo de nuevo más tarde';

  @override
  String get spotDetailRouteNotFound => 'Spot no encontrado';

  @override
  String get spotDetailRouteGoToExplore => 'Ir a Explorar';

  @override
  String get spotDetailCheckInVerifyFailed =>
      'No se pudieron verificar tus check-ins';

  @override
  String get spotDetailCheckInEndPreviousFailed =>
      'No se pudo terminar el check-in anterior';

  @override
  String get spotDetailCheckInSuccess => 'Has hecho check-in';

  @override
  String get spotDetailCheckInFailed => 'Check-in fallido';

  @override
  String get spotDetailCheckInRemoved => 'Check-in eliminado';

  @override
  String get spotDetailCheckInDeleteFailed => 'No se pudo eliminar el check-in';

  @override
  String get spotDetailCheckInUpdated => 'Check-in actualizado';

  @override
  String get spotDetailCheckInUpdateFailed =>
      'No se pudo actualizar el check-in';

  @override
  String get spotDetailCheckInFabTooltipSignIn =>
      'Inicia sesión para hacer check-in';

  @override
  String get spotDetailCheckInFabTooltipEdit => 'Editar check-in';

  @override
  String get spotDetailCheckInFabTooltipCheckIn => 'Check-in';

  @override
  String spotDetailSpotCreatedOnDateBy(String date) {
    return 'Spot creado $date por ';
  }

  @override
  String get spotDetailSpotCreatedBy => 'Spot creado por ';

  @override
  String get spotDetailUnknownSource => 'Fuente desconocida';

  @override
  String spotDetailSpotImportedOnDateFrom(String date) {
    return 'Spot importado $date desde ';
  }

  @override
  String get spotDetailSpotImportedFrom => 'Spot importado desde ';

  @override
  String get spotDetailFromFolder => ' de la carpeta ';

  @override
  String get spotDetailImprovedByAfterComma => ', mejorado por ';

  @override
  String get spotDetailImprovedByAfterAnd => ' y mejorado por ';

  @override
  String get spotDetailUnknownUser => 'Desconocido';

  @override
  String get spotDetailListJoinAnd => ' y ';

  @override
  String get spotDetailListJoinComma => ', ';

  @override
  String spotDetailLastUpdatedAfterCommaAnd(String date) {
    return ', y actualizado por última vez $date.';
  }

  @override
  String spotDetailLastUpdatedAfterAnd(String date) {
    return ' y actualizado por última vez $date.';
  }

  @override
  String get spotDetailDateToday => 'hoy';

  @override
  String get spotDetailDateYesterday => 'ayer';

  @override
  String get communityDateTomorrow => 'mañana';

  @override
  String communityActivityTrainSameDay(
    String startTime,
    String endTime,
    String day,
  ) {
    return 'De $startTime a $endTime $day';
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
  String spotDetailDateDaysAgo(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Hace $count días',
      one: 'Hace 1 día',
    );
    return '$_temp0';
  }

  @override
  String spotDetailDateWeeksAgo(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Hace $count semanas',
      one: 'Hace 1 semana',
    );
    return '$_temp0';
  }

  @override
  String spotDetailDateMonthsAgo(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Hace $count meses',
      one: 'Hace 1 mes',
    );
    return '$_temp0';
  }

  @override
  String spotDetailDateYearsAgo(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Hace $count años',
      one: 'Hace 1 año',
    );
    return '$_temp0';
  }

  @override
  String spotDetailCopySpotFailed(String error) {
    return 'No se pudo copiar el spot: $error';
  }

  @override
  String get spotDetailAddressCopiedToClipboard =>
      '¡Dirección copiada al portapapeles!';

  @override
  String spotDetailCopyAddressFailed(String error) {
    return 'No se pudo copiar la dirección: $error';
  }

  @override
  String spotDetailOpenMapsFailed(String error) {
    return 'No se pudo abrir la app de mapas: $error';
  }

  @override
  String get spotDetailMoreActionsTooltip => 'Más acciones';

  @override
  String get spotDetailMenuLogin => 'Iniciar sesión';

  @override
  String get spotDetailMenuLoginSubtitle =>
      'Inicia sesión primero para vincular cambios a tu cuenta';

  @override
  String get spotDetailMenuFlagDuplicate => 'Marcar como duplicado';

  @override
  String get spotDetailMenuFlagDuplicateSubtitleYes =>
      'Este spot es un duplicado';

  @override
  String get spotDetailMenuFlagDuplicateSubtitleNo =>
      'Ya marcado como duplicado';

  @override
  String get spotDetailMenuSuggestPhoto => 'Sugerir foto';

  @override
  String get spotDetailMenuSuggestPhotoSubtitleYes =>
      'Enviar fotos para este spot';

  @override
  String get spotDetailMenuSuggestPhotoSubtitleNo =>
      'No se pueden sugerir fotos en duplicados';

  @override
  String get spotDetailMenuSuggestEdit => 'Sugerir edición';

  @override
  String get spotDetailMenuSuggestEditSubtitleYes =>
      'Proponer cambios en este spot';

  @override
  String get spotDetailMenuSuggestEditSubtitleNo =>
      'No se pueden sugerir ediciones en duplicados';

  @override
  String get spotDetailMenuReportSpot => 'Reportar spot';

  @override
  String get spotDetailMenuReportSpotSubtitle => 'Ayúdanos a revisar este spot';

  @override
  String get spotDetailMenuEditSpot => 'Editar spot';

  @override
  String get spotDetailMenuEditSpotSubtitleNative =>
      'Crea primero un spot nativo';

  @override
  String get spotDetailMenuEditSpotSubtitleMod => 'Solo moderadores';

  @override
  String get spotDetailMenuMarkDuplicate => 'Marcar como duplicado';

  @override
  String get spotDetailMenuMarkDuplicateSubtitleDup =>
      'Ya marcado como duplicado';

  @override
  String get spotDetailMenuMarkDuplicateSubtitleMod => 'Solo moderadores';

  @override
  String get spotDetailMenuRemoveDuplicateStatus =>
      'Quitar estado de duplicado';

  @override
  String get spotDetailMenuCreateNative => 'Crear spot nativo';

  @override
  String get spotDetailMenuHideSpot => 'Ocultar spot';

  @override
  String get spotDetailMenuUnhideSpot => 'Mostrar spot';

  @override
  String get spotDetailMenuDeleteSpot => 'Eliminar spot';

  @override
  String get spotDetailMenuDeleteSubtitleAdmin => 'Solo administradores';

  @override
  String get spotDetailMenuTriggerResize => 'Activar redimensionado de imagen';

  @override
  String get spotDetailMenuTriggerResizeSubtitle =>
      'Volver a crear versiones redimensionadas';

  @override
  String get spotDetailExternalSourceCannotEdit =>
      'Los spots de fuentes externas no se pueden editar. Crea primero un spot nativo con «Marcar como duplicado» → «Crear spot nativo».';

  @override
  String get spotDetailOk => 'OK';

  @override
  String get spotDetailUnableEditNow => 'No se puede editar este spot ahora.';

  @override
  String get spotDetailOnlyAdminsDelete =>
      'Solo los administradores pueden eliminar spots.';

  @override
  String get spotDetailResizeAllHaveVersions =>
      'Todas las imágenes ya tienen versiones redimensionadas';

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
    return ', $failed fallidos';
  }

  @override
  String spotDetailResizeTriggerFailed(String error) {
    return 'No se pudo iniciar el redimensionado: $error';
  }

  @override
  String get spotDetailUnableFlagDuplicate =>
      'No se puede marcar este spot como duplicado ahora.';

  @override
  String get spotDetailThanksDuplicateReport =>
      '¡Gracias! Tu reporte de duplicado se ha enviado.';

  @override
  String get spotDetailUnableSuggestPhotos =>
      'No se pueden sugerir fotos para este spot ahora.';

  @override
  String get spotDetailCannotSuggestPhotosDuplicate =>
      'No se pueden sugerir fotos en spots duplicados.';

  @override
  String get spotDetailThanksPhotoSuggestion =>
      '¡Gracias! Tu sugerencia de foto se ha enviado para revisión.';

  @override
  String get spotDetailUnableSuggestEdits =>
      'No se pueden sugerir ediciones para este spot ahora.';

  @override
  String get spotDetailCannotSuggestEditsDuplicate =>
      'No se pueden sugerir ediciones en spots duplicados.';

  @override
  String get spotDetailThanksEditSuggestion =>
      '¡Gracias! Tu sugerencia de edición se ha enviado para revisión.';

  @override
  String get spotDetailUnableReportNow =>
      'No se puede reportar este spot ahora.';

  @override
  String get spotDetailThanksReportSubmitted =>
      '¡Gracias! Tu reporte se ha enviado.';

  @override
  String get spotDetailUnableAddToList =>
      'No se puede añadir este spot a una lista ahora.';

  @override
  String get spotDetailNoSpotListsAccess =>
      'No tienes acceso a las listas de spots.';

  @override
  String get spotDetailListCreatedAndAdded => '¡Lista creada y spot añadido!';

  @override
  String get spotDetailSpotAddedToList => '¡Spot añadido a la lista!';

  @override
  String get spotDetailEditReportTooltip => 'Editar y reportar';

  @override
  String get spotDetailShareTooltip => 'Compartir';

  @override
  String get spotDetailQuickActionSave => 'Guardar';

  @override
  String get spotDetailQuickActionEdit => 'Editar';

  @override
  String get spotDetailQuickActionShare => 'Compartir';

  @override
  String get spotDetailQuickActionRate => 'Valorar';

  @override
  String get spotDetailRatingTooltip =>
      'Valoración de la comunidad y tus estrellas';

  @override
  String get spotDetailPresenceHereNow => 'Aquí ahora';

  @override
  String get spotDetailCommunitySectionTitle => 'Comunidad';

  @override
  String get spotDetailCommunitySectionSubtitle =>
      'Mira quién entrena o planea entrenar aquí, y comparte tu sesión.';

  @override
  String get spotDetailCommunityNobodyHere =>
      'Nadie ha hecho check-in aún. Haz check-in para que otros sepan que estás aquí.';

  @override
  String get spotDetailCommunityNobodyHereShort => 'Nadie por aquí aún.';

  @override
  String get spotDetailCommunityNobodySocialShort =>
      'Nadie aquí ni con plan aún.';

  @override
  String get spotDetailCommunityActivityLoadError =>
      'No se pudo cargar la actividad.';

  @override
  String get spotDetailCommunityActivityEmpty => 'Nada que mostrar ahora.';

  @override
  String get spotDetailCommunityViewAll => 'Ver todos';

  @override
  String get spotDetailCommunityCheckInButton => 'Check-in';

  @override
  String get spotDetailCommunityEditCheckInButton => 'Editar check-in';

  @override
  String get spotDetailCommunitySignInToCheckInButton =>
      'Inicia sesión para hacer check-in';

  @override
  String get spotDetailCommunityPlanningVisitButton => 'Planear entreno';

  @override
  String get spotDetailCommunityPlanningVisitTooltip =>
      'Indica cuándo entrenarás aquí.';

  @override
  String get spotDetailCommunityCheckInButtonTooltip =>
      'Muestra a otros que estás aquí ahora.';

  @override
  String get spotDetailCommunityEditCheckInButtonTooltip =>
      'Actualizar tu check-in.';

  @override
  String get spotDetailCommunitySignInToCheckInButtonTooltip =>
      'Inicia sesión para hacer check-in.';

  @override
  String get spotDetailCommunityPlanningToTrain => 'Planeando entrenar';

  @override
  String get spotDetailCommunityNobodyPlanningShort => 'Aún no hay planes.';

  @override
  String get spotDetailCommunitySignInToPlanButton =>
      'Inicia sesión para planear';

  @override
  String get spotDetailCommunityEditTrainingPlanButton => 'Editar plan';

  @override
  String get spotCheckInDialogTitle => 'Check-in';

  @override
  String get spotCheckInDialogTitleEdit => 'Editar check-in';

  @override
  String get spotCheckInDialogIntroNew =>
      'Indica que estás entrenando aquí y más o menos hasta cuándo. Si lo compartes en público, apareces en la comunidad de este spot hasta esa hora de fin.';

  @override
  String get spotCheckInDialogIntroEdit =>
      'Cambia llegada y salida, quién puede ver el check-in y tu nota.';

  @override
  String get spotDetailSessionNoteLabel => 'Nota (opcional)';

  @override
  String get spotDetailSessionNoteHint => 'p. ej. habilidades o ejercicios';

  @override
  String get spotTrainingPlanDialogTitle => 'Planear entreno aquí';

  @override
  String get spotTrainingPlanDialogTitleEdit => 'Editar plan de entreno';

  @override
  String get spotTrainingPlanDialogBody =>
      'Define cuándo empiezas y terminas. Los planes públicos aparecen en la comunidad de este spot junto a otras personas que comparten.';

  @override
  String get spotTrainingPlanDialogSharePublic => 'Compartir en público';

  @override
  String get spotTrainingPlanDialogShareSub =>
      'Desactívalo para que solo tú veas el plan.';

  @override
  String get spotTrainingPlanDialogStartLabel => 'Empieza';

  @override
  String get spotTrainingPlanDialogEndLabel => 'Termina';

  @override
  String get spotTrainingPlanDialogSave => 'Guardar';

  @override
  String get spotTrainingPlanDialogCancel => 'Cancelar';

  @override
  String get spotTrainingPlanDialogDelete => 'Quitar plan';

  @override
  String get spotTrainingPlanDialogDeleteTitle => '¿Quitar este plan?';

  @override
  String get spotTrainingPlanDialogDeleteBody =>
      'Puedes crear un plan nuevo cuando quieras.';

  @override
  String get spotTrainingPlanValidationOrder =>
      'La hora de fin debe ser posterior al inicio.';

  @override
  String get spotTrainingPlanValidationMinDuration => 'Mínimo 15 minutos.';

  @override
  String get spotTrainingPlanValidationMaxDuration => 'Como máximo 12 horas.';

  @override
  String get spotTrainingPlanValidationStartTooFar =>
      'El inicio no puede ser más de 30 días adelante.';

  @override
  String get spotTrainingPlanValidationEndNotFuture =>
      'La hora de fin debe estar en el futuro.';

  @override
  String get spotTrainingPlanValidationInvalid => 'Rango de tiempo no válido.';

  @override
  String get spotDetailTrainingPlanSaved => 'Plan de entreno guardado';

  @override
  String get spotDetailTrainingPlanUpdated => 'Plan de entreno actualizado';

  @override
  String get spotDetailTrainingPlanFailed => 'No se pudo guardar el plan';

  @override
  String get spotDetailTrainingPlanRemoved => 'Plan de entreno eliminado';

  @override
  String get spotDetailTrainingPlanDeleteFailed =>
      'No se pudo eliminar el plan';

  @override
  String get spotTrainingPlanListDialogTitle => 'Planeando entrenar';

  @override
  String get spotTrainingPlanListDialogSubtitle =>
      'Personas con plan público en este spot.';

  @override
  String get spotTrainingPlanListDialogClose => 'Cerrar';

  @override
  String get spotTrainingPlanListEmpty => 'Aún no hay planes públicos.';

  @override
  String get spotTrainingPlanListLoadError =>
      'No se pudieron cargar los planes';

  @override
  String get spotTrainingPlanEditMine => 'Editar plan';

  @override
  String get spotTrainingPlanOnlyYou => 'Solo tú';

  @override
  String get spotTrainingPlanUnnamedPerson => 'Alguien';

  @override
  String spotTrainingPlanTimeRange(String start, String end) {
    return '$start – $end';
  }

  @override
  String get spotDetailHiddenBanner =>
      'Este spot está oculto al público. Probablemente ya no existe o no cumple nuestras normas. No aparecerá en búsquedas ni en el mapa.';

  @override
  String spotDetailSourceRemovedBanner(String source) {
    return 'Este spot ya no figura en $source. Los datos pueden estar desactualizados: comprueba antes de ir.';
  }

  @override
  String get spotDetailSourceRemovedUnknownSource => 'su fuente original';

  @override
  String get spotDetailSectionFeatures => 'Características';

  @override
  String get spotDetailSectionAccess => 'Acceso';

  @override
  String get spotDetailSectionFacilities => 'Instalaciones';

  @override
  String spotDetailJumpflixFetchFailed(String error) {
    return 'Error al obtener Jumpflix: $error';
  }

  @override
  String get spotDetailBrandYoutube => 'YouTube';

  @override
  String get spotDetailBrandJumpflix => 'Jumpflix';

  @override
  String get spotDetailBrandAsSeenIn => 'Como en';

  @override
  String get spotDetailLoading => 'Cargando…';

  @override
  String get spotDetailLoadingYourRating => 'Cargando tu valoración…';

  @override
  String get spotDetailRateThisSpot => 'Valora este spot';

  @override
  String get spotDetailHeaderNoRatingsYet => 'Sin valoraciones aún';

  @override
  String get spotDetailCouldNotLoadProfile => 'No se pudo cargar tu perfil.';

  @override
  String get spotDetailRefreshPageToRate => 'Actualiza la página para valorar.';

  @override
  String get spotDetailSignInToRateTitle =>
      'Inicia sesión para valorar este spot';

  @override
  String get spotDetailSignInToRateSubtitle =>
      'Inicia sesión para valorar este spot y ayudar a otros.';

  @override
  String get spotDetailSignInButton => 'Iniciar sesión';

  @override
  String get spotDetailCreateAccountButton => 'Crear cuenta';

  @override
  String get spotDetailMapSwitchToMap => 'Ver mapa';

  @override
  String get spotDetailMapSwitchToSatellite => 'Ver satélite';

  @override
  String get spotDetailMapLocateOnMap => 'Ver en el mapa';

  @override
  String get spotDetailDuplicateOf => 'Duplicado de';

  @override
  String get spotDetailOriginalSpotFallback => 'Spot original';

  @override
  String get spotDetailAlsoBasedOn => 'También basado en';

  @override
  String spotDetailAlsoBasedOnCount(int count) {
    return 'También basado en ($count)';
  }

  @override
  String get spotDetailNoImagesAvailable => 'No hay imágenes disponibles';

  @override
  String spotDetailGalleryPageIndicator(int current, int total) {
    return '$current / $total';
  }

  @override
  String get spotDetailSaveMenuTooltip => 'Guardar spot';

  @override
  String get spotDetailSaveMenuSignInTitle =>
      'Inicia sesión para guardar spots';

  @override
  String get spotDetailSaveMenuSignInBody =>
      'Añade este spot a «Quiero visitar», «Ya estuve» o tus listas. Inicia sesión o crea una cuenta gratuita.';

  @override
  String get spotDetailSaveMenuLogInOrCreate => 'Iniciar sesión o crear cuenta';

  @override
  String get spotDetailSaveTooltipUpdating => 'Actualizando…';

  @override
  String get spotDetailSaveTooltipWantToVisit => 'Guardado: Quiero visitar';

  @override
  String get spotDetailSaveTooltipBeenHere => 'Guardado: Ya estuve';

  @override
  String get spotDetailSaveTooltipGeneric => 'Guardar spot';

  @override
  String get spotDetailRemovedFromWantToVisit => 'Quitado de Quiero visitar';

  @override
  String get spotDetailFailedToRemove => 'No se pudo quitar';

  @override
  String get spotDetailAddedToWantToVisit => 'Añadido a Quiero visitar';

  @override
  String get spotDetailFailedToAdd => 'No se pudo añadir';

  @override
  String get spotDetailRemovedFromBeenHere => 'Quitado de Ya estuve';

  @override
  String get spotDetailAddedToBeenHere => 'Añadido a Ya estuve';

  @override
  String get spotDetailWantToVisit => 'Quiero visitar';

  @override
  String get spotDetailBeenHere => 'Ya estuve';

  @override
  String get spotDetailViewFullListTooltip => 'Ver lista completa';

  @override
  String get spotDetailAddToCustomList => 'Añadir a lista propia';

  @override
  String get spotDetailAddToCustomListSubtitle => 'Elige o crea una lista';

  @override
  String get spotDetailListNameEmpty =>
      'El nombre de la lista no puede estar vacío';

  @override
  String get spotDetailFailedAddToListGeneric =>
      'No se pudo añadir el spot a la lista';

  @override
  String get spotDetailFailedCreateList => 'No se pudo crear la lista';

  @override
  String get spotDetailFailedAddToSomeLists =>
      'No se pudo añadir el spot a algunas listas';

  @override
  String spotDetailAddToListTitle(String name) {
    return 'Añadir a $name';
  }

  @override
  String get spotDetailSelectSections => 'Seleccionar secciones:';

  @override
  String spotDetailSectionEntryCount(int count) {
    return 'Sección ($count spots)';
  }

  @override
  String get spotDetailAddToNewSection => 'Añadir a nueva sección';

  @override
  String get spotDetailSectionNameOptional => 'Nombre de sección (opcional)';

  @override
  String get spotDetailNoteOptional => 'Nota (opcional)';

  @override
  String get spotDetailSkip => 'Omitir';

  @override
  String get spotDetailAdd => 'Añadir';

  @override
  String get spotDetailAddToListDialogTitle => 'Añadir a la lista';

  @override
  String get spotDetailAlreadyInLists => 'Ya está en estas listas:';

  @override
  String get spotDetailNoListsYet =>
      'Aún no tienes listas. ¡Crea una para empezar!';

  @override
  String get spotDetailSelectListsPrompt =>
      'Selecciona las listas a las que añadir este spot:';

  @override
  String get spotDetailCreateNewList => 'Crear lista nueva';

  @override
  String get spotDetailListNameLabel => 'Nombre de la lista';

  @override
  String get spotDetailListNameHint => 'p. ej., Mis spots favoritos';

  @override
  String get spotDetailListDescriptionLabel => 'Descripción (opcional)';

  @override
  String get spotDetailListDescriptionHint =>
      'Añade una descripción para esta lista';

  @override
  String get spotDetailVisibilityLabel => 'Visibilidad';

  @override
  String get spotDetailCreateAndAdd => 'Crear y añadir';

  @override
  String get spotDetailReportDuplicateTitle => 'Reportar spot duplicado';

  @override
  String get spotDetailReportDuplicateIntro =>
      'Selecciona el spot del que es duplicado.';

  @override
  String get spotDetailEmailInvalid =>
      'Introduce un correo electrónico válido.';

  @override
  String get spotDetailEmailRequired => 'Introduce un correo electrónico.';

  @override
  String get spotDetailSubmitReport => 'Enviar reporte';

  @override
  String get spotDetailReportThisSpotTitle => 'Reportar este spot';

  @override
  String spotDetailReportIntro(String name) {
    return 'Cuéntanos qué falla con $name. Los moderadores revisarán tu reporte pronto.';
  }

  @override
  String get spotDetailReportWhatWrong => '¿Qué ocurre?';

  @override
  String get spotDetailReportCategoryLabel => 'Selecciona una categoría';

  @override
  String get spotDetailReportCategoryHint => 'Elige una categoría de reporte';

  @override
  String get spotDetailReportDescribeIssue => 'Describe el problema';

  @override
  String get spotDetailReportDescribeIssueHint =>
      'Dinos qué no coincide con la realidad';

  @override
  String get spotDetailReportAdditionalDetails => 'Detalles adicionales';

  @override
  String get spotDetailReportAdditionalDetailsHint =>
      '¿Algo más que debamos saber?';

  @override
  String get spotDetailReportEmailLabel => 'Correo electrónico';

  @override
  String get spotDetailReportEmailHelper =>
      'Solo te contactaremos por este reporte.';

  @override
  String spotDetailReportReachOutAt(String email) {
    return 'Si hace falta más información, te escribiremos a $email.';
  }

  @override
  String get spotDetailReportReachOutAccount =>
      'Si hace falta más información, usaremos el correo de tu cuenta.';

  @override
  String get spotDetailReportCategoryOtherDescribe =>
      'Describe el problema al elegir «Otro».';

  @override
  String get spotDetailReportCategoryRequired => 'Selecciona una categoría.';

  @override
  String get spotDetailReportSendFailed =>
      'No se pudo enviar el reporte. Inténtalo de nuevo.';

  @override
  String get spotDetailReportCategoryClosed => 'Spot cerrado o eliminado';

  @override
  String get spotDetailReportCategoryInaccurate =>
      'Ubicación o datos incorrectos';

  @override
  String get spotDetailReportCategoryUnsafe => 'Condiciones inseguras';

  @override
  String get spotDetailReportCategoryNotASpot => 'No es un spot';

  @override
  String get spotDetailReportCategoryOther => 'Otro';

  @override
  String get spotDetailReportCategoryClosedDesc =>
      'El spot se cerró, demolió o eliminó de forma permanente y ya no es accesible. Da más detalles abajo.';

  @override
  String get spotDetailReportCategoryInaccurateDesc =>
      'La ubicación en el mapa es incorrecta o datos como nombre, descripción o dirección están mal. Indica abajo qué corregir.';

  @override
  String get spotDetailReportCategoryUnsafeDesc =>
      'El spot se ha vuelto peligroso por estructura, entorno u otros riesgos. Explica abajo qué es inseguro.';

  @override
  String get spotDetailReportCategoryNotASpotDesc =>
      'Solo para casos objetivos: spam, ubicaciones inválidas (p. ej. mar abierto), viviendas privadas, ciudades enteras u entradas claramente inválidas. Para opiniones sobre calidad, usa la valoración. Explica abajo por qué no es un spot.';

  @override
  String get spotDetailReportCategoryOtherDesc =>
      'Cualquier otro problema no cubierto arriba. Descríbelo en el campo de abajo.';

  @override
  String get spotDetailMarkDuplicateTitle => 'Marcar como duplicado';

  @override
  String get spotDetailMarkDuplicateBody =>
      '¿Seguro que quieres marcar este spot como duplicado? Se puede deshacer después.';

  @override
  String get spotDetailMarkDuplicateAddToOriginal =>
      'Elige qué añadir al spot original:';

  @override
  String get spotDetailMarkDuplicatePhotos => 'Fotos';

  @override
  String get spotDetailMarkDuplicateYoutube => 'Enlaces de YouTube';

  @override
  String get spotDetailMarkDuplicateOverwrite =>
      'Elige qué sobrescribir en el spot original (si aplica):';

  @override
  String get spotDetailMarkDuplicateName => 'Nombre';

  @override
  String get spotDetailMarkDuplicateDescription => 'Descripción';

  @override
  String get spotDetailMarkDuplicateLocation => 'Ubicación';

  @override
  String get spotDetailMarkDuplicateSpotAttributes => 'Atributos del spot';

  @override
  String get spotDetailConfirm => 'Confirmar';

  @override
  String get spotDetailPickImagesFailed =>
      'No se pudieron elegir imágenes. Inténtalo de nuevo.';

  @override
  String get spotDetailSelectAtLeastOnePhoto => 'Selecciona al menos una foto';

  @override
  String get spotDetailSuggestPhotosTitle => 'Sugerir fotos';

  @override
  String get spotDetailSuggestPhotosIntro =>
      'Envía fotos para añadir a este spot. Los moderadores las revisarán antes de publicarlas.';

  @override
  String get spotDetailSelectPhotos => 'Seleccionar fotos';

  @override
  String get spotDetailPickPhotos => 'Elegir fotos';

  @override
  String get spotDetailAdditionalDetailsOptional =>
      'Detalles adicionales (opcional)';

  @override
  String get spotDetailAdditionalDetailsHint =>
      'Añade más información sobre estas fotos…';

  @override
  String get spotDetailSuggestPhotosEmailHelper =>
      'Solo te contactaremos por esta sugerencia.';

  @override
  String get spotDetailSuggestPhotosSubmitFailed =>
      'No se pudo enviar la sugerencia de fotos. Inténtalo de nuevo.';

  @override
  String spotDetailSuggestPhotosSubmitError(String error) {
    return 'Error al enviar sugerencia de fotos: $error';
  }

  @override
  String get spotDetailSuggestEditTitle => 'Sugerir edición';

  @override
  String get spotDetailSuggestEditIntro =>
      'Propón cambios en este spot. Los moderadores revisarán tus sugerencias.';

  @override
  String get spotDetailSuggestEditSuggestChange =>
      'Sugiere al menos un cambio.';

  @override
  String get spotDetailSuggestEditSubmitFailed =>
      'No se pudo enviar la sugerencia de edición. Inténtalo de nuevo.';

  @override
  String spotDetailSuggestEditSubmitError(String error) {
    return 'Error al enviar sugerencia de edición: $error';
  }

  @override
  String get spotDetailGeocoding => 'Geocodificando…';

  @override
  String get spotDetailChangeLocationPicked => 'Cambiar ubicación (elegida)';

  @override
  String get spotDetailPickLocationOnMap => 'Elegir otra ubicación en el mapa';

  @override
  String get spotDetailFieldTitle => 'Título';

  @override
  String get spotDetailFieldTitleHint => 'Título del spot';

  @override
  String get spotDetailFieldDescription => 'Descripción';

  @override
  String get spotDetailFieldDescriptionHint => 'Descripción del spot';

  @override
  String get spotDetailFieldSpotAttributes => 'Atributos del spot';

  @override
  String get spotDetailSuggestEditEmailHelper =>
      'Solo te contactaremos por esta sugerencia.';

  @override
  String get spotDetailMustBeLoggedInToRate =>
      'Debes iniciar sesión para valorar spots';

  @override
  String spotDetailRatingSubmitted(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '¡Valoración de $count estrellas enviada!',
      one: '¡Valoración de 1 estrella enviada!',
    );
    return '$_temp0';
  }

  @override
  String get spotDetailRatingSubmitFailed =>
      'No se pudo enviar la valoración. Inténtalo de nuevo.';

  @override
  String spotDetailRatingSubmitError(String error) {
    return 'Error al enviar la valoración: $error';
  }

  @override
  String get spotDetailNotExternalSource =>
      'Este spot no proviene de una fuente externa.';

  @override
  String get spotDetailMustBeLoggedInCreateNative =>
      'Debes iniciar sesión para crear un spot nativo.';

  @override
  String get spotDetailCreateNativeDialogTitle => 'Crear spot nativo';

  @override
  String get spotDetailCreateNativeDialogBody =>
      'Se creará un spot nativo basado en este y el actual se marcará como su duplicado. Se copiarán todos los datos (nombre, descripción, ubicación, fotos, enlaces de YouTube y atributos).\n\nNota: los administradores pueden eliminar spots y enlaces de duplicado si hace falta.';

  @override
  String get spotDetailCreateButton => 'Crear';

  @override
  String get spotDetailUnableCreateNativeNow =>
      'No se puede crear un spot nativo ahora.';

  @override
  String get spotDetailFailedCreateNativeSpot =>
      'No se pudo crear el spot nativo';

  @override
  String get spotDetailNativeCreatedDuplicateMarked =>
      'Spot nativo creado y el actual marcado como duplicado.';

  @override
  String get spotDetailFailedMarkDuplicateGeneric =>
      'No se pudo marcar como duplicado';

  @override
  String spotDetailErrorCreatingNativeSpot(String error) {
    return 'Error al crear spot nativo: $error';
  }

  @override
  String get spotDetailUnableMarkDuplicateNow =>
      'No se puede marcar este spot como duplicado ahora.';

  @override
  String get spotDetailAlreadyMarkedDuplicate =>
      'Este spot ya está marcado como duplicado.';

  @override
  String get spotDetailSpotMarkedDuplicateSuccess =>
      'Spot marcado como duplicado.';

  @override
  String spotDetailErrorMarkingDuplicateSpot(String error) {
    return 'Error al marcar como duplicado: $error';
  }

  @override
  String get spotDetailModeratorsOnlyHideUnhide =>
      'Solo moderadores pueden ocultar o mostrar spots.';

  @override
  String get spotDetailHideSpotTitle => 'Ocultar spot';

  @override
  String get spotDetailUnhideSpotTitle => 'Mostrar spot';

  @override
  String get spotDetailHideSpotMessage =>
      'El spot dejará de verse públicamente. No aparecerá en búsquedas ni en el mapa, pero los datos se conservan y pueden mostrarse después.';

  @override
  String get spotDetailUnhideSpotMessage =>
      'El spot volverá a ser público y aparecerá en búsquedas y en el mapa.';

  @override
  String get spotDetailActionHide => 'Ocultar';

  @override
  String get spotDetailActionUnhide => 'Mostrar';

  @override
  String get spotDetailUnableHideUnhideNow =>
      'No se puede ocultar o mostrar este spot ahora.';

  @override
  String get spotDetailSpotHiddenSuccess => 'Spot ocultado.';

  @override
  String get spotDetailSpotUnhiddenSuccess => 'Spot visible de nuevo.';

  @override
  String get spotDetailFailedHideSpot => 'No se pudo ocultar el spot';

  @override
  String get spotDetailFailedUnhideSpot => 'No se pudo mostrar el spot';

  @override
  String spotDetailErrorHidingSpot(String error) {
    return 'Error al ocultar el spot: $error';
  }

  @override
  String spotDetailErrorUnhidingSpot(String error) {
    return 'Error al mostrar el spot: $error';
  }

  @override
  String get spotDetailNotMarkedAsDuplicate =>
      'Este spot no está marcado como duplicado.';

  @override
  String get spotDetailModeratorsOnlyRemoveDuplicateStatus =>
      'Solo moderadores pueden quitar el estado de duplicado.';

  @override
  String get spotDetailRemoveDuplicateDialogBody =>
      'Se quitará el estado de duplicado; el spot ya no se considerará duplicado.\n\n¿Continuar?';

  @override
  String get spotDetailRemoveButton => 'Quitar';

  @override
  String get spotDetailUnableRemoveDuplicateStatusNow =>
      'No se puede quitar el estado de duplicado ahora.';

  @override
  String get spotDetailDuplicateStatusRemovedSuccess =>
      'Estado de duplicado eliminado.';

  @override
  String get spotDetailFailedRemoveDuplicateStatusGeneric =>
      'No se pudo quitar el estado de duplicado';

  @override
  String spotDetailErrorRemovingDuplicateStatus(String error) {
    return 'Error al quitar el estado de duplicado: $error';
  }

  @override
  String get spotDetailCheckingLinkedData => 'Comprobando datos vinculados…';

  @override
  String get spotDetailDeleteSpotDialogTitle => 'Eliminar spot';

  @override
  String get spotDetailDeleteSpotConfirmMessage =>
      '¿Seguro que quieres eliminar este spot? No se puede deshacer.';

  @override
  String get spotDetailLinkedDataHeading => 'Este spot tiene datos vinculados:';

  @override
  String spotDetailLinkedRatingsLine(int count) {
    return '• Valoraciones: $count';
  }

  @override
  String spotDetailLinkedReportsLine(int count) {
    return '• Reportes de spot: $count';
  }

  @override
  String spotDetailLinkedDuplicatesLine(int count) {
    return '• Spots duplicados: $count';
  }

  @override
  String get spotDetailResolveLinksBeforeDelete =>
      'Resuelve estos vínculos antes de eliminar el spot.';

  @override
  String get spotDetailSpotDeletedSuccess => 'Spot eliminado.';

  @override
  String get spotDetailFailedDeleteSpot => 'No se pudo eliminar el spot';

  @override
  String spotDetailErrorDeletingSpot(String error) {
    return 'Error al eliminar el spot: $error';
  }

  @override
  String get spotDetailFlagDuplicateDialogTitle => 'Marcar como duplicado';

  @override
  String get spotDetailFlagDuplicateIntro =>
      'Este spot parece un duplicado de otro. Selecciona el spot original abajo.';

  @override
  String get spotDetailFlagDuplicateWhichQuestion =>
      '¿De qué spot es duplicado?';

  @override
  String get spotDetailDuplicateSearchHint =>
      'Pega la URL del spot o escribe el ID';

  @override
  String get spotDetailSearch => 'Buscar';

  @override
  String get spotDetailNearbySpotsWithin50m => 'Spots cercanos (en ~50 m)';

  @override
  String get spotDetailFoundSpot => 'Spot encontrado';

  @override
  String spotDetailSpotIdLabel(String id) {
    return 'ID del spot: $id';
  }

  @override
  String get spotDetailRemoveSelectionTooltip => 'Quitar selección';

  @override
  String get spotDetailImageFailedToLoad => 'No se pudo cargar la imagen';

  @override
  String get spotDetailClose => 'Cerrar';

  @override
  String spotDetailExpandMoreCount(int count) {
    return '$count más';
  }

  @override
  String get spotDetailSubmit => 'Enviar';

  @override
  String get spotDetailDuplicateReportSelectRequired =>
      'Selecciona el spot del que es duplicado.';

  @override
  String get spotDetailDuplicateSearchEmpty => 'Introduce un ID o URL de spot';

  @override
  String get spotDetailDuplicateInvalidUrl => 'ID o URL de spot no válidos';

  @override
  String get spotDetailDuplicateCannotSelectSelf =>
      'Un spot no puede ser duplicado de sí mismo';

  @override
  String get spotDetailDuplicateSpotNotFound => 'Spot no encontrado';

  @override
  String spotDetailDuplicateFailedLoadSpot(String error) {
    return 'No se pudo cargar el spot: $error';
  }

  @override
  String get sourceDetailsLoadingSource => 'Cargando fuente...';

  @override
  String get sourceDetailsErrorTitle => 'Error';

  @override
  String get sourceDetailsNotFound => 'Fuente no encontrada';

  @override
  String get sourceDetailsTotalSpots => 'Spots totales';

  @override
  String get sourceDetailsFolders => 'Carpetas';

  @override
  String get sourceDetailsGoToSource => 'Ir a la fuente';

  @override
  String get sourceDetailsAdded => 'Añadido';

  @override
  String get sourceDetailsLastImported => 'Última importación';

  @override
  String sourceDetailsRelativeDaysAgo(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Hace $count días',
      one: 'Hace 1 día',
    );
    return '$_temp0';
  }

  @override
  String sourceDetailsRelativeHoursAgo(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Hace $count horas',
      one: 'Hace 1 hora',
    );
    return '$_temp0';
  }

  @override
  String sourceDetailsRelativeMinutesAgo(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Hace $count minutos',
      one: 'Hace 1 minuto',
    );
    return '$_temp0';
  }

  @override
  String get sourceDetailsRelativeJustNow => 'Justo ahora';

  @override
  String spotTrackingSignInToViewList(String listName) {
    return 'Inicia sesión para ver tu lista «$listName»';
  }

  @override
  String spotTrackingNoSpotsInList(String listName) {
    return 'No hay spots en $listName';
  }

  @override
  String get spotListSaveTooltipSaveList => 'Guardar lista';

  @override
  String get spotListSaveTooltipSavedList => 'Lista guardada';

  @override
  String get spotListSaveSignInTitle => 'Inicia sesión para guardar listas';

  @override
  String get spotListSaveSignInBody =>
      'Guarda la lista de spots de otra persona en tu perfil para poder abrirla de nuevo más tarde.';

  @override
  String get spotListSaveSavedToProfile => 'Lista guardada en tu perfil';

  @override
  String get spotListSaveCouldNotSaveList => 'No se pudo guardar la lista';

  @override
  String get spotListSaveRemovedFromSavedLists => 'Quitada de listas guardadas';

  @override
  String get spotListSaveCouldNotRemoveList => 'No se pudo quitar la lista';

  @override
  String get spotListSaveActionSaveList => 'Guardar lista';

  @override
  String get spotListSaveActionRemoveFromSaved => 'Quitar de guardadas';

  @override
  String get spotListSaveActionViewSavedLists => 'Ver listas guardadas';

  @override
  String get spotListDetailListNotFoundOrNotAccessible =>
      'Lista no encontrada o no accesible';

  @override
  String get spotListDetailDeleteListTitle => 'Eliminar lista';

  @override
  String spotListDetailDeleteListConfirmation(String name) {
    return '¿Seguro que quieres eliminar \"$name\"? Esta acción no se puede deshacer.';
  }

  @override
  String get spotListDetailDeleteAction => 'Eliminar';

  @override
  String get spotListDetailListDeleted => 'Lista eliminada';

  @override
  String get spotListDetailFailedToDeleteList => 'No se pudo eliminar la lista';

  @override
  String get spotListDetailNoSpotsInThisList => 'No hay spots en esta lista';

  @override
  String get spotListDetailEditListTitle => 'Editar lista';

  @override
  String get spotListDetailMoreInfoLinkLabel =>
      'Enlace con más información (opcional)';

  @override
  String get spotListDetailMoreInfoLinkHint => 'https://…';

  @override
  String get spotListDetailMoreInfoLinkHelper =>
      'Una página en la web con más información sobre esta lista';

  @override
  String get spotListDetailMoreInfoLinkValidationError =>
      'El enlace de más información debe ser una URL válida (http o https), p. ej. example.com o https://example.com/pagina';

  @override
  String get spotListDetailSave => 'Guardar';

  @override
  String get spotListDetailListUpdated => 'Lista actualizada';

  @override
  String get spotListDetailFailedToUpdateList =>
      'No se pudo actualizar la lista';

  @override
  String get spotListDetailVisibilityPublicList => 'Lista pública';

  @override
  String get spotListDetailVisibilityUnlistedList => 'Lista no listada';

  @override
  String get spotListDetailVisibilityPrivateList => 'Lista privada';

  @override
  String get spotListDetailCouldNotOpenProfile => 'No se pudo abrir el perfil';

  @override
  String spotListDetailCreatedPart(String visibility, String date) {
    return '$visibility creada $date';
  }

  @override
  String get spotListDetailCreatedBySuffix => ' por ';

  @override
  String spotListDetailLastUpdatedPart(String date) {
    return ', y actualizada por última vez $date.';
  }

  @override
  String get spotListDetailMoreInformationOn => 'Más información en ';

  @override
  String get spotListDetailCopiedToClipboard =>
      '¡Lista copiada al portapapeles!';

  @override
  String spotListDetailCopyFailed(String error) {
    return 'No se pudo copiar la lista: $error';
  }

  @override
  String get spotListDetailHighlightListOnMap => 'Resaltar lista en el mapa';

  @override
  String get spotListDetailEditListTooltip => 'Editar lista';

  @override
  String get spotListDetailMenuListSettings => 'Ajustes de la lista';

  @override
  String get spotListDetailMenuOrganizeList => 'Organizar lista';

  @override
  String get spotListDetailMenuDeleteList => 'Eliminar lista';

  @override
  String get spotListDetailPageTitle => 'Lista de spots';

  @override
  String get spotListDetailListNotFound => 'Lista no encontrada';

  @override
  String spotListDetailMetaDescriptionFallback(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count spots de parkour',
      one: '1 spot de parkour',
    );
    return 'Una lista curada de $_temp0 en Parkour·Spot';
  }

  @override
  String get publicProfilePageTitle => 'Perfil';

  @override
  String get publicProfileShareProfileTooltip => 'Compartir perfil';

  @override
  String get publicProfileErrorLoadingProfile => 'Error al cargar el perfil';

  @override
  String get publicProfilePleaseTryAgainLater => 'Inténtalo de nuevo más tarde';

  @override
  String publicProfileMetaDescription(String name, String defaultDescription) {
    return 'Consulta los spots y listas de parkour de $name en Parkour·Spot — $defaultDescription';
  }

  @override
  String get publicProfileProfileNotFound => 'Perfil no encontrado';

  @override
  String get publicProfileNotFoundOrPrivate =>
      'Este perfil no existe o es privado.';

  @override
  String publicProfileMemberSince(String date) {
    return 'Miembro desde $date';
  }

  @override
  String get publicProfileEditProfileTooltip => 'Editar perfil';

  @override
  String get publicProfileSpotTracking => 'Seguimiento de spots';

  @override
  String get publicProfileNoSpotsYet => 'Aún no hay spots';

  @override
  String get publicProfileAddSpotsFromSpotDetailPages =>
      'Añade spots desde las páginas de detalle del spot';

  @override
  String get publicProfileBeenTo => 'Visitados';

  @override
  String get publicProfileMyCheckIns => 'Mis check-ins';

  @override
  String get publicProfileMyCheckInsSubtitle =>
      'Tu historial registrado de visitas a spots';

  @override
  String get myCheckInsSignInPrompt => 'Inicia sesión para ver tus check-ins';

  @override
  String get myCheckInsLoadMore => 'Cargar más';

  @override
  String get myCheckInsEmptyTitle => 'Aún no hay check-ins';

  @override
  String get myCheckInsEmptyDescription =>
      'Abre un spot y toca Check in para registrar una visita. Hasta la hora de fin que configures, otras personas pueden verte como «aquí ahora» en ese spot, salvo que mantengas el check-in privado.';

  @override
  String get myCheckInsIntro =>
      'Un check-in registra que visitaste un spot, cuándo llegaste y hasta cuándo esperas quedarte. Los check-ins públicos pueden mostrarte en «quién está aquí ahora» de ese spot hasta esa hora de fin; los check-ins privados solo son visibles para ti.';

  @override
  String get myCheckInsSpotFallback => 'Spot';

  @override
  String get myCheckInsPrivateOnlyYou => 'Privado — solo tú puedes ver esto';

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
  String get publicProfileYours => 'Tuyas';

  @override
  String get publicProfileCreateYourFirstList => 'Crea tu primera lista';

  @override
  String get publicProfileSaved => 'Guardadas';

  @override
  String get publicProfilePublicSpotLists => 'Listas públicas de spots';

  @override
  String get publicProfileNoSavedListsYet => 'Aún no hay listas guardadas';

  @override
  String get publicProfileSaveListsHint =>
      'Guarda listas que encuentres en las páginas de listas de otros usuarios';

  @override
  String get publicProfileSavedListsUnavailable =>
      'Tus listas guardadas ya no están disponibles o fueron eliminadas.';

  @override
  String get publicProfileListCreatedSuccessfully =>
      'Lista creada correctamente';

  @override
  String get publicProfileChangeProfilePicture => 'Cambiar foto de perfil';

  @override
  String get publicProfileChooseFromGallery => 'Elegir de la galería';

  @override
  String get publicProfileTakePhoto => 'Tomar foto';

  @override
  String get publicProfileRemovePicture => 'Quitar foto';

  @override
  String publicProfileErrorPickingImage(String error) {
    return 'Error al elegir la imagen: $error';
  }

  @override
  String publicProfileErrorTakingPhoto(String error) {
    return 'Error al tomar la foto: $error';
  }

  @override
  String get publicProfileProcessingImage => 'Procesando imagen...';

  @override
  String get publicProfileReadingImage => 'Leyendo imagen...';

  @override
  String get publicProfileUploading => 'Subiendo...';

  @override
  String get publicProfileFinishing => 'Finalizando...';

  @override
  String get publicProfileUpdatingProfile => 'Actualizando perfil...';

  @override
  String get publicProfileProfilePictureUpdatedSuccessfully =>
      'Foto de perfil actualizada correctamente';

  @override
  String get publicProfileFailedToUpdateProfilePicture =>
      'No se pudo actualizar la foto de perfil';

  @override
  String publicProfileErrorUploadingProfilePicture(String error) {
    return 'Error al subir la foto de perfil: $error';
  }

  @override
  String get publicProfileRemoveProfilePicture => 'Quitar foto de perfil';

  @override
  String get publicProfileRemoveProfilePictureConfirmation =>
      '¿Seguro que quieres quitar tu foto de perfil?';

  @override
  String get publicProfileProfilePictureRemovedSuccessfully =>
      'Foto de perfil eliminada correctamente';

  @override
  String get publicProfileFailedToRemoveProfilePicture =>
      'No se pudo eliminar la foto de perfil';

  @override
  String publicProfileErrorRemovingProfilePicture(String error) {
    return 'Error al eliminar la foto de perfil: $error';
  }

  @override
  String get publicProfileProfileCopiedToClipboard =>
      '¡Perfil copiado al portapapeles!';

  @override
  String publicProfileFailedToCopyProfile(String error) {
    return 'No se pudo copiar el perfil: $error';
  }

  @override
  String get publicProfileStatsSpots => 'Spots';

  @override
  String get publicProfileStatsRatings => 'Valoraciones';

  @override
  String get publicProfileSettingsTitle => 'Ajustes del perfil';

  @override
  String get publicProfileEmailLabel => 'Correo electrónico';

  @override
  String get publicProfileEmailNotShownHint =>
      'Tu correo electrónico no se muestra públicamente.';

  @override
  String get publicProfileDisplayNameLabel => 'Nombre visible';

  @override
  String get publicProfileNoDisplayNameSet => 'Sin nombre visible';

  @override
  String get publicProfileEditAction => 'Editar';

  @override
  String get publicProfileDisplayNameHint => 'Introduce tu nombre';

  @override
  String publicProfileDisplayNameHelper(int max) {
    return 'Así se mostrará tu nombre a otras personas';
  }

  @override
  String publicProfileDisplayNameMaxLengthError(int max) {
    return 'El nombre visible debe tener como máximo 50 caracteres';
  }

  @override
  String get publicProfileDisplayNameUpdated => 'Nombre visible actualizado';

  @override
  String get publicProfileDisplayNameRemoved => 'Nombre visible eliminado';

  @override
  String get publicProfileDisplayNameUpdateFailed =>
      'No se pudo actualizar el nombre visible';

  @override
  String get publicProfileSaveAction => 'Guardar';

  @override
  String get publicProfileUsernameLabel => 'Nombre de usuario';

  @override
  String get publicProfileNoUsernameSet => 'Sin nombre de usuario';

  @override
  String get publicProfileUsernameHint => 'Introduce un nombre de usuario';

  @override
  String get publicProfileUsernameHelper =>
      'Único y usado en la URL de tu perfil';

  @override
  String get publicProfileUsernameEmpty =>
      'El nombre de usuario no puede estar vacío';

  @override
  String get publicProfileUsernameTaken =>
      'Ese nombre de usuario ya está en uso';

  @override
  String get publicProfileUsernameUpdated => 'Nombre de usuario actualizado';

  @override
  String get publicProfileUsernameUpdateFailed =>
      'No se pudo actualizar el nombre de usuario';

  @override
  String get publicProfileInstagramLabel => 'Instagram';

  @override
  String get publicProfileNoInstagramSet => 'Sin Instagram configurado';

  @override
  String get publicProfileAddAction => 'Añadir';

  @override
  String get publicProfileInstagramLinkLabel => 'Enlace de Instagram';

  @override
  String get publicProfileInstagramLinkHint =>
      'https://instagram.com/tuusuario';

  @override
  String get publicProfileInstagramLinkHelper =>
      'URL completa a tu perfil de Instagram';

  @override
  String get publicProfileInstagramInvalid =>
      'Introduce una URL de Instagram válida';

  @override
  String get publicProfileInstagramRemoved => 'Enlace de Instagram eliminado';

  @override
  String get publicProfileInstagramUpdated => 'Enlace de Instagram actualizado';

  @override
  String get publicProfileInstagramUpdateFailed =>
      'No se pudo actualizar el enlace de Instagram';

  @override
  String get publicProfilePrivacyTitle => 'Privacidad';

  @override
  String get publicProfilePrivacyPublicLabel => 'Perfil público';

  @override
  String get publicProfilePrivacyPrivateLabel => 'Perfil privado';

  @override
  String get publicProfilePrivacyPublicDescription =>
      'Cualquiera puede ver tu perfil y tus listas públicas.';

  @override
  String get publicProfilePrivacyPrivateDescription =>
      'Solo tú puedes ver tu perfil.';

  @override
  String get publicProfilePrivacyNowPublic => 'Tu perfil ahora es público';

  @override
  String get publicProfilePrivacyNowPrivate => 'Tu perfil ahora es privado';

  @override
  String get publicProfileFailedToUpdateProfilePrivacy =>
      'No se pudo actualizar la privacidad del perfil';
}
