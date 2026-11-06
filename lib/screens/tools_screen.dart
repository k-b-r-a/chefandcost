import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../l10n/app_localizations.dart';
import '../widgets/floating_pill_app_bar.dart';
import '../widgets/tool_card.dart';
import 'rule_of_three_screen.dart';
import 'unit_converter_screen.dart';
import 'kitchen_timers_screen.dart';
import '../provider/web_layout_provider.dart';

class ToolsScreen extends ConsumerStatefulWidget {
  const ToolsScreen({super.key});

  @override
  ConsumerState<ToolsScreen> createState() => _ToolsScreenState();
}

class _ToolsScreenState extends ConsumerState<ToolsScreen> {
  final ScrollController _scrollController = ScrollController();

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    return Scaffold(
      body: CustomScrollView(
        controller: _scrollController,
        slivers: [
          buildFloatingPillAppBar(
            context: context,
            title: l10n.tools_title,
            controller: _scrollController,
          ),
          SliverPadding(
            padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 16.0),
            sliver: SliverList.separated(
              itemCount: 3,
              separatorBuilder: (context, index) => const SizedBox(height: 12),
              itemBuilder: (context, index) {
                switch (index) {
                  case 0:
                    return Center(
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 820),
                        child: ToolCard(
                          title: l10n.timers_title,
                          subtitle: l10n.timers_desc,
                          icon: Icons.timer_outlined,
                          onTap: () async {
                            final guard = ref.read(recipeCanLeaveGuardProvider);
                            if (guard != null && !await guard()) return;
                            if (!context.mounted) return;
                            if (MediaQuery.sizeOf(context).width >= 800) {
                              ref.read(webLayoutProvider.notifier).openTool(0);
                            } else {
                              Navigator.of(context).push(
                                MaterialPageRoute(
                                  builder: (context) => const KitchenTimersScreen(),
                                ),
                              );
                            }
                          },
                        ),
                      ),
                    );
                  case 1:
                    return Center(
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 820),
                        child: ToolCard(
                          title: l10n.rule_of_three_title,
                          subtitle: l10n.rule_of_three_desc,
                          icon: Icons.calculate_outlined,
                          onTap: () async {
                            final guard = ref.read(recipeCanLeaveGuardProvider);
                            if (guard != null && !await guard()) return;
                            if (!context.mounted) return;
                            if (MediaQuery.sizeOf(context).width >= 800) {
                              ref.read(webLayoutProvider.notifier).openTool(1);
                            } else {
                              Navigator.of(context).push(
                                MaterialPageRoute(
                                  builder: (context) => const RuleOfThreeScreen(),
                                ),
                              );
                            }
                          },
                        ),
                      ),
                    );
                  case 2:
                    return Center(
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 820),
                        child: ToolCard(
                          title: l10n.unit_converter_title,
                          subtitle: l10n.unit_converter_desc,
                          icon: Icons.swap_horiz_rounded,
                          onTap: () async {
                            final guard = ref.read(recipeCanLeaveGuardProvider);
                            if (guard != null && !await guard()) return;
                            if (!context.mounted) return;
                            if (MediaQuery.sizeOf(context).width >= 800) {
                              ref.read(webLayoutProvider.notifier).openTool(2);
                            } else {
                              Navigator.of(context).push(
                                MaterialPageRoute(
                                  builder: (context) => const UnitConverterScreen(),
                                ),
                              );
                            }
                          },
                        ),
                      ),
                    );
                  default:
                    return const SizedBox.shrink();
                }
              },
            ),
          ),
        ],
      ),
    );
  }
}
