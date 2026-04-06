// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get tabExplore => 'Explore';

  @override
  String get tabAddSpot => 'Add Spot';

  @override
  String get tabAccount => 'Account';

  @override
  String get profileSettingsTitle => 'Settings';

  @override
  String get profileSettingsLanguageLabel => 'Language';

  @override
  String get profileSettingsLanguageDescription =>
      'Choose a language or follow your device settings.';

  @override
  String get profileLanguageSystemDefault => 'Device language';

  @override
  String get profileLoadErrorDefault => 'Failed to load profile.';

  @override
  String get profileRefreshPage => 'Refresh page';

  @override
  String get profileRetry => 'Retry';

  @override
  String get profileSignInTitle => 'Sign in to access your account';

  @override
  String get profileSignInSubtitle =>
      'Sign in to manage your spots and rate locations.';

  @override
  String get profileSignInButton => 'Sign In';

  @override
  String get profileOrDivider => 'OR';

  @override
  String get profileCreateAccount => 'Create an Account';

  @override
  String get profileDefaultDisplayName => 'User';

  @override
  String get profileViewEditSubtitle => 'View and edit your profile';

  @override
  String get profileModeratorSectionTitle => 'Moderator';

  @override
  String get profileModeratorToolsTitle => 'Moderator Tools';

  @override
  String get profileModeratorToolsSubtitle =>
      'Review and resolve incoming spot reports';

  @override
  String get profileAdminSectionTitle => 'Administrator';

  @override
  String get profileAdminToolsTitle => 'Admin Tools';

  @override
  String get profileAdminToolsSubtitle =>
      'Manage sources and administrative tasks';

  @override
  String get profileSignOut => 'Sign Out';

  @override
  String get profileSignOutMessage => 'Are you sure you want to sign out?';

  @override
  String get profileCancel => 'Cancel';

  @override
  String get profileAboutIntro =>
      'Parkour·Spot is a community-driven app for discovering and sharing parkour and freerunning spots worldwide. We\'re making it simple to find quality locations—wherever you train.';

  @override
  String get profileReadMore => 'Read more';

  @override
  String get profileAboutStoryBeforeName => 'Started by ';

  @override
  String get profileAboutStoryAfterName =>
      ' from the Utrecht parkour community, the app brings together local knowledge from existing city and regional maps—whether they lived on Facebook, Instagram, websites, or retired apps—so great spot data doesn\'t get lost.';

  @override
  String get profileAboutMapMission =>
      'This is your map. Add new spots, rate existing ones, and enrich listings with details. The more we contribute, the stronger the community\'s shared knowledge becomes.';

  @override
  String get profileAboutPrinciplesHeader => 'Our principles:';

  @override
  String get profileAboutPrincipleTransparency =>
      '• Transparency: you can browse the app without an account, and each spot shows which external sources contributed to it.';

  @override
  String get profileAboutPrinciplePortability =>
      '• Portability: we\'re building export tools so spot data can be used beyond the app.';

  @override
  String get profileAboutPrincipleOpenSource =>
      '• Open source: the app is community-owned, not dependent on one person.';

  @override
  String get profileAboutEnjoy =>
      'Enjoy discovering and sharing spots with Parkour.spot. Questions or ideas? Tap the contact button—we\'d love to hear from you.';

  @override
  String get profileCreditsBy => 'Major contributions by ';

  @override
  String get profileCreditsDaphneArt => ' (art), ';

  @override
  String get profileCreditsComma => ', ';

  @override
  String get profileCreditsEnd => ' and many others.';

  @override
  String get profileViewSourceCode => 'View source code';

  @override
  String get profileContactUs => 'Contact us';

  @override
  String get profileReportIssue => 'Report an issue';

  @override
  String get profileInstallBannerTitle => 'Install the Parkour·Spot app';

  @override
  String get profileInstallBannerSubtitle => 'Get the full app experience';

  @override
  String get profileInstallDialogTitle => 'Install Parkour·Spot';

  @override
  String profileInstallIntro(String device) {
    return 'To install Parkour·Spot on your $device:';
  }

  @override
  String get profileInstallDeviceIphone => 'iPhone';

  @override
  String get profileInstallDeviceAndroid => 'Android device';

  @override
  String get profileInstallIosStep1 =>
      'Tap the Share button at the bottom of the screen';

  @override
  String get profileInstallIosStep2 =>
      'Scroll down and tap \"Add to Home Screen\"';

  @override
  String get profileInstallIosStep3 => 'Tap \"Add\" in the top right corner';

  @override
  String get profileInstallIosStep4 =>
      'The app will appear on your home screen!';

  @override
  String get profileInstallAndroidStep1 =>
      'Tap the More menu (⋯) in the top right corner';

  @override
  String get profileInstallAndroidStep2 => 'Tap \"Add to home screen\"';

  @override
  String get profileInstallAndroidStep3 => 'Tap \"Install app\"';

  @override
  String get profileInstallAndroidStep4 =>
      'The app will appear on your home screen!';

  @override
  String get profileInstallGotIt => 'Got it';

  @override
  String get exploreMetaDefaultTitle => 'Parkour·Spot';

  @override
  String get exploreMetaDefaultDescription =>
      'Discover, map, and share the best parkour spots worldwide with community photos, ratings, and local tips for your next training session.';

  @override
  String exploreMetaTitleCityCountry(String city, String country) {
    return 'Best parkour spots in $city, $country';
  }

  @override
  String exploreMetaDescriptionCityCountry(String city, String country) {
    return 'Discover the best parkour spots in $city, $country. Find training locations, share your favorite spots, and connect with the parkour community.';
  }

  @override
  String exploreMetaTitleCountry(String country) {
    return 'Best parkour spots in $country';
  }

  @override
  String exploreMetaDescriptionCountry(String country) {
    return 'Discover the best parkour spots in $country. Find training locations, share your favorite spots, and connect with the parkour community.';
  }

  @override
  String get exploreAddSpotTitle => 'Add New Spot';

  @override
  String get exploreAddSpotSubtitle =>
      'Share your favorite parkour spots with the community';

  @override
  String get exploreSignInToAddSpot => 'Sign in to add a spot';

  @override
  String get exploreLoadingProfile => 'Loading your profile…';

  @override
  String get exploreSearchHint => 'Search location or spot…';

  @override
  String get exploreFilterBy => 'Filter by';

  @override
  String get exploreFilterAmenities => 'Amenities';

  @override
  String get exploreFilterSources => 'Sources';

  @override
  String get exploreSpotAccessTitle => 'Spot Access';

  @override
  String get exploreSpotAccessSubtitle => 'Filter spots by access level';

  @override
  String get exploreFilterAny => 'Any';

  @override
  String get exploreSpotFacilitiesTitle => 'Spot Facilities';

  @override
  String get exploreSpotFacilitiesSubtitle => 'Show spots with these amenities';

  @override
  String get exploreAttributesTitle => 'With any of these attributes';

  @override
  String get exploreAttributesSubtitle =>
      'Filter spots that have any of the selected skills or features';

  @override
  String get exploreGoodForSegment => 'Good For';

  @override
  String get exploreSpotFeaturesSegment => 'Spot Features';

  @override
  String get exploreSpotSourceLabel => 'Spot Source';

  @override
  String get exploreSourcesLoadError => 'Failed to load sources';

  @override
  String get exploreAllSources => 'All Sources';

  @override
  String get exploreParkourSpotNative => 'Parkour·Spot (Native)';

  @override
  String get exploreAllFolders => 'All Folders';

  @override
  String exploreLocationError(String error) {
    return 'Error getting location: $error';
  }

  @override
  String get exploreCurrentLocationSnackbar => 'This is your current location';

  @override
  String get exploreCloseTooltip => 'Close';

  @override
  String get exploreClearSearchTooltip => 'Clear';

  @override
  String get exploreFiltersTooltip => 'Filters';

  @override
  String get exploreFindingLocation => 'Finding location...';

  @override
  String get exploreAddSpotHereTitle => 'Add spot at this location?';

  @override
  String exploreMapRankedTotalBar(int total) {
    return '$total spots';
  }

  @override
  String exploreMapSpotsFoundLine(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count spots found',
      one: '1 spot found',
    );
    return '$_temp0';
  }

  @override
  String exploreMapBestShownParenthetical(int count) {
    return ' ($count best shown)';
  }

  @override
  String get exploreNoSpotsSearch => 'No spots found';

  @override
  String get exploreNoSpotsArea => 'No spots in this area';

  @override
  String get exploreNoSpotsSearchHint => 'Try adjusting your search terms';

  @override
  String get exploreNoSpotsMapHint => 'Move the map to explore different areas';

  @override
  String get exploreRefreshMapTooltip => 'Refresh spots in current view';

  @override
  String get exploreSwitchToMap => 'Switch to Map';

  @override
  String get exploreSwitchToSatellite => 'Switch to Satellite';

  @override
  String get exploreLocationPermissionDenied => 'Location permission denied';

  @override
  String get exploreCenterOnMyLocation => 'Center on my location';

  @override
  String get exploreFiltersDialogTitle => 'Filters';

  @override
  String get exploreClearFilters => 'Clear';

  @override
  String get exploreApplyFilters => 'Apply';

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
  String get explorePwaBannerInstall => 'Install';

  @override
  String get addSpotPickImagesFailed =>
      'Failed to pick images. Please try again.';

  @override
  String get addSpotTakePhotoFailed =>
      'Failed to take photo. Please try again.';

  @override
  String get addSpotNeedPhoto => 'Please upload at least one photo of the spot';

  @override
  String get addSpotNeedLocation =>
      'Please wait for location to be determined or pick a location on the map';

  @override
  String addSpotCreateError(String error) {
    return 'Error creating spot: $error';
  }

  @override
  String get addSpotNameLabel => 'Spot Name *';

  @override
  String get addSpotNameRequired => 'Please enter a spot name';

  @override
  String get addSpotDescriptionLabel => 'Description *';

  @override
  String get addSpotDescriptionRequired => 'Please enter a description';

  @override
  String get addSpotDescriptionMinLength =>
      'Description must be at least 10 characters';

  @override
  String get addSpotCreating => 'Creating Spot...';

  @override
  String get addSpotCreateButton => 'Create Spot';

  @override
  String get addSpotLocationSectionTitle => 'Select Spot Location';

  @override
  String get addSpotGettingLocation => 'Getting your location...';

  @override
  String get addSpotLocationNotAvailable => 'Location not available';

  @override
  String get addSpotPickLocationHint => 'Pick location';

  @override
  String get addSpotImagesSectionTitle => 'Select Spot Images';

  @override
  String get addSpotGalleryButton => 'Gallery';

  @override
  String get addSpotCameraButton => 'Camera';

  @override
  String get addSpotGoodForTitle => 'Good For';

  @override
  String get addSpotGoodForSubtitle =>
      'What parkour skills can be practiced here?';

  @override
  String get addSpotFeaturesTitle => 'Spot Features';

  @override
  String get addSpotFeaturesSubtitle =>
      'What physical features does this spot have?';

  @override
  String get addSpotAccessTitle => 'Spot Access';

  @override
  String get addSpotAccessSubtitle => 'What is the access level for this spot?';

  @override
  String get addSpotFacilitiesFormTitle => 'Spot Facilities';

  @override
  String get addSpotFacilitiesSubtitle =>
      'What amenities are available at this spot?';

  @override
  String get addSpotLongPressHintSkill => 'Long press any skill for more info';

  @override
  String get addSpotLongPressHintFeature =>
      'Long press any feature for more info';

  @override
  String get addSpotLongPressHintFacility =>
      'Long press any facility for more info';

  @override
  String get addSpotPickLocationAppBarTitle => 'Pick Location';

  @override
  String get addSpotTipLongPressMobile =>
      'Tip: You can also add spots from the Explore map by long-pressing on any location.';

  @override
  String get addSpotTipRightClickDesktop =>
      'Tip: You can also add spots from the Explore map by right-clicking on any location.';

  @override
  String get addSpotUseThisLocation => 'Use this location';

  @override
  String get addSpotDirectionsTooltip => 'Directions';

  @override
  String get addSpotGettingAddress => 'Getting address...';
}
