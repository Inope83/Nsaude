import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:saude_konekta/core/widgets/cascading_location_picker.dart';
import 'package:saude_konekta/features/geography/geography_repository.dart';

class _FakeGeography implements GeographyService {
  final List<String> postRequests = <String>[];
  final List<String> sucoRequests = <String>[];
  GeoItem? lastReportedSuco;
  int reportedCount = 0;

  @override
  Future<List<GeoItem>> municipalities() async => const <GeoItem>[
        GeoItem(id: 1, name: 'Dili', code: 'dili'),
        GeoItem(id: 2, name: 'Manufahi', code: 'mfh'),
      ];

  @override
  Future<List<GeoItem>> postsFor(String municipalityCode) async {
    postRequests.add(municipalityCode);
    return <GeoItem>[
      GeoItem(id: 10, name: 'Posto $municipalityCode', code: '$municipalityCode-p'),
    ];
  }

  @override
  Future<List<GeoItem>> sucosFor(String administrativePostCode) async {
    sucoRequests.add(administrativePostCode);
    return <GeoItem>[
      GeoItem(id: 100, name: 'Suco $administrativePostCode', code: '$administrativePostCode-s'),
    ];
  }
}

Widget _wrap(Widget child) =>
    MaterialApp(home: Scaffold(body: SingleChildScrollView(child: child)));

Future<void> _select(WidgetTester tester, int index, String label) async {
  final dropdown = find.byType(DropdownButtonFormField<GeoItem>).at(index);
  await tester.ensureVisible(dropdown);
  await tester.pumpAndSettle();
  await tester.tap(dropdown);
  await tester.pumpAndSettle();
  await tester.tap(find.text(label).last);
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('selecting a municipality loads its posts', (tester) async {
    final geography = _FakeGeography();
    await tester.pumpWidget(_wrap(CascadingLocationPicker(
      geographyService: geography,
      onSucoChanged: (_) {},
    )));
    await tester.pumpAndSettle();

    expect(find.byType(DropdownButtonFormField<GeoItem>), findsNWidgets(3));
    expect(geography.postRequests, isEmpty);

    await _select(tester, 0, 'Dili');
    await tester.pumpAndSettle();

    expect(geography.postRequests, <String>['dili']);
    final postField = tester.widget<DropdownButtonFormField<GeoItem>>(
      find.byType(DropdownButtonFormField<GeoItem>).at(1),
    );
    expect(postField.onChanged, isNotNull);
  });

  testWidgets('selecting a post loads its sucos and reports the suco',
      (tester) async {
    final geography = _FakeGeography();
    await tester.pumpWidget(_wrap(CascadingLocationPicker(
      geographyService: geography,
      onSucoChanged: (value) {
        geography.lastReportedSuco = value;
        geography.reportedCount += 1;
      },
    )));
    await tester.pumpAndSettle();

    await _select(tester, 0, 'Dili');
    await tester.pumpAndSettle();
    await _select(tester, 1, 'Posto dili');
    await tester.pumpAndSettle();
    await _select(tester, 2, 'Suco dili-p');
    await tester.pumpAndSettle();

    expect(geography.sucoRequests, <String>['dili-p']);
    expect(geography.lastReportedSuco?.name, 'Suco dili-p');
  });

  testWidgets('changing the municipality clears the selected suco',
      (tester) async {
    final geography = _FakeGeography();
    await tester.pumpWidget(_wrap(CascadingLocationPicker(
      geographyService: geography,
      onSucoChanged: (value) {
        geography.lastReportedSuco = value;
        geography.reportedCount += 1;
      },
    )));
    await tester.pumpAndSettle();

    await _select(tester, 0, 'Dili');
    await tester.pumpAndSettle();
    await _select(tester, 1, 'Posto dili');
    await tester.pumpAndSettle();
    await _select(tester, 2, 'Suco dili-p');
    await tester.pumpAndSettle();
    final reportedAfterSelect = geography.reportedCount;
    expect(reportedAfterSelect, 3);

    await _select(tester, 0, 'Manufahi');
    await tester.pumpAndSettle();

    expect(geography.lastReportedSuco, isNull);
    expect(geography.reportedCount, reportedAfterSelect + 1);
    expect(geography.postRequests, contains('mfh'));
    expect(find.text('Posto dili'), findsNothing);
  });
}
