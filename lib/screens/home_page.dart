import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:location/location.dart';
import 'package:cmproject/data/distance_calculator.dart';
import 'package:cmproject/data/location_service.dart';
import 'package:cmproject/data/metro_repository.dart';
import 'package:cmproject/location_module.dart';
import 'package:cmproject/models/station.dart';
import 'package:cmproject/screens/forms_page.dart';
import 'package:cmproject/screens/map_page.dart';
import 'package:cmproject/screens/station_detail_page.dart';
import 'package:cmproject/screens/stations_list_page.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  int selectedIndex = 0;

  late final List<Widget> pages;

  @override
  void initState() {
    super.initState();
    pages = const [
      DashboardPage(),
      StationsListPage(),
      MapPage(),
      FormsPage(),
    ];
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: pages[selectedIndex],
      bottomNavigationBar: NavigationBar(
        selectedIndex: selectedIndex,
        onDestinationSelected: (index) {
          setState(() {
            selectedIndex = index;
          });
        },
        destinations: const [
          NavigationDestination(
            key: Key('dashboard-bottom-bar-item'),
            icon: Icon(Icons.dashboard),
            label: 'Dashboard',
          ),
          NavigationDestination(
            key: Key('list-bottom-bar-item'),
            icon: Icon(Icons.train),
            label: 'Esta\u00e7\u00f5es',
          ),
          NavigationDestination(
            key: Key('map-bottom-bar-item'),
            icon: Icon(Icons.map),
            label: 'Mapa',
          ),
          NavigationDestination(
            key: Key('incidents-report-bottom-bar-item'),
            icon: Icon(Icons.report_problem),
            label: 'Incidentes',
          ),
        ],
      ),
    );
  }
}

class DashboardPage extends StatelessWidget {
  const DashboardPage({super.key});

  @override
  Widget build(BuildContext context) {
    final repository = context.watch<MetroRepository>();
    final stations = repository.getAllStations();
    final data = _DashboardData.from(stations);

    return Scaffold(
      key: const Key('dashboard-screen'),
      appBar: AppBar(title: const Text('Dashboard')),
      body: data.stationsCount == 0 ? _buildEmptyState(context) : _buildDashboard(context, data),
    );
  }

