import 'dart:convert';
import 'dart:io';

import 'package:cmproject/data/metro_datasource.dart';
import 'package:cmproject/data/metro_token_manager.dart';
import 'package:cmproject/models/incident_report.dart';
import 'package:cmproject/models/station.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;
import 'package:http/io_client.dart';

class HttpMetroDataSource extends MetroDataSource {
  // Use HTTPS with port 8243 (the API gateway typically serves TLS on this port).
  // Previous use of plain HTTP caused connection resets by peer on that port.
  static const String _baseUrl = 'https://api.metrolisboa.pt:8243/estadoServicoML/1.0.1';

  final MetroTokenManager _tokenManager = MetroTokenManager();

  Future<Map<String, String>> _buildHeaders() async {
    final headers = <String, String>{'Accept': 'application/json'};

    final manualToken = dotenv.env['METRO_API_TOKEN'] ?? Platform.environment['METRO_API_TOKEN'];
    if (manualToken != null && manualToken.isNotEmpty) {
      headers['Authorization'] = 'Bearer $manualToken';
      return headers;
    }

    final clientKey = dotenv.env['METRO_CLIENT_KEY'] ?? Platform.environment['METRO_CLIENT_KEY'];
    final clientSecret = dotenv.env['METRO_CLIENT_SECRET'] ?? Platform.environment['METRO_CLIENT_SECRET'];
    if (clientKey != null && clientSecret != null && clientKey.isNotEmpty && clientSecret.isNotEmpty) {
      final token = await _tokenManager.getToken();
      headers['Authorization'] = 'Bearer $token';
    }

    return headers;
  }

  Future<dynamic> _getJson(String path) async {
    final response = await _httpClient.get(
      Uri.parse('$_baseUrl$path'),
      headers: await _buildHeaders(),
    );

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw HttpException('GET $path failed with ${response.statusCode}: ${response.body}');
    }

    return jsonDecode(response.body);
  }

  List<String> _parseListField(dynamic value) {
    if (value == null) return const [];
    if (value is List) {
      return value.map((e) => e.toString().trim()).where((e) => e.isNotEmpty).toList();
    }

    final text = value.toString().trim();
    if (text.isEmpty) return const [];
    if (text.startsWith('[') && text.endsWith(']')) {
      return text.substring(1, text.length - 1).split(',').map((e) => e.trim()).where((e) => e.isNotEmpty).toList();
    }
    return [text];
  }

  String _pickString(Map<String, dynamic> map, List<String> keys) {
    for (final key in keys) {
      final value = map[key];
      if (value != null) return value.toString();
    }
    return '';
  }

  double _pickDouble(Map<String, dynamic> map, List<String> keys) {
    for (final key in keys) {
      final value = map[key];
      if (value == null) continue;
      if (value is num) return value.toDouble();
      final parsed = double.tryParse(value.toString().replaceAll(',', '.'));
      if (parsed != null) return parsed;
    }
    return 0.0;
  }

  Station _stationFromApiJson(dynamic json) {
    final map = Map<String, dynamic>.from(json as Map);

    final id = _pickString(map, ['stop_id', 'EstacaoID', 'ID', 'Id', 'Codigo', 'CodigoEstacao', 'Codigo_Estacao']);
    final name = _pickString(map, ['stop_name', 'EstacaoNome', 'Nome', 'Name', 'Descricao', 'Estacao']);
    final lat = _pickDouble(map, ['stop_lat', 'Latitude', 'Lat', 'latitude', 'lat', 'LatitudeWGS84']);
    final lon = _pickDouble(map, ['stop_lon', 'Longitude', 'Lon', 'longitude', 'lng', 'LongitudeWGS84']);

    List<String> lines = const [];
    if (map['linha'] != null) {
      lines = _parseListField(map['linha']);
    } else if (map['Linhas'] != null) {
      lines = _parseListField(map['Linhas']);
    }
    final lineName = lines.isNotEmpty ? lines.join('/') : 'Desconhecida';
    final zoneId = _pickString(map, ['zone_id', 'Zona', 'zona']);
    final officialUrls = <String>[];
    final urlRaw = map['stop_url'] ?? map['url'] ?? map['URL'];
    if (urlRaw != null) {
      officialUrls.addAll(_parseListField(urlRaw));
    }

    return Station(
      id: id.isNotEmpty ? id : name,
      name: name.isNotEmpty ? name : id,
      latitude: lat,
      longitude: lon,
      lineName: lineName,
      zoneId: zoneId.isEmpty ? null : zoneId,
      officialUrls: officialUrls,
      reports: const [],
    );
  }

  WaitingTime _waitingTimeFromApiJson(dynamic json) {
    final map = Map<String, dynamic>.from(json as Map);

    final platform = (map['cais'] ?? 'Cais').toString();
    final seconds = int.tryParse((map['tempoChegada1'] ?? '0').toString()) ?? 0;

    return WaitingTime(
      platform: platform,
      seconds: seconds,
    );
  }

  @override
  Future<void> insertStation(Station station) async {
    throw UnimplementedError('insertStation via HTTP is not supported');
  }

  @override
  Future<List<Station>> getAllStations() async {
    final json = await _getJson('/infoEstacao/todos');

    final items = <dynamic>[];
    if (json is Map<String, dynamic>) {
      final responseList = json['resposta'];
      if (responseList is List) {
        items.addAll(responseList);
      }
    } else if (json is List) {
      items.addAll(json);
    }

    return items.map((item) => _stationFromApiJson(item)).toList();
  }

  @override
  Future<List<Station>> getStationsByName(String name) async {
    final all = await getAllStations();
    final query = name.toLowerCase();
    return all.where((station) => station.name.toLowerCase().contains(query)).toList();
  }

  @override
  Future<Station> getStationDetail(String id) async {
    final all = await getAllStations();
    return all.firstWhere(
      (station) => station.id == id || station.name.toLowerCase() == id.toLowerCase(),
      orElse: () => throw Exception('Station with id $id not found'),
    );
  }

  @override
  Future<void> attachIncident(String id, IncidentReport report) async {
    throw UnimplementedError('attachIncident via HTTP is not supported');
  }

  @override
  Future<List<WaitingTime>> getWaitingTimesByStation(String stationId) async {
    final json = await _getJson('/tempoEspera/Estacao/$stationId');

    final items = <dynamic>[];
    if (json is Map<String, dynamic>) {
      final responseList = json['resposta'];
      if (responseList is List) {
        items.addAll(responseList);
      } else if (responseList is Map) {
        items.add(responseList);
      }
    } else if (json is List) {
      items.addAll(json);
    }

    return items.map((item) => _waitingTimeFromApiJson(item)).toList();
  }

  http.Client get _httpClient {
    // Create an HttpClient that accepts the server certificate. The professor
    // requested disabling certificate verification for this project, so we
    // return true unconditionally here (combined with the global override in
    // `main.dart` this ensures TLS handshake won't fail due to untrusted CA).
    final httpClient = HttpClient()..badCertificateCallback = (X509Certificate cert, String host, int port) => true;
    return IOClient(httpClient);
  }
}
