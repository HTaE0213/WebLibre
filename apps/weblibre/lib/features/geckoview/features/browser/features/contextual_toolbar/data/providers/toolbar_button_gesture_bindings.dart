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

import 'dart:convert';

import 'package:flutter_mozilla_components/flutter_mozilla_components.dart';
import 'package:riverpod/experimental/persist.dart';
import 'package:riverpod/riverpod.dart';
import 'package:riverpod_annotation/experimental/persist.dart';
import 'package:weblibre/features/browser_actions/data/models/browser_action.dart';
import 'package:weblibre/features/user/data/providers.dart';

enum ToolbarButtonGestureDirection { swipeUp, swipeDown }

/// A persisted action for a toolbar button gesture.
///
/// Browser actions are stored by enum name. Extension actions are stored by
/// extension ID and action type, so they survive title/icon changes and an
/// extension update without depending on its current presentation.
class ToolbarButtonGestureAction {
  final BrowserAction? browserAction;
  final String? extensionId;
  final WebExtensionActionType? extensionActionType;

  const ToolbarButtonGestureAction.browser(BrowserAction action)
    : browserAction = action,
      extensionId = null,
      extensionActionType = null;

  const ToolbarButtonGestureAction.extension({
    required this.extensionId,
    WebExtensionActionType actionType = WebExtensionActionType.browser,
  }) : browserAction = null,
       extensionActionType = actionType;

  bool get isBrowserAction => browserAction != null;
  bool get isExtensionAction => extensionId != null;

  Map<String, Object?> toJson() {
    final browserAction = this.browserAction;
    if (browserAction != null) {
      return {'type': 'browser', 'action': browserAction.name};
    }

    return {
      'type': 'extension',
      'extensionId': extensionId,
      'actionType':
          extensionActionType?.name ?? WebExtensionActionType.browser.name,
    };
  }

  static ToolbarButtonGestureAction? fromJson(Object? value) {
    if (value is! Map) return null;

    switch (value['type']) {
      case 'browser':
        final name = value['action'];
        if (name is! String) return null;
        for (final action in BrowserAction.values) {
          if (action.name == name) {
            return ToolbarButtonGestureAction.browser(action);
          }
        }
        return null;

      case 'extension':
        final extensionId = value['extensionId'];
        if (extensionId is! String || extensionId.isEmpty) return null;

        final actionTypeName = value['actionType'];
        var actionType = WebExtensionActionType.browser;
        if (actionTypeName is String) {
          var found = false;
          for (final candidate in WebExtensionActionType.values) {
            if (candidate.name == actionTypeName) {
              actionType = candidate;
              found = true;
              break;
            }
          }
          if (!found) return null;
        }

        return ToolbarButtonGestureAction.extension(
          extensionId: extensionId,
          actionType: actionType,
        );

      default:
        return null;
    }
  }

  @override
  bool operator ==(Object other) =>
      other is ToolbarButtonGestureAction &&
      other.browserAction == browserAction &&
      other.extensionId == extensionId &&
      other.extensionActionType == extensionActionType;

  @override
  int get hashCode =>
      Object.hash(browserAction, extensionId, extensionActionType);
}

typedef ToolbarButtonGestureBindingMap =
    Map<String, Map<String, ToolbarButtonGestureAction>>;

/// Gesture bindings are kept in Riverpod's profile-backed storage rather than
/// adding columns to the toolbar layout tables. This keeps existing profiles
/// and toolbar ordering migrations untouched.
final toolbarButtonGestureBindingsProvider =
    NotifierProvider<
      ToolbarButtonGestureBindingsNotifier,
      ToolbarButtonGestureBindingMap
    >(ToolbarButtonGestureBindingsNotifier.new);

class ToolbarButtonGestureBindingsNotifier
    extends Notifier<ToolbarButtonGestureBindingMap> {
  @override
  ToolbarButtonGestureBindingMap build() {
    persist(
      ref.watch(riverpodDatabaseStorageProvider),
      key: 'ToolbarButtonGestureBindings',
      options: const StorageOptions(cacheTime: StorageCacheTime.unsafe_forever),
      encode: (state) => jsonEncode({
        for (final entry in state.entries)
          entry.key: {
            for (final binding in entry.value.entries)
              binding.key: binding.value.toJson(),
          },
      }),
      decode: (encoded) {
        try {
          final decoded = jsonDecode(encoded);
          if (decoded is! Map) {
            return <String, Map<String, ToolbarButtonGestureAction>>{};
          }

          final result = <String, Map<String, ToolbarButtonGestureAction>>{};
          for (final entry in decoded.entries) {
            if (entry.value is! Map) continue;

            final bindings = <String, ToolbarButtonGestureAction>{};
            for (final binding in (entry.value as Map).entries) {
              final action = ToolbarButtonGestureAction.fromJson(binding.value);
              if (action != null) {
                bindings[binding.key.toString()] = action;
              }
            }

            if (bindings.isNotEmpty) {
              result[entry.key.toString()] = bindings;
            }
          }

          return result;
        } catch (_) {
          return <String, Map<String, ToolbarButtonGestureAction>>{};
        }
      },
    );

    return stateOrNull ?? const {};
  }

  void setAction({
    required String targetId,
    required ToolbarButtonGestureDirection direction,
    required ToolbarButtonGestureAction? action,
  }) {
    final next = <String, Map<String, ToolbarButtonGestureAction>>{
      for (final entry in state.entries) entry.key: {...entry.value},
    };
    final bindings = next[targetId] ?? <String, ToolbarButtonGestureAction>{};

    if (action == null) {
      bindings.remove(direction.name);
    } else {
      bindings[direction.name] = action;
    }

    if (bindings.isEmpty) {
      next.remove(targetId);
    } else {
      next[targetId] = bindings;
    }

    state = next;
  }
}

String toolbarButtonGestureTargetId(String buttonId) => 'button:$buttonId';

String addonGestureTargetId(String extensionId) => 'addon:$extensionId';
