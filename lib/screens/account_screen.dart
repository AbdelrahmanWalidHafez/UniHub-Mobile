import 'dart:typed_data';
import 'package:flutter/material.dart';
import '../services/auth_service.dart';
import '../services/affiliation_service.dart';
import '../services/token_service.dart';

class AccountScreen extends StatefulWidget {
  const AccountScreen({super.key});

  @override
  State<AccountScreen> createState() => _AccountScreenState();
}

class _AccountScreenState extends State<AccountScreen> {
  static const Color _lime = Color(0xFFB9FF66);
  static const Color _lightBg = Color(0xFFF8FAFB);

  bool _loadingUser = true;
  bool _loadingAffiliation = false;
  Map<String, dynamic>? _user;
  Map<String, dynamic>? _university;
  Map<String, dynamic>? _college;
  Uint8List? _logoBytes;

  final _newPasswordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  bool _showNewPassword = false;
  bool _showConfirmPassword = false;
  bool _savingPassword = false;
  String? _pwError;
  String? _pwSuccess;

  @override
  void initState() {
    super.initState();
    _loadUser();
  }

  @override
  void dispose() {
    _newPasswordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  Future<void> _loadUser() async {
    setState(() => _loadingUser = true);
    final data = await AuthService.getUserInfo();
    if (!mounted) return;
    setState(() {
      _user = data;
      _loadingUser = false;
    });
    if (data != null) {
      _loadAffiliation(data);
    }
  }

  /// Pulls an id out of a value that might be a raw id, or an object
  /// containing one of several possible id keys (mirrors the React
  /// `extractId` helper).
  dynamic _extractId(dynamic v) {
    if (v == null) return null;
    if (v is String || v is num) return v;
    if (v is Map) {
      return v['id'] ??
          v['college_id'] ??
          v['collegeId'] ??
          v['cid'] ??
          v['_id'] ??
          v['uid'] ??
          v['tid'];
    }
    return null;
  }

  Future<void> _loadAffiliation(Map<String, dynamic> user) async {
    final token = await TokenService.getAccessToken();
    if (token == null) return;

    final roleObj = user['role'];
    final roleName = (user['role_name'] ??
        user['roleName'] ??
        (roleObj is Map ? roleObj['name'] : null) ??
        '')
        .toString();

    final university = user['university'];
    final universityMap = university is Map ? university : null;

    final rawTid = user['tid'] ??
        user['university_id'] ??
        user['uniId'] ??
        user['universityId'] ??
        universityMap?['tid'] ??
        user['tenant_id'] ??
        user['tenantId'] ??
        universityMap?['id'];

    final rawCid = user['cid'] ??
        user['college_id'] ??
        user['collegeId'] ??
        universityMap?['cid'] ??
        universityMap?['college_id'];

    final tid = _extractId(rawTid);
    final cid = _extractId(rawCid);
    print('AFFILIATION DEBUG: tid=$tid, cid=$cid, token=${token.substring(0, 10)}...');

    if (tid == null && cid == null) {
      if (AffiliationService.enableLogging) {
        print('No tid/cid found on user object — skipping affiliation fetch. User keys: ${user.keys}');
      }
      return;
    }

    setState(() => _loadingAffiliation = true);

    if (tid != null) {
      final uni = await AffiliationService.getUniversity(tid.toString(), token);
      if (mounted) setState(() => _university = uni);
      if (uni != null && uni['logo_key'] != null) {
        final bytes = await AffiliationService.getFileBytes(uni['logo_key'].toString(), token);
        if (mounted && bytes != null) {
          setState(() => _logoBytes = Uint8List.fromList(bytes));
        }
      }
    }

    if (cid != null && roleName != 'ROLE_SYSTEM_ADMIN') {
      final col = await AffiliationService.getCollege(cid.toString(), token);
      if (mounted) setState(() => _college = col);
    }

    if (mounted) setState(() => _loadingAffiliation = false);
  }

  String _field(List<String> keys) {
    if (_user == null) return '';
    for (final k in keys) {
      final v = _user![k];
      if (v != null && v.toString().isNotEmpty) return v.toString();
    }
    return '';
  }

  /// Role comes back nested as `role: { rid, name }`, not as a flat
  /// `role_name` field, so this checks both shapes.
  String _getRoleName() {
    if (_user == null) return '';
    final flat = _user!['role_name'] ?? _user!['roleName'];
    if (flat != null && flat.toString().isNotEmpty) return flat.toString();

    final roleObj = _user!['role'];
    if (roleObj is Map) {
      final name = roleObj['name'];
      if (name != null) return name.toString();
    }
    return '';
  }

  String _formatRole(String r) {
    if (r.isEmpty) return '';
    var s = r.replaceFirst(RegExp(r'^ROLE_'), '').replaceAll('_', ' ');
    return s.split(' ').map((w) {
      if (w.isEmpty) return w;
      return w[0].toUpperCase() + w.substring(1).toLowerCase();
    }).join(' ');
  }

  String _formatDate(String raw) {
    if (raw.isEmpty) return '—';
    try {
      final dt = DateTime.parse(raw);
      return '${dt.month}/${dt.day}/${dt.year}, ${_formatTime(dt)}';
    } catch (_) {
      return raw;
    }
  }

  String _formatTime(DateTime dt) {
    final hour = dt.hour % 12 == 0 ? 12 : dt.hour % 12;
    final minute = dt.minute.toString().padLeft(2, '0');
    final period = dt.hour >= 12 ? 'PM' : 'AM';
    return '$hour:$minute $period';
  }

  Future<void> _submitPasswordChange() async {
    setState(() {
      _pwError = null;
      _pwSuccess = null;
    });

    final newPassword = _newPasswordController.text;
    final confirmPassword = _confirmPasswordController.text;

    final pwRegex = RegExp(r'^(?=.*[0-9])(?=.*[a-z])(?=.*[A-Z])(?=.*[@#$%^&+=!]).{8,}$');

    if (newPassword.isEmpty) {
      setState(() => _pwError = 'Password cannot be blank');
      return;
    }
    if (!pwRegex.hasMatch(newPassword)) {
      setState(() => _pwError =
      'Password must have uppercase, lowercase, digit, special character, and be at least 8 characters long.');
      return;
    }
    if (confirmPassword.isEmpty) {
      setState(() => _pwError = 'Confirm password cannot be blank');
      return;
    }
    if (newPassword != confirmPassword) {
      setState(() => _pwError = 'Passwords do not match');
      return;
    }

    setState(() => _savingPassword = true);
    final result = await AuthService.changePassword(newPassword, confirmPassword);
    if (!mounted) return;
    setState(() => _savingPassword = false);

    if (result['success'] == true) {
      setState(() {
        _pwSuccess = 'Password updated successfully';
        _pwError = null;
      });
      _newPasswordController.clear();
      _confirmPasswordController.clear();
    } else {
      setState(() {
        _pwError = result['message']?.toString() ?? 'Failed to change password';
        _pwSuccess = null;
      });
    }
  }

  void _clearPasswordForm() {
    _newPasswordController.clear();
    _confirmPasswordController.clear();
    setState(() {
      _pwError = null;
      _pwSuccess = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _lightBg,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        foregroundColor: Colors.black,
        title: const Text(
          'Account',
          style: TextStyle(fontWeight: FontWeight.bold, color: Colors.black),
        ),
      ),
      body: _loadingUser
          ? const Center(child: CircularProgressIndicator())
          : _user == null
          ? const Center(child: Text('Could not load account info.'))
          : RefreshIndicator(
        onRefresh: _loadUser,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildIdLine(),
              const SizedBox(height: 12),
              _buildProfileCard(),
              const SizedBox(height: 16),
              _buildAffiliationCard(),
              const SizedBox(height: 16),
              _buildMetadataCard(),
              const SizedBox(height: 16),
              _buildChangePasswordCard(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildIdLine() {
    final userId = _field(['user_id', 'userId', 'id']);
    if (userId.isEmpty) return const SizedBox.shrink();
    return Text(
      '#$userId',
      style: TextStyle(fontFamily: 'monospace', color: Colors.grey.shade600, fontSize: 12),
    );
  }

  Widget _sectionCard({required String title, required Widget child}) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE5E7EB)),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 8, offset: const Offset(0, 2)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
            decoration: const BoxDecoration(
              color: Color(0xFFFAFBFC),
              border: Border(bottom: BorderSide(color: Color(0xFFF3F4F6))),
            ),
            child: Row(
              children: [
                Container(width: 3, height: 16, color: _lime),
                const SizedBox(width: 10),
                Text(
                  title.toUpperCase(),
                  style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.black),
                ),
              ],
            ),
          ),
          Padding(padding: const EdgeInsets.all(20), child: child),
        ],
      ),
    );
  }

  Widget _infoItem(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label.toUpperCase(),
            style: TextStyle(fontSize: 11, color: Colors.grey.shade500, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 4),
          Text(
            value.isEmpty ? '—' : value,
            style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w500, color: Color(0xFF111827)),
          ),
        ],
      ),
    );
  }

  Widget _buildProfileCard() {
    final firstName = _field(['first_name', 'firstName']);
    final lastName = _field(['last_name', 'lastName']);
    final email = _field(['email', 'username']);
    final dob = _field(['date_of_birth', 'dob']);
    final gender = _field(['gender', 'sex']);
    final roleRaw = _getRoleName();
    final displayName = (firstName.isNotEmpty || lastName.isNotEmpty)
        ? '$firstName $lastName'.trim()
        : (email.isNotEmpty ? email : '—');

    return _sectionCard(
      title: 'Profile',
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 80,
            height: 80,
            decoration: const BoxDecoration(color: Color(0xFFF3F4F6), shape: BoxShape.circle),
            child: Center(
              child: Text(
                (displayName.isNotEmpty ? displayName[0] : 'U').toUpperCase(),
                style: TextStyle(fontSize: 32, fontWeight: FontWeight.bold, color: Colors.grey.shade500),
              ),
            ),
          ),
          const SizedBox(width: 20),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(displayName, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                const SizedBox(height: 14),
                Row(
                  children: [
                    Expanded(child: _infoItem('First name', firstName)),
                    Expanded(child: _infoItem('Last name', lastName)),
                  ],
                ),
                Row(
                  children: [
                    Expanded(child: _infoItem('Email', email)),
                    Expanded(child: _infoItem('Date of birth', dob)),
                  ],
                ),
                Row(
                  children: [
                    Expanded(child: _infoItem('Gender', gender)),
                    Expanded(child: _infoItem('Role', _formatRole(roleRaw))),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAffiliationCard() {
    final roleRaw = _getRoleName();
    final uniName = _university?['name']?.toString() ?? '';
    final collegeName = _college?['name']?.toString() ?? '';
    final campus = _college?['campus']?.toString() ?? '';

    return _sectionCard(
      title: 'Affiliation',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 50,
                height: 50,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: const Color(0xFFF3F4F6),
                  border: Border.all(color: const Color(0xFFE5E7EB)),
                  image: _logoBytes != null
                      ? DecorationImage(image: MemoryImage(_logoBytes!), fit: BoxFit.cover)
                      : null,
                ),
                child: _logoBytes == null
                    ? Center(
                  child: Text(
                    (uniName.isNotEmpty ? uniName[0] : '?').toUpperCase(),
                    style: TextStyle(fontSize: 18, color: Colors.grey.shade500, fontWeight: FontWeight.bold),
                  ),
                )
                    : null,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('UNIVERSITY', style: TextStyle(fontSize: 11, color: Colors.grey.shade500, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 4),
                    Text(
                      _loadingAffiliation ? 'Loading…' : (uniName.isEmpty ? '—' : uniName),
                      style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (roleRaw != 'ROLE_SYSTEM_ADMIN') ...[
            const SizedBox(height: 16),
            Text('COLLEGE', style: TextStyle(fontSize: 11, color: Colors.grey.shade500, fontWeight: FontWeight.bold)),
            const SizedBox(height: 4),
            Text(
              _loadingAffiliation ? 'Loading…' : (collegeName.isEmpty ? '—' : collegeName),
              style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 4),
            Text('Campus: ${campus.isEmpty ? '—' : campus}', style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
          ],
        ],
      ),
    );
  }

  Widget _buildMetadataCard() {
    final createdAt = _field(['created_at', 'createdAt']);
    final createdBy = _field(['created_by', 'createdBy']);
    final updatedAt = _field(['updated_at', 'updatedAt']);
    final updatedBy = _field(['updated_by', 'updatedBy']);

    Widget row(String label, String value) => Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: TextStyle(fontSize: 12, color: Colors.grey.shade500, fontWeight: FontWeight.bold)),
          Flexible(
            child: Text(
              value.isEmpty ? '—' : value,
              textAlign: TextAlign.right,
              style: const TextStyle(fontSize: 14),
            ),
          ),
        ],
      ),
    );

    return _sectionCard(
      title: 'Metadata',
      child: Column(
        children: [
          row('Created At', _formatDate(createdAt)),
          row('Created By', createdBy),
          row('Updated At', _formatDate(updatedAt)),
          row('Updated By', updatedBy),
        ],
      ),
    );
  }

  Widget _buildChangePasswordCard() {
    return _sectionCard(
      title: 'Change password',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (_pwSuccess != null)
            Container(
              margin: const EdgeInsets.only(bottom: 10),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: const Color(0xFFECFDF5),
                border: Border.all(color: const Color(0xFFD1FAE5)),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(_pwSuccess!, style: const TextStyle(color: Color(0xFF065F46))),
            ),
          if (_pwError != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Text(_pwError!, style: const TextStyle(color: Color(0xFFB91C1C), fontWeight: FontWeight.w600, fontSize: 13)),
            ),
          TextField(
            controller: _newPasswordController,
            obscureText: !_showNewPassword,
            decoration: InputDecoration(
              hintText: 'New password',
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
              suffixIcon: IconButton(
                icon: Icon(_showNewPassword ? Icons.visibility_off : Icons.visibility),
                onPressed: () => setState(() => _showNewPassword = !_showNewPassword),
              ),
            ),
          ),
          const SizedBox(height: 10),
          TextField(
            controller: _confirmPasswordController,
            obscureText: !_showConfirmPassword,
            decoration: InputDecoration(
              hintText: 'Confirm password',
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
              suffixIcon: IconButton(
                icon: Icon(_showConfirmPassword ? Icons.visibility_off : Icons.visibility),
                onPressed: () => setState(() => _showConfirmPassword = !_showConfirmPassword),
              ),
            ),
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              ElevatedButton(
                onPressed: _savingPassword ? null : _submitPasswordChange,
                style: ElevatedButton.styleFrom(
                  backgroundColor: _lime,
                  foregroundColor: Colors.black,
                  elevation: 0,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
                child: _savingPassword
                    ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2, color: Colors.black),
                )
                    : const Text('Save', style: TextStyle(fontWeight: FontWeight.bold)),
              ),
              const SizedBox(width: 10),
              OutlinedButton(
                onPressed: _savingPassword ? null : _clearPasswordForm,
                style: OutlinedButton.styleFrom(
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
                child: const Text('Clear'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}