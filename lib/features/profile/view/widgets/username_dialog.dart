import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../../core/network/api_exception.dart';
import '../../../../core/theme/app_pallete.dart';
import '../../model/profile_model.dart';
import '../../repositories/profile_repository.dart';

/// Asks the user to claim or change their username. Returns the updated profile when saved,
/// or null if they cancelled.
Future<ProfileModel?> showUsernameDialog(
  BuildContext context, {
  String? currentUsername,
  String? suggestion,
}) {
  return showDialog<ProfileModel>(
    context: context,
    barrierDismissible: false,
    builder: (ctx) => _UsernameDialog(
      currentUsername: currentUsername,
      suggestion: suggestion,
    ),
  );
}

class _UsernameDialog extends StatefulWidget {
  final String? currentUsername;
  final String? suggestion;

  const _UsernameDialog({this.currentUsername, this.suggestion});

  @override
  State<_UsernameDialog> createState() => _UsernameDialogState();
}

class _UsernameDialogState extends State<_UsernameDialog> {
  late final TextEditingController _controller;
  bool _saving = false;
  String? _error;

  bool get _isChange => widget.currentUsername != null;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(
      text: widget.currentUsername ?? widget.suggestion ?? '',
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_saving) return;
    final value = _controller.text.trim().toLowerCase();
    if (value.isEmpty) {
      setState(() => _error = 'Please enter a username');
      return;
    }

    setState(() {
      _saving = true;
      _error = null;
    });

    try {
      final profile = await ProfileRepository().setUsername(value);
      if (!mounted) return;
      Navigator.of(context).pop(profile);
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _saving = false;
        _error = e.message;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _saving = false;
        _error = 'Could not save. Check your connection and try again.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: Pallete.cardColor,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      title: Text(
        _isChange ? 'Change username' : 'Choose a username',
        style: const TextStyle(
          color: Pallete.whiteColor,
          fontWeight: FontWeight.bold,
        ),
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            _isChange
                ? 'Friends find you by this name. You can change it only once every 30 days.'
                : 'Friends add you by this name. 3-20 letters, numbers or underscores, starting with a letter.',
            style: const TextStyle(color: Pallete.subtitleText, fontSize: 13),
          ),
          const SizedBox(height: 14),
          TextField(
            controller: _controller,
            enabled: !_saving,
            autofocus: true,
            autocorrect: false,
            textInputAction: TextInputAction.done,
            inputFormatters: [
              FilteringTextInputFormatter.allow(RegExp(r'[A-Za-z0-9_]')),
              LengthLimitingTextInputFormatter(20),
            ],
            style: const TextStyle(color: Pallete.whiteColor),
            decoration: InputDecoration(
              prefixText: '@',
              hintText: 'username',
              errorText: _error,
              errorMaxLines: 3,
            ),
            onSubmitted: (_) => _save(),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: _saving ? null : () => Navigator.of(context).pop(),
          child: const Text(
            'Cancel',
            style: TextStyle(color: Pallete.subtitleText),
          ),
        ),
        ElevatedButton(
          onPressed: _saving ? null : _save,
          style: ElevatedButton.styleFrom(
            backgroundColor: Pallete.gradient1,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
          ),
          child: _saving
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Colors.white,
                  ),
                )
              : const Text('Save', style: TextStyle(color: Colors.white)),
        ),
      ],
    );
  }
}
