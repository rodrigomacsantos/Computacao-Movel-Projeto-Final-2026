import 'dart:core';

import 'incident_report.dart';

class Station {
  final String id;
  final String name;
  final double latitude, longitude;
  final String lineName;
  final String? zoneId;
  final List<String> officialUrls;
  final List<IncidentReport> reports;

  Station({
    required this.id,
    required this.name,
    required this.latitude,
    required this.longitude,
    required this.lineName,
    this.zoneId,
    List<String>? officialUrls,
    List<IncidentReport>? reports,
  })  : officialUrls = officialUrls ?? const [],
        reports = reports ?? [];

  Station copyWith({
    String? id,
    String? name,
    double? latitude,
    double? longitude,
    String? lineName,
    String? zoneId,
    List<String>? officialUrls,
    List<IncidentReport>? reports,
  }) {
    return Station(
      id: id ?? this.id,
      name: name ?? this.name,
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
      lineName: lineName ?? this.lineName,
      zoneId: zoneId ?? this.zoneId,
      officialUrls: officialUrls ?? this.officialUrls,
      reports: reports ?? this.reports,
    );
  }

  @override
  bool operator ==(Object other) {
    return other is Station && other.id == id;
  }

  @override
  int get hashCode => id.hashCode;
}