  Widget _buildDashboard(BuildContext context, _DashboardData data) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _NearestStationCard(stations: data.stations),
        const SizedBox(height: 16),
        _buildMetricGrid(context, data),
        const SizedBox(height: 24),
        const _SectionHeader(
          title: 'Cobertura por linha',
          subtitle: 'Distribui\u00e7\u00e3o de esta\u00e7\u00f5es e pontos de correspond\u00eancia.',
        ),
        const SizedBox(height: 10),
        ...data.lines.map(
          (line) => _LineCoverageCard(
            line: line,
            totalStations: data.stationsCount,
            onTap: () {
              _openLineStations(context, line.name);
            },
          ),
        ),
        const SizedBox(height: 24),
        const _SectionHeader(
          title: 'Esta\u00e7\u00f5es com correspond\u00eancia',
          subtitle: 'Esta\u00e7\u00f5es associadas a mais do que uma linha.',
        ),
        const SizedBox(height: 10),
        _buildInterchangeList(context, data),
      ],
    );
  }

  Widget _buildMetricGrid(BuildContext context, _DashboardData data) {
    final metrics = [
      _MetricItem(
        title: 'Estacoes monitorizadas',
        value: '${data.stationsCount}',
        icon: Icons.location_city,
        color: Theme.of(context).colorScheme.primary,
      ),
      _MetricItem(
        title: 'Linhas identificadas',
        value: '${data.linesCount}',
        icon: Icons.timeline,
        color: const Color(0xFF00897B),
      ),
      _MetricItem(
        title: 'Esta\u00e7\u00f5es com correspond\u00eancia',
        value: '${data.interchangeCount}',
        icon: Icons.device_hub,
        color: const Color(0xFFE65100),
      ),
    ];

    return LayoutBuilder(
      builder: (context, constraints) {
        final columns = constraints.maxWidth >= 680
            ? 3
            : constraints.maxWidth >= 480
                ? 2
                : 1;
        final spacing = columns == 1 ? 0.0 : 12.0;
        final itemWidth = (constraints.maxWidth - spacing * (columns - 1)) / columns;

        return Wrap(
          spacing: spacing,
          runSpacing: 12,
          children: metrics
              .map(
                (metric) => SizedBox(
                  width: itemWidth,
                  child: _MetricCard(metric: metric),
                ),
              )
              .toList(),
        );
      },
    );
  }

  Widget _buildInterchangeList(BuildContext context, _DashboardData data) {
    if (data.interchangeStations.isEmpty) {
      return const _EmptyInsightCard(
        icon: Icons.device_hub,
        title: 'Sem correspond\u00eancias identificadas',
        subtitle: 'Cada esta\u00e7\u00e3o est\u00e1 associada a uma \u00fanica linha.',
      );
    }

    return Column(
      children: data.interchangeStations.map(
        (station) {
          final lines = _stationLines(station);

          return Card(
            margin: const EdgeInsets.only(bottom: 8),
            child: ListTile(
              minLeadingWidth: lines.length * 34.0,
              leading: _LineMarkerButtons(lines: lines),
              title: Text(station.name),
              subtitle: Text(lines.join(' / ')),
              onTap: () {
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => StationDetailPage(station: station),
                  ),
                );
              },
              trailing: Text(
                '${lines.length} linhas',
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
            ),
          );
        },
      ).toList(),
    );
  }

  Widget _buildEmptyState(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.map_outlined,
              size: 56,
              color: Theme.of(context).colorScheme.primary,
            ),
            const SizedBox(height: 12),
            const Text(
              'Sem dados de rede dispon\u00edveis',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 6),
            const Text(
              'Quando as esta\u00e7\u00f5es forem carregadas, este painel mostra cobertura, linhas e correspond\u00eancias.',
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

class _NearestStationCard extends StatefulWidget {
  final List<Station> stations;

  const _NearestStationCard({required this.stations});

  @override
  State<_NearestStationCard> createState() => _NearestStationCardState();
}

class _NearestStationCardState extends State<_NearestStationCard> {
  Stream<LocationData>? _locationStream;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _locationStream ??= _readLocationStream(context)?.timeout(
      const Duration(seconds: 10),
      onTimeout: (sink) {
        sink.addError('Location timeout');
        sink.close();
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final stream = _locationStream;

    if (stream == null) {
      return _buildUnavailable(context, 'Ative a localiza\u00e7\u00e3o para calcular a esta\u00e7\u00e3o mais pr\u00f3xima.');
    }

    return StreamBuilder<LocationData>(
      stream: stream,
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return _buildUnavailable(context, 'N\u00e3o foi poss\u00edvel obter a sua localiza\u00e7\u00e3o.');
        }

        if (!snapshot.hasData) {
          if (snapshot.connectionState == ConnectionState.done) {
            return _buildUnavailable(context, 'Localiza\u00e7\u00e3o indispon\u00edvel neste momento.');
          }

          return _buildLoading(context);
        }

        final nearest = _nearestStationForLocation(snapshot.data!, widget.stations);
        if (nearest == null) {
          return _buildUnavailable(context, 'Sem coordenadas de esta\u00e7\u00f5es suficientes para calcular proximidade.');
        }

        return _buildNearest(context, nearest);
      },
    );
  }

  Stream<LocationData>? _readLocationStream(BuildContext context) {
    try {
      return Provider.of<LocationService>(context, listen: false).onLocationChanged();
    } catch (_) {
      try {
        return Provider.of<LocationModule>(context, listen: false).onLocationChanged();
      } catch (_) {
        return null;
      }
    }
  }

  Widget _buildLoading(BuildContext context) {
    return Card(
      margin: EdgeInsets.zero,
      child: ListTile(
        leading: const SizedBox(
          width: 38,
          height: 38,
          child: Padding(
            padding: EdgeInsets.all(8),
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
        ),
        title: const Text('Esta\u00e7\u00e3o mais pr\u00f3xima'),
        subtitle: const Text('A obter a sua localiza\u00e7\u00e3o...'),
      ),
    );
  }

  Widget _buildUnavailable(BuildContext context, String message) {
    final color = Theme.of(context).colorScheme.primary;

    return Card(
      margin: EdgeInsets.zero,
      child: ListTile(
        leading: _TintedIcon(icon: Icons.near_me_disabled, color: color),
        title: const Text('Esta\u00e7\u00e3o mais pr\u00f3xima'),
        subtitle: Text(message),
      ),
    );
  }

  Widget _buildNearest(BuildContext context, _NearestStationResult nearest) {
    final station = nearest.station;
    final lines = _stationLines(station);
    final lineLabel = lines.isEmpty ? station.lineName : lines.join(' / ');
    final color = lines.isEmpty ? Theme.of(context).colorScheme.primary : _lineColor(lines.first);
    final distance = DistanceCalculator.formatDistance(nearest.distanceKm);

    return Card(
      margin: EdgeInsets.zero,
      elevation: 2,
      child: InkWell(
        borderRadius: BorderRadius.circular(8),
        onTap: () {
          Navigator.of(context).push(
            MaterialPageRoute(
              builder: (_) => StationDetailPage(station: station),
            ),
          );
        },
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  _TintedIcon(icon: Icons.near_me, color: color),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Esta\u00e7\u00e3o mais pr\u00f3xima',
                          style: Theme.of(context).textTheme.labelLarge?.copyWith(
                                color: Colors.black54,
                                fontWeight: FontWeight.w700,
                              ),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          station.name,
                          style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                                fontWeight: FontWeight.w800,
                              ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  _SmallStat(label: 'Dist\u00e2ncia', value: distance),
                  _SmallStat(label: 'Linha', value: lineLabel),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _DashboardData {
  final List<Station> stations;
  final List<_LineSummary> lines;
  final List<Station> interchangeStations;

  const _DashboardData({
    required this.stations,
    required this.lines,
    required this.interchangeStations,
  });

  int get stationsCount => stations.length;
  int get linesCount => lines.length;
  int get interchangeCount => interchangeStations.length;

  factory _DashboardData.from(List<Station> rawStations) {
    final stations = List<Station>.of(rawStations)..sort((a, b) => a.name.compareTo(b.name));
    final lineNamesByKey = <String, String>{};
    final lineToStations = <String, Set<String>>{};
    final lineToTransfers = <String, Set<String>>{};

    final interchangeStations = <Station>[];

    for (final station in stations) {
      final stationLines = _stationLines(station);

      if (stationLines.length > 1) {
        interchangeStations.add(station);
      }

      for (final line in stationLines) {
        final key = _lineKey(line);
        lineNamesByKey.putIfAbsent(key, () => line);
        (lineToStations[key] ??= <String>{}).add(station.id);
        if (stationLines.length > 1) {
          (lineToTransfers[key] ??= <String>{}).add(station.id);
        }
      }
    }

    final lines = lineToStations.entries.map(
      (entry) {
        final name = lineNamesByKey[entry.key] ?? entry.key;
        return _LineSummary(
          name: name,
          stationCount: entry.value.length,
          transferCount: lineToTransfers[entry.key]?.length ?? 0,
        );
      },
    ).toList()
      ..sort(_compareLineSummaries);

    interchangeStations.sort((a, b) {
      final lineDiff = _stationLines(b).length.compareTo(_stationLines(a).length);
      if (lineDiff != 0) return lineDiff;
      return a.name.compareTo(b.name);
    });

    return _DashboardData(
      stations: stations,
      lines: lines,
      interchangeStations: interchangeStations,
    );
  }
}

class _LineSummary {
  final String name;
  final int stationCount;
  final int transferCount;

  const _LineSummary({
    required this.name,
    required this.stationCount,
    required this.transferCount,
  });
}

class _NearestStationResult {
  final Station station;
  final double distanceKm;

  const _NearestStationResult({
    required this.station,
    required this.distanceKm,
  });
}

class _MetricItem {
  final String title;
  final String value;
  final IconData icon;
  final Color color;

  const _MetricItem({
    required this.title,
    required this.value,
    required this.icon,
    required this.color,
  });
}

class _SectionHeader extends StatelessWidget {
  final String title;
  final String subtitle;

  const _SectionHeader({
    required this.title,
    required this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: 4),
        Text(
          subtitle,
          style: const TextStyle(color: Colors.black54),
        ),
      ],
    );
  }
}

class _MetricCard extends StatelessWidget {
  final _MetricItem metric;

  const _MetricCard({required this.metric});

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: EdgeInsets.zero,
      child: ListTile(
        minLeadingWidth: 36,
        leading: _TintedIcon(icon: metric.icon, color: metric.color),
        title: Text(
          metric.title,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
        ),
        trailing: Text(
          metric.value,
          style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800),
        ),
      ),
    );
  }
}

