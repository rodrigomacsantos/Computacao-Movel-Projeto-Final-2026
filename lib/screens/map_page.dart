import 'package:cmproject/connectivity_module.dart';
import 'package:cmproject/data/location_service.dart';
import 'package:cmproject/data/metro_repository.dart';
import 'package:cmproject/data/sqflite_metro_datasource.dart';
import 'package:cmproject/models/station.dart';
import 'package:cmproject/screens/station_detail_page.dart';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:intl/intl.dart';
import 'package:location/location.dart';
import 'package:provider/provider.dart';

class MapPage extends StatefulWidget {
  const MapPage({super.key});

  @override
  State<MapPage> createState() => _MapPageState();
}

class _MapPageState extends State<MapPage> {
  GoogleMapController? _mapController;
  LocationData? _userLocation;
  Future<String?>? _offlineNoticeFuture;
  String? _selectedLineKey;

  @override
  void initState() {
    super.initState();
    _initializeLocation();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _offlineNoticeFuture ??= _buildOfflineNotice();
  }

  void _initializeLocation() {
    try {
      final locationService = Provider.of<LocationService>(context, listen: false);
      locationService.onLocationChanged().first.then((location) {
        if (mounted) {
          setState(() {
            _userLocation = location;
            if (_mapController != null) {
              _mapController!.animateCamera(
                CameraUpdate.newCameraPosition(
                  CameraPosition(
                    target: LatLng(location.latitude ?? 38.7223, location.longitude ?? -9.1393),
                    zoom: 14,
                  ),
                ),
              );
            }
          });
        }
      }).catchError((_) {});
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<MetroRepository>(
      builder: (context, repository, _) {
        final stations = repository.getAllStations();
        final lineOptions = _lineOptionsFromStations(stations);
        final filteredStations = _filterStationsByLine(stations, _selectedLineKey);
        final markers = _buildMarkers(context, filteredStations);
        final target = _initialTarget(filteredStations.isEmpty ? stations : filteredStations);

        return Scaffold(
          key: const Key('map-screen'),
          appBar: AppBar(
            title: const Text('Mapa'),
          ),
          body: Stack(
            children: [
              GoogleMap(
                onMapCreated: (controller) {
                  _mapController = controller;
                  if (_userLocation != null) {
                    controller.animateCamera(
                      CameraUpdate.newCameraPosition(
                        CameraPosition(
                          target: LatLng(_userLocation!.latitude ?? 38.7223, _userLocation!.longitude ?? -9.1393),
                          zoom: 14,
                        ),
                      ),
                    );
                  }
                },
                initialCameraPosition: CameraPosition(
                  target: target,
                  zoom: stations.isEmpty ? 11 : 12,
                ),
                markers: markers,
                myLocationButtonEnabled: false,
                zoomControlsEnabled: true,
                mapToolbarEnabled: false,
              ),
              _MapFilterOverlay(
                noticeFuture: _offlineNoticeFuture,
                lineOptions: lineOptions,
                selectedLineKey: _selectedLineKey,
                onSelected: (lineKey) {
                  setState(() {
                    _selectedLineKey = lineKey;
                  });
                  final nextStations = _filterStationsByLine(stations, lineKey);
                  _moveCameraToStations(nextStations.isEmpty ? stations : nextStations);
                },
              ),
            ],
          ),
        );
      },
    );
  }

  LatLng _initialTarget(List<Station> stations) {
    if (_userLocation != null) {
      return LatLng(_userLocation!.latitude ?? 38.7223, _userLocation!.longitude ?? -9.1393);
    }

    if (stations.isEmpty) {
      return const LatLng(38.7223, -9.1393);
    }

    final latitude = stations.map((station) => station.latitude).reduce((a, b) => a + b) / stations.length;
    final longitude = stations.map((station) => station.longitude).reduce((a, b) => a + b) / stations.length;
    return LatLng(latitude, longitude);
  }

  Set<Marker> _buildMarkers(BuildContext context, List<Station> stations) {
    final markers = <Marker>{};

    if (_userLocation != null) {
      markers.add(
        Marker(
          markerId: const MarkerId('user_location'),
          position: LatLng(_userLocation!.latitude ?? 38.7223, _userLocation!.longitude ?? -9.1393),
          infoWindow: const InfoWindow(
            title: 'A sua localizacao',
            snippet: 'Aqui esta',
          ),
          icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueBlue),
        ),
      );
    }

    markers.addAll(
      stations.map(
        (station) => Marker(
          markerId: MarkerId(station.id),
          position: LatLng(station.latitude, station.longitude),
          onTap: () {
            Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => StationDetailPage(station: station),
              ),
            );
          },
          infoWindow: InfoWindow(
            title: station.name,
            snippet: station.lineName,
            onTap: () {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => StationDetailPage(station: station),
                ),
              );
            },
          ),
        ),
      ),
    );

    return markers;
  }

  void _moveCameraToStations(List<Station> stations) {
    if (_mapController == null || stations.isEmpty) {
      return;
    }

    final latitude = stations.map((station) => station.latitude).reduce((a, b) => a + b) / stations.length;
    final longitude = stations.map((station) => station.longitude).reduce((a, b) => a + b) / stations.length;
    _mapController!.animateCamera(
      CameraUpdate.newCameraPosition(
        CameraPosition(
          target: LatLng(latitude, longitude),
          zoom: 12,
        ),
      ),
    );
  }

  Future<String?> _buildOfflineNotice() async {
    ConnectivityModule? connectivity;
    try {
      connectivity = Provider.of<ConnectivityModule>(context, listen: false);
    } catch (_) {
      connectivity = null;
    }

    SqfliteMetroDataSource? local;
    try {
      local = Provider.of<SqfliteMetroDataSource>(context, listen: false);
    } catch (_) {
      local = null;
    }

    final isOnline = connectivity == null ? true : await connectivity.checkConnectivity();
    if (isOnline) {
      return null;
    }

    DateTime? lastUpdate;
    if (local != null && local.runtimeType == SqfliteMetroDataSource) {
      try {
        lastUpdate = await local.getLastStationsUpdate();
      } catch (_) {
        lastUpdate = null;
      }
    }

    if (lastUpdate == null) {
      return 'Sem ligacao. A mostrar dados guardados anteriormente.';
    }

    final formatted = DateFormat('dd/MM/yyyy HH:mm').format(lastUpdate);
    return 'Sem ligacao. A mostrar dados guardados da ultima atualizacao: $formatted.';
  }
}

