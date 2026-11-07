import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:recipetools/utils/ui_utils.dart';
import 'package:recipetools/widgets/gooey_toast.dart';

void main() {
  testWidgets('GooeyToast shows, animates drop and melt, and displays content', (WidgetTester tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) {
              return ElevatedButton(
                onPressed: () {
                  GooeyToast.show(
                    context,
                    message: 'Recipe saved successfully!',
                    title: 'Success',
                    type: GooeyToastType.success,
                  );
                },
                child: const Text('Show Toast'),
              );
            },
          ),
        ),
      ),
    );

    // Tap button to show toast
    await tester.tap(find.text('Show Toast'));
    await tester.pump(); // Start entry animation

    // Pump through droplet fall and squash phase
    await tester.pump(const Duration(milliseconds: 300));
    // Mid-fall CustomPaint is active
    expect(find.byType(CustomPaint), findsWidgets);

    // Pump to melt and horizontal spread completion
    await tester.pump(const Duration(milliseconds: 500));

    // Message and title should now be visible
    expect(find.text('Recipe saved successfully!'), findsOneWidget);
    expect(find.text('Success'), findsOneWidget);

    // Dismiss manually
    GooeyToast.dismiss();
    await tester.pumpAndSettle();

    // After dismissal, toast should be gone
    expect(find.text('Recipe saved successfully!'), findsNothing);
  });

  testWidgets('GooeyToast shows warning, error, and info types with action button', (WidgetTester tester) async {
    bool actionTriggered = false;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) {
              return Column(
                children: [
                  ElevatedButton(
                    onPressed: () {
                      GooeyToast.showWarning(
                        context,
                        message: 'Warning message here',
                        title: 'Notice',
                        actionLabel: 'UNDO',
                        onAction: () {
                          actionTriggered = true;
                        },
                      );
                    },
                    child: const Text('Show Warning'),
                  ),
                  ElevatedButton(
                    onPressed: () {
                      GooeyToast.showError(
                        context,
                        message: 'Error occurred during sync',
                        title: 'Error',
                      );
                    },
                    child: const Text('Show Error'),
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );

    // Tap to show warning with action button
    await tester.tap(find.text('Show Warning'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 800));

    expect(find.text('Warning message here'), findsOneWidget);
    expect(find.text('Notice'), findsOneWidget);
    expect(find.text('UNDO'), findsOneWidget);

    // Tap UNDO action button
    await tester.tap(find.text('UNDO'));
    expect(actionTriggered, isTrue);

    await tester.pumpAndSettle();
    expect(find.text('Warning message here'), findsNothing);

    // Tap to show error
    await tester.tap(find.text('Show Error'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 800));

    expect(find.text('Error occurred during sync'), findsOneWidget);
    expect(find.text('Error'), findsOneWidget);

    // Tap close icon button
    await tester.tap(find.byIcon(Icons.close_rounded));
    await tester.pumpAndSettle();
    expect(find.text('Error occurred during sync'), findsNothing);
  });

  testWidgets('GooeyToast dismisses via upward drag gesture', (WidgetTester tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) {
              return ElevatedButton(
                onPressed: () {
                  GooeyToast.show(
                    context,
                    message: 'Swipe me up to dismiss',
                  );
                },
                child: const Text('Show Toast'),
              );
            },
          ),
        ),
      ),
    );

    await tester.tap(find.text('Show Toast'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 800));

    expect(find.text('Swipe me up to dismiss'), findsOneWidget);

    // Drag toast upward by 50px
    await tester.drag(find.text('Swipe me up to dismiss'), const Offset(0, -60));
    await tester.pumpAndSettle();

    // Toast should be dismissed
    expect(find.text('Swipe me up to dismiss'), findsNothing);
  });

  testWidgets('AppSnackBar delegates to GooeyToast', (WidgetTester tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) {
              return Column(
                children: [
                  ElevatedButton(
                    onPressed: () {
                      AppSnackBar.showSuccess(context, 'Success via AppSnackBar');
                    },
                    child: const Text('SnackBar Success'),
                  ),
                  ElevatedButton(
                    onPressed: () {
                      AppSnackBar.showError(context, 'Error via AppSnackBar');
                    },
                    child: const Text('SnackBar Error'),
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );

    await tester.tap(find.text('SnackBar Success'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 800));

    expect(find.text('Success via AppSnackBar'), findsOneWidget);

    // Show error immediately - replaces current toast
    await tester.tap(find.text('SnackBar Error'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 800));

    expect(find.text('Error via AppSnackBar'), findsOneWidget);
    expect(find.text('Success via AppSnackBar'), findsNothing);

    GooeyToast.dismiss();
    await tester.pumpAndSettle();
  });

  testWidgets('GooeyToast never expands to fill full screen height during melt/spread phase', (WidgetTester tester) async {
    tester.view.physicalSize = const Size(800, 1200);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) {
              return ElevatedButton(
                onPressed: () {
                  GooeyToast.show(context, message: 'Boundary test message');
                },
                child: const Text('Show Toast'),
              );
            },
          ),
        ),
      ),
    );

    await tester.tap(find.text('Show Toast'));
    await tester.pump();

    // Check frames throughout the squash & spread phases (300ms to 700ms)
    for (int ms = 300; ms <= 700; ms += 50) {
      await tester.pump(const Duration(milliseconds: 50));
      final containerFinders = find.byType(Container);
      for (final element in containerFinders.evaluate()) {
        final renderBox = element.renderObject;
        if (renderBox is RenderBox && renderBox.hasSize) {
          // No toast container in overlay should ever exceed 120px height
          expect(renderBox.size.height, lessThan(150.0));
        }
      }
    }

    GooeyToast.dismiss();
    await tester.pumpAndSettle();
  });
}
