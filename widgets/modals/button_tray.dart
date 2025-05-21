import 'package:flutter/material.dart';

class ButtonTray extends StatelessWidget {
  final Widget primaryButton;
  final Widget secondaryButton;
  final double spacing;
  final EdgeInsetsGeometry padding;
  final bool showDivider;

  const ButtonTray({
    Key? key,
    required this.primaryButton,
    required this.secondaryButton,
    this.spacing = 16.0,
    this.padding = const EdgeInsets.all(16.0),
    this.showDivider = true,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (showDivider) Divider(height: 1, color: theme.dividerColor),
        Container(
          padding: padding,
          color: theme.cardColor,
          child: Row(
            children: [
              Expanded(child: secondaryButton),
              SizedBox(width: spacing),
              Expanded(child: primaryButton),
            ],
          ),
        ),
      ],
    );
  }
}
