import 'package:flutter/material.dart';
import '../../../../core/theme/app_pallete.dart';

/// Asks for a playlist name. Returns the trimmed name, or `null` if cancelled.
Future<String?> promptPlaylistName(
  BuildContext context, {
  String title = 'New playlist',
  String confirmLabel = 'Create',
  String initialName = '',
}) {
  return showDialog<String>(
    context: context,
    builder: (BuildContext dialogContext) =>
        _PlaylistNameDialog(
          title: title,
          confirmLabel: confirmLabel,
          initialName: initialName,
        ),
  );
}

class _PlaylistNameDialog extends StatefulWidget {
  final String title;
  final String confirmLabel;
  final String initialName;

  const _PlaylistNameDialog({
    required this.title,
    required this.confirmLabel,
    required this.initialName,
  });

  @override
  State<_PlaylistNameDialog> createState() => _PlaylistNameDialogState();
}

class _PlaylistNameDialogState extends State<_PlaylistNameDialog> {
  late final TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.initialName);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _submit() {
    final String name = _controller.text.trim();
    if (name.isEmpty) return;
    Navigator.pop(context, name);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: Pallete.cardColor,
      title: Text(
        widget.title,
        style: const TextStyle(color: Pallete.whiteColor),
      ),
      content: TextField(
        controller: _controller,
        autofocus: true,
        maxLength: 80,
        textCapitalization: TextCapitalization.sentences,
        style: const TextStyle(color: Pallete.whiteColor),
        cursorColor: Pallete.gradient2,
        decoration: const InputDecoration(
          hintText: 'Playlist name',
          hintStyle: TextStyle(color: Pallete.subtitleText),
          counterStyle: TextStyle(color: Pallete.subtitleText),
          enabledBorder: UnderlineInputBorder(
            borderSide: BorderSide(color: Pallete.borderColor),
          ),
          focusedBorder: UnderlineInputBorder(
            borderSide: BorderSide(color: Pallete.gradient2),
          ),
        ),
        onSubmitted: (_) => _submit(),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text(
            'Cancel',
            style: TextStyle(color: Pallete.subtitleText),
          ),
        ),
        TextButton(
          onPressed: _submit,
          child: Text(
            widget.confirmLabel,
            style: const TextStyle(color: Pallete.gradient2),
          ),
        ),
      ],
    );
  }
}
