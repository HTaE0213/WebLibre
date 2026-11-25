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

import 'package:weblibre/utils/uri_parser.dart' as uri_parser;

/// What the browser lands on when there is no tab to show.
enum HomeTarget {
  /// Show the home surface. The default, and what the browser has always done.
  home,

  /// Reopen the most recently used tab, scoped to the selected container.
  resumeLastTab,

  /// Open a configured address.
  customUrl,
}

/// How the New Tab action chooses its destination, independently of startup.
///
/// [followHome] preserves the fork's original behavior on upgrade.
enum NewTabTarget {
  followHome,
  defaultSearch,
  customUrl,
}

/// Returns the New Tab destination; null means WebLibre's search/new-tab UI.
/// Kept pure to cover upgrades, independent URLs and invalid addresses in tests.
Uri? resolveNewTabUrl({
  required NewTabTarget target,
  required HomeTarget homeTarget,
  required String? homeUrl,
  required String? customNewTabUrl,
}) {
  final url = switch (target) {
    NewTabTarget.followHome when homeTarget == HomeTarget.customUrl => homeUrl,
    NewTabTarget.customUrl => customNewTabUrl,
    _ => null,
  };
  if (url == null || url.trim().isEmpty) return null;
  return uri_parser.tryParseUrl(url);
}
