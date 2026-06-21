import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';
import 'package:path/path.dart' as path;
import '../models/post_model.dart';
import '../models/comment_model.dart';
import '../models/like_model.dart';
import 'token_service.dart';

class AnnouncementService {

  static const String _baseUrl = 'http://34.58.11.82:8082/unihub/announcement/api/v1';
  static const bool enableLogging = true;

  // ==================== HELPERS ====================

  static Future<Map<String, String>> _authHeaders() async {
    final accessToken = await TokenService.getAccessToken();
    return {
      'Content-Type': 'application/json',
      if (accessToken != null) 'Authorization': 'Bearer $accessToken',
    };
  }

  static Future<String?> _getToken() async {
    return await TokenService.getAccessToken();
  }

  // ==================== POSTS ====================

  static Future<Post> createPost({
    required String title,
    String? content,
    File? media,
  }) async {
    try {
      final token = await _getToken();
      if (enableLogging) print('Creating post: $title');

      final request = http.MultipartRequest(
        'POST',
        Uri.parse('$_baseUrl/posts/public/create'),
      );

      if (token != null) {
        request.headers['Authorization'] = 'Bearer $token';
      }

      final dataJson = json.encode({
        'title': title,
        if (content != null && content.trim().isNotEmpty) 'content': content.trim(),
      });

      request.files.add(
        http.MultipartFile.fromString(
          'data',
          dataJson,
          contentType: MediaType('application', 'json'),
        ),
      );

      if (media != null) {
        final stream = http.ByteStream(media.openRead());
        final length = await media.length();

        String contentType = 'image/jpeg';
        final extension = path.basename(media.path).split('.').last.toLowerCase();
        switch (extension) {
          case 'jpg':
          case 'jpeg':
            contentType = 'image/jpeg';
            break;
          case 'png':
            contentType = 'image/png';
            break;
          case 'gif':
            contentType = 'image/gif';
            break;
          case 'mp4':
            contentType = 'video/mp4';
            break;
          case 'pdf':
            contentType = 'application/pdf';
            break;
        }

        request.files.add(
          http.MultipartFile(
            'media',
            stream,
            length,
            filename: path.basename(media.path),
            contentType: MediaType.parse(contentType),
          ),
        );
      }

      final streamedResponse = await request.send()
          .timeout(const Duration(seconds: 30));
      final responseBody = await streamedResponse.stream.bytesToString();

      if (enableLogging) print('Create post status: ${streamedResponse.statusCode}');
      if (enableLogging) print('Create post body: $responseBody');

      if (streamedResponse.statusCode == 201 || streamedResponse.statusCode == 200) {
        return Post.fromJson(json.decode(responseBody));
      } else {
        String msg = 'Failed to create post (${streamedResponse.statusCode})';
        try {
          final err = json.decode(responseBody);
          msg = err['message'] ?? err['error'] ?? msg;
        } catch (_) {}
        throw Exception(msg);
      }
    } on TimeoutException {
      throw Exception('Request timed out. Check your connection.');
    } on SocketException {
      throw Exception('No internet connection.');
    } catch (e) {
      if (enableLogging) print('Create post error: $e');
      rethrow;
    }
  }

