// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for German (`de`).
class AppLocalizationsDe extends AppLocalizations {
  AppLocalizationsDe([String locale = 'de']) : super(locale);

  @override
  String get tabExplore => 'Entdecken';

  @override
  String get tabAddSpot => 'Spot hinzufügen';

  @override
  String get tabAccount => 'Konto';

  @override
  String get profileSettingsTitle => 'Einstellungen';

  @override
  String get profileSettingsLanguageLabel => 'Sprache';

  @override
  String get profileSettingsLanguageDescription =>
      'Sprache wählen oder Geräteeinstellung verwenden.';

  @override
  String get profileLanguageSystemDefault => 'Gerätesprache';

  @override
  String get profileLoadErrorDefault => 'Profil konnte nicht geladen werden.';

  @override
  String get profileRefreshPage => 'Seite neu laden';

  @override
  String get profileRetry => 'Erneut versuchen';

  @override
  String get profileSignInTitle =>
      'Melde dich an, um auf dein Konto zuzugreifen';

  @override
  String get profileSignInSubtitle =>
      'Melde dich an, um deine Spots zu verwalten und Orte zu bewerten.';

  @override
  String get profileSignInButton => 'Anmelden';

  @override
  String get profileOrDivider => 'ODER';

  @override
  String get profileCreateAccount => 'Konto erstellen';

  @override
  String get profileDefaultDisplayName => 'Nutzer';

  @override
  String get profileViewEditSubtitle => 'Profil ansehen und bearbeiten';

  @override
  String get profileModeratorSectionTitle => 'Moderation';

  @override
  String get profileModeratorToolsTitle => 'Moderations-Tools';

  @override
  String get profileModeratorToolsSubtitle =>
      'Eingehende Spot-Meldungen prüfen und bearbeiten';

  @override
  String get profileAdminSectionTitle => 'Administrator';

  @override
  String get profileAdminToolsTitle => 'Admin-Tools';

  @override
  String get profileAdminToolsSubtitle =>
      'Quellen und Verwaltungsaufgaben verwalten';

  @override
  String get profileSignOut => 'Abmelden';

  @override
  String get profileSignOutMessage => 'Möchtest du dich wirklich abmelden?';

  @override
  String get profileCancel => 'Abbrechen';

  @override
  String get profileAboutIntro =>
      'Parkour·Spot ist eine Community-App zum Entdecken und Teilen von Parkour- und Freerunning-Spots weltweit. Wir machen es einfach, gute Orte zu finden—egal, wo du trainierst.';

  @override
  String get profileReadMore => 'Mehr lesen';

  @override
  String get profileAboutStoryBeforeName => 'Gestartet von ';

  @override
  String get profileAboutStoryAfterName =>
      ' aus der Parkour-Community Utrecht: Die App bündelt lokales Wissen aus bestehenden Stadt- und Regionalkarten—ob auf Facebook, Instagram, Websites oder in eingestellten Apps—damit gute Spot-Daten nicht verloren gehen.';

  @override
  String get profileAboutMapMission =>
      'Das ist deine Karte. Füge neue Spots hinzu, bewerte vorhandene und ergänze Einträge mit Details. Je mehr wir beitragen, desto stärker wird das gemeinsame Wissen der Community.';

  @override
  String get profileAboutPrinciplesHeader => 'Unsere Prinzipien:';

  @override
  String get profileAboutPrincipleTransparency =>
      '• Transparenz: Du kannst die App ohne Konto durchsuchen, und jeder Spot zeigt, welche externen Quellen dazu beigetragen haben.';

  @override
  String get profileAboutPrinciplePortability =>
      '• Portabilität: Wir entwickeln Export-Tools, damit Spot-Daten auch außerhalb der App nutzbar sind.';

  @override
  String get profileAboutPrincipleOpenSource =>
      '• Open Source: Die App gehört der Community, nicht einer einzelnen Person.';

  @override
  String get profileAboutEnjoy =>
      'Viel Spaß beim Entdecken und Teilen von Spots mit Parkour.spot. Fragen oder Ideen? Tippe auf Kontakt—wir freuen uns auf deine Nachricht.';

  @override
  String get profileCreditsBy => 'Große Beiträge von ';

  @override
  String get profileCreditsDaphneArt => ' (Grafik), ';

  @override
  String get profileCreditsComma => ', ';

  @override
  String get profileCreditsEnd => ' und vielen anderen.';

  @override
  String get profileViewSourceCode => 'Quellcode ansehen';

  @override
  String get profileContactUs => 'Kontakt';

  @override
  String get profileReportIssue => 'Problem melden';

  @override
  String get profileInstallBannerTitle => 'Parkour·Spot-App installieren';

  @override
  String get profileInstallBannerSubtitle => 'Die volle App-Erfahrung nutzen';

  @override
  String get profileInstallDialogTitle => 'Parkour·Spot installieren';

  @override
  String profileInstallIntro(String device) {
    return 'So installierst du Parkour·Spot auf deinem $device:';
  }

  @override
  String get profileInstallDeviceIphone => 'iPhone';

