import 'package:flutter_test/flutter_test.dart';

import 'package:opinion_hub/main.dart';

void main() {
  testWidgets('OpinionHub app loads', (WidgetTester tester) async {
    await tester.pumpWidget(const OpinionHubApp());

    expect(find.text('OpinionHub'), findsOneWidget);
  });
}