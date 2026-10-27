import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../../core/models/recommendation_models.dart';
import '../../../../core/network/api_exception.dart';
import '../../../../core/services/device_sync_service.dart';
import '../../../../core/services/favorites_service.dart';
import '../../../../core/services/friends_service.dart';
import '../../../../core/services/music_player_service.dart';
import '../../../../core/services/now_playing_reporter.dart';
import '../../../../core/services/presence_service.dart';
import '../../../../core/services/playlists_service.dart';
import '../../../../core/services/recent_searches_service.dart';
import '../../../../core/services/recommendation_service.dart';
import '../../../../core/services/room_service.dart';
import '../../../../core/utils/greeting.dart';
import '../../../../core/theme/app_pallete.dart';
import '../../../auth/model/user_model.dart';
import '../../../auth/repositories/auth_local_repository.dart';
import '../../../auth/view/pages/login_page.dart';
import '../../../device_sync/view/widgets/device_sync_card.dart';
import '../../../favorites/view/pages/liked_songs_page.dart';
import '../../../friends/model/friend_models.dart';
import '../../../profile/model/profile_model.dart';
import '../../../profile/repositories/profile_repository.dart';
import '../../../profile/view/widgets/username_dialog.dart';
import '../../../playlists/view/widgets/library_playlists_section.dart';
import '../../../rooms/view/widgets/room_home_section.dart';
import '../../../search/model/song_model.dart';
import '../../../search/repositories/search_repository.dart';
import '../../../search/view/pages/recent_searches_page.dart';
import '../../../search/view/pages/search_page.dart';
import 'offline_songs_page.dart';
import '../widgets/add_friend_bar.dart';
import '../widgets/friend_card.dart';
import '../widgets/friend_request_tile.dart';
import '../widgets/mini_player.dart';
import '../widgets/quick_action_card.dart';

class HomePage extends StatefulWidget {
  final UserModel? user;

  const HomePage({super.key, this.user});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage>
    with SingleTickerProviderStateMixin, WidgetsBindingObserver {
  UserModel? _currentUser;
  int _currentNavIndex = 0;

  HomepageResponseModel? _homepageData;
  List<HomepageSectionModel> _homepageSections = [];
  bool _isLoadingRecommendations = false;
  int _refreshSeed = 0;
  late final AnimationController _refreshSpinController;
  MusicDnaModel? _musicDna;
  bool _isLoadingTasteProfile = false;
  bool? _shareListening; // null until loaded from the server
  bool _isSavingPrivacy = false;
  bool _privacyLoadFailed = false;
  String? _username; // null until the user claims one
  String? _suggestedUsername;
  bool _canChangeUsername = true;
  DateTime? _usernameChangeAvailableAt;
  bool _appInForeground = true;
  bool _isShuffling = false;
  final FriendsService _friendsService = FriendsService();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _friendsService.addListener(_onFriendsChanged);
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
      _loadPrivacySetting();
      PresenceService().start(); // "online" green circle for friends
      NowPlayingReporter().start(); // lets friends see what you are playing
      RoomService().start(); // invites + listening-room sync
      DeviceSyncService().start(); // reports playback; follows other devices when the switch is on
      _syncFriendsPolling();
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Only count as online while the app is in the foreground (also keeps request volume low).
    _appInForeground = state == AppLifecycleState.resumed;
    RoomService().setAppForeground(_appInForeground); // rooms keep syncing in the background
    DeviceSyncService().setAppForeground(_appInForeground);
    if (_appInForeground) {
      PresenceService().start();
    } else {
      PresenceService().stop();
    }
    _syncFriendsPolling();
  }

  void _onFriendsChanged() {
    if (mounted) setState(() {});
  }

