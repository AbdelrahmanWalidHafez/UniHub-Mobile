import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';
import '../models/classroom/classroom_model.dart';
import '../models/classroom/material_model.dart';
import '../models/classroom/comment_model.dart';
import '../models/classroom/submission_model.dart';
import 'token_service.dart';

class ClassroomService {
  static const String _gatewayUrl = 'http://34.58.11.82:8082';
  static const bool enableLogging = true;

  static Future<Map<String, String>> _authHeaders() async {
    final accessToken = await TokenService.getAccessToken();
    final userData = await TokenService.getUserData();

    final headers = {
      'Content-Type': 'application/json',
      if (accessToken != null) 'Authorization': 'Bearer $accessToken',
    };

    if (userData != null) {
      final university = userData['university'];
      if (university != null) {
        if (university['uid'] != null) {
          headers['X-User-University-Id'] = university['uid'].toString();
        }
        if (university['cid'] != null) {
          headers['X-User-College-Id'] = university['cid'].toString();
        }
      }
      if (userData['email'] != null) {
        headers['X-User-Email'] = userData['email'].toString();
      }
    }

    return headers;
  }

  static Future<String?> _getToken() async {
    return await TokenService.getAccessToken();
  }

  // ==================== CLASSROOM ENDPOINTS ====================

  static Future<Classroom> createClassroom(
      String classTitle, String classSubTitle) async {
    try {
      final headers = await _authHeaders();
      final url = Uri.parse(
          '$_gatewayUrl/unihub/classroom/api/v1/classroom/instructor/create');

      if (enableLogging) print('POST create classroom URL: $url');

      final response = await http
          .post(
        url,
        headers: headers,
        body: json.encode({
          'class_title': classTitle,
          'class_sub_title': classSubTitle,
        }),
      )
          .timeout(const Duration(seconds: 30));

      if (enableLogging) {
        print('Create classroom status: ${response.statusCode}');
        print('Create classroom response: ${response.body}');
      }

      if (response.statusCode == 201 || response.statusCode == 200) {
        // Backend returns ClassRoomResponse — map it to Classroom
        final Map<String, dynamic> data = json.decode(response.body);
        return Classroom.fromJson(data);
      } else {
        throw Exception(
            'Failed to create classroom (${response.statusCode}): ${response.body}');
      }
    } catch (e) {
      if (enableLogging) print('Create classroom error: $e');
      rethrow;
    }
  }

  static Future<List<Classroom>> getEnrolledClasses() async {
    try {
      final headers = await _authHeaders();
      final url = Uri.parse('$_gatewayUrl/unihub/classroom/api/v1/classroom/get-enrolled-classes');

      if (enableLogging) print('GET enrolled classes URL: $url');

      final response = await http.get(url, headers: headers).timeout(const Duration(seconds: 30));

      if (enableLogging) print('Get enrolled classes status: ${response.statusCode}');

      if (response.statusCode == 200) {
        final Map<String, dynamic> data = json.decode(response.body);
        final List<dynamic> classrooms = data['class_rooms'] ?? [];
        return classrooms.map((j) => Classroom.fromJson(j)).toList();
      }
      return [];
    } catch (e) {
      if (enableLogging) print('Get enrolled classes error: $e');
      return [];
    }
  }

  static Future<List<Classroom>> getActiveClasses() async {
    try {
      final headers = await _authHeaders();
      final url = Uri.parse('$_gatewayUrl/unihub/classroom/api/v1/classroom/instructor/get-active-classes');

      final response = await http.get(url, headers: headers).timeout(const Duration(seconds: 30));

      if (enableLogging) print('Get active classes status: ${response.statusCode}');

      if (response.statusCode == 200) {
        final Map<String, dynamic> data = json.decode(response.body);
        final List<dynamic> classrooms = data['class_rooms'] ?? [];
        return classrooms.map((j) => Classroom.fromJson(j)).toList();
      }
      return [];
    } catch (e) {
      if (enableLogging) print('Get active classes error: $e');
      return [];
    }
  }

