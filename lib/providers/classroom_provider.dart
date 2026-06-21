import 'package:flutter/material.dart';
import 'dart:io';
import '../models/classroom/classroom_model.dart';
import '../models/classroom/material_model.dart';
import '../models/classroom/comment_model.dart';
import '../services/classroom_service.dart';

class ClassroomProvider extends ChangeNotifier {
  List<Classroom> _enrolledClasses = [];
  List<Classroom> _teachingClasses = [];
  List<Classroom> _archivedClasses = [];
  List<ClassroomMaterial> _materials = [];
  List<ClassroomMaterial> _assignments = [];
  List<ClassroomComment> _comments = [];
  List<Member> _members = [];
  Owner? _owner;

  bool _isLoading = false;
  bool _isLoadingMore = false;
  bool _hasMoreMaterials = true;
  bool _hasMoreComments = true;
  String? _error;

  int _materialsPage = 1;
  int _commentsPage = 1;
  int _membersPage = 1;
  bool _hasMoreMembers = true;

  List<Classroom> get enrolledClasses => _enrolledClasses;
  List<Classroom> get teachingClasses => _teachingClasses;
  List<Classroom> get archivedClasses => _archivedClasses;
  List<ClassroomMaterial> get materials => _materials;
  List<ClassroomMaterial> get assignments => _assignments;
  List<ClassroomComment> get comments => _comments;
  List<Member> get members => _members;
  Owner? get owner => _owner;
  bool get isLoading => _isLoading;
  bool get isLoadingMore => _isLoadingMore;
  bool get hasMoreMaterials => _hasMoreMaterials;
  bool get hasMoreMembers => _hasMoreMembers;
  String? get error => _error;

  // ==================== CLASSROOM METHODS ====================