class _LineCoverageCard extends StatelessWidget {
  final _LineSummary line;
  final int totalStations;
  final VoidCallback onTap;

  const _LineCoverageCard({
    required this.line,
    required this.totalStations,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final color = _lineColor(line.name);
    final ratio = totalStations == 0 ? 0.0 : line.stationCount / totalStations;

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: InkWell(
        borderRadius: BorderRadius.circular(8),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 12,
                    height: 36,
                    decoration: BoxDecoration(
                      color: color,
                      borderRadius: BorderRadius.circular(6),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'Linha ${line.name}',
                      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
                    ),
                  ),
                  Text(
                    '${line.stationCount}',
                    style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800),
                  ),
                  const SizedBox(width: 8),
                  const Icon(Icons.chevron_right),
                ],
              ),
              const SizedBox(height: 12),
              LinearProgressIndicator(
                value: ratio.clamp(0.0, 1.0).toDouble(),
                minHeight: 8,
                color: color,
                backgroundColor: color.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(4),
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  _SmallStat(label: 'Esta\u00e7\u00f5es', value: '${line.stationCount}'),
                  _SmallStat(label: 'Correspond\u00eancias', value: '${line.transferCount}'),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SmallStat extends StatelessWidget {
  final String label;
  final String value;

  const _SmallStat({
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.04),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        child: Text(
          '$label: $value',
          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
        ),
      ),
    );
  }
}

