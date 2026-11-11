import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import '../../core/theme.dart';
import '../../models/models.dart';
import '../../services/services.dart';
import '../../widgets/common.dart';
import 'profile_setup_screen.dart';

const _ink = Color(0xFF111114);
const _sub = Color(0xFF6B6B72);
const _line = Color(0xFFE3E3E8);
const _tile = Color(0xFFE3EBFC);

/// Step 1 after sign-up: pick a role (same white + blue style as login).
class RoleScreen extends StatefulWidget {
  const RoleScreen({super.key});
  @override
  State<RoleScreen> createState() => _RoleScreenState();
}

class _RoleScreenState extends State<RoleScreen> {
  String _role = Roles.hod;

  static const _info = {
    Roles.hod: (CupertinoIcons.building_2_fill, 'Head of department'),
    Roles.professor: (CupertinoIcons.book_fill, 'Senior teaching staff'),
    Roles.associateProfessor: (CupertinoIcons.book, 'Teaching staff'),
    Roles.assistantProfessor: (CupertinoIcons.pencil_outline, 'Teaching staff'),
    Roles.labAssistant: (CupertinoIcons.wrench_fill, 'Lab and office staff'),
    Roles.student: (CupertinoIcons.person_2_fill, 'Can request to meet staff'),
  };

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Responsive(
          maxWidth: 460,
          child: Column(
            children: [
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(22, 20, 22, 16),
                  children: [
                    Row(
                      children: [
                        const _Logo(),
                        const Spacer(),
                        CupertinoButton(
                          padding: EdgeInsets.zero,
                          minimumSize: Size.zero,
                          onPressed: AuthService.logout,
                          child: const Text(
                            'Sign out',
                            style: TextStyle(
                              fontSize: 15,
                              color: AppColors.accent,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),
                    const Text(
                      'Choose your role',
                      style: TextStyle(
                        fontSize: 27,
                        fontWeight: FontWeight.w700,
                        letterSpacing: -0.5,
                        color: _ink,
                      ),
                    ),
                    const SizedBox(height: 2),
                    const Text(
                      'Step 1 of 2 · Only an admin can change it later.',
                      style: TextStyle(fontSize: 15, color: _sub),
                    ),
                    const SizedBox(height: 20),
                    for (final r in Roles.selfSelectable) ...[
                      _RoleTile(
                        icon: _info[r]!.$1,
                        label: r,
                        hint: _info[r]!.$2,
                        selected: _role == r,
                        onTap: () => setState(() => _role = r),
                      ),
                      const SizedBox(height: 10),
                    ],
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(22, 4, 22, 16),
                child: _PillButton(
                  label: 'Continue',
                  onPressed: () => Navigator.push(
                    context,
                    CupertinoPageRoute(
                      builder: (_) => ProfileSetupScreen(role: _role),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _RoleTile extends StatelessWidget {
  final IconData icon;
  final String label, hint;
  final bool selected;
  final VoidCallback onTap;
  const _RoleTile({
    required this.icon,
    required this.label,
    required this.hint,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: selected ? const Color(0xFFF2F6FE) : Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: selected ? AppColors.accent : _line,
            width: selected ? 1.6 : 1,
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 46,
              height: 46,
              decoration: BoxDecoration(
                color: selected ? AppColors.accent : _tile,
                borderRadius: BorderRadius.circular(14),
              ),
              child: Icon(
                icon,
                size: 22,
                color: selected ? Colors.white : AppColors.accent,
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: const TextStyle(
                      fontSize: 16.5,
                      fontWeight: FontWeight.w600,
                      color: _ink,
                    ),
                  ),
                  Text(
                    hint,
                    style: const TextStyle(fontSize: 13.5, color: _sub),
                  ),
                ],
              ),
            ),
            AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              width: 24,
              height: 24,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: selected ? AppColors.accent : Colors.white,
                border: Border.all(
                  color: selected ? AppColors.accent : const Color(0xFFC9C9CF),
                  width: 1.5,
                ),
              ),
              child: selected
                  ? const Icon(
                      CupertinoIcons.checkmark_alt,
                      size: 16,
                      color: Colors.white,
                    )
                  : null,
            ),
            const SizedBox(width: 4),
          ],
        ),
      ),
    );
  }
}

class _Logo extends StatelessWidget {
  const _Logo();
  @override
  Widget build(BuildContext context) => Row(
    children: [
      Container(
        width: 30,
        height: 30,
        decoration: BoxDecoration(
          color: AppColors.accent,
          borderRadius: BorderRadius.circular(9),
        ),
        child: const Icon(
          CupertinoIcons.bell_fill,
          color: Colors.white,
          size: 17,
        ),
      ),
      const SizedBox(width: 8),
      const Text(
        'CampusBell',
        style: TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.w600,
          color: _ink,
        ),
      ),
    ],
  );
}

class _PillButton extends StatelessWidget {
  final String label;
  final VoidCallback onPressed;
  const _PillButton({required this.label, required this.onPressed});
  @override
  Widget build(BuildContext context) => SizedBox(
    width: double.infinity,
    height: 52,
    child: CupertinoButton(
      padding: EdgeInsets.zero,
      color: AppColors.accent,
      disabledColor: AppColors.accent.withValues(alpha: .6),
      borderRadius: BorderRadius.circular(26),
      onPressed: onPressed,
      child: Text(
        label,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 16,
          fontWeight: FontWeight.w600,
        ),
      ),
    ),
  );
}
