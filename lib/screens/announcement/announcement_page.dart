import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/announcement_provider.dart';
import '../../providers/auth_provider.dart';
import '../../models/post_model.dart';
import 'create_post_screen.dart';
import 'post_detail_screen.dart';
import 'widgets/post_card.dart';

class AnnouncementPage extends StatefulWidget {
  final bool isSecretary;

  const AnnouncementPage({
    super.key,
    this.isSecretary = false,
  });

  @override
  State<AnnouncementPage> createState() => _AnnouncementPageState();
}

class _AnnouncementPageState extends State<AnnouncementPage> {
  final ScrollController _scrollController = ScrollController();
  bool _showMyPosts = false;

  static const Color _lime = Color(0xFFB9FF66);
  static const Color _lightBg = Color(0xFFF8FAFB);

  // List of random colors for avatars
  static const List<Color> _avatarColors = [
    Color(0xFFE57373), // Red
    Color(0xFFF06292), // Pink
    Color(0xFFBA68C8), // Purple
    Color(0xFF7986CB), // Indigo
    Color(0xFF64B5F6), // Blue
    Color(0xFF4DD0E1), // Cyan
    Color(0xFF4DB6AC), // Teal
    Color(0xFF81C784), // Green
    Color(0xFFAED581), // Light Green
    Color(0xFFFFD54F), // Yellow
    Color(0xFFFFB74D), // Orange
    Color(0xFFA1887F), // Brown
    Color(0xFF90A4AE), // Blue Grey
  ];

  // Cache to store colors per user
  final Map<String, Color> _userColorCache = {};