  static Future<List<Post>> getPosts({
    int pageNum = 1,
    String sortDir = 'desc',
    String sortField = 'createdAt',
  }) async {
    try {
      final headers = await _authHeaders();
      final url = Uri.parse(
        '$_baseUrl/posts/public/get-posts?page_num=$pageNum&sort_dir=$sortDir&sort_field=$sortField',
      );

      if (enableLogging) print('Fetching posts: $url');

      final response = await http.get(url, headers: headers)
          .timeout(const Duration(seconds: 30));

      if (enableLogging) print('Get posts status: ${response.statusCode}');
      if (enableLogging) print('Get posts response body: ${response.body}');

      if (response.statusCode == 200) {
        final dynamic data = json.decode(response.body);
        if (enableLogging) print('Decoded data type: ${data.runtimeType}');

        List<dynamic> postsJson = [];

        if (data is Map<String, dynamic>) {
          if (data.containsKey('content') && data['content'] is List) {
            postsJson = data['content'] as List<dynamic>;
            if (enableLogging) print('Found posts in "content" key, count: ${postsJson.length}');
          }
          else if (data.containsKey('posts') && data['posts'] is List) {
            postsJson = data['posts'] as List<dynamic>;
            if (enableLogging) print('Found posts in "posts" key, count: ${postsJson.length}');
          }
          else if (data.containsKey('data') && data['data'] is List) {
            postsJson = data['data'] as List<dynamic>;
            if (enableLogging) print('Found posts in "data" key, count: ${postsJson.length}');
          }
        } else if (data is List) {
          postsJson = data;
          if (enableLogging) print('Data is a list, count: ${postsJson.length}');
        }

        if (enableLogging) print('Total posts to parse: ${postsJson.length}');

        final posts = postsJson.map((j) {
          if (enableLogging) print('Parsing post: ${j['title']}');
          return Post.fromJson(j);
        }).toList();

        if (enableLogging) print('Successfully parsed ${posts.length} posts');
        return posts;
      } else {
        throw Exception('Failed to get posts (${response.statusCode})');
      }
    } on TimeoutException {
      throw Exception('Request timed out.');
    } on SocketException {
      throw Exception('No internet connection.');
    } catch (e) {
      if (enableLogging) print('Get posts error: $e');
      return [];
    }
  }

  static Future<List<Post>> getMyPosts({
    int pageNum = 1,
    String sortDir = 'desc',
    String sortField = 'createdAt',
  }) async {
    try {
      final headers = await _authHeaders();
      final url = Uri.parse(
        '$_baseUrl/posts/public/get-my-posts?page_num=$pageNum&sort_dir=$sortDir&sort_field=$sortField',
      );

      if (enableLogging) print('Fetching my posts: $url');

      final response = await http.get(url, headers: headers)
          .timeout(const Duration(seconds: 30));

      if (enableLogging) print('Get my posts status: ${response.statusCode}');
      if (enableLogging) print('Get my posts response body: ${response.body}');

      if (response.statusCode == 200) {
        final dynamic data = json.decode(response.body);

        List<dynamic> postsJson = [];

        if (data is Map<String, dynamic>) {
          if (data.containsKey('content') && data['content'] is List) {
            postsJson = data['content'] as List<dynamic>;
          }
          else if (data.containsKey('posts') && data['posts'] is List) {
            postsJson = data['posts'] as List<dynamic>;
          }
          else if (data.containsKey('data') && data['data'] is List) {
            postsJson = data['data'] as List<dynamic>;
          }
        } else if (data is List) {
          postsJson = data;
        }

        return postsJson.map((j) => Post.fromJson(j)).toList();
      } else {
        throw Exception('Failed to get my posts (${response.statusCode})');
      }
    } on TimeoutException {
      throw Exception('Request timed out.');
    } on SocketException {
      throw Exception('No internet connection.');
    } catch (e) {
      if (enableLogging) print('Get my posts error: $e');
      return [];
    }
  }

  static Future<Post> getPostById(String postId) async {
    try {
      final headers = await _authHeaders();
      final response = await http.get(
        Uri.parse('$_baseUrl/posts/public/get-post/$postId'),
        headers: headers,
      ).timeout(const Duration(seconds: 30));

      if (enableLogging) print('Get post status: ${response.statusCode}');

      if (response.statusCode == 200) {
        return Post.fromJson(json.decode(response.body));
      } else {
        throw Exception('Failed to get post (${response.statusCode})');
      }
    } on TimeoutException {
      throw Exception('Request timed out.');
    } on SocketException {
      throw Exception('No internet connection.');
    } catch (e) {
      if (enableLogging) print('Get post error: $e');
      rethrow;
    }
  }

