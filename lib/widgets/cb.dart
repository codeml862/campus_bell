import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import '../core/theme.dart';
import '../models/models.dart';
import 'photo.dart';

/// Compact, clean building blocks shared by Profile, the other-user
/// profile and Directory, so they all look the same. Deep blue only.
class Cb {
  static const navy = Color(0xFF0F1B45);
  static const ink = Color(0xFF15171C);
  static const sub = Color(0xFF5F6472);
  static const line = Color(0xFFE9EBF1);
  static const tile = Color(0xFFE7EEFB);
  static const page = Colors.white;
}

String initials(String name) => name
    .trim()
    .split(RegExp(r'\s+'))
    .take(2)
    .map((p) => p.isEmpty ? '' : p[0].toUpperCase())
    .join();

/// Back arrow + page title (and optional trailing widget).
class CbHeader extends StatelessWidget {
  final String title;
  final bool back;
  final Widget? trailing;
  const CbHeader(this.title, {super.key, this.back = true, this.trailing});
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(4, 2, 4, 8),
    child: Row(
      children: [
        if (back && Navigator.of(context).canPop()) ...[
          GestureDetector(
            onTap: () => Navigator.of(context).maybePop(),
            child: const Padding(
              padding: EdgeInsets.all(6),
              child: Icon(CupertinoIcons.arrow_left, color: Cb.ink, size: 24),
            ),
          ),
          const SizedBox(width: 8),
        ],
        Expanded(
          child: Text(
            title,
            style: const TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.w800,
              letterSpacing: -0.4,
              color: Cb.navy,
            ),
          ),
        ),
        ?trailing,
      ],
    ),
  );
}

/// Deep-blue identity card: avatar, name, line 2, role pill, then an
/// optional bottom area (stats / buttons) inside a translucent box.
class CbBlueCard extends StatelessWidget {
  final String name, line2;
  final String? pill;
  final Widget? bottom;
  final VoidCallback? onTap;

  /// Replaces the initials circle (e.g. an editable photo).
  final Widget? avatar;
  const CbBlueCard({
    super.key,
    required this.name,
    required this.line2,
    this.pill,
    this.bottom,
    this.onTap,
    this.avatar,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(22),
        gradient: const LinearGradient(
          colors: [Color(0xFF1E3A8A), Color(0xFF172E6E)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Column(
        children: [
          GestureDetector(
            onTap: onTap,
            behavior: HitTestBehavior.opaque,
            child: Row(
              children: [
                avatar ??
                    Container(
                      width: 50,
                      height: 50,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: Colors.white,
                        border: Border.all(
                          color: Colors.white.withValues(alpha: .35),
                          width: 3,
                          strokeAlign: BorderSide.strokeAlignOutside,
                        ),
                      ),
                      child: Text(
                        initials(name),
                        style: const TextStyle(
                          color: AppColors.accent,
                          fontSize: 20,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      Text(
                        line2,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Color(0xFFD0DAF4),
                          fontSize: 13.5,
                        ),
                      ),
                      if (pill != null) ...[
                        const SizedBox(height: 5),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: .18),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(
                            pill!,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                if (onTap != null)
                  const Icon(
                    CupertinoIcons.chevron_forward,
                    color: Colors.white,
                    size: 18,
                  ),
              ],
            ),
          ),
          if (bottom != null) ...[
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.fromLTRB(12, 8, 8, 8),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: .12),
                borderRadius: BorderRadius.circular(18),
              ),
              child: bottom,
            ),
          ],
        ],
      ),
    );
  }
}

/// Small white pill button used inside the blue card.
class CbWhitePill extends StatelessWidget {
  final String label;
  final IconData? icon;
  final VoidCallback? onTap;
  const CbWhitePill(this.label, {super.key, this.icon, this.onTap});
  @override
  Widget build(BuildContext context) => CupertinoButton(
    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
    minimumSize: Size.zero,
    color: Colors.white,
    disabledColor: Colors.white.withValues(alpha: .5),
    borderRadius: BorderRadius.circular(22),
    onPressed: onTap,
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (icon != null) ...[
          Icon(icon, color: AppColors.accent, size: 16),
          const SizedBox(width: 6),
        ],
        Text(
          label,
          style: const TextStyle(
            color: AppColors.accent,
            fontSize: 14,
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    ),
  );
}

/// Blue section title ("Account").
class CbSection extends StatelessWidget {
  final String text;
  const CbSection(this.text, {super.key});
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(6, 14, 6, 6),
    child: Text(
      text,
      style: const TextStyle(
        color: AppColors.accent,
        fontSize: 16,
        fontWeight: FontWeight.w700,
      ),
    ),
  );
}

/// White rounded card with thin dividers between rows.
class CbCard extends StatelessWidget {
  final List<Widget> children;
  final double indent;
  const CbCard({super.key, required this.children, this.indent = 60});
  @override
  Widget build(BuildContext context) => Container(
    // Border drawn on top (foreground) so row backgrounds can't hide it.
    foregroundDecoration: BoxDecoration(
      borderRadius: BorderRadius.circular(20),
      border: Border.all(color: Cb.line),
    ),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(20),
    ),
    clipBehavior: Clip.antiAlias,
    child: Column(
      children: [
        for (var i = 0; i < children.length; i++) ...[
          if (i > 0)
            Padding(
              padding: EdgeInsets.only(left: indent),
              child: const Divider(height: 1, thickness: 1, color: Cb.line),
            ),
          children[i],
        ],
      ],
    ),
  );
}

