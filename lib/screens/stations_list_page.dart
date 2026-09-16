import 'package:cmproject/connectivity_module.dart';
import 'package:cmproject/data/http_metro_datasource.dart';
import 'package:cmproject/data/metro_datasource.dart';
import 'package:cmproject/data/metro_repository.dart';
import 'package:cmproject/data/sqflite_metro_datasource.dart';
import 'package:cmproject/models/station.dart';
import 'package:cmproject/screens/station_detail_page.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

class StationsListPage extends StatefulWidget {
  final String? initialLineKey;

  const StationsListPage({
    super.key,
    this.initialLineKey,
  });

  @override
  State<StationsListPage> createState() => _StationsListPageState();
}

class _StationsListPageState extends State<StationsListPage> {
  static const _noStationsError =
      'Não foi possível obter as estações de metro. Verifique a conectividade e volte a tentar';

  String _searchText = '';
  String? _selectedLineKey;
  List<Station>? _asyncStations;
  bool _loading = true;
  bool _initialized = false;
  String? _offlineError;
  Future<void>? _loadFuture;

  @override
  void initState() {
    super.initState();
    _selectedLineKey = widget.initialLineKey;
  }

  @override
  Widget build(BuildContext context) {
    final metroRepository = Provider.of<MetroRepository>(context);
    final stations = _asyncStations ?? metroRepository.getAllStations();
    final lineOptions = _lineOptionsFromStations(stations);
    final selectedLineName = _lineNameForKey(lineOptions, _selectedLineKey);
    final filteredStations = stations.where((station) {
      final matchesName = station.name.toLowerCase().contains(_searchText.toLowerCase());
      final matchesLine = _selectedLineKey == null || _stationLineKeys(station).contains(_selectedLineKey);
      return matchesName && matchesLine;
    }).toList();

    return Scaffold(
      key: const Key('list-screen'),
      appBar: AppBar(
        title: Text(selectedLineName == null ? 'Estacoes' : 'Linha $selectedLineName'),
      ),
      body: FutureBuilder<void>(
        future: _loadFuture,
        builder: (context, snapshot) {
          if (_loading || snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (stations.isEmpty) {
            return Center(
              child: Text(
                _offlineError ?? 'Sem estacoes disponiveis',
                textAlign: TextAlign.center,
              ),
            );
          }

          return Column(
            children: [
              if (_offlineError != null)
                Padding(
                  padding: const EdgeInsets.fromLTRB(12, 12, 12, 0),
                  child: Text(
                    _offlineError!,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.error,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 12, 12, 4),
                child: TextField(
                  key: const Key('stations-search-field'),
                  decoration: const InputDecoration(
                    labelText: 'Pesquisar estacao',
                    prefixIcon: Icon(Icons.search),
                  ),
                  onChanged: (value) {
                    setState(() {
                      _searchText = value;
                    });
                  },
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 4, 12, 4),
                child: _LineFilterBar(
                  lineOptions: lineOptions,
                  selectedLineKey: _selectedLineKey,
                  onSelected: (lineKey) {
                    setState(() {
                      _selectedLineKey = lineKey;
                    });
                  },
                ),
              ),
              Expanded(
                child: filteredStations.isEmpty
                    ? const Center(
                        child: Text('Nenhuma estacao encontrada'),
                      )
                    : ListView.separated(
                        padding: const EdgeInsets.all(12),
                        key: const Key('list-view'),
                        itemCount: filteredStations.length,
                        separatorBuilder: (context, index) => const SizedBox(height: 4),
                        itemBuilder: (context, index) {
                          final station = filteredStations[index];

                          return Card(
                            child: ListTile(
                              leading: const Icon(Icons.train),
                              title: Text(station.name),
                              subtitle: Text('Linha ${station.lineName}'),
                              trailing: Text('${station.reports.length} incidentes'),
                              onTap: () {
                                Navigator.of(context).push(
                                  MaterialPageRoute(
                                    builder: (_) => StationDetailPage(station: station),
                                  ),
                                );
                              },
                            ),
                          );
                        },
                      ),
              ),
            ],
          );
        },
      ),
    );
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_initialized) {
      _initialized = true;
      setState(() {
        _loading = true;
      });
      _loadFuture = _tryLoadRemoteStations();
    }
  }

