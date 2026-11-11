import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import '../../core/theme.dart';
import '../../models/models.dart';
import '../../services/services.dart';
import '../../widgets/cb.dart';
import '../../widgets/common.dart';
import '../../widgets/ios.dart';
import '../call/call_screen.dart';

/// A group: its members and one "Ring group" button. Everyone in the group
/// rings; the first to accept goes and the others are told.
class GroupScreen extends StatelessWidget {
  final AppUser me;
  final Group group;
  final List<AppUser> users;
  const GroupScreen({
    super.key,
    required this.me,
    required this.group,
    required this.users,
  });

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<Group>>(
      stream: GroupService.mine(me),
      builder: (_, snap) {
        final g =
            (snap.data ?? const <Group>[])
                .where((x) => x.id == group.id)
                .firstOrNull ??
            group;
        final members = users
            .where((u) => g.memberUids.contains(u.uid))
            .toList();
        final canManage = GroupService.canManage(me, g);
        final canRing = canManage || g.ownerUid == me.uid;
        return Scaffold(
          backgroundColor: Cb.page,
          body: SafeArea(
            child: Responsive(
              maxWidth: 520,
              child: Column(
                children: [
                  Expanded(
                    child: ListView(
                      padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                      children: [
                        CbHeader(
                          'Group',
                          trailing: canManage
                              ? CupertinoButton(
                                  padding: EdgeInsets.zero,
                                  minimumSize: Size.zero,
                                  onPressed: () => Navigator.push(
                                    context,
                                    iosRoute(
                                      GroupEditScreen(
                                        me: me,
                                        users: users,
                                        group: g,
                                      ),
                                    ),
                                  ),
                                  child: const Text(
                                    'Edit',
                                    style: TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w600,
                                      color: AppColors.accent,
                                    ),
                                  ),
                                )
                              : null,
                        ),
                        CbBlueCard(
                          name: g.name,
                          line2: g.department,
                          pill:
                              '${members.length} member${members.length == 1 ? '' : 's'}',
                        ),
                        const CbSection('Members'),
                        if (members.isEmpty)
                          const CbCard(
                            children: [
                              CbItem(
                                icon: CupertinoIcons.person_add,
                                title: 'No members yet',
                                subtitle: 'Tap Edit to add people.',
                              ),
                            ],
                          )
                        else
                          CbCard(
                            indent: 72,
                            children: [
                              for (final u in members)
                                CbItem(
                                  leading: CbAvatar(u.name, uid: u.uid),
                                  title: u.uid == me.uid
                                      ? '${u.name} (you)'
                                      : u.name,
                                  subtitle: u.roleLabel,
                                ),
                            ],
                          ),
                        const SizedBox(height: 12),
                        const Padding(
                          padding: EdgeInsets.symmetric(horizontal: 6),
                          child: Text(
                            'Ring group rings everyone at once. The first person to '
                            'accept comes to you; the others get "X accepted" and '
                            'their phones stop ringing.',
                            style: TextStyle(
                              fontSize: 12.5,
                              height: 1.4,
                              color: Cb.sub,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (canRing)
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 6, 16, 14),
                      child: SizedBox(
                        width: double.infinity,
                        height: 54,
                        child: CupertinoButton(
                          padding: EdgeInsets.zero,
                          color: AppColors.accent,
                          borderRadius: BorderRadius.circular(27),
                          onPressed: members.isEmpty
                              ? null
                              : () => Navigator.push(
                                  context,
                                  iosRoute(CallScreen(me: me, group: g)),
                                ),
                          child: const Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                CupertinoIcons.bell_fill,
                                color: Colors.white,
                                size: 20,
                              ),
                              SizedBox(width: 8),
                              Text(
                                'Ring group',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 16,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ],
                          ),
                        ),
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
}

/// Create or edit a group: name + members from the department.
class GroupEditScreen extends StatefulWidget {
  final AppUser me;
  final List<AppUser> users;
  final Group? group;
  const GroupEditScreen({
    super.key,
    required this.me,
    required this.users,
    this.group,
  });
  @override
  State<GroupEditScreen> createState() => _GroupEditScreenState();
}

class _GroupEditScreenState extends State<GroupEditScreen> {
  late final _name = TextEditingController(text: widget.group?.name ?? '');
  late final Set<String> _members = {...?widget.group?.memberUids};
  late final String _dept = widget.group?.department ?? widget.me.department;
  String _q = '';
  bool _busy = false;

  Future<void> _save() async {
    if (_name.text.trim().length < 2) {
      showSnack(context, 'Give the group a name.');
      return;
    }
    setState(() => _busy = true);
    try {
      await GroupService.save(
        me: widget.me,
        id: widget.group?.id,
        name: _name.text,
        department: _dept,
        memberUids: _members.toList(),
      );
      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (mounted) showSnack(context, 'Could not save: $e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _delete() async {
    final ok = await showCupertinoDialog<bool>(
      context: context,
      builder: (c) => CupertinoAlertDialog(
        title: const Text('Delete group?'),
        content: const Text('Members stay in CampusBell; only the group goes.'),
        actions: [
          CupertinoDialogAction(
            onPressed: () => Navigator.pop(c, false),
            child: const Text('Cancel'),
          ),
          CupertinoDialogAction(
            isDestructiveAction: true,
            onPressed: () => Navigator.pop(c, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    await GroupService.delete(widget.group!.id);
    if (!mounted) return;
    Navigator.of(context)
      ..pop()
      ..pop();
  }

  @override
  Widget build(BuildContext context) {
    final me = widget.me;
    // Only people below you in your department (main admin: that department).
    final people = widget.users
        .where(
          (u) =>
              u.uid != me.uid &&
              u.department == _dept &&
              Roles.canCall(me.role, u.role) &&
              (_q.isEmpty || u.name.toLowerCase().contains(_q)),
        )
        .toList();
    return Scaffold(
      backgroundColor: Cb.page,
      body: SafeArea(
        child: Responsive(
          maxWidth: 520,
          child: Column(
            children: [
              Expanded(
                child: ListView(
                  keyboardDismissBehavior:
                      ScrollViewKeyboardDismissBehavior.onDrag,
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                  children: [
                    CbHeader(widget.group == null ? 'New group' : 'Edit group'),
                    const CbSection('Name'),
                    Container(
                      height: 48,
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF7F7F9),
                        borderRadius: BorderRadius.circular(24),
                        border: Border.all(color: Cb.line),
                      ),
                      alignment: Alignment.centerLeft,
                      child: CupertinoTextField.borderless(
                        controller: _name,
                        placeholder: 'e.g. Lab assistants',
                        padding: EdgeInsets.zero,
                        textCapitalization: TextCapitalization.sentences,
                        style: const TextStyle(fontSize: 15.5),
                      ),
                    ),
                    Row(
                      children: [
                        Expanded(
                          child: CbSection('Members (${_members.length})'),
                        ),
                      ],
                    ),
                    CupertinoSearchTextField(
                      placeholder: 'Search people in $_dept',
                      onChanged: (v) =>
                          setState(() => _q = v.trim().toLowerCase()),
                    ),
                    const SizedBox(height: 10),
                    if (people.isEmpty)
                      const Padding(
                        padding: EdgeInsets.all(20),
                        child: Center(
                          child: Text(
                            'No one found.',
                            style: TextStyle(color: Cb.sub),
                          ),
                        ),
                      )
                    else
                      CbCard(
                        indent: 72,
                        children: [
                          for (final u in people)
                            CbItem(
                              leading: CbAvatar(u.name, uid: u.uid),
                              title: u.name,
                              subtitle: u.roleLabel,
                              trailing: Icon(
                                _members.contains(u.uid)
                                    ? CupertinoIcons.checkmark_circle_fill
                                    : CupertinoIcons.circle,
                                color: _members.contains(u.uid)
                                    ? AppColors.accent
                                    : Cb.line,
                                size: 24,
                              ),
                              onTap: () => setState(
                                () => _members.contains(u.uid)
                                    ? _members.remove(u.uid)
                                    : _members.add(u.uid),
                              ),
                            ),
                        ],
                      ),
                    if (widget.group != null) ...[
                      const SizedBox(height: 20),
                      CbCard(
                        children: [
                          CbItem(
                            icon: CupertinoIcons.trash,
                            title: 'Delete group',
                            danger: true,
                            chevron: false,
                            onTap: _delete,
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 6, 16, 14),
                child: SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: CupertinoButton(
                    padding: EdgeInsets.zero,
                    color: AppColors.accent,
                    borderRadius: BorderRadius.circular(26),
                    onPressed: _busy ? null : _save,
                    child: _busy
                        ? const CupertinoActivityIndicator(color: Colors.white)
                        : const Text(
                            'Save group',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
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
