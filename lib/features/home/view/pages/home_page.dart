import 'package:flutter/material.dart';
import '../../../../core/theme/app_pallete.dart';
import '../../../auth/model/user_model.dart';
import '../../../auth/repositories/auth_local_repository.dart';
import '../../../auth/view/pages/login_page.dart';
import '../widgets/mini_player.dart';
import '../widgets/music_card.dart';
import '../widgets/quick_play_tile.dart';
import '../widgets/section_header.dart';

class HomePage extends StatefulWidget {
  final UserModel? user;

  const HomePage({super.key, this.user});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  UserModel? _currentUser;
  int _currentNavIndex = 0;
  String _selectedCategory = 'All';

  final List<String> _categories = const [
    'All',
    'Music',
    'Podcasts',
    'Made For You',
  ];

  @override
  void initState() {
    super.initState();
    _currentUser = widget.user;
    if (_currentUser == null) {
      _loadCachedUser();
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
      return 'Good morning';
    } else if (hour < 17) {
      return 'Good afternoon';
    } else {
      return 'Good evening';
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
          style: TextStyle(color: Pallete.whiteColor, fontWeight: FontWeight.bold),
        ),
        content: const Text(
          'Are you sure you want to log out of your account?',
          style: TextStyle(color: Pallete.subtitleText),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel', style: TextStyle(color: Pallete.greyColor)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Pallete.errorColor,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
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

  @override
  Widget build(BuildContext context) {
    final greeting = _getGreeting();
    final displayName = _currentUser?.name.isNotEmpty == true
        ? _currentUser!.name
        : 'Listener';

    return Scaffold(
      backgroundColor: Pallete.backgroundColor,
      body: SafeArea(
        child: Column(
          children: [
            // Top App Bar
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 19,
                    backgroundColor: Pallete.gradient1,
                    child: Text(
                      displayName.isNotEmpty ? displayName[0].toUpperCase() : 'U',
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          greeting,
                          style: const TextStyle(
                            fontSize: 12,
                            color: Pallete.subtitleText,
                          ),
                        ),
                        Text(
                          displayName,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Pallete.whiteColor,
                          ),
                        ),
                      ],
                    ),
                  ),
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
            ),

            // Scrollable Home Feed
            Expanded(
              child: SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Category Filter Pills
                    SizedBox(
                      height: 48,
                      child: ListView.separated(
                        scrollDirection: Axis.horizontal,
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                        itemCount: _categories.length,
                        separatorBuilder: (_, _) => const SizedBox(width: 8),
                        itemBuilder: (context, index) {
                          final category = _categories[index];
                          final isSelected = category == _selectedCategory;
                          return ChoiceChip(
                            label: Text(category),
                            selected: isSelected,
                            onSelected: (selected) {
                              if (selected) {
                                setState(() => _selectedCategory = category);
                              }
                            },
                            selectedColor: Pallete.gradient1,
                            backgroundColor: Pallete.cardColor,
                            labelStyle: TextStyle(
                              color: isSelected ? Colors.white : Pallete.subtitleText,
                              fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                              fontSize: 13,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(20),
                              side: BorderSide(
                                color: isSelected
                                    ? Pallete.gradient1
                                    : Pallete.borderColor.withAlpha(100),
                              ),
                            ),
                          );
                        },
                      ),
                    ),

                    const SizedBox(height: 12),

                    // Quick Play 2-Column Grid
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16.0),
                      child: GridView.count(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        crossAxisCount: 2,
                        crossAxisSpacing: 10,
                        mainAxisSpacing: 10,
                        childAspectRatio: 2.8,
                        children: [
                          QuickPlayTile(
                            title: 'Liked Songs',
                            icon: Icons.favorite_rounded,
                            gradientColors: const [
                              Pallete.gradient1,
                              Pallete.gradient2,
                            ],
                            onTap: () {},
                          ),
                          QuickPlayTile(
                            title: "Today's Top Hits",
                            icon: Icons.whatshot_rounded,
                            gradientColors: const [
                              Pallete.gradient2,
                              Pallete.gradient3,
                            ],
                            onTap: () {},
                          ),
                          QuickPlayTile(
                            title: 'Lo-Fi Chill Beats',
                            icon: Icons.headphones_rounded,
                            gradientColors: const [
                              Color(0xFF4A00E0),
                              Color(0xFF8E2DE2),
                            ],
                            onTap: () {},
                          ),
                          QuickPlayTile(
                            title: 'Deep Focus',
                            icon: Icons.lightbulb_outline_rounded,
                            gradientColors: const [
                              Color(0xFF00B4DB),
                              Color(0xFF0083B0),
                            ],
                            onTap: () {},
                          ),
                          QuickPlayTile(
                            title: 'Release Radar',
                            icon: Icons.radar_rounded,
                            gradientColors: const [
                              Color(0xFF11998E),
                              Color(0xFF38EF7D),
                            ],
                            onTap: () {},
                          ),
                          QuickPlayTile(
                            title: 'Synthwave Night',
                            icon: Icons.nightlife_rounded,
                            gradientColors: const [
                              Color(0xFFFF416C),
                              Color(0xFFFF4B2B),
                            ],
                            onTap: () {},
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 24),

                    // Section 1: Made For You
                    SectionHeader(
                      title: 'Made For You',
                      onSeeAllTap: () {},
                    ),
                    SizedBox(
                      height: 230,
                      child: ListView(
                        scrollDirection: Axis.horizontal,
                        physics: const BouncingScrollPhysics(),
                        padding: const EdgeInsets.only(right: 16),
                        children: [
                          MusicCard(
                            title: 'Daily Mix 1',
                            subtitle: 'The Weeknd, Dua Lipa, Daft Punk & more',
                            gradientColors: const [
                              Pallete.gradient1,
                              Pallete.gradient2,
                            ],
                            icon: Icons.album_rounded,
                            onTap: () {},
                          ),
                          MusicCard(
                            title: 'Discover Weekly',
                            subtitle: 'Your weekly mixtape of fresh discoveries',
                            gradientColors: const [
                              Color(0xFF11998E),
                              Color(0xFF38EF7D),
                            ],
                            icon: Icons.auto_awesome_rounded,
                            onTap: () {},
                          ),
                          MusicCard(
                            title: 'Chill Vibes',
                            subtitle: 'Soft rhythms and relaxing acoustic melodies',
                            gradientColors: const [
                              Color(0xFF4A00E0),
                              Color(0xFF8E2DE2),
                            ],
                            icon: Icons.spa_rounded,
                            onTap: () {},
                          ),
                          MusicCard(
                            title: 'Cyberpunk 2099',
                            subtitle: 'Darksynth, electro and bass-heavy tracks',
                            gradientColors: const [
                              Color(0xFFFF416C),
                              Color(0xFFFF4B2B),
                            ],
                            icon: Icons.electric_bolt_rounded,
                            onTap: () {},
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 16),

                    // Section 2: Trending & Popular
                    SectionHeader(
                      title: 'Trending & Charts',
                      onSeeAllTap: () {},
                    ),
                    SizedBox(
                      height: 230,
                      child: ListView(
                        scrollDirection: Axis.horizontal,
                        physics: const BouncingScrollPhysics(),
                        padding: const EdgeInsets.only(right: 16),
                        children: [
                          MusicCard(
                            title: 'Global Top 50',
                            subtitle: 'The most played tracks worldwide right now',
                            gradientColors: const [
                              Pallete.gradient2,
                              Pallete.gradient3,
                            ],
                            icon: Icons.trending_up_rounded,
                            onTap: () {},
                          ),
                          MusicCard(
                            title: 'Hip-Hop Central',
                            subtitle: 'Drake, Kendrick Lamar, Travis Scott',
                            gradientColors: const [
                              Color(0xFF2C3E50),
                              Color(0xFF4CA1AF),
                            ],
                            icon: Icons.speaker_group_rounded,
                            onTap: () {},
                          ),
                          MusicCard(
                            title: 'Electronic Odyssey',
                            subtitle: 'High energy dance, house & progressive',
                            gradientColors: const [
                              Color(0xFF8A2387),
                              Color(0xFFE94057),
                            ],
                            icon: Icons.graphic_eq_rounded,
                            onTap: () {},
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 10),
                  ],
                ),
              ),
            ),

            // Persistent Mini Player
            const MiniPlayer(),
          ],
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
        selectedLabelStyle: const TextStyle(fontWeight: FontWeight.w600, fontSize: 12),
        unselectedLabelStyle: const TextStyle(fontSize: 12),
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.home_filled),
            label: 'Home',
          ),
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
}
