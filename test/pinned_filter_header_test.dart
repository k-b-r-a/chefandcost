import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:recipetools/widgets/floating_pill_app_bar.dart';

void main() {
  for (final width in [360.0, 1000.0]) {
    testWidgets(
      'title stays above filters and shrinks on scroll at width $width',
      (tester) async {
        tester.view.physicalSize = Size(width, 800);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        final controller = ScrollController();
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: Builder(
                builder: (context) => CustomScrollView(
                  controller: controller,
                  slivers: [
                    buildFloatingPillAppBar(
                      context: context,
                      title: 'RECETAS',
                      actions: [
                        IconButton(
                          key: const ValueKey('import_action'),
                          onPressed: () {},
                          icon: const Icon(Icons.file_download_outlined),
                        ),
                      ],
                      controller: controller,
                      bottom: const PreferredSize(
                        preferredSize: Size.fromHeight(52),
                        child: SizedBox(
                          key: ValueKey('filters'),
                          height: 52,
                          width: double.infinity,
                          child: SingleChildScrollView(
                            scrollDirection: Axis.horizontal,
                            child: Row(
                              children: [
                                Text(
                                  'Todos   Cocina   Pastelería   Coctelería',
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                    SliverList.builder(
                      itemCount: 60,
                      itemBuilder: (_, i) =>
                          SizedBox(height: 60, child: Text('Recipe $i')),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        final title = find.text('RECETAS');
        final filters = find.byKey(const ValueKey('filters'));
        final expandedTitleHeight = tester.widget<Text>(title).style!.fontSize!;
        expect(
          tester.getRect(title).bottom,
          lessThanOrEqualTo(tester.getRect(filters).top),
        );
        controller.jumpTo(350);
        await tester.pumpAndSettle();
        expect(
          tester.getRect(title).bottom,
          lessThanOrEqualTo(tester.getRect(filters).top),
        );
        expect(
          tester.widget<Text>(title).style!.fontSize!,
          lessThan(expandedTitleHeight),
        );
        expect(tester.takeException(), isNull);
        expect(
          tester
              .widget<Opacity>(find.byKey(const ValueKey('header_title_fade')))
              .opacity,
          0,
        );
        expect(tester.getRect(filters).top, closeTo(0, 0.01));
        final actionOpacity = tester.widget<Opacity>(
          find
              .ancestor(
                of: find.byKey(const ValueKey('import_action')),
                matching: find.byType(Opacity),
              )
              .first,
        );
        expect(actionOpacity.opacity, 0);
        await tester.pumpWidget(const SizedBox());
        controller.dispose();
      },
    );
  }
}
