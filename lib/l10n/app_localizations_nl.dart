// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Dutch Flemish (`nl`).
class AppLocalizationsNl extends AppLocalizations {
  AppLocalizationsNl([String locale = 'nl']) : super(locale);

  @override
  String get tabExplore => 'Verkennen';

  @override
  String get tabAddSpot => 'Spot toevoegen';

  @override
  String get tabAccount => 'Account';

  @override
  String get profileSettingsTitle => 'Instellingen';

  @override
  String get profileSettingsLanguageLabel => 'Taal';

  @override
  String get profileSettingsLanguageDescription =>
      'Kies een taal of volg je apparaatinstellingen.';

  @override
  String get profileLanguageSystemDefault => 'Apparaattaal';

  @override
  String get profileLoadErrorDefault => 'Profiel laden mislukt.';

  @override
  String get profileRefreshPage => 'Pagina vernieuwen';

  @override
  String get profileRetry => 'Opnieuw proberen';

  @override
  String get profileSignInTitle => 'Log in om je account te gebruiken';

  @override
  String get profileSignInSubtitle =>
      'Log in om je spots te beheren en locaties te beoordelen.';

  @override
  String get profileSignInButton => 'Inloggen';

  @override
  String get profileOrDivider => 'OF';

  @override
  String get profileCreateAccount => 'Account aanmaken';

  @override
  String get profileDefaultDisplayName => 'Gebruiker';

  @override
  String get profileViewEditSubtitle => 'Profiel bekijken en bewerken';

  @override
  String get profileModeratorSectionTitle => 'Moderator';

  @override
  String get profileModeratorToolsTitle => 'Moderatortools';

  @override
  String get profileModeratorToolsSubtitle =>
      'Inkomende spotmeldingen bekijken en afhandelen';

  @override
  String get profileAdminSectionTitle => 'Beheerder';

  @override
  String get profileAdminToolsTitle => 'Beheerderstools';

  @override
  String get profileAdminToolsSubtitle => 'Bronnen en beheertaken beheren';

  @override
  String get profileSignOut => 'Uitloggen';

  @override
  String get profileSignOutMessage => 'Weet je zeker dat je wilt uitloggen?';

  @override
  String get profileCancel => 'Annuleren';

  @override
  String get profileAboutIntro =>
      'Parkour·Spot is een community-app om parkour- en freerunningspots wereldwijd te ontdekken en te delen. We maken het eenvoudig om goede locaties te vinden—waar je ook traint.';

  @override
  String get profileReadMore => 'Meer lezen';

  @override
  String get profileAboutStoryBeforeName => 'Begonnen door ';

  @override
  String get profileAboutStoryAfterName =>
      ' uit de Utrechtse parkourcommunity: de app brengt lokale kennis van bestaande stads- en regionale kaarten samen—of die nu op Facebook, Instagram, websites of in oude apps stonden—zodat goede spotdata niet verloren gaat.';

  @override
  String get profileAboutMapMission =>
      'Dit is jouw kaart. Voeg nieuwe spots toe, beoordeel bestaande en verrijk vermeldingen met details. Hoe meer we bijdragen, hoe sterker de gedeelde kennis van de community wordt.';

  @override
  String get profileAboutPrinciplesHeader => 'Onze principes:';

  @override
  String get profileAboutPrincipleTransparency =>
      '• Transparantie: je kunt de app doorbladeren zonder account, en elke spot toont welke externe bronnen hebben bijgedragen.';

  @override
  String get profileAboutPrinciplePortability =>
      '• Draagbaarheid: we bouwen exporttools zodat spotdata ook buiten de app bruikbaar is.';

  @override
  String get profileAboutPrincipleOpenSource =>
      '• Open source: de app is van de community, niet afhankelijk van één persoon.';

  @override
  String get profileAboutEnjoy =>
      'Veel plezier met het ontdekken en delen van spots met Parkour.spot. Vragen of ideeën? Tik op contact—we horen graag van je.';

  @override
  String get profileCreditsBy => 'Grote bijdragen van ';

  @override
  String get profileCreditsDaphneArt => ' (illustratie), ';

  @override
  String get profileCreditsComma => ', ';

  @override
  String get profileCreditsEnd => ' en vele anderen.';

  @override
  String get profileViewSourceCode => 'Broncode bekijken';

  @override
  String get profileContactUs => 'Contact';

  @override
  String get profileReportIssue => 'Probleem melden';

  @override
  String get profileInstallBannerTitle => 'Installeer de Parkour·Spot-app';

  @override
  String get profileInstallBannerSubtitle => 'De volledige app-ervaring';

  @override
  String get profileInstallDialogTitle => 'Parkour·Spot installeren';

  @override
  String profileInstallIntro(String device) {
    return 'Om Parkour·Spot op je $device te installeren:';
  }

  @override
  String get profileInstallDeviceIphone => 'iPhone';

  @override
  String get profileInstallDeviceAndroid => 'Android-apparaat';

  @override
  String get profileInstallIosStep1 => 'Tik onderaan op de Deel-knop';

  @override
  String get profileInstallIosStep2 =>
      'Scroll naar beneden en tik op ‘Zet op beginscherm’';

  @override
  String get profileInstallIosStep3 => 'Tik rechtsboven op ‘Voeg toe’';

  @override
  String get profileInstallIosStep4 => 'De app verschijnt op je beginscherm!';

