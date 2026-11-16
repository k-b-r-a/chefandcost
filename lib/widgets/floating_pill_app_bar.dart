import 'package:flutter/material.dart';

class ProgressiveBlurBackground extends StatelessWidget {
  const ProgressiveBlurBackground({
    super.key,
    required this.progress,
    required this.surfaceColor,
    this.animationsEnabled = true,
  });

  final double progress;
  final Color surfaceColor;
  final bool animationsEnabled;

  @override
  Widget build(BuildContext context) {
    final amount = progress.clamp(0.0, 1.0).toDouble();
    if (amount <= 0.01) return const SizedBox.expand();

    return RepaintBoundary(
      child: IgnorePointer(
        child: DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              stops: const [0.0, 0.72, 0.88, 1.0],
              colors: [
                surfaceColor.withValues(alpha: 0.96 * amount),
                surfaceColor.withValues(alpha: 0.96 * amount),
                surfaceColor.withValues(alpha: 0.82 * amount),
                surfaceColor.withValues(alpha: 0.0),
              ],
            ),
          ),
          child: const SizedBox.expand(),
        ),
      ),
    );
  }
}

class _HeaderScrollProgressBuilder extends StatefulWidget {
  const _HeaderScrollProgressBuilder({
    required this.controller,
    required this.scrollExtent,
    required this.builder,
  });

  final ScrollController controller;
  final double scrollExtent;
  final Widget Function(BuildContext context, double progress) builder;

  @override
  State<_HeaderScrollProgressBuilder> createState() =>
      _HeaderScrollProgressBuilderState();
}

class _HeaderScrollProgressBuilderState
    extends State<_HeaderScrollProgressBuilder> {
  late double _progress;

  double _computeProgress() {
    if (!widget.controller.hasClients || widget.scrollExtent <= 0) {
      return 0.0;
    }
    final offset = widget.controller.offset;
    if (offset <= 0.0) return 0.0;
    if (offset >= widget.scrollExtent) return 1.0;
    final raw = (offset / widget.scrollExtent).clamp(0.0, 1.0);
    return ((raw * 50).round() / 50.0).clamp(0.0, 1.0).toDouble();
  }

  void _onScroll() {
    if (!widget.controller.hasClients || widget.scrollExtent <= 0) return;
    final offset = widget.controller.offset;
    if (_progress == 1.0 && offset >= widget.scrollExtent) {
      return;
    }
    if (_progress == 0.0 && offset <= 0.0) {
      return;
    }
    final next = _computeProgress();
    if (next != _progress) {
      setState(() {
        _progress = next;
      });
    }
  }

  @override
  void initState() {
    super.initState();
    _progress = _computeProgress();
    widget.controller.addListener(_onScroll);
  }

  @override
  void didUpdateWidget(covariant _HeaderScrollProgressBuilder oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller != widget.controller) {
      oldWidget.controller.removeListener(_onScroll);
      widget.controller.addListener(_onScroll);
      _progress = _computeProgress();
    } else if (oldWidget.scrollExtent != widget.scrollExtent) {
      _progress = _computeProgress();
    }
  }

  @override
  void dispose() {
    widget.controller.removeListener(_onScroll);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return widget.builder(context, _progress);
  }
}