  static Future<Map<String, int>> getPostStatusCounts() async {
    try {
      final headers = await _authHeaders();
      final response = await http.get(
        Uri.parse('$_baseUrl/posts/public/get-my-posts-analysis'),
        headers: headers,
      ).timeout(const Duration(seconds: 30));

      if (enableLogging) print('Get status counts: ${response.statusCode}');

      if (response.statusCode == 200) {
        final List<dynamic> data = json.decode(response.body);
        final Map<String, int> counts = {};
        for (var item in data) {
          final status = item['status'] as String;
          final count = int.tryParse(item['count'].toString()) ?? 0;
          counts[status] = count;
        }
        return counts;
      } else {
        return {};
      }
    } on TimeoutException {
      return {};
    } on SocketException {
      return {};
    } catch (e) {
      if (enableLogging) print('Get status counts error: $e');
      return {};
    }
  }

  static Future<Post> publishPost(String postId) async {
    try {
      final headers = await _authHeaders();
      final response = await http.patch(
        Uri.parse('$_baseUrl/posts/public/publish/$postId'),
        headers: headers,
      ).timeout(const Duration(seconds: 30));

      if (enableLogging) print('Publish post status: ${response.statusCode}');

      if (response.statusCode == 200) {
        return Post.fromJson(json.decode(response.body));
      } else {
        throw Exception('Failed to publish post (${response.statusCode})');
      }
    } on TimeoutException {
      throw Exception('Request timed out.');
    } on SocketException {
      throw Exception('No internet connection.');
    } catch (e) {
      if (enableLogging) print('Publish post error: $e');
      rethrow;
    }
  }

  static Future<Post> editPost({
    required String postId,
    required String title,
    String? content,
    File? media,
    bool removeMedia = false,
  }) async {
    try {
      final token = await _getToken();

      final request = http.MultipartRequest(
        'PUT',
        Uri.parse('$_baseUrl/posts/public/edit/$postId?remove_media=$removeMedia'),
      );

      if (token != null) {
        request.headers['Authorization'] = 'Bearer $token';
      }

      final dataJson = json.encode({
        'title': title,
        if (content != null && content.trim().isNotEmpty) 'content': content.trim(),
      });

      request.files.add(
        http.MultipartFile.fromString(
          'data',
          dataJson,
          contentType: MediaType('application', 'json'),
        ),
      );

      if (media != null) {
        final stream = http.ByteStream(media.openRead());
        final length = await media.length();
        request.files.add(
          http.MultipartFile(
            'media',
            stream,
            length,
            filename: path.basename(media.path),
            contentType: MediaType.parse('image/jpeg'),
          ),
        );
      }

      final streamedResponse = await request.send()
          .timeout(const Duration(seconds: 30));
      final responseBody = await streamedResponse.stream.bytesToString();

      if (enableLogging) print('Edit post status: ${streamedResponse.statusCode}');

      if (streamedResponse.statusCode == 200) {
        return Post.fromJson(json.decode(responseBody));
      } else {
        throw Exception('Failed to edit post (${streamedResponse.statusCode})');
      }
    } on TimeoutException {
      throw Exception('Request timed out.');
    } on SocketException {
      throw Exception('No internet connection.');
    } catch (e) {
      if (enableLogging) print('Edit post error: $e');
      rethrow;
    }
  }

  static Future<void> deletePost(String postId) async {
    try {
      final headers = await _authHeaders();
      final response = await http.delete(
        Uri.parse('$_baseUrl/posts/public/delete/$postId'),
        headers: headers,
      ).timeout(const Duration(seconds: 30));

      if (enableLogging) print('Delete post status: ${response.statusCode}');

      if (response.statusCode != 204 && response.statusCode != 200) {
        throw Exception('Failed to delete post (${response.statusCode})');
      }
    } on TimeoutException {
      throw Exception('Request timed out.');
    } on SocketException {
      throw Exception('No internet connection.');
    } catch (e) {
      if (enableLogging) print('Delete post error: $e');
      rethrow;
    }
  }

  // ==================== SECRETARY ENDPOINTS ====================

