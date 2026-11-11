import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import '../core/theme.dart';
import '../models/models.dart';
import 'photo.dart';

/// Caps content width so screens look right on small phones, big phones
/// and tablets.
class Responsive extends StatelessWidget {
  final Widget child;
  final double maxWidth;
  final double? heightFactor;
  const Responsive({
    super.key,
    required this.child,
    this.maxWidth = 560,
    this.heightFactor,
  });
  @override
  Widget build(BuildContext context) => Align(
    alignment: Alignment.topCenter,
    heightFactor: heightFactor,
    child: ConstrainedBox(
      constraints: BoxConstraints(maxWidth: maxWidth),
      child: child,
    ),
  );
}

/// Flat #F5F5F5 page background.
class AppBackground extends StatelessWidget {
  final Widget child;
  const AppBackground({super.key, required this.child});
  @override
  Widget build(BuildContext context) =>
      ColoredBox(color: AppColors.bg, child: child);
}

/// Standard page: background + safe area + responsive width + optional header.
class AppPage extends StatelessWidget {
  final String? title;
  final bool back;
  final Widget child;
  final Widget? bottom;
  const AppPage({
    super.key,
    this.title,
    this.back = true,
    required this.child,
    this.bottom,
  });
  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: Colors.transparent,
    body: AppBackground(
      child: SafeArea(
        child: Responsive(
          child: Column(
            children: [
              if (title != null || back) ScreenHeader(title: title, back: back),
              Expanded(child: child),
              ?bottom,
            ],
          ),
        ),
      ),
    ),
  );
}

class ScreenHeader extends StatelessWidget {
  final String? title;
  final bool back;
  const ScreenHeader({super.key, this.title, this.back = true});
  @override
  Widget build(BuildContext context) => SizedBox(
    height: 56,
    child: Stack(
      alignment: Alignment.center,
      children: [
        if (back && Navigator.of(context).canPop())
          Align(
            alignment: Alignment.centerLeft,
            child: IconButton(
              icon: const Icon(CupertinoIcons.back, color: AppColors.text),
              onPressed: () => Navigator.of(context).maybePop(),
            ),
          ),
        if (title != null)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 56),
            child: Text(
              title!,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w800,
                letterSpacing: -0.3,
              ),
            ),
          ),
      ],
    ),
  );
}

/// White rounded card. Tappable cards shrink slightly while pressed
/// (animation instead of shadows).
class AppCard extends StatefulWidget {
  final Widget child;
  final EdgeInsets padding;
  final VoidCallback? onTap;
  final Color? color;
  final BorderRadius? radius;
  const AppCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(16),
    this.onTap,
    this.color,
    this.radius,
  });
  @override
  State<AppCard> createState() => _AppCardState();
}

class _AppCardState extends State<AppCard> {
  bool _down = false;

  void _set(bool v) {
    if (widget.onTap != null && _down != v) setState(() => _down = v);
  }

  @override
  Widget build(BuildContext context) {
    final r = widget.radius ?? BorderRadius.circular(18);
    return AnimatedScale(
      scale: _down ? 0.97 : 1,
      duration: const Duration(milliseconds: 140),
      curve: Curves.easeOut,
      child: Container(
        decoration: BoxDecoration(
          color: widget.color ?? AppColors.card,
          borderRadius: r,
        ),
        child: Material(
          color: Colors.transparent,
          borderRadius: r,
          child: InkWell(
            borderRadius: r,
            onTap: widget.onTap,
            onHighlightChanged: _set,
            splashColor: AppColors.accent.withValues(alpha: 0.06),
            highlightColor: AppColors.accent.withValues(alpha: 0.04),
            child: Padding(padding: widget.padding, child: widget.child),
          ),
        ),
      ),
    );
  }
}

