/*
 * Copyright (c) 2024-2026 Fabian Freund.
 *
 * This file is part of WebLibre
 * (see https://weblibre.eu).
 *
 * This program is free software: you can redistribute it and/or modify
 * it under the terms of the GNU Affero General Public License as
 * published by the Free Software Foundation, either version 3 of the
 * License, or (at your option) any later version.
 *
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU Affero General Public License for more details.
 *
 * You should have received a copy of the GNU Affero General Public License
 * along with this program. If not, see <http://www.gnu.org/licenses/>.
 */

import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:flutter_mozilla_components/flutter_mozilla_components.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:weblibre/core/design/display_features.dart';
import 'package:weblibre/features/browser_actions/data/models/browser_action.dart';
import 'package:weblibre/features/browser_actions/domain/entities/browser_action_policy.dart';
import 'package:weblibre/features/browser_actions/presentation/utils/browser_action_l10n.dart';
import 'package:weblibre/features/geckoview/domain/providers/web_extensions_state.dart';
import 'package:weblibre/features/geckoview/features/browser/features/contextual_toolbar/data/providers/toolbar_button_gesture_bindings.dart';
import 'package:weblibre/features/geckoview/features/browser/presentation/widgets/extension_badge_icon.dart';
import 'package:weblibre/features/settings/presentation/widgets/settings_detail.dart';
import 'package:weblibre/features/user/domain/repositories/general_settings.dart';
import 'package:weblibre/l10n/generated/app_localizations.dart';
import 'package:weblibre/presentation/widgets/pointer_scrollable_sheet.dart';
import 'package:weblibre/presentation/widgets/sheet_drag_handle.dart';

const _maxChildSize = 0.95;

/// Edits the two directional swipe actions for one toolbar button or pinned
/// extension shortcut.
class ToolbarButtonGestureSettingsEditor extends ConsumerWidget {
  const ToolbarButtonGestureSettingsEditor({
    super.key,
    required this.targetId,
    this.showHeading = false,
    this.dense = false,
  });

  final String targetId;
  final bool showHeading;
  final bool dense;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final bindings = ref.watch(toolbarButtonGestureBindingsProvider);
    final targetBindings = bindings[targetId] ?? const {};
    final swipeUp = targetBindings[ToolbarButtonGestureDirection.swipeUp.name];
    final swipeDown =
        targetBindings[ToolbarButtonGestureDirection.swipeDown.name];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (showHeading)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
            child: Text(
              'Swipe actions',
              style: Theme.of(context).textTheme.titleSmall,
            ),
          ),
        _SwipeActionTile(
          targetId: targetId,
          direction: ToolbarButtonGestureDirection.swipeUp,
          action: swipeUp,
          dense: dense,
        ),
        _SwipeActionTile(
          targetId: targetId,
          direction: ToolbarButtonGestureDirection.swipeDown,
          action: swipeDown,
          dense: dense,
        ),
      ],
    );
  }
}

class _SwipeActionTile extends ConsumerWidget {
  const _SwipeActionTile({
    required this.targetId,
    required this.direction,
    required this.action,
    required this.dense,
  });

  final String targetId;
  final ToolbarButtonGestureDirection direction;
  final ToolbarButtonGestureAction? action;
  final bool dense;

  String _actionLabel(BuildContext context, WidgetRef ref) {
    final browserAction = action?.browserAction;
    if (browserAction != null) return browserAction.label(context);

    final extensionId = action?.extensionId;
    if (extensionId != null) {
      final actionType =
          action?.extensionActionType ?? WebExtensionActionType.browser;
      final extension = ref.watch(webExtensionsStateProvider(actionType))[
        extensionId
      ];
      return extension?.title ?? extensionId;
    }

    return AppLocalizations.of(context).settings_longPressNoneTitle;
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isUp = direction == ToolbarButtonGestureDirection.swipeUp;
    final l10n = AppLocalizations.of(context);

    return ListTile(
      dense: dense,
      contentPadding: EdgeInsets.zero,
      leading: Icon(isUp ? Icons.arrow_upward : Icons.arrow_downward),
      title: Text(isUp ? 'Swipe up' : 'Swipe down'),
      subtitle: Text(_actionLabel(context, ref)),
      trailing: const Icon(Icons.chevron_right),
      onTap: () async {
        final picked = await showToolbarButtonGestureActionPicker(
          context,
          ref,
          selected: action,
          title: isUp ? 'Swipe up action' : 'Swipe down action',
        );
        if (picked == null) return;

        ref
            .read(toolbarButtonGestureBindingsProvider.notifier)
            .setAction(
              targetId: targetId,
              direction: direction,
              action: picked.action,
            );
      },
    );
  }
}

/// Returns null when dismissed. A non-null result with a null action means
/// that the user deliberately cleared the binding.
Future<({ToolbarButtonGestureAction? action})?>
showToolbarButtonGestureActionPicker(
  BuildContext context,
  WidgetRef ref, {
  required ToolbarButtonGestureAction? selected,
  required String title,
}) {
  return showModalBottomSheet<({ToolbarButtonGestureAction? action})>(
    context: context,
    anchorPoint: preferredAnchorPoint(MediaQuery.of(context)),
    isScrollControlled: true,
    useSafeArea: true,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
    ),
    builder: (context) => _ToolbarButtonGestureActionPicker(
      selected: selected,
      title: title,
    ),
  );
}

class _ToolbarButtonGestureActionPicker extends HookConsumerWidget {
  const _ToolbarButtonGestureActionPicker({
    required this.selected,
    required this.title,
  });

  final ToolbarButtonGestureAction? selected;
  final String title;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final search = useSettingsSearch();
    final query = search.normalizedQuery;
    final sheetController = useDraggableScrollableController();
    final searchFocus = useFocusNode();

