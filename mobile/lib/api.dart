import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;

const apiBaseUrl = String.fromEnvironment(
  'API_BASE_URL',
  defaultValue: 'http://10.0.2.2:8000/api',
);

class ApiException implements Exception {
  ApiException(this.message);
  final String message;
  @override
  String toString() => message;
}

class Api {
  Api(this.token);
  String? token;

  Future<Map<String, dynamic>> get(String path) => _request('GET', path);
  Future<Map<String, dynamic>> post(String path, Map<String, dynamic> body) =>
      _request('POST', path, body);
  Future<Map<String, dynamic>> put(String path, Map<String, dynamic> body) =>
      _request('PUT', path, body);
  Future<Map<String, dynamic>> delete(String path, Map<String, dynamic> body) =>
      _request('DELETE', path, body);

  Future<Map<String, dynamic>> _request(
    String method,
    String path, [
    Map<String, dynamic>? body,
  ]) async {
    final attempts = method == 'GET' || method == 'PUT' ? 2 : 1;
    for (var attempt = 0; attempt < attempts; attempt++) {
      final request = http.Request(method, Uri.parse('$apiBaseUrl$path'));
      request.headers['Accept'] = 'application/json';
      request.headers['Content-Type'] = 'application/json';
      if (token != null) request.headers['Authorization'] = 'Bearer $token';
      if (body != null) request.body = jsonEncode(body);
      final client = http.Client();
      try {
        final response = await client
            .send(request)
            .timeout(const Duration(seconds: 15));
        final text = await response.stream.bytesToString();
        final data = text.isEmpty ? <String, dynamic>{} : jsonDecode(text);
        if (response.statusCode >= 400) {
          final map = data is Map<String, dynamic> ? data : <String, dynamic>{};
          final errors = map['errors'];
          final firstError = errors is Map && errors.isNotEmpty
              ? (errors.values.first as List).first.toString()
              : null;
          throw ApiException(
            firstError ?? map['message']?.toString() ?? 'Request failed',
          );
        }
        return data is Map<String, dynamic> ? data : <String, dynamic>{};
      } on ApiException {
        rethrow;
      } on TimeoutException catch (_) {
        if (attempt + 1 == attempts) {
          throw ApiException('Connection timed out. Please try again.');
        }
      } on SocketException catch (_) {
        if (attempt + 1 == attempts) {
          throw ApiException(
            'Connection problem. Check your internet and try again.',
          );
        }
      } on http.ClientException catch (_) {
        if (attempt + 1 == attempts) {
          throw ApiException(
            'Connection problem. Check your internet and try again.',
          );
        }
      } on FormatException catch (_) {
        throw ApiException(
          'The server returned an invalid response. Please try again.',
        );
      } finally {
        client.close();
      }
      await Future<void>.delayed(const Duration(milliseconds: 400));
    }
    throw ApiException(
      'Connection problem. Check your internet and try again.',
    );
  }

  Stream<Map<String, dynamic>> snapshots() async* {
    final client = http.Client();
    try {
      final request = http.Request('GET', Uri.parse('$apiBaseUrl/stream'));
      request.headers['Accept'] = 'text/event-stream';
      request.headers['Authorization'] = 'Bearer $token';
      final response = await client.send(request);
      if (response.statusCode != 200) {
        throw ApiException('Live updates unavailable');
      }
      await for (final line
          in response.stream
              .transform(utf8.decoder)
              .transform(const LineSplitter())) {
        if (line.startsWith('data: ')) {
          final data = jsonDecode(line.substring(6));
          if (data is Map<String, dynamic>) yield data;
        }
      }
    } finally {
      client.close();
    }
  }
}
