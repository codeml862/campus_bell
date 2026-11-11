import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import '../core/theme.dart';
import 'common.dart';

/// iOS system colours used across the redesigned screens.
class IosColors {
  static const bg = Color(0xFFF2F2F7);
  static const separator = Color(0xFFC6C6C8);
  static const secondary = Color(0xFF8E8E93);
  static const tertiary = Color(0xFFC7C7CC);
  static const green = Color(0xFF34C759);
  static const red = Color(0xFFFF3B30);
  static const orange = Color(0xFFFF9500);
  static const blue = Color(0xFF1E3A8A);
  static const indigo = Color(0xFF5856D6);
  static const teal = Color(0xFF30B0C7);
  static const gray = Color(0xFF8E8E93);
}

/// iOS page: grouped background, optional "‹ Back" button, large title,
/// trailing action, then scrolling [children] (or a custom [body]).
class IosPage extends StatelessWidget {
  final String? title;
  final String? backLabel;
  final bool back;
  final Widget? action;
  final List<Widget>? children;
  final Widget? body;
  final Widget? header;
  final double bottomPadding;

  const IosPage({
    super.key,
    this.title,
    this.back = true,
    this.backLabel,
    this.action,
    this.children,
    this.body,
    this.header,
    this.bottomPadding = 32,
  });

  @override
  Widget build(BuildContext context) {
    final canPop = back && Navigator.of(context).canPop();
    return Scaffold(
      backgroundColor: IosColors.bg,
      body: SafeArea(
        bottom: false,
        child: Responsive(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (canPop || action != null)
                SizedBox(
                  height: 44,
                  child: Row(
                    children: [
                      if (canPop)
                        CupertinoButton(
                          padding: const EdgeInsets.only(left: 6, right: 12),
                          onPressed: () => Navigator.of(context).maybePop(),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(
                                CupertinoIcons.chevron_back,
                                color: AppColors.accent,
                                size: 26,
                              ),
                              Text(
                                backLabel ?? 'Back',
                                style: const TextStyle(
                                  fontSize: 17,
                                  color: AppColors.accent,
                                ),
                              ),
                            ],
                          ),
                        ),
                      const Spacer(),
                      if (action != null)
                        Padding(
                          padding: const EdgeInsets.only(right: 8),
                          child: action,
                        ),
                    ],
                  ),
                ),
              if (title != null)
                Padding(
                  padding: EdgeInsets.fromLTRB(
                    20,
                    canPop || action != null ? 0 : 12,
                    20,
                    10,
                  ),
                  child: Text(
                    title!,
                    style: const TextStyle(
                      fontSize: 34,
                      fontWeight: FontWeight.w700,
                      letterSpacing: -0.6,
                      color: Colors.black,
                    ),
                  ),
                ),
              ?header,
              Expanded(
                child:
                    body ??
                    ListView(
                      keyboardDismissBehavior:
                          ScrollViewKeyboardDismissBehavior.onDrag,
                      padding: EdgeInsets.fromLTRB(16, 4, 16, bottomPadding),
                      children: children ?? const [],
                    ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Inset-grouped section: optional header/footer and white rounded rows.
class IosSection extends StatelessWidget {
  final String? header, footer;
  final List<Widget> children;
  final double indent;
  const IosSection({
    super.key,
    this.header,
    this.footer,
    required this.children,
    this.indent = 58,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 26),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (header != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 7),
              child: Text(
                header!.toUpperCase(),
                style: const TextStyle(
                  fontSize: 13,
                  color: IosColors.secondary,
                  letterSpacing: .2,
                ),
              ),
            ),
          ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: ColoredBox(
              color: Colors.white,
              child: Column(
                children: [
                  for (var i = 0; i < children.length; i++) ...[
                    if (i > 0)
                      Padding(
                        padding: EdgeInsets.only(left: indent),
                        child: const Divider(
                          height: .5,
                          thickness: .5,
                          color: IosColors.separator,
                        ),
                      ),
                    children[i],
                  ],
                ],
              ),
            ),
          ),
          if (footer != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 7, 16, 0),
              child: Text(
                footer!,
                style: const TextStyle(
                  fontSize: 13,
                  color: IosColors.secondary,
                  height: 1.3,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// Rounded square with a white glyph, like iOS Settings icons.
class IosIcon extends StatelessWidget {
  final IconData icon;
  final Color color;
  final double size;
  const IosIcon(this.icon, this.color, {super.key, this.size = 30});
  @override
  Widget build(BuildContext context) => Container(
    width: size,
    height: size,
    decoration: BoxDecoration(
      color: color,
      borderRadius: BorderRadius.circular(size * .23),
    ),
    child: Icon(icon, color: Colors.white, size: size * .6),
  );
}

/// One row in an [IosSection]: leading, title/subtitle, value, trailing.
class IosRow extends StatefulWidget {
  final Widget? leading;
  final String title;
  final String? subtitle, value;
  final Widget? trailing;
  final bool chevron, destructive, centered;
  final Color? titleColor;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;

  const IosRow({
    super.key,
    required this.title,
    this.leading,
    this.subtitle,
    this.value,
    this.trailing,
    this.chevron = false,
    this.destructive = false,
    this.centered = false,
    this.titleColor,
    this.onTap,
    this.onLongPress,
  });

  @override
  State<IosRow> createState() => _IosRowState();
}

class _IosRowState extends State<IosRow> {
  bool _down = false;

  @override
  Widget build(BuildContext context) {
    final w = widget;
    final color = w.destructive
        ? IosColors.red
        : (w.titleColor ?? Colors.black);
    final title = Text(
      w.title,
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: TextStyle(fontSize: 17, color: color),
    );
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: w.onTap,
      onLongPress: w.onLongPress,
      onTapDown: w.onTap == null ? null : (_) => setState(() => _down = true),
      onTapUp: (_) => setState(() => _down = false),
      onTapCancel: () => setState(() => _down = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 120),
        color: _down ? const Color(0xFFE5E5EA) : Colors.white,
        constraints: const BoxConstraints(minHeight: 50),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 9),
        child: w.centered
            ? Center(child: title)
            : Row(
                children: [
                  if (w.leading != null) ...[
                    w.leading!,
                    const SizedBox(width: 14),
                  ],
                  Flexible(
                    // With a value the title keeps its size and the value
                    // takes the rest, right-aligned (iOS Settings style).
                    flex: w.value == null ? 1 : 0,
                    fit: w.value == null ? FlexFit.tight : FlexFit.loose,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        title,
                        if (w.subtitle != null) ...[
                          const SizedBox(height: 2),
                          Text(
                            w.subtitle!,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 14,
                              color: IosColors.secondary,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  if (w.value != null)
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.only(left: 12),
                        child: Text(
                          w.value!,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          textAlign: TextAlign.right,
                          style: const TextStyle(
                            fontSize: 17,
                            color: IosColors.secondary,
                          ),
                        ),
                      ),
                    ),
                  if (w.trailing != null) ...[
                    const SizedBox(width: 8),
                    w.trailing!,
                  ],
                  if (w.chevron)
                    const Padding(
                      padding: EdgeInsets.only(left: 6),
                      child: Icon(
                        CupertinoIcons.chevron_forward,
                        size: 18,
                        color: IosColors.tertiary,
                      ),
                    ),
                ],
              ),
      ),
    );
  }
}

/// iOS-style route (swipe back from the edge).
Route<T> iosRoute<T>(Widget page) =>
    CupertinoPageRoute<T>(builder: (_) => page);
