import 'package:http/http.dart' as http;
import 'dart:convert';
import '../providers/auth_provider.dart';

class HttpClient {
  static AuthProvider? _authProvider;

  static void init(AuthProvider authProvider) {
    _authProvider = authProvider;
  }

  static Future<http.Response> request(
      String method,
      String url, {
        Map<String, String>? headers,
        dynamic body,
      }) async {
    String? token = _authProvider?.accessToken;

    final Map<String, String> finalHeaders = {
      'Content-Type': 'application/json',
      if (token != null) 'Authorization': 'Bearer $token',
      ...?headers,
    };

    http.Response response;
    try {
      switch (method.toUpperCase()) {
        case 'GET':
          response = await http.get(Uri.parse(url), headers: finalHeaders);
          break;
        case 'POST':
          response = await http.post(
            Uri.parse(url),
            headers: finalHeaders,
            body: body != null ? json.encode(body) : null,
          );
          break;
        case 'PUT':
          response = await http.put(
            Uri.parse(url),
            headers: finalHeaders,
            body: body != null ? json.encode(body) : null,
          );
          break;
        case 'DELETE':
          response = await http.delete(Uri.parse(url), headers: finalHeaders);
          break;
        default:
          throw Exception('Unsupported HTTP method: $method');
      }
    } catch (e) {
      rethrow;
    }

    if (response.statusCode == 401 && _authProvider != null) {
      final refreshed = await _authProvider!.refreshToken();

      if (refreshed) {
        final newToken = _authProvider!.accessToken;
        finalHeaders['Authorization'] = 'Bearer $newToken';

        switch (method.toUpperCase()) {
          case 'GET':
            response = await http.get(Uri.parse(url), headers: finalHeaders);
            break;
          case 'POST':
            response = await http.post(
              Uri.parse(url),
              headers: finalHeaders,
              body: body != null ? json.encode(body) : null,
            );
            break;
          case 'PUT':
            response = await http.put(
              Uri.parse(url),
              headers: finalHeaders,
              body: body != null ? json.encode(body) : null,
            );
            break;
          case 'DELETE':
            response = await http.delete(Uri.parse(url), headers: finalHeaders);
            break;
        }
      } else {
        await _authProvider!.logout();
      }
    }

    return response;
  }

  static Future<http.Response> get(String url, {Map<String, String>? headers}) {
    return request('GET', url, headers: headers);
  }

  static Future<http.Response> post(String url, {dynamic body, Map<String, String>? headers}) {
    return request('POST', url, headers: headers, body: body);
  }

  static Future<http.Response> put(String url, {dynamic body, Map<String, String>? headers}) {
    return request('PUT', url, headers: headers, body: body);
  }

  static Future<http.Response> delete(String url, {Map<String, String>? headers}) {
    return request('DELETE', url, headers: headers);
  }
}