import 'package:cmproject/connectivity_module.dart';

class FakeConnectivityModule extends ConnectivityModule {
  bool isOnline;

  FakeConnectivityModule({this.isOnline = true});

  @override
  Future<bool> checkConnectivity() async => isOnline == true;
}