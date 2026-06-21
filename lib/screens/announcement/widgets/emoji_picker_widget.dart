import 'package:flutter/material.dart';
import 'simple_emoji_picker.dart';

class EmojiPickerWidget extends StatelessWidget {
  final Function(String) onEmojiSelected;
  final VoidCallback onBackspacePressed;
  final bool showPicker;

  const EmojiPickerWidget({
    super.key,
    required this.onEmojiSelected,
    required this.onBackspacePressed,
    this.showPicker = true,
  });

  @override
  Widget build(BuildContext context) {
    if (!showPicker) return const SizedBox.shrink();

    return SimpleEmojiPicker(
      onEmojiSelected: onEmojiSelected,
      onBackspacePressed: onBackspacePressed,
    );
  }
}