  static Future<List<Post>> getSecretaryPosts({
    int pageNum = 1,
    String sortDir = 'desc',
    String sortField = 'createdAt',
    String status = 'PENDING',
  }) async {
    try {
      final headers = await _authHeaders();
      final url = Uri.parse(
        '$_baseUrl/posts/secretary/get-posts?page_num=$pageNum&sort_dir=$sortDir&sort_field=$sortField&status=$status',
      );

      final response = await http.get(url, headers: headers)
          .timeout(const Duration(seconds: 30));

      if (enableLogging) print('Secretary get posts status: ${response.statusCode}');

      if (response.statusCode == 200) {
        final dynamic data = json.decode(response.body);

        List<dynamic> postsJson = [];

        if (data is Map<String, dynamic>) {
          postsJson = data['posts'] ?? [];
        } else if (data is List) {
          postsJson = data;
        }

        return postsJson.map((j) => Post.fromJson(j)).toList();
      } else {
        throw Exception('Failed to get secretary posts (${response.statusCode})');
      }
    } on TimeoutException {
      throw Exception('Request timed out.');
    } on SocketException {
      throw Exception('No internet connection.');
    } catch (e) {
      if (enableLogging) print('Secretary get posts error: $e');
      return [];
    }
  }

  static Future<Post> acceptPost(String postId) async {
    try {
      final headers = await _authHeaders();
      final response = await http.patch(
        Uri.parse('$_baseUrl/posts/secretary/accept/post/$postId'),
        headers: headers,
      ).timeout(const Duration(seconds: 30));

      if (enableLogging) print('Accept post status: ${response.statusCode}');

      if (response.statusCode == 200) {
        return Post.fromJson(json.decode(response.body));
      } else {
        throw Exception('Failed to accept post (${response.statusCode})');
      }
    } on TimeoutException {
      throw Exception('Request timed out.');
    } on SocketException {
      throw Exception('No internet connection.');
    } catch (e) {
      if (enableLogging) print('Accept post error: $e');
      rethrow;
    }
  }

  static Future<Post> rejectPost(String postId) async {
    try {
      final headers = await _authHeaders();
      final response = await http.patch(
        Uri.parse('$_baseUrl/posts/secretary/reject/post/$postId'),
        headers: headers,
      ).timeout(const Duration(seconds: 30));

      if (enableLogging) print('Reject post status: ${response.statusCode}');

      if (response.statusCode == 200) {
        return Post.fromJson(json.decode(response.body));
      } else {
        throw Exception('Failed to reject post (${response.statusCode})');
      }
    } on TimeoutException {
      throw Exception('Request timed out.');
    } on SocketException {
      throw Exception('No internet connection.');
    } catch (e) {
      if (enableLogging) print('Reject post error: $e');
      rethrow;
    }
  }

  static Future<void> deletePostSecretary(String postId) async {
    try {
      final headers = await _authHeaders();
      final response = await http.delete(
        Uri.parse('$_baseUrl/posts/secretary/delete/post/$postId'),
        headers: headers,
      ).timeout(const Duration(seconds: 30));

      if (enableLogging) print('Secretary delete post status: ${response.statusCode}');

      if (response.statusCode != 204 && response.statusCode != 200) {
        throw Exception('Failed to delete post (${response.statusCode})');
      }
    } on TimeoutException {
      throw Exception('Request timed out.');
    } on SocketException {
      throw Exception('No internet connection.');
    } catch (e) {
      if (enableLogging) print('Secretary delete post error: $e');
      rethrow;
    }
  }

  // ==================== LIKES ====================

  static Future<void> toggleLike(String postId) async {
    try {
      final headers = await _authHeaders();
      final response = await http.post(
        Uri.parse('$_baseUrl/likes/$postId/like-toggle'),
        headers: headers,
      ).timeout(const Duration(seconds: 30));

      if (enableLogging) print('Toggle like status: ${response.statusCode}');

      if (response.statusCode != 200) {
        throw Exception('Failed to toggle like (${response.statusCode})');
      }
    } on TimeoutException {
      throw Exception('Request timed out.');
    } on SocketException {
      throw Exception('No internet connection.');
    } catch (e) {
      if (enableLogging) print('Toggle like error: $e');
      rethrow;
    }
  }

