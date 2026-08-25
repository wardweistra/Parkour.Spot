import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'emoji_text.dart';

/// A reusable scaffold widget that provides consistent layout across pages.
/// 
/// Features:
/// - Consistent AppBar with back button
/// - Consistent max width (1200px)
/// - Consistent padding (16px)
/// - Scrollable body
/// - Optional title and actions
class PageScaffold extends StatelessWidget {
  /// The title to display in the AppBar
  final String? title;
  
  /// Optional actions to display in the AppBar
  final List<Widget>? actions;
  
  /// The body content of the page
  final Widget body;
  
  /// Whether to show the back button (default: true)
  final bool showBackButton;
  
  /// Custom back button action (default: navigates back)
  final VoidCallback? onBack;
  
  /// Whether the body should be scrollable (default: true)
  final bool scrollable;
  
  /// Custom padding for the body (default: EdgeInsets.all(16.0))
  final EdgeInsets? padding;
  
  /// Whether to center the content (default: true)
  final bool centerContent;
  
  /// Maximum width constraint (default: 1200)
  final double maxWidth;

  const PageScaffold({
    super.key,
    this.title,
    this.actions,
    required this.body,
    this.showBackButton = true,
    this.onBack,
    this.scrollable = true,
    this.padding,
    this.centerContent = true,
    this.maxWidth = 1200,
  });

  @override
  Widget build(BuildContext context) {
    // Determine padding to use
    final effectivePadding = padding ?? const EdgeInsets.all(16.0);
    
    final PreferredSizeWidget? appBar =
        title != null || actions != null || showBackButton
        ? AppBar(
            // Keep the toolbar row inside [maxWidth] centered on wide viewports,
            // while this AppBar's Material (and M3 scrolled-under tint) spans
            // the full scaffold width.
            centerTitle: true,
            automaticallyImplyLeading: false,
            elevation: 0,
            titleSpacing: NavigationToolbar.kMiddleSpacing,
            title: Center(
              child: ConstrainedBox(
                constraints: BoxConstraints(maxWidth: maxWidth),
                child: Padding(
                  padding: EdgeInsets.symmetric(
                    horizontal: effectivePadding.horizontal / 2,
                  ),
                  child: Row(
                    children: [
                      if (showBackButton)
                        BackButton(
                          onPressed: onBack ??
                              () {
                                if (Navigator.canPop(context)) {
                                  Navigator.pop(context);
                                } else {
                                  context.go('/explore');
                                }
                              },
                        ),
                      if (title != null)
                        Expanded(
                          child: Align(
                            alignment: Alignment.centerLeft,
                            child: EmojiText(
                              title!,
                              overflow: TextOverflow.ellipsis,
                              maxLines: 1,
                            ),
                          ),
                        )
                      else if (actions != null && actions!.isNotEmpty)
                        const Spacer(),
                      if (actions != null) ...actions!,
                    ],
                  ),
                ),
              ),
            ),
          )
        : null;
    
    Widget content = Padding(
      padding: effectivePadding,
      child: body,
    );

    // Apply max width constraint
    if (centerContent) {
      content = ConstrainedBox(
        constraints: BoxConstraints(maxWidth: maxWidth),
        child: content,
      );
    }

    // Wrap in scroll view if needed, with proper centering
    if (scrollable) {
      content = SingleChildScrollView(
        child: centerContent
            ? Center(
                child: ConstrainedBox(
                  constraints: BoxConstraints(maxWidth: maxWidth),
                  child: Padding(
                    padding: effectivePadding,
                    child: body,
                  ),
                ),
              )
            : content,
      );
    } else if (centerContent) {
      // For non-scrollable content, wrap in Center
      content = Center(
        child: content,
      );
    }

    return Scaffold(
      appBar: appBar,
      body: content,
    );
  }
}