class _LineMarkerButtons extends StatelessWidget {
  final List<String> lines;

  const _LineMarkerButtons({required this.lines});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: lines.length * 34.0,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: lines
            .map(
              (line) => Padding(
                padding: const EdgeInsets.only(right: 6),
                child: Tooltip(
                  message: 'Linha $line',
                  child: InkWell(
                    borderRadius: BorderRadius.circular(16),
                    onTap: () => _openLineStations(context, line),
                    child: Container(
                      width: 28,
                      height: 28,
                      decoration: BoxDecoration(
                        color: _lineColor(line),
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white, width: 2),
                        boxShadow: const [
                          BoxShadow(
                            color: Color(0x22000000),
                            blurRadius: 4,
                            offset: Offset(0, 1),
                          ),
                        ],
                      ),
                      child: const Icon(
                        Icons.device_hub,
                        color: Colors.white,
                        size: 15,
                      ),
                    ),
                  ),
                ),
              ),
            )
            .toList(),
      ),
    );
  }
}

class _TintedIcon extends StatelessWidget {
  final IconData icon;
  final Color color;

  const _TintedIcon({
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 38,
      height: 38,
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.11),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Icon(icon, color: color, size: 21),
    );
  }
}

class _EmptyInsightCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;

  const _EmptyInsightCard({
    required this.icon,
    required this.title,
    required this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: EdgeInsets.zero,
      child: ListTile(
        leading: _TintedIcon(icon: icon, color: Theme.of(context).colorScheme.primary),
        title: Text(title),
        subtitle: Text(subtitle),
      ),
    );
  }
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

void _openLineStations(BuildContext context, String line) {
  Navigator.of(context).push(
    MaterialPageRoute(
      builder: (_) => StationsListPage(initialLineKey: _lineKey(line)),
    ),
  );
}

_NearestStationResult? _nearestStationForLocation(LocationData location, List<Station> stations) {
  final latitude = location.latitude;
  final longitude = location.longitude;
  if (latitude == null || longitude == null) {
    return null;
  }

  _NearestStationResult? nearest;
  for (final station in stations) {
    if (!_hasValidCoordinates(station)) {
      continue;
    }

    final distance = DistanceCalculator.calculateDistance(
      latitude,
      longitude,
      station.latitude,
      station.longitude,
    );

    if (nearest == null || distance < nearest.distanceKm) {
      nearest = _NearestStationResult(
        station: station,
        distanceKm: distance,
      );
    }
  }

  return nearest;
}

String _lineKey(String line) => line.trim().toLowerCase();

bool _hasValidCoordinates(Station station) {
  return station.latitude != 0.0 && station.longitude != 0.0;
}

int _compareLineSummaries(_LineSummary a, _LineSummary b) {
  final rankDiff = _lineRank(a.name).compareTo(_lineRank(b.name));
  if (rankDiff != 0) return rankDiff;
  return a.name.compareTo(b.name);
}

int _lineRank(String lineName) {
  switch (_lineKey(lineName)) {
    case 'azul':
      return 0;
    case 'amarela':
      return 1;
    case 'verde':
      return 2;
    case 'vermelha':
      return 3;
    default:
      return 100;
  }
}

Color _lineColor(String lineName) {
  switch (_lineKey(lineName)) {
    case 'azul':
      return const Color(0xFF1565C0);
    case 'amarela':
      return const Color(0xFFF9A825);
    case 'verde':
      return const Color(0xFF2E7D32);
    case 'vermelha':
      return const Color(0xFFC62828);
    case 'rosa':
      return const Color(0xFFAD1457);
    case 'castanha':
      return const Color(0xFF6D4C41);
    default:
      return const Color(0xFF455A64);
  }
}