  @override
  String get profileInstallAndroidStep1 => 'Tik rechtsboven op het menu (⋯)';

  @override
  String get profileInstallAndroidStep2 => 'Tik op ‘Toevoegen aan startscherm’';

  @override
  String get profileInstallAndroidStep3 => 'Tik op ‘App installeren’';

  @override
  String get profileInstallAndroidStep4 =>
      'De app verschijnt op je startscherm!';

  @override
  String get profileInstallGotIt => 'Begrepen';

  @override
  String get exploreMetaDefaultTitle => 'Parkour·Spot';

  @override
  String get exploreMetaDefaultDescription =>
      'Ontdek, breng in kaart en deel de beste parkour-spots wereldwijd met communityfoto\'s, beoordelingen en lokale tips voor je volgende training.';

  @override
  String exploreMetaTitleCityCountry(String city, String country) {
    return 'Beste parkour-spots in $city, $country';
  }

  @override
  String exploreMetaDescriptionCityCountry(String city, String country) {
    return 'Ontdek de beste parkour-spots in $city, $country. Vind trainingsplekken, deel je favoriete spots en maak contact met de parkour-community.';
  }

  @override
  String exploreMetaTitleCountry(String country) {
    return 'Beste parkour-spots in $country';
  }

  @override
  String exploreMetaDescriptionCountry(String country) {
    return 'Ontdek de beste parkour-spots in $country. Vind trainingsplekken, deel je favoriete spots en maak contact met de parkour-community.';
  }

  @override
  String get exploreAddSpotTitle => 'Nieuwe spot toevoegen';

  @override
  String get exploreAddSpotSubtitle =>
      'Deel je favoriete parkour-spots met de community';

  @override
  String get exploreSignInToAddSpot => 'Log in om een spot toe te voegen';

  @override
  String get exploreLoadingProfile => 'Profiel laden…';

  @override
  String get exploreSearchHint => 'Zoek locatie of spot…';

  @override
  String get exploreFilterBy => 'Filteren op';

  @override
  String get exploreFilterAmenities => 'Voorzieningen';

  @override
  String get exploreFilterSources => 'Bronnen';

  @override
  String get exploreSpotAccessTitle => 'Spottoegang';

  @override
  String get exploreSpotAccessSubtitle => 'Filter spots op toegangsniveau';

  @override
  String get exploreFilterAny => 'Alle';

  @override
  String get exploreSpotFacilitiesTitle => 'Spotvoorzieningen';

  @override
  String get exploreSpotFacilitiesSubtitle =>
      'Toon spots met deze voorzieningen';

  @override
  String get exploreAttributesTitle => 'Met een van deze kenmerken';

  @override
  String get exploreAttributesSubtitle =>
      'Filter spots die minstens een van de gekozen skills of features hebben';

  @override
  String get exploreGoodForSegment => 'Geschikt voor';

  @override
  String get exploreSpotFeaturesSegment => 'Spotfeatures';

  @override
  String get exploreSpotSourceLabel => 'Spotbron';

  @override
  String get exploreSourcesLoadError => 'Bronnen laden mislukt';

  @override
  String get exploreAllSources => 'Alle bronnen';

  @override
  String get exploreParkourSpotNative => 'Parkour·Spot (native)';

  @override
  String get exploreAllFolders => 'Alle mappen';

  @override
  String exploreLocationError(String error) {
    return 'Fout bij ophalen locatie: $error';
  }

  @override
  String get exploreCurrentLocationSnackbar => 'Dit is je huidige locatie';

  @override
  String get exploreCloseTooltip => 'Sluiten';

  @override
  String get exploreClearSearchTooltip => 'Wissen';

  @override
  String get exploreFiltersTooltip => 'Filters';

  @override
  String get exploreFindingLocation => 'Locatie zoeken…';

  @override
  String get exploreAddSpotHereTitle => 'Spot op deze locatie toevoegen?';

  @override
  String exploreMapRankedTotalBar(int total) {
    return '$total spots';
  }

  @override
  String exploreMapSpotsFoundLine(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count spots gevonden',
      one: '1 spot gevonden',
    );
    return '$_temp0';
  }

  @override
  String exploreMapBestShownParenthetical(int count) {
    return ' ($count beste getoond)';
  }

  @override
  String get exploreNoSpotsSearch => 'Geen spots gevonden';

  @override
  String get exploreNoSpotsArea => 'Geen spots in dit gebied';

  @override
  String get exploreNoSpotsSearchHint => 'Pas je zoektermen aan';

  @override
  String get exploreNoSpotsMapHint =>
      'Verplaats de kaart om andere gebieden te verkennen';

  @override
  String get exploreRefreshMapTooltip => 'Spots in huidig beeld vernieuwen';

  @override
  String get exploreSwitchToMap => 'Naar kaart';

  @override
  String get exploreSwitchToSatellite => 'Naar satelliet';

  @override
  String get exploreLocationPermissionDenied => 'Locatietoegang geweigerd';

  @override
  String get exploreCenterOnMyLocation => 'Centreren op mijn locatie';

  @override
  String get exploreFiltersDialogTitle => 'Filters';

  @override
  String get exploreClearFilters => 'Wissen';

  @override
  String get exploreApplyFilters => 'Toepassen';

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
  String get explorePwaBannerInstall => 'Installeren';
}