  static Future<List<Classroom>> getArchivedClasses() async {
    try {
      final headers = await _authHeaders();
      final url = Uri.parse('$_gatewayUrl/unihub/classroom/api/v1/classroom/instructor/get-archived-classes');

      final response = await http.get(url, headers: headers).timeout(const Duration(seconds: 30));

      if (enableLogging) print('Get archived classes status: ${response.statusCode}');

      if (response.statusCode == 200) {
        final Map<String, dynamic> data = json.decode(response.body);
        final List<dynamic> classrooms = data['class_rooms'] ?? [];
        return classrooms.map((j) => Classroom.fromJson(j)).toList();
      }
      return [];
    } catch (e) {
      if (enableLogging) print('Get archived classes error: $e');
      return [];
    }
  }

  static Future<Member> joinClassroom(String code) async {
    try {
      final headers = await _authHeaders();
      final url = Uri.parse('$_gatewayUrl/unihub/classroom/api/v1/classroom/join?code=${Uri.encodeComponent(code)}');

      if (enableLogging) print('Join classroom URL: $url');

      final response = await http.post(url, headers: headers).timeout(const Duration(seconds: 30));

      if (enableLogging) {
        print('Join classroom status: ${response.statusCode}');
        print('Join classroom response: ${response.body}');
      }

      if (response.statusCode == 201 || response.statusCode == 200) {
        return Member.fromJson(json.decode(response.body));
      } else if (response.statusCode == 400) {
        throw Exception('You are already a member of this class.');
      } else if (response.statusCode == 404) {
        throw Exception('Invalid class code. Please check and try again.');
      } else {
        throw Exception('Failed to join classroom (${response.statusCode})');
      }
    } catch (e) {
      if (enableLogging) print('Join classroom error: $e');
      rethrow;
    }
  }

  static Future<void> leaveClassroom(String classroomId) async {
    try {
      final headers = await _authHeaders();
      final response = await http.delete(
        Uri.parse('$_gatewayUrl/unihub/classroom/api/v1/classroom/leave/$classroomId'),
        headers: headers,
      ).timeout(const Duration(seconds: 30));

      if (enableLogging) print('Leave classroom status: ${response.statusCode}');

      if (response.statusCode != 204 && response.statusCode != 200) {
        throw Exception('Failed to leave classroom');
      }
    } catch (e) {
      if (enableLogging) print('Leave classroom error: $e');
      rethrow;
    }
  }

  static Future<List<Member>> getMembers(String classroomId, {int pageNum = 1}) async {
    try {
      final headers = await _authHeaders();
      final response = await http.get(
        Uri.parse('$_gatewayUrl/unihub/classroom/api/v1/classroom/get-members/$classroomId?page_num=$pageNum'),
        headers: headers,
      ).timeout(const Duration(seconds: 30));

      if (enableLogging) print('Get members status: ${response.statusCode}');

      if (response.statusCode == 200) {
        final Map<String, dynamic> data = json.decode(response.body);
        final List<dynamic> members = data['members'] ?? [];
        return members.map((j) => Member.fromJson(j)).toList();
      }
      return [];
    } catch (e) {
      if (enableLogging) print('Get members error: $e');
      return [];
    }
  }

  static Future<Owner> getOwner(String classroomId) async {
    try {
      final headers = await _authHeaders();
      final response = await http.get(
        Uri.parse('$_gatewayUrl/unihub/classroom/api/v1/classroom/get-owner/$classroomId'),
        headers: headers,
      ).timeout(const Duration(seconds: 30));

      if (enableLogging) print('Get owner status: ${response.statusCode}');

      if (response.statusCode == 200) {
        return Owner.fromJson(json.decode(response.body));
      }
      throw Exception('Failed to get owner');
    } catch (e) {
      if (enableLogging) print('Get owner error: $e');
      rethrow;
    }
  }

  // ==================== MATERIAL ENDPOINTS ====================