  Color _getUserColor(String userName) {
    if (_userColorCache.containsKey(userName)) {
      return _userColorCache[userName]!;
    }
    // Generate a consistent color based on the username
    final index = userName.hashCode.abs() % _avatarColors.length;
    final color = _avatarColors[index];
    _userColorCache[userName] = color;
    return color;
  }

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadData();
    });
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _loadData() {
    final provider = context.read<AnnouncementProvider>();
    if (widget.isSecretary) {
      provider.loadSecretaryPosts(refresh: true);
    } else if (_showMyPosts) {
      provider.loadMyPosts(refresh: true);
    } else {
      provider.loadPosts(refresh: true);
    }
    if (!widget.isSecretary) {
      provider.loadStatusCounts();
    }
  }

  void _onScroll() {
    if (_scrollController.position.pixels >=
        _scrollController.position.maxScrollExtent - 200) {
      final provider = context.read<AnnouncementProvider>();
      if (widget.isSecretary) {
        if (!provider.isLoading && provider.hasMorePosts) {
          provider.loadSecretaryPosts();
        }
      } else if (_showMyPosts) {
        if (!provider.isLoading && provider.hasMoreMyPosts) {
          provider.loadMyPosts();
        }
      } else {
        if (!provider.isLoading && provider.hasMorePosts) {
          provider.loadPosts();
        }
      }
    }
  }

  void _toggleView() {
    setState(() {
      _showMyPosts = !_showMyPosts;
    });
    _loadData();
  }

  Future<void> _refresh() async {
    final provider = context.read<AnnouncementProvider>();
    if (widget.isSecretary) {
      await provider.loadSecretaryPosts(refresh: true);
    } else if (_showMyPosts) {
      await provider.loadMyPosts(refresh: true);
    } else {
      await provider.loadPosts(refresh: true);
    }
    if (!widget.isSecretary) {
      await provider.loadStatusCounts();
    }
  }

  List<Post> _currentList(AnnouncementProvider provider) {
    if (widget.isSecretary) return provider.posts;
    if (_showMyPosts) return provider.myPosts;
    return provider.posts;
  }

  @override
  Widget build(BuildContext context) {
    final authProvider = context.watch<AuthProvider>();
    final provider = context.watch<AnnouncementProvider>();
    final displayList = _currentList(provider);

    return Scaffold(
      backgroundColor: _lightBg,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        centerTitle: false,
        actions: [
          if (!widget.isSecretary) ...[
            IconButton(
              icon: const Icon(Icons.add, color: Colors.black87),
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const CreatePostScreen()),
                ).then((_) => _refresh());
              },
            ),
            IconButton(
              icon: Icon(
                _showMyPosts ? Icons.public : Icons.person,
                color: Colors.black87,
              ),
              onPressed: _toggleView,
              tooltip: _showMyPosts ? 'View all posts' : 'View my posts',
            ),
          ],
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _refresh,
        color: _lime,
        child: Column(
          children: [
            if (!widget.isSecretary && _showMyPosts)
              _buildStatusCards(provider),
            if (widget.isSecretary) _buildSecretaryFilterBar(provider),
            Expanded(
              child: _buildPostsList(context, authProvider, provider, displayList),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPostsList(
      BuildContext context,
      AuthProvider authProvider,
      AnnouncementProvider provider,
      List<Post> displayList,
      ) {
    if (provider.isLoading && displayList.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }

    if (displayList.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                color: Colors.grey.shade100,
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.forum_outlined, size: 40, color: Colors.grey),
            ),
            const SizedBox(height: 16),
            const Text(
              'No posts yet',
              style: TextStyle(color: Colors.grey),
            ),
            const SizedBox(height: 8),
            if (!widget.isSecretary)
              Text(
                'Tap + to create your first post',
                style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
              ),
          ],
        ),
      );
    }

    return ListView.builder(
      controller: _scrollController,
      padding: const EdgeInsets.all(12),
      itemCount: displayList.length + (provider.isLoadingMore ? 1 : 0),
      itemBuilder: (context, index) {
        if (index == displayList.length) {
          return const Padding(
            padding: EdgeInsets.all(16),
            child: Center(
              child: SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            ),
          );
        }

        final post = displayList[index];
        final isOwner = post.createdBy == authProvider.userEmail ||
            post.displayName == authProvider.userName ||
            post.createdBy.split('@').first == authProvider.userName;

        return PostCard(
          post: post,
          isSecretary: widget.isSecretary,
          isOwner: isOwner,
          avatarColor: _getUserColor(post.displayName), // Added this
          onLike: () async {
            await provider.toggleLike(post.id);
          },
          onComment: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => PostDetailScreen(
                  postId: post.id,
                  post: post,
                ),
              ),
            ).then((_) => _refresh());
          },
          onEdit: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => CreatePostScreen(postToEdit: post),
              ),
            ).then((_) => _refresh());
          },
          onDelete: () async {
            final confirmed = await _showDeleteDialog(context);
            if (confirmed == true) {
              if (widget.isSecretary) {
                await provider.deletePostSecretary(post.id);
              } else {
                await provider.deletePost(post.id);
              }
              _refresh();
            }
          },
          onPublish: () async {
            await provider.publishPost(post.id);
            _refresh();
          },
          onAccept: widget.isSecretary && post.status == PostStatus.pending
              ? () async {
            await provider.acceptPost(post.id);
            _refresh();
          }
              : null,
          onReject: widget.isSecretary && post.status == PostStatus.pending
              ? () async {
            await provider.rejectPost(post.id);
            _refresh();
          }
              : null,
        );
      },
    );
  }

  Future<bool?> _showDeleteDialog(BuildContext context) {
    return showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Delete Post', style: TextStyle(color: Colors.black87)),
        content: const Text(
          'Are you sure you want to delete this post?',
          style: TextStyle(color: Colors.grey),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text('Cancel', style: TextStyle(color: Colors.grey.shade600)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  Widget _buildSecretaryFilterBar(AnnouncementProvider provider) {
    const statuses = ['PENDING', 'ACCEPTED', 'REJECTED'];
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: Row(
        children: statuses.map((status) {
          final isSelected = provider.secretaryStatusFilter == status;
          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: FilterChip(
              label: Text(
                status[0] + status.substring(1).toLowerCase(),
                style: TextStyle(
                  color: isSelected ? Colors.white : Colors.black87,
                  fontWeight: FontWeight.w600,
                ),
              ),
              selected: isSelected,
              onSelected: (_) {
                provider.setSecretaryStatusFilter(status);
                _refresh();
              },
              selectedColor: status == 'PENDING' ? Colors.orange : (status == 'ACCEPTED' ? Colors.green : Colors.red),
              backgroundColor: Colors.grey.shade100,
              checkmarkColor: Colors.white,
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildStatusCards(AnnouncementProvider provider) {
    final accepted = provider.statusCounts['ACCEPTED'] ?? 0;
    final pending = provider.statusCounts['PENDING'] ?? 0;
    final rejected = provider.statusCounts['REJECTED'] ?? 0;
    final drafts = provider.statusCounts['DRAFT'] ?? 0;

    return Container(
      margin: const EdgeInsets.all(12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.1),
            spreadRadius: 1,
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                width: 4,
                height: 20,
                decoration: BoxDecoration(
                  color: _lime,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(width: 8),
              const Text(
                'Your Posts Summary',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.black87),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              _buildStatusChip('Published', accepted, Colors.green),
              const SizedBox(width: 8),
              _buildStatusChip('Pending', pending, Colors.orange),
              const SizedBox(width: 8),
              _buildStatusChip('Rejected', rejected, Colors.red),
              const SizedBox(width: 8),
              _buildStatusChip('Drafts', drafts, Colors.grey),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStatusChip(String label, int count, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 8),
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Column(
          children: [
            Text(
              count.toString(),
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
            Text(
              label,
              style: TextStyle(fontSize: 12, color: color),
            ),
          ],
        ),
      ),
    );
  }
}