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
    // In widget tests without an injected client, return empty list immediately to prevent test hangs
    if (!_isCustomClient && !kIsWeb) {
      try {
        if (Platform.environment['FLUTTER_TEST'] == 'true') {
          return const [];
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

    // 5. Final offline fallback: return empty list
    return const [];
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
}
