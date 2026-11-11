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

/// Hierarchy tab: the department as a tree
/// (HOD → Professors → Associate → Assistant → Lab staff → Students), with search, counts and
/// who is in class right now. Groups have their own page. Ring goes top → bottom;
/// people above you get a quiet "request to meet" instead.
class HierarchyScreen extends StatefulWidget {
  final AppUser me;
  const HierarchyScreen({super.key, required this.me});
  @override
  State<HierarchyScreen> createState() => _HierarchyScreenState();
}

class _HierarchyScreenState extends State<HierarchyScreen> {
  late String _dept = widget.me.department;
  String _q = '';

  @override
  Widget build(BuildContext context) {
    final me = widget.me;
    return Scaffold(
      backgroundColor: Cb.page,
      body: SafeArea(
        bottom: false,
        child: Responsive(
          maxWidth: 560,
          child: StreamBuilder<List<AppUser>>(
            stream: BellService.users(),
            builder: (_, snap) {
              // The main administrator stays out of the hierarchy.
              final users = (snap.data ?? const <AppUser>[])
                  .where((u) => !u.isAdmin)
                  .toList();
              final depts = {
                me.department,
                ...users.map((u) => u.department),
              }.where((d) => d.isNotEmpty).toList()..sort();
              final inDept = users.where((u) => u.department == _dept).toList();
              final q = _q.toLowerCase();
              final shown = q.isEmpty
                  ? inDept
                  : inDept
                        .where(
                          (u) =>
                              u.name.toLowerCase().contains(q) ||
                              (u.staffId ?? '').toLowerCase().contains(q) ||
                              u.roleLabel.toLowerCase().contains(q),
                        )
                        .toList();
              final inClass = inDept
                  .where((u) => u.currentClass != null)
                  .length;
              return ListView(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 120),
                children: [
                  const CbHeader('Hierarchy', back: false),
                  CupertinoSearchTextField(
                    placeholder: 'Search name, ID or role',
                    backgroundColor: const Color(0xFFF4F5F8),
                    borderRadius: BorderRadius.circular(14),
                    onChanged: (v) => setState(() => _q = v.trim()),
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      const Expanded(child: CbSection('Department')),
                      if (me.isAdmin && depts.length > 1)
                        Padding(
                          padding: const EdgeInsets.only(top: 12),
                          child: _DeptPicker(
                            value: _dept,
                            items: depts,
                            onChanged: (d) => setState(() => _dept = d),
                          ),
                        ),
                    ],
                  ),
                  if (!snap.hasData)
                    const Padding(
                      padding: EdgeInsets.all(32),
                      child: Center(child: CupertinoActivityIndicator()),
                    )
                  else ...[
                    _Summary(people: inDept, inClass: inClass),
                    const SizedBox(height: 10),
                    _Tree(
                      me: me,
                      dept: _dept,
                      people: shown,
                      searching: q.isNotEmpty,
                    ),
                    const SizedBox(height: 10),
                    const _Legend(),
                  ],
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}

// ------------------------------------------------------------ tree

class _Tree extends StatelessWidget {
  final AppUser me;
  final String dept;
  final List<AppUser> people;
  final bool searching;
  const _Tree({
    required this.me,
    required this.dept,
    required this.people,
    this.searching = false,
  });

  // The main administrator is not part of any department's hierarchy.
  static const _levels = [
    (Roles.hod, 'Head of department', CupertinoIcons.building_2_fill),
    (Roles.professor, 'Professors', CupertinoIcons.book_fill),
    (Roles.associateProfessor, 'Associate Professors', CupertinoIcons.book),
    (
      Roles.assistantProfessor,
      'Assistant Professors',
      CupertinoIcons.pencil_outline,
    ),
    (Roles.labAssistant, 'Lab Assistants', CupertinoIcons.wrench_fill),
    (Roles.student, 'Students', CupertinoIcons.person_2_fill),
  ];

  @override
  Widget build(BuildContext context) {
    final levels = [
      for (final (role, label, icon) in _levels)
        (
          role,
          label,
          icon,
          people.where((u) => Roles.normal(u.role) == role).toList(),
        ),
    ];

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Cb.line),
      ),
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: AppColors.accent,
                  borderRadius: BorderRadius.circular(11),
                ),
                child: const Icon(
                  CupertinoIcons.building_2_fill,
                  color: Colors.white,
                  size: 18,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  dept,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: Cb.navy,
                  ),
                ),
              ),
              Text(
                '${people.length}',
                style: const TextStyle(color: Cb.sub, fontSize: 13),
              ),
            ],
          ),
          const SizedBox(height: 6),
          for (var i = 0; i < levels.length; i++)
            _Level(
              key: ValueKey('${levels[i].$1}-$searching'),
              me: me,
              label: levels[i].$2,
              icon: levels[i].$3,
              people: levels[i].$4,
              last: i == levels.length - 1,
              initiallyOpen:
                  searching ||
                  Roles.rank(levels[i].$1) <= Roles.rank(me.role) + 1,
            ),
        ],
      ),
    );
  }
}

