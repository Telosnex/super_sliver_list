import "package:flutter/material.dart";
import "package:flutter_test/flutter_test.dart";
import "package:super_sliver_list/super_sliver_list.dart";

void main() {
  for (final batch in [true, false]) {
    testWidgets("zero-extent leading items are built (batch shift: $batch)",
        (tester) async {
      final previous = SuperSliverListPerfFlags.batchLeadingChildShift;
      SuperSliverListPerfFlags.batchLeadingChildShift = batch;
      addTearDown(
        () => SuperSliverListPerfFlags.batchLeadingChildShift = previous,
      );
      final scroll = ScrollController();
      addTearDown(scroll.dispose);
      final extents = ValueNotifier<List<double>>([0, 0, 100, 0, 100]);
      addTearDown(extents.dispose);
      await tester.pumpWidget(Directionality(
        textDirection: TextDirection.ltr,
        child: ValueListenableBuilder(
          valueListenable: extents,
          builder: (context, value, _) => SuperListView.builder(
            controller: scroll,
            itemCount: value.length,
            extentEstimation: (index, _) => index == null ? 0 : value[index],
            itemBuilder: (_, index) => SizedBox(
              key: ValueKey(index),
              height: value[index],
            ),
          ),
        ),
      ));
      await tester.pumpAndSettle();
      // Every item, including the zero-extent ones at the leading edge, is in
      // the tree. Otherwise a later change to their content is never laid out.
      // A zero-extent item is never "onstage".
      for (var i = 0; i < 5; i++) {
        expect(
          find.byKey(ValueKey(i), skipOffstage: false),
          findsOneWidget,
          reason: "item $i",
        );
      }

      extents.value = [60, 0, 100, 40, 100];
      await tester.pumpAndSettle();
      expect(tester.getTopLeft(find.byKey(const ValueKey(0))).dy, 0);
      expect(tester.getSize(find.byKey(const ValueKey(0))).height, 60);
      expect(tester.getTopLeft(find.byKey(const ValueKey(2))).dy, 60);
      expect(tester.getTopLeft(find.byKey(const ValueKey(3))).dy, 160);
      expect(tester.getTopLeft(find.byKey(const ValueKey(4))).dy, 200);
      expect(scroll.offset, 0);
    });
  }

  testWidgets("zero-extent leading item is rebuilt after it was collected",
      (tester) async {
    final scroll = ScrollController();
    addTearDown(scroll.dispose);
    final first = ValueNotifier<double>(0);
    addTearDown(first.dispose);
    await tester.pumpWidget(Directionality(
      textDirection: TextDirection.ltr,
      child: ValueListenableBuilder(
        valueListenable: first,
        builder: (context, value, _) => SuperListView.builder(
          controller: scroll,
          itemCount: 100,
          extentEstimation: (index, _) =>
              index == null ? 0 : (index == 0 ? value : 100),
          itemBuilder: (_, index) => SizedBox(
            key: ValueKey(index),
            height: index == 0 ? value : 100,
          ),
        ),
      ),
    ));
    await tester.pumpAndSettle();
    // Far enough that item 0 leaves the cache area and is collected.
    scroll.jumpTo(3000);
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey(0), skipOffstage: false), findsNothing);
    scroll.jumpTo(0);
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey(0), skipOffstage: false), findsOneWidget);

    first.value = 60;
    await tester.pumpAndSettle();
    expect(tester.getSize(find.byKey(const ValueKey(0))).height, 60);
    expect(tester.getTopLeft(find.byKey(const ValueKey(1))).dy, 60);
  });
}