  Future<void> loadEnrolledClasses({bool refresh = false}) async {
    if (!refresh && _isLoading) return;

    if (refresh) {
      _enrolledClasses = [];
      _isLoading = true;
      _error = null;
      notifyListeners();
    }

    try {
      final classes = await ClassroomService.getEnrolledClasses();
      _enrolledClasses = classes;
    } catch (e) {
      _error = e.toString();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> loadTeachingClasses({bool refresh = false}) async {
    if (!refresh && _isLoading) return;

    if (refresh) {
      _teachingClasses = [];
      _isLoading = true;
      _error = null;
      notifyListeners();
    }

    try {
      final classes = await ClassroomService.getActiveClasses();
      _teachingClasses = classes;
    } catch (e) {
      _error = e.toString();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> loadArchivedClasses({bool refresh = false}) async {
    if (!refresh && _isLoading) return;

    if (refresh) {
      _archivedClasses = [];
      _isLoading = true;
      _error = null;
      notifyListeners();
    }

    try {
      final classes = await ClassroomService.getArchivedClasses();
      _archivedClasses = classes;
    } catch (e) {
      _error = e.toString();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<Classroom?> createClassroom(
      String classTitle, String classSubTitle) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final classroom =
      await ClassroomService.createClassroom(classTitle, classSubTitle);
      // Add to the top of teaching list immediately so UI updates
      _teachingClasses.insert(0, classroom);
      return classroom;
    } catch (e) {
      _error = e.toString();
      return null;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> joinClassroom(String code) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      await ClassroomService.joinClassroom(code);
      _isLoading = false;
      notifyListeners();
      await loadEnrolledClasses(refresh: true);
    } catch (e) {
      _error = e.toString();
      _isLoading = false;
      notifyListeners();
      rethrow;
    }
  }

  Future<void> leaveClassroom(String classroomId) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      await ClassroomService.leaveClassroom(classroomId);
      _enrolledClasses.removeWhere((c) => c.id == classroomId);
      _teachingClasses.removeWhere((c) => c.id == classroomId);
    } catch (e) {
      _error = e.toString();
      rethrow;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // ==================== MATERIAL METHODS ====================

  Future<void> loadMaterials(String classroomId, {bool refresh = false}) async {
    if (!refresh && _isLoading) return;

    if (refresh) {
      _materialsPage = 1;
      _materials = [];
      _hasMoreMaterials = true;
    }

    if (!_hasMoreMaterials && !refresh) return;

    _isLoading = true;
    _isLoadingMore = !refresh && _materials.isNotEmpty;
    _error = null;
    notifyListeners();

    try {
      final newMaterials = await ClassroomService.getAllMaterials(
        classroomId,
        pageNum: _materialsPage,
      );

      if (refresh) {
        _materials = newMaterials;
      } else {
        _materials.addAll(newMaterials);
      }

      _hasMoreMaterials = newMaterials.isNotEmpty;
      if (newMaterials.isNotEmpty) {
        _materialsPage++;
      }
    } catch (e) {
      _error = e.toString();
    } finally {
      _isLoading = false;
      _isLoadingMore = false;
      notifyListeners();
    }
  }

  Future<void> loadAssignments(String classroomId, {bool refresh = false}) async {
    if (!refresh && _isLoading) return;

    if (refresh) {
      _assignments = [];
      _isLoading = true;
    }

    _error = null;
    notifyListeners();

    try {
      final newAssignments = await ClassroomService.getAllAssignments(classroomId);
      _assignments = newAssignments;
    } catch (e) {
      _error = e.toString();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<ClassroomMaterial?> createAnnouncement(
      String classroomId,
      String headLine,
      String description,
      List<File>? files,
      ) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final material = await ClassroomService.createAnnouncement(
        classroomId,
        headLine,
        description,
        files,
      );
      _materials.insert(0, material);
      return material;
    } catch (e) {
      _error = e.toString();
      return null;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // ==================== MEMBER METHODS ====================

  Future<void> loadMembers(String classroomId, {bool refresh = false}) async {
    if (!refresh && _isLoading) return;

    if (refresh) {
      _membersPage = 1;
      _members = [];
      _hasMoreMembers = true;
    }

    if (!_hasMoreMembers && !refresh) return;

    _isLoading = true;
    _isLoadingMore = !_isLoading && !refresh;
    _error = null;
    notifyListeners();

    try {
      final newMembers = await ClassroomService.getMembers(
        classroomId,
        pageNum: _membersPage,
      );

      if (refresh) {
        _members = newMembers;
      } else {
        _members.addAll(newMembers);
      }

      _hasMoreMembers = newMembers.length >= 10;
      if (newMembers.isNotEmpty) {
        _membersPage++;
      }
    } catch (e) {
      _error = e.toString();
    } finally {
      _isLoading = false;
      _isLoadingMore = false;
      notifyListeners();
    }
  }

  Future<void> loadOwner(String classroomId) async {
    try {
      _owner = await ClassroomService.getOwner(classroomId);
      notifyListeners();
    } catch (e) {
      // Silent fail
    }
  }

  // ==================== COMMENT METHODS ====================

  Future<void> loadComments(String materialId, {bool refresh = false}) async {
    if (!refresh && _isLoading) return;

    if (refresh) {
      _commentsPage = 1;
      _comments = [];
      _hasMoreComments = true;
    }

    if (!_hasMoreComments && !refresh) return;

    _isLoading = true;
    _isLoadingMore = !_isLoading && !refresh;
    _error = null;
    notifyListeners();

    try {
      final newComments = await ClassroomService.getComments(
        materialId,
        pageNum: _commentsPage,
      );

      if (refresh) {
        _comments = newComments;
      } else {
        _comments.addAll(newComments);
      }

      _hasMoreComments = newComments.isNotEmpty;
      if (newComments.isNotEmpty) {
        _commentsPage++;
      }
    } catch (e) {
      _error = e.toString();
    } finally {
      _isLoading = false;
      _isLoadingMore = false;
      notifyListeners();
    }
  }

  Future<ClassroomComment?> createComment(String materialId, String content) async {
    try {
      final comment = await ClassroomService.createComment(materialId, content);
      _comments.insert(0, comment);
      notifyListeners();
      return comment;
    } catch (e) {
      _error = e.toString();
      return null;
    }
  }

  Future<bool> deleteComment(String commentId) async {
    try {
      await ClassroomService.deleteComment(commentId);
      _comments.removeWhere((c) => c.id == commentId);
      notifyListeners();
      return true;
    } catch (e) {
      _error = e.toString();
      return false;
    }
  }

  // ==================== UTILITY ====================

  void reset() {
    _enrolledClasses = [];
    _teachingClasses = [];
    _archivedClasses = [];
    _materials = [];
    _assignments = [];
    _comments = [];
    _members = [];
    _owner = null;
    _materialsPage = 1;
    _commentsPage = 1;
    _membersPage = 1;
    _hasMoreMaterials = true;
    _hasMoreComments = true;
    _hasMoreMembers = true;
    _isLoading = false;
    _isLoadingMore = false;
    _error = null;
    notifyListeners();
  }

  void clearError() {
    _error = null;
    notifyListeners();
  }
}