/// One level of the tree with a connector line on the left.
class _Level extends StatefulWidget {
  final AppUser me;
  final String label;
  final IconData icon;
  final List<AppUser> people;
  final bool last, initiallyOpen;
  const _Level({
    super.key,
    required this.me,
    required this.label,
    required this.icon,
    required this.people,
    required this.last,
    required this.initiallyOpen,
  });
  @override
  State<_Level> createState() => _LevelState();
}

class _LevelState extends State<_Level> {
  late bool _open = widget.initiallyOpen;

  @override
  Widget build(BuildContext context) {
    final w = widget;
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // tree connector
          SizedBox(
            width: 18,
            child: Column(
              children: [
                Container(width: 2, height: 20, color: Cb.line),
                Container(
                  width: 8,
                  height: 2,
                  color: Cb.line,
                  margin: const EdgeInsets.only(left: 8),
                ),
                if (!w.last)
                  Expanded(child: Container(width: 2, color: Cb.line)),
              ],
            ),
          ),
          const SizedBox(width: 4),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: () => setState(() => _open = !_open),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    child: Row(
                      children: [
                        Icon(w.icon, size: 17, color: AppColors.accent),
                        const SizedBox(width: 8),
                        Text(
                          w.label,
                          style: const TextStyle(
                            fontSize: 14.5,
                            fontWeight: FontWeight.w700,
                            color: Cb.ink,
                          ),
                        ),
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 7,
                            vertical: 1,
                          ),
                          decoration: BoxDecoration(
                            color: Cb.tile,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Text(
                            '${w.people.length}',
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: AppColors.accent,
                            ),
                          ),
                        ),
                        const Spacer(),
                        Icon(
                          _open
                              ? CupertinoIcons.chevron_up
                              : CupertinoIcons.chevron_down,
                          size: 15,
                          color: Cb.sub,
                        ),
                      ],
                    ),
                  ),
                ),
                if (_open)
                  if (w.people.isEmpty)
                    const Padding(
                      padding: EdgeInsets.only(left: 25, bottom: 8),
                      child: Text(
                        'No one yet',
                        style: TextStyle(fontSize: 13, color: Cb.sub),
                      ),
                    )
                  else
                    for (final u in w.people) _PersonRow(me: w.me, user: u),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _PersonRow extends StatelessWidget {
  final AppUser me, user;
  const _PersonRow({required this.me, required this.user});

  @override
  Widget build(BuildContext context) {
    final self = me.uid == user.uid;
    final ring = !self && Roles.canCall(me.role, user.role);
    final request = !self && Roles.canRequest(me.role, user.role);
    final now = user.currentClass;
    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: self
          ? null
          : () => Navigator.push(
              context,
              iosRoute(UserDetailsScreen(me: me, user: user)),
            ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(4, 6, 0, 6),
        child: Row(
          children: [
            Stack(
              clipBehavior: Clip.none,
              children: [
                CbAvatar(user.name, size: 38, uid: user.uid),
                Positioned(
                  right: -1,
                  bottom: -1,
                  child: Container(
                    width: 12,
                    height: 12,
                    decoration: BoxDecoration(
                      color: !user.isActive
                          ? Cb.sub
                          : now != null
                          ? _busy
                          : _free,
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white, width: 2),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    self ? '${user.name} (you)' : user.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 14.5,
                      fontWeight: FontWeight.w600,
                      color: Cb.ink,
                    ),
                  ),
                  Text(
                    !user.isActive
                        ? 'Disabled'
                        : now != null
                        ? 'In class till ${now.end}${now.place.isEmpty ? '' : ' · ${now.place}'}'
                        : (user.staffId ?? 'Available'),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 12.5,
                      color: now != null ? _busyText : Cb.sub,
                    ),
                  ),
                ],
              ),
            ),
            if (ring)
              _RingPill(
                onTap: () => Navigator.push(
                  context,
                  iosRoute(CallScreen(me: me, to: user)),
                ),
              )
            else if (request)
              _RequestPill(
                onTap: () => Navigator.push(
                  context,
                  iosRoute(CallScreen(me: me, to: user, request: true)),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _RingPill extends StatelessWidget {
  final VoidCallback onTap;
  const _RingPill({required this.onTap});
  @override
  Widget build(BuildContext context) => CupertinoButton(
    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
    minimumSize: Size.zero,
    color: AppColors.accent,
    borderRadius: BorderRadius.circular(16),
    onPressed: onTap,
    child: const Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(CupertinoIcons.bell_fill, size: 14, color: Colors.white),
        SizedBox(width: 4),
        Text(
          'Ring',
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: Colors.white,
          ),
        ),
      ],
    ),
  );
}

class _RequestPill extends StatelessWidget {
  final VoidCallback onTap;
  const _RequestPill({required this.onTap});
  @override
  Widget build(BuildContext context) => CupertinoButton(
    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
    minimumSize: Size.zero,
    color: Cb.tile,
    borderRadius: BorderRadius.circular(16),
    onPressed: onTap,
    child: const Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(
          CupertinoIcons.hand_raised_fill,
          size: 14,
          color: AppColors.accent,
        ),
        SizedBox(width: 4),
        Text(
          'Request',
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: AppColors.accent,
          ),
        ),
      ],
    ),
  );
}

