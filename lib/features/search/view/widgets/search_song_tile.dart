import 'package:flutter/material.dart';
import '../../../../core/services/favorites_service.dart';
import '../../../../core/theme/app_pallete.dart';
import '../../../playlists/view/widgets/add_to_playlist_sheet.dart';
import '../../model/song_model.dart';

class SearchSongTile extends StatelessWidget {
  final SongModel song;
  final bool isSelected;
  final bool isPlaying;
  final VoidCallback onTap;

  const SearchSongTile({
    super.key,
    required this.song,
    required this.isSelected,
    required this.isPlaying,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isLiked = FavoritesService().isLiked(song.id);

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: Material(
        color: isSelected ? Pallete.cardColor : Colors.transparent,
        borderRadius: BorderRadius.circular(8),
        clipBehavior: Clip.antiAlias,
        child: ListTile(
          onTap: onTap,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 10,
            vertical: 4,
          ),
          leading: ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: Container(
              width: 52,
              height: 52,
              color: Pallete.cardColor,
              child: song.image.isNotEmpty
                  ? Image.network(
                      song.image,
                      fit: BoxFit.cover,
                      errorBuilder: (_, _, _) => Container(
                        color: Pallete.borderColor,
                        child: const Icon(
                          Icons.music_note_rounded,
                          color: Pallete.subtitleText,
                        ),
                      ),
                    )
                  : const Icon(
                      Icons.music_note_rounded,
                      color: Pallete.subtitleText,
                    ),
            ),
          ),
          title: Text(
            song.song,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 15,
              fontWeight: isSelected ? FontWeight.bold : FontWeight.w600,
              color: isSelected ? Pallete.gradient2 : Pallete.whiteColor,
            ),
          ),
          subtitle: Padding(
            padding: const EdgeInsets.only(top: 4.0),
            child: Text(
              '${song.displayArtist} • ${song.album.isNotEmpty ? song.album : (song.year.isNotEmpty ? song.year : 'Single')}',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 12, color: Pallete.subtitleText),
            ),
          ),
          trailing: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              IconButton(
                iconSize: 22,
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
                tooltip: isLiked ? 'Unlike' : 'Like',
                onPressed: () {
                  FavoritesService().toggleLike(song);
                },
                icon: Icon(
                  isLiked
                      ? Icons.favorite_rounded
                      : Icons.favorite_border_rounded,
                  color: isLiked ? Pallete.gradient2 : Pallete.subtitleText,
                ),
              ),
              const SizedBox(width: 10),
              IconButton(
                iconSize: 22,
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
                tooltip: 'Add to playlist',
                onPressed: () => showAddToPlaylistSheet(context, song),
                icon: const Icon(
                  Icons.playlist_add_rounded,
                  color: Pallete.subtitleText,
                ),
              ),
              const SizedBox(width: 10),
              Text(
                song.formattedDuration,
                style: const TextStyle(
                  fontSize: 12,
                  color: Pallete.subtitleText,
                ),
              ),
              const SizedBox(width: 10),
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: isSelected
                      ? Pallete.gradient2
                      : Pallete.borderColor.withAlpha(120),
                ),
                child: Icon(
                  isSelected && isPlaying
                      ? Icons.pause_rounded
                      : Icons.play_arrow_rounded,
                  color: Colors.white,
                  size: 20,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
