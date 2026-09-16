import 'package:location/location.dart';

abstract class LocationModule {
  Stream<LocationData> onLocationChanged();
}