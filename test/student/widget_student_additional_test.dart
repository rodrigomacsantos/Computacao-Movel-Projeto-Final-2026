import 'package:cmproject/data/metro_repository.dart';
import 'package:cmproject/main.dart';
import 'package:cmproject/models/incident_report.dart';
import 'package:cmproject/models/station.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:testable_form_field/testable_form_field.dart';

void main() {
  group('Student additional tests', () {
    testWidgets('Dashboard - antes e depois de atualizar o modelo', (tester) async {
      final repository = MetroRepository();
      repository.insertStation(
        Station(
          id: 'st1',
          name: 'Station 1',
          latitude: 40.0,
          longitude: -8.0,
          lineName: 'Rosa',
        ),
      );

      await _pumpApp(tester, repository);

      final stationsTile = find.widgetWithText(ListTile, 'Estacoes monitorizadas');
      expect(find.descendant(of: stationsTile, matching: find.text('1')), findsOneWidget);

      repository.insertStation(
        Station(
          id: 'st2',
          name: 'Station 2',
          latitude: 41.0,
          longitude: -9.0,
          lineName: 'Castanha',
        ),
      );

      // Trigger a rebuild of the dashboard by changing tabs and coming back.
      await tester.tap(find.byKey(const Key('list-bottom-bar-item')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('dashboard-bottom-bar-item')));
      await tester.pumpAndSettle();

      expect(find.descendant(of: stationsTile, matching: find.text('2')), findsOneWidget);
    });

    testWidgets('Formulario - validacao extra da avaliacao fora do intervalo', (tester) async {
      final repository = MetroRepository();
      final station = Station(
        id: 'st1',
        name: 'Station 1',
        latitude: 40.0,
        longitude: -8.0,
        lineName: 'Rosa',
      );
      repository.insertStation(station);

      await _pumpApp(tester, repository);

      await tester.tap(find.byKey(const Key('incidents-report-bottom-bar-item')));
      await tester.pumpAndSettle();

      final stationField = tester.widget<TestableFormField<Station>>(
        find.byKey(const Key('incident-station-selection-field')),
      );
      final incidentTypeField = tester.widget<TestableFormField<IncidentType>>(
        find.byKey(const Key('incident-type-selection-field')),
      );
      final dateTimeField = tester.widget<TestableFormField<DateTime>>(
        find.byKey(const Key('incident-datetime-field')),
      );

      stationField.setValue(station);
      incidentTypeField.setValue(IncidentType.Elevator);
      dateTimeField.setValue(DateTime(2026, 1, 10, 10, 30));

      final ratingInput = find.descendant(
        of: find.byKey(const Key('incident-rating-field')),
        matching: find.byType(TextFormField),
      );
      await tester.enterText(ratingInput, '0');

      final submitButton = find.byKey(const Key('incident-form-submit-button'));
      await tester.ensureVisible(submitButton);
      await tester.tap(submitButton);
      await tester.pumpAndSettle();

      expect(find.textContaining('inteiro entre 1 e 5'), findsOneWidget);
    });

    test('Modelo - duas avaliacoes na mesma estacao e media correta', () {
      final repository = MetroRepository();
      final station = Station(
        id: 'st1',
        name: 'Hospital Central',
        latitude: 40.0,
        longitude: -8.0,
        lineName: 'Rosa',
      );
      repository.insertStation(station);

      repository.attachIncident(
        station.id,
        IncidentReport(
          timestamp: DateTime(2026, 1, 1, 8, 0),
          rate: 3,
          type: IncidentType.Escalator,
        ),
      );

      repository.attachIncident(
        station.id,
        IncidentReport(
          timestamp: DateTime(2026, 1, 1, 9, 0),
          rate: 5,
          type: IncidentType.Elevator,
        ),
      );

      final reports = repository.getStationDetail(station.id).reports;
      final average = reports.map((r) => r.rate).reduce((a, b) => a + b) / reports.length;

      expect(reports.length, 2);
      expect(average, 4);
    });

    testWidgets('Pesquisa - filtra estacoes pelo nome', (tester) async {
      final repository = MetroRepository();
      repository.insertStation(
        Station(
          id: 'st1',
          name: 'Oriente',
          latitude: 38.0,
          longitude: -9.0,
          lineName: 'Vermelha',
        ),
      );
      repository.insertStation(
        Station(
          id: 'st2',
          name: 'Campo Grande',
          latitude: 38.7,
          longitude: -9.1,
          lineName: 'Amarela',
        ),
      );

      await _pumpApp(tester, repository);

      await tester.tap(find.byKey(const Key('list-bottom-bar-item')));
      await tester.pumpAndSettle();

      await tester.enterText(find.byKey(const Key('stations-search-field')), 'Oriente');
      await tester.pumpAndSettle();

      final listView = find.byKey(const Key('list-view'));
      expect(
        find.descendant(of: listView, matching: find.text('Oriente')),
        findsOneWidget,
      );
      expect(
        find.descendant(of: listView, matching: find.text('Campo Grande')),
        findsNothing,
      );
    });
  });
}

Future<void> _pumpApp(WidgetTester tester, MetroRepository repository) async {
  await tester.pumpWidget(
    MultiProvider(
      providers: [
        Provider<MetroRepository>.value(value: repository),
      ],
      child: const MyApp(),
    ),
  );

  await tester.pumpAndSettle();
}


