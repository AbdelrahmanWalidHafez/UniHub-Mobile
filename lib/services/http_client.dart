import 'dart:async';
import 'dart:io';
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

    Map<String, String> finalHeaders = {
      'Content-Type': 'application/json',
      if (token != null) 'Authorization': 'Bearer $token',
      ...?headers,
    };

    http.Response response;

    try {
      response = await _executeRequest(method, url, finalHeaders, body);
    } on TimeoutException {
      throw Exception('Connection timed out. Please try again.');
    } on SocketException {
      throw Exception('No internet connection.');
    } catch (e) {
      rethrow;
    }

    // Handle 401 — try token refresh once
    if (response.statusCode == 401 && _authProvider != null) {
      final refreshed = await _authProvider!.refreshToken();

      if (refreshed) {
        final newToken = _authProvider!.accessToken;
        finalHeaders = {
          ...finalHeaders,
          if (newToken != null) 'Authorization': 'Bearer $newToken',
        };

        try {
          response = await _executeRequest(method, url, finalHeaders, body);
        } on TimeoutException {
          throw Exception('Connection timed out. Please try again.');
        } on SocketException {
          throw Exception('No internet connection.');
        }
      } else {

        await _authProvider!.logout();
      }
    }

    return response;
  }


  static Future<http.Response> _executeRequest(
      String method,
      String url,
      Map<String, String> headers,
      dynamic body,
      ) async {
    final uri = Uri.parse(url);
    final encodedBody = body != null ? json.encode(body) : null;

    switch (method.toUpperCase()) {
      case 'GET':
        return await http
            .get(uri, headers: headers)
            .timeout(const Duration(seconds: 30));
      case 'POST':
        return await http
            .post(uri, headers: headers, body: encodedBody)
            .timeout(const Duration(seconds: 30));
      case 'PUT':
        return await http
            .put(uri, headers: headers, body: encodedBody)
            .timeout(const Duration(seconds: 30));
      case 'PATCH':
        return await http
            .patch(uri, headers: headers, body: encodedBody)
            .timeout(const Duration(seconds: 30));
      case 'DELETE':
        return await http
            .delete(uri, headers: headers)
            .timeout(const Duration(seconds: 30));
      default:
        throw Exception('Unsupported HTTP method: $method');
    }
  }


  static Future<http.Response> get(String url,
      {Map<String, String>? headers}) {
    return request('GET', url, headers: headers);
  }

  static Future<http.Response> post(String url,
      {dynamic body, Map<String, String>? headers}) {
    return request('POST', url, headers: headers, body: body);
  }

  static Future<http.Response> put(String url,
      {dynamic body, Map<String, String>? headers}) {
    return request('PUT', url, headers: headers, body: body);
  }

  static Future<http.Response> patch(String url,
      {dynamic body, Map<String, String>? headers}) {
    return request('PATCH', url, headers: headers, body: body);
  }

  static Future<http.Response> delete(String url,
      {Map<String, String>? headers}) {
    return request('DELETE', url, headers: headers);
  }
}