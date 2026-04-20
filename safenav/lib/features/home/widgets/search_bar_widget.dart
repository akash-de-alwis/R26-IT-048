import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';

class SearchBarWidget extends StatefulWidget {
  final ValueChanged<String> onSubmitted;
  final ValueChanged<String>? onSearchTap;

  const SearchBarWidget({
    super.key,
    required this.onSubmitted,
    this.onSearchTap,
  });

  @override
  State<SearchBarWidget> createState() => _SearchBarWidgetState();
}

class _SearchBarWidgetState extends State<SearchBarWidget> {
  final _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _handleArrowTap() {
    final text = _controller.text.trim();
    if (widget.onSearchTap != null) {
      widget.onSearchTap!(text);
    } else {
      widget.onSubmitted(text);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 52,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE8EDF2)),
      ),
      child: Row(
        children: [
          const SizedBox(width: 14),
          const Icon(Icons.search, color: AppColors.primary, size: 20),
          const SizedBox(width: 8),
          Expanded(
            child: TextField(
              controller: _controller,
              onSubmitted: widget.onSubmitted,
              style: const TextStyle(
                fontSize: 14,
                color: AppColors.textPrimary,
              ),
              decoration: const InputDecoration(
                hintText: 'Search destination...',
                hintStyle: TextStyle(
                  fontSize: 14,
                  color: AppColors.textHint,
                ),
                border: InputBorder.none,
                enabledBorder: InputBorder.none,
                focusedBorder: InputBorder.none,
                isDense: true,
                contentPadding: EdgeInsets.zero,
              ),
            ),
          ),
          const SizedBox(width: 6),
          GestureDetector(
            onTap: _handleArrowTap,
            child: Container(
              width: 40,
              height: 40,
              margin: const EdgeInsets.all(6),
              decoration: const BoxDecoration(
                color: AppColors.primary,
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.arrow_forward,
                color: Colors.white,
                size: 18,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
