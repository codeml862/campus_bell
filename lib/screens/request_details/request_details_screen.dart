import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import '../../core/theme.dart';
import '../../models/models.dart';
import '../../services/services.dart';
import '../../widgets/common.dart';
import '../incoming/ringing_screen.dart';

const _ink = Color(0xFF111114);
const _sub = Color(0xFF6B6B72);
const _line = Color(0xFFE6E8EF);
const _green = Color(0xFF22A35A);
const _greenBg = Color(0xFFE3F6EA);
const _red = Color(0xFFE5484D);
const _redBg = Color(0xFFFDE8E8);
const _blueBg = Color(0xFFE6EEFB);

/// Details of one bell (sent or received): status, person, message,
/// details, and a full-rounded Done button.
class RequestDetailsScreen extends StatelessWidget {
  final AppUser? me;
  final String requestId;
  const RequestDetailsScreen({super.key, this.me, required this.requestId});

  @override
  Widget build(BuildContext context) {
    final myUid = me?.uid ?? auth.currentUser?.uid;
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Responsive(
          maxWidth: 480,
          child: StreamBuilder<BellRequest?>(
            stream: BellService.watch(requestId),
            builder: (_, snap) {
              if (snap.connectionState == ConnectionState.waiting) {
                return const Center(child: CupertinoActivityIndicator());
              }
              final r = snap.data;
              if (r == null) {
                return _shell(
                  context,
                  const Center(
                    child: Text(
                      'This bell no longer exists.',
                      style: TextStyle(color: _sub, fontSize: 16),
                    ),
                  ),
                );
              }
              // A request to me that I haven't answered: Accept / Decline.
              final answerable =
                  myUid != null &&
                  r.isRequest &&
                  r.isFor(myUid) &&
                  (r.status == BellStatus.pending ||
                      r.status == BellStatus.delivered);
              return _shell(
                context,
                _body(r, r.senderUid == myUid),
                bottom: answerable ? _AnswerBar(bell: r) : null,
              );
            },
          ),
        ),
      ),
    );
  }

  /// Back button on top, content, Done at the bottom.
  Widget _shell(BuildContext context, Widget content, {Widget? bottom}) =>
      Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CupertinoButton(
            padding: const EdgeInsets.fromLTRB(10, 4, 16, 4),
            onPressed: () => Navigator.of(context).maybePop(),
            child: const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  CupertinoIcons.chevron_back,
                  color: AppColors.accent,
                  size: 26,
                ),
                Text(
                  'Back',
                  style: TextStyle(fontSize: 17, color: AppColors.accent),
                ),
              ],
            ),
          ),
          Expanded(child: content),
          if (bottom != null)
            bottom
          else
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
              child: SizedBox(
                width: double.infinity,
                height: 50,
                child: CupertinoButton(
                  padding: EdgeInsets.zero,
                  color: AppColors.accent,
                  borderRadius: BorderRadius.circular(26),
                  onPressed: () => Navigator.of(context).maybePop(),
                  child: const Text(
                    'Done',
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
      );

  Widget _body(BellRequest r, bool sent) {
    final accepted = r.status == BellStatus.accepted;
    final declined = r.status == BellStatus.declined;
    final delivered = r.status == BellStatus.delivered || accepted || declined;
    final failed =
        r.status == BellStatus.failed ||
        r.status == BellStatus.rejected ||
        declined;
    final first = shortName(sent ? r.recipientName : r.senderName);
    final color = declined
        ? _red
        : delivered
        ? _green
        : (failed ? _red : AppColors.accent);
    final name = sent ? r.recipientName : r.senderName;
    final role = sent ? r.recipientRole : r.senderRole;
    final prio = r.priority[0].toUpperCase() + r.priority.substring(1);
    final (prioFg, prioBg) = switch (r.priority) {
      Priority.urgent => (_red, _redBg),
      Priority.high => (const Color(0xFFB86E00), const Color(0xFFFFF1DC)),
      _ => (AppColors.accent, _blueBg),
    };

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
      children: [
        Center(
          child: Container(
            width: 60,
            height: 60,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
            child: Icon(
              declined
                  ? CupertinoIcons.xmark
                  : delivered
                  ? CupertinoIcons.checkmark_alt
                  : failed
                  ? CupertinoIcons.exclamationmark
                  : CupertinoIcons.bell_fill,
              color: Colors.white,
              size: 30,
            ),
          ),
        ),
        const SizedBox(height: 10),
        Text(
          accepted
              ? 'Accepted'
              : declined
              ? 'Declined'
              : delivered
              ? 'Delivered'
              : failed
              ? 'Not delivered'
              : 'Sending…',
          textAlign: TextAlign.center,
          style: const TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.w800,
            color: Color(0xFF0F1B45),
          ),
        ),
        const SizedBox(height: 4),
        Text(
          accepted
              ? (sent ? '$first is on the way.' : 'You accepted this bell.')
              : declined
              ? (sent
                    ? '$first declined: ${(r.reason ?? '').isEmpty ? 'no reason given' : r.reason}'
                    : 'You declined: ${r.reason ?? ''}')
              : delivered
              ? (sent
                    ? 'The bell rang on ${name.split(' ').first}\'s phone.'
                    : 'This bell rang on your phone.')
              : failed
              ? (r.error ?? 'The bell was not delivered.')
              : 'Sending the bell…',
          textAlign: TextAlign.center,
          style: const TextStyle(fontSize: 14.5, color: _sub, height: 1.35),
        ),
        const SizedBox(height: 16),
        // From / To
        _Card(
          child: Row(
            children: [
              Avatar(
                name,
                radius: 22,
                uid: sent ? r.recipientUid : r.senderUid,
              ),
              Container(
                width: 1,
                height: 38,
                margin: const EdgeInsets.symmetric(horizontal: 12),
                color: _line,
              ),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      sent ? 'TO' : 'FROM',
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        letterSpacing: .4,
                        color: _sub,
                      ),
                    ),
                    Text(
                      name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 16.5,
                        fontWeight: FontWeight.w700,
                        color: _ink,
                      ),
                    ),
                    if (role.isNotEmpty)
                      Text(
                        role,
                        style: const TextStyle(fontSize: 14.5, color: _sub),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 10),
        // Message
        _Card(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const _CardTitle(CupertinoIcons.text_bubble_fill, 'Message'),
              const SizedBox(height: 6),
              Text(
                r.message.isEmpty ? 'Please come' : r.message,
                style: const TextStyle(fontSize: 16, height: 1.35, color: _ink),
              ),
            ],
          ),
        ),
        const SizedBox(height: 10),
        // Details
        _Card(
          padding: const EdgeInsets.fromLTRB(14, 12, 14, 2),
          child: Column(
            children: [
              const Align(
                alignment: Alignment.centerLeft,
                child: _CardTitle(CupertinoIcons.info_circle, 'Details'),
              ),
              const SizedBox(height: 4),
              _Detail(
                icon: CupertinoIcons.flag,
                label: 'Priority',
                trailing: _Pill(prio, prioFg, prioBg),
              ),
              _Detail(
                icon: CupertinoIcons.paperplane,
                label: 'Sent',
                trailing: _Value(fmtDateTime(r.createdAt)),
              ),
              if (accepted || declined)
                _Detail(
                  icon: accepted
                      ? CupertinoIcons.hand_thumbsup
                      : CupertinoIcons.hand_thumbsdown,
                  label: 'Response',
                  trailing: _Pill(
                    accepted ? 'Accepted' : 'Declined',
                    accepted ? _green : _red,
                    accepted ? _greenBg : _redBg,
                  ),
                ),
              if (r.isGroup && (r.claimedByName ?? '').isNotEmpty)
                _Detail(
                  icon: CupertinoIcons.person_crop_circle_badge_checkmark,
                  label: 'Accepted by',
                  trailing: _Value(r.claimedByName!),
                ),
              if (declined && (r.reason ?? '').isNotEmpty)
                _Detail(
                  icon: CupertinoIcons.text_quote,
                  label: 'Reason',
                  trailing: _Value(r.reason!),
                ),
              if (delivered && r.deliveredAt != null)
                _Detail(
                  icon: CupertinoIcons.checkmark_circle_fill,
                  iconColor: _green,
                  label: 'Delivered',
                  trailing: _Value(fmtDateTime(r.deliveredAt)),
                )
              else if (failed && !declined)
                const _Detail(
                  icon: CupertinoIcons.xmark_circle_fill,
                  iconColor: _red,
                  label: 'Delivery',
                  trailing: _Pill('Not delivered', _red, _redBg),
                ),
              _Detail(
                icon: CupertinoIcons.bell,
                label: 'Keep ringing',
                trailing: _Value(r.persistent ? 'On' : 'Off'),
                last: true,
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _Card extends StatelessWidget {
  final Widget child;
  final EdgeInsets padding;
  const _Card({required this.child, this.padding = const EdgeInsets.all(14)});
  @override
  Widget build(BuildContext context) => Container(
    width: double.infinity,
    padding: padding,
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(16),
      border: Border.all(color: _line),
    ),
    child: child,
  );
}

class _CardTitle extends StatelessWidget {
  final IconData icon;
  final String text;
  const _CardTitle(this.icon, this.text);
  @override
  Widget build(BuildContext context) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      Icon(icon, size: 20, color: AppColors.accent),
      const SizedBox(width: 8),
      Text(
        text.toUpperCase(),
        style: const TextStyle(
          fontSize: 12.5,
          fontWeight: FontWeight.w600,
          letterSpacing: .4,
          color: _sub,
        ),
      ),
    ],
  );
}

class _Detail extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String label;
  final Widget trailing;
  final bool last;
  const _Detail({
    required this.icon,
    required this.label,
    required this.trailing,
    this.iconColor = _ink,
    this.last = false,
  });
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(vertical: 9),
    decoration: BoxDecoration(
      border: last ? null : const Border(bottom: BorderSide(color: _line)),
    ),
    child: Row(
      children: [
        Icon(icon, size: 19, color: iconColor),
        const SizedBox(width: 10),
        Text(
          label,
          style: const TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w600,
            color: _ink,
          ),
        ),
        const SizedBox(width: 12),
        // Long values (dates) shrink / wrap instead of overlapping the label.
        Expanded(
          child: Align(alignment: Alignment.centerRight, child: trailing),
        ),
      ],
    ),
  );
}