    useEffect(() {
      void expandForKeyboard() {
        if (searchFocus.hasFocus && sheetController.isAttached) {
          sheetController.animateTo(
            _maxChildSize,
            duration: const Duration(milliseconds: 200),
            curve: Curves.easeOutCubic,
          );
        }
      }

      searchFocus.addListener(expandForKeyboard);
      return () => searchFocus.removeListener(expandForKeyboard);
    }, [searchFocus, sheetController]);

    bool matches(List<String> values) =>
        query.isEmpty || matchesSettingsSearch(query, values);

    final browserActions = shownBrowserActions(
      BrowserAction.values,
      ref.watch(displayedGeneralSettingsProvider),
      selected: selected?.browserAction,
    );
    final byCategory = <BrowserActionCategory, List<BrowserAction>>{};
    for (final action in browserActions) {
      if (matches([
        action.label(context),
        action.description(context),
        action.category.label(context),
        ...action.keywords(context),
      ])) {
        byCategory.putIfAbsent(action.category, () => []).add(action);
      }
    }

    final extensionStates = ref.watch(
      webExtensionsStateProvider(WebExtensionActionType.browser),
    );
    final selectedExtensionId = selected?.extensionId;
    final extensions = extensionStates.values
        .where(
          (extension) =>
              extension.enabled || extension.extensionId == selectedExtensionId,
        )
        .where(
          (extension) => matches([
            extension.title ?? extension.extensionId,
            extension.extensionId,
          ]),
        )
        .toList()
      ..sort(
        (a, b) => (a.title ?? a.extensionId).toLowerCase().compareTo(
          (b.title ?? b.extensionId).toLowerCase(),
        ),
      );

    final showStaleExtension =
        selectedExtensionId != null &&
        !extensionStates.containsKey(selectedExtensionId) &&
        matches([selectedExtensionId]);
    final showUnset = matches(['None', 'No action', 'Do nothing']);
    final hasMatches =
        showUnset ||
        byCategory.values.any((actions) => actions.isNotEmpty) ||
        extensions.isNotEmpty ||
        showStaleExtension;

    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: PointerScrollableSheet(
        controller: sheetController,
        initialChildSize: 0.7,
        minChildSize: 0.4,
        maxChildSize: _maxChildSize,
        expand: false,
        builder: (context, scrollController) {
          return Column(
            children: [
              const SheetDragHandle(),
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 0, 24, 8),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Text(title, style: theme.textTheme.titleLarge),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                child: SettingsSearchField(
                  controller: search.controller,
                  focusNode: searchFocus,
                  hintText: l10n.gestures_actionSearchHint,
                ),
              ),
              Expanded(
                child: ListView(
                  controller: scrollController,
                  padding: const EdgeInsets.only(bottom: 8),
                  children: [
                    if (showUnset)
                      ListTile(
                        leading: const Icon(Icons.block),
                        title: const Text('None'),
                        subtitle: const Text(
                          'Do nothing when this button is swiped',
                        ),
                        selected: selected == null,
                        trailing: selected == null
                            ? Icon(Icons.check, color: colorScheme.primary)
                            : null,
                        onTap: () =>
                            Navigator.of(context).pop((action: null)),
                      ),
                    for (final category in BrowserActionCategory.values)
                      if (byCategory[category] case final actions?
                          when actions.isNotEmpty) ...[
                        Padding(
                          padding: const EdgeInsets.fromLTRB(24, 12, 24, 4),
                          child: Text(
                            category.label(context),
                            style: theme.textTheme.titleSmall?.copyWith(
                              color: colorScheme.primary,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                        for (final action in actions)
                          ListTile(
                            leading: Icon(action.icon),
                            title: Text(action.label(context)),
                            subtitle: Text(action.description(context)),
                            selected: selected?.browserAction == action,
                            trailing: selected?.browserAction == action
                                ? Icon(Icons.check, color: colorScheme.primary)
                                : null,
                            onTap: () => Navigator.of(context).pop((
                              action: ToolbarButtonGestureAction.browser(
                                action,
                              ),
                            )),
                          ),
                      ],
                    if (extensions.isNotEmpty || showStaleExtension) ...[
                      Padding(
                        padding: const EdgeInsets.fromLTRB(24, 12, 24, 4),
                        child: Text(
                          l10n.addons_genericTitle,
                          style: theme.textTheme.titleSmall?.copyWith(
                            color: colorScheme.primary,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                      if (showStaleExtension)
                        ListTile(
                          leading: const Icon(Icons.extension_outlined),
                          title: Text(selectedExtensionId),
                          subtitle: const Text('Extension is not installed'),
                          selected: true,
                          enabled: false,
                        ),
                      for (final extension in extensions)
                        ListTile(
                          leading: ExtensionBadgeIcon(extension),
                          title: Text(extension.title ?? extension.extensionId),
                          subtitle: Text(extension.extensionId),
                          selected:
                              selected?.extensionId == extension.extensionId,
                          trailing:
                              selected?.extensionId == extension.extensionId
                              ? Icon(Icons.check, color: colorScheme.primary)
                              : null,
                          enabled: extension.enabled,
                          onTap: extension.enabled
                              ? () => Navigator.of(context).pop((
                                  action: ToolbarButtonGestureAction.extension(
                                    extensionId: extension.extensionId,
                                  ),
                                ))
                              : null,
                        ),
                    ],
                    if (!hasMatches)
                      Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 24,
                          vertical: 32,
                        ),
                        child: Text(
                          l10n.gestures_noMatchingActions,
                          textAlign: TextAlign.center,
                          style: theme.textTheme.bodyLarge?.copyWith(
                            color: colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}