  @override
  String get profileInstallDeviceAndroid => 'Android-Gerät';

  @override
  String get profileInstallIosStep1 => 'Tippe unten auf den Teilen-Button';

  @override
  String get profileInstallIosStep2 =>
      'Scrolle nach unten und tippe auf „Zum Home-Bildschirm“';

  @override
  String get profileInstallIosStep3 => 'Tippe oben rechts auf „Hinzufügen“';

  @override
  String get profileInstallIosStep4 =>
      'Die App erscheint auf deinem Home-Bildschirm!';

  @override
  String get profileInstallAndroidStep1 => 'Tippe oben rechts auf das Menü (⋯)';

  @override
  String get profileInstallAndroidStep2 =>
      'Tippe auf „Zum Startbildschirm hinzufügen“';

  @override
  String get profileInstallAndroidStep3 => 'Tippe auf „App installieren“';

  @override
  String get profileInstallAndroidStep4 =>
      'Die App erscheint auf deinem Startbildschirm!';

  @override
  String get profileInstallGotIt => 'Verstanden';

  @override
  String get exploreMetaDefaultTitle => 'Parkour·Spot';

  @override
  String get exploreMetaDefaultDescription =>
      'Entdecke, kartiere und teile die besten Parkour-Spots weltweit mit Community-Fotos, Bewertungen und lokalen Tipps für dein nächstes Training.';

  @override
  String exploreMetaTitleCityCountry(String city, String country) {
    return 'Die besten Parkour-Spots in $city, $country';
  }

  @override
  String exploreMetaDescriptionCityCountry(String city, String country) {
    return 'Entdecke die besten Parkour-Spots in $city, $country. Finde Trainingsorte, teile deine Lieblings-Spots und vernetze dich mit der Parkour-Community.';
  }

  @override
  String exploreMetaTitleCountry(String country) {
    return 'Die besten Parkour-Spots in $country';
  }

  @override
  String exploreMetaDescriptionCountry(String country) {
    return 'Entdecke die besten Parkour-Spots in $country. Finde Trainingsorte, teile deine Lieblings-Spots und vernetze dich mit der Parkour-Community.';
  }

  @override
  String get exploreAddSpotTitle => 'Neuen Spot hinzufügen';

  @override
  String get exploreAddSpotSubtitle =>
      'Teile deine Lieblings-Parkour-Spots mit der Community';

  @override
  String get exploreSignInToAddSpot =>
      'Melde dich an, um einen Spot hinzuzufügen';

  @override
  String get exploreLoadingProfile => 'Profil wird geladen…';

  @override
  String get exploreSearchHint => 'Ort oder Spot suchen…';

  @override
  String get exploreFilterBy => 'Filtern nach';

  @override
  String get exploreFilterAmenities => 'Ausstattung';

  @override
  String get exploreFilterSources => 'Quellen';

  @override
  String get exploreSpotAccessTitle => 'Spot-Zugang';

  @override
  String get exploreSpotAccessSubtitle => 'Spots nach Zugangstyp filtern';

  @override
  String get exploreFilterAny => 'Beliebig';

  @override
  String get exploreSpotFacilitiesTitle => 'Spot-Ausstattung';

  @override
  String get exploreSpotFacilitiesSubtitle =>
      'Spots mit diesen Annehmlichkeiten anzeigen';

  @override
  String get exploreAttributesTitle => 'Mit einer dieser Eigenschaften';

  @override
  String get exploreAttributesSubtitle =>
      'Spots, die mindestens eine der gewählten Skills oder Features haben';

  @override
  String get exploreGoodForSegment => 'Geeignet für';

  @override
  String get exploreSpotFeaturesSegment => 'Spot-Features';

  @override
  String get exploreSpotSourceLabel => 'Spot-Quelle';

  @override
  String get exploreSourcesLoadError => 'Quellen konnten nicht geladen werden';

  @override
  String get exploreAllSources => 'Alle Quellen';

  @override
  String get exploreParkourSpotNative => 'Parkour·Spot (Native)';

  @override
  String get exploreAllFolders => 'Alle Ordner';

  @override
  String exploreLocationError(String error) {
    return 'Standort konnte nicht ermittelt werden: $error';
  }

  @override
  String get exploreCurrentLocationSnackbar =>
      'Das ist dein aktueller Standort';

  @override
  String get exploreCloseTooltip => 'Schließen';

  @override
  String get exploreClearSearchTooltip => 'Leeren';

  @override
  String get exploreFiltersTooltip => 'Filter';

  @override
  String get exploreFindingLocation => 'Standort wird gesucht…';

  @override
  String get exploreAddSpotHereTitle => 'Spot an diesem Ort hinzufügen?';

  @override
  String exploreMapRankedTotalBar(int total) {
    return '$total Spots';
  }

