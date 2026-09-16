import 'package:cmproject/connectivity_module.dart';
import 'package:cmproject/data/generic_data_source.dart';
import 'package:cmproject/data/http_metro_datasource.dart';
import 'package:cmproject/data/sqflite_metro_datasource.dart';
import 'package:cmproject/location_module.dart';
import 'package:cmproject/main.dart';
import 'package:cmproject/models/station.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import 'fake_connectivity_module.dart';
import 'fake_generic_data_source.dart';
import 'fake_http_metro_datasource.dart';
import 'fake_location_module.dart';
import 'fake_sqflite_metro_datasource.dart';

List<Station> getDefaults() => [
  Station(
    id: "st1",
    name: 'Station 1',
    latitude: 40.7128,
    longitude: -74.0060,
    lineName: 'Rosa',
  ),
  Station(
    id: "st2",
    name: 'Station 2',
    latitude: 43.7128,
    longitude: -71.0060,
    lineName: 'Castanha',
  ),
];

extension PumpDependencies on WidgetTester {
  Future<AppHelper> pumpAppWithDependencies({
    List<Station>? remoteStations,
    List<Station>? localStations,
    bool isOnline = true,
    int? delay,
  }) async {
    final defaults = getDefaults();

    final generic = FakeGenericDataSource();
    // o .toList é para passar a lista por cópia e não por referencia...
    final remote = FakeHttpMetroDataSource(delay: delay, stations: (remoteStations ?? defaults).toList());
    final local = FakeSqfliteMetroDataSource(stations: (localStations ?? defaults).toList());
    final location = FakeLocationModule();
    final connectivity = FakeConnectivityModule(isOnline: isOnline);

    await pumpWidget(
      MultiProvider(
        providers: [
          Provider<GenericDataSource>.value(value: generic),
          Provider<HttpMetroDataSource>.value(value: remote),
          Provider<SqfliteMetroDataSource>.value(value: local),
          Provider<LocationModule>.value(value: location),
          Provider<ConnectivityModule>.value(value: connectivity),
        ],
        child: const MyApp(),
      ),
    );

    await pumpAndSettle(const Duration(milliseconds: 200));

    return AppHelper(
      genericDataSource: generic,
      remoteDataSource: remote,
      localDataSource: local,
      locationModule: location,
      connectivityModule: connectivity,
    );
  }
}

class AppHelper {
  final FakeGenericDataSource genericDataSource;
  final FakeHttpMetroDataSource remoteDataSource;
  final FakeSqfliteMetroDataSource localDataSource;
  final FakeLocationModule locationModule;
  final FakeConnectivityModule connectivityModule;

  AppHelper({
    required this.genericDataSource,
    required this.remoteDataSource,
    required this.localDataSource,
    required this.locationModule,
    required this.connectivityModule,
  });
}