Widget buildFloatingPillAppBar({
  required BuildContext context,
  required String title,
  required ScrollController controller,
  Widget? titleWidget,
  bool showCollapsedTitlePill = true,
  Widget? leading,
  Widget? trailing,
  Widget? underTitle,
  PreferredSizeWidget? bottom,
  List<Widget>? actions,
}) {
  final theme = Theme.of(context);
  final filtersOnly = bottom != null;
  final bottomHeight = bottom?.preferredSize.height ?? 0.0;
  final expandedTitleHeight = filtersOnly ? 96.0 : 88.0;
  final collapsedTitleHeight = filtersOnly ? 0.0 : 48.0;
  final extra = underTitle != null ? 30.0 : 0.0;
  final wrappedBottom = bottom != null
      ? PreferredSize(
          preferredSize: bottom.preferredSize,
          child: RepaintBoundary(child: bottom),
        )
      : null;
  return SliverAppBar(
    pinned: true,
    leading: leading,
    automaticallyImplyLeading: !filtersOnly,
    toolbarHeight: filtersOnly ? 0 : 48,
    expandedHeight: expandedTitleHeight + bottomHeight + extra,
    collapsedHeight: collapsedTitleHeight + extra,
    backgroundColor: Colors.transparent,
    surfaceTintColor: Colors.transparent,
    elevation: 0,
    actions: filtersOnly ? null : actions,
    bottom: wrappedBottom,
    flexibleSpace: RepaintBoundary(
      child: _HeaderScrollProgressBuilder(
        controller: controller,
        scrollExtent: expandedTitleHeight - collapsedTitleHeight,
        builder: (context, progress) {
          final rawOpacity = filtersOnly
              ? 1 - Curves.easeOut.transform(progress)
              : 1.0;
          final hideCollapsedElements = filtersOnly && rawOpacity < 0.05;
          final opacity = hideCollapsedElements ? 0.0 : rawOpacity;
          return LayoutBuilder(
            builder: (context, constraints) {
              final expandedFont = (constraints.maxWidth / 20).clamp(20.0, 26.0);
              final targetFont = expandedFont + (16 - expandedFont) * progress;
              final titleScale = targetFont / expandedFont;
              return Stack(
                fit: StackFit.expand,
                children: [
                  ProgressiveBlurBackground(
                    progress: progress,
                    surfaceColor: theme.colorScheme.surface,
                  ),
                  if (!hideCollapsedElements)
                    Positioned(
                      left: 16,
                      right: 16,
                      bottom: bottomHeight + 8,
                      child: IgnorePointer(
                        ignoring: hideCollapsedElements,
                        child: ExcludeSemantics(
                          excluding: hideCollapsedElements,
                          child: Opacity(
                            key: const ValueKey('header_title_fade'),
                            opacity: opacity,
                            child: Transform.translate(
                              offset: Offset(0, filtersOnly ? -12 * progress : 0),
                              child: GestureDetector(
                                onTap: () => controller.animateTo(
                                  0,
                                  duration: const Duration(milliseconds: 500),
                                  curve: Curves.easeOut,
                                ),
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Transform.scale(
                                      scale: titleScale,
                                      alignment: Alignment.center,
                                      child: FittedBox(
                                        fit: BoxFit.scaleDown,
                                        child:
                                            titleWidget ??
                                            Row(
                                              mainAxisSize: MainAxisSize.min,
                                              children: [
                                                Text(
                                                  title,
                                                  style: TextStyle(
                                                    color: theme
                                                        .colorScheme
                                                        .onSurface
                                                        .withValues(alpha: 0.8),
                                                    fontWeight: FontWeight.w900,
                                                    fontSize: expandedFont,
                                                  ),
                                                ),
                                                if (trailing != null) ...[
                                                  const SizedBox(width: 8),
                                                  trailing,
                                                ],
                                              ],
                                            ),
                                      ),
                                    ),
                                    if (underTitle != null) ...[
                                      const SizedBox(height: 6),
                                      underTitle,
                                    ],
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  if (filtersOnly && leading != null && !hideCollapsedElements)
                    Positioned(
                      top: MediaQuery.paddingOf(context).top,
                      left: 4,
                      child: IgnorePointer(
                        ignoring: hideCollapsedElements,
                        child: ExcludeSemantics(
                          excluding: hideCollapsedElements,
                          child: Opacity(
                            opacity: opacity,
                            child: Transform.translate(
                              offset: Offset(0, -12 * progress),
                              child: leading,
                            ),
                          ),
                        ),
                      ),
                    ),
                  if (filtersOnly && actions != null && !hideCollapsedElements)
                    Positioned(
                      top: MediaQuery.paddingOf(context).top,
                      right: 0,
                      child: IgnorePointer(
                        ignoring: hideCollapsedElements,
                        child: ExcludeSemantics(
                          excluding: hideCollapsedElements,
                          child: Opacity(
                            opacity: opacity,
                            child: Transform.translate(
                              offset: Offset(0, -12 * progress),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: actions,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                ],
              );
            },
          );
        },
      ),
    ),
  );
}
