import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../l10n/app_localizations.dart';
import '../provider/database_provider.dart';
import 'group_management_sheet.dart';

/// Interactive chip widget displaying the currently active workspace / group.
/// Tapping opens the [GroupManagementSheet] switcher.
class ActiveGroupChip extends ConsumerWidget {
  final bool isCompact;

  const ActiveGroupChip({super.key, this.isCompact = false});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final activeGroup = ref.watch(activeGroupProvider);
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context)!;

    final allSpaces = ref.watch(activeGroupIdProvider) == kAllGroupsId;
    final groupName = (activeGroup?.id == 'group_default_principal' &&
            (activeGroup?.name == 'Principal' || activeGroup?.name == 'Main'))
        ? l10n.group_default_name
        : (activeGroup?.name ??
            (allSpaces ? l10n.group_all_workspaces : l10n.group_default_name));
    final groupColor = parseGroupColor(activeGroup?.colorHex);
    final groupIcon = allSpaces
        ? Icons.all_inclusive_rounded
        : getGroupIconData(activeGroup?.iconName);

    return Material(
      color: Colors.transparent,
      child: Tooltip(
        message: l10n.group_switcher_tooltip,
        child: InkWell(
          borderRadius: BorderRadius.circular(20),
          onTap: () => GroupManagementSheet.show(context),
          child: Container(
            padding: EdgeInsets.symmetric(
              horizontal: isCompact ? 10 : 12,
              vertical: isCompact ? 4 : 6,
            ),
            decoration: BoxDecoration(
              color: theme.colorScheme.surfaceContainerHighest.withValues(
                alpha: 0.6,
              ),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: theme.colorScheme.outlineVariant.withValues(alpha: 0.35),
                width: 1,
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: isCompact ? 18 : 20,
                  height: isCompact ? 18 : 20,
                  decoration: BoxDecoration(
                    color: groupColor.withValues(alpha: 0.2),
                    shape: BoxShape.circle,
                  ),
                  child: Center(
                    child: Icon(
                      groupIcon,
                      size: isCompact ? 12 : 13,
                      color: groupColor,
                    ),
                  ),
                ),
                const SizedBox(width: 6),
                ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 120),
                  child: Text(
                    groupName,
                    style: TextStyle(
                      fontSize: isCompact ? 12 : 13,
                      fontWeight: FontWeight.w600,
                      color: theme.colorScheme.onSurface,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(width: 2),
                Icon(
                  Icons.arrow_drop_down_rounded,
                  size: isCompact ? 18 : 20,
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
