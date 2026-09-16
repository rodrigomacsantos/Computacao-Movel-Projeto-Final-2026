import 'package:cmproject/models/incident_report.dart';
import 'package:cmproject/models/station.dart';

class MetroRepository {
  final List<Station> _stations = [];

  List<Station> getAllStations() {
    return List.unmodifiable(_stations);
  }

  void attachIncident(String id, IncidentReport report) {
    final index = _stations.indexWhere((station) => station.id == id);

    if (index == -1) {
      throw Exception('Station with id $id not found');
    }

    final station = _stations[index];
    _stations[index] = station.copyWith(
      reports: [
        ...station.reports,
        report,
      ],
    );
  }

  void insertStation(Station station) {
    final index = _stations.indexWhere((s) => s.id == station.id);
    if (index == -1) {
      _stations.add(station);
    } else {
      final existing = _stations[index];
      _stations[index] = station.copyWith(reports: existing.reports);
    }
  }

  Station getStationDetail(String id) {
    return _stations.firstWhere(
          (station) => station.id == id,
      orElse: () => throw Exception('Station with id $id not found'),
    );
  }

  List<Station> getStationsByName(String name) {
    return _stations
        .where(
          (station) => station.name.toLowerCase().contains(name.toLowerCase()),
    )
        .toList();
  }
}