  static Future<List<ClassroomMaterial>> getAllMaterials(String classroomId, {int pageNum = 1}) async {
    try {
      final headers = await _authHeaders();
      final response = await http.get(
        Uri.parse('$_gatewayUrl/unihub/classroom/api/v1/material/get-all-materials/$classroomId?page_num=$pageNum'),
        headers: headers,
      ).timeout(const Duration(seconds: 30));

      if (enableLogging) print('Get materials status: ${response.statusCode}');

      if (response.statusCode == 200) {
        final Map<String, dynamic> data = json.decode(response.body);
        final List<dynamic> materials = data['materials'] ?? [];
        return materials.map((j) => ClassroomMaterial.fromJson(j)).toList();
      }
      return [];
    } catch (e) {
      if (enableLogging) print('Get materials error: $e');
      return [];
    }
  }

  static Future<List<ClassroomMaterial>> getAllAssignments(String classroomId, {int pageNum = 1}) async {
    try {
      final headers = await _authHeaders();
      final response = await http.get(
        Uri.parse('$_gatewayUrl/unihub/classroom/api/v1/material/get-all-assignments/$classroomId?page_num=$pageNum'),
        headers: headers,
      ).timeout(const Duration(seconds: 30));

      if (enableLogging) print('Get assignments status: ${response.statusCode}');

      if (response.statusCode == 200) {
        final Map<String, dynamic> data = json.decode(response.body);
        final List<dynamic> assignments = data['assignments'] ?? [];
        return assignments.map((j) => ClassroomMaterial.fromJson(j)).toList();
      }
      return [];
    } catch (e) {
      if (enableLogging) print('Get assignments error: $e');
      return [];
    }
  }

  static Future<ClassroomMaterial> getMaterial(String materialId) async {
    try {
      final headers = await _authHeaders();
      final response = await http.get(
        Uri.parse('$_gatewayUrl/unihub/classroom/api/v1/material/get-material/$materialId'),
        headers: headers,
      ).timeout(const Duration(seconds: 30));

      if (enableLogging) print('Get material status: ${response.statusCode}');

      if (response.statusCode == 200) {
        return ClassroomMaterial.fromJson(json.decode(response.body));
      }
      throw Exception('Failed to get material');
    } catch (e) {
      if (enableLogging) print('Get material error: $e');
      rethrow;
    }
  }

  static Future<String> getAssignmentIdFromMaterial(String materialId) async {
    try {
      final headers = await _authHeaders();
      final response = await http.get(
        Uri.parse('$_gatewayUrl/unihub/classroom/api/v1/material/get-assignment/$materialId'),
        headers: headers,
      ).timeout(const Duration(seconds: 30));

      print('Get assignment from material status: ${response.statusCode}');
      print('Response: ${response.body}');

      if (response.statusCode == 200) {
        final Map<String, dynamic> data = json.decode(response.body);
        final assignmentId = data['assignment_id']?.toString() ?? data['aid']?.toString();
        print('Found assignment ID: $assignmentId');
        if (assignmentId == null || assignmentId.isEmpty) {
          throw Exception('Assignment ID not found in response');
        }
        return assignmentId;
      }
      throw Exception('Assignment not found for material: $materialId');
    } catch (e) {
      print('Get assignment error: $e');
      rethrow;
    }
  }

  static Future<ClassroomMaterial> createAnnouncement(
      String classroomId,
      String headLine,
      String description,
      List<File>? files,
      ) async {
    try {
      final token = await _getToken();
      final request = http.MultipartRequest(
        'POST',
        Uri.parse('$_gatewayUrl/unihub/classroom/api/v1/material/instructor/create-announcement/$classroomId'),
      );

      if (token != null) {
        request.headers['Authorization'] = 'Bearer $token';
      }

      final dataJson = json.encode({
        'head_line': headLine,
        'description': description,
      });

      request.files.add(
        http.MultipartFile.fromString(
          'data',
          dataJson,
          contentType: MediaType('application', 'json'),
        ),
      );

      if (files != null && files.isNotEmpty) {
        for (final file in files) {
          final stream = http.ByteStream(file.openRead());
          final length = await file.length();
          request.files.add(
            http.MultipartFile(
              'files',
              stream,
              length,
              filename: file.path.split('/').last,
            ),
          );
        }
      }

      final response = await request.send();
      final responseBody = await response.stream.bytesToString();

      if (enableLogging) print('Create announcement status: ${response.statusCode}');

      if (response.statusCode == 201 || response.statusCode == 200) {
        return ClassroomMaterial.fromJson(json.decode(responseBody));
      }
      throw Exception('Failed to create announcement');
    } catch (e) {
      if (enableLogging) print('Create announcement error: $e');
      rethrow;
    }
  }

