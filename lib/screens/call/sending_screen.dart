import 'dart:async';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import '../../core/theme.dart';
import '../../models/models.dart';
import '../../services/services.dart';
import '../../widgets/common.dart';

/// Live progress of a bell: created -> pushed -> delivered to the phone.
/// Every step reflects real server state; nothing is simulated.
class SendingScreen extends StatefulWidget {
  final String requestId, recipientName;
  const SendingScreen({
    super.key,
    required this.requestId,
    required this.recipientName,
  });
  @override
  State<SendingScreen> createState() => _SendingScreenState();
}

enum _Step { waiting, done, failed }

const _ink = Color(0xFF111114);
const _muted = Color(0xFF6B6B72);
const _line = Color(0xFFE6E8EF);
const _green = Color(0xFF22A35A);
const _red = Color(0xFFE5484D);

class _SendingScreenState extends State<SendingScreen>
    with SingleTickerProviderStateMixin {
  late final _pulse = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1600),
  )..repeat();
  _Step _push = _Step.waiting, _deliver = _Step.waiting;
  String? _error;
  BellRequest? _bell;
  StreamSubscription<BellRequest?>? _sub;

  @override
  void initState() {
    super.initState();
    _sub = BellService.watch(widget.requestId).listen(_onUpdate);
    BellService.notify(widget.requestId)
        .then((_) {
          if (mounted) setState(() => _push = _Step.done);
        })
        .catchError((Object e) {
          if (!mounted) return;
          setState(() {
            // If the server already answered "failed", the push step ran.
            _push = _deliver == _Step.failed ? _Step.done : _Step.failed;
            _error ??= e.toString();
          });
        });
  }

  void _onUpdate(BellRequest? r) {
    if (!mounted || r == null) return;
    setState(() => _bell = r);
    if (r.status == BellStatus.delivered || r.isAnswered) {
      _pulse.stop();
      setState(() {
        _push = _Step.done;
        _deliver = _Step.done;
      });
    } else if (r.status == BellStatus.failed ||
        r.status == BellStatus.rejected) {
      _pulse.stop();
      setState(() {
        // The server tried to send it, so the "sending" step is finished.
        _push = _Step.done;
        _deliver = _Step.failed;
        _error = r.error ?? 'Could not deliver the bell.';
      });
    }
  }

  @override
  void dispose() {
    _sub?.cancel();
    _pulse.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final b = _bell;
    final accepted = b?.status == BellStatus.accepted;
    final declined = b?.status == BellStatus.declined;
    final delivered = _deliver == _Step.done;
    final failed = _error != null || declined;
    final done = delivered || failed;
    final color = failed ? _red : (delivered ? _green : AppColors.accent);
    final first = shortName(widget.recipientName);

    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Responsive(
          maxWidth: 480,
          child: Column(
            children: [
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(20, 28, 20, 16),
                  children: [
                    // Status icon (pulses while sending).
                    Center(
                      child: SizedBox(
                        width: 130,
                        height: 130,
                        child: AnimatedBuilder(
                          animation: _pulse,
                          builder: (_, _) => Stack(
                            alignment: Alignment.center,
                            children: [
                              if (!done)
                                for (final k in [0.0, 0.5])
                                  Container(
                                    width: 76 + 54 * ((_pulse.value + k) % 1),
                                    height: 76 + 54 * ((_pulse.value + k) % 1),
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      color: AppColors.accent.withValues(
                                        alpha:
                                            .18 *
                                            (1 - ((_pulse.value + k) % 1)),
                                      ),
                                    ),
                                  ),
                              Container(
                                width: 76,
                                height: 76,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: color,
                                ),
                                child: Icon(
                                  declined
                                      ? CupertinoIcons.xmark
                                      : failed
                                      ? CupertinoIcons.exclamationmark
                                      : delivered
                                      ? CupertinoIcons.checkmark_alt
                                      : CupertinoIcons.bell_fill,
                                  color: Colors.white,
                                  size: 38,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      accepted
                          ? '$first accepted'
                          : declined
                          ? '$first declined'
                          : failed
                          ? 'Bell not delivered'
                          : delivered
                          ? 'Bell delivered'
                          : 'Sending bell…',
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontSize: 26,
                        fontWeight: FontWeight.w700,
                        color: _ink,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      accepted
                          ? '$first is on the way.'
                          : declined
                          ? 'Reason: ${(b!.reason ?? '').isEmpty ? 'No reason given' : b.reason}'
                          : failed
                          ? _error!
                          : delivered
                          ? '$first\'s phone is ringing now. Waiting for an answer…'
                          : 'Notifying $first…',
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontSize: 15,
                        color: _muted,
                        height: 1.4,
                      ),
                    ),
                    const SizedBox(height: 26),
                    const _Caption('To'),
                    _Box(
                      child: Row(
                        children: [
                          Avatar(widget.recipientName, radius: 22),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  widget.recipientName,
                                  style: const TextStyle(
                                    fontSize: 16.5,
                                    fontWeight: FontWeight.w600,
                                    color: _ink,
                                  ),
                                ),
                                if (b != null && b.recipientRole.isNotEmpty)
                                  Text(
                                    b.recipientRole,
                                    style: const TextStyle(
                                      fontSize: 14,
                                      color: _muted,
                                    ),
                                  ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (b != null) ...[
                      const SizedBox(height: 16),
                      const _Caption('Message'),
                      _Box(
                        child: Text(
                          b.message.isEmpty ? 'Please come' : b.message,
                          style: const TextStyle(
                            fontSize: 16,
                            height: 1.4,
                            color: _ink,
                          ),
                        ),
                      ),
                    ],
                    const SizedBox(height: 16),
                    const _Caption('Status'),
                    _Box(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: Column(
                        children: [
                          _row('Request created', _Step.done),
                          const Divider(height: 1, color: _line),
                          _row('Sending notification', _push),
                          const Divider(height: 1, color: _line),
                          _row('Ringing on their phone', _deliver),
                          const Divider(height: 1, color: _line),
                          _row(
                            accepted
                                ? 'Accepted'
                                : declined
                                ? 'Declined'
                                : 'Waiting for answer',
                            accepted
                                ? _Step.done
                                : declined
                                ? _Step.failed
                                : (_deliver == _Step.failed
                                      ? _Step.failed
                                      : _Step.waiting),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              // Full-rounded bottom button.
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 4, 20, 16),
                child: SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: CupertinoButton(
                    padding: EdgeInsets.zero,
                    color: done ? AppColors.accent : const Color(0xFFF1F2F6),
                    borderRadius: BorderRadius.circular(26),
                    onPressed: () => Navigator.pop(context),
                    child: Text(
                      done ? 'Done' : 'Close',
                      style: TextStyle(
                        color: done ? Colors.white : _ink,
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
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

  Widget _row(String label, _Step s) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 13),
    child: Row(
      children: [
        Expanded(
          child: Text(
            label,
            style: const TextStyle(fontSize: 15.5, color: _ink),
          ),
        ),
        switch (s) {
          _Step.done => const Icon(
            CupertinoIcons.checkmark_circle_fill,
            color: _green,
            size: 22,
          ),
          _Step.failed => const Icon(
            CupertinoIcons.xmark_circle_fill,
            color: _red,
            size: 22,
          ),
          _Step.waiting => const CupertinoActivityIndicator(radius: 9),
        },
      ],
    ),
  );
}

class _Caption extends StatelessWidget {
  final String text;
  const _Caption(this.text);
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(left: 4, bottom: 7),
    child: Text(
      text.toUpperCase(),
      style: const TextStyle(
        fontSize: 12.5,
        fontWeight: FontWeight.w600,
        letterSpacing: .4,
        color: _muted,
      ),
    ),
  );
}

class _Box extends StatelessWidget {
  final Widget child;
  final EdgeInsets padding;
  const _Box({required this.child, this.padding = const EdgeInsets.all(16)});
  @override
  Widget build(BuildContext context) => Container(
    width: double.infinity,
    padding: padding,
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(18),
      border: Border.all(color: _line),
    ),
    child: child,
  );
}
