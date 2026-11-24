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

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter/services.dart';

/// Adds up/down swipe triggers without replacing the child's tap or long press.
///
/// The vertical drag recognizer only wins after the pointer has moved far
/// enough to be a swipe. A short tap and the child's own long press therefore
/// keep their existing gesture-arena behaviour.
class ToolbarButtonGestureSurface extends StatefulWidget {
  const ToolbarButtonGestureSurface({
    super.key,
    required this.child,
    this.onSwipeUp,
    this.onSwipeDown,
    this.enabled = true,
  });

  final Widget child;
  final Future<void> Function()? onSwipeUp;
  final Future<void> Function()? onSwipeDown;

  /// The pinned add-on strip is vertically scrollable on a side rail. Its
  /// vertical gestures stand down there so scrolling remains possible.
  final bool enabled;

  @override
  State<ToolbarButtonGestureSurface> createState() =>
      _ToolbarButtonGestureSurfaceState();
}

class _ToolbarButtonGestureSurfaceState
    extends State<ToolbarButtonGestureSurface> {
  static const _minimumDistance = 28.0;
  static const _minimumVelocity = 420.0;
  static const _swipeUpSemantics = CustomSemanticsAction(label: 'Swipe up');
  static const _swipeDownSemantics = CustomSemanticsAction(label: 'Swipe down');

  double _dragDistance = 0;

  void _invoke(Future<void> Function()? action) {
    if (action == null) return;
    unawaited(HapticFeedback.selectionClick());
    unawaited(action());
  }

  @override
  Widget build(BuildContext context) {
    final onSwipeUp = widget.enabled ? widget.onSwipeUp : null;
    final onSwipeDown = widget.enabled ? widget.onSwipeDown : null;

    if (onSwipeUp == null && onSwipeDown == null) return widget.child;

    final customActions = <CustomSemanticsAction, VoidCallback>{
      if (onSwipeUp != null)
        _swipeUpSemantics: () => _invoke(onSwipeUp),
      if (onSwipeDown != null)
        _swipeDownSemantics: () => _invoke(onSwipeDown),
    };

    return Semantics(
      customSemanticsActions: customActions,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onVerticalDragStart: (_) => _dragDistance = 0,
        onVerticalDragUpdate: (details) {
          _dragDistance += details.delta.dy;
        },
        onVerticalDragEnd: (details) {
          final distance = _dragDistance;
          final velocity = details.primaryVelocity ?? 0;
          _dragDistance = 0;

          if (distance <= -_minimumDistance || velocity <= -_minimumVelocity) {
            _invoke(onSwipeUp);
          } else if (distance >= _minimumDistance ||
              velocity >= _minimumVelocity) {
            _invoke(onSwipeDown);
          }
        },
        onVerticalDragCancel: () => _dragDistance = 0,
        child: widget.child,
      ),
    );
  }
}
