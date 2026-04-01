import 'dart:js_interop';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:intl/intl.dart';
import 'package:parkour_spot/services/mobile_detection_service.dart';
import 'package:web/web.dart' as web;

/// One section of the support debug report (display + clipboard).
class SupportReportSection {
  const SupportReportSection({required this.title, required this.rows});

  final String title;
  final List<MapEntry<String, String>> rows;
}

/// Collects platform, locale, and web details for support (e.g. map rendering differences).
List<SupportReportSection> buildSupportDebugReportSections(BuildContext context) {
  final mq = MediaQuery.maybeOf(context);
  final appLocale = Localizations.maybeLocaleOf(context);
  final pd = View.maybeOf(context)?.platformDispatcher ??
      WidgetsBinding.instance.platformDispatcher;
  final systemLocale = pd.locale;
  final systemLocales = pd.locales;

  final sections = <SupportReportSection>[
    SupportReportSection(
      title: 'Flutter / device',
      rows: [
        MapEntry('kIsWeb', '$kIsWeb'),
        MapEntry('defaultTargetPlatform', '$defaultTargetPlatform'),
        MapEntry('logicalSize (dp)', mq == null ? 'unknown' : '${mq.size.width} x ${mq.size.height}'),
        MapEntry('devicePixelRatio', mq == null ? 'unknown' : '${mq.devicePixelRatio}'),
      ],
    ),
    SupportReportSection(
      title: 'Locale',
      rows: [
        MapEntry('MaterialApp locale (resolved)', appLocale?.toLanguageTag() ?? 'null'),
        MapEntry('PlatformDispatcher.locale', systemLocale.toLanguageTag()),
        MapEntry(
          'PlatformDispatcher.locales (ordered)',
          systemLocales.map((l) => l.toLanguageTag()).join(', '),
        ),
      ],
    ),
    SupportReportSection(
      title: 'Time zone',
      rows: [
        MapEntry('DateTime.timeZoneName', DateTime.now().timeZoneName),
        MapEntry('DateTime.timeZoneOffset', DateTime.now().timeZoneOffset.toString()),
      ],
    ),
    SupportReportSection(
      title: 'Mobile detection (app heuristics)',
      rows: [
        MapEntry('isMobileDevice', '${MobileDetectionService.isMobileDevice}'),
        MapEntry('isIOS', '${MobileDetectionService.isIOS}'),
        MapEntry('isAndroid', '${MobileDetectionService.isAndroid}'),
        MapEntry('isRunningAsPWA', '${MobileDetectionService.isRunningAsPWA}'),
        MapEntry('isRunningInBrowser', '${MobileDetectionService.isRunningInBrowser}'),
        MapEntry('preferredMapsApp', MobileDetectionService.preferredMapsApp),
      ],
    ),
  ];

  final deviceMap = MobileDetectionService.detailedDeviceInfo;
  sections.add(
    SupportReportSection(
      title: 'MobileDetectionService.detailedDeviceInfo',
      rows: [
        for (final e in deviceMap.entries) MapEntry(e.key, '${e.value}'),
      ],
    ),
  );

  if (kIsWeb) {
    sections.add(
      SupportReportSection(
        title: 'Web browser',
        rows: [
          MapEntry('navigator.language', web.window.navigator.language),
          MapEntry(
            'navigator.languages',
            web.window.navigator.languages.toDart.map((s) => s.toDart).join(', '),
          ),
          MapEntry('navigator.userAgent', web.window.navigator.userAgent),
          MapEntry('location.href', web.window.location.href),
        ],
      ),
    );
  }

  if (kIsWeb) {
    sections.add(
      const SupportReportSection(
        title: 'Google Maps in this app (web)',
        rows: [
          MapEntry(
            'Maps JS API script',
            'Loaded from web/index.html without language= or region= query parameters; '
                'Google uses browser defaults unless set.',
          ),
        ],
      ),
    );
  } else {
    sections.add(
      const SupportReportSection(
        title: 'Google Maps in this app (native)',
        rows: [
          MapEntry(
            'Map SDK',
            'google_maps_flutter uses the platform Maps SDK; labeling/region behavior follows '
                'Google and the device locale/region settings, not the web script URL.',
          ),
        ],
      ),
    );
  }

  return sections;
}

/// Plain-text report for clipboard / email.
String buildSupportDebugReportText(BuildContext context) {
  final buffer = StringBuffer();
  buffer.writeln('=== Parkour·Spot support debug ===');
  buffer.writeln('Generated: ${DateFormat('yyyy-MM-dd HH:mm:ss').format(DateTime.now())}');
  buffer.writeln('');
  for (final section in buildSupportDebugReportSections(context)) {
    buffer.writeln('--- ${section.title} ---');
    for (final row in section.rows) {
      buffer.writeln('${row.key}: ${row.value}');
    }
    buffer.writeln('');
  }
  return buffer.toString();
}
