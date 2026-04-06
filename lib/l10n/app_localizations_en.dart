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
}
