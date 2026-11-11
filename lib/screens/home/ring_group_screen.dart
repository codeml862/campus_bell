import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import '../../core/theme.dart';
import '../../models/models.dart';
import '../../services/services.dart';
import '../../widgets/ios.dart';
import '../call/call_screen.dart';
import '../hierarchy/group_screen.dart';
import 'home_screen.dart';

/// Groups page: every group you own or belong to. Ring a group (everyone
/// rings, the first to accept goes), open it to see members, or make one.
class RingGroupScreen extends StatelessWidget {
  final AppUser me;
  const RingGroupScreen({super.key, required this.me});

  @override
  Widget build(BuildContext context) {
    final canCreate = GroupService.canManage(me, null);
    final top = MediaQuery.paddingOf(context).top;
    return Scaffold(
      backgroundColor: HomeColors.bg,
      body: StreamBuilder<List<AppUser>>(
        stream: BellService.users(),
        builder: (_, usersSnap) => StreamBuilder<List<Group>>(
          stream: GroupService.mine(me),
          builder: (_, snap) {
            final users = usersSnap.data ?? const <AppUser>[];
            final groups = snap.data ?? const <Group>[];
            final ringable = ringableGroups(me, groups).toSet();
            return ListView(
              padding: EdgeInsets.fromLTRB(16, top + 8, 16, 32),
              children: [
                Row(
                  children: [
                    _Round(
                      icon: CupertinoIcons.chevron_back,
                      onTap: () => Navigator.maybePop(context),
                    ),
                    const SizedBox(width: 12),
                    const Expanded(
                      child: Text(
                        'Groups',
                        style: TextStyle(
                          fontSize: 26,
                          fontWeight: FontWeight.w700,
                          letterSpacing: -0.5,
                          color: HomeColors.ink,
                        ),
                      ),
                    ),
                    if (canCreate)
                      _Round(
                        icon: CupertinoIcons.add,
                        filled: true,
                        onTap: usersSnap.hasData
                            ? () => Navigator.push(
                                context,
                                iosRoute(GroupEditScreen(me: me, users: users)),
                              )
                            : () {},
                      ),
                  ],
                ),
                const Padding(
                  padding: EdgeInsets.fromLTRB(4, 10, 4, 16),
                  child: Text(
                    'Ring a whole group at once. The first person to accept goes, and everyone else is told who is going.',
                    style: TextStyle(
                      fontSize: 13.5,
                      height: 1.35,
                      color: HomeColors.sub,
                    ),
                  ),
                ),
                if (!snap.hasData)
                  const Padding(
                    padding: EdgeInsets.all(40),
                    child: Center(child: CupertinoActivityIndicator()),
                  )
                else if (groups.isEmpty)
                  Container(
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(18),
                    ),
                    child: Column(
                      children: [
                        const Icon(
                          CupertinoIcons.person_3,
                          size: 40,
                          color: HomeColors.blue,
                        ),
                        const SizedBox(height: 8),
                        const Text(
                          'No groups yet',
                          style: TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          canCreate
                              ? 'Tap + to make one, like "Lab assistants".'
                              : 'Your HOD can add you to a group.',
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            fontSize: 14,
                            color: HomeColors.sub,
                          ),
                        ),
                      ],
                    ),
                  )
                else
                  for (final g in groups) ...[
                    _GroupCard(
                      group: g,
                      users: users,
                      canRing: ringable.contains(g),
                      onOpen: () => Navigator.push(
                        context,
                        iosRoute(GroupScreen(me: me, group: g, users: users)),
                      ),
                      onRing: () => Navigator.push(
                        context,
                        iosRoute(CallScreen(me: me, group: g)),
                      ),
                    ),
                    const SizedBox(height: 10),
                  ],
              ],
            );
          },
        ),
      ),
    );
  }
}

class _Round extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  final bool filled;
  const _Round({required this.icon, required this.onTap, this.filled = false});
  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: onTap,
    child: Container(
      width: 42,
      height: 42,
      decoration: BoxDecoration(
        color: filled ? AppColors.accent : Colors.white,
        shape: BoxShape.circle,
      ),
      child: Icon(
        icon,
        size: 20,
        color: filled ? Colors.white : HomeColors.ink,
      ),
    ),
  );
}

class _GroupCard extends StatelessWidget {
  final Group group;
  final List<AppUser> users;
  final bool canRing;
  final VoidCallback onOpen, onRing;
  const _GroupCard({
    required this.group,
    required this.users,
    required this.canRing,
    required this.onOpen,
    required this.onRing,
  });

  @override
  Widget build(BuildContext context) {
    final byId = {for (final u in users) u.uid: u};
    final members = group.memberUids
        .map((id) => byId[id])
        .whereType<AppUser>()
        .toList();
    final free = members.where((u) => u.currentClass == null).length;
    return GestureDetector(
      onTap: onOpen,
      behavior: HitTestBehavior.opaque,
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(18),
        ),
        child: Row(
          children: [
            Container(
              width: 46,
              height: 46,
              decoration: BoxDecoration(
                color: HomeColors.blueBg,
                borderRadius: BorderRadius.circular(14),
              ),
              child: const Icon(
                CupertinoIcons.person_3_fill,
                color: HomeColors.blue,
                size: 24,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    group.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: HomeColors.ink,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '${group.memberUids.length} member${group.memberUids.length == 1 ? '' : 's'}'
                    '${users.isEmpty ? '' : ' · $free available'}',
                    style: const TextStyle(fontSize: 13, color: HomeColors.sub),
                  ),
                  if (members.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    SizedBox(
                      height: 26,
                      child: Stack(
                        children: [
                          for (var i = 0; i < members.length && i < 5; i++)
                            Positioned(
                              left: i * 18.0,
                              child: Container(
                                width: 26,
                                height: 26,
                                alignment: Alignment.center,
                                decoration: BoxDecoration(
                                  color: HomeColors.blueBg,
                                  shape: BoxShape.circle,
                                  border: Border.all(
                                    color: Colors.white,
                                    width: 2,
                                  ),
                                ),
                                child: Text(
                                  members[i].name.isEmpty
                                      ? '?'
                                      : members[i].name[0].toUpperCase(),
                                  style: const TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w700,
                                    color: HomeColors.blue,
                                  ),
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            ),
            if (canRing)
              CupertinoButton(
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 8,
                ),
                minimumSize: Size.zero,
                color: AppColors.accent,
                borderRadius: BorderRadius.circular(99),
                onPressed: onRing,
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      CupertinoIcons.bell_fill,
                      size: 15,
                      color: Colors.white,
                    ),
                    SizedBox(width: 5),
                    Text(
                      'Ring',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: Colors.white,
                      ),
                    ),
                  ],
                ),
              )
            else
              const Icon(
                CupertinoIcons.chevron_forward,
                size: 17,
                color: HomeColors.muted,
              ),
          ],
        ),
      ),
    );
  }
}
