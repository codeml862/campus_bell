import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import '../../core/theme.dart';
import '../../models/models.dart';
import '../../services/services.dart';
import '../../widgets/cb.dart';
import '../../widgets/common.dart';
import '../../widgets/ios.dart';
import '../call/call_screen.dart';
import '../user_details/user_details_screen.dart';

/// All campus users: header, search, role filter, compact list.
/// [callMode]: tapping a person opens the Ring screen directly.
class DirectoryScreen extends StatefulWidget {
  final AppUser me;
  final bool callMode;
  final bool autofocus;
  final bool asTab;
  const DirectoryScreen({
    super.key,
    required this.me,
    this.callMode = false,
    this.autofocus = false,
    this.asTab = false,
  });
  @override
  State<DirectoryScreen> createState() => _DirectoryScreenState();
}

class _DirectoryScreenState extends State<DirectoryScreen> {
  String _q = '';
  int _filter = 0;
  static const _filters = ['All', 'HOD', 'Faculty', 'Lab staff', 'Student'];

  bool _match(AppUser u) {
    final roleOk = switch (_filter) {
      1 => u.role == Roles.hod,
      2 => Roles.faculty.contains(u.role),
      3 => Roles.normal(u.role) == Roles.labAssistant || u.role == Roles.admin,
      4 => u.role == Roles.student,
      _ => true,
    };
    if (!roleOk) return false;
    if (_q.isEmpty) return true;
    return u.name.toLowerCase().contains(_q) ||
        (u.username ?? '').contains(_q) ||
        (u.staffId ?? '').toLowerCase().contains(_q) ||
        u.department.toLowerCase().contains(_q) ||
        deptShort(u.department).toLowerCase().contains(_q);
  }

  void _open(AppUser u) {
    final me = widget.me;
    final page = widget.callMode && Roles.canCall(me.role, u.role)
        ? CallScreen(me: me, to: u)
        : UserDetailsScreen(me: me, user: u);
    Navigator.push(context, iosRoute(page));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Cb.page,
      body: SafeArea(
        bottom: false,
        child: Responsive(
          maxWidth: 560,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                child: CbHeader(
                  widget.callMode ? 'Ring someone' : 'Directory',
                  back: !widget.asTab,
                ),
              ),
              // Search pill.
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Container(
                  height: 46,
                  padding: const EdgeInsets.symmetric(horizontal: 14),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF4F6FA),
                    borderRadius: BorderRadius.circular(23),
                    border: Border.all(color: Cb.line),
                  ),
                  child: Row(
                    children: [
                      const Icon(
                        CupertinoIcons.search,
                        size: 19,
                        color: Cb.sub,
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: CupertinoTextField.borderless(
                          autofocus: widget.autofocus,
                          placeholder: 'Search name, ID or department',
                          placeholderStyle: const TextStyle(
                            fontSize: 15,
                            color: Color(0xFF9AA0AE),
                          ),
                          style: const TextStyle(fontSize: 15, color: Cb.ink),
                          padding: EdgeInsets.zero,
                          cursorColor: AppColors.accent,
                          clearButtonMode: OverlayVisibilityMode.editing,
                          onChanged: (v) =>
                              setState(() => _q = v.trim().toLowerCase()),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              // Role filter chips.
              SizedBox(
                height: 52,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
                  itemCount: _filters.length,
                  separatorBuilder: (_, _) => const SizedBox(width: 8),
                  itemBuilder: (_, i) {
                    final sel = i == _filter;
                    return GestureDetector(
                      onTap: () => setState(() => _filter = i),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 180),
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: sel ? AppColors.accent : Cb.tile,
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          _filters[i],
                          style: TextStyle(
                            fontSize: 13.5,
                            fontWeight: FontWeight.w600,
                            color: sel ? Colors.white : AppColors.accent,
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
              Expanded(child: _list()),
            ],
          ),
        ),
      ),
    );
  }

  Widget _list() => StreamBuilder<List<AppUser>>(
    stream: BellService.users(),
    builder: (_, snap) {
      if (snap.hasError) {
        return Center(child: Text('Could not load: ${snap.error}'));
      }
      if (!snap.hasData) {
        return const Center(child: CupertinoActivityIndicator());
      }
      final users = snap.data!
          .where((u) => u.uid != widget.me.uid && _match(u))
          .toList();
      if (users.isEmpty) {
        return const Center(
          child: Text(
            'No one found.',
            style: TextStyle(color: Cb.sub, fontSize: 15),
          ),
        );
      }
      final groups = <String, List<AppUser>>{};
      for (final u in users) {
        final l = u.name.isEmpty ? '#' : u.name[0].toUpperCase();
        groups
            .putIfAbsent(RegExp('[A-Z]').hasMatch(l) ? l : '#', () => [])
            .add(u);
      }
      return ListView(
        keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
        padding: EdgeInsets.fromLTRB(16, 4, 16, widget.asTab ? 120 : 28),
        children: [
          for (final e in groups.entries) ...[
            Padding(
              padding: const EdgeInsets.fromLTRB(6, 14, 6, 8),
              child: Text(
                e.key,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: AppColors.accent,
                ),
              ),
            ),
            CbCard(
              indent: 72,
              children: [
                for (final u in e.value)
                  CbItem(
                    leading: CbAvatar(u.name, uid: u.uid),
                    title: u.name,
                    subtitle: '${u.roleLabel} · ${deptShort(u.department)}',
                    trailing:
                        widget.callMode && Roles.canCall(widget.me.role, u.role)
                        ? Container(
                            width: 36,
                            height: 36,
                            decoration: const BoxDecoration(
                              color: AppColors.accent,
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(
                              CupertinoIcons.bell_fill,
                              color: Colors.white,
                              size: 17,
                            ),
                          )
                        : null,
                    onTap: () => _open(u),
                  ),
              ],
            ),
          ],
          Padding(
            padding: const EdgeInsets.only(top: 16),
            child: Center(
              child: Text(
                '${users.length} ${users.length == 1 ? 'person' : 'people'}',
                style: const TextStyle(fontSize: 13, color: Cb.sub),
              ),
            ),
          ),
        ],
      );
    },
  );
}
