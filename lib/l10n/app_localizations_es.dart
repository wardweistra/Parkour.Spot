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
}