  // ==================== COMMENT ENDPOINTS ====================

  static Future<ClassroomComment> createComment(String materialId, String content) async {
    try {
      final headers = await _authHeaders();
      final response = await http.post(
        Uri.parse('$_gatewayUrl/unihub/classroom/api/v1/comment/create-material/$materialId'),
        headers: headers,
        body: json.encode({'content': content}),
      ).timeout(const Duration(seconds: 30));

      if (enableLogging) print('Create comment status: ${response.statusCode}');

      if (response.statusCode == 201 || response.statusCode == 200) {
        return ClassroomComment.fromJson(json.decode(response.body));
      }
      throw Exception('Failed to create comment');
    } catch (e) {
      if (enableLogging) print('Create comment error: $e');
      rethrow;
    }
  }

  static Future<List<ClassroomComment>> getComments(String materialId, {int pageNum = 1}) async {
    try {
      final headers = await _authHeaders();
      final response = await http.get(
        Uri.parse('$_gatewayUrl/unihub/classroom/api/v1/comment/get-material-comments/$materialId?page_num=$pageNum'),
        headers: headers,
      ).timeout(const Duration(seconds: 30));

      if (enableLogging) print('Get comments status: ${response.statusCode}');

      if (response.statusCode == 200) {
        final Map<String, dynamic> data = json.decode(response.body);
        final List<dynamic> comments = data['comments'] ?? [];
        return comments.map((j) => ClassroomComment.fromJson(j)).toList();
      }
      return [];
    } catch (e) {
      if (enableLogging) print('Get comments error: $e');
      return [];
    }
  }

  static Future<void> deleteComment(String commentId) async {
    try {
      final headers = await _authHeaders();
      final response = await http.delete(
        Uri.parse('$_gatewayUrl/unihub/classroom/api/v1/comment/delete/$commentId'),
        headers: headers,
      ).timeout(const Duration(seconds: 30));

      if (enableLogging) print('Delete comment status: ${response.statusCode}');

      if (response.statusCode != 204 && response.statusCode != 200) {
        throw Exception('Failed to delete comment');
      }
    } catch (e) {
      if (enableLogging) print('Delete comment error: $e');
      rethrow;
    }
  }

  static Future<ClassroomComment> editComment(String commentId, String content) async {
    try {
      final headers = await _authHeaders();
      final response = await http.put(
        Uri.parse('$_gatewayUrl/unihub/classroom/api/v1/comment/edit/$commentId'),
        headers: headers,
        body: json.encode({'content': content}),
      ).timeout(const Duration(seconds: 30));

      if (enableLogging) print('Edit comment status: ${response.statusCode}');

      if (response.statusCode == 200) {
        return ClassroomComment.fromJson(json.decode(response.body));
      }
      throw Exception('Failed to edit comment');
    } catch (e) {
      if (enableLogging) print('Edit comment error: $e');
      rethrow;
    }
  }

  // ==================== SUBMISSION ENDPOINTS ====================

