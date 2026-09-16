import 'package:location/location.dart';

/// Serviço de localização simples e self-contained pensado para ser
/// injetado via Provider. Este serviço garante permissões e fornece um
/// stream de atualizações de localização.
class LocationService {
  final Location _client = Location();

  /// Retorna um stream de LocationData. Antes de expor o stream garante que
  /// o serviço está ativo e que as permissões foram concedidas.
  Stream<LocationData> onLocationChanged() async* {
    // Garante que o serviço de localização está ativo
    final serviceEnabled = await _client.serviceEnabled();
    if (!serviceEnabled) {
      final enabled = await _client.requestService();
      if (!enabled) return;
    }

    // Garante permissões
    final permission = await _client.hasPermission();
    if (permission == PermissionStatus.denied) {
      final requested = await _client.requestPermission();
      if (requested != PermissionStatus.granted) return;
    }

    // Por fim expõe o stream real de localização
    yield* _client.onLocationChanged;
  }
}


