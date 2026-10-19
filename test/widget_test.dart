import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:swordnote/app.dart';

void main() {
  testWidgets('App loads HomeScreen', (WidgetTester tester) async {
    await tester.pumpWidget(
      const ProviderScope(child: SwordNoteApp()),
    );
    expect(find.text('SwordNote'), findsOneWidget);
  });

  testWidgets('HomeScreen shows quick actions', (WidgetTester tester) async {
    await tester.pumpWidget(
      const ProviderScope(child: SwordNoteApp()),
    );
    expect(find.text('New Note'), findsOneWidget);
    expect(find.text('Math Solver'), findsOneWidget);
    expect(find.text('Chemistry'), findsOneWidget);
    expect(find.text('CAD Sketch'), findsOneWidget);
  });
}
