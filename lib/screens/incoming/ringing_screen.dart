import 'dart:async';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import '../../core/theme.dart';
import '../../models/models.dart';
import '../../services/notifications.dart';
import '../../services/services.dart';
import '../request_details/request_details_screen.dart';

/// Full-screen "someone is ringing you" page, shown over the lock screen
/// when a bell arrives. Keeps ringing until Accept or Decline (or 60 s).
/// Decline asks for a reason, which the sender sees.
class RingingScreen extends StatefulWidget {
  final String requestId;
  const RingingScreen({super.key, required this.requestId});
  @override
  State<RingingScreen> createState() => _RingingScreenState();
}

class _RingingScreenState extends State<RingingScreen>
    with SingleTickerProviderStateMixin {
  late final _pulse = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1200),
  )..repeat();

  StreamSubscription<BellRequest?>? _sub;
  BellRequest? _bell;
  bool _closing = false;

  @override
  void initState() {
    super.initState();
    // Group bell: if someone else accepts first, stop and say who.
    _sub = BellService.watch(widget.requestId).listen((b) {
      _bell = b;
      final me = auth.currentUser?.uid;
      if (b == null || !b.isGroup || _closing) return;
      if (b.status == BellStatus.accepted && b.claimedBy != me) {
        _closing = true;
        NotificationService.stop(widget.requestId);
        _showClaimed(b.claimedByName ?? 'Someone');
      }
    });
  }

  Future<void> _showClaimed(String name) async {
    if (!mounted) return;
    await showCupertinoDialog(
      context: context,
      builder: (c) => CupertinoAlertDialog(
        title: Text('$name accepted'),
        content: Text('$name is going. You don\'t need to.'),
        actions: [
          CupertinoDialogAction(
            isDefaultAction: true,
            onPressed: () => Navigator.pop(c),
            child: const Text('OK'),
          ),
        ],
      ),
    );
    if (mounted) Navigator.of(context).maybePop();
  }

  @override
  void dispose() {
    _sub?.cancel();
    _pulse.dispose();
    super.dispose();
  }

  bool _busy = false;

  Future<void> _answer({required bool accept}) async {
    final group = _bell?.isGroup ?? false;
    // Group: "Can't come" just stops my ringing; others can still accept.
    if (group && !accept) {
      _closing = true;
      await NotificationService.stop(widget.requestId);
      if (mounted) Navigator.of(context).maybePop();
      return;
    }
    String? reason;
    if (!accept) {
      reason = await showCupertinoModalPopup<String>(
        context: context,
        builder: (_) => const DeclineSheet(),
      );
      if (reason == null) return; // closed the sheet: keep ringing
    }
    setState(() => _busy = true);
    await NotificationService.stop(widget.requestId);
    try {
      await BellService.respond(
        widget.requestId,
        accept: accept,
        reason: reason,
      );
    } catch (_) {
      // Group: someone was faster (rules allow only the first accept).
      if (group) {
        final b = await BellService.watch(widget.requestId).first;
        if (b != null && b.claimedBy != auth.currentUser?.uid) {
          _closing = true;
          await _showClaimed(b.claimedByName ?? 'Someone');
          return;
        }
      }
    }
    if (!mounted) return;
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(
        builder: (_) => RequestDetailsScreen(requestId: widget.requestId),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      onPopInvokedWithResult: (_, _) =>
          NotificationService.stop(widget.requestId),
      child: Scaffold(
        body: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [Color(0xFF0F1B45), AppColors.accent],
            ),
          ),
          child: SafeArea(
            child: StreamBuilder<BellRequest?>(
              stream: BellService.watch(widget.requestId),
              builder: (_, s) {
                final b = s.data;
                return Padding(
                  padding: const EdgeInsets.all(28),
                  child: Column(
                    children: [
                      // Leave the top free: the ringing notification
                      // banner covers it while the phone rings.
                      const Spacer(flex: 3),
                      _PulsingBell(_pulse),
                      const SizedBox(height: 18),
                      Text(
                        b?.senderName ?? '…',
                        textAlign: TextAlign.center,
                        maxLines: 2,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 30,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        b == null
                            ? ''
                            : b.isGroup
                            ? '${b.senderRole} is calling ${b.recipientName}'
                            : '${b.senderRole} is calling you',
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: .75),
                          fontSize: 16,
                        ),
                      ),
                      if (b != null && b.priority != 'normal') ...[
                        const SizedBox(height: 10),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: b.priority == 'urgent'
                                ? AppColors.danger
                                : AppColors.warning,
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(
                            b.priority.toUpperCase(),
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 12,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 1,
                            ),
                          ),
                        ),
                      ],
                      const SizedBox(height: 22),
                      if (b != null)
                        Container(
                          width: double.infinity,
                          constraints: const BoxConstraints(maxHeight: 220),
                          padding: const EdgeInsets.all(18),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(22),
                          ),
                          child: SingleChildScrollView(
                            child: Text(
                              b.message.isEmpty ? 'Please come' : b.message,
                              textAlign: TextAlign.center,
                              style: const TextStyle(
                                color: Color(0xFF111114),
                                fontSize: 19,
                                fontWeight: FontWeight.w500,
                                height: 1.4,
                              ),
                            ),
                          ),
                        ),
                      const Spacer(flex: 2),
                      if (_busy)
                        const Padding(
                          padding: EdgeInsets.only(bottom: 40),
                          child: CupertinoActivityIndicator(
                            color: Colors.white,
                            radius: 14,
                          ),
                        )
                      else
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                          children: [
                            _CallButton(
                              icon: CupertinoIcons.xmark,
                              label: (b?.isGroup ?? false)
                                  ? "Can't come"
                                  : 'Decline',
                              color: const Color(0xFFE5484D),
                              onTap: () => _answer(accept: false),
                            ),
                            _CallButton(
                              icon: CupertinoIcons.checkmark_alt,
                              label: 'Accept',
                              color: const Color(0xFF22A35A),
                              onTap: () => _answer(accept: true),
                            ),
                          ],
                        ),
                      const SizedBox(height: 12),
                    ],
                  ),
                );
              },
            ),
          ),
        ),
      ),
    );
  }
}