class _DeptPicker extends StatelessWidget {
  final String value;
  final List<String> items;
  final ValueChanged<String> onChanged;
  const _DeptPicker({
    required this.value,
    required this.items,
    required this.onChanged,
  });
  @override
  Widget build(BuildContext context) => CupertinoButton(
    padding: const EdgeInsets.symmetric(horizontal: 6),
    minimumSize: Size.zero,
    onPressed: () => showCupertinoModalPopup(
      context: context,
      builder: (c) => CupertinoActionSheet(
        title: const Text('Department'),
        actions: [
          for (final d in items)
            CupertinoActionSheetAction(
              onPressed: () {
                onChanged(d);
                Navigator.pop(c);
              },
              child: Text(d),
            ),
        ],
        cancelButton: CupertinoActionSheetAction(
          onPressed: () => Navigator.pop(c),
          child: const Text('Cancel'),
        ),
      ),
    ),
    child: const Row(
      children: [
        Text(
          'Change',
          style: TextStyle(
            fontSize: 14.5,
            fontWeight: FontWeight.w600,
            color: AppColors.accent,
          ),
        ),
        Icon(CupertinoIcons.chevron_down, size: 14, color: AppColors.accent),
      ],
    ),
  );
}

const _free = Color(0xFF22A35A);
const _busy = Color(0xFFF2B02E);
const _busyText = Color(0xFF9A6200);

/// Counts per role and how many are in class right now.
class _Summary extends StatelessWidget {
  final List<AppUser> people;
  final int inClass;
  const _Summary({required this.people, required this.inClass});
  @override
  Widget build(BuildContext context) {
    int n(String r) => people.where((u) => Roles.normal(u.role) == r).length;
    final items = [
      ('HOD', n(Roles.hod)),
      ('Faculty', people.where((u) => Roles.faculty.contains(u.role)).length),
      ('Lab staff', n(Roles.labAssistant)),
      ('Students', n(Roles.student)),
    ];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            for (var i = 0; i < items.length; i++) ...[
              if (i > 0) const SizedBox(width: 8),
              Expanded(
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 9),
                  decoration: BoxDecoration(
                    color: Cb.tile,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Column(
                    children: [
                      Text(
                        '${items[i].$2}',
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                          color: AppColors.accent,
                        ),
                      ),
                      Text(
                        items[i].$1,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontSize: 11.5, color: Cb.sub),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ],
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            const Icon(CupertinoIcons.clock, size: 14, color: _busyText),
            const SizedBox(width: 6),
            Text(
              inClass == 0
                  ? 'No one is in class right now'
                  : '$inClass in class right now',
              style: const TextStyle(fontSize: 12.5, color: _busyText),
            ),
          ],
        ),
      ],
    );
  }
}

/// What the dots mean.
class _Legend extends StatelessWidget {
  const _Legend();
  @override
  Widget build(BuildContext context) {
    Widget dot(Color c, String t) => Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 9,
          height: 9,
          decoration: BoxDecoration(color: c, shape: BoxShape.circle),
        ),
        const SizedBox(width: 5),
        Text(t, style: const TextStyle(fontSize: 12, color: Cb.sub)),
      ],
    );
    return Wrap(
      alignment: WrapAlignment.center,
      spacing: 14,
      children: [
        dot(_free, 'Available'),
        dot(_busy, 'In class'),
        dot(Cb.sub, 'Disabled'),
      ],
    );
  }
}
