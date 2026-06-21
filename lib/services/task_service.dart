import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/task/task_model.dart';
import 'token_service.dart';

class TaskService {
  static const String baseUrl = 'http://34.58.11.82:8082/unihub';
  static const String taskBaseUrl = '$baseUrl/taskmanager/api/v1/tasks';

  static Future<Map<String, String>> _getHeaders() async {
    final accessToken = await TokenService.getAccessToken();
    return {
      'Content-Type': 'application/json',  // ✅ FIXED
      'Authorization': 'Bearer $accessToken',
    };
  }

  static Future<List<Task>> getTasks({int pageNum = 1}) async {
    try {
      final headers = await _getHeaders();
      final url = Uri.parse('$taskBaseUrl/get-tasks?page_num=$pageNum');

      print('TaskService: GET $url');
      final response = await http.get(url, headers: headers);

      print('TaskService: Response status: ${response.statusCode}');
      print('TaskService: Response body: ${response.body}');

      if (response.statusCode == 200) {
        final Map<String, dynamic> data = json.decode(response.body);
        final List<dynamic> tasksList = data['tasks'] ?? [];
        return tasksList.map((json) => Task.fromJson(json)).toList();
      } else {
        throw Exception('Failed to get tasks: ${response.statusCode} - ${response.body}');
      }
    } catch (e) {
      print('TaskService: Error: $e');
      rethrow;
    }
  }

  static Future<Task> createTask(CreateTaskRequest request) async {
    try {
      final headers = await _getHeaders();
      final url = Uri.parse('$taskBaseUrl/create');

      final body = json.encode({
        'title': request.title,
        'description': request.description,
        'priority': request.priority.value,
        'due_date': request.dueDate.toIso8601String(),
      });

      print('TaskService: POST $url');
      print('TaskService: Headers: $headers');
      print('TaskService: Body: $body');

      final response = await http.post(url, headers: headers, body: body);

      print('TaskService: Response status: ${response.statusCode}');
      print('TaskService: Response body: ${response.body}');

      if (response.statusCode == 200 || response.statusCode == 201) {
        final Map<String, dynamic> data = json.decode(response.body);
        return Task.fromJson(data);
      } else {
        throw Exception('Failed to create task: ${response.statusCode} - ${response.body}');
      }
    } catch (e) {
      print('TaskService: Error: $e');
      rethrow;
    }
  }

  static Future<Task> editTask(String taskId, CreateTaskRequest request) async {
    try {
      final headers = await _getHeaders();
      final url = Uri.parse('$taskBaseUrl/edit-task/$taskId');

      final body = json.encode({
        'title': request.title,
        'description': request.description,
        'priority': request.priority.value,
        'due_date': request.dueDate.toIso8601String(),
      });

      final response = await http.put(url, headers: headers, body: body);

      if (response.statusCode == 200) {
        final Map<String, dynamic> data = json.decode(response.body);
        return Task.fromJson(data);
      } else {
        throw Exception('Failed to edit task: ${response.statusCode}');
      }
    } catch (e) {
      print('TaskService: Error: $e');
      rethrow;
    }
  }

  static Future<Task> setTaskStatus(String taskId, TaskStatus status) async {
    try {
      final headers = await _getHeaders();
      final url = Uri.parse('$taskBaseUrl/set-task-state/$taskId');

      final response = await http.patch(
        url,
        headers: headers,
        body: json.encode(status.value),
      );

      if (response.statusCode == 200) {
        final Map<String, dynamic> data = json.decode(response.body);
        return Task.fromJson(data);
      } else {
        throw Exception('Failed to update task status: ${response.statusCode}');
      }
    } catch (e) {
      print('TaskService: Error: $e');
      rethrow;
    }
  }

  static Future<void> deleteTask(String taskId) async {
    try {
      final headers = await _getHeaders();
      final url = Uri.parse('$taskBaseUrl/delete-task/$taskId');

      final response = await http.delete(url, headers: headers);

      if (response.statusCode != 204 && response.statusCode != 200) {
        throw Exception('Failed to delete task: ${response.statusCode}');
      }
    } catch (e) {
      print('TaskService: Error: $e');
      rethrow;
    }
  }

  static Future<void> deleteTasks(List<String> taskIds) async {
    try {
      final headers = await _getHeaders();
      final url = Uri.parse('$taskBaseUrl/delete-in-batch');

      final response = await http.delete(
        url,
        headers: headers,
        body: json.encode(taskIds),
      );

      if (response.statusCode != 204 && response.statusCode != 200) {
        throw Exception('Failed to delete tasks: ${response.statusCode}');
      }
    } catch (e) {
      print('TaskService: Error: $e');
      rethrow;
    }
  }
}