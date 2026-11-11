import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import '../../core/theme.dart';
import '../../models/models.dart';
import '../../services/services.dart';
import '../../widgets/common.dart';
import '../../widgets/department_picker.dart';

const _ink = Color(0xFF111114);
const _sub = Color(0xFF6B6B72);
const _hint = Color(0xFFA0A0A8);
const _fieldBg = Color(0xFFF7F7F9);
const _line = Color(0xFFE3E3E8);
const _red = Color(0xFFE5484D);

/// Step 2 after sign-up: name, department, designation, ID.
/// Same white + blue, pill-field style as the login screens.
class ProfileSetupScreen extends StatefulWidget {
  final String role;
  const ProfileSetupScreen({super.key, required this.role});
  @override
  State<ProfileSetupScreen> createState() => _ProfileSetupScreenState();
}

class _ProfileSetupScreenState extends State<ProfileSetupScreen> {
  final _name = TextEditingController(text: AuthService.pendingName ?? '');
  final _id = TextEditingController();
  String _dept = departments.first;
  late String _role = widget.role;
  String _hodAs = Roles.professor;
  bool _busy = false;
  String? _error;

  Future<void> _save() async {
    FocusScope.of(context).unfocus();
    if (_name.text.trim().length < 2) {
      setState(() => _error = 'Enter your full name.');
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      if (_role == Roles.hod) await HodService.ensureFree(_dept);
      await AuthService.createProfile(
        name: _name.text.trim(),
        department: _dept,
        role: _role,
        designation: _role == Roles.hod ? _hodAs : null,
        staffId: _id.text.trim().isEmpty ? null : _id.text.trim(),
      );
      // The app switches to Home automatically; close the onboarding pages.
      if (mounted) Navigator.of(context).popUntil((r) => r.isFirst);
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _pick(
    String title,
    List<String> items,
    String current,
    ValueChanged<String> onPick,
  ) => showCupertinoModalPopup(
    context: context,
    builder: (c) => CupertinoActionSheet(
      title: Text(title),
      actions: [
        for (final i in items)
          CupertinoActionSheetAction(
            onPressed: () {
              onPick(i);
              Navigator.pop(c);
            },
            child: Text(
              i,
              style: TextStyle(
                fontWeight: i == current ? FontWeight.w700 : FontWeight.w400,
                color: AppColors.accent,
              ),
            ),
          ),
      ],
      cancelButton: CupertinoActionSheetAction(
        onPressed: () => Navigator.pop(c),
        child: const Text('Cancel'),
      ),
    ),
  );

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
                  keyboardDismissBehavior:
                      ScrollViewKeyboardDismissBehavior.onDrag,
                  padding: const EdgeInsets.fromLTRB(22, 8, 22, 16),
                  children: [
                    Align(
                      alignment: Alignment.centerLeft,
                      child: CupertinoButton(
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        minimumSize: Size.zero,
                        onPressed: () => Navigator.of(context).maybePop(),
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              CupertinoIcons.chevron_back,
                              color: AppColors.accent,
                              size: 24,
                            ),
                            Text(
                              'Role',
                              style: TextStyle(
                                fontSize: 16,
                                color: AppColors.accent,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        ValueListenableBuilder(
                          valueListenable: _name,
                          builder: (_, v, _) => Avatar(
                            v.text.trim().isEmpty ? '?' : v.text,
                            radius: 28,
                          ),
                        ),
                        const SizedBox(width: 14),
                        const Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Your profile',
                                style: TextStyle(
                                  fontSize: 27,
                                  fontWeight: FontWeight.w700,
                                  letterSpacing: -0.5,
                                  color: _ink,
                                ),
                              ),
                              Text(
                                'Step 2 of 2 · How others will find you',
                                style: TextStyle(fontSize: 15, color: _sub),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 22),
                    const _Label('Full name'),
                    _PillField(
                      controller: _name,
                      hint: 'Your full name',
                      icon: CupertinoIcons.person,
                      caps: TextCapitalization.words,
                    ),
                    const SizedBox(height: 12),
                    const _Label('Department'),
                    _PillSelect(
                      icon: CupertinoIcons.building_2_fill,
                      value: _dept,
                      onTap: () async {
                        final d = await pickDepartment(
                          context,
                          current: _dept,
                          title: 'Your department',
                        );
                        if (d != null && d.isNotEmpty) {
                          setState(() => _dept = d);
                        }
                      },
                    ),
                    const SizedBox(height: 12),
                    const _Label('Designation'),
                    _PillSelect(
                      icon: CupertinoIcons.briefcase,
                      value: _role,
                      onTap: () => _pick(
                        'Designation',
                        Roles.selfSelectable,
                        _role,
                        (v) => setState(() => _role = v),
                      ),
                    ),
                    if (_role == Roles.hod) ...[
                      const SizedBox(height: 12),
                      const _Label('HOD designation'),
                      _PillSelect(
                        icon: CupertinoIcons.rosette,
                        value: _hodAs,
                        onTap: () => _pick(
                          'You are HOD as',
                          Roles.hodDesignations,
                          _hodAs,
                          (v) => setState(() => _hodAs = v),
                        ),
                      ),
                    ],
                    const SizedBox(height: 12),
                    const _Label('Employee / Student ID (optional)'),
                    _PillField(
                      controller: _id,
                      hint: 'CUH-1234',
                      icon: CupertinoIcons.number,
                      caps: TextCapitalization.characters,
                    ),
                    if (_error != null)
                      Padding(
                        padding: const EdgeInsets.only(top: 10, left: 4),
                        child: Row(
                          children: [
                            const Icon(
                              CupertinoIcons.exclamationmark_circle,
                              size: 15,
                              color: _red,
                            ),
                            const SizedBox(width: 6),
                            Expanded(
                              child: Text(
                                _error!,
                                style: const TextStyle(
                                  color: _red,
                                  fontSize: 13,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(22, 4, 22, 16),
                child: SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: CupertinoButton(
                    padding: EdgeInsets.zero,
                    color: AppColors.accent,
                    disabledColor: AppColors.accent.withValues(alpha: .6),
                    borderRadius: BorderRadius.circular(26),
                    onPressed: _busy ? null : _save,
                    child: _busy
                        ? const CupertinoActivityIndicator(color: Colors.white)
                        : const Text(
                            'Save and continue',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                            ),
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

class _Label extends StatelessWidget {
  final String text;
  const _Label(this.text);
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(left: 4, bottom: 6),
    child: Text(
      text,
      style: const TextStyle(
        fontSize: 13,
        fontWeight: FontWeight.w600,
        color: _ink,
      ),
    ),
  );
}

/// Pill text field (blue border while typing), same as the login screen.
class _PillField extends StatefulWidget {
  final TextEditingController controller;
  final String hint;
  final IconData icon;
  final TextCapitalization caps;
  const _PillField({
    required this.controller,
    required this.hint,
    required this.icon,
    this.caps = TextCapitalization.none,
  });
  @override
  State<_PillField> createState() => _PillFieldState();
}

class _PillFieldState extends State<_PillField> {
  final _focus = FocusNode();
  @override
  void initState() {
    super.initState();
    _focus.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _focus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final on = _focus.hasFocus;
    return AnimatedContainer(
      duration: const Duration(milliseconds: 150),
      height: 48,
      padding: const EdgeInsets.symmetric(horizontal: 14),
      decoration: BoxDecoration(
        color: on ? Colors.white : _fieldBg,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: on ? AppColors.accent : _line,
          width: on ? 1.5 : 1,
        ),
      ),
      child: Row(
        children: [
          Icon(widget.icon, size: 19, color: on ? AppColors.accent : _hint),
          const SizedBox(width: 10),
          Expanded(
            child: CupertinoTextField.borderless(
              controller: widget.controller,
              focusNode: _focus,
              placeholder: widget.hint,
              placeholderStyle: const TextStyle(fontSize: 15.5, color: _hint),
              style: const TextStyle(fontSize: 15.5, color: _ink),
              textCapitalization: widget.caps,
              cursorColor: AppColors.accent,
              padding: EdgeInsets.zero,
              clearButtonMode: OverlayVisibilityMode.editing,
            ),
          ),
        ],
      ),
    );
  }
}

/// Pill "select" field that opens an iOS action sheet.
class _PillSelect extends StatelessWidget {
  final IconData icon;
  final String value;
  final VoidCallback onTap;
  const _PillSelect({
    required this.icon,
    required this.value,
    required this.onTap,
  });
  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: onTap,
    child: Container(
      height: 48,
      padding: const EdgeInsets.symmetric(horizontal: 14),
      decoration: BoxDecoration(
        color: _fieldBg,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: _line),
      ),
      child: Row(
        children: [
          Icon(icon, size: 19, color: _hint),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              value,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 15.5, color: _ink),
            ),
          ),
          const Icon(CupertinoIcons.chevron_down, size: 16, color: _hint),
        ],
      ),
    ),
  );
}
