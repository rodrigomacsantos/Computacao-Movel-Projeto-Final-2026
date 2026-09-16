import 'package:cmproject/data/http_metro_datasource.dart';
import 'package:cmproject/models/station.dart';

class FakeHttpMetroDataSource extends HttpMetroDataSource {

  final int? delay;
  final List<Station> stations;

  FakeHttpMetroDataSource({this.delay, required this.stations});

  @override
  Future<List<Station>> getAllStations() async {
    if (delay != null) {
      await Future.delayed(Duration(seconds: delay!));
    }

    return stations;
  }

  @override
  Future<Station> getStationDetail(String id) async {
    return stations.firstWhere((element) => element.id == id);
  }

}