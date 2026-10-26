import 'package:flutter/material.dart';
import '../../../../core/services/room_service.dart';
import '../../../../core/theme/app_pallete.dart';
import '../../../home/view/widgets/room_action_button.dart';
import '../../model/room_models.dart';
import '../pages/room_page.dart';

/// Home-screen block under "Listen with Friends": create a room, answer invites,
/// or (when already in a room) a status card that opens it.
class RoomHomeSection extends StatefulWidget {
  const RoomHomeSection({super.key});

  @override
  State<RoomHomeSection> createState() => _RoomHomeSectionState();
}

class _RoomHomeSectionState extends State<RoomHomeSection> {
  final RoomService _service = RoomService();
  String? _busyInviteRoomId;

  @override
  void initState() {
    super.initState();
    _service.addListener(_onUpdate);
  }

  @override
  void dispose() {
    _service.removeListener(_onUpdate);
    super.dispose();
  }

  void _onUpdate() {
    if (!mounted) return;
    final String? notice = _service.takeNotice();
    if (notice != null) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(notice)));
    }
    setState(() {});
  }

  void _openRoom() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (BuildContext context) => const RoomPage()),
    );
  }

  Future<void> _accept(RoomInviteModel invite) async {
    if (_busyInviteRoomId != null) return;
    setState(() => _busyInviteRoomId = invite.roomId);
    final String? error = await _service.accept(invite);
    if (!mounted) return;
    setState(() => _busyInviteRoomId = null);
    if (error != null) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(error)));
    }
  }

  @override
  Widget build(BuildContext context) {
    final RoomModel? room = _service.room;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0),
      child: room != null ? _roomCard(room) : _createAndInvites(),
    );
  }

  Widget _createAndInvites() {
    return Column(
      children: [
        Row(
          children: [
            RoomActionButton(
              label: 'Create Room',
              icon: Icons.sensors_rounded,
              isPrimary: true,
              onTap: _openRoom,
            ),
          ],
        ),
        for (final RoomInviteModel invite in _service.invites) _inviteCard(invite),
      ],
    );
  }

  Widget _inviteCard(RoomInviteModel invite) {
    final bool busy = _busyInviteRoomId == invite.roomId;
    return Container(
      margin: const EdgeInsets.only(top: 10),
      padding: const EdgeInsets.fromLTRB(14, 12, 8, 12),
      decoration: BoxDecoration(
        color: Pallete.cardColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Pallete.gradient1.withAlpha(150)),
      ),
      child: Row(
        children: [
          const Icon(Icons.headphones_rounded, color: Pallete.gradient2),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${invite.inviterLabel} invited you to listen together',
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Pallete.whiteColor,
                    fontWeight: FontWeight.w600,
                    fontSize: 13,
                  ),
                ),
                Text(
                  '${invite.memberCount} in the room so far',
                  style: const TextStyle(color: Pallete.subtitleText, fontSize: 12),
                ),
              ],
            ),
          ),
          TextButton(
            onPressed: busy ? null : () => _service.decline(invite),
            child: const Text('Decline', style: TextStyle(color: Pallete.subtitleText)),
          ),
          ElevatedButton(
            onPressed: busy ? null : () => _accept(invite),
            style: ElevatedButton.styleFrom(
              backgroundColor: Pallete.gradient2,
              foregroundColor: Colors.white,
            ),
            child: busy
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                  )
                : const Text('Join'),
          ),
        ],
      ),
    );
  }

  Widget _roomCard(RoomModel room) {
    final RoomSongModel? song = room.song;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: _openRoom,
        borderRadius: BorderRadius.circular(14),
        child: Container(
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
              const Icon(Icons.sensors_rounded, color: Colors.white),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'In a room • ${room.members.where((m) => m.isJoined).length}/${room.capacity}',
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 15,
                      ),
                    ),
                    Text(
                      song == null ? 'Play a song to share it' : '♪ ${song.title}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(color: Colors.white70, fontSize: 12),
                    ),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right_rounded, color: Colors.white),
            ],
          ),
        ),
      ),
    );
  }
}
