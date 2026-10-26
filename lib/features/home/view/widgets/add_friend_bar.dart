import 'package:flutter/material.dart';
import '../../../../core/theme/app_pallete.dart';

class AddFriendBar extends StatefulWidget {
  /// Sends the request for the typed username. Return true on success (the field is then cleared),
  /// false to keep the text so the user can fix a typo.
  final Future<bool> Function(String username) onAdd;

  const AddFriendBar({
    super.key,
    required this.onAdd,
  });

  @override
  State<AddFriendBar> createState() => _AddFriendBarState();
}

class _AddFriendBarState extends State<AddFriendBar> {
  final TextEditingController _controller = TextEditingController();
  bool _isSending = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_isSending) return;
    var text = _controller.text.trim();
    if (text.startsWith('@')) {
      text = text.substring(1).trim();
    }
    if (text.isEmpty) return;

    FocusScope.of(context).unfocus();
    setState(() => _isSending = true);
    var success = false;
    try {
      success = await widget.onAdd(text);
    } catch (_) {
      success = false;
    }
    if (!mounted) return;
    setState(() => _isSending = false);
    if (success) {
      _controller.clear();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 52,
      decoration: BoxDecoration(
        color: Pallete.cardColor,
        borderRadius: BorderRadius.circular(26),
        border: Border.all(
          color: Pallete.borderColor.withAlpha(140),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(70),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Row(
        children: [
          const SizedBox(width: 16),
          const Icon(
            Icons.person_search_rounded,
            color: Pallete.subtitleText,
            size: 22,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: TextField(
              controller: _controller,
              enabled: !_isSending,
              autocorrect: false,
              textInputAction: TextInputAction.send,
              style: const TextStyle(
                color: Pallete.whiteColor,
                fontSize: 14,
              ),
              decoration: const InputDecoration(
                hintText: "Friend's username",
                hintStyle: TextStyle(
                  color: Pallete.subtitleText,
                  fontSize: 13,
                ),
                border: InputBorder.none,
                enabledBorder: InputBorder.none,
                focusedBorder: InputBorder.none,
                contentPadding: EdgeInsets.symmetric(vertical: 14),
              ),
              onSubmitted: (_) => _submit(),
            ),
          ),
          Padding(
            padding: const EdgeInsets.only(right: 6.0),
            child: InkWell(
              onTap: _isSending ? null : _submit,
              borderRadius: BorderRadius.circular(20),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Pallete.gradient1, Pallete.gradient2],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                      color: Pallete.gradient1.withAlpha(80),
                      blurRadius: 6,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: _isSending
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Text(
                        'Add',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
