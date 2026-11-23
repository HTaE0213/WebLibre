import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:weblibre/features/geckoview/features/browser/features/contextual_toolbar/presentation/widgets/toolbar_button_gesture_surface.dart';

void main() {
  testWidgets('upward swipe invokes only the up action', (tester) async {
    var upCount = 0;
    var downCount = 0;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Center(
            child: ToolbarButtonGestureSurface(
              onSwipeUp: () async {
                upCount++;
              },
              onSwipeDown: () async {
                downCount++;
              },
              child: const SizedBox(
                key: ValueKey('gesture-target'),
                width: 80,
                height: 80,
              ),
            ),
          ),
        ),
      ),
    );

    final gesture = await tester.startGesture(
      tester.getCenter(find.byKey(const ValueKey('gesture-target'))),
    );
    await gesture.moveBy(const Offset(0, -72));
    await gesture.up();
    await tester.pump();

    expect(upCount, 1);
    expect(downCount, 0);
  });

  testWidgets('downward swipe invokes only the down action', (tester) async {
    var upCount = 0;
    var downCount = 0;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Center(
            child: ToolbarButtonGestureSurface(
              onSwipeUp: () async => upCount++,
              onSwipeDown: () async => downCount++,
              child: const SizedBox(
                key: ValueKey('gesture-target'),
                width: 80,
                height: 80,
              ),
            ),
          ),
        ),
      ),
    );

    final gesture = await tester.startGesture(
      tester.getCenter(find.byKey(const ValueKey('gesture-target'))),
    );
    await gesture.moveBy(const Offset(0, 72));
    await gesture.up();
    await tester.pump();

    expect(upCount, 0);
    expect(downCount, 1);
  });

  testWidgets('a short tap still reaches the child', (tester) async {
    var tapCount = 0;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Center(
            child: ToolbarButtonGestureSurface(
              onSwipeUp: () async {},
              onSwipeDown: () async {},
              child: GestureDetector(
                key: const ValueKey('gesture-target'),
                onTap: () => tapCount++,
                child: const SizedBox(width: 80, height: 80),
              ),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.byKey(const ValueKey('gesture-target')));
    await tester.pump();

    expect(tapCount, 1);
  });
}
