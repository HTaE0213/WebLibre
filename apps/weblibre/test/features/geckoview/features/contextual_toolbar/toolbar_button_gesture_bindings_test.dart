import 'package:flutter_test/flutter_test.dart';
import 'package:weblibre/features/browser_actions/data/models/browser_action.dart';
import 'package:weblibre/features/geckoview/features/browser/features/contextual_toolbar/data/providers/toolbar_button_gesture_bindings.dart';

void main() {
  group('ToolbarButtonGestureAction', () {
    test('round-trips a browser action by its stable enum name', () {
      const action = ToolbarButtonGestureAction.browser(BrowserAction.back);

      expect(ToolbarButtonGestureAction.fromJson(action.toJson()), action);
    });

    test('round-trips an extension shortcut by extension ID', () {
      const action = ToolbarButtonGestureAction.extension(
        extensionId: 'test-extension@example.com',
      );

      expect(ToolbarButtonGestureAction.fromJson(action.toJson()), action);
    });

    test(
      'drops unknown browser actions instead of binding the wrong action',
      () {
        expect(
          ToolbarButtonGestureAction.fromJson({
            'type': 'browser',
            'action': 'removedAction',
          }),
          isNull,
        );
      },
    );

    test('drops malformed extension bindings', () {
      expect(
        ToolbarButtonGestureAction.fromJson({
          'type': 'extension',
          'extensionId': '',
          'actionType': 'browser',
        }),
        isNull,
      );
    });

    test('drops unknown extension action types', () {
      expect(
        ToolbarButtonGestureAction.fromJson({
          'type': 'extension',
          'extensionId': 'test-extension@example.com',
          'actionType': 'futureAction',
        }),
        isNull,
      );
    });
  });
}
