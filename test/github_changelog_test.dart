import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:recipetools/l10n/app_localizations.dart';
import 'package:recipetools/services/github_changelog_service.dart';
import 'package:recipetools/widgets/github_changelog_view.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    GithubChangelogService.clearMemoryCache();
  });

  group('GithubChangelogService Unit Tests', () {
    test('Paginates releases using while loop and parses fields correctly', () async {
      int requestCount = 0;

      final mockClient = MockClient((request) async {
        requestCount++;
        final page = request.url.queryParameters['page'];

        if (page == '1') {
          final page1 = [
            for (int i = 1; i <= 10; i++)
              {
                'tag_name': 'v0.1.0-beta+$i',
                'name': 'Release $i',
                'published_at': '2026-10-0${i % 9 + 1}T12:00:00Z',
                'body': '### Notes for release $i\n- Feature $i implemented',
              }
          ];
          return http.Response(jsonEncode(page1), 200);
        } else if (page == '2') {
          final page2 = [
            {
              'tag_name': 'v0.1.0-beta+11',
              'name': 'Release 11',
              'published_at': '2026-10-11T12:00:00Z',
              'body': '### Notes for release 11\n- Feature 11 implemented',
            }
          ];
          return http.Response(jsonEncode(page2), 200);
        } else {
          return http.Response(jsonEncode([]), 200);
        }
      });

      final service = GithubChangelogService(
        owner: 'test-owner',
        repo: 'test-repo',
        client: mockClient,
      );

      final releases = await service.fetchReleases();

      expect(requestCount, 2); // Page 1 returned 10, page 2 returned 1 (< 10), so loop completed
      expect(releases.length, 11);
      expect(releases.first.tagName, 'v0.1.0-beta+1');
      expect(releases.first.displayVersion, 'v0.1.0-beta+1');
      expect(releases.first.name, 'Release 1');
      expect(releases.first.publishedAt, isNotNull);
      expect(releases.first.body, contains('Feature 1 implemented'));
    });

    test('Caches releases in memory and SharedPreferences to prevent rate limit hits', () async {
      int apiCallCount = 0;

      final mockClient = MockClient((request) async {
        apiCallCount++;
        return http.Response(
          jsonEncode([
            {
              'tag_name': 'v0.1.0-beta+8',
              'name': 'Beta 8',
              'published_at': '2026-10-09T12:00:00Z',
              'body': '### Highlights\n- Dynamic changelog from GitHub',
            }
          ]),
          200,
        );
      });

      final service = GithubChangelogService(
        owner: 'test-owner',
        repo: 'test-repo',
        client: mockClient,
      );

      // First call hits network
      final firstFetch = await service.fetchReleases();
      expect(apiCallCount, 1);
      expect(firstFetch.length, 1);

      // Second call uses cache (network count unchanged)
      final secondFetch = await service.fetchReleases();
      expect(apiCallCount, 1);
      expect(secondFetch.length, 1);

      // Force refresh bypasses cache and hits network
      final forceRefresh = await service.fetchReleases(forceRefresh: true);
      expect(apiCallCount, 2);
      expect(forceRefresh.length, 1);
    });

    test('Gracefully falls back to cache or bundled data when rate limited or offline', () async {
      final failingClient = MockClient((request) async {
        return http.Response('Rate limit exceeded', 403);
      });

      final service = GithubChangelogService(
        owner: 'test-owner',
        repo: 'test-repo',
        client: failingClient,
      );

      final releases = await service.fetchReleases();

      // Gracefully returns bundled fallback releases without throwing
      expect(releases, isNotEmpty);
      expect(releases.first.tagName, contains('beta'));
    });
  });

  group('GithubChangelogView UI Widget Tests', () {
    Widget buildTestApp(Widget child) {
      return MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        locale: const Locale('es'),
        home: Scaffold(body: child),
      );
    }

    testWidgets('Renders releases with MarkdownBody, tags and badges', (tester) async {
      final mockClient = MockClient((request) async {
        return http.Response(
          jsonEncode([
            {
              'tag_name': 'v0.1.0-beta+8',
              'name': 'Release 0.1.0-beta+8',
              'published_at': '2026-10-09T10:00:00Z',
              'body': '### Destacado\n- **Nuevo** soporte de changelog dinámico',
            },
            {
              'tag_name': 'v0.1.0-beta+7',
              'name': 'Release 0.1.0-beta+7',
              'published_at': '2026-10-07T10:00:00Z',
              'body': '### Destacado\n- Correcciones generales',
            },
          ]),
          200,
        );
      });

      final service = GithubChangelogService(client: mockClient);

      await tester.pumpWidget(buildTestApp(GithubChangelogView(service: service)));
      await tester.pumpAndSettle();

      expect(find.text('v0.1.0-beta+8'), findsOneWidget);
      expect(find.text('v0.1.0-beta+7'), findsOneWidget);
      expect(find.byType(MarkdownBody), findsNWidgets(2));
      expect(find.textContaining('soporte de changelog dinámico'), findsOneWidget);
    });

    testWidgets('Renders empty state when no releases are available', (tester) async {
      final emptyClient = MockClient((request) async {
        return http.Response(jsonEncode([]), 200);
      });

      final service = GithubChangelogService(client: emptyClient);

      await tester.pumpWidget(buildTestApp(GithubChangelogView(service: service)));
      await tester.pumpAndSettle();

      expect(find.byIcon(Icons.history_toggle_off_rounded), findsOneWidget);
      expect(find.text('No se encontraron notas de versión.'), findsOneWidget);
      expect(find.text('Actualizar'), findsOneWidget);
    });

    testWidgets('Opens dialog using showGithubChangelogDialog and closes cleanly', (tester) async {
      final mockClient = MockClient((request) async {
        return http.Response(
          jsonEncode([
            {
              'tag_name': 'v0.1.0-beta+8',
              'name': 'Beta 8',
              'published_at': '2026-10-09T10:00:00Z',
              'body': 'Changelog inside modal dialog',
            }
          ]),
          200,
        );
      });

      final service = GithubChangelogService(client: mockClient);

      await tester.pumpWidget(
        buildTestApp(
          Builder(
            builder: (context) => ElevatedButton(
              onPressed: () => showGithubChangelogDialog(context: context, service: service),
              child: const Text('Open Dialog'),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Open Dialog'));
      await tester.pumpAndSettle();

      expect(find.byType(AlertDialog), findsOneWidget);
      expect(find.text('Registro de Cambios'), findsOneWidget);
      expect(find.text('v0.1.0-beta+8'), findsOneWidget);

      await tester.tap(find.text('Cerrar'));
      await tester.pumpAndSettle();

      expect(find.byType(AlertDialog), findsNothing);
    });
  });
}