class GradientButton extends StatelessWidget {
  final String label;
  final IconData? icon;
  final IconData? trailingIcon;
  final VoidCallback? onPressed;
  final bool loading;
  const GradientButton({
    super.key,
    required this.label,
    this.icon,
    this.trailingIcon,
    this.onPressed,
    this.loading = false,
  });
  @override
  Widget build(BuildContext context) {
    final enabled = onPressed != null && !loading;
    return Opacity(
      opacity: enabled ? 1 : 0.6,
      child: Container(
        height: 54,
        decoration: BoxDecoration(
          gradient: const LinearGradient(colors: AppColors.gradient),
          borderRadius: BorderRadius.circular(28),
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: BorderRadius.circular(28),
            onTap: enabled ? onPressed : null,
            child: Center(
              child: loading
                  ? const SizedBox(
                      height: 22,
                      width: 22,
                      child: CircularProgressIndicator(
                        strokeWidth: 2.5,
                        color: Colors.white,
                      ),
                    )
                  : Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (icon != null) ...[
                          Icon(icon, color: Colors.white, size: 20),
                          const SizedBox(width: 8),
                        ],
                        Text(
                          label,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        if (trailingIcon != null) ...[
                          const SizedBox(width: 10),
                          Icon(trailingIcon, color: Colors.white, size: 20),
                        ],
                      ],
                    ),
            ),
          ),
        ),
      ),
    );
  }
}

/// App logo: rounded deep-blue square with a bell.
class AppLogo extends StatelessWidget {
  final double size;
  final bool light;
  const AppLogo({super.key, this.size = 64, this.light = false});
  @override
  Widget build(BuildContext context) => Container(
    width: size,
    height: size,
    decoration: BoxDecoration(
      gradient: light
          ? null
          : const LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: AppColors.accentGradient,
            ),
      color: light ? Colors.white.withValues(alpha: 0.18) : null,
      borderRadius: BorderRadius.circular(size * 0.28),
    ),
    child: Icon(
      CupertinoIcons.bell_fill,
      color: Colors.white,
      size: size * 0.5,
    ),
  );
}

/// Initials avatar (photos need paid Storage, so initials keep it free).
class Avatar extends StatelessWidget {
  final String name;
  final double radius;
  final String? uid;
  const Avatar(this.name, {super.key, this.radius = 24, this.uid});
  @override
  Widget build(BuildContext context) {
    final parts = name.trim().split(RegExp(r'\s+')).where((p) => p.isNotEmpty);
    final initials = parts
        .where((p) => !p.endsWith('.'))
        .take(2)
        .map((p) => p[0].toUpperCase())
        .join();
    // Neutral, same for everyone (no random colours).
    final box = Container(
      width: radius * 2,
      height: radius * 2,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: const Color(0xFFE9E9EC),
        border: Border.all(color: Colors.white, width: radius > 30 ? 3 : 2),
      ),
      alignment: Alignment.center,
      child: Text(
        initials.isEmpty ? '?' : initials,
        style: TextStyle(
          color: const Color(0xFF55555C),
          fontWeight: FontWeight.w700,
          fontSize: radius * 0.7,
        ),
      ),
    );
    return uid == null
        ? box
        : UserPhoto(uid: uid!, size: radius * 2, fallback: box);
  }
}

String timeAgo(DateTime? t) {
  if (t == null) return 'just now';
  final d = DateTime.now().difference(t);
  if (d.inSeconds < 60) return 'just now';
  if (d.inMinutes < 60) return '${d.inMinutes} min ago';
  if (d.inHours < 24) return '${d.inHours} hr ago';
  if (d.inDays < 7) return '${d.inDays} d ago';
  return fmtDateTime(t);
}

String fmtDateTime(DateTime? t) {
  if (t == null) return '—';
  const m = [
    'Jan',
    'Feb',
    'Mar',
    'Apr',
    'May',
    'Jun',
    'Jul',
    'Aug',
    'Sep',
    'Oct',
    'Nov',
    'Dec',
  ];
  final h = t.hour % 12 == 0 ? 12 : t.hour % 12;
  final mm = t.minute.toString().padLeft(2, '0');
  return '${t.day} ${m[t.month - 1]} ${t.year}, ${h.toString().padLeft(2, '0')}:$mm ${t.hour < 12 ? 'AM' : 'PM'}';
}

