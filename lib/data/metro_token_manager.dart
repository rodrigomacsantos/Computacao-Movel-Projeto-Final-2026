import 'dart:convert';
import 'dart:io';

import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;
import 'package:http/io_client.dart';

/// Simple token manager for Metro API using OAuth2 client_credentials
///
/// It reads `METRO_CLIENT_KEY` and `METRO_CLIENT_SECRET` from environment
/// by default. Call `getToken()` to obtain a valid access token; the manager
/// caches it in memory until shortly before expiry.
class MetroTokenManager {
  final String tokenUrl;
  final String? clientKey;
  final String? clientSecret;

  String? _token;
  DateTime? _expiry;
  http.Client? _client;

  MetroTokenManager({String? tokenUrl, this.clientKey, this.clientSecret})
      : tokenUrl = tokenUrl ?? 'https://api.metrolisboa.pt:8243/token';

  Future<void> _fetchToken() async {
    final key = clientKey ?? dotenv.env['METRO_CLIENT_KEY'] ?? Platform.environment['METRO_CLIENT_KEY'];
    final secret = clientSecret ?? dotenv.env['METRO_CLIENT_SECRET'] ?? Platform.environment['METRO_CLIENT_SECRET'];
    if (key == null || secret == null) {
      throw Exception('Metro API client credentials not provided');
    }

    final auth = base64.encode(utf8.encode('$key:$secret'));

    final res = await _httpClient.post(
      Uri.parse(tokenUrl),
      headers: {
        'Authorization': 'Basic $auth',
        'Content-Type': 'application/x-www-form-urlencoded'
      },
      body: 'grant_type=client_credentials',
    );

    if (res.statusCode < 200 || res.statusCode >= 300) {
      throw HttpException('Token endpoint returned ${res.statusCode}: ${res.body}');
    }

    final json = jsonDecode(res.body) as Map<String, dynamic>;
    _token = json['access_token']?.toString();
    final expiresIn = int.tryParse(json['expires_in']?.toString() ?? '') ?? 3600;
    _expiry = DateTime.now().add(Duration(seconds: expiresIn));
  }

  /// Returns a valid access token, refreshing it when necessary.
  Future<String> getToken() async {
    if (_token != null && _expiry != null) {
      // refresh slightly before expiry to avoid races
      if (DateTime.now().isBefore(_expiry!.subtract(const Duration(seconds: 30)))) {
        return _token!;
      }
    }

    await _fetchToken();
    if (_token == null) throw Exception('Failed to obtain access token');
    return _token!;
  }

  http.Client get _httpClient {
    final existing = _client;
    if (existing != null) return existing;

    final httpClient = HttpClient()
      ..badCertificateCallback = (X509Certificate cert, String host, int port) {
        return host == 'api.metrolisboa.pt' || host.endsWith('.metrolisboa.pt');
      };

    _client = IOClient(httpClient);
    return _client!;
  }
}