  static Future<Submission> submitAssignment(String assignmentId, List<File> files) async {
    try {
      final token = await _getToken();
      final url = '$_gatewayUrl/unihub/classroom/api/v1/submissions/student/submit/$assignmentId';

      print('=== SUBMISSION DEBUG ===');
      print('URL: $url');
      print('Assignment ID: $assignmentId');
      print('Files count: ${files.length}');

      final request = http.MultipartRequest('POST', Uri.parse(url));

      if (token != null) {
        request.headers['Authorization'] = 'Bearer $token';
      }

      final userData = await TokenService.getUserData();
      if (userData != null) {
        final university = userData['university'];
        if (university != null) {
          if (university['uid'] != null) {
            request.headers['X-User-University-Id'] = university['uid'].toString();
          }
          if (university['cid'] != null) {
            request.headers['X-User-College-Id'] = university['cid'].toString();
          }
        }
        if (userData['email'] != null) {
          request.headers['X-User-Email'] = userData['email'].toString();
        }
      }

      if (files.isNotEmpty) {
        for (final file in files) {
          final stream = http.ByteStream(file.openRead());
          final length = await file.length();
          request.files.add(
            http.MultipartFile(
              'files',
              stream,
              length,
              filename: file.path.split('/').last,
            ),
          );
        }
      }

      final response = await request.send();
      final responseBody = await response.stream.bytesToString();

      print('Submit assignment status: ${response.statusCode}');
      print('Submit assignment response: $responseBody');

      if (response.statusCode == 201 || response.statusCode == 200) {
        return Submission.fromJson(json.decode(responseBody));
      } else {
        throw Exception('Failed to submit assignment: ${response.statusCode}');
      }
    } catch (e) {
      print('Submit assignment error: $e');
      rethrow;
    }
  }

  static Future<Submission> editSubmission(String submissionId, List<File> files, List<String> toDeleteFiles) async {
    try {
      final token = await _getToken();
      final url = '$_gatewayUrl/unihub/classroom/api/v1/submissions/student/edit/$submissionId';

      final request = http.MultipartRequest('PUT', Uri.parse(url));

      if (token != null) {
        request.headers['Authorization'] = 'Bearer $token';
      }

      final userData = await TokenService.getUserData();
      if (userData != null) {
        final university = userData['university'];
        if (university != null) {
          if (university['uid'] != null) {
            request.headers['X-User-University-Id'] = university['uid'].toString();
          }
          if (university['cid'] != null) {
            request.headers['X-User-College-Id'] = university['cid'].toString();
          }
        }
        if (userData['email'] != null) {
          request.headers['X-User-Email'] = userData['email'].toString();
        }
      }

      if (files.isNotEmpty) {
        for (final file in files) {
          final stream = http.ByteStream(file.openRead());
          final length = await file.length();
          request.files.add(
            http.MultipartFile(
              'files',
              stream,
              length,
              filename: file.path.split('/').last,
            ),
          );
        }
      }

      if (toDeleteFiles.isNotEmpty) {
        request.files.add(
          http.MultipartFile.fromString(
            'ToDeleteFiles',
            json.encode(toDeleteFiles),
            contentType: MediaType('application', 'json'),
          ),
        );
      }

      final response = await request.send();
      final responseBody = await response.stream.bytesToString();

      print('Edit submission status: ${response.statusCode}');

      if (response.statusCode == 200) {
        return Submission.fromJson(json.decode(responseBody));
      }
      throw Exception('Failed to edit submission');
    } catch (e) {
      print('Edit submission error: $e');
      rethrow;
    }
  }

  static Future<void> deleteSubmission(String submissionId) async {
    try {
      final headers = await _authHeaders();
      final response = await http.delete(
        Uri.parse('$_gatewayUrl/unihub/classroom/api/v1/submissions/student/delete/$submissionId'),
        headers: headers,
      ).timeout(const Duration(seconds: 30));

      print('Delete submission status: ${response.statusCode}');

      if (response.statusCode != 204 && response.statusCode != 200) {
        throw Exception('Failed to delete submission');
      }
    } catch (e) {
      print('Delete submission error: $e');
      rethrow;
    }
  }

  static Future<Submission> getStudentSubmission(String assignmentId) async {
    try {
      final headers = await _authHeaders();
      final response = await http.get(
        Uri.parse('$_gatewayUrl/unihub/classroom/api/v1/submissions/student/get-submission/$assignmentId'),
        headers: headers,
      ).timeout(const Duration(seconds: 30));

      print('Get student submission status: ${response.statusCode}');

      if (response.statusCode == 200) {
        return Submission.fromJson(json.decode(response.body));
      }
      throw Exception('Failed to get submission');
    } catch (e) {
      print('Get student submission error: $e');
      rethrow;
    }
  }
}