/*
 * Copyright (c) 2026.
 * SPDX-License-Identifier: AGPL-3.0-or-later
 */
import 'package:flutter_test/flutter_test.dart';
import 'package:weblibre/features/geckoview/features/browser/domain/entities/home_target.dart';
import 'package:weblibre/features/user/data/models/general_settings.dart';

void main() {
  group('New Tab target', () {
    test('existing profiles default to following Home', () {
      final defaults = GeneralSettings.withDefaults();
      expect(defaults.newTabTarget, NewTabTarget.followHome);
      expect(defaults.newTabTargetUrl, isNull);
    });

    test('Home and New Tab can use different URLs', () {
      final result = resolveNewTabUrl(
        target: NewTabTarget.customUrl,
        homeTarget: HomeTarget.customUrl,
        homeUrl: 'https://home.example/',
        customNewTabUrl: 'https://new-tab.example/',
      );
      expect(result, Uri.parse('https://new-tab.example/'));
    });

    test('follow home uses Home only when it has a custom URL', () {
      expect(
        resolveNewTabUrl(
          target: NewTabTarget.followHome,
          homeTarget: HomeTarget.customUrl,
          homeUrl: 'https://home.example/',
          customNewTabUrl: 'https://other.example/',
        ),
        Uri.parse('https://home.example/'),
      );
      expect(
        resolveNewTabUrl(
          target: NewTabTarget.followHome,
          homeTarget: HomeTarget.home,
          homeUrl: 'https://home.example/',
          customNewTabUrl: null,
        ),
        isNull,
      );
    });

    test('standard WebLibre New Tab ignores both URLs', () {
      expect(
        resolveNewTabUrl(
          target: NewTabTarget.defaultSearch,
          homeTarget: HomeTarget.customUrl,
          homeUrl: 'https://home.example/',
          customNewTabUrl: 'https://new-tab.example/',
        ),
        isNull,
      );
    });

    test('missing or invalid custom URL falls back to SearchRoute', () {
      for (final url in [null, '', '  ', 'not a valid url at all']) {
        expect(
          resolveNewTabUrl(
            target: NewTabTarget.customUrl,
            homeTarget: HomeTarget.home,
            homeUrl: null,
            customNewTabUrl: url,
          ),
          isNull,
        );
      }
    });

    test('settings JSON round-trip keeps new-tab policy', () {
      final original = GeneralSettings.withDefaults(
        homeTarget: HomeTarget.customUrl,
        homeTargetUrl: 'https://home.example',
        newTabTarget: NewTabTarget.customUrl,
        newTabTargetUrl: 'https://new-tab.example',
      );
      final restored = GeneralSettings.fromJson(original.toJson());
      expect(restored.homeTarget, HomeTarget.customUrl);
      expect(restored.homeTargetUrl, 'https://home.example');
      expect(restored.newTabTarget, NewTabTarget.customUrl);
      expect(restored.newTabTargetUrl, 'https://new-tab.example');
    });
  });
}
