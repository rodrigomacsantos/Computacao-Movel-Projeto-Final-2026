import 'dart:convert';

import 'package:cmproject/data/metro_datasource.dart';
import 'package:cmproject/models/incident_report.dart';
import 'package:cmproject/models/station.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';

class SqfliteMetroDataSource extends MetroDataSource {
  static const _databaseName = 'metro_cache.db';
  static const _databaseVersion = 1;
  static const _stationsTable = 'stations';
  static const _incidentsTable = 'incidents';
  static const _metadataTable = 'metadata';
  static const _lastStationsUpdateKey = 'last_stations_update';

  Database? _database;

  Future<bool> init() async {
    await _db;
    return true;
  }

  Future<Database> get _db async {
    final current = _database;
    if (current != null) {
      return current;
    }

    final databasePath = await getDatabasesPath();
    final database = await openDatabase(
      p.join(databasePath, _databaseName),
      version: _databaseVersion,
      onCreate: (db, version) async {
        await db.execute('''
          CREATE TABLE $_stationsTable (
            id TEXT PRIMARY KEY,
            name TEXT NOT NULL,
            latitude REAL NOT NULL,
            longitude REAL NOT NULL,
            line_name TEXT NOT NULL,
            zone_id TEXT,
            official_urls TEXT NOT NULL
          )
        ''');
        await db.execute('''
          CREATE TABLE $_incidentsTable (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            station_id TEXT NOT NULL,
            timestamp TEXT NOT NULL,
            rate INTEGER NOT NULL,
            notes TEXT,
            type TEXT NOT NULL,
            FOREIGN KEY(station_id) REFERENCES $_stationsTable(id) ON DELETE CASCADE
          )
        ''');
        await db.execute('''
          CREATE TABLE $_metadataTable (
            key TEXT PRIMARY KEY,
            value TEXT NOT NULL
          )
        ''');
      },
    );
    _database = database;
    return database;
  }

  @override
  Future<void> insertStation(Station station) async {
    final db = await _db;
    await db.insert(
      _stationsTable,
      _stationToMap(station),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
    await _setLastStationsUpdate(DateTime.now());
  }

  @override
  Future<List<Station>> getAllStations() async {
    final db = await _db;
    final rows = await db.query(_stationsTable, orderBy: 'name COLLATE NOCASE ASC');
    final stations = <Station>[];

    for (final row in rows) {
      stations.add(
        _stationFromMap(
          row,
          await _getIncidentsForStation(row['id'] as String),
        ),
      );
    }

    return stations;
  }

  @override
  Future<List<Station>> getStationsByName(String name) async {
    final query = name.toLowerCase();
    final stations = await getAllStations();
    return stations.where((station) => station.name.toLowerCase().contains(query)).toList();
  }

  @override
  Future<Station> getStationDetail(String id) async {
    final db = await _db;
    final rows = await db.query(
      _stationsTable,
      where: 'id = ?',
      whereArgs: [id],
      limit: 1,
    );

    if (rows.isEmpty) {
      throw Exception('Station with id $id not found');
    }

    return _stationFromMap(rows.first, await _getIncidentsForStation(id));
  }

  @override
  Future<void> attachIncident(String id, IncidentReport report) async {
    final db = await _db;
    await db.insert(_incidentsTable, {
      'station_id': id,
      'timestamp': report.timestamp.toIso8601String(),
      'rate': report.rate,
      'notes': report.notes,
      'type': report.type.name,
    });
  }

  Future<DateTime?> getLastStationsUpdate() async {
    final db = await _db;
    final rows = await db.query(
      _metadataTable,
      columns: ['value'],
      where: 'key = ?',
      whereArgs: [_lastStationsUpdateKey],
      limit: 1,
    );

    if (rows.isEmpty) {
      return null;
    }

    return DateTime.tryParse(rows.first['value'] as String);
  }

  Future<void> _setLastStationsUpdate(DateTime value) async {
    final db = await _db;
    await db.insert(
      _metadataTable,
      {
        'key': _lastStationsUpdateKey,
        'value': value.toIso8601String(),
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Map<String, Object?> _stationToMap(Station station) {
    return {
      'id': station.id,
      'name': station.name,
      'latitude': station.latitude,
      'longitude': station.longitude,
      'line_name': station.lineName,
      'zone_id': station.zoneId,
      'official_urls': jsonEncode(station.officialUrls),
    };
  }

  Station _stationFromMap(Map<String, Object?> map, List<IncidentReport> reports) {
    return Station(
      id: map['id'] as String,
      name: map['name'] as String,
      latitude: (map['latitude'] as num).toDouble(),
      longitude: (map['longitude'] as num).toDouble(),
      lineName: map['line_name'] as String,
      zoneId: map['zone_id'] as String?,
      officialUrls: _decodeStringList(map['official_urls'] as String?),
      reports: reports,
    );
  }

  Future<List<IncidentReport>> _getIncidentsForStation(String stationId) async {
    final db = await _db;
    final rows = await db.query(
      _incidentsTable,
      where: 'station_id = ?',
      whereArgs: [stationId],
      orderBy: 'timestamp DESC',
    );

    return rows.map(_incidentFromMap).toList();
  }

  IncidentReport _incidentFromMap(Map<String, Object?> map) {
    return IncidentReport(
      timestamp: DateTime.parse(map['timestamp'] as String),
      rate: map['rate'] as int,
      notes: map['notes'] as String?,
      type: IncidentType.values.firstWhere(
        (type) => type.name == map['type'],
        orElse: () => IncidentType.other,
      ),
    );
  }

  List<String> _decodeStringList(String? value) {
    if (value == null || value.isEmpty) {
      return const [];
    }

    final decoded = jsonDecode(value);
    if (decoded is! List) {
      return const [];
    }

    return decoded.map((item) => item.toString()).toList();
  }

  @override
  Future<List<WaitingTime>> getWaitingTimesByStation(String stationId) async {
    return const [];
  }
}