  /// Poll friends only while the Home tab is visible and the app is in the foreground.
  void _syncFriendsPolling() {
    if (_appInForeground && _currentNavIndex == 0) {
      _friendsService.startPolling();
    } else {
      _friendsService.stopPolling();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _friendsService.removeListener(_onFriendsChanged);
    _friendsService.stopPolling();
    NowPlayingReporter().stop();
    DeviceSyncService().stop();
    PresenceService().stop();
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
      final dna = await RecommendationService().getMusicDna(userId);
      if (mounted) {
        setState(() {
          _musicDna = dna;
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

  String _getGreeting() => greetingForTime(DateTime.now());

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
      await RoomService().leave(); // while the token is still valid
      await AuthLocalRepository().clear();
      RoomService().reset();
      DeviceSyncService().reset();
      RecentSearchesService().reset();
      PresenceService().stop();
      FriendsService().reset();
      NowPlayingReporter().stop(clear: true);
      PlaylistsService().reset();
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

  void _showSnack(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: Pallete.cardColor),
    );
  }

  void _applyProfile(ProfileModel profile) {
    setState(() {
      _username = profile.username;
      _suggestedUsername = profile.suggestedUsername;
      _canChangeUsername = profile.canChangeUsername;
      _usernameChangeAvailableAt = profile.usernameChangeAvailableAt;
      _shareListening = profile.shareListening;
      _privacyLoadFailed = false;
    });
  }

  /// Opens the claim/change username dialog. Returns the saved username, or null if cancelled.
  Future<String?> _promptForUsername() async {
    if (!mounted) return null;
    final profile = await showUsernameDialog(
      context,
      currentUsername: _username,
      suggestion: _suggestedUsername,
    );
    if (profile == null || !mounted) return null;
    _applyProfile(profile);
    return profile.username;
  }

  /// Sends a friend request. Returns true on success (the input is then cleared).
  Future<bool> _handleAddFriend(String username, {bool retried = false}) async {
    try {
      final message = await _friendsService.sendRequest(username);
      _showSnack(message);
      return true;
    } on ApiException catch (e) {
      if (e.code == 'username_required' && !retried) {
        // Friends need your own username first: ask for it, then send again.
        final chosen = await _promptForUsername();
        if (chosen == null) return false;
        return _handleAddFriend(username, retried: true);
      }
      _showSnack(e.message);
      return false;
    } catch (_) {
      _showSnack('Could not send the request. Check your connection and try again.');
      return false;
    }
  }

  Future<void> _handleAcceptRequest(FriendRequestModel request) async {
    try {
      final message = await _friendsService.acceptRequest(request);
      _showSnack(message);
    } on ApiException catch (e) {
      _showSnack(e.message);
      _friendsService.refresh();
    } catch (_) {
      _showSnack('Could not accept the request. Please try again.');
    }
  }

  Future<void> _handleDeclineRequest(FriendRequestModel request) async {
    try {
      await _friendsService.declineRequest(request);
    } on ApiException catch (e) {
      _showSnack(e.message);
      _friendsService.refresh();
    } catch (_) {
      _showSnack('Could not decline the request. Please try again.');
    }
  }

  /// Plays the song a friend is listening to (or last listened to).
  Future<void> _handleTuneIn(FriendActivityModel friend) async {
    final shared = friend.song;
    if (shared == null) return;
    _showSnack('Finding "${shared.title}"...');

    final perma = shared.permaUrl;
    final searchText = '${shared.title} ${shared.artist ?? ''}'.trim();
    final repository = SearchRepository();

    SongModel? song;
    if (perma != null && perma.isNotEmpty) {
      song = await repository.fetchSongDetails(perma);
    }
    if (song == null || song.mediaUrl.trim().isEmpty) {
      song = await repository.fetchSongDetails(searchText);
    }
    if (!mounted) return;

    if (song == null) {
      _showSnack('Could not load that song right now.');
      return;
    }
    MusicPlayerService().playSongWithAutoplay(song);
    _showSnack('Tuned in with ${friend.name.isNotEmpty ? friend.name : friend.username} • ${shared.title}');
  }

  /// Plays all of the user's liked songs in random order.
  Future<void> _handleShuffleAll() async {
    if (_isShuffling) return;
    _isShuffling = true;
    try {
      final favorites = FavoritesService();
      var pages = 0;
      while (favorites.hasMore && pages < 20) {
        final before = favorites.likedSongs.length;
        await favorites.fetchLikedSongs();
        pages++;
        if (favorites.errorMessage != null || favorites.likedSongs.length == before) {
          break;
        }
      }

      final songs = List<SongModel>.from(favorites.likedSongs)..shuffle();
      if (!mounted) return;
      if (songs.isEmpty) {
        _showSnack(
          favorites.errorMessage != null
              ? 'Could not load your liked songs. Please try again.'
              : 'Like some songs first, then Shuffle will play them.',
        );
        return;
      }
      MusicPlayerService().playSong(songs.first, queue: songs);
      _showSnack('Shuffling ${songs.length} liked songs');
    } finally {
      _isShuffling = false;
    }
  }

  FriendModel _toFriendModel(FriendActivityModel friend) {
    final song = friend.song;
    String statusText;
    var canTuneIn = false;

    if (song != null && friend.status == 'listening') {
      statusText = song.title;
      canTuneIn = true;
    } else if (song != null && friend.status == 'paused') {
      statusText = 'Paused • ${song.title}';
      canTuneIn = true;
    } else if (song != null && friend.status == 'recent') {
      statusText = 'Last: ${song.title}';
      canTuneIn = true;
    } else if (friend.online) {
      statusText = 'Online';
    } else {
      statusText = 'Offline';
    }

    return FriendModel(
      username: friend.username,
      name: friend.name,
      statusText: statusText,
      isOnline: friend.online,
      isListening: friend.isListening,
      canTuneIn: canTuneIn,
      avatarGradient: friendGradientFor(friend.username),
    );
  }

  Widget _buildFriendsList() {
    final service = _friendsService;
    final friends = service.friends;

    if (!service.hasLoaded) {
      if (service.errorMessage != null) {
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(
            children: [
              const Expanded(
                child: Text(
                  'Could not load your friends.',
                  style: TextStyle(color: Pallete.subtitleText, fontSize: 13),
                ),
              ),
              TextButton(
                onPressed: service.refresh,
                child: const Text(
                  'Retry',
                  style: TextStyle(color: Pallete.gradient2),
                ),
              ),
            ],
          ),
        );
      }
      return const SizedBox(
        height: 80,
        child: Center(
          child: CircularProgressIndicator(color: Pallete.gradient2),
        ),
      );
    }

    if (friends.isEmpty) {
      return const Padding(
        padding: EdgeInsets.symmetric(horizontal: 16),
        child: Text(
          'No friends yet. Add someone by their username above.',
          style: TextStyle(color: Pallete.subtitleText, fontSize: 13),
        ),
      );
    }

    return SizedBox(
      height: 180,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: friends.length,
        itemBuilder: (context, index) {
          final friend = friends[index];
          return FriendCard(
            friend: _toFriendModel(friend),
            onListenAlong: () => _handleTuneIn(friend),
          );
        },
      ),
    );
  }

  Widget _buildFriendsSection() {
    final requests = _friendsService.incomingRequests;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (requests.isNotEmpty) ...[
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Friend requests',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Pallete.whiteColor,
                    letterSpacing: -0.5,
                  ),
                ),
                const SizedBox(height: 10),
                for (final request in requests)
                  FriendRequestTile(
                    key: ValueKey(request.id),
                    request: request,
                    onAccept: () => _handleAcceptRequest(request),
                    onDecline: () => _handleDeclineRequest(request),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 16),
        ],
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
        _buildFriendsList(),
      ],
    );
  }

  String _formatDate(DateTime? date) {
    if (date == null) return 'later';
    final local = date.toLocal();
    return '${local.day}/${local.month}/${local.year}';
  }

  Widget _buildUsernameCard() {
    final username = _username;
    final loading = _shareListening == null && !_privacyLoadFailed;

    String subtitle;
    if (_privacyLoadFailed && username == null) {
      subtitle = 'Could not load your profile. Tap to retry.';
    } else if (loading) {
      subtitle = 'Loading...';
    } else if (username == null) {
      subtitle = 'Pick a username so friends can find you';
    } else if (_canChangeUsername) {
      subtitle = 'Friends add you with this. You can change it once every 30 days.';
    } else {
      subtitle = 'You can change it again on ${_formatDate(_usernameChangeAvailableAt)}';
    }

    final canEdit = !loading && !_privacyLoadFailed && (username == null || _canChangeUsername);

    return GestureDetector(
      onTap: (_privacyLoadFailed && username == null) ? _loadPrivacySetting : null,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: Pallete.cardColor,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Pallete.borderColor),
        ),
        child: Row(
          children: [
            const Icon(
              Icons.alternate_email_rounded,
              color: Pallete.gradient2,
              size: 26,
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    username != null ? '@$username' : 'Choose a username',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Pallete.whiteColor,
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                    ),
                  ),
                  Text(
                    subtitle,
                    style: const TextStyle(
                      color: Pallete.subtitleText,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
            TextButton(
              onPressed: canEdit ? _promptForUsername : null,
              child: Text(
                username == null ? 'Set' : 'Edit',
                style: TextStyle(
                  color: canEdit ? Pallete.gradient2 : Pallete.subtitleText,
                ),
              ),
            ),
          ],
        ),
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
          _syncFriendsPolling();
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
                Expanded(
                  child: Row(
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
                    Flexible(
                      child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          greeting,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 14,
                            color: Pallete.subtitleText,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        Text(
                          displayName,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.bold,
                            color: Pallete.whiteColor,
                            letterSpacing: -0.5,
                          ),
                        ),
                      ],
                    ),
                    ),
                  ],
                ),
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
                  onTap: _handleShuffleAll,
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 16.0),
            child: DeviceSyncCard(),
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
          const RoomHomeSection(),

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

          // Section 4: Friend requests + Friends (live from the backend)
          _buildFriendsSection(),

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
                  subtitle: 'History • Your latest searches',
                  icon: Icons.history_rounded,
                  colors: const [Color(0xFF00B4DB), Color(0xFF0083B0)],
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const RecentSearchesPage(),
                      ),
                    );
                  },
                ),
                const LibraryPlaylistsSection(),
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
          _buildUsernameCard(),
          const SizedBox(height: 12),
          _buildPrivacyCard(),
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
            title: 'Discover',
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
        title: 'Discover',
        subtitle:'Personalized mix based on your taste',
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

  Future<void> _loadPrivacySetting() async {
    try {
      final profile = await ProfileRepository().getProfile();
      if (!mounted) return;
      _applyProfile(profile);
    } catch (_) {
      if (!mounted) return;
      setState(() => _privacyLoadFailed = true);
    }
  }

  Future<void> _setShareListening(bool value) async {
    final bool? previous = _shareListening;
    setState(() {
      _shareListening = value;
      _isSavingPrivacy = true;
    });
    try {
      final updated = await ProfileRepository().setShareListening(value);
      if (!mounted) return;
      setState(() {
        _shareListening = updated.shareListening;
        _isSavingPrivacy = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _shareListening = previous;
        _isSavingPrivacy = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Could not update your privacy setting. Please try again.'),
        ),
      );
    }
  }

  Widget _buildPrivacyCard() {
    final bool? shareListening = _shareListening;
    final String subtitle = _privacyLoadFailed
        ? 'Could not load this setting. Tap to retry.'
        : shareListening == null
            ? 'Loading...'
            : shareListening
                ? 'Friends can see the song you are playing'
                : 'Friends only see that you are online';

    return GestureDetector(
      onTap: _privacyLoadFailed ? _loadPrivacySetting : null,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: Pallete.cardColor,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Pallete.borderColor),
        ),
        child: Row(
          children: [
            Icon(
              shareListening == false
                  ? Icons.visibility_off_rounded
                  : Icons.visibility_rounded,
              color: Pallete.gradient2,
              size: 26,
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Show what I am listening to',
                    style: TextStyle(
                      color: Pallete.whiteColor,
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                    ),
                  ),
                  Text(
                    subtitle,
                    style: const TextStyle(
                      color: Pallete.subtitleText,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
            Switch(
              value: shareListening ?? true,
              activeTrackColor: Pallete.gradient2,
              onChanged: (shareListening == null || _isSavingPrivacy)
                  ? null
                  : _setShareListening,
            ),
          ],
        ),
      ),
    );
  }

  List<String> _stringList(dynamic raw) {
    if (raw is List) return raw.map((e) => e.toString()).toList();
    return <String>[];
  }

  String _dnaFreshnessLabel(DateTime? generatedAt) {
    if (generatedAt == null) return 'Refreshed daily';
    final age = DateTime.now().difference(generatedAt);
    if (age.inMinutes < 1) return 'Updated just now • refreshed daily';
    if (age.inHours < 1) return 'Updated ${age.inMinutes}m ago • refreshed daily';
    return 'Updated ${age.inHours}h ago • refreshed daily';
  }

  Widget _buildDnaSection(
    String title,
    List<String> labels,
    int maxItems, {
    Color? accent,
  }) {
    if (labels.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
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
            children: labels.take(maxItems).map((label) {
              return Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: accent != null
                      ? accent.withAlpha(35)
                      : Pallete.backgroundColor,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: accent != null
                        ? accent.withAlpha(120)
                        : Pallete.borderColor,
                    width: 0.8,
                  ),
                ),
                child: Text(
                  label,
                  style: TextStyle(
                    fontSize: 11,
                    color: accent == Pallete.gradient2
                        ? Pallete.gradient2
                        : Pallete.whiteColor,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildTasteProfileCard() {
    final MusicDnaModel? dna = _musicDna;

    // Prefer the daily Music DNA; fall back to the homepage taste until DNA exists.
    final List<String> tasteGenres = dna != null && dna.hasData
        ? dna.topGenres.map((e) => '${e.name} • ${e.percent}%').toList()
        : _stringList(_homepageData?.topTaste['topGenres']);
    final List<String> tasteMoods = dna != null && dna.hasData
        ? dna.topMoods.map((e) => e.name).toList()
        : _stringList(_homepageData?.topTaste['topMoods']);
    final List<String> tasteArtists = dna != null && dna.hasData
        ? dna.topArtists.map((e) => e.name).toList()
        : <String>[];
    final List<String> tasteLanguages = dna != null && dna.hasData
        ? dna.topLanguages.map((e) => e.name).toList()
        : <String>[];

    final String subtitle = dna != null && dna.hasData
        ? '${dna.summary.isNotEmpty ? '${dna.summary} ' : ''}${_dnaFreshnessLabel(dna.generatedAt)}'
        : 'Play songs & like tracks to build your Music DNA!';

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
                tooltip: 'Reload DNA',
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
            subtitle,
            style: const TextStyle(color: Pallete.subtitleText, fontSize: 11),
          ),
          const SizedBox(height: 14),
          _buildDnaSection('TOP GENRES', tasteGenres, 4, accent: Pallete.gradient1),
          _buildDnaSection('TOP MOODS', tasteMoods, 4, accent: Pallete.gradient2),
          _buildDnaSection('TOP ARTISTS', tasteArtists, 3),
          _buildDnaSection('TOP LANGUAGES', tasteLanguages, 3),
        ],
      ),
    );
  }
}
