import 'package:cmproject/location_module.dart';
import 'package:location/location.dart';

class FakeLocationModule extends LocationModule {
  final double? latitude;
  final double? longitude;

  FakeLocationModule({this.latitude, this.longitude});

  @override
  Stream<LocationData> onLocationChanged() {

    if (latitude == null) {
      return Stream.empty();
    }

    final fakeLocation = LocationData.fromMap({
      'latitude': latitude,
      'longitude': longitude,
      'accuracy': 1.0
    });

    return Stream.value(fakeLocation);
  }
}