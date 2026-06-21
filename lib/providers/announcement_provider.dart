import 'package:flutter/material.dart';
import 'dart:io';
import '../models/post_model.dart';
import '../models/comment_model.dart';
import '../services/announcement_service.dart';

class AnnouncementProvider extends ChangeNotifier {
  List<Post> _posts = [];
  List<Post> _myPosts = [];
  Map<String, int> _statusCounts = {};
  String? _error;
  bool _isLoading = false;
  bool _isLoadingMore = false;
  bool _hasMorePosts = true;
  bool _hasMoreMyPosts = true;
  int _currentPage = 1;
  int _currentMyPage = 1;
  String _sortField = 'createdAt';
  String _sortDir = 'desc';

  bool _isLoadingPosts = false;
  bool _isLoadingMyPosts = false;

  String _secretaryStatusFilter = 'PENDING';
  bool _isSecretaryMode = false;

  List<Post> get posts => _posts;
  List<Post> get myPosts => _myPosts;
  Map<String, int> get statusCounts => _statusCounts;
  String? get error => _error;
  bool get isLoading => _isLoading;
  bool get isLoadingMore => _isLoadingMore;
  bool get hasMorePosts => _hasMorePosts;
  bool get hasMoreMyPosts => _hasMoreMyPosts;
  String get secretaryStatusFilter => _secretaryStatusFilter;
  bool get isSecretaryMode => _isSecretaryMode;

  void setSecretaryMode(bool isSecretary) {
    _isSecretaryMode = isSecretary;
    if (isSecretary) {
      _secretaryStatusFilter = 'PENDING';
    }
    notifyListeners();
  }

