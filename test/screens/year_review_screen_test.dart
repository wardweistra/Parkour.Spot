import 'package:firebase_auth/firebase_auth.dart' as firebase_auth;
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:parkour_spot/l10n/app_localizations.dart';
import 'package:parkour_spot/models/year_review.dart';
import 'package:parkour_spot/screens/profile/year_review_screen.dart';
import 'package:parkour_spot/services/auth_service.dart';
import 'package:parkour_spot/services/year_review_service.dart';
import 'package:parkour_spot/utils/year_review_window.dart';
import 'package:parkour_spot/widgets/year_review_banner.dart';
import 'package:provider/provider.dart';

Map<String, dynamic> reviewMap({int moreCount = 0}) => {
  'userId': 'u1',
  'username': 'noor',
  'name': 'Noor',
  'year': 2026,
  'sentence': 'In 2026 Noor put 1 spot on the map in Utrecht',
  'soFar': true,
  'frames': [
    {
      'spotId': 's1',
      'kind': 'spotsAdded',
      'name': 'Parkour Park Leeuwesteyn',
      'city': 'Utrecht',
      'imageUrl': null,
      'date': '2026-06-05T00:00:00.000Z',
    },
    {'spotId': 's2', 'kind': 'unknown', 'name': 'Dropped'},
  ],
  'moreCount': moreCount,
  'pagePath': '/year/2026/@noor',
  'storyPath': '/year/2026/@noor/story.jpg',
  'squarePath': '/year/2026/@noor/square.jpg',
};

class FakeYearReviewService extends YearReviewService {
  FakeYearReviewService(this.review);

  final YearReview? review;
  int loads = 0;

  @override
  Future<YearReview?> getYearReview({
    required String userIdOrUsername,
    required int year,
  }) async {
    loads++;
    return review;
  }

  @override
  Uri cardUrl(YearReview review, YearReviewCardFormat format) =>
      Uri.parse('https://example.invalid/card.jpg');
}

class FakeAuthService extends ChangeNotifier implements AuthService {
  FakeAuthService(this.uid);

  final String? uid;