  static Future<List<LikeUser>> getLikes(String postId, {int pageNum = 1}) async {
    try {
      final headers = await _authHeaders();
      final response = await http.get(
        Uri.parse('$_baseUrl/likes/$postId?page_num=$pageNum'),
        headers: headers,
      ).timeout(const Duration(seconds: 30));

      if (enableLogging) print('Get likes status: ${response.statusCode}');

      if (response.statusCode == 200) {
        final List<dynamic> data = json.decode(response.body);
        return data.map((j) => LikeUser.fromJson(j)).toList();
      } else {
        return [];
      }
    } on TimeoutException {
      return [];
    } on SocketException {
      return [];
    } catch (e) {
      if (enableLogging) print('Get likes error: $e');
      return [];
    }
  }

  // ==================== COMMENTS ====================

  static Future<Comment> createComment(String postId, String content) async {
    try {
      final headers = await _authHeaders();
      final response = await http.post(
        Uri.parse('$_baseUrl/comments/public/create/$postId'),
        headers: headers,
        body: json.encode({'content': content}),
      ).timeout(const Duration(seconds: 30));

      if (enableLogging) print('Create comment status: ${response.statusCode}');
      if (enableLogging) print('Create comment body: ${response.body}');

      if (response.statusCode == 200 || response.statusCode == 201) {
        return Comment.fromJson(json.decode(response.body));
      } else {
        throw Exception('Failed to create comment (${response.statusCode})');
      }
    } on TimeoutException {
      throw Exception('Request timed out.');
    } on SocketException {
      throw Exception('No internet connection.');
    } catch (e) {
      if (enableLogging) print('Create comment error: $e');
      rethrow;
    }
  }

  static Future<List<Comment>> getComments(String postId, {int pageNum = 1}) async {
    try {
      final headers = await _authHeaders();
      final url = Uri.parse(
        '$_baseUrl/comments/public/get-comments/$postId?page_num=$pageNum',
      );

      if (enableLogging) print('Fetching comments from: $url');

      final response = await http.get(url, headers: headers)
          .timeout(const Duration(seconds: 30));

      if (enableLogging) print('Get comments status: ${response.statusCode}');
      if (enableLogging) print('Get comments response: ${response.body}');

      if (response.statusCode == 200) {
        final dynamic body = json.decode(response.body);
        List<dynamic> commentsList = [];

        if (body is List) {
          commentsList = body;
        } else if (body is Map<String, dynamic>) {
          commentsList = body['comments'] ?? body['data'] ?? [];
        }

        if (enableLogging) print('Found ${commentsList.length} comments');

        return commentsList.map((j) => Comment.fromJson(j)).toList();
      } else {
        if (enableLogging) print('Failed to get comments: ${response.statusCode}');
        return [];
      }
    } on TimeoutException {
      if (enableLogging) print('Timeout getting comments');
      return [];
    } on SocketException {
      if (enableLogging) print('No internet connection');
      return [];
    } catch (e) {
      if (enableLogging) print('Get comments error: $e');
      return [];
    }
  }

  static Future<Comment> updateComment(String commentId, String content) async {
    try {
      final headers = await _authHeaders();
      final response = await http.patch(
        Uri.parse('$_baseUrl/comments/public/update/$commentId'),
        headers: headers,
        body: json.encode({'content': content}),
      ).timeout(const Duration(seconds: 30));

      if (enableLogging) print('Update comment status: ${response.statusCode}');

      if (response.statusCode == 200) {
        return Comment.fromJson(json.decode(response.body));
      } else {
        throw Exception('Failed to update comment (${response.statusCode})');
      }
    } on TimeoutException {
      throw Exception('Request timed out.');
    } on SocketException {
      throw Exception('No internet connection.');
    } catch (e) {
      if (enableLogging) print('Update comment error: $e');
      rethrow;
    }
  }

