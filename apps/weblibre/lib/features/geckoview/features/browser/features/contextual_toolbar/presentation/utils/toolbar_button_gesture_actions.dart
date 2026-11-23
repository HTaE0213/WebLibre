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

import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:weblibre/features/browser_actions/domain/services/browser_action_dispatcher.dart';
import 'package:weblibre/features/geckoview/domain/providers.dart';
import 'package:weblibre/features/geckoview/domain/providers/web_extensions_state.dart';
import 'package:weblibre/features/geckoview/features/browser/features/contextual_toolbar/data/providers/toolbar_button_gesture_bindings.dart';

/// Runs either a normal browser action or a specific installed extension's
/// browser action. Missing/disabled extensions are deliberately a no-op: a
/// stale binding must never open a different extension by position.
Future<void> runToolbarButtonGestureAction(
  WidgetRef ref,
  ToolbarButtonGestureAction action,
) async {
  final browserAction = action.browserAction;
  if (browserAction != null) {
    await ref
        .read(browserActionDispatcherProvider.notifier)
        .run(browserAction);
    return;
  }

  final extensionId = action.extensionId;
  if (extensionId == null) return;

  final actionType =
      action.extensionActionType ?? WebExtensionActionType.browser;
  final extension = ref.read(webExtensionsStateProvider(actionType))[extensionId];
  if (extension?.enabled != true) return;

  await ref
      .read(addonServiceProvider)
      .invokeAddonAction(extensionId, actionType);
}
