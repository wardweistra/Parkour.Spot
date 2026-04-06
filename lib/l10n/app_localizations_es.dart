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
}
