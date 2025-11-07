import 'package:flutter_test/flutter_test.dart';
import 'package:hm_innova_app/app.dart';

void main() {
  testWidgets('App builds', (tester) async {
    await tester.pumpWidget(const HmInnovaApp());
    expect(find.textContaining('HM INNOVA'), findsOneWidget);
  });
}