  Future<void> _tryLoadRemoteStations() async {
    final repo = Provider.of<MetroRepository>(context, listen: false);
    final local = _readLocalDataSource();
    final connectivity = _readConnectivityModule();
    final remote = _readRemoteDataSource();
    final isOnline = connectivity == null ? true : await connectivity.checkConnectivity();

    if (!isOnline) {
      final localStations = await _loadLocalStations(repo, local);
      final lastUpdate = await _getLastLocalUpdate(local);
      if (mounted) {
        setState(() {
          _asyncStations = localStations;
          _offlineError = localStations.isEmpty ? _noStationsError : _buildCachedDataMessage(lastUpdate);
          _loading = false;
        });
      }
      return;
    }

    if (remote == null) {
      if (mounted) {
        setState(() {
          _asyncStations = repo.getAllStations();
          _loading = false;
        });
      }
      return;
    }

    try {
      final stations = await remote.getAllStations() as List<Station>;
      for (final station in stations) {
        repo.insertStation(station);
        await local?.insertStation(station);
      }

      if (mounted) {
        setState(() {
          _asyncStations = repo.getAllStations();
          _offlineError = null;
          _loading = false;
        });
      }
    } catch (_) {
      final localStations = await _loadLocalStations(repo, local);
      final lastUpdate = await _getLastLocalUpdate(local);
      if (mounted) {
        setState(() {
          _offlineError = localStations.isEmpty ? _noStationsError : _buildCachedDataMessage(lastUpdate);
          _asyncStations = localStations;
          _loading = false;
        });
      }
    }
  }

  ConnectivityModule? _readConnectivityModule() {
    try {
      return Provider.of<ConnectivityModule>(context, listen: false);
    } catch (_) {
      return null;
    }
  }

  dynamic _readRemoteDataSource() {
    try {
      return Provider.of<MetroDataSource>(context, listen: false);
    } catch (_) {
      try {
        return Provider.of<HttpMetroDataSource>(context, listen: false);
      } catch (_) {
        return null;
      }
    }
  }

  SqfliteMetroDataSource? _readLocalDataSource() {
    try {
      return Provider.of<SqfliteMetroDataSource>(context, listen: false);
    } catch (_) {
      return null;
    }
  }


  Future<List<Station>> _loadLocalStations(
    MetroRepository repo,
    SqfliteMetroDataSource? local,
  ) async {
    if (local == null) {
      return repo.getAllStations();
    }

    try {
      final stations = await local.getAllStations();
      for (final station in stations) {
        repo.insertStation(station);
      }
      return repo.getAllStations();
    } catch (_) {
      return repo.getAllStations();
    }
  }

  Future<DateTime?> _getLastLocalUpdate(SqfliteMetroDataSource? local) async {
    if (local == null || local.runtimeType != SqfliteMetroDataSource) {
      return null;
    }

    try {
      return local.getLastStationsUpdate();
    } catch (_) {
      return null;
    }
  }

  String _buildCachedDataMessage(DateTime? lastUpdate) {
    if (lastUpdate == null) {
      return 'Sem ligacao. A mostrar dados guardados anteriormente.';
    }

    final formatted = DateFormat('dd/MM/yyyy HH:mm').format(lastUpdate);
    return 'Sem ligacao. A mostrar dados guardados da ultima atualizacao: $formatted.';
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

String? _lineNameForKey(List<_LineOption> lineOptions, String? lineKey) {
  if (lineKey == null) {
    return null;
  }

  for (final option in lineOptions) {
    if (option.key == lineKey) {
      return option.name;
    }
  }

  return null;
}