class _Value extends StatelessWidget {
  final String text;
  const _Value(this.text);
  @override
  Widget build(BuildContext context) => Text(
    text,
    textAlign: TextAlign.right,
    maxLines: 2,
    overflow: TextOverflow.ellipsis,
    style: const TextStyle(fontSize: 14, color: _sub),
  );
}

class _Pill extends StatelessWidget {
  final String text;
  final Color fg, bg;
  const _Pill(this.text, this.fg, this.bg);
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
    decoration: BoxDecoration(
      color: bg,
      borderRadius: BorderRadius.circular(20),
    ),
    child: Text(
      text,
      style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: fg),
    ),
  );
}

/// Accept / Decline for a request to meet (decline asks for a reason).
class _AnswerBar extends StatefulWidget {
  final BellRequest bell;
  const _AnswerBar({required this.bell});
  @override
  State<_AnswerBar> createState() => _AnswerBarState();
}

class _AnswerBarState extends State<_AnswerBar> {
  bool _busy = false;

  Future<void> _answer(bool accept) async {
    String? reason;
    if (!accept) {
      reason = await showCupertinoModalPopup<String>(
        context: context,
        builder: (_) => const DeclineSheet(),
      );
      if (reason == null) return;
    }
    setState(() => _busy = true);
    try {
      await BellService.respond(widget.bell.id, accept: accept, reason: reason);
      if (mounted) {
        showSnack(
          context,
          accept
              ? '${widget.bell.senderName} has been told to come.'
              : 'Declined. ${widget.bell.senderName} can see your reason.',
        );
      }
    } catch (e) {
      if (mounted) showSnack(context, 'Could not answer: $e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 4, 20, 16),
      child: _busy
          ? const SizedBox(
              height: 52,
              child: Center(child: CupertinoActivityIndicator()),
            )
          : Row(
              children: [
                Expanded(
                  child: SizedBox(
                    height: 52,
                    child: CupertinoButton(
                      padding: EdgeInsets.zero,
                      color: _redBg,
                      borderRadius: BorderRadius.circular(26),
                      onPressed: () => _answer(false),
                      child: const Text(
                        'Decline',
                        style: TextStyle(
                          color: _red,
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: SizedBox(
                    height: 52,
                    child: CupertinoButton(
                      padding: EdgeInsets.zero,
                      color: _green,
                      borderRadius: BorderRadius.circular(26),
                      onPressed: () => _answer(true),
                      child: const Text(
                        'Accept',
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
    );
  }
}
