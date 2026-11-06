import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:intl/intl.dart';
import '../constants.dart';
import '../l10n/app_localizations.dart';
import '../services/github_changelog_service.dart';

/// Interactive UI view displaying GitHub release notes with markdown rendering,
/// pagination loading, caching, and clean empty/error states.
class GithubChangelogView extends StatefulWidget {
  final GithubChangelogService? service;
  final ScrollPhysics? physics;
  final bool shrinkWrap;

  const GithubChangelogView({
    super.key,
    this.service,
    this.physics,
    this.shrinkWrap = false,
  });

  @override
  State<GithubChangelogView> createState() => _GithubChangelogViewState();
}

class _GithubChangelogViewState extends State<GithubChangelogView> {
  late GithubChangelogService _service;
  late Future<List<GithubRelease>> _releasesFuture;

  @override
  void initState() {
    super.initState();
    _service = widget.service ?? GithubChangelogService();
    _loadReleases(forceRefresh: false);
  }

  @override
  void didUpdateWidget(covariant GithubChangelogView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.service != oldWidget.service) {
      _service = widget.service ?? GithubChangelogService();
      _loadReleases(forceRefresh: false);
    }
  }

  void _loadReleases({bool forceRefresh = false}) {
    final isSpanish = WidgetsBinding.instance.platformDispatcher.locale.languageCode == 'es';
    setState(() {
      _releasesFuture = _service.fetchReleases(
        forceRefresh: forceRefresh,
        isSpanish: isSpanish,
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context)!;
    final locale = Localizations.localeOf(context).toString();

    return FutureBuilder<List<GithubRelease>>(
      future: _releasesFuture,
      builder: (context, snapshot) {
        // 1. Loading State
        if (snapshot.connectionState == ConnectionState.waiting) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(32.0),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const CircularProgressIndicator(),
                  const SizedBox(height: 16),
                  Text(
                    l10n.settings_about_changelog_loading,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
          );
        }

        // 2. Error State
        if (snapshot.hasError) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.cloud_off_rounded,
                    size: 48,
                    color: theme.colorScheme.error,
                  ),
                  const SizedBox(height: 12),
                  Text(
                    l10n.settings_about_changelog_error,
                    textAlign: TextAlign.center,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 16),
                  FilledButton.icon(
                    onPressed: () => _loadReleases(forceRefresh: true),
                    icon: const Icon(Icons.refresh_rounded, size: 18),
                    label: Text(l10n.settings_about_changelog_retry),
                  ),
                ],
              ),
            ),
          );
        }

        final releases = snapshot.data ?? [];

        // 3. Empty State
        if (releases.isEmpty) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.history_toggle_off_rounded,
                    size: 48,
                    color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.6),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    l10n.settings_about_changelog_empty,
                    textAlign: TextAlign.center,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 16),
                  OutlinedButton.icon(
                    onPressed: () => _loadReleases(forceRefresh: true),
                    icon: const Icon(Icons.refresh_rounded, size: 18),
                    label: Text(l10n.settings_about_changelog_refresh),
                  ),
                ],
              ),
            ),
          );
        }

        // 4. Populated Releases List
        return ListView.separated(
          shrinkWrap: widget.shrinkWrap,
          physics: widget.physics,
          padding: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 4.0),
          itemCount: releases.length,
          separatorBuilder: (_, index) => const Divider(height: 28),
          itemBuilder: (context, index) {
            final release = releases[index];
            final isCurrent = index == 0 || release.displayVersion.contains(kAppVersion);

            String formattedDate = '';
            if (release.publishedAt != null) {
              try {
                formattedDate = DateFormat.yMMMMd(locale).format(release.publishedAt!);
              } catch (_) {
                formattedDate = DateFormat.yMMMMd().format(release.publishedAt!);
              }
            }

            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Release Header: Version tag, current badge, and published date
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        Text(
                          release.displayVersion,
                          style: theme.textTheme.titleSmall?.copyWith(
                            fontWeight: FontWeight.bold,
                            color: isCurrent ? theme.colorScheme.primary : null,
                          ),
                        ),
                        if (isCurrent) ...[
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: theme.colorScheme.primaryContainer,
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              l10n.settings_about_version_current,
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                                color: theme.colorScheme.onPrimaryContainer,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                    if (formattedDate.isNotEmpty)
                      Text(
                        formattedDate,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 8),

                // Markdown Release Notes
                if (release.body.trim().isNotEmpty)
                  MarkdownBody(
                    data: release.body,
                    selectable: true,
                    styleSheet: MarkdownStyleSheet.fromTheme(theme).copyWith(
                      p: theme.textTheme.bodyMedium?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                        height: 1.4,
                      ),
                      listBullet: TextStyle(
                        color: theme.colorScheme.primary,
                        fontWeight: FontWeight.bold,
                      ),
                      h3: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: theme.colorScheme.onSurface,
                      ),
                      code: TextStyle(
                        backgroundColor: theme.colorScheme.surfaceContainerHighest,
                        fontFamily: 'monospace',
                        fontSize: 12,
                      ),
                    ),
                  )
                else
                  Text(
                    release.name,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
              ],
            );
          },
        );
      },
    );
  }
}

/// Helper to display the dynamic GitHub changelog in a standardized modal dialog.
Future<void> showGithubChangelogDialog({
  required BuildContext context,
  GithubChangelogService? service,
}) {
  final theme = Theme.of(context);
  final l10n = AppLocalizations.of(context)!;

  return showDialog<void>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: Row(
        children: [
          Icon(Icons.history_rounded, color: theme.colorScheme.primary),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              l10n.settings_about_changelog,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
      content: SizedBox(
        width: double.maxFinite,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxHeight: 520, maxWidth: 640),
          child: GithubChangelogView(service: service),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(ctx).pop(),
          child: Text(l10n.close_button),
        ),
      ],
    ),
  );
}
