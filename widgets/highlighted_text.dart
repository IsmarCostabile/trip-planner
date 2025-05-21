import 'package:flutter/material.dart';

class HighlightedText extends StatelessWidget {
  final String text;
  final Color highlightColor;
  final TextStyle style;

  const HighlightedText({
    Key? key,
    required this.text,
    required this.highlightColor,
    this.style = const TextStyle(fontWeight: FontWeight.bold),
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: highlightColor.withOpacity(0.3),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(text, style: style),
    );
  }
}
