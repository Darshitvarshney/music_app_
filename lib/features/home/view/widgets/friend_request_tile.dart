import 'package:flutter/material.dart';
import '../../../../core/theme/app_pallete.dart';
import '../../../friends/model/friend_models.dart';
import 'friend_card.dart';

/// One incoming friend request with Accept / Decline.
class FriendRequestTile extends StatefulWidget {
  final FriendRequestModel request;
  final Future<void> Function() onAccept;
  final Future<void> Function() onDecline;

  const FriendRequestTile({
    super.key,
    required this.request,
    required this.onAccept,
    required this.onDecline,
  });

  @override
  State<FriendRequestTile> createState() => _FriendRequestTileState();
}

class _FriendRequestTileState extends State<FriendRequestTile> {
  bool _busy = false;

  Future<void> _run(Future<void> Function() action) async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      await action();
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final request = widget.request;
    final displayName = request.name.isNotEmpty ? request.name : request.username;

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Pallete.cardColor,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Pallete.gradient1.withAlpha(80)),
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 20,
            backgroundColor: friendGradientFor(request.username).first,
            child: Text(
              displayName.isNotEmpty ? displayName[0].toUpperCase() : 'F',
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  displayName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Pallete.whiteColor,
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                ),
                Text(
                  '@${request.username} wants to be friends',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Pallete.subtitleText,
                    fontSize: 11,
                  ),
                ),
              ],
            ),
          ),
          if (_busy)
            const SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: Pallete.gradient2,
              ),
            )
          else ...[
            IconButton(
              tooltip: 'Decline',
              onPressed: () => _run(widget.onDecline),
              icon: const Icon(Icons.close_rounded, color: Pallete.subtitleText),
            ),
            IconButton(
              tooltip: 'Accept',
              onPressed: () => _run(widget.onAccept),
              icon: const Icon(Icons.check_circle_rounded, color: Color(0xFF00E676)),
            ),
          ],
        ],
      ),
    );
  }
}
