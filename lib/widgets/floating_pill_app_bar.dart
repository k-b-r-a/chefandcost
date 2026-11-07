import 'dart:ui' as ui;

import 'package:flutter/material.dart';

class ProgressiveBlurBackground extends StatelessWidget {
  const ProgressiveBlurBackground({
    super.key,
    required this.progress,
    required this.surfaceColor,
  });

  final double progress;
  final Color surfaceColor;

  @override
  Widget build(BuildContext context) {
    final amount = progress.clamp(0.0, 1.0).toDouble();
    if (amount == 0) return const SizedBox.expand();

    return ClipRect(
      child: IgnorePointer(
        child: Stack(
          fit: StackFit.expand,
          children: [
            ShaderMask(
              blendMode: BlendMode.dstIn,
              shaderCallback: (bounds) => ui.Gradient.linear(
                Offset(0, bounds.top),
                Offset(0, bounds.bottom),
                const [
                  Colors.black,
                  Colors.black,
                  Color(0xB8000000),
                  Color(0x47000000),
                  Colors.transparent,
                ],
                const [0.0, 0.6, 0.78, 0.91, 1.0],
              ),
              child: BackdropFilter(
                filter: ui.ImageFilter.blur(
                  sigmaX: 16 * amount,
                  sigmaY: 16 * amount,
                ),
                child: const SizedBox.expand(
                  child: ColoredBox(color: Color(0x01000000)),
                ),
              ),
            ),
            DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  stops: const [0.0, 0.6, 0.78, 0.91, 1.0],
                  colors: [
                    surfaceColor.withValues(alpha: 0.76 * amount),
                    surfaceColor.withValues(alpha: 0.74 * amount),
                    surfaceColor.withValues(alpha: 0.48 * amount),
                    surfaceColor.withValues(alpha: 0.16 * amount),
                    Colors.transparent,
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
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
    bottom: bottom,
    flexibleSpace: AnimatedBuilder(
      animation: controller,
      builder: (context, _) {
        final progress =
            ((controller.hasClients ? controller.offset : 0) /
                    (expandedTitleHeight - collapsedTitleHeight))
                .clamp(0.0, 1.0)
                .toDouble();
        final opacity = filtersOnly
            ? 1 - Curves.easeOut.transform(progress)
            : 1.0;
        return LayoutBuilder(
          builder: (context, constraints) {
            final expandedFont = (constraints.maxWidth / 20).clamp(20.0, 26.0);
            final fontSize = expandedFont + (16 - expandedFont) * progress;
            return Stack(
              fit: StackFit.expand,
              children: [
                ProgressiveBlurBackground(
                  progress: progress,
                  surfaceColor: theme.colorScheme.surface,
                ),
                Positioned(
                  left: 16,
                  right: 16,
                  bottom: bottomHeight + 8,
                  child: IgnorePointer(
                    ignoring: opacity < 0.05,
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
                              FittedBox(
                                fit: BoxFit.scaleDown,
                                child:
                                    titleWidget ??
                                    Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Text(
                                          title,
                                          style: TextStyle(
                                            color: theme.colorScheme.onSurface
                                                .withValues(alpha: 0.8),
                                            fontWeight: FontWeight.w900,
                                            fontSize: fontSize,
                                          ),
                                        ),
                                        if (trailing != null) ...[
                                          const SizedBox(width: 8),
                                          trailing,
                                        ],
                                      ],
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
                if (filtersOnly && leading != null)
                  Positioned(
                    top: MediaQuery.paddingOf(context).top,
                    left: 4,
                    child: IgnorePointer(
                      ignoring: opacity < 0.05,
                      child: Opacity(
                        opacity: opacity,
                        child: Transform.translate(
                          offset: Offset(0, -12 * progress),
                          child: leading,
                        ),
                      ),
                    ),
                  ),
                if (filtersOnly && actions != null)
                  Positioned(
                    top: MediaQuery.paddingOf(context).top,
                    right: 0,
                    child: IgnorePointer(
                      ignoring: opacity < 0.05,
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
              ],
            );
          },
        );
      },
    ),
  );
}
