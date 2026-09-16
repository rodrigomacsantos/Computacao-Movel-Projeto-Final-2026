import 'package:cmproject/models/incident_report.dart';
import 'package:cmproject/models/station.dart';

class WaitingTime {
  final String platform;
  final int seconds;

  const WaitingTime({
    required this.platform,
    required this.seconds,
  });
}

abstract class MetroDataSource {

  Future<void> insertStation(Station station);

  Future<List<Station>> getAllStations();

  Future<List<Station>> getStationsByName(String name);

  Future<Station> getStationDetail(String id);

  Future<void> attachIncident(String id, IncidentReport report);

  Future<List<WaitingTime>> getWaitingTimesByStation(String stationId);

}