  @override
  String exploreMapSpotsFoundLine(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count Spots gefunden',
      one: '1 Spot gefunden',
    );
    return '$_temp0';
  }

  @override
  String exploreMapBestShownParenthetical(int count) {
    return ' ($count beste angezeigt)';
  }

  @override
  String get exploreNoSpotsSearch => 'Keine Spots gefunden';

  @override
  String get exploreNoSpotsArea => 'Keine Spots in diesem Gebiet';

  @override
  String get exploreNoSpotsSearchHint => 'Passe deine Suchbegriffe an';

  @override
  String get exploreNoSpotsMapHint =>
      'Verschiebe die Karte, um andere Gebiete zu erkunden';

  @override
  String get exploreRefreshMapTooltip =>
      'Spots in der aktuellen Ansicht aktualisieren';

  @override
  String get exploreSwitchToMap => 'Zur Karte';

  @override
  String get exploreSwitchToSatellite => 'Zu Satellit';

  @override
  String get exploreLocationPermissionDenied => 'Standortzugriff verweigert';

  @override
  String get exploreCenterOnMyLocation => 'Auf meinen Standort zentrieren';

  @override
  String get exploreFiltersDialogTitle => 'Filter';

  @override
  String get exploreClearFilters => 'Zurücksetzen';

  @override
  String get exploreApplyFilters => 'Anwenden';

  @override
  String exploreSpotCountShort(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count Spots',
      one: '1 Spot',
    );
    return '$_temp0';
  }

  @override
  String get explorePwaBannerInstall => 'Installieren';

  @override
  String get addSpotPickImagesFailed =>
      'Bilder konnten nicht ausgewählt werden. Bitte erneut versuchen.';

  @override
  String get addSpotTakePhotoFailed =>
      'Foto konnte nicht aufgenommen werden. Bitte erneut versuchen.';

  @override
  String get addSpotNeedPhoto =>
      'Bitte lade mindestens ein Foto des Spots hoch';

  @override
  String get addSpotNeedLocation =>
      'Warte auf den Standort oder wähle einen Ort auf der Karte';

  @override
  String addSpotCreateError(String error) {
    return 'Spot konnte nicht erstellt werden: $error';
  }

  @override
  String get addSpotNameLabel => 'Spot-Name *';

  @override
  String get addSpotNameRequired => 'Bitte gib einen Spot-Namen ein';

  @override
  String get addSpotDescriptionLabel => 'Beschreibung *';

  @override
  String get addSpotDescriptionRequired => 'Bitte gib eine Beschreibung ein';

  @override
  String get addSpotDescriptionMinLength =>
      'Die Beschreibung muss mindestens 10 Zeichen haben';

  @override
  String get addSpotCreating => 'Spot wird erstellt…';

  @override
  String get addSpotCreateButton => 'Spot erstellen';

  @override
  String get addSpotLocationSectionTitle => 'Spot-Standort wählen';

  @override
  String get addSpotGettingLocation => 'Standort wird ermittelt…';

  @override
  String get addSpotLocationNotAvailable => 'Standort nicht verfügbar';

  @override
  String get addSpotPickLocationHint => 'Ort wählen';

  @override
  String get addSpotImagesSectionTitle => 'Spot-Bilder wählen';

  @override
  String get addSpotGalleryButton => 'Galerie';

  @override
  String get addSpotCameraButton => 'Kamera';

  @override
  String get addSpotGoodForTitle => 'Geeignet für';

  @override
  String get addSpotGoodForSubtitle =>
      'Welche Parkour-Fähigkeiten kann man hier trainieren?';

  @override
  String get addSpotFeaturesTitle => 'Spot-Features';

  @override
  String get addSpotFeaturesSubtitle =>
      'Welche körperlichen Merkmale hat dieser Spot?';

  @override
  String get addSpotAccessTitle => 'Spot-Zugang';

  @override
  String get addSpotAccessSubtitle => 'Wie ist der Zugang zu diesem Spot?';

  @override
  String get addSpotFacilitiesFormTitle => 'Spot-Ausstattung';

  @override
  String get addSpotFacilitiesSubtitle =>
      'Welche Annehmlichkeiten gibt es an diesem Spot?';

  @override
  String get addSpotLongPressHintSkill =>
      'Lange auf eine Fähigkeit drücken für mehr Infos';

  @override
  String get addSpotLongPressHintFeature =>
      'Lange auf ein Feature drücken für mehr Infos';

  @override
  String get addSpotLongPressHintFacility =>
      'Lange auf eine Ausstattung drücken für mehr Infos';

  @override
  String get addSpotPickLocationAppBarTitle => 'Ort wählen';

  @override
  String get addSpotTipLongPressMobile =>
      'Tipp: Du kannst Spots auch auf der Explore-Karte per langem Tippen auf einen Ort hinzufügen.';

  @override
  String get addSpotTipRightClickDesktop =>
      'Tipp: Du kannst Spots auch auf der Explore-Karte per Rechtsklick auf einen Ort hinzufügen.';

  @override
  String get addSpotUseThisLocation => 'Diesen Ort verwenden';

  @override
  String get addSpotDirectionsTooltip => 'Route';

  @override
  String get addSpotGettingAddress => 'Adresse wird geladen…';
}
