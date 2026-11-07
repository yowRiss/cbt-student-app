import 'package:flutter_test/flutter_test.dart';
import 'package:cbt_mobile/main.dart';

void main() {
  testWidgets('CbtStudentApp smoke test', (WidgetTester tester) async {
    await tester.pumpWidget(const CbtStudentApp());
  });
}