class _PulsingBell extends AnimatedWidget {
  const _PulsingBell(Animation<double> a) : super(listenable: a);

  @override
  Widget build(BuildContext context) {
    final t = (listenable as Animation<double>).value;
    return SizedBox(
      width: 220,
      height: 220,
      child: Stack(
        alignment: Alignment.center,
        children: [
          for (final o in [0.0, 0.5])
            Builder(
              builder: (_) {
                final p = (t + o) % 1;
                return Container(
                  width: 110 + 110 * p,
                  height: 110 + 110 * p,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.white.withValues(alpha: .18 * (1 - p)),
                  ),
                );
              },
            ),
          Transform.rotate(
            angle: 0.25 * (t < .5 ? (t * 4 - 1) : (3 - t * 4)).clamp(-1, 1),
            child: Container(
              width: 110,
              height: 110,
              decoration: const BoxDecoration(
                color: Colors.white,
                shape: BoxShape.circle,
              ),
              child: const Icon(
                CupertinoIcons.bell_fill,
                color: AppColors.accent,
                size: 54,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Round call-style button with a label (Accept / Decline).
class _CallButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;
  const _CallButton({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });
  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: onTap,
    child: Column(
      children: [
        Container(
          width: 76,
          height: 76,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          child: Icon(icon, color: Colors.white, size: 36),
        ),
        const SizedBox(height: 8),
        Text(
          label,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 15,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    ),
  );
}

/// Pick (or type) a reason for declining. Returns it, or null if closed.
class DeclineSheet extends StatefulWidget {
  const DeclineSheet();
  @override
  State<DeclineSheet> createState() => DeclineSheetState();
}

class DeclineSheetState extends State<DeclineSheet> {
  static const _reasons = [
    'I am in a class',
    'I am in a meeting',
    'Will come in 10 minutes',
    'Not available today',
    'Call me later',
  ];
  final _other = TextEditingController();

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
            padding: const EdgeInsets.fromLTRB(18, 16, 18, 14),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    const Expanded(
                      child: Text(
                        'Why are you declining?',
                        style: TextStyle(
                          fontSize: 19,
                          fontWeight: FontWeight.w800,
                          color: Color(0xFF0F1B45),
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
                        size: 26,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                const Text(
                  'The sender will see your reason.',
                  style: TextStyle(fontSize: 13.5, color: Color(0xFF5F6472)),
                ),
                const SizedBox(height: 12),
                for (final r in _reasons)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: GestureDetector(
                      onTap: () => Navigator.pop(context, r),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 13,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF4F6FA),
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Text(
                          r,
                          style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w500,
                            color: Color(0xFF15171C),
                          ),
                        ),
                      ),
                    ),
                  ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Expanded(
                      child: Container(
                        height: 46,
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        alignment: Alignment.centerLeft,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(23),
                          border: Border.all(color: const Color(0xFFE3E3E8)),
                        ),
                        child: CupertinoTextField.borderless(
                          controller: _other,
                          placeholder: 'Other reason',
                          padding: EdgeInsets.zero,
                          maxLength: 100,
                          style: const TextStyle(fontSize: 15),
                          onChanged: (_) => setState(() {}),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    CupertinoButton(
                      padding: const EdgeInsets.symmetric(horizontal: 18),
                      minimumSize: const Size(0, 46),
                      color: const Color(0xFFE5484D),
                      disabledColor: const Color(0xFFF3B5B7),
                      borderRadius: BorderRadius.circular(23),
                      onPressed: _other.text.trim().isEmpty
                          ? null
                          : () => Navigator.pop(context, _other.text.trim()),
                      child: const Text(
                        'Decline',
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
