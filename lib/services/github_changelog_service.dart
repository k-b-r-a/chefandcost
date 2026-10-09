import 'dart:convert';
import 'dart:io' show Platform;
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

/// Model representing a GitHub release.
class GithubRelease {
  final String tagName;
  final String name;
  final DateTime? publishedAt;
  final String body;

  const GithubRelease({
    required this.tagName,
    required this.name,
    this.publishedAt,
    required this.body,
  });

  /// Formatted version string guaranteed to have a leading 'v' (e.g., 'v0.1.0-beta+8').
  String get displayVersion {
    if (tagName.isEmpty) return name;
    return tagName.startsWith('v') ? tagName : 'v$tagName';
  }

  factory GithubRelease.fromJson(Map<String, dynamic> json) {
    return GithubRelease(
      tagName: json['tag_name'] as String? ?? '',
      name: json['name'] as String? ?? (json['tag_name'] as String? ?? ''),
      publishedAt: json['published_at'] != null
          ? DateTime.tryParse(json['published_at'] as String)
          : null,
      body: json['body'] as String? ?? '',
    );
  }

  Map<String, dynamic> toJson() => {
    'tag_name': tagName,
    'name': name,
    'published_at': publishedAt?.toIso8601String(),
    'body': body,
  };
}

/// Service to dynamically query, paginate, and cache releases from the GitHub Releases API.
class GithubChangelogService {
  final String owner;
  final String repo;
  final http.Client _client;

  // In-memory cache
  static List<GithubRelease>? _inMemoryCache;
  static DateTime? _inMemoryCacheTime;

  /// Cache time-to-live to prevent hitting GitHub unauthenticated rate limits (60 requests/hour).
  static const Duration cacheTtl = Duration(hours: 1);

  final bool _isCustomClient;

  GithubChangelogService({
    this.owner = 'k-b-r-a',
    this.repo = 'chefandcost',
    http.Client? client,
  })  : _client = client ?? http.Client(),
        _isCustomClient = client != null;

  String get _cacheKey => 'github_changelog_cache_${owner}_$repo';
  String get _cacheTimeKey => 'github_changelog_cache_time_${owner}_$repo';

  /// Resets in-memory cache (primarily for tests or hard reloads).
  static void clearMemoryCache() {
    _inMemoryCache = null;
    _inMemoryCacheTime = null;
  }

  /// Fetches releases using paginated requests (`while` loop) with caching and fallback.
  Future<List<GithubRelease>> fetchReleases({
    bool forceRefresh = false,
    int maxReleases = 30,
    bool isSpanish = false,
  }) async {
    // Fast path: in widget tests without an injected client, return bundled releases directly
    if (!_isCustomClient && !kIsWeb) {
      try {
        if (Platform.environment['FLUTTER_TEST'] == 'true') {
          return getBundledFallbackReleases(isSpanish: isSpanish);
        }
      } catch (_) {}
    }
    // 1. In-memory cache check
    if (!forceRefresh && _inMemoryCache != null && _inMemoryCacheTime != null) {
      if (DateTime.now().difference(_inMemoryCacheTime!) < cacheTtl) {
        return _inMemoryCache!;
      }
    }

    // 2. SharedPreferences persistent cache check
    if (!forceRefresh) {
      final cached = await _getCachedReleasesFromPrefs();
      if (cached != null && cached.isNotEmpty) {
        _inMemoryCache = cached;
        _inMemoryCacheTime = DateTime.now();
        return cached;
      }
    }

    // 3. Paginated network fetch from GitHub API using while loop
    try {
      int page = 1;
      final List<GithubRelease> fetchedReleases = [];
      bool hasMore = true;
      bool apiCallSucceeded = false;

      while (hasMore && fetchedReleases.length < maxReleases) {
        final uri = Uri.parse(
          'https://api.github.com/repos/$owner/$repo/releases?per_page=10&page=$page',
        );

        final response = await _client.get(
          uri,
          headers: const {
            'Accept': 'application/vnd.github.v3+json',
            'User-Agent': 'ChefAndCost-App',
          },
        ).timeout(const Duration(seconds: 10));

        if (response.statusCode == 200) {
          apiCallSucceeded = true;
          final dynamic decoded = jsonDecode(response.body);
          if (decoded is List) {
            if (decoded.isEmpty) {
              hasMore = false;
              break;
            }

            for (final item in decoded) {
              if (item is Map<String, dynamic>) {
                fetchedReleases.add(GithubRelease.fromJson(item));
                if (fetchedReleases.length >= maxReleases) {
                  hasMore = false;
                  break;
                }
              }
            }

            // If fewer than 10 releases were returned, we have reached the last page
            if (decoded.length < 10) {
              hasMore = false;
            } else {
              page++;
            }
          } else {
            hasMore = false;
          }
        } else {
          // If HTTP error or rate limit hit, exit pagination loop
          hasMore = false;
          break;
        }
      }

      if (apiCallSucceeded) {
        _inMemoryCache = fetchedReleases;
        _inMemoryCacheTime = DateTime.now();
        await _saveReleasesToPrefs(fetchedReleases);
        return fetchedReleases;
      }
    } catch (_) {
      // Gracefully catch network / timeout / formatting errors
    }

    // 4. Graceful offline fallback: return persistent cache if available
    final fallbackCache = await _getCachedReleasesFromPrefs();
    if (fallbackCache != null && fallbackCache.isNotEmpty) {
      _inMemoryCache = fallbackCache;
      _inMemoryCacheTime = DateTime.now();
      return fallbackCache;
    }

    if (_inMemoryCache != null && _inMemoryCache!.isNotEmpty) {
      return _inMemoryCache!;
    }

    // 5. Final offline fallback: return bundled releases
    return getBundledFallbackReleases(isSpanish: isSpanish);
  }

