import 'package:flutter/material.dart';
import 'package:trip_planner/widgets/location_photo_carousel.dart';

/// A utility function to show a modal bottom sheet with consistent styling
/// and behavior throughout the app.
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
  // Use the provided context, but recommend passing the root context for best results
  return showModalBottomSheet<T>(
    context: context,
    isScrollControlled: isScrollControlled,
    isDismissible: isDismissible,
    useSafeArea: useSafeArea,
    backgroundColor: backgroundColor,
    builder: builder,
  );
}

/// A base class for modal bottom sheets in the app.
/// Provides consistent styling and behavior.
class BaseModal extends StatelessWidget {
  /// The primary content of the modal.
  final Widget child;

  /// Whether the modal is scrollable.
  final bool isScrollable;

  /// The controller for the scrollable content, if any.
  final ScrollController? scrollController;

  /// The initial size of the modal as a fraction of the screen height.
  final double initialChildSize;

  /// The minimum size of the modal as a fraction of the screen height.
  final double minChildSize;

  /// The maximum size of the modal as a fraction of the screen height.
  final double maxChildSize;

  /// The background color of the modal.
  final Color? backgroundColor;

  /// Optional footer widget (buttons, etc.), which will be pinned at the bottom.
  final Widget? footer;

  /// Optional loading indicator to show when the modal is loading content.
  final bool isLoading;

  /// Optional padding for the entire modal container.
  final EdgeInsetsGeometry? padding;

  /// Optional title for the modal.
  final String? title;

  /// Whether to dismiss keyboard when tapping outside content
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
      // When tapping the modal background, dismiss the keyboard
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
        // Use LayoutBuilder to ensure we have proper constraints
        child: LayoutBuilder(
          builder: (context, constraints) {
            return Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Drag handle
                _buildDragHandle(context),

                // Title if provided
                if (title != null)
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Text(
                      title!,
                      style: theme.textTheme.titleLarge,
                      textAlign: TextAlign.center,
                    ),
                  ),

                // Loading indicator
                if (isLoading)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 8),
                    child: LinearProgressIndicator(),
                  ),

                // Main content - add SizedBox with constraints to prevent layout issues
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

                // Footer if provided
                if (footer != null) footer!,
              ],
            );
          },
        ),
      ),
    );
  }

  /// Builds the drag handle at the top of the modal
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

/// A standard button row for modal footers with consistent styling
class ModalFooter extends StatelessWidget {
  /// Primary action button
  final Widget? primaryButton;

  /// Secondary action button
  final Widget? secondaryButton;

  /// Additional buttons
  final List<Widget>? additionalButtons;

  /// Spacing between buttons
  final double spacing;

  /// Padding around the entire footer
  final EdgeInsetsGeometry padding;

  /// Whether to show a divider above the footer
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

    // Add secondary button if provided
    if (secondaryButton != null) {
      buttons.add(Expanded(child: secondaryButton!));
    }

    // Add spacing between buttons if both are provided
    if (secondaryButton != null && primaryButton != null) {
      buttons.add(SizedBox(width: spacing));
    }

    // Add primary button if provided
    if (primaryButton != null) {
      buttons.add(Expanded(child: primaryButton!));
    }

    // Add additional buttons
    if (additionalButtons != null && additionalButtons!.isNotEmpty) {
      for (final button in additionalButtons!) {
        buttons.add(SizedBox(width: spacing));
        buttons.add(Expanded(child: button));
      }
    }

    return buttons;
  }
}
