import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../../core/models/recommendation_models.dart';
import '../../../../core/services/favorites_service.dart';
import '../../../../core/services/music_player_service.dart';
import '../../../../core/services/recommendation_service.dart';
import '../../../../core/theme/app_pallete.dart';
import '../../../auth/model/user_model.dart';
import '../../../auth/repositories/auth_local_repository.dart';
import '../../../auth/view/pages/login_page.dart';
import '../../../favorites/view/pages/liked_songs_page.dart';
import '../../../search/model/song_model.dart';
import '../../../search/view/pages/search_page.dart';
import 'offline_songs_page.dart';
import '../widgets/add_friend_bar.dart';
import '../widgets/friend_card.dart';
import '../widgets/mini_player.dart';
import '../widgets/quick_action_card.dart';
import '../widgets/room_action_button.dart';

class HomePage extends StatefulWidget {
  final UserModel? user;

  const HomePage({super.key, this.user});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage>
    with SingleTickerProviderStateMixin {
  UserModel? _currentUser;
  int _currentNavIndex = 0;

  HomepageResponseModel? _homepageData;
  List<HomepageSectionModel> _homepageSections = [];
  bool _isLoadingRecommendations = false;
  int _refreshSeed = 0;
  late final AnimationController _refreshSpinController;
  UserPreferenceProfileModel? _userTasteProfile;
  bool _isLoadingTasteProfile = false;

  final List<FriendModel> _friends = const [
    FriendModel(
      id: '1',
      name: 'Sarah',
      currentSong: 'Believer',
      artist: 'Imagine Dragons',
      isOnline: true,
      avatarGradient: [Color(0xFF8E2DE2), Color(0xFF4A00E0)],
    ),
    FriendModel(
      id: '2',
      name: 'Devon',
      currentSong: 'Starboy',
      artist: 'The Weeknd',
      isOnline: true,
      avatarGradient: [Color(0xFFFF416C), Color(0xFFFF4B2B)],
    ),
    FriendModel(
      id: '3',
      name: 'Aarav',
      currentSong: 'Blinding Lights',
      artist: 'The Weeknd',
      isOnline: true,
      avatarGradient: [Color(0xFF11998E), Color(0xFF38EF7D)],
    ),
    FriendModel(
      id: '4',
      name: 'Elena',
      currentSong: 'Offline',
      artist: '',
      isOnline: false,
      avatarGradient: [Color(0xFF606C38), Color(0xFF283618)],
    ),
    FriendModel(
      id: '5',
      name: 'Marcus',
      currentSong: 'Levitating',
      artist: 'Dua Lipa',
      isOnline: true,
      avatarGradient: [Color(0xFFF7971E), Color(0xFFFFD200)],
    ),
  ];

  @override
  void initState() {
    super.initState();
    _refreshSpinController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    );
    _currentUser = widget.user;
    if (_currentUser == null) {
      _loadCachedUser();
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      FavoritesService().fetchLikedSongs();
      _fetchRecommendations();
      _fetchTasteProfile();
    });
  }

  @override
  void dispose() {
    _refreshSpinController.dispose();
    super.dispose();
  }

  Future<void> _fetchRecommendations({bool isRefresh = false}) async {
    if (isRefresh) {
      _refreshSpinController.repeat();
    }
    setState(() => _isLoadingRecommendations = true);
    try {
      final userId = await AuthLocalRepository().getEffectiveUserId();
      final response = await RecommendationService().getHomepageRecommendations(
        userId: userId,
        limit: 16,
        forceRefresh: isRefresh,
      );
      if (mounted) {
        if (isRefresh) {
          _refreshSeed++;
        }

        final sections = response?.sections ?? [];
        final processedSections = sections.map((sec) {
          if (sec.songs.length > 5 && isRefresh) {
            final rotated = List<RecommendedSongModel>.from(sec.songs);
            final offset = (_refreshSeed * 4) % rotated.length;
            final sublist = [
              ...rotated.sublist(offset),
              ...rotated.sublist(0, offset),
            ];
            return HomepageSectionModel(
              id: sec.id,
              title: sec.title,
              subtitle: sec.subtitle,
              seedSong: sec.seedSong,
              songs: sublist,
            );
          }
          return sec;
        }).toList();

        setState(() {
          _homepageData = response;
          _homepageSections = processedSections;
          _isLoadingRecommendations = false;
        });

        if (isRefresh) {
          _refreshSpinController.stop();
          _refreshSpinController.reset();
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Recommendations refreshed!'),
              duration: Duration(milliseconds: 1200),
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
      }
    } catch (_) {
      if (mounted) {
        _refreshSpinController.stop();
        _refreshSpinController.reset();
        setState(() => _isLoadingRecommendations = false);
      }
    }
  }

  Future<void> _fetchTasteProfile() async {
    setState(() => _isLoadingTasteProfile = true);
    try {
      final userId = await AuthLocalRepository().getEffectiveUserId();
      final profile = await RecommendationService().getUserPreferences(userId);
      if (mounted) {
        setState(() {
          _userTasteProfile = profile;
          _isLoadingTasteProfile = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _isLoadingTasteProfile = false);
    }
  }

  Future<void> _loadCachedUser() async {
    final cached = await AuthLocalRepository().getUser();
    if (mounted && cached != null) {
      setState(() {
        _currentUser = cached;
      });
    }
  }

  String _getGreeting() {
    final hour = DateTime.now().hour;
    if (hour < 12) {
      return 'Good Morning';
    } else if (hour < 17) {
      return 'Good Afternoon';
    } else {
      return 'Good Evening';
    }
  }

  Future<void> _handleLogout() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Pallete.cardColor,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text(
          'Log Out',
          style: TextStyle(
            color: Pallete.whiteColor,
            fontWeight: FontWeight.bold,
          ),
        ),
        content: const Text(
          'Are you sure you want to log out of your account?',
          style: TextStyle(color: Pallete.subtitleText),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text(
              'Cancel',
              style: TextStyle(color: Pallete.greyColor),
            ),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Pallete.errorColor,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Log Out', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      await AuthLocalRepository().clear();
      if (!mounted) return;
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (context) => const SigninPage()),
        (route) => false,
      );
    }
  }

  static const _appChannel = MethodChannel('com.example.client/app');

  Future<void> _handleBackPress() async {
    if (_currentNavIndex != 0) {
      setState(() {
        _currentNavIndex = 0;
      });
      return;
    }

    try {
      await _appChannel.invokeMethod('moveToBackground');
    } catch (_) {
      await SystemNavigator.pop();
    }
  }

  void _showCreateRoomDialog() {
    final roomCode = 'JAM-${1000 + Random().nextInt(9000)}';
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Pallete.cardColor,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(
          children: [
            Icon(Icons.sensors_rounded, color: Pallete.gradient2),
            SizedBox(width: 8),
            Text(
              'Create Jam Room',
              style: TextStyle(
                color: Pallete.whiteColor,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Share this code with your friends to listen together in sync:',
              style: TextStyle(color: Pallete.subtitleText, fontSize: 13),
            ),
            const SizedBox(height: 16),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 14),
              decoration: BoxDecoration(
                color: Pallete.backgroundColor,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: Pallete.gradient1.withAlpha(150)),
              ),
              child: Center(
                child: Text(
                  roomCode,
                  style: const TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: Pallete.gradient2,
                    letterSpacing: 3,
                  ),
                ),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text(
              'Close',
              style: TextStyle(color: Pallete.subtitleText),
            ),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Pallete.gradient1,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            onPressed: () {
              Navigator.pop(ctx);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('Room code $roomCode copied to clipboard!'),
                ),
              );
            },
            child: const Text(
              'Copy Code',
              style: TextStyle(color: Colors.white),
            ),
          ),
        ],
      ),
    );
  }

  void _showJoinRoomDialog() {
    final codeController = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Pallete.cardColor,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(
          children: [
            Icon(Icons.group_add_rounded, color: Pallete.gradient1),
            SizedBox(width: 8),
            Text(
              'Join Room',
              style: TextStyle(
                color: Pallete.whiteColor,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              "Enter your friend's 6-character room code:",
              style: TextStyle(color: Pallete.subtitleText, fontSize: 13),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: codeController,
              textCapitalization: TextCapitalization.characters,
              style: const TextStyle(
                color: Pallete.whiteColor,
                fontWeight: FontWeight.bold,
              ),
              decoration: InputDecoration(
                hintText: 'e.g. JAM-8921',
                hintStyle: const TextStyle(color: Pallete.subtitleText),
                filled: true,
                fillColor: Pallete.backgroundColor,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text(
              'Cancel',
              style: TextStyle(color: Pallete.subtitleText),
            ),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Pallete.gradient2,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            onPressed: () {
              final code = codeController.text.trim();
              Navigator.pop(ctx);
              if (code.isNotEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Joined Room $code! Syncing audio stream...'),
                  ),
                );
              }
            },
            child: const Text('Join', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  void _handleAddFriend(String username) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Friend request sent to $username!'),
        backgroundColor: Pallete.cardColor,
      ),
    );
  }

  void _handleTuneIn(FriendModel friend) {
    final demoSong = SongModel(
      id: 'friend_${friend.id}',
      song: friend.currentSong,
      album: 'Shared Stream',
      primaryArtists: friend.artist,
      singers: friend.artist,
      duration: 180,
      image: '',
      mediaUrl: '',
      mediaPreviewUrl: '',
      year: '2026',
      language: 'English',
      hasLyrics: false,
    );
    MusicPlayerService().playSong(demoSong);

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Tuned in with ${friend.name} • ${friend.currentSong}'),
        backgroundColor: Pallete.cardColor,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final greeting = _getGreeting();
    final displayName = _currentUser?.name.isNotEmpty == true
        ? _currentUser!.name
        : 'Dinto';

    return Scaffold(
      backgroundColor: Pallete.backgroundColor,
      body: PopScope(
        canPop: false,
        onPopInvokedWithResult: (didPop, result) {
          if (didPop) return;
          _handleBackPress();
        },
        child: SafeArea(
          child: Column(
            children: [
              Expanded(child: _buildCurrentTab(displayName, greeting)),

              // Persistent Mini Player across all tabs
              const MiniPlayer(),
            ],
          ),
        ),
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentNavIndex,
        onTap: (index) {
          setState(() {
            _currentNavIndex = index;
          });
        },
        type: BottomNavigationBarType.fixed,
        backgroundColor: Pallete.backgroundColor,
        selectedItemColor: Pallete.whiteColor,
        unselectedItemColor: Pallete.inactiveBottomBarItemColor,
        selectedLabelStyle: const TextStyle(
          fontWeight: FontWeight.w600,
          fontSize: 12,
        ),
        unselectedLabelStyle: const TextStyle(fontSize: 12),
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.home_filled), label: 'Home'),
          BottomNavigationBarItem(
            icon: Icon(Icons.search_rounded),
            label: 'Search',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.library_music_rounded),
            label: 'Your Library',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.person_outline_rounded),
            label: 'Profile',
          ),
        ],
      ),
    );
  }

  Widget _buildCurrentTab(String displayName, String greeting) {
    switch (_currentNavIndex) {
      case 1:
        return const SearchPage();
      case 2:
        return _buildLibraryView();
      case 3:
        return _buildProfileView(displayName);
      case 0:
      default:
        return _buildHomeFeed(displayName, greeting);
    }
  }

  Widget _buildHomeFeed(String displayName, String greeting) {
    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header Container with curved bottom arch (matching the sketch curve)
          Container(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 22),
            decoration: BoxDecoration(
              color: Pallete.cardColor,
              borderRadius: const BorderRadius.vertical(
                bottom: Radius.elliptical(200, 30),
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withAlpha(120),
                  blurRadius: 16,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    CircleAvatar(
                      radius: 24,
                      backgroundColor: Pallete.gradient1,
                      child: Text(
                        displayName.isNotEmpty
                            ? displayName[0].toUpperCase()
                            : 'D',
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 20,
                        ),
                      ),
                    ),
                    const SizedBox(width: 14),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          greeting,
                          style: const TextStyle(
                            fontSize: 14,
                            color: Pallete.subtitleText,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        Text(
                          displayName,
                          style: const TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.bold,
                            color: Pallete.whiteColor,
                            letterSpacing: -0.5,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
                Row(
                  children: [
                    IconButton(
                      onPressed: () {},
                      icon: const Icon(
                        Icons.notifications_none_rounded,
                        color: Pallete.whiteColor,
                      ),
                    ),
                    IconButton(
                      onPressed: _handleLogout,
                      tooltip: 'Log out',
                      icon: const Icon(
                        Icons.logout_rounded,
                        color: Pallete.errorColor,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          const SizedBox(height: 18),

          // 2x2 Quick Action Cards: Liked Song, Playlist, Offline Play, Shuffle
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0),
            child: GridView.count(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              crossAxisCount: 2,
              crossAxisSpacing: 12,
              mainAxisSpacing: 12,
              childAspectRatio: 2.3,
              children: [
                QuickActionCard(
                  title: 'Liked Song',
                  icon: Icons.favorite_rounded,
                  gradientColors: const [Pallete.gradient1, Pallete.gradient2],
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const LikedSongsPage(),
                      ),
                    );
                  },
                ),
                QuickActionCard(
                  title: 'Playlist',
                  icon: Icons.queue_music_rounded,
                  gradientColors: const [Color(0xFF8E2DE2), Color(0xFF4A00E0)],
                  onTap: () {
                    setState(() => _currentNavIndex = 2);
                  },
                ),
                QuickActionCard(
                  title: 'Offline Play',
                  icon: Icons.cloud_download_rounded,
                  gradientColors: const [Color(0xFF11998E), Color(0xFF38EF7D)],
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const OfflineSongsPage(),
                      ),
                    );
                  },
                ),
                QuickActionCard(
                  title: 'Shuffle',
                  icon: Icons.shuffle_rounded,
                  gradientColors: const [Color(0xFFFF416C), Color(0xFFFF4B2B)],
                  onTap: () {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Shuffling all songs...')),
                    );
                  },
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),

          // Section: Recommended For You (AI-powered personalized recommendations)
          _buildRecommendationsSection(),

          const SizedBox(height: 24),

          // Section 2: Listen with Friends
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 16.0),
            child: Text(
              'Listen with Friends',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Pallete.whiteColor,
                letterSpacing: -0.5,
              ),
            ),
          ),
          const SizedBox(height: 12),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0),
            child: Row(
              children: [
                RoomActionButton(
                  label: 'Create Room',
                  icon: Icons.sensors_rounded,
                  isPrimary: true,
                  onTap: _showCreateRoomDialog,
                ),
                const SizedBox(width: 12),
                RoomActionButton(
                  label: 'Join Room',
                  icon: Icons.group_add_rounded,
                  isPrimary: false,
                  onTap: _showJoinRoomDialog,
                ),
              ],
            ),
          ),

          const SizedBox(height: 24),

          // Section 3: Add Friend :
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 16.0),
            child: Text(
              'Add Friend :',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Pallete.whiteColor,
                letterSpacing: -0.5,
              ),
            ),
          ),
          const SizedBox(height: 10),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0),
            child: AddFriendBar(onAdd: _handleAddFriend),
          ),

          const SizedBox(height: 24),

          // Section 4: Friends :-
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 16.0),
            child: Text(
              'Friends :-',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Pallete.whiteColor,
                letterSpacing: -0.5,
              ),
            ),
          ),
          const SizedBox(height: 12),
          SizedBox(
            height: 180,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              physics: const BouncingScrollPhysics(),
              padding: const EdgeInsets.symmetric(horizontal: 16),
              itemCount: _friends.length,
              itemBuilder: (context, index) {
                final friend = _friends[index];
                return FriendCard(
                  friend: friend,
                  onListenAlong: () => _handleTuneIn(friend),
                );
              },
            ),
          ),

          const SizedBox(height: 24),
        ],
      ),
    );
  }

  Widget _buildLibraryView() {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Your Library',
            style: TextStyle(
              fontSize: 32,
              fontWeight: FontWeight.bold,
              color: Pallete.whiteColor,
              letterSpacing: -0.5,
            ),
          ),
          const SizedBox(height: 20),
          Expanded(
            child: ListView(
              physics: const BouncingScrollPhysics(),
              children: [
                _buildLibraryTile(
                  title: 'Liked Songs',
                  subtitle: 'Playlist • Auto-saved favorites',
                  icon: Icons.favorite_rounded,
                  colors: const [Pallete.gradient1, Pallete.gradient2],
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const LikedSongsPage(),
                      ),
                    );
                  },
                ),
                _buildLibraryTile(
                  title: 'Recent Searches',
                  subtitle: 'History • Recently discovered tracks',
                  icon: Icons.history_rounded,
                  colors: const [Color(0xFF00B4DB), Color(0xFF0083B0)],
                ),
                _buildLibraryTile(
                  title: 'Top Hits Mixtape',
                  subtitle: 'Custom playlist • 24 tracks',
                  icon: Icons.queue_music_rounded,
                  colors: const [Color(0xFFFF416C), Color(0xFFFF4B2B)],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLibraryTile({
    required String title,
    required String subtitle,
    required IconData icon,
    required List<Color> colors,
    VoidCallback? onTap,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      child: Material(
        color: Pallete.cardColor,
        borderRadius: BorderRadius.circular(10),
        clipBehavior: Clip.antiAlias,
        child: ListTile(
          onTap: onTap,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 14,
            vertical: 4,
          ),
          leading: Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(8),
              gradient: LinearGradient(
                colors: colors,
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
            child: Icon(icon, color: Colors.white, size: 24),
          ),
          title: Text(
            title,
            style: const TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w600,
              color: Pallete.whiteColor,
            ),
          ),
          subtitle: Text(
            subtitle,
            style: const TextStyle(fontSize: 12, color: Pallete.subtitleText),
          ),
          trailing: const Icon(
            Icons.chevron_right_rounded,
            color: Pallete.subtitleText,
          ),
        ),
      ),
    );
  }

  Widget _buildProfileView(String displayName) {
    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.all(16.0),
      child: Column(
        children: [
          const SizedBox(height: 20),
          CircleAvatar(
            radius: 46,
            backgroundColor: Pallete.gradient1,
            child: Text(
              displayName.isNotEmpty ? displayName[0].toUpperCase() : 'D',
              style: const TextStyle(
                fontSize: 36,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
          ),
          const SizedBox(height: 16),
          Text(
            displayName,
            style: const TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.bold,
              color: Pallete.whiteColor,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            _currentUser?.email ?? 'dinto@musicapp.com',
            style: const TextStyle(fontSize: 14, color: Pallete.subtitleText),
          ),
          const SizedBox(height: 24),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            decoration: BoxDecoration(
              color: Pallete.cardColor,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Pallete.borderColor),
            ),
            child: const Row(
              children: [
                Icon(
                  Icons.workspace_premium_rounded,
                  color: Pallete.gradient2,
                  size: 26,
                ),
                SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Music Premium',
                        style: TextStyle(
                          color: Pallete.whiteColor,
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                        ),
                      ),
                      Text(
                        'Ad-free high-fidelity streaming active',
                        style: TextStyle(
                          color: Pallete.subtitleText,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),

          // Music DNA & Taste Profile Card
          _buildTasteProfileCard(),

          const SizedBox(height: 28),
          ElevatedButton.icon(
            onPressed: _handleLogout,
            style: ElevatedButton.styleFrom(
              backgroundColor: Pallete.errorColor.withAlpha(220),
              minimumSize: const Size(double.infinity, 50),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            icon: const Icon(Icons.logout_rounded, color: Colors.white),
            label: const Text(
              'Log Out',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
          ),
          const SizedBox(height: 20),
        ],
      ),
    );
  }

  Widget _buildRecommendationsSection() {
    if (_isLoadingRecommendations && _homepageSections.isEmpty) {
      return const SizedBox(
        height: 160,
        child: Center(
          child: CircularProgressIndicator(color: Pallete.gradient2),
        ),
      );
    }

    if (_homepageSections.isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
        child: Center(
          child: TextButton.icon(
            onPressed: _fetchRecommendations,
            icon: const Icon(Icons.refresh_rounded, color: Pallete.gradient2),
            label: const Text(
              'Load Personalized Mix',
              style: TextStyle(color: Pallete.whiteColor),
            ),
          ),
        ),
      );
    }

    // Render only ONE single personalized recommendation section on the home page.
    // Exclude separate trending, chill and relaxed, or extra sections.
    final primarySection = _homepageSections.firstWhere(
      (s) =>
          (s.id == 'made_for_you' ||
              s.title.toLowerCase().contains('for you') ||
              s.title.toLowerCase().contains('recommended')) &&
          s.songs.isNotEmpty,
      orElse: () => _homepageSections.firstWhere(
        (s) {
          final idLower = s.id.toLowerCase();
          final titleLower = s.title.toLowerCase();
          final isTrending =
              idLower.contains('trending') || titleLower.contains('trending');
          final isChill =
              idLower.contains('chill') || titleLower.contains('chill');
          return !isTrending && !isChill && s.songs.isNotEmpty;
        },
        orElse: () => _homepageSections.firstWhere(
          (s) => s.songs.isNotEmpty,
          orElse: () => const HomepageSectionModel(
            id: 'recommended_for_you',
            title: 'Discover New',
            subtitle: 'Personalized mix based on your taste',
            songs: [],
          ),
        ),
      ),
    );

    if (primarySection.songs.isEmpty) {
      return const SizedBox.shrink();
    }

    return _buildHomepageSection(
      HomepageSectionModel(
        id: primarySection.id,
        title: 'Discover New',
        subtitle: primarySection.subtitle.isNotEmpty
            ? primarySection.subtitle
            : 'Personalized mix based on your taste',
        seedSong: primarySection.seedSong,
        songs: primarySection.songs,
      ),
    );
  }

  Widget _buildHomepageSection(HomepageSectionModel section) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [Pallete.gradient1, Pallete.gradient2],
                        ),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Icon(
                        Icons.auto_awesome_rounded,
                        color: Colors.white,
                        size: 16,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            section.title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: Pallete.whiteColor,
                              letterSpacing: -0.5,
                            ),
                          ),
                          if (section.subtitle.isNotEmpty)
                            Text(
                              section.subtitle,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontSize: 11,
                                color: Pallete.subtitleText,
                              ),
                            ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              IconButton(
                tooltip: 'Refresh',
                icon: RotationTransition(
                  turns: _refreshSpinController,
                  child: Icon(
                    Icons.refresh_rounded,
                    color: _isLoadingRecommendations
                        ? Pallete.gradient2
                        : Pallete.subtitleText,
                    size: 20,
                  ),
                ),
                onPressed: _isLoadingRecommendations
                    ? null
                    : () => _fetchRecommendations(isRefresh: true),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        AnimatedOpacity(
          opacity: _isLoadingRecommendations ? 0.45 : 1.0,
          duration: const Duration(milliseconds: 250),
          child: SizedBox(
            height: 220,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              physics: const BouncingScrollPhysics(),
              padding: const EdgeInsets.symmetric(horizontal: 16),
              itemCount: section.songs.length,
              itemBuilder: (context, index) {
                final song = section.songs[index];
                return _buildRecommendationCard(song, index, section.songs);
              },
            ),
          ),
        ),
        const SizedBox(height: 16),
      ],
    );
  }

  Widget _buildRecommendationCard(
    RecommendedSongModel song,
    int index,
    List<RecommendedSongModel> sectionSongs,
  ) {
    final matchScore = (song.recommendationScore * 100).round();
    final badgeLabel = song.matchingMoods.isNotEmpty
        ? song.matchingMoods.first
        : (song.matchingGenres.isNotEmpty
              ? song.matchingGenres.first
              : '$matchScore% Match');

    return Container(
      width: 140,
      margin: const EdgeInsets.only(right: 14),
      child: GestureDetector(
        onTap: () => _playRecommendedSong(song, index, sectionSongs),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Stack(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: Container(
                    width: 140,
                    height: 140,
                    decoration: BoxDecoration(
                      color: Pallete.cardColor,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: song.image.isNotEmpty
                        ? Image.network(
                            song.image,
                            fit: BoxFit.cover,
                            errorBuilder: (context, error, stackTrace) =>
                                _fallbackCover(140),
                          )
                        : _fallbackCover(140),
                  ),
                ),
                // Match / Mood Tag Pill
                Positioned(
                  top: 8,
                  left: 8,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 6,
                      vertical: 3,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.black.withAlpha(190),
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(
                        color: Pallete.gradient2.withAlpha(160),
                        width: 0.8,
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(
                          Icons.bolt_rounded,
                          color: Pallete.gradient2,
                          size: 12,
                        ),
                        const SizedBox(width: 2),
                        Text(
                          badgeLabel,
                          style: const TextStyle(
                            color: Pallete.whiteColor,
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                // Play Button Overlay
                Positioned(
                  bottom: 8,
                  right: 8,
                  child: Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Pallete.gradient1, Pallete.gradient2],
                      ),
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withAlpha(160),
                          blurRadius: 8,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: const Icon(
                      Icons.play_arrow_rounded,
                      color: Colors.white,
                      size: 20,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              song.song,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: Pallete.whiteColor,
                fontWeight: FontWeight.w600,
                fontSize: 13,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              song.displayArtist,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(color: Pallete.subtitleText, fontSize: 11),
            ),
          ],
        ),
      ),
    );
  }

  Widget _fallbackCover(double size) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: Pallete.cardColor,
        borderRadius: BorderRadius.circular(12),
      ),
      child: const Icon(
        Icons.music_note_rounded,
        color: Pallete.gradient1,
        size: 36,
      ),
    );
  }

  void _playRecommendedSong(
    RecommendedSongModel song, [
    int? index,
    List<RecommendedSongModel>? sectionSongs,
  ]) {
    final songModel = song.toSongModel();
    // Play selected song alone and populate autoplay queue dynamically
    // from POST /api/recommend instead of homepage recommendation section.
    MusicPlayerService().playSongWithAutoplay(songModel);

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Playing "${song.song}" • Autoplay via /api/recommend'),
        backgroundColor: Pallete.cardColor,
        duration: const Duration(milliseconds: 1500),
      ),
    );
  }

  Widget _buildTasteProfileCard() {
    final profile = _userTasteProfile;
    final totalEvents = profile != null && profile.totalEvents > 0
        ? profile.totalEvents
        : (_homepageData?.favoritesCount ?? 0);
    final topGenres = profile?.genres.entries.toList() ?? [];
    topGenres.sort((a, b) => b.value.compareTo(a.value));

    final tasteGenres = topGenres.isNotEmpty
        ? topGenres.map((e) => '${e.key} • ${(e.value * 10).round()}%').toList()
        : (_homepageData?.topTaste['topGenres'] ?? <String>[]);

    final topMoods = profile?.moods.entries.toList() ?? [];
    topMoods.sort((a, b) => b.value.compareTo(a.value));

    final tasteMoods = topMoods.isNotEmpty
        ? topMoods.map((e) => e.key).toList()
        : (_homepageData?.topTaste['topMoods'] ?? <String>[]);

    final topArtists = profile?.artists.entries.toList() ?? [];
    topArtists.sort((a, b) => b.value.compareTo(a.value));

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Pallete.cardColor,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Pallete.gradient1.withAlpha(120), width: 1.2),
        boxShadow: [
          BoxShadow(
            color: Pallete.gradient1.withAlpha(30),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Row(
                children: [
                  Icon(
                    Icons.graphic_eq_rounded,
                    color: Pallete.gradient2,
                    size: 22,
                  ),
                  SizedBox(width: 8),
                  Text(
                    'Your Music DNA',
                    style: TextStyle(
                      color: Pallete.whiteColor,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
              IconButton(
                tooltip: 'Refresh DNA',
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
                icon: _isLoadingTasteProfile
                    ? const SizedBox(
                        width: 14,
                        height: 14,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Pallete.gradient2,
                        ),
                      )
                    : const Icon(
                        Icons.refresh_rounded,
                        color: Pallete.subtitleText,
                        size: 18,
                      ),
                onPressed: _isLoadingTasteProfile ? null : _fetchTasteProfile,
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            totalEvents > 0
                ? '$totalEvents listening telemetry events recorded in taste profile'
                : 'Play songs & like tracks to build your real-time Taste Profile!',
            style: const TextStyle(color: Pallete.subtitleText, fontSize: 11),
          ),
          const SizedBox(height: 14),

          // Top Genres
          if (tasteGenres.isNotEmpty) ...[
            const Text(
              'TOP GENRES',
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.bold,
                color: Pallete.subtitleText,
                letterSpacing: 1.2,
              ),
            ),
            const SizedBox(height: 6),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: tasteGenres.take(4).map((label) {
                return Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: Pallete.gradient1.withAlpha(35),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: Pallete.gradient1.withAlpha(120),
                      width: 0.8,
                    ),
                  ),
                  child: Text(
                    label,
                    style: const TextStyle(
                      fontSize: 11,
                      color: Pallete.whiteColor,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: 12),
          ],

          // Top Moods
          if (tasteMoods.isNotEmpty) ...[
            const Text(
              'TOP MOODS',
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.bold,
                color: Pallete.subtitleText,
                letterSpacing: 1.2,
              ),
            ),
            const SizedBox(height: 6),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: tasteMoods.take(4).map((mood) {
                return Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: Pallete.gradient2.withAlpha(35),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: Pallete.gradient2.withAlpha(120),
                      width: 0.8,
                    ),
                  ),
                  child: Text(
                    mood,
                    style: const TextStyle(
                      fontSize: 11,
                      color: Pallete.gradient2,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: 12),
          ],

          // Top Artists
          if (topArtists.isNotEmpty) ...[
            const Text(
              'TOP ARTISTS',
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.bold,
                color: Pallete.subtitleText,
                letterSpacing: 1.2,
              ),
            ),
            const SizedBox(height: 6),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: topArtists.take(3).map((entry) {
                return Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: Pallete.backgroundColor,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Pallete.borderColor),
                  ),
                  child: Text(
                    entry.key,
                    style: const TextStyle(
                      fontSize: 11,
                      color: Pallete.whiteColor,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                );
              }).toList(),
            ),
          ],
        ],
      ),
    );
  }
}
