import 'package:flutter/material.dart';
import '../../../../core/services/friends_service.dart';
import '../../../../core/services/room_service.dart';
import '../../../../core/theme/app_pallete.dart';
import '../../../friends/model/friend_models.dart';
import '../../model/room_models.dart';

/// Create a room (pick 1-2 friends) or, when already in one, see who is in it and invite more.
class RoomPage extends StatefulWidget {
  const RoomPage({super.key});

  @override
  State<RoomPage> createState() => _RoomPageState();
}

class _RoomPageState extends State<RoomPage> {
  final RoomService _roomService = RoomService();
  final FriendsService _friendsService = FriendsService();

  final Set<String> _selected = <String>{};
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _roomService.addListener(_onUpdate);
    _friendsService.addListener(_onUpdate);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _friendsService.refresh();
    });
  }

  @override
  void dispose() {
    _roomService.removeListener(_onUpdate);
    _friendsService.removeListener(_onUpdate);
    super.dispose();
  }

  void _onUpdate() {
    if (!mounted) return;
    final String? notice = _roomService.takeNotice();
    if (notice != null) _toast(notice);
    setState(() {});
  }

  void _toast(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), duration: const Duration(seconds: 3)),
    );
  }

  Future<void> _create() async {
    if (_selected.isEmpty || _busy) return;
    setState(() => _busy = true);
    final String? error = await _roomService.createRoom(_selected.toList());
    if (!mounted) return;
    setState(() {
      _busy = false;
      if (error == null) _selected.clear();
    });
    if (error != null) _toast(error);
  }

  Future<void> _invite(String username) async {
    if (_busy) return;
    setState(() => _busy = true);
    final String? error = await _roomService.invite(username);
    if (!mounted) return;
    setState(() => _busy = false);
    _toast(error ?? 'Invite sent to @$username');
  }

  Future<void> _leave() async {
    final bool? confirmed = await showDialog<bool>(
      context: context,
      builder: (BuildContext dialogContext) => AlertDialog(
        backgroundColor: Pallete.cardColor,
        title: const Text('Leave room?', style: TextStyle(color: Pallete.whiteColor)),
        content: const Text(
          'Your music stops being synced. Your friends stay in the room.',
          style: TextStyle(color: Pallete.subtitleText),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Stay', style: TextStyle(color: Pallete.subtitleText)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Leave', style: TextStyle(color: Pallete.errorColor)),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    await _roomService.leave();
    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final RoomModel? room = _roomService.room;
    return Scaffold(
      backgroundColor: Pallete.backgroundColor,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(8, 12, 16, 4),
              child: Row(
                children: [
                  IconButton(
                    icon: const Icon(
                      Icons.arrow_back_ios_new_rounded,
                      color: Pallete.whiteColor,
                      size: 22,
                    ),
                    onPressed: () => Navigator.pop(context),
                  ),
                  Expanded(
                    child: Text(
                      room == null ? 'Create a room' : 'Your room',
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Pallete.whiteColor,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: room == null ? _buildCreate() : _buildRoom(room),
            ),
          ],
        ),
      ),
    );
  }

  // create
  Widget _buildCreate() {
    final List<FriendActivityModel> friends = _friendsService.friends;

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
      children: [
        const Text(
          'Pick up to 2 friends. Whenever someone in the room starts or changes a song, '
          'it changes for everyone. Pausing and seeking stay on your own phone.',
          style: TextStyle(color: Pallete.subtitleText, fontSize: 13, height: 1.4),
        ),
        const SizedBox(height: 16),
        if (friends.isEmpty)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 32),
            child: Center(
              child: Text(
                'Add a friend first, then come back to create a room.',
                textAlign: TextAlign.center,
                style: TextStyle(color: Pallete.whiteColor, fontSize: 15),
              ),
            ),
          ),
        for (final FriendActivityModel friend in friends)
          _friendTile(
            friend,
            trailing: Checkbox(
              value: _selected.contains(friend.username),
              activeColor: Pallete.gradient2,
              onChanged: (bool? value) => _toggleSelected(friend.username, value == true),
            ),
            onTap: () => _toggleSelected(
              friend.username,
              !_selected.contains(friend.username),
            ),
          ),
        const SizedBox(height: 16),
        ElevatedButton.icon(
          onPressed: _selected.isEmpty || _busy ? null : _create,
          icon: _busy
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                )
              : const Icon(Icons.sensors_rounded),
          label: Text(
            _selected.isEmpty
                ? 'Select friends to invite'
                : 'Create room (${_selected.length + 1}/3)',
          ),
          style: ElevatedButton.styleFrom(
            backgroundColor: Pallete.gradient2,
            foregroundColor: Colors.white,
            disabledBackgroundColor: Pallete.borderColor,
            minimumSize: const Size.fromHeight(50),
          ),
        ),
      ],
    );
  }

  void _toggleSelected(String username, bool selected) {
    setState(() {
      if (selected) {
        if (_selected.length < 2) _selected.add(username);
      } else {
        _selected.remove(username);
      }
    });
  }

  Widget _friendTile(
    FriendActivityModel friend, {
    required Widget trailing,
    VoidCallback? onTap,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      child: Material(
        color: Pallete.cardColor,
        borderRadius: BorderRadius.circular(10),
        clipBehavior: Clip.antiAlias,
        child: ListTile(
          onTap: onTap,
          leading: _avatar(friend.name, friend.online),
          title: Text(
            friend.name,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: Pallete.whiteColor,
              fontWeight: FontWeight.w600,
            ),
          ),
          subtitle: Text(
            '@${friend.username}',
            style: const TextStyle(color: Pallete.subtitleText, fontSize: 12),
          ),
          trailing: trailing,
        ),
      ),
    );
  }

  Widget _avatar(String name, bool online) {
    final String initial = name.isNotEmpty ? name[0].toUpperCase() : '?';
    return Stack(
      clipBehavior: Clip.none,
      children: [
        CircleAvatar(
          radius: 22,
          backgroundColor: Pallete.gradient1,
          child: Text(
            initial,
            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
          ),
        ),
        Positioned(
          right: -1,
          bottom: -1,
          child: Container(
            width: 12,
            height: 12,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: online ? Pallete.greenColor : Pallete.greyColor,
              border: Border.all(color: Pallete.cardColor, width: 2),
            ),
          ),
        ),
      ],
    );
  }

  // in a room
  Widget _buildRoom(RoomModel room) {
    final List<FriendActivityModel> invitable = _friendsService.friends
        .where((FriendActivityModel f) => !room.hasMember(f.username))
        .toList();

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
      children: [
        _nowSharing(room),
        const SizedBox(height: 20),
        Text(
          'In this room (${room.members.length}/${room.capacity})',
          style: const TextStyle(
            color: Pallete.whiteColor,
            fontSize: 16,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 10),
        for (final RoomMemberModel member in room.members) _memberTile(member),
        if (!room.isFull) ...[
          const SizedBox(height: 16),
          const Text(
            'Invite a friend',
            style: TextStyle(
              color: Pallete.whiteColor,
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 10),
          if (invitable.isEmpty)
            const Text(
              'All your friends are already here.',
              style: TextStyle(color: Pallete.subtitleText, fontSize: 13),
            ),
          for (final FriendActivityModel friend in invitable)
            _friendTile(
              friend,
              onTap: _busy ? null : () => _invite(friend.username),
              trailing: const Icon(Icons.person_add_alt_1_rounded, color: Pallete.gradient2),
            ),
        ],
        const SizedBox(height: 24),
        const Text(
          'Anyone changing the song changes it for everyone. Pause, resume and seeking '
          'only affect your own phone. The room keeps working with your screen off.',
          style: TextStyle(color: Pallete.subtitleText, fontSize: 12, height: 1.4),
        ),
        const SizedBox(height: 16),
        OutlinedButton.icon(
          onPressed: _leave,
          icon: const Icon(Icons.logout_rounded),
          label: const Text('Leave room'),
          style: OutlinedButton.styleFrom(
            foregroundColor: Pallete.errorColor,
            side: const BorderSide(color: Pallete.errorColor),
            minimumSize: const Size.fromHeight(48),
          ),
        ),
      ],
    );
  }

  Widget _nowSharing(RoomModel room) {
    final RoomSongModel? song = room.song;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14),
        gradient: const LinearGradient(
          colors: [Pallete.gradient1, Pallete.gradient2],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Row(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: SizedBox(
              width: 56,
              height: 56,
              child: song?.imageUrl != null
                  ? Image.network(
                      song!.imageUrl!,
                      fit: BoxFit.cover,
                      errorBuilder: (_, _, _) => const ColoredBox(
                        color: Colors.black26,
                        child: Icon(Icons.music_note_rounded, color: Colors.white),
                      ),
                    )
                  : const ColoredBox(
                      color: Colors.black26,
                      child: Icon(Icons.music_note_rounded, color: Colors.white),
                    ),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  song == null ? 'Nothing playing yet' : song.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  song == null
                      ? 'Play any song and it starts for everyone'
                      : (room.songChangedBy != null
                          ? 'Picked by @${room.songChangedBy}'
                          : (song.artist ?? '')),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(color: Colors.white70, fontSize: 12),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _memberTile(RoomMemberModel member) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      child: Material(
        color: Pallete.cardColor,
        borderRadius: BorderRadius.circular(10),
        child: ListTile(
          leading: _avatar(member.name, member.isJoined && member.online),
          title: Text(
            member.isMe ? '${member.name} (you)' : member.name,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: Pallete.whiteColor,
              fontWeight: FontWeight.w600,
            ),
          ),
          subtitle: Text(
            '@${member.username}',
            style: const TextStyle(color: Pallete.subtitleText, fontSize: 12),
          ),
          trailing: Text(
            member.isJoined ? (member.online ? 'Listening' : 'Away') : 'Invited',
            style: TextStyle(
              fontSize: 12,
              color: member.isJoined && member.online
                  ? Pallete.greenColor
                  : Pallete.subtitleText,
            ),
          ),
        ),
      ),
    );
  }
}