/// Row: light-blue icon tile (or any leading), title, subtitle, chevron.
class CbItem extends StatelessWidget {
  final IconData? icon;
  final Widget? leading;
  final String title;
  final String? subtitle;
  final Widget? trailing;
  final bool chevron, danger;
  final VoidCallback? onTap, onLongPress;
  const CbItem({
    super.key,
    this.icon,
    this.leading,
    required this.title,
    this.subtitle,
    this.trailing,
    this.chevron = true,
    this.danger = false,
    this.onTap,
    this.onLongPress,
  });

  @override
  Widget build(BuildContext context) {
    final c = danger ? const Color(0xFFE5484D) : AppColors.accent;
    return Material(
      color: Colors.white,
      child: InkWell(
        onTap: onTap,
        onLongPress: onLongPress,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          child: Row(
            children: [
              leading ??
                  Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: danger ? const Color(0xFFFDEBEC) : Cb.tile,
                      borderRadius: BorderRadius.circular(11),
                    ),
                    child: Icon(icon, color: c, size: 19),
                  ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 15.5,
                        fontWeight: FontWeight.w600,
                        color: danger ? c : Cb.ink,
                      ),
                    ),
                    if (subtitle != null) ...[
                      const SizedBox(height: 1),
                      Text(
                        subtitle!,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 13.5,
                          height: 1.3,
                          color: Cb.sub,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              if (trailing != null) ...[const SizedBox(width: 8), trailing!],
              if (chevron && trailing == null && onTap != null)
                const Padding(
                  padding: EdgeInsets.only(left: 6),
                  child: Icon(
                    CupertinoIcons.chevron_forward,
                    size: 18,
                    color: AppColors.accent,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Round light-blue avatar with initials (lists).
class CbAvatar extends StatelessWidget {
  final String name;
  final double size;
  final String? uid;
  const CbAvatar(this.name, {super.key, this.size = 44, this.uid});
  @override
  Widget build(BuildContext context) {
    final box = Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: const BoxDecoration(color: Cb.tile, shape: BoxShape.circle),
      child: Text(
        initials(name),
        style: TextStyle(
          color: AppColors.accent,
          fontSize: size * .36,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
    return uid == null ? box : UserPhoto(uid: uid!, size: size, fallback: box);
  }
}

/// Account rows (email, username, ID, department, role) used by both
/// profile pages.
List<Widget> cbAccountRows(
  AppUser u, {
  VoidCallback? onEmail,
  VoidCallback? onEdit,
  VoidCallback? onRole,
  VoidCallback? onDepartment,
}) => [
  CbItem(
    icon: CupertinoIcons.mail,
    title: 'Email',
    subtitle: u.email,
    onTap: onEmail,
  ),
  if (u.username != null)
    CbItem(
      icon: CupertinoIcons.at,
      title: 'Username',
      subtitle: '@${u.username}',
    ),
  CbItem(
    icon: CupertinoIcons.number,
    title: 'Employee / Student ID',
    subtitle: u.staffId ?? 'Not added',
    onTap: onEdit,
  ),
  CbItem(
    icon: CupertinoIcons.building_2_fill,
    title: 'Department',
    subtitle: u.department,
    onTap: onDepartment,
  ),
  CbItem(
    icon: CupertinoIcons.briefcase,
    title: 'Role',
    subtitle: u.roleLabel,
    onTap: onRole,
  ),
];
