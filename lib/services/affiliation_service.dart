import 'dart:convert';
import 'package:http/http.dart' as http;

class AffiliationService {
  static const String _gatewayBase = 'http://34.58.11.82:8082';
  static const bool enableLogging = true;


  static final Map<String, dynamic> _cache = {};

  static Future<Map<String, dynamic>?> _getCached(String path, String token) async {
    if (_cache.containsKey(path)) return _cache[path];
    try {
      final response = await http.get(
        Uri.parse('$_gatewayBase/$path'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      ).timeout(const Duration(seconds: 30));

      if (enableLogging) print('GET $path -> ${response.statusCode}');

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        _cache[path] = data;
        return data;
      }
      return null;
    } catch (e) {
      if (enableLogging) print('Affiliation fetch error ($path): $e');
      return null;
    }
  }


  static Future<Map<String, dynamic>?> getUniversity(String tid, String token) async {
    final data = await _getCached('unihub/universitymanagement/api/v1/get-university/$tid', token);
    if (data == null) return null;
    return {
      'id': data['university_id'] ?? data['uniId'] ?? data['id'],
      'name': data['university_name'] ?? data['universityName'] ?? data['name'],
      'logo_key': data['logo_key'] ?? data['university_logo'] ?? data['universityLogo'] ?? data['logoKey'],
    };
  }


  static Future<Map<String, dynamic>?> getCollege(String cid, String token) async {
    final data = await _getCached('unihub/universitymanagement/api/v1/colleges/public/get-college/$cid', token);
    if (data == null) return null;
    return {
      'id': data['college_id'] ?? data['collegeId'] ?? data['id'],
      'name': data['college_name'] ?? data['collegeName'] ?? data['name'],
      'campus': data['campus'] ?? data['college_campus'] ?? data['campus_name'] ?? '',
    };
  }


  static Future<List<int>?> getFileBytes(String fileKey, String token) async {
    try {
      final response = await http.get(
        Uri.parse('$_gatewayBase/unihub/s3/api/v1/get-file/$fileKey'),
        headers: {'Authorization': 'Bearer $token'},
      ).timeout(const Duration(seconds: 30));

      if (response.statusCode == 200) {
        return response.bodyBytes;
      }
      return null;
    } catch (e) {
      if (enableLogging) print('Logo fetch error: $e');
      return null;
    }
  }
}