  static Future<void> deleteComment(String commentId) async {
    try {
      final headers = await _authHeaders();
      final response = await http.delete(
        Uri.parse('$_baseUrl/comments/public/delete/$commentId'),
        headers: headers,
      ).timeout(const Duration(seconds: 30));

      if (enableLogging) print('Delete comment status: ${response.statusCode}');

      if (response.statusCode != 204 && response.statusCode != 200) {
        throw Exception('Failed to delete comment (${response.statusCode})');
      }
    } on TimeoutException {
      throw Exception('Request timed out.');
    } on SocketException {
      throw Exception('No internet connection.');
    } catch (e) {
      if (enableLogging) print('Delete comment error: $e');
      rethrow;
    }
  }

  static Future<void> deleteCommentSecretary(String postId, String commentId) async {
    try {
      final headers = await _authHeaders();
      final response = await http.delete(
        Uri.parse('$_baseUrl/comments/secretary/delete/$postId/$commentId'),
        headers: headers,
      ).timeout(const Duration(seconds: 30));

      if (enableLogging) print('Secretary delete comment status: ${response.statusCode}');

      if (response.statusCode != 204 && response.statusCode != 200) {
        throw Exception('Failed to delete comment (${response.statusCode})');
      }
    } on TimeoutException {
      throw Exception('Request timed out.');
    } on SocketException {
      throw Exception('No internet connection.');
    } catch (e) {
      if (enableLogging) print('Secretary delete comment error: $e');
      rethrow;
    }
  }

  // ==================== REPLIES ====================

  static Future<List<Comment>> getReplies(String commentId, {int pageNum = 1}) async {
    try {
      final headers = await _authHeaders();
      final url = Uri.parse(
        '$_baseUrl/comments/public/get-comments-reply/$commentId?page_num=$pageNum',
      );

      if (enableLogging) print('Fetching replies from: $url');

      final response = await http.get(url, headers: headers)
          .timeout(const Duration(seconds: 30));

      if (enableLogging) print('Get replies status: ${response.statusCode}');
      if (enableLogging) print('Get replies response: ${response.body}');

      if (response.statusCode == 200) {
        final dynamic body = json.decode(response.body);
        List<dynamic> repliesList = [];

        if (body is List) {
          repliesList = body;
        } else if (body is Map<String, dynamic>) {
          if (body.containsKey('replies')) {
            repliesList = body['replies'] is List ? body['replies'] : [];
          } else if (body.containsKey('data')) {
            repliesList = body['data'] is List ? body['data'] : [];
          } else if (body.containsKey('comments')) {
            repliesList = body['comments'] is List ? body['comments'] : [];
          } else {
            if (body.containsKey('content') || body.containsKey('comment_id')) {
              repliesList = [body];
            } else {
              for (var value in body.values) {
                if (value is List) {
                  repliesList = value;
                  break;
                }
              }
            }
          }
        }

        if (enableLogging) print('Found ${repliesList.length} replies');

        return repliesList.map((j) => Comment.fromJson(j)).toList();
      } else {
        if (enableLogging) print('Failed to get replies: ${response.statusCode}');
        return [];
      }
    } on TimeoutException {
      if (enableLogging) print('Timeout getting replies');
      return [];
    } on SocketException {
      if (enableLogging) print('No internet connection');
      return [];
    } catch (e) {
      if (enableLogging) print('Get replies error: $e');
      return [];
    }
  }

  static Future<Comment> createReply(String commentId, String content) async {
    try {
      final headers = await _authHeaders();
      final response = await http.post(
        Uri.parse('$_baseUrl/comments/public/reply/$commentId'),
        headers: headers,
        body: json.encode({'content': content}),
      ).timeout(const Duration(seconds: 30));

      if (enableLogging) print('Create reply status: ${response.statusCode}');

      if (response.statusCode == 200 || response.statusCode == 201) {
        return Comment.fromJson(json.decode(response.body));
      } else {
        throw Exception('Failed to create reply (${response.statusCode})');
      }
    } on TimeoutException {
      throw Exception('Request timed out.');
    } on SocketException {
      throw Exception('No internet connection.');
    } catch (e) {
      if (enableLogging) print('Create reply error: $e');
      rethrow;
    }
  }
}