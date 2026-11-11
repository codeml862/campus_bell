import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import '../../core/theme.dart';
import '../../models/models.dart';
import '../../services/services.dart';
import '../../widgets/cb.dart';
import '../../widgets/common.dart';
import '../../widgets/department_picker.dart';

const _red = Color(0xFFE5484D);
const _redBg = Color(0xFFFDEBEC);
const _green = Color(0xFF1E8E3E);
const _greenBg = Color(0xFFE3F4E8);

enum _Filter { all, staff, students, disabled }

/// Administrators: search people, change roles, disable / enable accounts.
class AdminScreen extends StatefulWidget {
  const AdminScreen({super.key});
  @override
  State<AdminScreen> createState() => _AdminScreenState();
}

class _AdminScreenState extends State<AdminScreen> {
  final _search = TextEditingController();
  final _stream = usersCol.snapshots().map(
    (s) => s.docs.map(AppUser.fromDoc).toList()
      ..sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase())),
  );
  _Filter _filter = _Filter.all;
  String _dept = '';

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  bool _match(AppUser u) {
    final q = _search.text.trim().toLowerCase();
    if (q.isNotEmpty &&
        !u.name.toLowerCase().contains(q) &&
        !u.email.toLowerCase().contains(q) &&
        !(u.username ?? '').contains(q) &&
        !(u.staffId ?? '').toLowerCase().contains(q)) {
      return false;
    }
    if (_dept.isNotEmpty && u.department != _dept) return false;
    return switch (_filter) {
      _Filter.all => true,
      _Filter.staff => u.isActive && u.role != Roles.student,
      _Filter.students => u.isActive && u.role == Roles.student,
      _Filter.disabled => !u.isActive,
    };
  }

  Future<void> _pickDept() async {
    final v = await pickDepartment(
      context,
      current: _dept,
      allowAll: true,
      title: 'Filter by department',
    );
    if (v != null) setState(() => _dept = v);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Cb.page,
      body: SafeArea(
        child: Responsive(
          maxWidth: 560,
          child: StreamBuilder<List<AppUser>>(
            stream: _stream,
            builder: (_, snap) {
              final all = snap.data ?? const <AppUser>[];
              final shown = all.where(_match).toList();
              final active = all.where((u) => u.isActive).length;
              return CustomScrollView(
                keyboardDismissBehavior:
                    ScrollViewKeyboardDismissBehavior.onDrag,
                slivers: [
                  SliverPadding(
                    padding: const EdgeInsets.fromLTRB(16, 4, 16, 0),
                    sliver: SliverList.list(
                      children: [
                        const CbHeader('Manage users'),
                        Row(
                          children: [
                            _StatBox('${all.length}', 'Total', Cb.ink),
                            const SizedBox(width: 8),
                            _StatBox('$active', 'Active', _green),
                            const SizedBox(width: 8),
                            _StatBox(
                              '${all.length - active}',
                              'Disabled',
                              _red,
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        _SearchBox(
                          controller: _search,
                          onChanged: () => setState(() {}),
                        ),
                        const SizedBox(height: 10),
                        SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          child: Row(
                            children: [
                              for (final f in _Filter.values)
                                _Chip(
                                  switch (f) {
                                    _Filter.all => 'All',
                                    _Filter.staff => 'Staff',
                                    _Filter.students => 'Students',
                                    _Filter.disabled => 'Disabled',
                                  },
                                  selected: _filter == f,
                                  onTap: () => setState(() => _filter = f),
                                ),
                              _Chip(
                                _dept.isEmpty ? 'Department' : deptShort(_dept),
                                selected: _dept.isNotEmpty,
                                icon: CupertinoIcons.chevron_down,
                                onTap: _pickDept,
                              ),
                            ],
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.fromLTRB(6, 16, 6, 6),
                          child: Text(
                            snap.hasData
                                ? '${shown.length} ${shown.length == 1 ? 'person' : 'people'}'
                                : 'Loading…',
                            style: const TextStyle(color: Cb.sub, fontSize: 13),
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (snap.hasError)
                    SliverFillRemaining(
                      hasScrollBody: false,
                      child: Center(
                        child: Text(
                          'Could not load users: ${snap.error}',
                          style: const TextStyle(color: Cb.sub),
                        ),
                      ),
                    )
                  else if (!snap.hasData)
                    const SliverFillRemaining(
                      hasScrollBody: false,
                      child: Center(child: CupertinoActivityIndicator()),
                    )
                  else if (shown.isEmpty)
                    const SliverFillRemaining(
                      hasScrollBody: false,
                      child: Center(
                        child: Text(
                          'No one matches.',
                          style: TextStyle(color: Cb.sub, fontSize: 15),
                        ),
                      ),
                    )
                  else
                    SliverPadding(
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                      sliver: SliverToBoxAdapter(
                        child: CbCard(
                          indent: 64,
                          children: [
                            for (final u in shown)
                              _UserRow(
                                u: u,
                                onTap: () => showCupertinoModalPopup(
                                  context: context,
                                  builder: (_) => _ManageSheet(user: u),
                                ),
                              ),
                          ],
                        ),
                      ),
                    ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}

class _StatBox extends StatelessWidget {
  final String value, label;
  final Color color;
  const _StatBox(this.value, this.label, this.color);
  @override
  Widget build(BuildContext context) => Expanded(
    child: Container(
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Cb.line),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            value,
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w700,
              color: color,
            ),
          ),
          Text(label, style: const TextStyle(fontSize: 12.5, color: Cb.sub)),
        ],
      ),
    ),
  );
}

class _SearchBox extends StatelessWidget {
  final TextEditingController controller;
  final VoidCallback onChanged;
  const _SearchBox({required this.controller, required this.onChanged});
  @override
  Widget build(BuildContext context) => Container(
    height: 44,
    padding: const EdgeInsets.symmetric(horizontal: 12),
    decoration: BoxDecoration(
      color: const Color(0xFFF4F5F8),
      borderRadius: BorderRadius.circular(14),
    ),
    child: Row(
      children: [
        const Icon(CupertinoIcons.search, size: 18, color: Cb.sub),
        const SizedBox(width: 8),
        Expanded(
          child: CupertinoTextField.borderless(
            controller: controller,
            placeholder: 'Name, email, username or ID',
            padding: EdgeInsets.zero,
            style: const TextStyle(fontSize: 15.5),
            cursorColor: AppColors.accent,
            clearButtonMode: OverlayVisibilityMode.editing,
            onChanged: (_) => onChanged(),
          ),
        ),
      ],
    ),
  );
}

class _Chip extends StatelessWidget {
  final String label;
  final bool selected;
  final IconData? icon;
  final VoidCallback onTap;
  const _Chip(
    this.label, {
    required this.selected,
    required this.onTap,
    this.icon,
  });
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(right: 8),
    child: GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
        decoration: BoxDecoration(
          color: selected ? AppColors.accent : Colors.white,
          borderRadius: BorderRadius.circular(99),
          border: Border.all(color: selected ? AppColors.accent : Cb.line),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              label,
              style: TextStyle(
                fontSize: 13.5,
                fontWeight: FontWeight.w600,
                color: selected ? Colors.white : Cb.ink,
              ),
            ),
            if (icon != null) ...[
              const SizedBox(width: 4),
              Icon(icon, size: 13, color: selected ? Colors.white : Cb.sub),
            ],
          ],
        ),
      ),
    ),
  );
}

class _StatusPill extends StatelessWidget {
  final bool active;
  const _StatusPill(this.active);
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
    decoration: BoxDecoration(
      color: active ? _greenBg : _redBg,
      borderRadius: BorderRadius.circular(99),
    ),
    child: Text(
      active ? 'Active' : 'Disabled',
      style: TextStyle(
        fontSize: 11.5,
        fontWeight: FontWeight.w600,
        color: active ? _green : _red,
      ),
    ),
  );
}

class _UserRow extends StatelessWidget {
  final AppUser u;
  final VoidCallback onTap;
  const _UserRow({required this.u, required this.onTap});
  @override
  Widget build(BuildContext context) => CbItem(
    leading: Opacity(
      opacity: u.isActive ? 1 : .45,
      child: CbAvatar(u.name, size: 40, uid: u.uid),
    ),
    title: u.name.isEmpty ? u.email : u.name,
    subtitle: '${u.roleLabel} · ${deptShort(u.department)}',
    trailing: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (!u.isActive) const _StatusPill(false),
        const SizedBox(width: 4),
        const Icon(CupertinoIcons.chevron_forward, size: 16, color: Cb.sub),
      ],
    ),
    onTap: onTap,
  );
}

/// Bottom sheet: role and access for one person.
class _ManageSheet extends StatefulWidget {
  final AppUser user;
  const _ManageSheet({required this.user});
  @override
  State<_ManageSheet> createState() => _ManageSheetState();
}

class _ManageSheetState extends State<_ManageSheet> {
  late String _role = widget.user.role;
  late String _dept = widget.user.department;
  late bool _active = widget.user.isActive;
  bool _busy = false;

  bool get _isMe => widget.user.uid == auth.currentUser?.uid;

  Future<void> _update(Map<String, dynamic> data, String done) async {
    setState(() => _busy = true);
    try {
      await usersCol.doc(widget.user.uid).update(data);
      if (mounted) showSnack(context, done);
    } catch (e) {
      if (mounted) showSnack(context, 'Could not save: $e');
      rethrow;
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _pickRole() async {
    final r = await showCupertinoModalPopup<String>(
      context: context,
      builder: (c) => CupertinoActionSheet(
        title: const Text('Role'),
        actions: [
          for (final r in Roles.all)
            CupertinoActionSheetAction(
              onPressed: () => Navigator.pop(c, r),
              child: Text(
                r,
                style: TextStyle(
                  fontWeight: r == _role ? FontWeight.w700 : null,
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
    if (r == null || r == _role) return;
    if (r == Roles.hod) {
      try {
        await HodService.ensureFree(_dept, exceptUid: widget.user.uid);
      } catch (e) {
        if (mounted) showSnack(context, '$e');
        return;
      }
    }
    try {
      await _update({'role': r}, 'Role changed to $r.');
      if (mounted) setState(() => _role = r);
    } catch (_) {}
  }

  Future<void> _changeDept() async {
    final d = await pickDepartment(context, current: _dept);
    if (d == null || d.isEmpty || d == _dept) return;
    if (_role == Roles.hod) {
      try {
        await HodService.ensureFree(d, exceptUid: widget.user.uid);
      } catch (e) {
        if (mounted) showSnack(context, '$e');
        return;
      }
    }
    try {
      await _update({'department': d}, 'Moved to ${deptShort(d)}.');
      if (mounted) setState(() => _dept = d);
    } catch (_) {}
  }

  Future<void> _toggleActive() async {
    if (_active) {
      final ok = await showCupertinoDialog<bool>(
        context: context,
        builder: (c) => CupertinoAlertDialog(
          title: Text('Disable ${widget.user.name}?'),
          content: const Text(
            'They will not be able to send or receive bells until enabled again.',
          ),
          actions: [
            CupertinoDialogAction(
              onPressed: () => Navigator.pop(c, false),
              child: const Text('Cancel'),
            ),
            CupertinoDialogAction(
              isDestructiveAction: true,
              onPressed: () => Navigator.pop(c, true),
              child: const Text('Disable'),
            ),
          ],
        ),
      );
      if (ok != true) return;
    }
    final next = !_active;
    try {
      await _update({
        'status': next ? 'active' : 'disabled',
      }, next ? 'Account enabled.' : 'Account disabled.');
      if (mounted) setState(() => _active = next);
    } catch (_) {}
  }

  Widget _info(String label, String value) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 6),
    child: Row(
      children: [
        SizedBox(
          width: 96,
          child: Text(
            label,
            style: const TextStyle(color: Cb.sub, fontSize: 14),
          ),
        ),
        Expanded(
          child: Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(color: Cb.ink, fontSize: 14.5),
          ),
        ),
      ],
    ),
  );

  @override
  Widget build(BuildContext context) {
    final u = widget.user;
    return Material(
      color: Colors.white,
      borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      clipBehavior: Clip.antiAlias,
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 10, 20, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(
                child: Container(
                  width: 38,
                  height: 5,
                  decoration: BoxDecoration(
                    color: Cb.line,
                    borderRadius: BorderRadius.circular(3),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  CbAvatar(u.name, size: 52, uid: u.uid),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          u.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 19,
                            fontWeight: FontWeight.w700,
                            color: Cb.navy,
                          ),
                        ),
                        const SizedBox(height: 3),
                        _StatusPill(_active),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              const Divider(height: 1, color: Cb.line),
              const SizedBox(height: 8),
              _info('Email', u.email),
              if (u.username != null) _info('Username', '@${u.username}'),
              _info('ID', u.staffId ?? 'Not added'),
              const SizedBox(height: 12),
              CbCard(
                indent: 60,
                children: [
                  CbItem(
                    icon: CupertinoIcons.building_2_fill,
                    title: 'Department',
                    subtitle: _dept,
                    onTap: _busy || _isMe ? null : _changeDept,
                  ),
                  CbItem(
                    icon: CupertinoIcons.briefcase,
                    title: 'Role',
                    subtitle: _role,
                    onTap: _busy || _isMe ? null : _pickRole,
                  ),
                  CbItem(
                    icon: _active
                        ? CupertinoIcons.nosign
                        : CupertinoIcons.checkmark_shield,
                    title: _active ? 'Disable account' : 'Enable account',
                    subtitle: _active
                        ? 'Stops sending and receiving bells'
                        : 'Let them use CampusBell again',
                    danger: _active,
                    chevron: false,
                    onTap: _busy || _isMe ? null : _toggleActive,
                  ),
                ],
              ),
              if (_isMe)
                const Padding(
                  padding: EdgeInsets.fromLTRB(6, 8, 6, 0),
                  child: Text(
                    "You can't change your own role or access.",
                    style: TextStyle(color: Cb.sub, fontSize: 12.5),
                  ),
                ),
              const SizedBox(height: 14),
              SizedBox(
                height: 50,
                child: CupertinoButton(
                  padding: EdgeInsets.zero,
                  color: const Color(0xFFF4F5F8),
                  borderRadius: BorderRadius.circular(14),
                  onPressed: () => Navigator.pop(context),
                  child: _busy
                      ? const CupertinoActivityIndicator()
                      : const Text(
                          'Done',
                          style: TextStyle(
                            color: Cb.ink,
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
    );
  }
}
