import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/theme.dart';
import '../../models/models.dart';
import '../../widgets/cb.dart';
import '../../widgets/common.dart';
import '../../widgets/ios.dart';
import '../call/call_screen.dart';
import '../home/home_screen.dart';
import '../../widgets/photo.dart';

/// Another person's profile: photo + name, quick actions (Ring, Message,
/// Request, Email), their details and today's classes.
class UserDetailsScreen extends StatelessWidget {
  final AppUser me, user;
  const UserDetailsScreen({super.key, required this.me, required this.user});

  void _open(BuildContext context, Widget page) =>
      Navigator.push(context, iosRoute(page));

  @override
  Widget build(BuildContext context) {
    final u = user;
    final canRing = Roles.canCall(me.role, u.role);
    final canRequest = Roles.canRequest(me.role, u.role);
    final top = MediaQuery.paddingOf(context).top;

    void copy(String what, String text) {
      Clipboard.setData(ClipboardData(text: text));
      showSnack(context, '$what copied');
    }

    final actions = <Widget>[
      if (canRing) ...[
        _Action(
          icon: CupertinoIcons.bell_fill,
          label: 'Ring',
          primary: true,
          onTap: () => _open(context, CallScreen(me: me, to: u)),
        ),
        _Action(
          icon: CupertinoIcons.chat_bubble_fill,
          label: 'Message',
          onTap: () =>
              _open(context, CallScreen(me: me, to: u, focusMessage: true)),
        ),
      ],
      if (canRequest)
        _Action(
          icon: CupertinoIcons.hand_raised_fill,
          label: 'Request',
          primary: true,
          onTap: () => _open(context, CallScreen(me: me, to: u, request: true)),
        ),
      _Action(
        icon: CupertinoIcons.mail_solid,
        label: 'Email',
        onTap: () => copy('Email', u.email),
      ),
    ];

    final today = u.timetable
        .where((p) => p.day == DateTime.now().weekday)
        .toList();

    return Scaffold(
      backgroundColor: HomeColors.bg,
      body: Responsive(
        maxWidth: 520,
        child: ListView(
          padding: EdgeInsets.fromLTRB(16, top + 8, 16, 32),
          children: [
            Align(
              alignment: Alignment.centerLeft,
              child: GestureDetector(
                onTap: () => Navigator.maybePop(context),
                child: Container(
                  width: 42,
                  height: 42,
                  decoration: const BoxDecoration(
                    color: Colors.white,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    CupertinoIcons.chevron_back,
                    color: HomeColors.ink,
                    size: 20,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 6),
            // Identity
            Center(
              child: UserPhoto(
                uid: u.uid,
                size: 96,
                fallback: Container(
                  width: 96,
                  height: 96,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: HomeColors.blue,
                    border: Border.all(color: HomeColors.blueBg, width: 6),
                  ),
                  child: Text(
                    initials(u.name),
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 32,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 14),
            Text(
              u.name,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.w700,
                letterSpacing: -0.4,
                color: HomeColors.ink,
              ),
            ),
            const SizedBox(height: 8),
            Wrap(
              alignment: WrapAlignment.center,
              spacing: 8,
              runSpacing: 6,
              children: [
                _Pill(u.roleLabel, strong: true),
                _Pill(deptShort(u.department)),
                if (!u.isActive) const _Pill('Disabled', danger: true),
              ],
            ),
            const SizedBox(height: 22),
            // Quick actions
            Row(
              children: [
                for (var i = 0; i < actions.length; i++) ...[
                  if (i > 0) const SizedBox(width: 10),
                  Expanded(child: actions[i]),
                ],
              ],
            ),
            if (!canRing && !canRequest)
              Padding(
                padding: const EdgeInsets.only(top: 12),
                child: Text(
                  'Your role (${me.roleLabel}) can\'t ring a ${u.roleLabel}.',
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 13, color: HomeColors.sub),
                ),
              ),
            const SizedBox(height: 22),
            _Section(
              title: 'Details',
              children: [
                _InfoRow(
                  icon: CupertinoIcons.mail,
                  label: 'Email',
                  value: u.email,
                  onTap: () => copy('Email', u.email),
                  trailing: CupertinoIcons.doc_on_doc,
                ),
                if (u.username != null)
                  _InfoRow(
                    icon: CupertinoIcons.at,
                    label: 'Username',
                    value: '@${u.username}',
                    onTap: () => copy('Username', '@${u.username}'),
                    trailing: CupertinoIcons.doc_on_doc,
                  ),
                _InfoRow(
                  icon: CupertinoIcons.number,
                  label: u.role == Roles.student ? 'Student ID' : 'Employee ID',
                  value: u.staffId ?? 'Not added',
                ),
                _InfoRow(
                  icon: CupertinoIcons.building_2_fill,
                  label: 'Department',
                  value: u.department,
                ),
              ],
            ),
            if (today.isNotEmpty) ...[
              const SizedBox(height: 18),
              _Section(
                title: 'Classes today',
                children: [
                  for (final p in today)
                    _InfoRow(
                      icon: CupertinoIcons.clock,
                      label: '${p.start} – ${p.end}',
                      value: p.place.isEmpty
                          ? p.title
                          : '${p.title} · ${p.place}',
                    ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _Pill extends StatelessWidget {
  final String text;
  final bool strong, danger;
  const _Pill(this.text, {this.strong = false, this.danger = false});
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
    decoration: BoxDecoration(
      color: danger
          ? HomeColors.redBg
          : strong
          ? HomeColors.blueBg
          : Colors.white,
      borderRadius: BorderRadius.circular(99),
    ),
    child: Text(
      text,
      style: TextStyle(
        fontSize: 13,
        fontWeight: FontWeight.w600,
        color: danger
            ? HomeColors.redText
            : strong
            ? HomeColors.blue
            : HomeColors.sub,
      ),
    ),
  );
}

class _Action extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool primary;
  final VoidCallback onTap;
  const _Action({
    required this.icon,
    required this.label,
    required this.onTap,
    this.primary = false,
  });
  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: onTap,
    child: Container(
      padding: const EdgeInsets.symmetric(vertical: 14),
      decoration: BoxDecoration(
        color: primary ? HomeColors.blue : Colors.white,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        children: [
          Icon(icon, size: 22, color: primary ? Colors.white : HomeColors.blue),
          const SizedBox(height: 6),
          Text(
            label,
            style: TextStyle(
              fontSize: 13.5,
              fontWeight: FontWeight.w600,
              color: primary ? Colors.white : HomeColors.ink,
            ),
          ),
        ],
      ),
    ),
  );
}

class _Section extends StatelessWidget {
  final String title;
  final List<Widget> children;
  const _Section({required this.title, required this.children});
  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      Padding(
        padding: const EdgeInsets.fromLTRB(4, 0, 4, 8),
        child: Text(
          title.toUpperCase(),
          style: const TextStyle(
            fontSize: 12.5,
            fontWeight: FontWeight.w600,
            letterSpacing: .3,
            color: HomeColors.sub,
          ),
        ),
      ),
      Container(
        padding: const EdgeInsets.symmetric(horizontal: 14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(18),
        ),
        child: Column(
          children: [
            for (var i = 0; i < children.length; i++) ...[
              if (i > 0)
                const Divider(height: 1, indent: 46, color: HomeColors.line),
              children[i],
            ],
          ],
        ),
      ),
    ],
  );
}

class _InfoRow extends StatelessWidget {
  final IconData icon;
  final String label, value;
  final IconData? trailing;
  final VoidCallback? onTap;
  const _InfoRow({
    required this.icon,
    required this.label,
    required this.value,
    this.trailing,
    this.onTap,
  });
  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: onTap,
    behavior: HitTestBehavior.opaque,
    child: Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Row(
        children: [
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              color: HomeColors.blueBg,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, size: 17, color: HomeColors.blue),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: const TextStyle(fontSize: 12.5, color: HomeColors.sub),
                ),
                const SizedBox(height: 1),
                Text(
                  value,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 15.5, color: HomeColors.ink),
                ),
              ],
            ),
          ),
          if (trailing != null)
            Icon(trailing, size: 17, color: HomeColors.muted),
        ],
      ),
    ),
  );
}
