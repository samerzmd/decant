import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:decant/ui/widgets/decant_notice.dart';

void main() {
  Future<BuildContext> pump(WidgetTester tester) async {
    late BuildContext ctx;
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(body: Builder(builder: (c) {
        ctx = c;
        return const SizedBox.expand();
      })),
    ));
    return ctx;
  }

  testWidgets('shows a branded card, not a plain snackbar', (tester) async {
    final ctx = await pump(tester);
    showDecantNotice(ctx, 'No moves left',
        icon: Icons.do_not_disturb_alt_rounded, tone: NoticeTone.blocked);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    expect(find.byType(DecantNotice), findsOneWidget);
    expect(find.text('No moves left'), findsOneWidget);
    expect(find.byIcon(Icons.do_not_disturb_alt_rounded), findsOneWidget);
    final bar = tester.widget<SnackBar>(find.byType(SnackBar));
    expect(bar.behavior, SnackBarBehavior.floating);
    expect(bar.backgroundColor, Colors.transparent);
  });

  testWidgets('a new notice replaces the one showing', (tester) async {
    final ctx = await pump(tester);
    showDecantNotice(ctx, 'First');
    await tester.pump();
    showDecantNotice(ctx, 'Second');
    await tester.pumpAndSettle();

    expect(find.text('First'), findsNothing);
    expect(find.text('Second'), findsOneWidget);
  });
}
