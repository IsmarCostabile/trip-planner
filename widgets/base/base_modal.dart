import 'package:flutter/material.dart';
import 'package:trip_planner/widgets/location_photo_carousel.dart';

Future<T?> showAppModal<T>({
  required BuildContext context,
  required Widget Function(BuildContext) builder,
  bool isDismissible = true,
  bool isScrollControlled = true,
  bool useSafeArea = true,
  Color backgroundColor = Colors.transparent,
  double initialChildSize = 0.6,
  double minChildSize = 0.6,
  double maxChildSize = 1.0,
}) {
  return showModalBottomSheet<T>(
    context: context,
    isScrollControlled: isScrollControlled,
    isDismissible: isDismissible,
    useSafeArea: useSafeArea,
    backgroundColor: backgroundColor,
    builder: builder,
  );
}

class BaseModal extends StatelessWidget {
  final Widget child;
  final bool isScrollable;
  final ScrollController? scrollController;
  final double initialChildSize;
  final double minChildSize;
  final double maxChildSize;
  final Color? backgroundColor;
  final Widget? footer;
  final bool isLoading;
  final EdgeInsetsGeometry? padding;
  final String? title;
  final bool dismissKeyboardOnTapOutside;

  const BaseModal({
    super.key,
    required this.child,
    this.isScrollable = true,
    this.scrollController,
    this.initialChildSize = 0.6,
    this.minChildSize = 0.6,
    this.maxChildSize = 1.0,
    this.backgroundColor,
    this.footer,
    this.isLoading = false,
    this.padding,
    this.title,
    this.dismissKeyboardOnTapOutside = true,
  });

  @override
  Widget build(BuildContext context) {
    return isScrollable
        ? _buildScrollableModal(context)
        : _buildStaticModal(context);
  }

  Widget _buildScrollableModal(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: initialChildSize,
      minChildSize: minChildSize,
      maxChildSize: maxChildSize,
      builder: (context, scrollController) {
        return _buildModalContainer(
          context,
          scrollController: scrollController,
        );
      },
    );
  }

  Widget _buildStaticModal(BuildContext context) {
    return _buildModalContainer(context);
  }

  Widget _buildModalContainer(
    BuildContext context, {
    ScrollController? scrollController,
  }) {
    final theme = Theme.of(context);

    return GestureDetector(
      onTap:
          dismissKeyboardOnTapOutside
              ? () => FocusScope.of(context).unfocus()
              : null,
      behavior: HitTestBehavior.translucent,
      child: Container(
        padding:
            padding ??
            EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
        ),
        child: LayoutBuilder(
          builder: (context, constraints) {
            return Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _buildDragHandle(context),
                if (title != null)
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Text(
                      title!,
                      style: theme.textTheme.titleLarge,
                      textAlign: TextAlign.center,
                    ),
                  ),
                if (isLoading)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 8),
                    child: LinearProgressIndicator(),
                  ),
                Flexible(
                  child: SizedBox(
                    width: constraints.maxWidth,
                    child:
                        isScrollable
                            ? SingleChildScrollView(
                              controller: scrollController,
                              child: child,
                            )
                            : child,
                  ),
                ),
                if (footer != null) footer!,
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _buildDragHandle(BuildContext context) {
    return Container(
      width: 40,
      height: 4,
      margin: const EdgeInsets.symmetric(vertical: 8),
      decoration: BoxDecoration(
        color: Colors.grey[300],
        borderRadius: BorderRadius.circular(2),
      ),
    );
  }
}

class ModalFooter extends StatelessWidget {
  final Widget? primaryButton;
  final Widget? secondaryButton;
  final List<Widget>? additionalButtons;
  final double spacing;
  final EdgeInsetsGeometry padding;
  final bool showDivider;

  const ModalFooter({
    super.key,
    this.primaryButton,
    this.secondaryButton,
    this.additionalButtons,
    this.spacing = 16.0,
    this.padding = const EdgeInsets.all(16.0),
    this.showDivider = true,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (showDivider) Divider(height: 1, color: Colors.black),
        Container(
          padding: padding,
          decoration: BoxDecoration(color: Colors.black),
          child: Row(children: _buildButtons()),
        ),
      ],
    );
  }

  List<Widget> _buildButtons() {
    final buttons = <Widget>[];

    if (secondaryButton != null) {
      buttons.add(Expanded(child: secondaryButton!));
    }

    if (secondaryButton != null && primaryButton != null) {
      buttons.add(SizedBox(width: spacing));
    }

    if (primaryButton != null) {
      buttons.add(Expanded(child: primaryButton!));
    }

    if (additionalButtons != null && additionalButtons!.isNotEmpty) {
      for (final button in additionalButtons!) {
        buttons.add(SizedBox(width: spacing));
        buttons.add(Expanded(child: button));
      }
    }

    return buttons;
  }
}
