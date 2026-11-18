import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:share_plus/share_plus.dart';

import '../../core/theme.dart';
import '../../models/models.dart';
import '../../services/services.dart';
import '../../services/group_links.dart';
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
        if (snap.hasData && !snap.data!.any((g) => g.id == group.id)) {
          return Scaffold(
            backgroundColor: Cb.page,
            body: SafeArea(
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: const [
                  CbHeader('Group'),
                  Text('This group is no longer available to you.'),
                ],
              ),
            ),
          );
        }
        final g =
            (snap.data ?? const <Group>[])
                .where((x) => x.id == group.id)
                .firstOrNull ??
            group;
        final members = users
            .where((u) => g.memberUids.contains(u.uid))
            .toList();
        final canManage = GroupService.canManage(me, g);
        final canRing = GroupService.canRing(me, g);
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
                        if (canManage) ...[
                          const CbSection('Invite students'),
                          CbCard(
                            children: [
                              CbItem(
                                icon: CupertinoIcons.share,
                                title: 'Share group link',
                                subtitle:
                                    'Students in ${g.department} join when they open it.',
                                onTap: () async {
                                  try {
                                    final box =
                                        context.findRenderObject()
                                            as RenderBox?;
                                    await SharePlus.instance.share(
                                      ShareParams(
                                        text:
                                            'Join ${g.name} on CampusBell:\n${GroupLinks.inviteUrl(g.id)}',
                                        sharePositionOrigin: box == null
                                            ? null
                                            : box.localToGlobal(Offset.zero) &
                                                  box.size,
                                      ),
                                    );
                                  } catch (e) {
                                    if (context.mounted) {
                                      showSnack(context, 'Could not share: $e');
                                    }
                                  }
                                },
                              ),
                              CbItem(
                                icon: CupertinoIcons.doc_on_doc,
                                title: 'Copy group link',
                                onTap: () async {
                                  await Clipboard.setData(
                                    ClipboardData(
                                      text: GroupLinks.inviteUrl(g.id),
                                    ),
                                  );
                                  if (context.mounted) {
                                    showSnack(context, 'Group link copied');
                                  }
                                },
                              ),
                            ],
                          ),
                        ],
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
                                  subtitle:
                                      g.adminUids.contains(u.uid) ||
                                          g.ownerUid == u.uid
                                      ? '${u.roleLabel} · Group admin'
                                      : u.roleLabel,
                                  onTap: canManage && u.uid != g.ownerUid
                                      ? () => _memberActions(context, g, u)
                                      : null,
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

  Future<void> _memberActions(
    BuildContext context,
    Group g,
    AppUser member,
  ) async {
    final isAdmin = g.adminUids.contains(member.uid);
    final action = await showCupertinoModalPopup<String>(
      context: context,
      builder: (c) => CupertinoActionSheet(
        title: Text(member.name),
        actions: [
          CupertinoActionSheetAction(
            onPressed: () => Navigator.pop(c, 'admin'),
            child: Text(isAdmin ? 'Remove group admin' : 'Make group admin'),
          ),
          CupertinoActionSheetAction(
            isDestructiveAction: true,
            onPressed: () => Navigator.pop(c, 'remove'),
            child: const Text('Remove from group'),
          ),
        ],
        cancelButton: CupertinoActionSheetAction(
          onPressed: () => Navigator.pop(c),
          child: const Text('Cancel'),
        ),
      ),
    );
    if (action == null) return;
    try {
      if (action == 'admin') {
        await GroupService.setAdmin(me, g.id, member.uid, !isAdmin);
      } else {
        await GroupService.save(
          me: me,
          id: g.id,
          name: g.name,
          department: g.department,
          originalMemberUids: g.memberUids,
          memberUids: g.memberUids.where((uid) => uid != member.uid).toList(),
        );
      }
      if (context.mounted) {
        showSnack(
          context,
          action == 'admin' ? 'Group admin updated.' : 'Member removed.',
        );
      }
    } catch (e) {
      if (context.mounted) showSnack(context, 'Could not update member: $e');
    }
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

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

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
        originalMemberUids: widget.group?.memberUids,
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
    // Group admins may add or remove people in this department.
    final people = widget.users
        .where(
          (u) =>
              u.uid != me.uid &&
              u.department == _dept &&
              (widget.group != null || Roles.canCall(me.role, u.role)) &&
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