  void setSecretaryStatusFilter(String status) {
    if (_secretaryStatusFilter != status) {
      _secretaryStatusFilter = status;
      _currentPage = 1;
      _posts = [];
      _hasMorePosts = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        loadSecretaryPosts(refresh: true);
      });
    }
  }

  // ==================== POST LOADING METHODS ====================

  Future<void> loadPosts({bool refresh = false}) async {
    if (_isLoadingPosts) return;

    if (refresh) {
      _currentPage = 1;
      _posts = [];
      _hasMorePosts = true;
    }

    if (!_hasMorePosts && !refresh) return;

    _isLoadingPosts = true;
    _isLoading = _posts.isEmpty;
    _isLoadingMore = !_isLoading && !refresh;
    _error = null;
    notifyListeners();

    try {
      print('Loading posts - page: $_currentPage');
      final newPosts = await AnnouncementService.getPosts(
        pageNum: _currentPage,
        sortDir: _sortDir,
        sortField: _sortField,
      );

      print('Received ${newPosts.length} posts');

      if (refresh) {
        _posts = newPosts;
      } else {
        _posts.addAll(newPosts);
      }

      print('Total posts in provider: ${_posts.length}');

      _hasMorePosts = newPosts.isNotEmpty;
      if (newPosts.isNotEmpty) {
        _currentPage++;
      }
    } catch (e) {
      print('Error loading posts: $e');
      _error = e.toString();
      if (refresh) _posts = [];
    } finally {
      _isLoading = false;
      _isLoadingMore = false;
      _isLoadingPosts = false;
      notifyListeners();
    }
  }

  Future<void> loadMyPosts({bool refresh = false}) async {
    if (_isLoadingMyPosts) return;

    if (refresh) {
      _currentMyPage = 1;
      _myPosts = [];
      _hasMoreMyPosts = true;
    }

    if (!_hasMoreMyPosts && !refresh) return;

    _isLoadingMyPosts = true;
    _isLoading = _myPosts.isEmpty;
    _isLoadingMore = !_isLoading && !refresh;
    _error = null;
    notifyListeners();

    try {
      final newPosts = await AnnouncementService.getMyPosts(
        pageNum: _currentMyPage,
        sortDir: _sortDir,
        sortField: _sortField,
      );

      if (refresh) {
        _myPosts = newPosts;
      } else {
        _myPosts.addAll(newPosts);
      }

      _hasMoreMyPosts = newPosts.isNotEmpty;
      if (newPosts.isNotEmpty) {
        _currentMyPage++;
      }
    } catch (e) {
      _error = e.toString();
      if (refresh) _myPosts = [];
    } finally {
      _isLoading = false;
      _isLoadingMore = false;
      _isLoadingMyPosts = false;
      notifyListeners();
    }
  }

  Future<void> loadSecretaryPosts({bool refresh = false}) async {
    if (_isLoadingPosts) return;

    if (refresh) {
      _currentPage = 1;
      _posts = [];
      _hasMorePosts = true;
    }

    if (!_hasMorePosts && !refresh) return;

    _isLoadingPosts = true;
    _isLoading = _posts.isEmpty;
    _isLoadingMore = !_isLoading && !refresh;
    _error = null;
    notifyListeners();

    try {
      final newPosts = await AnnouncementService.getSecretaryPosts(
        status: _secretaryStatusFilter,
        pageNum: _currentPage,
        sortDir: _sortDir,
        sortField: _sortField,
      );

      if (refresh) {
        _posts = newPosts;
      } else {
        _posts.addAll(newPosts);
      }

      _hasMorePosts = newPosts.isNotEmpty;
      if (newPosts.isNotEmpty) {
        _currentPage++;
      }
    } catch (e) {
      _error = e.toString();
      if (refresh) _posts = [];
    } finally {
      _isLoading = false;
      _isLoadingMore = false;
      _isLoadingPosts = false;
      notifyListeners();
    }
  }

  Future<void> loadStatusCounts() async {
    try {
      _statusCounts = await AnnouncementService.getPostStatusCounts();
      notifyListeners();
    } catch (e) {
      print('Error loading status counts: $e');
    }
  }

  // ==================== POST CRUD OPERATIONS ====================

  Future<Post?> createPost({
    required String title,
    String? content,
    File? media,
  }) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final post = await AnnouncementService.createPost(
        title: title,
        content: content,
        media: media,
      );

      if (post.status == PostStatus.draft) {
        _myPosts.insert(0, post);
      } else {
        _posts.insert(0, post);
      }

      await loadStatusCounts();
      return post;
    } catch (e) {
      _error = e.toString();
      return null;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<Post?> editPost({
    required String postId,
    required String title,
    String? content,
    File? media,
    bool removeMedia = false,
  }) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final post = await AnnouncementService.editPost(
        postId: postId,
        title: title,
        content: content,
        media: media,
        removeMedia: removeMedia,
      );

      final myIndex = _myPosts.indexWhere((p) => p.id == postId);
      if (myIndex != -1) {
        _myPosts[myIndex] = post;
      }

      final publicIndex = _posts.indexWhere((p) => p.id == postId);
      if (publicIndex != -1) {
        _posts[publicIndex] = post;
      }

      await loadStatusCounts();
      return post;
    } catch (e) {
      _error = e.toString();
      return null;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<Post?> publishPost(String postId) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final post = await AnnouncementService.publishPost(postId);

      final myIndex = _myPosts.indexWhere((p) => p.id == postId);
      if (myIndex != -1) {
        _myPosts[myIndex] = post;
      }

      await loadStatusCounts();
      return post;
    } catch (e) {
      _error = e.toString();
      return null;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<bool> deletePost(String postId) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      await AnnouncementService.deletePost(postId);
      _myPosts.removeWhere((p) => p.id == postId);
      _posts.removeWhere((p) => p.id == postId);
      await loadStatusCounts();
      return true;
    } catch (e) {
      _error = e.toString();
      return false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<bool> deletePostSecretary(String postId) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      await AnnouncementService.deletePostSecretary(postId);
      _myPosts.removeWhere((p) => p.id == postId);
      _posts.removeWhere((p) => p.id == postId);
      await loadStatusCounts();
      return true;
    } catch (e) {
      _error = e.toString();
      return false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // ==================== LIKE OPERATIONS ====================

  Future<bool> toggleLike(String postId) async {
    try {
      await AnnouncementService.toggleLike(postId);
      _updatePostLikeStatus(postId);
      return true;
    } catch (e) {
      _error = e.toString();
      return false;
    }
  }

  void _updatePostLikeStatus(String postId) {
    final updatePost = (Post post) {
      final wasLiked = post.likedByCurrentUser;
      return post.copyWith(
        likedByCurrentUser: !wasLiked,
        likesCount: wasLiked ? post.likesCount - 1 : post.likesCount + 1,
      );
    };

    final myIndex = _myPosts.indexWhere((p) => p.id == postId);
    if (myIndex != -1) {
      _myPosts[myIndex] = updatePost(_myPosts[myIndex]);
    }

    final publicIndex = _posts.indexWhere((p) => p.id == postId);
    if (publicIndex != -1) {
      _posts[publicIndex] = updatePost(_posts[publicIndex]);
    }

    notifyListeners();
  }

  // ==================== SECRETARY POST ACTIONS ====================

  Future<Post?> acceptPost(String postId) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final post = await AnnouncementService.acceptPost(postId);

      final index = _posts.indexWhere((p) => p.id == postId);
      if (index != -1) {
        _posts[index] = post;
      }

      final myIndex = _myPosts.indexWhere((p) => p.id == postId);
      if (myIndex != -1) {
        _myPosts[myIndex] = post;
      }

      await loadStatusCounts();
      return post;
    } catch (e) {
      _error = e.toString();
      return null;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<Post?> rejectPost(String postId) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final post = await AnnouncementService.rejectPost(postId);

      final index = _posts.indexWhere((p) => p.id == postId);
      if (index != -1) {
        _posts[index] = post;
      }

      final myIndex = _myPosts.indexWhere((p) => p.id == postId);
      if (myIndex != -1) {
        _myPosts[myIndex] = post;
      }

      await loadStatusCounts();
      return post;
    } catch (e) {
      _error = e.toString();
      return null;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // ==================== UTILITY METHODS ====================

  void clearError() {
    _error = null;
    notifyListeners();
  }

  void reset() {
    _posts = [];
    _myPosts = [];
    _statusCounts = {};
    _error = null;
    _isLoading = false;
    _isLoadingMore = false;
    _hasMorePosts = true;
    _hasMoreMyPosts = true;
    _currentPage = 1;
    _currentMyPage = 1;
    _isLoadingPosts = false;
    _isLoadingMyPosts = false;
    _secretaryStatusFilter = 'PENDING';
    notifyListeners();
  }
}