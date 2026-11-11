import 'dart:ui';

import 'package:flutter/material.dart';

import '../../core/theme.dart';
import '../../models/models.dart';
import '../../widgets/common.dart';
import '../directory/directory_screen.dart';
import '../hierarchy/hierarchy_screen.dart';
import '../profile/profile_screen.dart';
import 'home_screen.dart';

/// Logged-in shell: Home, Directory, Call (bell), Hierarchy.
/// History opens from Home.
/// Profile opens from the avatar on Home.
class MainShell extends StatefulWidget {
  final AppUser me;
  const MainShell({super.key, required this.me});
  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> {
  // Tab indexes: 0 Home, 1 Directory, 3 Hierarchy. 2 = bell, 4 = profile (pushed).
  int _tab = 0;

  void _go(int i) {
    final me = widget.me;
    if (i == 2) {
      if (!Roles.canCallAnyone(me.role)) {
        showSnack(context, 'Your role can receive bells but cannot send them.');
        return;
      }
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => DirectoryScreen(me: me, callMode: true),
        ),
      );
      return;
    }
    if (i == 4) {
      Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => ProfileScreen(me: me)),
      );
      return;
    }
    setState(() => _tab = i);
  }

  @override
  Widget build(BuildContext context) {
    final me = widget.me;
    return Scaffold(
      extendBody: true,
      backgroundColor: AppColors.bg,
      body: IndexedStack(
        index: _tab == 3 ? 2 : _tab,
        children: [
          HomeScreen(me: me, goToTab: _go),
          DirectoryScreen(me: me, asTab: true),
          HierarchyScreen(me: me),
        ],
      ),
      bottomNavigationBar: _GlassBar(index: _tab, onTap: _go),
    );
  }
}

/// Frosted, semi-transparent bar with an animated pill behind the active tab.
class _GlassBar extends StatelessWidget {
  final int index;
  final ValueChanged<int> onTap;
  const _GlassBar({required this.index, required this.onTap});

  @override
  Widget build(BuildContext context) {
    const items = [
      (0, Icons.home_outlined, Icons.home_rounded, 'Home'),
      (1, Icons.people_outline_rounded, Icons.people_rounded, 'Directory'),
      (
        2,
        Icons.notifications_none_rounded,
        Icons.notifications_rounded,
        'Call',
      ),
      (3, Icons.account_tree_outlined, Icons.account_tree_rounded, 'Hierarchy'),
    ];
    return SafeArea(
      top: false,
      child: Responsive(
        heightFactor: 1,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(32),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 24, sigmaY: 24),
              child: Container(
                height: 68,
                padding: const EdgeInsets.symmetric(horizontal: 8),
                // iOS 26 "Liquid Glass" capsule: very translucent white,
                // hairline grey edge.
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.6),
                  borderRadius: BorderRadius.circular(34),
                  border: Border.all(
                    color: Colors.black.withValues(alpha: 0.08),
                    width: 0.6,
                  ),
                ),
                child: Row(
                  children: [
                    for (final (i, icon, activeIcon, label) in items)
                      Expanded(
                        child: i == 2
                            ? _BellButton(onTap: () => onTap(2))
                            : _NavItem(
                                icon: icon,
                                activeIcon: activeIcon,
                                label: label,
                                selected: index == i,
                                onTap: () => onTap(i),
                              ),
                      ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _NavItem extends StatelessWidget {
  final IconData icon, activeIcon;
  final String label;
  final bool selected;
  final VoidCallback onTap;
  const _NavItem({
    required this.icon,
    required this.activeIcon,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    // iOS: selected = accent, others = near-black.
    final color = selected ? AppColors.accent : const Color(0xFF1C1C1E);
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Center(
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 280),
          curve: Curves.easeOutCubic,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
          // Grey glass pill behind the selected tab (like iOS 26).
          decoration: BoxDecoration(
            color: selected
                ? Colors.black.withValues(alpha: 0.07)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(26),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              AnimatedScale(
                scale: selected ? 1.12 : 1,
                duration: const Duration(milliseconds: 280),
                curve: Curves.easeOutBack,
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 200),
                  child: Icon(
                    selected ? activeIcon : icon,
                    key: ValueKey(selected),
                    color: color,
                    size: 24,
                  ),
                ),
              ),
              const SizedBox(height: 2),
              AnimatedDefaultTextStyle(
                duration: const Duration(milliseconds: 200),
                style: TextStyle(
                  fontSize: 11,
                  color: color,
                  fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                ),
                child: Text(label, maxLines: 1),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _BellButton extends StatefulWidget {
  final VoidCallback onTap;
  const _BellButton({required this.onTap});
  @override
  State<_BellButton> createState() => _BellButtonState();
}

class _BellButtonState extends State<_BellButton> {
  bool _down = false;
  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => setState(() => _down = true),
      onTapCancel: () => setState(() => _down = false),
      onTapUp: (_) {
        setState(() => _down = false);
        widget.onTap();
      },
      child: Center(
        child: AnimatedScale(
          scale: _down ? 0.88 : 1,
          duration: const Duration(milliseconds: 120),
          child: Container(
            width: 52,
            height: 52,
            decoration: const BoxDecoration(
              shape: BoxShape.circle,
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: AppColors.accentGradient,
              ),
            ),
            child: const Icon(
              Icons.notifications_active_rounded,
              color: Colors.white,
              size: 26,
            ),
          ),
        ),
      ),
    );
  }
}
