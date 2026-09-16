import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:location/location.dart';
import 'package:provider/provider.dart';
import 'package:cmproject/connectivity_module.dart';
import 'package:cmproject/data/http_metro_datasource.dart';
import 'package:cmproject/data/metro_datasource.dart';
import 'package:cmproject/data/sqflite_metro_datasource.dart';
import 'package:cmproject/models/station.dart';
import 'package:cmproject/data/distance_calculator.dart';
import 'package:cmproject/data/location_service.dart';

class StationDetailPage extends StatelessWidget {
  final Station station;

  const StationDetailPage({
    super.key,
    required this.station,
  });

  @override
  Widget build(BuildContext context) {
    final lineStatus = _buildLineStatusPlaceholder(station);

    return Scaffold(
      key: const Key('detail-screen'),
      appBar: AppBar(
        title: Text(station.name),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        station.name,
                        style: const TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text('Linha ${station.lineName}',
                        style: const TextStyle(fontSize: 16)),
                      const SizedBox(height: 6),
                      Text('Latitude: ${station.latitude.toStringAsFixed(4)}'),
                      Text('Longitude: ${station.longitude.toStringAsFixed(4)}'),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Card(
                child: Column(
                  children: [
                    // Distância calculada em tempo real
                    _buildDistanceCard(context),
                    ListTile(
                      leading: const Icon(Icons.traffic),
                      title: const Text('Estado da linha'),
                      subtitle: Text(lineStatus),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              const Text(
                'Tempos de espera:',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              _buildWaitingTimesList(context),
              const SizedBox(height: 16),
              const Text(
                'Incidentes',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              SizedBox(
                height: 250,
                child: _buildIncidentsList(),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Widget que mostra os tempos de espera vindos da API
  Widget _buildWaitingTimesList(BuildContext context) {
    final dataSource = _readMetroDataSource(context);

    if (dataSource == null) {
      return _buildRealtimeUnavailableCard(context);
    }

    return FutureBuilder<List<WaitingTime>>(
      future: dataSource.getWaitingTimesByStation(station.id),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Card(
            child: ListTile(
              leading: SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
              title: Text('A carregar tempos de espera...'),
            ),
          );
        }

        if (snapshot.hasError) {
          return _buildRealtimeUnavailableCard(context);
        }

        final waitingTimes = snapshot.data ?? const [];
        if (waitingTimes.isEmpty) {
          return const Card(
            child: ListTile(
              title: Text('Sem tempos de espera disponiveis'),
            ),
          );
        }

        return Card(
          child: ListView.separated(
            key: const Key('detail-screen-waiting-times-list'),
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: waitingTimes.length,
            separatorBuilder: (context, index) => const Divider(height: 1),
            itemBuilder: (context, index) {
              final waitingTime = waitingTimes[index];
              return ListTile(
                title: Text(waitingTime.platform),
                trailing: Text('${waitingTime.seconds}s'),
              );
            },
          ),
        );
      },
    );
  }

  MetroDataSource? _readMetroDataSource(BuildContext context) {
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

  Widget _buildRealtimeUnavailableCard(BuildContext context) {
    return FutureBuilder<String>(
      future: _buildRealtimeUnavailableMessage(context),
      builder: (context, snapshot) {
        return Card(
          child: ListTile(
            leading: const Icon(Icons.wifi_off),
            title: const Text('Tempos de espera indisponiveis'),
            subtitle: Text(snapshot.data ?? 'Nao foi possivel obter dados em tempo real.'),
          ),
        );
      },
    );
  }

  Future<String> _buildRealtimeUnavailableMessage(BuildContext context) async {
    var isOnline = true;
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

    try {
      isOnline = connectivity == null ? true : await connectivity.checkConnectivity();
    } catch (_) {
      isOnline = true;
    }

    DateTime? lastUpdate;
    if (local != null && local.runtimeType == SqfliteMetroDataSource) {
      try {
        lastUpdate = await local.getLastStationsUpdate();
      } catch (_) {
        lastUpdate = null;
      }
    }

    final prefix = isOnline
        ? 'Nao foi possivel obter dados em tempo real.'
        : 'Sem ligacao. Os tempos de espera precisam de internet.';

    if (lastUpdate == null) {
      return '$prefix A mostrar dados guardados anteriormente.';
    }

    final formatted = DateFormat('dd/MM/yyyy HH:mm').format(lastUpdate);
    return '$prefix Dados das estacoes atualizados pela ultima vez em $formatted.';
  }

  Widget _buildDistanceCard(BuildContext context) {
    try {
      final locationService = Provider.of<LocationService>(context);

      return StreamBuilder<LocationData>(
        stream: locationService.onLocationChanged().timeout(
          const Duration(seconds: 10),
          onTimeout: (sink) {
            sink.addError('Timeout ao obter localização');
            sink.close();
          },
        ),
        builder: (context, snapshot) {
          // Se a conexão está waiting (> 2 segundos), mostra mensagem
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const ListTile(
              leading: Icon(Icons.directions_walk),
              title: Text('Distância'),
              subtitle: Text('Obtendo localização...'),
            );
          }

          if (snapshot.hasError) {
            return ListTile(
              leading: const Icon(Icons.directions_walk),
              title: const Text('Distância'),
              subtitle: Text('Localização não disponível'),
            );
          }

          if (!snapshot.hasData || snapshot.data == null) {
            return const ListTile(
              leading: Icon(Icons.directions_walk),
              title: Text('Distância'),
              subtitle: Text('Localização não disponível'),
            );
          }

          final location = snapshot.data!;
          final distance = DistanceCalculator.calculateDistance(
            location.latitude ?? 0.0,
            location.longitude ?? 0.0,
            station.latitude,
            station.longitude,
          );
          final formattedDistance = DistanceCalculator.formatDistance(distance);

          return ListTile(
            leading: const Icon(Icons.directions_walk),
            title: const Text('Distância'),
            subtitle: Text(formattedDistance),
          );
        },
      );
    } catch (_) {
      // Se LocationService não está registrado no Provider, mostra erro
      return const ListTile(
        leading: Icon(Icons.directions_walk),
        title: Text('Distância'),
        subtitle: Text('Serviço não configurado'),
      );
    }
  }

  /// Widget que lista os incidentes da estação
  Widget _buildIncidentsList() {
    final dateFormat = DateFormat('dd/MM/yyyy HH:mm');

    if (station.reports.isEmpty) {
      return const Center(
        child: Text('Sem incidentes'),
      );
    }

    return ListView.builder(
      key: const Key('detail-screen-incidents-list'),
      itemCount: station.reports.length,
      itemBuilder: (context, index) {
        final report = station.reports[index];

        return Card(
          child: ListTile(
            title: Text(report.type.displayName),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(dateFormat.format(report.timestamp)),
                Text(report.notes ?? 'Sem comentários'),
              ],
            ),
            trailing: Text(report.rate.toString()),
          ),
        );
      },
    );
  }

  String _buildLineStatusPlaceholder(Station station) {
    if (station.reports.isNotEmpty) {
      return 'Atenção a incidentes reportados';
    }
    return 'Operação normal';
  }
}
