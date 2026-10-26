import 'package:flutter/material.dart';
import '../../../../core/theme/app_pallete.dart';

/// Square playlist artwork: a 2x2 collage for 4+ images, a single image for fewer,
/// or a gradient placeholder when the playlist is empty.
class PlaylistCover extends StatelessWidget {
  final List<String> images;
  final double size;
  final double radius;

  const PlaylistCover({
    super.key,
    required this.images,
    this.size = 48,
    this.radius = 8,
  });

  Widget _image(String url) {
    return Image.network(
      url,
      fit: BoxFit.cover,
      errorBuilder: (_, _, _) => Container(
        color: Pallete.borderColor,
        child: const Icon(Icons.music_note_rounded, color: Pallete.subtitleText),
      ),
    );
  }

  Widget _placeholder() {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [Pallete.gradient1, Pallete.gradient2],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Icon(
        Icons.queue_music_rounded,
        color: Colors.white,
        size: size * 0.5,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    Widget content;
    if (images.isEmpty) {
      content = _placeholder();
    } else if (images.length < 4) {
      content = _image(images.first);
    } else {
      content = Column(
        children: [
          Expanded(
            child: Row(
              children: [
                Expanded(child: _image(images[0])),
                Expanded(child: _image(images[1])),
              ],
            ),
          ),
          Expanded(
            child: Row(
              children: [
                Expanded(child: _image(images[2])),
                Expanded(child: _image(images[3])),
              ],
            ),
          ),
        ],
      );
    }

    return ClipRRect(
      borderRadius: BorderRadius.circular(radius),
      child: SizedBox(width: size, height: size, child: content),
    );
  }
}