  Future<List<GithubRelease>?> _getCachedReleasesFromPrefs() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final jsonStr = prefs.getString(_cacheKey);
      if (jsonStr != null && jsonStr.isNotEmpty) {
        final decoded = jsonDecode(jsonStr);
        if (decoded is List) {
          return decoded
              .whereType<Map<String, dynamic>>()
              .map(GithubRelease.fromJson)
              .toList();
        }
      }
    } catch (_) {}
    return null;
  }

  Future<void> _saveReleasesToPrefs(List<GithubRelease> releases) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final jsonStr = jsonEncode(releases.map((r) => r.toJson()).toList());
      await prefs.setString(_cacheKey, jsonStr);
      await prefs.setInt(_cacheTimeKey, DateTime.now().millisecondsSinceEpoch);
    } catch (_) {}
  }

  /// Bundled fallback releases in markdown format for offline first launches.
  static List<GithubRelease> getBundledFallbackReleases({bool isSpanish = false}) {
    if (isSpanish) {
      return const [
        GithubRelease(
          tagName: 'v0.1.0-beta+8',
          name: 'Chef&Cost v0.1.0-beta+8',
          body: '''### Destacado
- Escalado inverso de recetas por ingrediente objetivo con aviso visual temporal y opción de guardado permanente.
- Ordenamiento de ingredientes por tipo (Sólido, Líquido, Piezas) y alfabético.
- Aislamiento de búsqueda independiente entre ingredientes y recetas.
- Autocapitalización en campos de texto y mejoras de estabilidad en sincronización en la nube.''',
        ),
        GithubRelease(
          tagName: 'v0.1.0-beta+7',
          name: 'Chef&Cost v0.1.0-beta+7',
          body: '''### Destacado
- Corrección en selector de copia de seguridad local: eliminación de restricciones de extensiones para permitir seleccionar cualquier archivo SQLite.''',
        ),
        GithubRelease(
          tagName: 'v0.1.0-beta+6',
          name: 'Chef&Cost v0.1.0-beta+6',
          body: '''### Destacado
- Actualización oficial del correo de contacto y soporte del desarrollador (`kbradevp@gmail.com`).
- Optimizaciones de estabilidad y ajustes de despliegue en canal Beta.''',
        ),
        GithubRelease(
          tagName: 'v0.1.0-beta+5',
          name: 'Chef&Cost v0.1.0-beta+5',
          body: '''### Destacado
- Copia de seguridad local: exportación y carga de archivos SQLite desde el dispositivo.
- Nueva sección Acerca de con información del desarrollador, esquema DB y términos.
- Ajuste del tamaño de la barra de navegación y mejoras generales.''',
        ),
        GithubRelease(
          tagName: 'v0.1.0-beta+4',
          name: 'Chef&Cost v0.1.0-beta+4',
          body: '''### Destacado
- Sincronización en la nube con Firebase Firestore y Google Drive.
- Temporizadores de recetas con auto-dismiss y alarmas acústicas.
- Selector y buscador reactivo de ingredientes en recetas.
- Conversor de unidades optimizado sin ceros innecesarios.
- Regla de tres con soporte de decimales y unidades automáticas.
- Configuración del tamaño de la barra de navegación.
- Pantalla Acerca de con registro de cambios, privacidad, diagnóstico y licencias.''',
        ),
        GithubRelease(
          tagName: 'v0.1.0-beta+3',
          name: 'Chef&Cost v0.1.0-beta+3',
          body: '''### Destacado
- Nueva barra de navegación inferior flotante adaptativa con indicador suave.
- Soporte completo de localización y accesibilidad en español e inglés.
- Ajustes de física de desplazamiento, transiciones y modo zurdo.''',
        ),
        GithubRelease(
          tagName: 'v0.1.0-beta+2',
          name: 'Chef&Cost v0.1.0-beta+2',
          body: '''### Destacado
- Métricas financieras por porción y receta.
- Reordenamiento interactivo de ingredientes en costos.
- Persistencia local con base de datos SQLite (Drift).''',
        ),
        GithubRelease(
          tagName: 'v0.1.0-beta+1',
          name: 'Chef&Cost v0.1.0-beta+1',
          body: '''### Destacado
- Lanzamiento inicial de Chef&Cost.
- Gestión de recetas, ingredientes, conversión de medidas y herramientas.''',
        ),
      ];
    } else {
      return const [
        GithubRelease(
          tagName: 'v0.1.0-beta+8',
          name: 'Chef&Cost v0.1.0-beta+8',
          body: '''### Highlights
- Target recipe scaling by single ingredient with temporary banner indicator and permanent save option.
- Ingredient sorting controls by type (Solid, Liquid, Pieces) and alphabetical order.
- Isolated search states between ingredients and recipes.
- Text field auto-capitalization and cloud sync stability improvements.''',
        ),
        GithubRelease(
          tagName: 'v0.1.0-beta+7',
          name: 'Chef&Cost v0.1.0-beta+7',
          body: '''### Highlights
- Local backup picker fix: removed restrictive extension filters to allow selecting any SQLite backup file.''',
        ),
        GithubRelease(
          tagName: 'v0.1.0-beta+6',
          name: 'Chef&Cost v0.1.0-beta+6',
          body: '''### Highlights
- Official developer support & contact email update (`kbradevp@gmail.com`).
- Beta channel deployment refinements and stability fixes.''',
        ),
        GithubRelease(
          tagName: 'v0.1.0-beta+5',
          name: 'Chef&Cost v0.1.0-beta+5',
          body: '''### Highlights
- Local backup: import and export SQLite files directly to device storage.
- Revamped About screen with developer contact, DB schema version, and privacy terms.
- Navigation bar size preference and stability enhancements.''',
        ),
        GithubRelease(
          tagName: 'v0.1.0-beta+4',
          name: 'Chef&Cost v0.1.0-beta+4',
          body: '''### Highlights
- Cloud synchronization with Firebase Firestore and Google Drive.
- Recipe timers with auto-dismiss and sound alarms.
- Reactive ingredient selector and live search in recipes.
- Unit converter optimized with clean decimal formatting.
- Rule of three with decimal support and auto-unit resolution.
- Navigation bar size customization.
- About screen with changelog, privacy policy, diagnostics, and licenses.''',
        ),
        GithubRelease(
          tagName: 'v0.1.0-beta+3',
          name: 'Chef&Cost v0.1.0-beta+3',
          body: '''### Highlights
- New floating adaptive bottom navigation bar with fluid indicator.
- Full localization and accessibility in English and Spanish.
- Tuned scroll physics, screen transitions, and left-handed mode.''',
        ),
        GithubRelease(
          tagName: 'v0.1.0-beta+2',
          name: 'Chef&Cost v0.1.0-beta+2',
          body: '''### Highlights
- Financial portion and recipe yield metrics.
- Interactive ingredient cost reordering.
- Local SQLite database persistence (Drift).''',
        ),
        GithubRelease(
          tagName: 'v0.1.0-beta+1',
          name: 'Chef&Cost v0.1.0-beta+1',
          body: '''### Highlights
- Initial release of Chef&Cost.
- Recipe costing, ingredient manager, units, and kitchen utilities.''',
        ),
      ];
    }
  }
}
