import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/theme.dart';
import '../../models/models.dart';
import '../../services/services.dart';
import '../../widgets/cb.dart';
import '../../widgets/common.dart';
import '../../widgets/ios.dart';
import '../admin/admin_screen.dart';
import '../../widgets/photo.dart';
import '../../services/share_app.dart';

const _navy = Cb.navy;
const _line = Cb.line;
const _red = Color(0xFFE5484D);

/// Your own profile (same layout as another user's profile).
class ProfileScreen extends StatelessWidget {
  final AppUser me;
  const ProfileScreen({super.key, required this.me});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder(
      stream: usersCol.doc(me.uid).snapshots(),
      builder: (_, snap) {
        final u = snap.hasData && snap.data!.exists
            ? AppUser.fromDoc(snap.data!)
            : me;
        void edit() => _edit(context, u);

        return Scaffold(
          backgroundColor: Cb.page,
          body: SafeArea(
            child: Responsive(
              maxWidth: 520,
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 4, 16, 20),
                children: [
                  const CbHeader('Profile'),
                  CbBlueCard(
                    avatar: EditablePhoto(
                      uid: u.uid,
                      size: 52,
                      fallback: Container(
                        width: 52,
                        height: 52,
                        alignment: Alignment.center,
                        decoration: const BoxDecoration(
                          color: Colors.white,
                          shape: BoxShape.circle,
                        ),
                        child: Text(
                          initials(u.name),
                          style: const TextStyle(
                            color: AppColors.accent,
                            fontSize: 19,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                    ),
                    name: u.name,
                    line2: u.email,
                    pill: '${u.roleLabel} · ${deptShort(u.department)}',
                    onTap: edit,
                    bottom: Row(
                      children: [
                        Expanded(child: _Stats(uid: u.uid)),
                        CbWhitePill(
                          'Edit',
                          icon: CupertinoIcons.pencil,
                          onTap: edit,
                        ),
                      ],
                    ),
                  ),
                  const CbSection('Account'),
                  CbCard(
                    children: cbAccountRows(
                      u,
                      onEmail: () {
                        Clipboard.setData(ClipboardData(text: u.email));
                        showSnack(context, 'Email copied');
                      },
                      onEdit: edit,
                      onDepartment: () => showSnack(
                        context,
                        'Your department was set when you signed up. Ask your admin to change it.',
                      ),
                      onRole: () => showSnack(
                        context,
                        'Only an admin can change your role.',
                      ),
                    ),
                  ),
                  const CbSection('Notifications'),
                  CbCard(
                    children: [
                      CbItem(
                        icon: u.soundOn
                            ? CupertinoIcons.bell
                            : CupertinoIcons.bell_slash,
                        title: 'Ring for incoming bells',
                        subtitle: u.soundOn
                            ? 'Rings with your ringtone'
                            : 'Silent – bells will not ring',
                        trailing: CupertinoSwitch(
                          value: u.soundOn,
                          activeTrackColor: AppColors.accent,
                          onChanged: (v) =>
                              usersCol.doc(u.uid).update({'prefs.sound': v}),
                        ),
                      ),
                    ],
                  ),
                  const CbSection('Security'),
                  CbCard(
                    children: [
                      CbItem(
                        icon: CupertinoIcons.lock,
                        title: 'Change password',
                        subtitle: AuthService.hasPassword
                            ? 'Change it right here'
                            : 'You sign in with Google',
                        onTap: () => AuthService.hasPassword
                            ? showCupertinoModalPopup(
                                context: context,
                                builder: (_) => const _PasswordSheet(),
                              )
                            : showSnack(
                                context,
                                'You sign in with Google, so there is no CampusBell password to change.',
                              ),
                      ),
                      if (u.isAdmin)
                        CbItem(
                          icon: CupertinoIcons.person_2,
                          title: 'Manage users',
                          subtitle: 'Roles and access',
                          onTap: () => Navigator.push(
                            context,
                            iosRoute(const AdminScreen()),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  CbCard(
                    children: [
                      CbItem(
                        icon: CupertinoIcons.share,
                        title: 'Share CampusBell',
                        subtitle:
                            'Send the app on WhatsApp, Bluetooth and more',
                        onTap: () async {
                          try {
                            await ShareApp.share();
                          } catch (e) {
                            if (context.mounted) {
                              showSnack(context, 'Could not share: $e');
                            }
                          }
                        },
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  CbCard(
                    children: [
                      CbItem(
                        icon: CupertinoIcons.square_arrow_right,
                        title: 'Sign out',
                        danger: true,
                        chevron: false,
                        onTap: () => _signOut(context),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  const Center(
                    child: Text(
                      'CampusBell 1.0.0',
                      style: TextStyle(color: Cb.sub, fontSize: 12.5),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  void _edit(BuildContext context, AppUser u) => showCupertinoModalPopup(
    context: context,
    builder: (_) => _EditSheet(u: u),
  );

  Future<void> _signOut(BuildContext context) async {
    final ok = await showCupertinoModalPopup<bool>(
      context: context,
      builder: (c) => CupertinoActionSheet(
        message: const Text('You will stop receiving bells on this phone.'),
        actions: [
          CupertinoActionSheetAction(
            isDestructiveAction: true,
            onPressed: () => Navigator.pop(c, true),
            child: const Text('Sign Out'),
          ),
        ],
        cancelButton: CupertinoActionSheetAction(
          onPressed: () => Navigator.pop(c, false),
          child: const Text('Cancel'),
        ),
      ),
    );
    if (ok == true) {
      await AuthService.logout();
      if (context.mounted) Navigator.of(context).popUntil((r) => r.isFirst);
    }
  }
}

/// Sent | Received | Today (white, inside the blue card).
class _Stats extends StatelessWidget {
  final String uid;
  const _Stats({required this.uid});
  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<BellRequest>>(
      stream: BellService.sent(uid),
      builder: (_, s) => StreamBuilder<List<BellRequest>>(
        stream: BellService.received(uid),
        builder: (_, r) {
          final sent = s.data ?? const <BellRequest>[];
          final rec = r.data ?? const <BellRequest>[];
          final now = DateTime.now();
          final today = [...sent, ...rec].where((x) {
            final t = x.createdAt;
            return t != null &&
                t.year == now.year &&
                t.month == now.month &&
                t.day == now.day;
          }).length;
          final ready = s.hasData && r.hasData;
          String v(int n) => ready ? '$n' : '–';
          return Row(
            children: [
              _Stat(v(sent.length), 'Sent'),
              _Stat(v(rec.length), 'Received'),
              _Stat(v(today), 'Today'),
            ],
          );
        },
      ),
    );
  }
}

class _Stat extends StatelessWidget {
  final String value, label;
  const _Stat(this.value, this.label);
  @override
  Widget build(BuildContext context) => Expanded(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          value,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 17,
            fontWeight: FontWeight.w700,
          ),
        ),
        Text(
          label,
          maxLines: 1,
          style: const TextStyle(color: Color(0xFFD0DAF4), fontSize: 12),
        ),
      ],
    ),
  );
}

/// iOS sheet to edit name, department and ID (role is admin-only).
class _EditSheet extends StatefulWidget {
  final AppUser u;
  const _EditSheet({required this.u});
  @override
  State<_EditSheet> createState() => _EditSheetState();
}

class _EditSheetState extends State<_EditSheet> {
  late final _name = TextEditingController(text: widget.u.name);
  late final _id = TextEditingController(text: widget.u.staffId ?? '');
  bool _busy = false;
  String? _error;

  Future<void> _save() async {
    if (_name.text.trim().length < 2) {
      setState(() => _error = 'Enter your name.');
      return;
    }
    setState(() => _busy = true);
    try {
      await usersCol.doc(widget.u.uid).update({
        'name': _name.text.trim(),
        'staffId': _id.text.trim().isEmpty ? null : _id.text.trim(),
      });
      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Widget _field(
    String label,
    TextEditingController c, {
    TextCapitalization caps = TextCapitalization.none,
  }) => SizedBox(
    height: 50,
    child: Row(
      children: [
        const SizedBox(width: 16),
        SizedBox(
          width: 100,
          child: Text(label, style: const TextStyle(fontSize: 17)),
        ),
        Expanded(
          child: CupertinoTextField.borderless(
            controller: c,
            textCapitalization: caps,
            padding: EdgeInsets.zero,
            style: const TextStyle(fontSize: 17, color: Colors.black),
            cursorColor: AppColors.accent,
            clearButtonMode: OverlayVisibilityMode.editing,
          ),
        ),
        const SizedBox(width: 8),
      ],
    ),
  );

  @override
  Widget build(BuildContext context) {
    return Material(
      color: IosColors.bg,
      borderRadius: const BorderRadius.vertical(top: Radius.circular(14)),
      clipBehavior: Clip.antiAlias,
      child: Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom,
        ),
        child: SafeArea(
          top: false,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              SizedBox(
                height: 54,
                child: Row(
                  children: [
                    CupertinoButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text(
                        'Cancel',
                        style: TextStyle(color: AppColors.accent),
                      ),
                    ),
                    const Expanded(
                      child: Text(
                        'Edit Profile',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    CupertinoButton(
                      onPressed: _busy ? null : _save,
                      child: _busy
                          ? const CupertinoActivityIndicator()
                          : const Text(
                              'Done',
                              style: TextStyle(
                                color: AppColors.accent,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
                child: IosSection(
                  indent: 16,
                  footer: _error,
                  children: [
                    _field('Name', _name, caps: TextCapitalization.words),
                    _field('ID', _id, caps: TextCapitalization.characters),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Change password inside the app: current, new, confirm.
class _PasswordSheet extends StatefulWidget {
  const _PasswordSheet();
  @override
  State<_PasswordSheet> createState() => _PasswordSheetState();
}

class _PasswordSheetState extends State<_PasswordSheet> {
  final _current = TextEditingController();
  final _next = TextEditingController();
  final _confirm = TextEditingController();
  bool _hide = true, _busy = false;
  String? _error;

  bool get _strong =>
      _next.text.length >= 8 &&
      _next.text.contains(RegExp(r'\d')) &&
      _next.text.contains(RegExp(r'[A-Za-z]'));

  Future<void> _save() async {
    FocusScope.of(context).unfocus();
    String? err;
    if (_current.text.isEmpty) {
      err = 'Enter your current password.';
    } else if (!_strong) {
      err = 'New password needs 8+ characters with a letter and a number.';
    } else if (_next.text != _confirm.text) {
      err = 'New passwords don\'t match.';
    } else if (_next.text == _current.text) {
      err = 'New password must be different.';
    }
    if (err != null) {
      setState(() => _error = err);
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await AuthService.changePassword(_current.text, _next.text);
      if (!mounted) return;
      Navigator.pop(context);
      showSnack(context, 'Password changed');
    } on FirebaseAuthException catch (e) {
      setState(
        () => _error = switch (e.code) {
          'wrong-password' ||
          'invalid-credential' => 'Current password is wrong.',
          'too-many-requests' => 'Too many attempts. Try again later.',
          'network-request-failed' => 'No internet connection.',
          _ => e.message ?? e.code,
        },
      );
    } catch (e) {
      setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Widget _field(String label, TextEditingController c, String hint) => Padding(
    padding: const EdgeInsets.only(bottom: 12),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 4, bottom: 6),
          child: Text(
            label,
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: _navy,
            ),
          ),
        ),
        Container(
          height: 48,
          padding: const EdgeInsets.only(left: 16, right: 4),
          decoration: BoxDecoration(
            color: const Color(0xFFF7F7F9),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: _line),
          ),
          child: Row(
            children: [
              Expanded(
                child: CupertinoTextField.borderless(
                  controller: c,
                  obscureText: _hide,
                  placeholder: hint,
                  padding: EdgeInsets.zero,
                  onChanged: (_) => setState(() {}),
                  style: const TextStyle(fontSize: 15.5),
                  cursorColor: AppColors.accent,
                ),
              ),
              CupertinoButton(
                padding: const EdgeInsets.symmetric(horizontal: 10),
                minimumSize: Size.zero,
                onPressed: () => setState(() => _hide = !_hide),
                child: Icon(
                  _hide ? CupertinoIcons.eye : CupertinoIcons.eye_slash,
                  size: 19,
                  color: const Color(0xFFA0A0A8),
                ),
              ),
            ],
          ),
        ),
      ],
    ),
  );

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      clipBehavior: Clip.antiAlias,
      child: Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom,
        ),
        child: SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 18, 20, 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    const Expanded(
                      child: Text(
                        'Change password',
                        style: TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.w800,
                          color: _navy,
                        ),
                      ),
                    ),
                    CupertinoButton(
                      padding: EdgeInsets.zero,
                      minimumSize: Size.zero,
                      onPressed: () => Navigator.pop(context),
                      child: const Icon(
                        CupertinoIcons.xmark_circle_fill,
                        color: Color(0xFFC9CCD6),
                        size: 28,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 18),
                _field('Current password', _current, 'Your current password'),
                _field('New password', _next, '8+ characters, letter + number'),
                _field('Confirm new password', _confirm, 'Type it again'),
                if (_error != null)
                  Padding(
                    padding: const EdgeInsets.only(left: 4, bottom: 10),
                    child: Text(
                      _error!,
                      style: const TextStyle(color: _red, fontSize: 13),
                    ),
                  ),
                const SizedBox(height: 6),
                SizedBox(
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
                            'Update password',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
