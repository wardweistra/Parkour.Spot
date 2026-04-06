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
