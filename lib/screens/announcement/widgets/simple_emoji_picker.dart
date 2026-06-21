import 'package:flutter/material.dart';

class SimpleEmojiPicker extends StatelessWidget {
  final Function(String) onEmojiSelected;
  final VoidCallback onBackspacePressed;

  const SimpleEmojiPicker({
    super.key,
    required this.onEmojiSelected,
    required this.onBackspacePressed,
  });

  static const List<String> _emojis = [
    // Smileys & Emotion
    '😀', '😃', '😄', '😁', '😅', '😂', '🤣', '😊',
    '😍', '🥰', '😘', '😗', '😙', '😚',  '😜',
    '🤪', '😝', '🤑', '🤗', '🤭', '🤫', '🤔', '🤐',
    '🤨', '😐', '😑', '😶', '😏', '😒', '🙄', '😬',
    '🤥', '😌', '😔', '😪', '🤤', '😴', '😷', '🤒',
    '🤕', '🤢', '🤮', '🥴', '😵', '🤯', '🤠', '🥳',
    '😎', '🤓', '🧐', '😕', '😟', '🙁', '☹️', '😮',
    '😯', '😲', '😳', '🥺', '😦', '😧', '😨', '😰',
    '😥', '😢', '😭', '😱', '😖', '😣', '😞', '😓',
    '😩', '😫', '🥱', '😤', '😡', '😠', '🤬', '😈',
    '👿', '💀', '☠️', '💩', '🤡', '👹', '👺', '👻',
    '👽', '👾', '🤖',
    // Hearts & Love
    '💝', '💖', '💗', '💓', '💞', '💕', '💟', '❣️',
    '💔', '❤️', '🧡', '💛', '💚', '💙', '💜', '🤎',
    '🖤', '🤍',
    // Symbols
    '💯', '💢', '💬', '💭', '💤', '💪', '🦾',
    // Body Parts
    '🦵', '🦶', '👂', '🦻', '👃', '🧠', '🦷', '🦴',
    '👀', '👁️', '👅', '👄',
    // Hands
    '👍', '👎', '👊', '✊', '🤛', '🤜', '👏', '🙌',
    '👐', '🤲', '🤝', '🙏', '✌️', '🤟', '🤘', '👌',
    // Animals
    '🐶', '🐱', '🐭', '🐹', '🐰', '🦊', '🐻', '🐼',
    '🐨', '🐯', '🦁', '🐮', '🐷', '🐸', '🐵', '🐔',
    '🐧', '🐦', '🐤', '🐣', '🐥', '🦆', '🦅', '🦉',
    '🐺', '🐗', '🐴', '🦄', '🐝', '🐛', '🦋', '🐌',
    // Food
    '🍎', '🍐', '🍊', '🍋', '🍌', '🍉', '🍇', '🍓',
    '🫐', '🍈', '🍒', '🍑', '🥭', '🍍', '🥥', '🥝',
    '🍅', '🍆', '🥑', '🫑', '🌽', '🥕', '🫒', '🧄',
    '🧅', '🥔', '🍠', '🥐', '🥯', '🍞', '🥖', '🥨',
    '🧀', '🥚', '🍳', '🥞', '🧇', '🥓', '🥩', '🍗',
    '🍖', '🦴', '🌭', '🍔', '🍟', '🍕', '🫓', '🥪',
    '🥙', '🧆', '🌮', '🌯', '🥗', '🥘', '🫕', '🥫',
    '🍝', '🍜', '🍲', '🍛', '🍣', '🍱', '🥟', '🦪',
    '🍤', '🍙', '🍚', '🍘', '🍥', '🥠', '🥮', '🍡',
    '🍢', '🍧', '🍨', '🍦', '🥧', '🧁', '🍰', '🎂',
    '🍮', '🍭', '🍬', '🍫', '🍿', '🍩', '🍪', '🧋',
    '🧃', '🥤', '🧊', '🍺', '🍻', '🥂', '🍷', '🥃',
    // Activities
    '⚽', '🏀', '🏈', '⚾', '🥎', '🎾', '🏐', '🏉',
    '🥏', '🎱', '🪀', '🏓', '🏸', '🏒', '🏑', '🥍',
    '🏏', '⛳', '🏹', '🎣', '🤿', '🥊', '🥋', '🎽',
    '🛹', '🛼', '🚴', '🚵', '🏋️', '🤸', '⛹️', '🤾',
    '🏌️', '🏇', '🧘', '🏄', '🏊', '🤽', '🚣', '🧗',
    '🚵', '🪂',
    // Travel
    '🚗', '🚕', '🚙', '🚌', '🚎', '🏎️', '🚓', '🚑',
    '🚒', '🚐', '🛻', '🚚', '🚛', '🚜', '🏍️', '🛵',
    '🚲', '🛴', '🛹', '🛼', '🚁', '✈️', '🛩️', '🛫',
    '🛬', '🪂', '💺', '🚀', '🛸', '🚄', '🚅', '🚆',
    '🚇', '🚈', '🚉', '🚊', '🚝', '🚞', '🚋', '🚃',
    '🚎', '🚌', '🚍', '🚙', '🚗', '🚕', '🚚', '🚛',
  ];

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 280,
      color: Colors.white,
      child: Column(
        children: [
          // Header
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              color: const Color(0xFFF8FAFB),
              border: Border(
                bottom: BorderSide(color: Colors.grey.shade200),
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Emojis',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Colors.black87,
                  ),
                ),
                Row(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.backspace, color: Colors.black87),
                      onPressed: onBackspacePressed,
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                    ),
                    const SizedBox(width: 8),
                    IconButton(
                      icon: const Icon(Icons.close, color: Colors.black87),
                      onPressed: () {
                        // Close the picker - this will be handled by parent
                      },
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                    ),
                  ],
                ),
              ],
            ),
          ),
          // Emoji grid
          Expanded(
            child: GridView.builder(
              padding: const EdgeInsets.all(8),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 8,
                childAspectRatio: 1.0,
                crossAxisSpacing: 2,
                mainAxisSpacing: 2,
              ),
              itemCount: _emojis.length,
              itemBuilder: (context, index) {
                return GestureDetector(
                  onTap: () => onEmojiSelected(_emojis[index]),
                  child: Container(
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(8),
                      color: Colors.grey.shade50,
                    ),
                    child: Text(
                      _emojis[index],
                      style: const TextStyle(fontSize: 28),
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}