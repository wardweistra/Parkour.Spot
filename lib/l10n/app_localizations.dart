import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_de.dart';
import 'app_localizations_en.dart';
import 'app_localizations_es.dart';
import 'app_localizations_fr.dart';
import 'app_localizations_nl.dart';
import 'app_localizations_pt.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppLocalizations
/// returned by `AppLocalizations.of(context)`.
///
/// Applications need to include `AppLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'l10n/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: AppLocalizations.localizationsDelegates,
///   supportedLocales: AppLocalizations.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the AppLocalizations.supportedLocales
/// property.
abstract class AppLocalizations {
  AppLocalizations(String locale)
    : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppLocalizations? of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations);
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates =
      <LocalizationsDelegate<dynamic>>[
        delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
      ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[
    Locale('en'),
    Locale('de'),
    Locale('es'),
    Locale('fr'),
    Locale('nl'),
    Locale('pt'),
  ];

  /// Bottom navigation: map and search tab
  ///
  /// In en, this message translates to:
  /// **'Explore'**
  String get tabExplore;

  /// Bottom navigation: submit a new spot
  ///
  /// In en, this message translates to:
  /// **'Add Spot'**
  String get tabAddSpot;

  /// Bottom navigation: profile and settings
  ///
  /// In en, this message translates to:
  /// **'Account'**
  String get tabAccount;

  /// Profile: settings card title
  ///
  /// In en, this message translates to:
  /// **'Settings'**
  String get profileSettingsTitle;

  /// Profile settings: language row label
  ///
  /// In en, this message translates to:
  /// **'Language'**
  String get profileSettingsLanguageLabel;

  /// Profile settings: short hint for language control
  ///
  /// In en, this message translates to:
  /// **'Choose a language or follow your device settings.'**
  String get profileSettingsLanguageDescription;

  /// Use OS/browser locale resolution instead of a fixed app language
  ///
  /// In en, this message translates to:
  /// **'Device language'**
  String get profileLanguageSystemDefault;

  /// Account tab: shown when profile could not be loaded
  ///
  /// In en, this message translates to:
  /// **'Failed to load profile.'**
  String get profileLoadErrorDefault;

  /// Account tab error: reload on web
  ///
  /// In en, this message translates to:
  /// **'Refresh page'**
  String get profileRefreshPage;

  /// Account tab error: retry loading profile on native
  ///
  /// In en, this message translates to:
  /// **'Retry'**
  String get profileRetry;

  /// Account tab signed-out: card heading
  ///
  /// In en, this message translates to:
  /// **'Sign in to access your account'**
  String get profileSignInTitle;

  /// Account tab signed-out: supporting text
  ///
  /// In en, this message translates to:
  /// **'Sign in to manage your spots and rate locations.'**
  String get profileSignInSubtitle;

  /// Account tab: primary sign-in button
  ///
  /// In en, this message translates to:
  /// **'Sign In'**
  String get profileSignInButton;

  /// Account tab: divider between sign-in and sign-up
  ///
  /// In en, this message translates to:
  /// **'OR'**
  String get profileOrDivider;

  /// Account tab: secondary sign-up button
  ///
  /// In en, this message translates to:
  /// **'Create an Account'**
  String get profileCreateAccount;

  /// Fallback display name when missing
  ///
  /// In en, this message translates to:
  /// **'User'**
  String get profileDefaultDisplayName;

  /// Account card subtitle linking to full profile
  ///
  /// In en, this message translates to:
  /// **'View and edit your profile'**
  String get profileViewEditSubtitle;

  /// Account tab: moderator section heading
  ///
  /// In en, this message translates to:
  /// **'Moderator'**
  String get profileModeratorSectionTitle;

  /// Account tab: moderator tools row title
  ///
  /// In en, this message translates to:
  /// **'Moderator Tools'**
  String get profileModeratorToolsTitle;

  /// Account tab: moderator tools row subtitle
  ///
  /// In en, this message translates to:
  /// **'Review and resolve incoming spot reports'**
  String get profileModeratorToolsSubtitle;

  /// Account tab: admin section heading
  ///
  /// In en, this message translates to:
  /// **'Administrator'**
  String get profileAdminSectionTitle;

  /// Account tab: admin tools row title
  ///
  /// In en, this message translates to:
  /// **'Admin Tools'**
  String get profileAdminToolsTitle;

  /// Account tab: admin tools row subtitle
  ///
  /// In en, this message translates to:
  /// **'Manage sources and administrative tasks'**
  String get profileAdminToolsSubtitle;

  /// Account tab: sign out button and dialog action
  ///
  /// In en, this message translates to:
  /// **'Sign Out'**
  String get profileSignOut;

  /// Account tab: sign out confirmation body
  ///
  /// In en, this message translates to:
  /// **'Are you sure you want to sign out?'**
  String get profileSignOutMessage;

  /// Dismiss dialog without action
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get profileCancel;

  /// About section: short intro paragraph
  ///
  /// In en, this message translates to:
  /// **'Parkour·Spot is a community-driven app for discovering and sharing parkour and freerunning spots worldwide. We\'re making it simple to find quality locations—wherever you train.'**
  String get profileAboutIntro;

  /// About section: expand long text
  ///
  /// In en, this message translates to:
  /// **'Read more'**
  String get profileReadMore;

  /// About expanded: text before founder name link (keep trailing space)
  ///
  /// In en, this message translates to:
  /// **'Started by '**
  String get profileAboutStoryBeforeName;

  /// About expanded: story after founder name
  ///
  /// In en, this message translates to:
  /// **' from the Utrecht parkour community, the app brings together local knowledge from existing city and regional maps—whether they lived on Facebook, Instagram, websites, or retired apps—so great spot data doesn\'t get lost.'**
  String get profileAboutStoryAfterName;

  /// About expanded: community map paragraph
  ///
  /// In en, this message translates to:
  /// **'This is your map. Add new spots, rate existing ones, and enrich listings with details. The more we contribute, the stronger the community\'s shared knowledge becomes.'**
  String get profileAboutMapMission;

  /// About expanded: principles list heading
  ///
  /// In en, this message translates to:
  /// **'Our principles:'**
  String get profileAboutPrinciplesHeader;

  /// About expanded: transparency bullet
  ///
  /// In en, this message translates to:
  /// **'• Transparency: you can browse the app without an account, and each spot shows which external sources contributed to it.'**
  String get profileAboutPrincipleTransparency;

  /// About expanded: portability bullet
  ///
  /// In en, this message translates to:
  /// **'• Portability: we\'re building export tools so spot data can be used beyond the app.'**
  String get profileAboutPrinciplePortability;

  /// About expanded: open source bullet
  ///
  /// In en, this message translates to:
  /// **'• Open source: the app is community-owned, not dependent on one person.'**
  String get profileAboutPrincipleOpenSource;

  /// About expanded: closing encouragement
  ///
  /// In en, this message translates to:
  /// **'Enjoy discovering and sharing spots with Parkour.spot. Questions or ideas? Tap the contact button—we\'d love to hear from you.'**
  String get profileAboutEnjoy;

  /// Credits line before names (keep trailing space)
  ///
  /// In en, this message translates to:
  /// **'Major contributions by '**
  String get profileCreditsBy;

  /// After Daphne's name: role and separator
  ///
  /// In en, this message translates to:
  /// **' (art), '**
  String get profileCreditsDaphneArt;

  /// Separator between contributor names
  ///
  /// In en, this message translates to:
  /// **', '**
  String get profileCreditsComma;

  /// End of credits line
  ///
  /// In en, this message translates to:
  /// **' and many others.'**
  String get profileCreditsEnd;

  /// About section: GitHub button
  ///
  /// In en, this message translates to:
  /// **'View source code'**
  String get profileViewSourceCode;

  /// About section: email button
  ///
  /// In en, this message translates to:
  /// **'Contact us'**
  String get profileContactUs;

  /// About section: GitHub issues button
  ///
  /// In en, this message translates to:
  /// **'Report an issue'**
  String get profileReportIssue;

  /// About section: link to translation contribution (Crowdin or similar)
  ///
  /// In en, this message translates to:
  /// **'Help translate the app'**
  String get profileHelpTranslate;

  /// Account tab: PWA install card title
  ///
  /// In en, this message translates to:
  /// **'Install the Parkour·Spot app'**
  String get profileInstallBannerTitle;

  /// Account tab: PWA install card subtitle
  ///
  /// In en, this message translates to:
  /// **'Get the full app experience'**
  String get profileInstallBannerSubtitle;

  /// PWA install instructions dialog title
  ///
  /// In en, this message translates to:
  /// **'Install Parkour·Spot'**
  String get profileInstallDialogTitle;

  /// PWA install dialog: intro before steps
  ///
  /// In en, this message translates to:
  /// **'To install Parkour·Spot on your {device}:'**
  String profileInstallIntro(String device);

  /// Device name for iOS install instructions
  ///
  /// In en, this message translates to:
  /// **'iPhone'**
  String get profileInstallDeviceIphone;

  /// Device name for Android install instructions
  ///
  /// In en, this message translates to:
  /// **'Android device'**
  String get profileInstallDeviceAndroid;

  /// PWA install iOS step 1
  ///
  /// In en, this message translates to:
  /// **'Tap the Share button at the bottom of the screen'**
  String get profileInstallIosStep1;

  /// PWA install iOS step 2
  ///
  /// In en, this message translates to:
  /// **'Scroll down and tap \"Add to Home Screen\"'**
  String get profileInstallIosStep2;

  /// PWA install iOS step 3
  ///
  /// In en, this message translates to:
  /// **'Tap \"Add\" in the top right corner'**
  String get profileInstallIosStep3;

  /// PWA install iOS step 4
  ///
  /// In en, this message translates to:
  /// **'The app will appear on your home screen!'**
  String get profileInstallIosStep4;

  /// PWA install Android step 1
  ///
  /// In en, this message translates to:
  /// **'Tap the More menu (⋯) in the top right corner'**
  String get profileInstallAndroidStep1;

  /// PWA install Android step 2
  ///
  /// In en, this message translates to:
  /// **'Tap \"Add to home screen\"'**
  String get profileInstallAndroidStep2;

  /// PWA install Android step 3
  ///
  /// In en, this message translates to:
  /// **'Tap \"Install app\"'**
  String get profileInstallAndroidStep3;

  /// PWA install Android step 4
  ///
  /// In en, this message translates to:
  /// **'The app will appear on your home screen!'**
  String get profileInstallAndroidStep4;

  /// Close PWA install instructions dialog
  ///
  /// In en, this message translates to:
  /// **'Got it'**
  String get profileInstallGotIt;

  /// Web: default document title when leaving a location page
  ///
  /// In en, this message translates to:
  /// **'Parkour·Spot'**
  String get exploreMetaDefaultTitle;

  /// Web: default meta description when leaving a location page
  ///
  /// In en, this message translates to:
  /// **'Discover, map, and share the best parkour spots worldwide with community photos, ratings, and local tips for your next training session.'**
  String get exploreMetaDefaultDescription;

  /// Web SEO title for city pages
  ///
  /// In en, this message translates to:
  /// **'Best parkour spots in {city}, {country}'**
  String exploreMetaTitleCityCountry(String city, String country);

  /// Web SEO description for city pages
  ///
  /// In en, this message translates to:
  /// **'Discover the best parkour spots in {city}, {country}. Find training locations, share your favorite spots, and connect with the parkour community.'**
  String exploreMetaDescriptionCityCountry(String city, String country);

  /// Web SEO title for country-only pages
  ///
  /// In en, this message translates to:
  /// **'Best parkour spots in {country}'**
  String exploreMetaTitleCountry(String country);

  /// Web SEO description for country-only pages
  ///
  /// In en, this message translates to:
  /// **'Discover the best parkour spots in {country}. Find training locations, share your favorite spots, and connect with the parkour community.'**
  String exploreMetaDescriptionCountry(String country);

  /// Add spot tab: heading when not signed in
  ///
  /// In en, this message translates to:
  /// **'Add New Spot'**
  String get exploreAddSpotTitle;

  /// Add spot tab: supporting text when not signed in
  ///
  /// In en, this message translates to:
  /// **'Share your favorite parkour spots with the community'**
  String get exploreAddSpotSubtitle;

  /// Add spot tab: sign-in prompt title
  ///
  /// In en, this message translates to:
  /// **'Sign in to add a spot'**
  String get exploreSignInToAddSpot;

  /// Shown while profile loads before add spot
  ///
  /// In en, this message translates to:
  /// **'Loading your profile…'**
  String get exploreLoadingProfile;

  /// Map search field placeholder
  ///
  /// In en, this message translates to:
  /// **'Search location or spot…'**
  String get exploreSearchHint;

  /// Filters: section label
  ///
  /// In en, this message translates to:
  /// **'Filter by'**
  String get exploreFilterBy;

  /// Filter mode: amenities
  ///
  /// In en, this message translates to:
  /// **'Amenities'**
  String get exploreFilterAmenities;

  /// Filter mode: data sources
  ///
  /// In en, this message translates to:
  /// **'Sources'**
  String get exploreFilterSources;

  /// Filter card: access
  ///
  /// In en, this message translates to:
  /// **'Spot Access'**
  String get exploreSpotAccessTitle;

  /// Filter card: access description
  ///
  /// In en, this message translates to:
  /// **'Filter spots by access level'**
  String get exploreSpotAccessSubtitle;

  /// Access filter: any access level
  ///
  /// In en, this message translates to:
  /// **'Any'**
  String get exploreFilterAny;

  /// Filter card: facilities
  ///
  /// In en, this message translates to:
  /// **'Spot Facilities'**
  String get exploreSpotFacilitiesTitle;

  /// Filter card: facilities description
  ///
  /// In en, this message translates to:
  /// **'Show spots with these amenities'**
  String get exploreSpotFacilitiesSubtitle;

  /// Filter card: skills/features
  ///
  /// In en, this message translates to:
  /// **'With any of these attributes'**
  String get exploreAttributesTitle;

  /// Filter card: skills/features description
  ///
  /// In en, this message translates to:
  /// **'Filter spots that have any of the selected skills or features'**
  String get exploreAttributesSubtitle;

  /// Attribute filter: good-for mode
  ///
  /// In en, this message translates to:
  /// **'Good For'**
  String get exploreGoodForSegment;

  /// Attribute filter: features mode
  ///
  /// In en, this message translates to:
  /// **'Spot Features'**
  String get exploreSpotFeaturesSegment;

  /// Source filter section label
  ///
  /// In en, this message translates to:
  /// **'Spot Source'**
  String get exploreSpotSourceLabel;

  /// Error loading sync source list for filters
  ///
  /// In en, this message translates to:
  /// **'Failed to load sources'**
  String get exploreSourcesLoadError;

  /// Source filter: all sources option
  ///
  /// In en, this message translates to:
  /// **'All Sources'**
  String get exploreAllSources;

  /// Source filter: native app spots only
  ///
  /// In en, this message translates to:
  /// **'Parkour·Spot (Native)'**
  String get exploreParkourSpotNative;

  /// Source filter: all folders chip
  ///
  /// In en, this message translates to:
  /// **'All Folders'**
  String get exploreAllFolders;

  /// SnackBar when geolocation fails
  ///
  /// In en, this message translates to:
  /// **'Error getting location: {error}'**
  String exploreLocationError(String error);

  /// Shown when centering map on user location
  ///
  /// In en, this message translates to:
  /// **'This is your current location'**
  String get exploreCurrentLocationSnackbar;

  /// Close button tooltip
  ///
  /// In en, this message translates to:
  /// **'Close'**
  String get exploreCloseTooltip;

  /// Clear search field
  ///
  /// In en, this message translates to:
  /// **'Clear'**
  String get exploreClearSearchTooltip;

  /// Open filters
  ///
  /// In en, this message translates to:
  /// **'Filters'**
  String get exploreFiltersTooltip;

  /// Loading state in search
  ///
  /// In en, this message translates to:
  /// **'Finding location...'**
  String get exploreFindingLocation;

  /// Long-press map: add spot prompt
  ///
  /// In en, this message translates to:
  /// **'Add spot at this location?'**
  String get exploreAddSpotHereTitle;

  /// Bottom sheet: total spots in view when ranked
  ///
  /// In en, this message translates to:
  /// **'{total} spots'**
  String exploreMapRankedTotalBar(int total);

  /// Bottom sheet: how many spots matched (unranked summary)
  ///
  /// In en, this message translates to:
  /// **'{count, plural, one{1 spot found} other{{count} spots found}}'**
  String exploreMapSpotsFoundLine(int count);

  /// Suffix when not all spots are listed
  ///
  /// In en, this message translates to:
  /// **' ({count} best shown)'**
  String exploreMapBestShownParenthetical(int count);

  /// Empty state when search has no results
  ///
  /// In en, this message translates to:
  /// **'No spots found'**
  String get exploreNoSpotsSearch;

  /// Empty state when map area has no spots
  ///
  /// In en, this message translates to:
  /// **'No spots in this area'**
  String get exploreNoSpotsArea;

  /// Empty state hint for search
  ///
  /// In en, this message translates to:
  /// **'Try adjusting your search terms'**
  String get exploreNoSpotsSearchHint;

  /// Empty state hint for map
  ///
  /// In en, this message translates to:
  /// **'Move the map to explore different areas'**
  String get exploreNoSpotsMapHint;

  /// FAB: reload spots
  ///
  /// In en, this message translates to:
  /// **'Refresh spots in current view'**
  String get exploreRefreshMapTooltip;

  /// FAB: from satellite to map
  ///
  /// In en, this message translates to:
  /// **'Switch to Map'**
  String get exploreSwitchToMap;

  /// FAB: to satellite/hybrid
  ///
  /// In en, this message translates to:
  /// **'Switch to Satellite'**
  String get exploreSwitchToSatellite;

  /// FAB tooltip when location blocked
  ///
  /// In en, this message translates to:
  /// **'Location permission denied'**
  String get exploreLocationPermissionDenied;

  /// FAB tooltip for my location
  ///
  /// In en, this message translates to:
  /// **'Center on my location'**
  String get exploreCenterOnMyLocation;

  /// Fullscreen filters panel title
  ///
  /// In en, this message translates to:
  /// **'Filters'**
  String get exploreFiltersDialogTitle;

  /// Reset all filters
  ///
  /// In en, this message translates to:
  /// **'Clear'**
  String get exploreClearFilters;

  /// Apply filters and close
  ///
  /// In en, this message translates to:
  /// **'Apply'**
  String get exploreApplyFilters;

  /// Spot list preview: spot count
  ///
  /// In en, this message translates to:
  /// **'{count, plural, one{1 spot} other{{count} spots}}'**
  String exploreSpotCountShort(int count);

  /// Compact install button on explore PWA banner
  ///
  /// In en, this message translates to:
  /// **'Install'**
  String get explorePwaBannerInstall;

  /// Add spot: gallery picker error
  ///
  /// In en, this message translates to:
  /// **'Failed to pick images. Please try again.'**
  String get addSpotPickImagesFailed;

  /// Add spot: camera error
  ///
  /// In en, this message translates to:
  /// **'Failed to take photo. Please try again.'**
  String get addSpotTakePhotoFailed;

  /// Add spot: validation
  ///
  /// In en, this message translates to:
  /// **'Please upload at least one photo of the spot'**
  String get addSpotNeedPhoto;

  /// Add spot: validation
  ///
  /// In en, this message translates to:
  /// **'Please wait for location to be determined or pick a location on the map'**
  String get addSpotNeedLocation;

  /// Add spot: submit failed
  ///
  /// In en, this message translates to:
  /// **'Error creating spot: {error}'**
  String addSpotCreateError(String error);

  /// Add spot: name field label
  ///
  /// In en, this message translates to:
  /// **'Spot Name *'**
  String get addSpotNameLabel;

  /// Add spot: name validation
  ///
  /// In en, this message translates to:
  /// **'Please enter a spot name'**
  String get addSpotNameRequired;

  /// Add spot: description label
  ///
  /// In en, this message translates to:
  /// **'Description *'**
  String get addSpotDescriptionLabel;

  /// Add spot: description validation empty
  ///
  /// In en, this message translates to:
  /// **'Please enter a description'**
  String get addSpotDescriptionRequired;

  /// Add spot: description validation length
  ///
  /// In en, this message translates to:
  /// **'Description must be at least 10 characters'**
  String get addSpotDescriptionMinLength;

  /// Add spot: submit in progress
  ///
  /// In en, this message translates to:
  /// **'Creating Spot...'**
  String get addSpotCreating;

  /// Add spot: primary submit
  ///
  /// In en, this message translates to:
  /// **'Create Spot'**
  String get addSpotCreateButton;

  /// Add spot: map card title
  ///
  /// In en, this message translates to:
  /// **'Select Spot Location'**
  String get addSpotLocationSectionTitle;

  /// Add spot: GPS loading row
  ///
  /// In en, this message translates to:
  /// **'Getting your location...'**
  String get addSpotGettingLocation;

  /// Add spot: no GPS
  ///
  /// In en, this message translates to:
  /// **'Location not available'**
  String get addSpotLocationNotAvailable;

  /// Add spot: overlay on mini map
  ///
  /// In en, this message translates to:
  /// **'Pick location'**
  String get addSpotPickLocationHint;

  /// Add spot: photos card title
  ///
  /// In en, this message translates to:
  /// **'Select Spot Images'**
  String get addSpotImagesSectionTitle;

  /// Add spot: choose from gallery
  ///
  /// In en, this message translates to:
  /// **'Gallery'**
  String get addSpotGalleryButton;

  /// Add spot: take photo
  ///
  /// In en, this message translates to:
  /// **'Camera'**
  String get addSpotCameraButton;

  /// Add spot attributes: good for card
  ///
  /// In en, this message translates to:
  /// **'Good For'**
  String get addSpotGoodForTitle;

  /// Add spot attributes: good for hint
  ///
  /// In en, this message translates to:
  /// **'What parkour skills can be practiced here?'**
  String get addSpotGoodForSubtitle;

  /// Add spot attributes: features card
  ///
  /// In en, this message translates to:
  /// **'Spot Features'**
  String get addSpotFeaturesTitle;

  /// Add spot attributes: features hint
  ///
  /// In en, this message translates to:
  /// **'What physical features does this spot have?'**
  String get addSpotFeaturesSubtitle;

  /// Add spot attributes: access card
  ///
  /// In en, this message translates to:
  /// **'Spot Access'**
  String get addSpotAccessTitle;

  /// Add spot attributes: access hint
  ///
  /// In en, this message translates to:
  /// **'What is the access level for this spot?'**
  String get addSpotAccessSubtitle;

  /// Add spot attributes: facilities card (form)
  ///
  /// In en, this message translates to:
  /// **'Spot Facilities'**
  String get addSpotFacilitiesFormTitle;

  /// Add spot attributes: facilities hint
  ///
  /// In en, this message translates to:
  /// **'What amenities are available at this spot?'**
  String get addSpotFacilitiesSubtitle;

  /// Add spot: long-press hint for good-for chips
  ///
  /// In en, this message translates to:
  /// **'Long press any skill for more info'**
  String get addSpotLongPressHintSkill;

  /// Add spot: long-press hint for feature chips
  ///
  /// In en, this message translates to:
  /// **'Long press any feature for more info'**
  String get addSpotLongPressHintFeature;

  /// Add spot: long-press hint for facilities
  ///
  /// In en, this message translates to:
  /// **'Long press any facility for more info'**
  String get addSpotLongPressHintFacility;

  /// Full-screen map: choose coordinates
  ///
  /// In en, this message translates to:
  /// **'Pick Location'**
  String get addSpotPickLocationAppBarTitle;

  /// Location picker hint on mobile
  ///
  /// In en, this message translates to:
  /// **'Tip: You can also add spots from the Explore map by long-pressing on any location.'**
  String get addSpotTipLongPressMobile;

  /// Location picker hint on desktop web
  ///
  /// In en, this message translates to:
  /// **'Tip: You can also add spots from the Explore map by right-clicking on any location.'**
  String get addSpotTipRightClickDesktop;

  /// Location picker: confirm FAB
  ///
  /// In en, this message translates to:
  /// **'Use this location'**
  String get addSpotUseThisLocation;

  /// Open in maps from address row
  ///
  /// In en, this message translates to:
  /// **'Directions'**
  String get addSpotDirectionsTooltip;

  /// While reverse-geocoding coordinates
  ///
  /// In en, this message translates to:
  /// **'Getting address...'**
  String get addSpotGettingAddress;

  /// Spot card: placeholder when spot has no photos
  ///
  /// In en, this message translates to:
  /// **'No images'**
  String get spotCardNoImages;

  /// Spot card: empty description
  ///
  /// In en, this message translates to:
  /// **'No description provided'**
  String get spotCardNoDescription;

  /// Spot card list chip: text before list name (keep trailing space)
  ///
  /// In en, this message translates to:
  /// **'Part of '**
  String get spotCardPartOfPrefix;

  /// Spot card: remove from editable list
  ///
  /// In en, this message translates to:
  /// **'Remove from list'**
  String get spotCardRemoveFromListTooltip;

  /// After copying share link
  ///
  /// In en, this message translates to:
  /// **'Spot copied to clipboard!'**
  String get spotCardCopiedToClipboard;

  /// Share or clipboard error
  ///
  /// In en, this message translates to:
  /// **'Failed to share spot: {error}'**
  String spotCardShareFailed(String error);

  /// Clipboard text when native share unavailable
  ///
  /// In en, this message translates to:
  /// **'{name} 👉 {url}'**
  String spotCardShareClipboardText(String name, String url);

  /// Badge when external source dropped the spot
  ///
  /// In en, this message translates to:
  /// **'Removed from source'**
  String get spotCardRemovedFromSource;

  /// Check-in tooltip when display name missing
  ///
  /// In en, this message translates to:
  /// **'This person'**
  String get spotCheckInUnnamedPerson;

  /// Avatar tooltip: public check-in
  ///
  /// In en, this message translates to:
  /// **'{name} is here now at this spot (until {time})'**
  String spotCheckInTooltipPublic(String name, String time);

  /// Avatar tooltip: private check-in
  ///
  /// In en, this message translates to:
  /// **'You\'re here now at this spot until {time} — only you can see this check-in'**
  String spotCheckInTooltipPrivate(String time);

  /// No description provided for @spotDetailRouteErrorLoading.
  ///
  /// In en, this message translates to:
  /// **'Error loading spot'**
  String get spotDetailRouteErrorLoading;

  /// No description provided for @spotDetailRouteTryAgainLater.
  ///
  /// In en, this message translates to:
  /// **'Please try again later'**
  String get spotDetailRouteTryAgainLater;

  /// No description provided for @spotDetailRouteNotFound.
  ///
  /// In en, this message translates to:
  /// **'Spot not found'**
  String get spotDetailRouteNotFound;

  /// No description provided for @spotDetailRouteGoToExplore.
  ///
  /// In en, this message translates to:
  /// **'Go to Explore'**
  String get spotDetailRouteGoToExplore;

  /// No description provided for @spotDetailCheckInVerifyFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not verify your check-ins'**
  String get spotDetailCheckInVerifyFailed;

  /// No description provided for @spotDetailCheckInEndPreviousFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not end your previous check-in'**
  String get spotDetailCheckInEndPreviousFailed;

  /// No description provided for @spotDetailCheckInSuccess.
  ///
  /// In en, this message translates to:
  /// **'You’re checked in'**
  String get spotDetailCheckInSuccess;

  /// No description provided for @spotDetailCheckInFailed.
  ///
  /// In en, this message translates to:
  /// **'Check-in failed'**
  String get spotDetailCheckInFailed;

  /// No description provided for @spotDetailCheckInRemoved.
  ///
  /// In en, this message translates to:
  /// **'Check-in removed'**
  String get spotDetailCheckInRemoved;

  /// No description provided for @spotDetailCheckInDeleteFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not delete check-in'**
  String get spotDetailCheckInDeleteFailed;

  /// No description provided for @spotDetailCheckInUpdated.
  ///
  /// In en, this message translates to:
  /// **'Check-in updated'**
  String get spotDetailCheckInUpdated;

  /// No description provided for @spotDetailCheckInUpdateFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not update check-in'**
  String get spotDetailCheckInUpdateFailed;

  /// No description provided for @spotDetailCheckInFabTooltipSignIn.
  ///
  /// In en, this message translates to:
  /// **'Sign in to check in'**
  String get spotDetailCheckInFabTooltipSignIn;

  /// No description provided for @spotDetailCheckInFabTooltipEdit.
  ///
  /// In en, this message translates to:
  /// **'Edit check-in'**
  String get spotDetailCheckInFabTooltipEdit;

  /// No description provided for @spotDetailCheckInFabTooltipCheckIn.
  ///
  /// In en, this message translates to:
  /// **'Check in'**
  String get spotDetailCheckInFabTooltipCheckIn;

  /// No description provided for @spotDetailSpotCreatedOnDateBy.
  ///
  /// In en, this message translates to:
  /// **'Spot created {date} by '**
  String spotDetailSpotCreatedOnDateBy(String date);

  /// No description provided for @spotDetailSpotCreatedBy.
  ///
  /// In en, this message translates to:
  /// **'Spot created by '**
  String get spotDetailSpotCreatedBy;

  /// No description provided for @spotDetailUnknownSource.
  ///
  /// In en, this message translates to:
  /// **'Unknown Source'**
  String get spotDetailUnknownSource;

  /// No description provided for @spotDetailSpotImportedOnDateFrom.
  ///
  /// In en, this message translates to:
  /// **'Spot imported {date} from '**
  String spotDetailSpotImportedOnDateFrom(String date);

  /// No description provided for @spotDetailSpotImportedFrom.
  ///
  /// In en, this message translates to:
  /// **'Spot imported from '**
  String get spotDetailSpotImportedFrom;

  /// No description provided for @spotDetailFromFolder.
  ///
  /// In en, this message translates to:
  /// **' from the folder '**
  String get spotDetailFromFolder;

  /// No description provided for @spotDetailImprovedByAfterComma.
  ///
  /// In en, this message translates to:
  /// **', improved by '**
  String get spotDetailImprovedByAfterComma;

  /// No description provided for @spotDetailImprovedByAfterAnd.
  ///
  /// In en, this message translates to:
  /// **' and improved by '**
  String get spotDetailImprovedByAfterAnd;

  /// No description provided for @spotDetailUnknownUser.
  ///
  /// In en, this message translates to:
  /// **'Unknown'**
  String get spotDetailUnknownUser;

  /// No description provided for @spotDetailListJoinAnd.
  ///
  /// In en, this message translates to:
  /// **' and '**
  String get spotDetailListJoinAnd;

  /// No description provided for @spotDetailListJoinComma.
  ///
  /// In en, this message translates to:
  /// **', '**
  String get spotDetailListJoinComma;

  /// No description provided for @spotDetailLastUpdatedAfterCommaAnd.
  ///
  /// In en, this message translates to:
  /// **', and last updated {date}.'**
  String spotDetailLastUpdatedAfterCommaAnd(String date);

  /// No description provided for @spotDetailLastUpdatedAfterAnd.
  ///
  /// In en, this message translates to:
  /// **' and last updated {date}.'**
  String spotDetailLastUpdatedAfterAnd(String date);

  /// No description provided for @spotDetailDateToday.
  ///
  /// In en, this message translates to:
  /// **'today'**
  String get spotDetailDateToday;

  /// No description provided for @spotDetailDateYesterday.
  ///
  /// In en, this message translates to:
  /// **'yesterday'**
  String get spotDetailDateYesterday;

  /// No description provided for @spotDetailDateDaysAgo.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, one{1 day ago} other{{count} days ago}}'**
  String spotDetailDateDaysAgo(int count);

  /// No description provided for @spotDetailDateWeeksAgo.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, one{1 week ago} other{{count} weeks ago}}'**
  String spotDetailDateWeeksAgo(int count);

  /// No description provided for @spotDetailDateMonthsAgo.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, one{1 month ago} other{{count} months ago}}'**
  String spotDetailDateMonthsAgo(int count);

  /// No description provided for @spotDetailDateYearsAgo.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, one{1 year ago} other{{count} years ago}}'**
  String spotDetailDateYearsAgo(int count);

  /// No description provided for @spotDetailCopySpotFailed.
  ///
  /// In en, this message translates to:
  /// **'Failed to copy spot: {error}'**
  String spotDetailCopySpotFailed(String error);

  /// No description provided for @spotDetailAddressCopiedToClipboard.
  ///
  /// In en, this message translates to:
  /// **'Address copied to clipboard!'**
  String get spotDetailAddressCopiedToClipboard;

  /// No description provided for @spotDetailCopyAddressFailed.
  ///
  /// In en, this message translates to:
  /// **'Failed to copy address: {error}'**
  String spotDetailCopyAddressFailed(String error);

  /// No description provided for @spotDetailOpenMapsFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not open maps app: {error}'**
  String spotDetailOpenMapsFailed(String error);

  /// No description provided for @spotDetailMoreActionsTooltip.
  ///
  /// In en, this message translates to:
  /// **'More actions'**
  String get spotDetailMoreActionsTooltip;

  /// No description provided for @spotDetailMenuLogin.
  ///
  /// In en, this message translates to:
  /// **'Login'**
  String get spotDetailMenuLogin;

  /// No description provided for @spotDetailMenuLoginSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Sign in first to link edits to your account'**
  String get spotDetailMenuLoginSubtitle;

  /// No description provided for @spotDetailMenuFlagDuplicate.
  ///
  /// In en, this message translates to:
  /// **'Flag as duplicate'**
  String get spotDetailMenuFlagDuplicate;

  /// No description provided for @spotDetailMenuFlagDuplicateSubtitleYes.
  ///
  /// In en, this message translates to:
  /// **'This spot is a duplicate'**
  String get spotDetailMenuFlagDuplicateSubtitleYes;

  /// No description provided for @spotDetailMenuFlagDuplicateSubtitleNo.
  ///
  /// In en, this message translates to:
  /// **'Already marked as duplicate'**
  String get spotDetailMenuFlagDuplicateSubtitleNo;

  /// No description provided for @spotDetailMenuSuggestPhoto.
  ///
  /// In en, this message translates to:
  /// **'Suggest photo'**
  String get spotDetailMenuSuggestPhoto;

  /// No description provided for @spotDetailMenuSuggestPhotoSubtitleYes.
  ///
  /// In en, this message translates to:
  /// **'Submit photos for this spot'**
  String get spotDetailMenuSuggestPhotoSubtitleYes;

  /// No description provided for @spotDetailMenuSuggestPhotoSubtitleNo.
  ///
  /// In en, this message translates to:
  /// **'Cannot suggest photos for duplicates'**
  String get spotDetailMenuSuggestPhotoSubtitleNo;

  /// No description provided for @spotDetailMenuSuggestEdit.
  ///
  /// In en, this message translates to:
  /// **'Suggest an edit'**
  String get spotDetailMenuSuggestEdit;

  /// No description provided for @spotDetailMenuSuggestEditSubtitleYes.
  ///
  /// In en, this message translates to:
  /// **'Propose changes to this spot'**
  String get spotDetailMenuSuggestEditSubtitleYes;

  /// No description provided for @spotDetailMenuSuggestEditSubtitleNo.
  ///
  /// In en, this message translates to:
  /// **'Cannot suggest edits for duplicates'**
  String get spotDetailMenuSuggestEditSubtitleNo;

  /// No description provided for @spotDetailMenuReportSpot.
  ///
  /// In en, this message translates to:
  /// **'Report spot'**
  String get spotDetailMenuReportSpot;

  /// No description provided for @spotDetailMenuReportSpotSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Help us review this spot'**
  String get spotDetailMenuReportSpotSubtitle;

  /// No description provided for @spotDetailMenuEditSpot.
  ///
  /// In en, this message translates to:
  /// **'Edit spot'**
  String get spotDetailMenuEditSpot;

  /// No description provided for @spotDetailMenuEditSpotSubtitleNative.
  ///
  /// In en, this message translates to:
  /// **'Create native spot first'**
  String get spotDetailMenuEditSpotSubtitleNative;

  /// No description provided for @spotDetailMenuEditSpotSubtitleMod.
  ///
  /// In en, this message translates to:
  /// **'Moderator only'**
  String get spotDetailMenuEditSpotSubtitleMod;

  /// No description provided for @spotDetailMenuMarkDuplicate.
  ///
  /// In en, this message translates to:
  /// **'Mark as duplicate'**
  String get spotDetailMenuMarkDuplicate;

  /// No description provided for @spotDetailMenuMarkDuplicateSubtitleDup.
  ///
  /// In en, this message translates to:
  /// **'Already marked as duplicate'**
  String get spotDetailMenuMarkDuplicateSubtitleDup;

  /// No description provided for @spotDetailMenuMarkDuplicateSubtitleMod.
  ///
  /// In en, this message translates to:
  /// **'Moderator only'**
  String get spotDetailMenuMarkDuplicateSubtitleMod;

  /// No description provided for @spotDetailMenuRemoveDuplicateStatus.
  ///
  /// In en, this message translates to:
  /// **'Remove duplicate status'**
  String get spotDetailMenuRemoveDuplicateStatus;

  /// No description provided for @spotDetailMenuCreateNative.
  ///
  /// In en, this message translates to:
  /// **'Create native spot'**
  String get spotDetailMenuCreateNative;

  /// No description provided for @spotDetailMenuHideSpot.
  ///
  /// In en, this message translates to:
  /// **'Hide spot'**
  String get spotDetailMenuHideSpot;

  /// No description provided for @spotDetailMenuUnhideSpot.
  ///
  /// In en, this message translates to:
  /// **'Unhide spot'**
  String get spotDetailMenuUnhideSpot;

  /// No description provided for @spotDetailMenuDeleteSpot.
  ///
  /// In en, this message translates to:
  /// **'Delete spot'**
  String get spotDetailMenuDeleteSpot;

  /// No description provided for @spotDetailMenuDeleteSubtitleAdmin.
  ///
  /// In en, this message translates to:
  /// **'Admin only'**
  String get spotDetailMenuDeleteSubtitleAdmin;

  /// No description provided for @spotDetailMenuTriggerResize.
  ///
  /// In en, this message translates to:
  /// **'Trigger image resize'**
  String get spotDetailMenuTriggerResize;

  /// No description provided for @spotDetailMenuTriggerResizeSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Re-create resized versions'**
  String get spotDetailMenuTriggerResizeSubtitle;

  /// No description provided for @spotDetailExternalSourceCannotEdit.
  ///
  /// In en, this message translates to:
  /// **'Spots from external sources cannot be edited. Please create a native spot first using “Mark as Duplicate” → “Create Native Spot”.'**
  String get spotDetailExternalSourceCannotEdit;

  /// No description provided for @spotDetailOk.
  ///
  /// In en, this message translates to:
  /// **'OK'**
  String get spotDetailOk;

  /// No description provided for @spotDetailUnableEditNow.
  ///
  /// In en, this message translates to:
  /// **'Unable to edit this spot right now.'**
  String get spotDetailUnableEditNow;

  /// No description provided for @spotDetailOnlyAdminsDelete.
  ///
  /// In en, this message translates to:
  /// **'Only administrators can delete spots.'**
  String get spotDetailOnlyAdminsDelete;

  /// No description provided for @spotDetailResizeAllHaveVersions.
  ///
  /// In en, this message translates to:
  /// **'All images already have resized versions'**
  String get spotDetailResizeAllHaveVersions;

  /// No description provided for @spotDetailResizeSummary.
  ///
  /// In en, this message translates to:
  /// **'Resize: {triggered} triggered, {verified} verified{failedPart}'**
  String spotDetailResizeSummary(
    int triggered,
    int verified,
    String failedPart,
  );

  /// No description provided for @spotDetailResizeFailedPart.
  ///
  /// In en, this message translates to:
  /// **', {failed} failed'**
  String spotDetailResizeFailedPart(int failed);

  /// No description provided for @spotDetailResizeTriggerFailed.
  ///
  /// In en, this message translates to:
  /// **'Failed to trigger resize: {error}'**
  String spotDetailResizeTriggerFailed(String error);

  /// No description provided for @spotDetailUnableFlagDuplicate.
  ///
  /// In en, this message translates to:
  /// **'Unable to flag this spot as duplicate right now.'**
  String get spotDetailUnableFlagDuplicate;

  /// No description provided for @spotDetailThanksDuplicateReport.
  ///
  /// In en, this message translates to:
  /// **'Thanks! Your duplicate report has been submitted.'**
  String get spotDetailThanksDuplicateReport;

  /// No description provided for @spotDetailUnableSuggestPhotos.
  ///
  /// In en, this message translates to:
  /// **'Unable to suggest photos for this spot right now.'**
  String get spotDetailUnableSuggestPhotos;

  /// No description provided for @spotDetailCannotSuggestPhotosDuplicate.
  ///
  /// In en, this message translates to:
  /// **'Cannot suggest photos for duplicate spots.'**
  String get spotDetailCannotSuggestPhotosDuplicate;

  /// No description provided for @spotDetailThanksPhotoSuggestion.
  ///
  /// In en, this message translates to:
  /// **'Thanks! Your photo suggestion has been submitted for review.'**
  String get spotDetailThanksPhotoSuggestion;

  /// No description provided for @spotDetailUnableSuggestEdits.
  ///
  /// In en, this message translates to:
  /// **'Unable to suggest edits for this spot right now.'**
  String get spotDetailUnableSuggestEdits;

  /// No description provided for @spotDetailCannotSuggestEditsDuplicate.
  ///
  /// In en, this message translates to:
  /// **'Cannot suggest edits for duplicate spots.'**
  String get spotDetailCannotSuggestEditsDuplicate;

  /// No description provided for @spotDetailThanksEditSuggestion.
  ///
  /// In en, this message translates to:
  /// **'Thanks! Your edit suggestion has been submitted for review.'**
  String get spotDetailThanksEditSuggestion;

  /// No description provided for @spotDetailUnableReportNow.
  ///
  /// In en, this message translates to:
  /// **'Unable to report this spot right now.'**
  String get spotDetailUnableReportNow;

  /// No description provided for @spotDetailThanksReportSubmitted.
  ///
  /// In en, this message translates to:
  /// **'Thanks! Your report has been submitted.'**
  String get spotDetailThanksReportSubmitted;

  /// No description provided for @spotDetailUnableAddToList.
  ///
  /// In en, this message translates to:
  /// **'Unable to add this spot to a list right now.'**
  String get spotDetailUnableAddToList;

  /// No description provided for @spotDetailNoSpotListsAccess.
  ///
  /// In en, this message translates to:
  /// **'You do not have access to spot lists.'**
  String get spotDetailNoSpotListsAccess;

  /// No description provided for @spotDetailListCreatedAndAdded.
  ///
  /// In en, this message translates to:
  /// **'List created and spot added!'**
  String get spotDetailListCreatedAndAdded;

  /// No description provided for @spotDetailSpotAddedToList.
  ///
  /// In en, this message translates to:
  /// **'Spot added to list!'**
  String get spotDetailSpotAddedToList;

  /// No description provided for @spotDetailEditReportTooltip.
  ///
  /// In en, this message translates to:
  /// **'Edit & report'**
  String get spotDetailEditReportTooltip;

  /// No description provided for @spotDetailShareTooltip.
  ///
  /// In en, this message translates to:
  /// **'Share'**
  String get spotDetailShareTooltip;

  /// No description provided for @spotDetailPresenceHereNow.
  ///
  /// In en, this message translates to:
  /// **'Here now'**
  String get spotDetailPresenceHereNow;

  /// No description provided for @spotDetailHiddenBanner.
  ///
  /// In en, this message translates to:
  /// **'This spot is hidden from public view. It likely no longer exists or doesn’t meet our policies. It will not appear in search results or on the map.'**
  String get spotDetailHiddenBanner;

  /// No description provided for @spotDetailSourceRemovedBanner.
  ///
  /// In en, this message translates to:
  /// **'This spot is no longer listed in {source}. Details might be outdated, so double-check before visiting.'**
  String spotDetailSourceRemovedBanner(String source);

  /// No description provided for @spotDetailSourceRemovedUnknownSource.
  ///
  /// In en, this message translates to:
  /// **'its original source'**
  String get spotDetailSourceRemovedUnknownSource;

  /// No description provided for @spotDetailSectionFeatures.
  ///
  /// In en, this message translates to:
  /// **'Features'**
  String get spotDetailSectionFeatures;

  /// No description provided for @spotDetailSectionAccess.
  ///
  /// In en, this message translates to:
  /// **'Access'**
  String get spotDetailSectionAccess;

  /// No description provided for @spotDetailSectionFacilities.
  ///
  /// In en, this message translates to:
  /// **'Facilities'**
  String get spotDetailSectionFacilities;

  /// No description provided for @spotDetailJumpflixFetchFailed.
  ///
  /// In en, this message translates to:
  /// **'Jumpflix fetch failed: {error}'**
  String spotDetailJumpflixFetchFailed(String error);

  /// No description provided for @spotDetailBrandYoutube.
  ///
  /// In en, this message translates to:
  /// **'YouTube'**
  String get spotDetailBrandYoutube;

  /// No description provided for @spotDetailBrandJumpflix.
  ///
  /// In en, this message translates to:
  /// **'Jumpflix'**
  String get spotDetailBrandJumpflix;

  /// No description provided for @spotDetailBrandAsSeenIn.
  ///
  /// In en, this message translates to:
  /// **'As seen in'**
  String get spotDetailBrandAsSeenIn;

  /// No description provided for @spotDetailLoading.
  ///
  /// In en, this message translates to:
  /// **'Loading...'**
  String get spotDetailLoading;

  /// No description provided for @spotDetailLoadingYourRating.
  ///
  /// In en, this message translates to:
  /// **'Loading your rating...'**
  String get spotDetailLoadingYourRating;

  /// No description provided for @spotDetailRateThisSpot.
  ///
  /// In en, this message translates to:
  /// **'Rate this spot'**
  String get spotDetailRateThisSpot;

  /// No description provided for @spotDetailCouldNotLoadProfile.
  ///
  /// In en, this message translates to:
  /// **'Couldn’t load your profile.'**
  String get spotDetailCouldNotLoadProfile;

  /// No description provided for @spotDetailRefreshPageToRate.
  ///
  /// In en, this message translates to:
  /// **'Please refresh the page to rate.'**
  String get spotDetailRefreshPageToRate;

  /// No description provided for @spotDetailSignInToRateTitle.
  ///
  /// In en, this message translates to:
  /// **'Sign in to rate this spot'**
  String get spotDetailSignInToRateTitle;

  /// No description provided for @spotDetailSignInToRateSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Sign in to rate this spot and help other parkour enthusiasts.'**
  String get spotDetailSignInToRateSubtitle;

  /// No description provided for @spotDetailSignInButton.
  ///
  /// In en, this message translates to:
  /// **'Sign In'**
  String get spotDetailSignInButton;

  /// No description provided for @spotDetailCreateAccountButton.
  ///
  /// In en, this message translates to:
  /// **'Create an Account'**
  String get spotDetailCreateAccountButton;

  /// No description provided for @spotDetailMapSwitchToMap.
  ///
  /// In en, this message translates to:
  /// **'Switch to Map'**
  String get spotDetailMapSwitchToMap;

  /// No description provided for @spotDetailMapSwitchToSatellite.
  ///
  /// In en, this message translates to:
  /// **'Switch to Satellite'**
  String get spotDetailMapSwitchToSatellite;

  /// No description provided for @spotDetailMapLocateOnMap.
  ///
  /// In en, this message translates to:
  /// **'Locate on map'**
  String get spotDetailMapLocateOnMap;

  /// No description provided for @spotDetailDuplicateOf.
  ///
  /// In en, this message translates to:
  /// **'Duplicate of'**
  String get spotDetailDuplicateOf;

  /// No description provided for @spotDetailOriginalSpotFallback.
  ///
  /// In en, this message translates to:
  /// **'Original spot'**
  String get spotDetailOriginalSpotFallback;

  /// No description provided for @spotDetailAlsoBasedOn.
  ///
  /// In en, this message translates to:
  /// **'Also based on'**
  String get spotDetailAlsoBasedOn;

  /// No description provided for @spotDetailAlsoBasedOnCount.
  ///
  /// In en, this message translates to:
  /// **'Also based on ({count})'**
  String spotDetailAlsoBasedOnCount(int count);

  /// No description provided for @spotDetailNoImagesAvailable.
  ///
  /// In en, this message translates to:
  /// **'No images available'**
  String get spotDetailNoImagesAvailable;

  /// No description provided for @spotDetailGalleryPageIndicator.
  ///
  /// In en, this message translates to:
  /// **'{current} / {total}'**
  String spotDetailGalleryPageIndicator(int current, int total);

  /// No description provided for @spotDetailSaveMenuTooltip.
  ///
  /// In en, this message translates to:
  /// **'Save spot'**
  String get spotDetailSaveMenuTooltip;

  /// No description provided for @spotDetailSaveMenuSignInTitle.
  ///
  /// In en, this message translates to:
  /// **'Sign in to save spots'**
  String get spotDetailSaveMenuSignInTitle;

  /// No description provided for @spotDetailSaveMenuSignInBody.
  ///
  /// In en, this message translates to:
  /// **'Add this spot to Want to visit, Been here, or your own lists. Log in or create a free account to get started.'**
  String get spotDetailSaveMenuSignInBody;

  /// No description provided for @spotDetailSaveMenuLogInOrCreate.
  ///
  /// In en, this message translates to:
  /// **'Log in or create account'**
  String get spotDetailSaveMenuLogInOrCreate;

  /// No description provided for @spotDetailSaveTooltipUpdating.
  ///
  /// In en, this message translates to:
  /// **'Updating…'**
  String get spotDetailSaveTooltipUpdating;

  /// No description provided for @spotDetailSaveTooltipWantToVisit.
  ///
  /// In en, this message translates to:
  /// **'Saved: Want to visit'**
  String get spotDetailSaveTooltipWantToVisit;

  /// No description provided for @spotDetailSaveTooltipBeenHere.
  ///
  /// In en, this message translates to:
  /// **'Saved: Been here'**
  String get spotDetailSaveTooltipBeenHere;

  /// No description provided for @spotDetailSaveTooltipGeneric.
  ///
  /// In en, this message translates to:
  /// **'Save spot'**
  String get spotDetailSaveTooltipGeneric;

  /// No description provided for @spotDetailRemovedFromWantToVisit.
  ///
  /// In en, this message translates to:
  /// **'Removed from Want to visit'**
  String get spotDetailRemovedFromWantToVisit;

  /// No description provided for @spotDetailFailedToRemove.
  ///
  /// In en, this message translates to:
  /// **'Failed to remove'**
  String get spotDetailFailedToRemove;

  /// No description provided for @spotDetailAddedToWantToVisit.
  ///
  /// In en, this message translates to:
  /// **'Added to Want to visit'**
  String get spotDetailAddedToWantToVisit;

  /// No description provided for @spotDetailFailedToAdd.
  ///
  /// In en, this message translates to:
  /// **'Failed to add'**
  String get spotDetailFailedToAdd;

  /// No description provided for @spotDetailRemovedFromBeenHere.
  ///
  /// In en, this message translates to:
  /// **'Removed from Been here'**
  String get spotDetailRemovedFromBeenHere;

  /// No description provided for @spotDetailAddedToBeenHere.
  ///
  /// In en, this message translates to:
  /// **'Added to Been here'**
  String get spotDetailAddedToBeenHere;

  /// No description provided for @spotDetailWantToVisit.
  ///
  /// In en, this message translates to:
  /// **'Want to visit'**
  String get spotDetailWantToVisit;

  /// No description provided for @spotDetailBeenHere.
  ///
  /// In en, this message translates to:
  /// **'Been here'**
  String get spotDetailBeenHere;

  /// No description provided for @spotDetailViewFullListTooltip.
  ///
  /// In en, this message translates to:
  /// **'View full list'**
  String get spotDetailViewFullListTooltip;

  /// No description provided for @spotDetailAddToCustomList.
  ///
  /// In en, this message translates to:
  /// **'Add to custom list'**
  String get spotDetailAddToCustomList;

  /// No description provided for @spotDetailAddToCustomListSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Choose or create a list'**
  String get spotDetailAddToCustomListSubtitle;

  /// No description provided for @spotDetailListNameEmpty.
  ///
  /// In en, this message translates to:
  /// **'List name cannot be empty'**
  String get spotDetailListNameEmpty;

  /// No description provided for @spotDetailFailedAddToListGeneric.
  ///
  /// In en, this message translates to:
  /// **'Failed to add spot to list'**
  String get spotDetailFailedAddToListGeneric;

  /// No description provided for @spotDetailFailedCreateList.
  ///
  /// In en, this message translates to:
  /// **'Failed to create list'**
  String get spotDetailFailedCreateList;

  /// No description provided for @spotDetailFailedAddToSomeLists.
  ///
  /// In en, this message translates to:
  /// **'Failed to add spot to some lists'**
  String get spotDetailFailedAddToSomeLists;

  /// No description provided for @spotDetailAddToListTitle.
  ///
  /// In en, this message translates to:
  /// **'Add to {name}'**
  String spotDetailAddToListTitle(String name);

  /// No description provided for @spotDetailSelectSections.
  ///
  /// In en, this message translates to:
  /// **'Select sections:'**
  String get spotDetailSelectSections;

  /// No description provided for @spotDetailSectionEntryCount.
  ///
  /// In en, this message translates to:
  /// **'Section ({count} spots)'**
  String spotDetailSectionEntryCount(int count);

  /// No description provided for @spotDetailAddToNewSection.
  ///
  /// In en, this message translates to:
  /// **'Add to new section'**
  String get spotDetailAddToNewSection;

  /// No description provided for @spotDetailSectionNameOptional.
  ///
  /// In en, this message translates to:
  /// **'Section name (optional)'**
  String get spotDetailSectionNameOptional;

  /// No description provided for @spotDetailNoteOptional.
  ///
  /// In en, this message translates to:
  /// **'Note (optional)'**
  String get spotDetailNoteOptional;

  /// No description provided for @spotDetailSkip.
  ///
  /// In en, this message translates to:
  /// **'Skip'**
  String get spotDetailSkip;

  /// No description provided for @spotDetailAdd.
  ///
  /// In en, this message translates to:
  /// **'Add'**
  String get spotDetailAdd;

  /// No description provided for @spotDetailAddToListDialogTitle.
  ///
  /// In en, this message translates to:
  /// **'Add to List'**
  String get spotDetailAddToListDialogTitle;

  /// No description provided for @spotDetailAlreadyInLists.
  ///
  /// In en, this message translates to:
  /// **'Already in these lists:'**
  String get spotDetailAlreadyInLists;

  /// No description provided for @spotDetailNoListsYet.
  ///
  /// In en, this message translates to:
  /// **'You don’t have any lists yet. Create one to get started!'**
  String get spotDetailNoListsYet;

  /// No description provided for @spotDetailSelectListsPrompt.
  ///
  /// In en, this message translates to:
  /// **'Select lists to add this spot to:'**
  String get spotDetailSelectListsPrompt;

  /// No description provided for @spotDetailCreateNewList.
  ///
  /// In en, this message translates to:
  /// **'Create New List'**
  String get spotDetailCreateNewList;

  /// No description provided for @spotDetailListNameLabel.
  ///
  /// In en, this message translates to:
  /// **'List Name'**
  String get spotDetailListNameLabel;

  /// No description provided for @spotDetailListNameHint.
  ///
  /// In en, this message translates to:
  /// **'e.g., My Favorite Spots'**
  String get spotDetailListNameHint;

  /// No description provided for @spotDetailListDescriptionLabel.
  ///
  /// In en, this message translates to:
  /// **'Description (optional)'**
  String get spotDetailListDescriptionLabel;

  /// No description provided for @spotDetailListDescriptionHint.
  ///
  /// In en, this message translates to:
  /// **'Add a description for this list'**
  String get spotDetailListDescriptionHint;

  /// No description provided for @spotDetailVisibilityLabel.
  ///
  /// In en, this message translates to:
  /// **'Visibility'**
  String get spotDetailVisibilityLabel;

  /// No description provided for @spotDetailCreateAndAdd.
  ///
  /// In en, this message translates to:
  /// **'Create & Add'**
  String get spotDetailCreateAndAdd;

  /// No description provided for @spotDetailReportDuplicateTitle.
  ///
  /// In en, this message translates to:
  /// **'Report duplicate spot'**
  String get spotDetailReportDuplicateTitle;

  /// No description provided for @spotDetailReportDuplicateIntro.
  ///
  /// In en, this message translates to:
  /// **'Please select the spot this is a duplicate of.'**
  String get spotDetailReportDuplicateIntro;

  /// No description provided for @spotDetailEmailInvalid.
  ///
  /// In en, this message translates to:
  /// **'Enter a valid email address.'**
  String get spotDetailEmailInvalid;

  /// No description provided for @spotDetailEmailRequired.
  ///
  /// In en, this message translates to:
  /// **'Please provide an email address.'**
  String get spotDetailEmailRequired;

  /// No description provided for @spotDetailSubmitReport.
  ///
  /// In en, this message translates to:
  /// **'Submit report'**
  String get spotDetailSubmitReport;

  /// No description provided for @spotDetailReportThisSpotTitle.
  ///
  /// In en, this message translates to:
  /// **'Report this spot'**
  String get spotDetailReportThisSpotTitle;

  /// No description provided for @spotDetailReportIntro.
  ///
  /// In en, this message translates to:
  /// **'Let us know what is wrong with {name}. Moderators will review your report shortly.'**
  String spotDetailReportIntro(String name);

  /// No description provided for @spotDetailReportWhatWrong.
  ///
  /// In en, this message translates to:
  /// **'What is happening?'**
  String get spotDetailReportWhatWrong;

  /// No description provided for @spotDetailReportCategoryLabel.
  ///
  /// In en, this message translates to:
  /// **'Select a category'**
  String get spotDetailReportCategoryLabel;

  /// No description provided for @spotDetailReportCategoryHint.
  ///
  /// In en, this message translates to:
  /// **'Choose a report category'**
  String get spotDetailReportCategoryHint;

  /// No description provided for @spotDetailReportDescribeIssue.
  ///
  /// In en, this message translates to:
  /// **'Describe the issue'**
  String get spotDetailReportDescribeIssue;

  /// No description provided for @spotDetailReportDescribeIssueHint.
  ///
  /// In en, this message translates to:
  /// **'Tell us what does not match reality'**
  String get spotDetailReportDescribeIssueHint;

  /// No description provided for @spotDetailReportAdditionalDetails.
  ///
  /// In en, this message translates to:
  /// **'Additional details'**
  String get spotDetailReportAdditionalDetails;

  /// No description provided for @spotDetailReportAdditionalDetailsHint.
  ///
  /// In en, this message translates to:
  /// **'Anything else we should know?'**
  String get spotDetailReportAdditionalDetailsHint;

  /// No description provided for @spotDetailReportEmailLabel.
  ///
  /// In en, this message translates to:
  /// **'Email address'**
  String get spotDetailReportEmailLabel;

  /// No description provided for @spotDetailReportEmailHelper.
  ///
  /// In en, this message translates to:
  /// **'We will contact you only about this report.'**
  String get spotDetailReportEmailHelper;

  /// No description provided for @spotDetailReportReachOutAt.
  ///
  /// In en, this message translates to:
  /// **'We will reach out at {email} if we need more info.'**
  String spotDetailReportReachOutAt(String email);

  /// No description provided for @spotDetailReportReachOutAccount.
  ///
  /// In en, this message translates to:
  /// **'We will reach out using your account email if we need more info.'**
  String get spotDetailReportReachOutAccount;

  /// No description provided for @spotDetailReportCategoryOtherDescribe.
  ///
  /// In en, this message translates to:
  /// **'Please describe the issue when selecting Other.'**
  String get spotDetailReportCategoryOtherDescribe;

  /// No description provided for @spotDetailReportCategoryRequired.
  ///
  /// In en, this message translates to:
  /// **'Please select a category.'**
  String get spotDetailReportCategoryRequired;

  /// No description provided for @spotDetailReportSendFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not send your report. Please try again.'**
  String get spotDetailReportSendFailed;

  /// No description provided for @spotDetailReportCategoryClosed.
  ///
  /// In en, this message translates to:
  /// **'Spot closed or removed'**
  String get spotDetailReportCategoryClosed;

  /// No description provided for @spotDetailReportCategoryInaccurate.
  ///
  /// In en, this message translates to:
  /// **'Inaccurate location or details'**
  String get spotDetailReportCategoryInaccurate;

  /// No description provided for @spotDetailReportCategoryUnsafe.
  ///
  /// In en, this message translates to:
  /// **'Unsafe conditions'**
  String get spotDetailReportCategoryUnsafe;

  /// No description provided for @spotDetailReportCategoryNotASpot.
  ///
  /// In en, this message translates to:
  /// **'Not a spot'**
  String get spotDetailReportCategoryNotASpot;

  /// No description provided for @spotDetailReportCategoryOther.
  ///
  /// In en, this message translates to:
  /// **'Other'**
  String get spotDetailReportCategoryOther;

  /// No description provided for @spotDetailReportCategoryClosedDesc.
  ///
  /// In en, this message translates to:
  /// **'The spot has been permanently closed, demolished, or removed and is no longer accessible. Please provide more details below.'**
  String get spotDetailReportCategoryClosedDesc;

  /// No description provided for @spotDetailReportCategoryInaccurateDesc.
  ///
  /// In en, this message translates to:
  /// **'The spot’s location on the map is incorrect, or details like name, description, or address are wrong. Please provide more details below on what should be corrected.'**
  String get spotDetailReportCategoryInaccurateDesc;

  /// No description provided for @spotDetailReportCategoryUnsafeDesc.
  ///
  /// In en, this message translates to:
  /// **'The spot has become dangerous due to structural issues, environmental hazards, or other safety concerns. Please provide more details below on what is unsafe.'**
  String get spotDetailReportCategoryUnsafeDesc;

  /// No description provided for @spotDetailReportCategoryNotASpotDesc.
  ///
  /// In en, this message translates to:
  /// **'Only for objective issues like spam, spots in invalid locations (e.g., middle of the sea), private residences, entire cities, or other clearly invalid entries. For subjective opinions about spot quality, please use a rating instead. Please provide more details below on why this is not a spot.'**
  String get spotDetailReportCategoryNotASpotDesc;

  /// No description provided for @spotDetailReportCategoryOtherDesc.
  ///
  /// In en, this message translates to:
  /// **'Any other issue not covered by the categories above. Please describe the issue in the field below.'**
  String get spotDetailReportCategoryOtherDesc;

  /// No description provided for @spotDetailMarkDuplicateTitle.
  ///
  /// In en, this message translates to:
  /// **'Mark as Duplicate'**
  String get spotDetailMarkDuplicateTitle;

  /// No description provided for @spotDetailMarkDuplicateBody.
  ///
  /// In en, this message translates to:
  /// **'Are you sure you want to mark this spot as a duplicate? This action can be reversed later.'**
  String get spotDetailMarkDuplicateBody;

  /// No description provided for @spotDetailMarkDuplicateAddToOriginal.
  ///
  /// In en, this message translates to:
  /// **'Select which items to add to the original spot:'**
  String get spotDetailMarkDuplicateAddToOriginal;

  /// No description provided for @spotDetailMarkDuplicatePhotos.
  ///
  /// In en, this message translates to:
  /// **'Photos'**
  String get spotDetailMarkDuplicatePhotos;

  /// No description provided for @spotDetailMarkDuplicateYoutube.
  ///
  /// In en, this message translates to:
  /// **'YouTube links'**
  String get spotDetailMarkDuplicateYoutube;

  /// No description provided for @spotDetailMarkDuplicateOverwrite.
  ///
  /// In en, this message translates to:
  /// **'Select which items to overwrite in the original spot (if set):'**
  String get spotDetailMarkDuplicateOverwrite;

  /// No description provided for @spotDetailMarkDuplicateName.
  ///
  /// In en, this message translates to:
  /// **'Name'**
  String get spotDetailMarkDuplicateName;

  /// No description provided for @spotDetailMarkDuplicateDescription.
  ///
  /// In en, this message translates to:
  /// **'Description'**
  String get spotDetailMarkDuplicateDescription;

  /// No description provided for @spotDetailMarkDuplicateLocation.
  ///
  /// In en, this message translates to:
  /// **'Location'**
  String get spotDetailMarkDuplicateLocation;

  /// No description provided for @spotDetailMarkDuplicateSpotAttributes.
  ///
  /// In en, this message translates to:
  /// **'Spot attributes'**
  String get spotDetailMarkDuplicateSpotAttributes;

  /// No description provided for @spotDetailConfirm.
  ///
  /// In en, this message translates to:
  /// **'Confirm'**
  String get spotDetailConfirm;

  /// No description provided for @spotDetailPickImagesFailed.
  ///
  /// In en, this message translates to:
  /// **'Failed to pick images. Please try again.'**
  String get spotDetailPickImagesFailed;

  /// No description provided for @spotDetailSelectAtLeastOnePhoto.
  ///
  /// In en, this message translates to:
  /// **'Please select at least one photo'**
  String get spotDetailSelectAtLeastOnePhoto;

  /// No description provided for @spotDetailSuggestPhotosTitle.
  ///
  /// In en, this message translates to:
  /// **'Suggest Photos'**
  String get spotDetailSuggestPhotosTitle;

  /// No description provided for @spotDetailSuggestPhotosIntro.
  ///
  /// In en, this message translates to:
  /// **'Submit photos to be added to this spot. Photos will be reviewed by moderators before being added.'**
  String get spotDetailSuggestPhotosIntro;

  /// No description provided for @spotDetailSelectPhotos.
  ///
  /// In en, this message translates to:
  /// **'Select Photos'**
  String get spotDetailSelectPhotos;

  /// No description provided for @spotDetailPickPhotos.
  ///
  /// In en, this message translates to:
  /// **'Pick Photos'**
  String get spotDetailPickPhotos;

  /// No description provided for @spotDetailAdditionalDetailsOptional.
  ///
  /// In en, this message translates to:
  /// **'Additional Details (Optional)'**
  String get spotDetailAdditionalDetailsOptional;

  /// No description provided for @spotDetailAdditionalDetailsHint.
  ///
  /// In en, this message translates to:
  /// **'Add any additional information about these photos...'**
  String get spotDetailAdditionalDetailsHint;

  /// No description provided for @spotDetailSuggestPhotosEmailHelper.
  ///
  /// In en, this message translates to:
  /// **'We will contact you only about this suggestion.'**
  String get spotDetailSuggestPhotosEmailHelper;

  /// No description provided for @spotDetailSuggestPhotosSubmitFailed.
  ///
  /// In en, this message translates to:
  /// **'Failed to submit photo suggestion. Please try again.'**
  String get spotDetailSuggestPhotosSubmitFailed;

  /// No description provided for @spotDetailSuggestPhotosSubmitError.
  ///
  /// In en, this message translates to:
  /// **'Error submitting photo suggestion: {error}'**
  String spotDetailSuggestPhotosSubmitError(String error);

  /// No description provided for @spotDetailSuggestEditTitle.
  ///
  /// In en, this message translates to:
  /// **'Suggest an Edit'**
  String get spotDetailSuggestEditTitle;

  /// No description provided for @spotDetailSuggestEditIntro.
  ///
  /// In en, this message translates to:
  /// **'Propose changes to this spot. Moderators will review your suggestions.'**
  String get spotDetailSuggestEditIntro;

  /// No description provided for @spotDetailSuggestEditSuggestChange.
  ///
  /// In en, this message translates to:
  /// **'Please suggest at least one change.'**
  String get spotDetailSuggestEditSuggestChange;

  /// No description provided for @spotDetailSuggestEditSubmitFailed.
  ///
  /// In en, this message translates to:
  /// **'Failed to submit edit suggestion. Please try again.'**
  String get spotDetailSuggestEditSubmitFailed;

  /// No description provided for @spotDetailSuggestEditSubmitError.
  ///
  /// In en, this message translates to:
  /// **'Error submitting edit suggestion: {error}'**
  String spotDetailSuggestEditSubmitError(String error);

  /// No description provided for @spotDetailGeocoding.
  ///
  /// In en, this message translates to:
  /// **'Geocoding...'**
  String get spotDetailGeocoding;

  /// No description provided for @spotDetailChangeLocationPicked.
  ///
  /// In en, this message translates to:
  /// **'Change location (picked)'**
  String get spotDetailChangeLocationPicked;

  /// No description provided for @spotDetailPickLocationOnMap.
  ///
  /// In en, this message translates to:
  /// **'Pick different location on map'**
  String get spotDetailPickLocationOnMap;

  /// No description provided for @spotDetailFieldTitle.
  ///
  /// In en, this message translates to:
  /// **'Title'**
  String get spotDetailFieldTitle;

  /// No description provided for @spotDetailFieldTitleHint.
  ///
  /// In en, this message translates to:
  /// **'Spot title'**
  String get spotDetailFieldTitleHint;

  /// No description provided for @spotDetailFieldDescription.
  ///
  /// In en, this message translates to:
  /// **'Description'**
  String get spotDetailFieldDescription;

  /// No description provided for @spotDetailFieldDescriptionHint.
  ///
  /// In en, this message translates to:
  /// **'Spot description'**
  String get spotDetailFieldDescriptionHint;

  /// No description provided for @spotDetailFieldSpotAttributes.
  ///
  /// In en, this message translates to:
  /// **'Spot attributes'**
  String get spotDetailFieldSpotAttributes;

  /// No description provided for @spotDetailSuggestEditEmailHelper.
  ///
  /// In en, this message translates to:
  /// **'We will contact you only about this suggestion.'**
  String get spotDetailSuggestEditEmailHelper;

  /// No description provided for @spotDetailMustBeLoggedInToRate.
  ///
  /// In en, this message translates to:
  /// **'You must be logged in to rate spots'**
  String get spotDetailMustBeLoggedInToRate;

  /// No description provided for @spotDetailRatingSubmitted.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, one{Rating 1 star submitted!} other{Rating {count} stars submitted!}}'**
  String spotDetailRatingSubmitted(int count);

  /// No description provided for @spotDetailRatingSubmitFailed.
  ///
  /// In en, this message translates to:
  /// **'Failed to submit rating. Please try again.'**
  String get spotDetailRatingSubmitFailed;

  /// No description provided for @spotDetailRatingSubmitError.
  ///
  /// In en, this message translates to:
  /// **'Error submitting rating: {error}'**
  String spotDetailRatingSubmitError(String error);

  /// No description provided for @spotDetailNotExternalSource.
  ///
  /// In en, this message translates to:
  /// **'This spot is not from an external source.'**
  String get spotDetailNotExternalSource;

  /// No description provided for @spotDetailMustBeLoggedInCreateNative.
  ///
  /// In en, this message translates to:
  /// **'You must be logged in to create a native spot.'**
  String get spotDetailMustBeLoggedInCreateNative;

  /// No description provided for @spotDetailCreateNativeDialogTitle.
  ///
  /// In en, this message translates to:
  /// **'Create Native Spot'**
  String get spotDetailCreateNativeDialogTitle;

  /// No description provided for @spotDetailCreateNativeDialogBody.
  ///
  /// In en, this message translates to:
  /// **'This will create a new native spot based on this spot and mark the current spot as a duplicate of it. All spot data (name, description, location, photos, YouTube links, and attributes) will be copied to the new native spot.\n\nNote: Admins can remove spots and duplicate links can be removed if needed.'**
  String get spotDetailCreateNativeDialogBody;

  /// No description provided for @spotDetailCreateButton.
  ///
  /// In en, this message translates to:
  /// **'Create'**
  String get spotDetailCreateButton;

  /// No description provided for @spotDetailUnableCreateNativeNow.
  ///
  /// In en, this message translates to:
  /// **'Unable to create native spot right now.'**
  String get spotDetailUnableCreateNativeNow;

  /// No description provided for @spotDetailFailedCreateNativeSpot.
  ///
  /// In en, this message translates to:
  /// **'Failed to create native spot'**
  String get spotDetailFailedCreateNativeSpot;

  /// No description provided for @spotDetailNativeCreatedDuplicateMarked.
  ///
  /// In en, this message translates to:
  /// **'Native spot created and current spot marked as duplicate.'**
  String get spotDetailNativeCreatedDuplicateMarked;

  /// No description provided for @spotDetailFailedMarkDuplicateGeneric.
  ///
  /// In en, this message translates to:
  /// **'Failed to mark spot as duplicate'**
  String get spotDetailFailedMarkDuplicateGeneric;

  /// No description provided for @spotDetailErrorCreatingNativeSpot.
  ///
  /// In en, this message translates to:
  /// **'Error creating native spot: {error}'**
  String spotDetailErrorCreatingNativeSpot(String error);

  /// No description provided for @spotDetailUnableMarkDuplicateNow.
  ///
  /// In en, this message translates to:
  /// **'Unable to mark this spot as duplicate right now.'**
  String get spotDetailUnableMarkDuplicateNow;

  /// No description provided for @spotDetailAlreadyMarkedDuplicate.
  ///
  /// In en, this message translates to:
  /// **'This spot is already marked as a duplicate.'**
  String get spotDetailAlreadyMarkedDuplicate;

  /// No description provided for @spotDetailSpotMarkedDuplicateSuccess.
  ///
  /// In en, this message translates to:
  /// **'Spot marked as duplicate.'**
  String get spotDetailSpotMarkedDuplicateSuccess;

  /// No description provided for @spotDetailErrorMarkingDuplicateSpot.
  ///
  /// In en, this message translates to:
  /// **'Error marking spot as duplicate: {error}'**
  String spotDetailErrorMarkingDuplicateSpot(String error);

  /// No description provided for @spotDetailModeratorsOnlyHideUnhide.
  ///
  /// In en, this message translates to:
  /// **'Only moderators can hide/unhide spots.'**
  String get spotDetailModeratorsOnlyHideUnhide;

  /// No description provided for @spotDetailHideSpotTitle.
  ///
  /// In en, this message translates to:
  /// **'Hide Spot'**
  String get spotDetailHideSpotTitle;

  /// No description provided for @spotDetailUnhideSpotTitle.
  ///
  /// In en, this message translates to:
  /// **'Unhide Spot'**
  String get spotDetailUnhideSpotTitle;

  /// No description provided for @spotDetailHideSpotMessage.
  ///
  /// In en, this message translates to:
  /// **'This will hide the spot from public view. Hidden spots will not appear in search results or on the map, but the spot data will be preserved and can be unhidden later.'**
  String get spotDetailHideSpotMessage;

  /// No description provided for @spotDetailUnhideSpotMessage.
  ///
  /// In en, this message translates to:
  /// **'This will restore the spot to public view. The spot will appear in search results and on the map again.'**
  String get spotDetailUnhideSpotMessage;

  /// No description provided for @spotDetailActionHide.
  ///
  /// In en, this message translates to:
  /// **'Hide'**
  String get spotDetailActionHide;

  /// No description provided for @spotDetailActionUnhide.
  ///
  /// In en, this message translates to:
  /// **'Unhide'**
  String get spotDetailActionUnhide;

  /// No description provided for @spotDetailUnableHideUnhideNow.
  ///
  /// In en, this message translates to:
  /// **'Unable to hide/unhide this spot right now.'**
  String get spotDetailUnableHideUnhideNow;

  /// No description provided for @spotDetailSpotHiddenSuccess.
  ///
  /// In en, this message translates to:
  /// **'Spot hidden successfully.'**
  String get spotDetailSpotHiddenSuccess;

  /// No description provided for @spotDetailSpotUnhiddenSuccess.
  ///
  /// In en, this message translates to:
  /// **'Spot unhidden successfully.'**
  String get spotDetailSpotUnhiddenSuccess;

  /// No description provided for @spotDetailFailedHideSpot.
  ///
  /// In en, this message translates to:
  /// **'Failed to hide spot'**
  String get spotDetailFailedHideSpot;

  /// No description provided for @spotDetailFailedUnhideSpot.
  ///
  /// In en, this message translates to:
  /// **'Failed to unhide spot'**
  String get spotDetailFailedUnhideSpot;

  /// No description provided for @spotDetailErrorHidingSpot.
  ///
  /// In en, this message translates to:
  /// **'Error hiding spot: {error}'**
  String spotDetailErrorHidingSpot(String error);

  /// No description provided for @spotDetailErrorUnhidingSpot.
  ///
  /// In en, this message translates to:
  /// **'Error unhiding spot: {error}'**
  String spotDetailErrorUnhidingSpot(String error);

  /// No description provided for @spotDetailNotMarkedAsDuplicate.
  ///
  /// In en, this message translates to:
  /// **'This spot is not marked as a duplicate.'**
  String get spotDetailNotMarkedAsDuplicate;

  /// No description provided for @spotDetailModeratorsOnlyRemoveDuplicateStatus.
  ///
  /// In en, this message translates to:
  /// **'Only moderators can remove duplicate status.'**
  String get spotDetailModeratorsOnlyRemoveDuplicateStatus;

  /// No description provided for @spotDetailRemoveDuplicateDialogBody.
  ///
  /// In en, this message translates to:
  /// **'This will remove the duplicate status from this spot. The spot will no longer be marked as a duplicate.\n\nDo you want to continue?'**
  String get spotDetailRemoveDuplicateDialogBody;

  /// No description provided for @spotDetailRemoveButton.
  ///
  /// In en, this message translates to:
  /// **'Remove'**
  String get spotDetailRemoveButton;

  /// No description provided for @spotDetailUnableRemoveDuplicateStatusNow.
  ///
  /// In en, this message translates to:
  /// **'Unable to remove duplicate status right now.'**
  String get spotDetailUnableRemoveDuplicateStatusNow;

  /// No description provided for @spotDetailDuplicateStatusRemovedSuccess.
  ///
  /// In en, this message translates to:
  /// **'Duplicate status removed successfully.'**
  String get spotDetailDuplicateStatusRemovedSuccess;

  /// No description provided for @spotDetailFailedRemoveDuplicateStatusGeneric.
  ///
  /// In en, this message translates to:
  /// **'Failed to remove duplicate status'**
  String get spotDetailFailedRemoveDuplicateStatusGeneric;

  /// No description provided for @spotDetailErrorRemovingDuplicateStatus.
  ///
  /// In en, this message translates to:
  /// **'Error removing duplicate status: {error}'**
  String spotDetailErrorRemovingDuplicateStatus(String error);

  /// No description provided for @spotDetailCheckingLinkedData.
  ///
  /// In en, this message translates to:
  /// **'Checking linked data...'**
  String get spotDetailCheckingLinkedData;

  /// No description provided for @spotDetailDeleteSpotDialogTitle.
  ///
  /// In en, this message translates to:
  /// **'Delete Spot'**
  String get spotDetailDeleteSpotDialogTitle;

  /// No description provided for @spotDetailDeleteSpotConfirmMessage.
  ///
  /// In en, this message translates to:
  /// **'Are you sure you want to delete this spot? This action cannot be undone.'**
  String get spotDetailDeleteSpotConfirmMessage;

  /// No description provided for @spotDetailLinkedDataHeading.
  ///
  /// In en, this message translates to:
  /// **'This spot has linked data:'**
  String get spotDetailLinkedDataHeading;

  /// No description provided for @spotDetailLinkedRatingsLine.
  ///
  /// In en, this message translates to:
  /// **'• Ratings: {count}'**
  String spotDetailLinkedRatingsLine(int count);

  /// No description provided for @spotDetailLinkedReportsLine.
  ///
  /// In en, this message translates to:
  /// **'• Spot reports: {count}'**
  String spotDetailLinkedReportsLine(int count);

  /// No description provided for @spotDetailLinkedDuplicatesLine.
  ///
  /// In en, this message translates to:
  /// **'• Duplicate spots: {count}'**
  String spotDetailLinkedDuplicatesLine(int count);

  /// No description provided for @spotDetailResolveLinksBeforeDelete.
  ///
  /// In en, this message translates to:
  /// **'Please resolve these links before deleting the spot.'**
  String get spotDetailResolveLinksBeforeDelete;

  /// No description provided for @spotDetailSpotDeletedSuccess.
  ///
  /// In en, this message translates to:
  /// **'Spot deleted successfully'**
  String get spotDetailSpotDeletedSuccess;

  /// No description provided for @spotDetailFailedDeleteSpot.
  ///
  /// In en, this message translates to:
  /// **'Failed to delete spot'**
  String get spotDetailFailedDeleteSpot;

  /// No description provided for @spotDetailErrorDeletingSpot.
  ///
  /// In en, this message translates to:
  /// **'Error deleting spot: {error}'**
  String spotDetailErrorDeletingSpot(String error);

  /// No description provided for @spotDetailFlagDuplicateDialogTitle.
  ///
  /// In en, this message translates to:
  /// **'Flag as duplicate'**
  String get spotDetailFlagDuplicateDialogTitle;

  /// No description provided for @spotDetailFlagDuplicateIntro.
  ///
  /// In en, this message translates to:
  /// **'This spot appears to be a duplicate of another spot. Please select the original spot below.'**
  String get spotDetailFlagDuplicateIntro;

  /// No description provided for @spotDetailFlagDuplicateWhichQuestion.
  ///
  /// In en, this message translates to:
  /// **'Which spot is this a duplicate of?'**
  String get spotDetailFlagDuplicateWhichQuestion;

  /// No description provided for @spotDetailDuplicateSearchHint.
  ///
  /// In en, this message translates to:
  /// **'Paste spot URL or enter spot ID'**
  String get spotDetailDuplicateSearchHint;

  /// No description provided for @spotDetailSearch.
  ///
  /// In en, this message translates to:
  /// **'Search'**
  String get spotDetailSearch;

  /// No description provided for @spotDetailNearbySpotsWithin50m.
  ///
  /// In en, this message translates to:
  /// **'Nearby spots (within ~50m)'**
  String get spotDetailNearbySpotsWithin50m;

  /// No description provided for @spotDetailFoundSpot.
  ///
  /// In en, this message translates to:
  /// **'Found Spot'**
  String get spotDetailFoundSpot;

  /// No description provided for @spotDetailSpotIdLabel.
  ///
  /// In en, this message translates to:
  /// **'Spot ID: {id}'**
  String spotDetailSpotIdLabel(String id);

  /// No description provided for @spotDetailRemoveSelectionTooltip.
  ///
  /// In en, this message translates to:
  /// **'Remove selection'**
  String get spotDetailRemoveSelectionTooltip;

  /// No description provided for @spotDetailImageFailedToLoad.
  ///
  /// In en, this message translates to:
  /// **'Image failed to load'**
  String get spotDetailImageFailedToLoad;

  /// No description provided for @spotDetailClose.
  ///
  /// In en, this message translates to:
  /// **'Close'**
  String get spotDetailClose;

  /// No description provided for @spotDetailExpandMoreCount.
  ///
  /// In en, this message translates to:
  /// **'{count} more'**
  String spotDetailExpandMoreCount(int count);

  /// No description provided for @spotDetailSubmit.
  ///
  /// In en, this message translates to:
  /// **'Submit'**
  String get spotDetailSubmit;

  /// No description provided for @spotDetailDuplicateReportSelectRequired.
  ///
  /// In en, this message translates to:
  /// **'Please select the spot this is a duplicate of.'**
  String get spotDetailDuplicateReportSelectRequired;

  /// No description provided for @spotDetailDuplicateSearchEmpty.
  ///
  /// In en, this message translates to:
  /// **'Please enter a spot ID or URL'**
  String get spotDetailDuplicateSearchEmpty;

  /// No description provided for @spotDetailDuplicateInvalidUrl.
  ///
  /// In en, this message translates to:
  /// **'Invalid spot ID or URL format'**
  String get spotDetailDuplicateInvalidUrl;

  /// No description provided for @spotDetailDuplicateCannotSelectSelf.
  ///
  /// In en, this message translates to:
  /// **'Cannot mark a spot as duplicate of itself'**
  String get spotDetailDuplicateCannotSelectSelf;

  /// No description provided for @spotDetailDuplicateSpotNotFound.
  ///
  /// In en, this message translates to:
  /// **'Spot not found'**
  String get spotDetailDuplicateSpotNotFound;

  /// No description provided for @spotDetailDuplicateFailedLoadSpot.
  ///
  /// In en, this message translates to:
  /// **'Failed to load spot: {error}'**
  String spotDetailDuplicateFailedLoadSpot(String error);
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) => <String>[
    'de',
    'en',
    'es',
    'fr',
    'nl',
    'pt',
  ].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'de':
      return AppLocalizationsDe();
    case 'en':
      return AppLocalizationsEn();
    case 'es':
      return AppLocalizationsEs();
    case 'fr':
      return AppLocalizationsFr();
    case 'nl':
      return AppLocalizationsNl();
    case 'pt':
      return AppLocalizationsPt();
  }

  throw FlutterError(
    'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.',
  );
}
