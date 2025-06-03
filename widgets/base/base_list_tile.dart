import 'package:flutter/material.dart';

class BaseListTile extends StatefulWidget {
  final String title;
  final Widget? subtitle;
  final Widget? leading;
  final Widget? trailing;
  final VoidCallback? onTap;
  final EdgeInsetsGeometry margin;
  final EdgeInsetsGeometry? contentPadding;
  final double elevation;
  final Widget? badge;
  final Widget? expandableContent;
  final bool isExpandable;
  final Future<bool?> Function(DismissDirection)? confirmDismiss;
  final void Function()? onDismissed;
  final bool initiallyExpanded;
  final void Function(bool)? onExpansionChanged;
  final bool dense;
  final bool isDismissible;
  final TextStyle? titleTextStyle;

  const BaseListTile({
    Key? key,
    required this.title,
    this.subtitle,
    this.leading,
    this.trailing,
    this.onTap,
    this.margin = const EdgeInsets.symmetric(vertical: 4.0, horizontal: 8.0),
    this.contentPadding,
    this.elevation = 1.0,
    this.badge,
    this.expandableContent,
    this.isExpandable = false,
    this.confirmDismiss,
    this.onDismissed,
    this.initiallyExpanded = false,
    this.onExpansionChanged,
    this.dense = false,
    this.isDismissible = true,
    this.titleTextStyle,
  }) : super(key: key);

  @override
  State<BaseListTile> createState() => _BaseListTileState();
}

class _BaseListTileState extends State<BaseListTile>
    with SingleTickerProviderStateMixin {
  bool _isExpanded = false;
  late AnimationController _controller;
  late Animation<double> _expandAnimation;

  @override
  void initState() {
    super.initState();
    _isExpanded = widget.initiallyExpanded;
    _controller = AnimationController(
      duration: const Duration(milliseconds: 200),
      vsync: this,
    );
    _expandAnimation = CurvedAnimation(
      parent: _controller,
      curve: Curves.easeInOut,
    );
    if (_isExpanded) {
      _controller.value = 1.0;
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _toggleExpand() {
    setState(() {
      _isExpanded = !_isExpanded;
      if (_isExpanded) {
        _controller.forward();
      } else {
        _controller.reverse();
      }
      if (widget.onExpansionChanged != null) {
        widget.onExpansionChanged!(_isExpanded);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final bool hasExpandableContent =
        widget.isExpandable && widget.expandableContent != null;

    return widget.isDismissible
        ? Dismissible(
          key: widget.key ?? UniqueKey(),
          direction: DismissDirection.endToStart,
          background: Container(
            margin: widget.margin,
            decoration: BoxDecoration(color: Colors.red),
            alignment: Alignment.centerRight,
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: const Icon(Icons.exit_to_app, color: Colors.white),
          ),
          confirmDismiss: widget.confirmDismiss,
          onDismissed: (_) {
            if (widget.onDismissed != null) widget.onDismissed!();
          },
          child: _buildCard(context, hasExpandableContent),
        )
        : _buildCard(context, hasExpandableContent);
  }

  Widget _buildCard(BuildContext context, bool hasExpandableContent) {
    return Card(
      color: Colors.grey.shade50,
      margin: widget.margin,
      elevation: widget.elevation,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Stack(
            children: [
              ListTile(
                dense: widget.dense,
                minVerticalPadding: widget.dense ? 0 : null,
                contentPadding: widget.contentPadding,
                title: Text(
                  widget.title,
                  style:
                      widget.titleTextStyle ??
                      Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontSize: widget.dense ? 13 : null,
                      ),
                  overflow: TextOverflow.ellipsis,
                ),
                subtitle: widget.subtitle,
                leading: widget.leading,
                trailing:
                    hasExpandableContent
                        ? RotationTransition(
                          turns: Tween(
                            begin: 0.0,
                            end: 0.25,
                          ).animate(_expandAnimation),
                          child: Icon(
                            Icons.chevron_right,
                            size: widget.dense ? 16 : 24,
                          ),
                        )
                        : widget.trailing,
                onTap: hasExpandableContent ? _toggleExpand : widget.onTap,
                visualDensity:
                    widget.dense
                        ? VisualDensity.compact
                        : VisualDensity.standard,
              ),
              if (widget.badge != null)
                Positioned(top: 0, right: 0, child: widget.badge!),
            ],
          ),
          if (hasExpandableContent)
            SizeTransition(
              sizeFactor: _expandAnimation,
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16.0,
                  vertical: 8.0,
                ),
                child: widget.expandableContent,
              ),
            ),
        ],
      ),
    );
  }
}
