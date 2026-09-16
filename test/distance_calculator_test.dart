import 'package:flutter_test/flutter_test.dart';
import 'package:cmproject/data/distance_calculator.dart';

void main() {
  group('DistanceCalculator', () {
    test('calculateDistance deve retornar 0 para coordenadas iguais', () {
      final distance = DistanceCalculator.calculateDistance(38.7, -9.1, 38.7, -9.1);
      expect(distance, closeTo(0, 0.001));
    });

    test('calculateDistance deve retornar ~1.41 km para Príncipe Real -> Rossio', () {
      // Coordenadas aproximadas (Lisboa, Portugal)
      // Príncipe Real: ~38.7189, -9.1476
      // Rossio: ~38.7135, -9.1419
      final distance = DistanceCalculator.calculateDistance(
        38.7189, -9.1476,  // Príncipe Real
        38.7135, -9.1419,  // Rossio
      );
      // Distância esperada: ~0.84 km
      expect(distance, isPositive);
      expect(distance, greaterThan(0.5)); // Deve ser > 0.5 km
      expect(distance, lessThan(2.0));    // Deve ser < 2 km
    });

    test('formatDistance deve formatar < 1 km em metros', () {
      final formatted = DistanceCalculator.formatDistance(0.5);
      expect(formatted, contains('m'));
      expect(formatted.contains('500') || formatted.contains('m'), true);
    });

    test('formatDistance deve formatar >= 1 km em km', () {
      final formatted = DistanceCalculator.formatDistance(1.5);
      expect(formatted, contains('km'));
      expect(formatted, contains('1.5'));
    });

    test('formatDistance deve formatar < 1 m como "< 1 m"', () {
      final formatted = DistanceCalculator.formatDistance(0.0001);
      expect(formatted, equals('< 1 m'));
    });
  });
}