  @override
  firebase_auth.User? get currentUser => uid == null ? null : _FakeUser(uid!);

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _FakeUser implements firebase_auth.User {
  _FakeUser(this.uid);

  @override
  final String uid;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

Future<void> pumpScreen(
  WidgetTester tester, {
  required YearReview? review,
  String? signedInUid,
}) async {
  await tester.pumpWidget(
    ChangeNotifierProvider<AuthService>.value(
      value: FakeAuthService(signedInUid),
      child: MaterialApp(
        localizationsDelegates: const [
          AppLocalizations.delegate,
          ...GlobalMaterialLocalizations.delegates,
        ],
        supportedLocales: AppLocalizations.supportedLocales,
        home: YearReviewScreen(
          year: 2026,
          userIdOrUsername: '@noor',
          service: FakeYearReviewService(review),
        ),
      ),
    ),
  );
  await tester.pump();
  await tester.pump();
}

void main() {
  group('YearReview.fromMap', () {
    test('parses the callable response and skips unknown frame kinds', () {
      final review = YearReview.fromMap(reviewMap(moreCount: 3))!;
      expect(review.handle, '@noor');
      expect(review.frames, hasLength(1));
      expect(review.frames.single.kind, YearReviewFrameKind.spotAdded);
      expect(review.frames.single.date, DateTime.utc(2026, 6, 5));
      expect(review.moreCount, 3);
      expect(review.soFar, isTrue);
    });

    test('rejects incomplete responses', () {
      expect(YearReview.fromMap({'userId': 'u1'}), isNull);
      expect(YearReview.fromMap(null), isNull);
    });
  });

  group('promotion window', () {
    test('promotes December and January only', () {
      expect(promotedReviewYear(DateTime.utc(2026, 12, 1)), 2026);
      expect(promotedReviewYear(DateTime.utc(2027, 1, 31, 23)), 2026);
      expect(promotedReviewYear(DateTime.utc(2027, 2, 1)), isNull);
      expect(promotedReviewYear(DateTime.utc(2026, 11, 30)), isNull);
    });

    test('builds page paths from username or uid', () {
      expect(
        yearReviewPagePath(year: 2026, userId: 'u1', username: 'noor'),
        '/year/2026/@noor',
      );
      expect(yearReviewPagePath(year: 2026, userId: 'u1'), '/year/2026/u1');
    });
  });

  group('YearReviewScreen', () {
    testWidgets('owner sees share actions and the so-far note', (tester) async {
      final semantics = tester.ensureSemantics();
      await pumpScreen(
        tester,
        review: YearReview.fromMap(reviewMap()),
        signedInUid: 'u1',
      );
      expect(find.text('Share to your story'), findsOneWidget);
      expect(find.text('Share square image'), findsOneWidget);
      expect(find.text('Copy link'), findsOneWidget);
      expect(
        find.text('These numbers keep updating until 31 December.'),
        findsOneWidget,
      );
      expect(find.text('Open the map'), findsNothing);
      expect(find.text('A map made by people who train'), findsNothing);
      expect(find.text('Add a spot you know'), findsNothing);
      expect(find.text('Parkour Park Leeuwesteyn'), findsOneWidget);
      expect(find.text('Utrecht · Added'), findsOneWidget);
      expect(
        find.bySemanticsLabel(
          'Year in review card: In 2026 Noor put 1 spot on the map in Utrecht',
        ),
        findsOneWidget,
      );
      semantics.dispose();
    });

    testWidgets('visitors get the map and the profile instead', (tester) async {
      await pumpScreen(
        tester,
        review: YearReview.fromMap(reviewMap(moreCount: 4)),
      );
      expect(find.text('A map made by people who train'), findsOneWidget);
      expect(
        find.textContaining('comes from people like Noor'),
        findsOneWidget,
      );
      expect(find.text('Add a spot you know'), findsOneWidget);
      expect(find.text('Open the map'), findsOneWidget);
      expect(
        find.text(
          'Add something before 31 December and you get your own 2026 card.',
        ),
        findsOneWidget,
      );
      expect(find.text('Is this you? Log in to share'), findsOneWidget);
      expect(find.text("See Noor's profile"), findsOneWidget);
      expect(find.text('Share to your story'), findsNothing);
      expect(find.text('And 4 more spots with photos'), findsOneWidget);
    });

    testWidgets('private or empty reviews show the not-found state', (
      tester,
    ) async {
      await pumpScreen(tester, review: null);
      expect(find.text('No year in review here'), findsOneWidget);
      expect(find.text('Open the map'), findsOneWidget);
    });

    testWidgets('lays the card beside the details on wide screens', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(1280, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await pumpScreen(tester, review: YearReview.fromMap(reviewMap()));
      final card = tester.getTopLeft(find.byType(AspectRatio).first);
      final button = tester.getTopLeft(find.text('Open the map'));
      expect(button.dx, greaterThan(card.dx + 300));
      expect(tester.takeException(), isNull);
    });
  });

  group('YearReviewBanner', () {
    testWidgets('names your year or someone else\'s', (tester) async {
      var opened = 0;
      Future<void> pump(String? name) => tester.pumpWidget(
        MaterialApp(
          localizationsDelegates: const [
            AppLocalizations.delegate,
            ...GlobalMaterialLocalizations.delegates,
          ],
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: YearReviewBanner(
              year: 2026,
              name: name,
              onOpen: () => opened++,
            ),
          ),
        ),
      );
      await pump(null);
      expect(find.text('Your 2026 on Parkour·Spot'), findsOneWidget);
      await tester.tap(find.byType(YearReviewBanner));
      expect(opened, 1);
      await pump('Noor');
      expect(find.text("Noor's 2026 on Parkour·Spot"), findsOneWidget);
    });
  });
}
