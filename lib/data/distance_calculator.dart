import 'dart:math' as math;

/// Utilitário para calcular distâncias reais entre coordenadas geográficas
/// usando a fórmula de Haversine (distância em km).
class DistanceCalculator {
  // Raio da Terra em km
  static const double earthRadiusKm = 6371.0;

  /// Calcula a distância em km entre dois pontos (latitude, longitude)
  /// usando a fórmula de Haversine.
  static double calculateDistance(
    double lat1,
    double lon1,
    double lat2,
    double lon2,
  ) {
    // Converter para radianos
    final dLat = _toRadians(lat2 - lat1);
    final dLon = _toRadians(lon2 - lon1);
    final lat1Rad = _toRadians(lat1);
    final lat2Rad = _toRadians(lat2);

    // Fórmula de Haversine
    final a = math.sin(dLat / 2) * math.sin(dLat / 2) +
        math.sin(dLon / 2) * math.sin(dLon / 2) *
        math.cos(lat1Rad) * math.cos(lat2Rad);

    final c = 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));
    final distance = earthRadiusKm * c;

    return distance;
  }

  /// Converte graus para radianos
  static double _toRadians(double degrees) {
    return degrees * math.pi / 180.0;
  }

  /// Formata a distância em km para uma string legível
  static String formatDistance(double distanceKm) {
    if (distanceKm < 0.001) {
      return '< 1 m';
    }
    if (distanceKm < 1) {
      final meters = (distanceKm * 1000).toStringAsFixed(0);
      return '$meters m';
    }
    return '${distanceKm.toStringAsFixed(1)} km';
  }
}