class _MapFilterOverlay extends StatelessWidget {
  final Future<String?>? noticeFuture;
  final List<_LineOption> lineOptions;
  final String? selectedLineKey;
  final ValueChanged<String?> onSelected;

  const _MapFilterOverlay({
    required this.noticeFuture,
    required this.lineOptions,
    required this.selectedLineKey,
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.topCenter,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            FutureBuilder<String?>(
              future: noticeFuture,
              builder: (context, snapshot) {
                final notice = snapshot.data;
                if (notice == null || notice.isEmpty) {
                  return const SizedBox.shrink();
                }

                return Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Material(
                    color: Theme.of(context).colorScheme.errorContainer,
                    borderRadius: BorderRadius.circular(8),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      child: Text(
                        notice,
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.onErrorContainer,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
            Material(
              color: Colors.white,
              elevation: 2,
              borderRadius: BorderRadius.circular(8),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                child: _LineFilterBar(
                  lineOptions: lineOptions,
                  selectedLineKey: selectedLineKey,
                  onSelected: onSelected,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _LineFilterBar extends StatelessWidget {
  final List<_LineOption> lineOptions;
  final String? selectedLineKey;
  final ValueChanged<String?> onSelected;

  const _LineFilterBar({
    required this.lineOptions,
    required this.selectedLineKey,
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          ChoiceChip(
            label: const Text('Todas'),
            selected: selectedLineKey == null,
            onSelected: (_) => onSelected(null),
          ),
          const SizedBox(width: 8),
          ...lineOptions.map(
            (line) => Padding(
              padding: const EdgeInsets.only(right: 8),
              child: ChoiceChip(
                label: Text(line.name),
                selected: selectedLineKey == line.key,
                onSelected: (_) => onSelected(line.key),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _LineOption {
  final String key;
  final String name;

  const _LineOption({
    required this.key,
    required this.name,
  });
}

List<Station> _filterStationsByLine(List<Station> stations, String? selectedLineKey) {
  if (selectedLineKey == null) {
    return stations;
  }

  return stations.where((station) => _stationLineKeys(station).contains(selectedLineKey)).toList();
}

List<_LineOption> _lineOptionsFromStations(List<Station> stations) {
  final namesByKey = <String, String>{};
  for (final station in stations) {
    for (final line in _stationLines(station)) {
      namesByKey.putIfAbsent(_lineKey(line), () => line);
    }
  }

  return namesByKey.entries
      .map((entry) => _LineOption(key: entry.key, name: entry.value))
      .toList()
    ..sort((a, b) => a.name.compareTo(b.name));
}

List<String> _stationLines(Station station) {
  final seen = <String>{};
  final lines = <String>[];

  for (final part in station.lineName.split('/')) {
    final line = part.trim();
    if (line.isEmpty) continue;

    final key = _lineKey(line);
    if (seen.add(key)) {
      lines.add(line);
    }
  }

  return lines;
}

Set<String> _stationLineKeys(Station station) {
  return _stationLines(station).map(_lineKey).toSet();
}

String _lineKey(String line) => line.trim().toLowerCase();