(Color, IconData, String) statusStyle(String status) => switch (status) {
  BellStatus.delivered => (
    AppColors.success,
    CupertinoIcons.checkmark_alt,
    'Delivered',
  ),
  BellStatus.failed => (
    AppColors.danger,
    CupertinoIcons.exclamationmark_circle,
    'Not delivered',
  ),
  BellStatus.rejected => (AppColors.danger, CupertinoIcons.nosign, 'Rejected'),
  BellStatus.accepted => (
    AppColors.success,
    CupertinoIcons.checkmark_seal_fill,
    'Accepted',
  ),
  BellStatus.declined => (
    AppColors.danger,
    CupertinoIcons.xmark_circle,
    'Declined',
  ),
  _ => (AppColors.warning, CupertinoIcons.clock, 'Sending'),
};

/// "✓ Acknowledged • 5 min ago"
class StatusLine extends StatelessWidget {
  final String status;
  final DateTime? time;
  const StatusLine(this.status, {super.key, this.time});
  @override
  Widget build(BuildContext context) {
    final (color, icon, label) = statusStyle(status);
    return Row(
      children: [
        Icon(icon, size: 16, color: color),
        const SizedBox(width: 4),
        Flexible(
          child: Text(
            '$label • ${timeAgo(time)}',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(color: AppColors.muted, fontSize: 13),
          ),
        ),
      ],
    );
  }
}

/// List row: avatar, title, subtitle widget, chevron.
class PersonRow extends StatelessWidget {
  final String name;
  final Widget subtitle;
  final VoidCallback? onTap;
  final Widget? trailing;
  const PersonRow({
    super.key,
    required this.name,
    required this.subtitle,
    this.onTap,
    this.trailing,
  });
  @override
  Widget build(BuildContext context) => InkWell(
    onTap: onTap,
    borderRadius: BorderRadius.circular(16),
    child: Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      child: Row(
        children: [
          Avatar(name, radius: 24),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 3),
                subtitle,
              ],
            ),
          ),
          trailing ??
              const Icon(
                CupertinoIcons.chevron_right,
                size: 18,
                color: AppColors.muted,
              ),
        ],
      ),
    ),
  );
}

/// Icon + label + value row used on detail screens.
class InfoRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color? valueColor;
  const InfoRow({
    super.key,
    required this.icon,
    required this.label,
    required this.value,
    this.valueColor,
  });
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 10),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 22, color: AppColors.text),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: const TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: 14,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                value,
                style: TextStyle(
                  color: valueColor ?? AppColors.muted,
                  fontSize: 14,
                  fontWeight: valueColor != null
                      ? FontWeight.w600
                      : FontWeight.normal,
                ),
              ),
            ],
          ),
        ),
      ],
    ),
  );
}

/// Pill-style segmented control (Sign In / Sign Up, All / Sent / Received...).
class Segmented extends StatelessWidget {
  final List<String> items;
  final int index;
  final ValueChanged<int> onChanged;
  final List<Color?>? colors;
  const Segmented({
    super.key,
    required this.items,
    required this.index,
    required this.onChanged,
    this.colors,
  });
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(4),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(30),
    ),
    child: Row(
      children: [
        for (var i = 0; i < items.length; i++)
          Expanded(
            child: GestureDetector(
              onTap: () => onChanged(i),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                height: 40,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  gradient: i == index
                      ? LinearGradient(
                          colors: colors?[i] != null
                              ? [colors![i]!, colors![i]!]
                              : AppColors.gradient,
                        )
                      : null,
                  borderRadius: BorderRadius.circular(26),
                ),
                child: Text(
                  items[i],
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    color: i == index ? Colors.white : AppColors.text,
                  ),
                ),
              ),
            ),
          ),
      ],
    ),
  );
}

void showSnack(BuildContext context, String text) =>
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
