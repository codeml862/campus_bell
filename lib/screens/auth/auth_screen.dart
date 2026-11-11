import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:google_sign_in/google_sign_in.dart';

import '../../core/theme.dart';
import '../../services/services.dart';
import '../../widgets/common.dart';

String authError(Object e) {
  if (e is GoogleSignInException) {
    return e.code == GoogleSignInExceptionCode.canceled
        ? 'Google sign-in was cancelled.'
        : 'Google sign-in is not set up yet.';
  }
  if (e is FirebaseAuthException) {
    switch (e.code) {
      case 'invalid-credential':
      case 'wrong-password':
      case 'user-not-found':
        return 'Wrong username/email or password.';
      case 'email-already-in-use':
        return 'This email is already registered. Sign in instead.';
      case 'weak-password':
        return 'Password is too weak.';
      case 'invalid-email':
        return 'Enter a valid email.';
      case 'network-request-failed':
        return 'No internet connection.';
      case 'too-many-requests':
        return 'Too many attempts. Try again in a few minutes.';
      case 'account-exists-with-different-credential':
        return 'This email already has a password account. Sign in with it.';
    }
    return e.message ?? e.code;
  }
  return e.toString();
}

// Colours for the auth screens.
const _ink = Color(0xFF111114);
const _sub = Color(0xFF6B6B72);
const _hint = Color(0xFFA0A0A8);
const _fieldBg = Color(0xFFF7F7F9);
const _line = Color(0xFFE3E3E8);
const _red = Color(0xFFE5484D);

/// Sign In (first screen when logged out).
class AuthScreen extends StatefulWidget {
  const AuthScreen({super.key});
  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> {
  final _id = TextEditingController();
  final _pass = TextEditingController();
  bool _hide = true, _busy = false, _gBusy = false;
  String? _error;

  Future<void> _run(Future<void> Function() f, {bool google = false}) async {
    FocusScope.of(context).unfocus();
    setState(() {
      google ? _gBusy = true : _busy = true;
      _error = null;
    });
    try {
      await f();
    } catch (e) {
      if (mounted) setState(() => _error = authError(e));
    } finally {
      if (mounted) setState(() => _busy = _gBusy = false);
    }
  }

  void _submit() {
    if (_id.text.trim().isEmpty || _pass.text.isEmpty) {
      setState(() => _error = 'Enter your username or email and password.');
      return;
    }
    _run(() => AuthService.login(_id.text, _pass.text));
  }

  Future<void> _forgot() async {
    final email = _id.text.trim();
    if (!email.contains('@') || email.startsWith('@')) {
      setState(() => _error = 'Type your email above, then tap Forgot.');
      return;
    }
    try {
      await AuthService.resetPassword(email);
      if (mounted) showSnack(context, 'Reset link sent to $email');
    } catch (e) {
      setState(() => _error = authError(e));
    }
  }

  @override
  Widget build(BuildContext context) {
    return _AuthPage(
      centered: true,
      title: 'Sign in',
      subtitle: 'Welcome back. Enter your details.',
      children: [
        const _Label('Username or email'),
        _Field(
          controller: _id,
          hint: 'name@college.edu',
          icon: CupertinoIcons.person,
          keyboard: TextInputType.emailAddress,
          autofill: const [AutofillHints.username, AutofillHints.email],
          action: TextInputAction.next,
        ),
        const SizedBox(height: 12),
        _Label(
          'Password',
          trailing: GestureDetector(
            onTap: _forgot,
            child: const Text(
              'Forgot?',
              style: TextStyle(
                fontSize: 13,
                color: AppColors.accent,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ),
        _Field(
          controller: _pass,
          hint: 'Your password',
          icon: CupertinoIcons.lock,
          obscure: _hide,
          onToggleObscure: () => setState(() => _hide = !_hide),
          autofill: const [AutofillHints.password],
          action: TextInputAction.done,
          onSubmitted: (_) => _submit(),
        ),
        _ErrorText(_error),
        const SizedBox(height: 16),
        _PrimaryButton(label: 'Sign in', loading: _busy, onPressed: _submit),
        const _OrDivider(),
        _GoogleButton(
          loading: _gBusy,
          onPressed: () => _run(AuthService.google, google: true),
        ),
        const SizedBox(height: 18),
        _FooterLink(
          text: 'New to CampusBell?',
          link: 'Create account',
          onTap: () => Navigator.of(context).push(
            CupertinoPageRoute(builder: (_) => const CreateAccountScreen()),
          ),
        ),
      ],
    );
  }
}

/// Create Account: first + last name, email, password.
/// The username is made automatically from the name.
class CreateAccountScreen extends StatefulWidget {
  const CreateAccountScreen({super.key});
  @override
  State<CreateAccountScreen> createState() => _CreateAccountScreenState();
}

class _CreateAccountScreenState extends State<CreateAccountScreen> {
  final _first = TextEditingController();
  final _last = TextEditingController();
  final _email = TextEditingController();
  final _pass = TextEditingController();
  bool _hide = true, _busy = false, _gBusy = false;
  String? _error;

  bool get _len => _pass.text.length >= 8;
  bool get _num => _pass.text.contains(RegExp(r'\d'));
  bool get _letter => _pass.text.contains(RegExp(r'[A-Za-z]'));
  int get _strength => [_len, _num, _letter].where((x) => x).length;

  Future<void> _run(Future<void> Function() f, {bool google = false}) async {
    FocusScope.of(context).unfocus();
    setState(() {
      google ? _gBusy = true : _busy = true;
      _error = null;
    });
    try {
      await f();
      // Signed in: the app underneath moves on to role selection.
      if (mounted) Navigator.of(context).popUntil((r) => r.isFirst);
    } catch (e) {
      if (mounted) setState(() => _error = authError(e));
    } finally {
      if (mounted) setState(() => _busy = _gBusy = false);
    }
  }

  String? _check() {
    if (_first.text.trim().isEmpty) return 'Enter your first name.';
    if (_last.text.trim().isEmpty) return 'Enter your last name.';
    if (!RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(_email.text.trim())) {
      return 'Enter a valid email.';
    }
    if (_strength < 3) {
      return 'Password needs 8+ characters with a letter and a number.';
    }
    return null;
  }

  void _submit() {
    final err = _check();
    if (err != null) {
      setState(() => _error = err);
      return;
    }
    _run(
      () => AuthService.signUp(
        firstName: _first.text,
        lastName: _last.text,
        email: _email.text.trim(),
        password: _pass.text,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return _AuthPage(
      title: 'Create account',
      subtitle: 'It takes less than a minute.',
      children: [
        Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const _Label('First name'),
                  _Field(
                    controller: _first,
                    hint: 'First',
                    caps: TextCapitalization.words,
                    autofill: const [AutofillHints.givenName],
                    action: TextInputAction.next,
                  ),
                ],
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const _Label('Last name'),
                  _Field(
                    controller: _last,
                    hint: 'Last',
                    caps: TextCapitalization.words,
                    autofill: const [AutofillHints.familyName],
                    action: TextInputAction.next,
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        const _Label('Email'),
        _Field(
          controller: _email,
          hint: 'name@college.edu',
          icon: CupertinoIcons.mail,
          keyboard: TextInputType.emailAddress,
          autofill: const [AutofillHints.email],
          action: TextInputAction.next,
        ),
        const SizedBox(height: 12),
        const _Label('Password'),
        _Field(
          controller: _pass,
          hint: 'Create a password',
          icon: CupertinoIcons.lock,
          obscure: _hide,
          onToggleObscure: () => setState(() => _hide = !_hide),
          onChanged: (_) => setState(() {}),
          autofill: const [AutofillHints.newPassword],
          action: TextInputAction.done,
          onSubmitted: (_) => _submit(),
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            for (var i = 0; i < 3; i++) ...[
              if (i > 0) const SizedBox(width: 4),
              Expanded(
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  height: 4,
                  decoration: BoxDecoration(
                    color: i < _strength ? AppColors.accent : _line,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
            ],
          ],
        ),
        const Padding(
          padding: EdgeInsets.only(top: 6, left: 4),
          child: Text(
            '8+ characters with a letter and a number',
            style: TextStyle(fontSize: 12, color: Color(0xFF8A8A92)),
          ),
        ),
        _ErrorText(_error),
        const SizedBox(height: 16),
        _PrimaryButton(
          label: 'Create account',
          loading: _busy,
          onPressed: _submit,
        ),
        const _OrDivider(),
        _GoogleButton(
          loading: _gBusy,
          onPressed: () => _run(AuthService.google, google: true),
        ),
        const SizedBox(height: 16),
        _FooterLink(
          text: 'Already have an account?',
          link: 'Sign in',
          onTap: () => Navigator.of(context).pop(),
        ),
      ],
    );
  }
}

// ------------------------------------------------------------ pieces

/// White page: small logo + name, title, subtitle, then the form.
class _AuthPage extends StatelessWidget {
  final String title, subtitle;
  final List<Widget> children;

  /// Sign in: the form sits in the middle of the screen (no empty space
  /// at the bottom). Create account keeps the normal top-aligned list.
  final bool centered;
  const _AuthPage({
    required this.title,
    required this.subtitle,
    required this.children,
    this.centered = false,
  });

  static const _pad = EdgeInsets.fromLTRB(22, 26, 22, 20);

  Widget _layout(List<Widget> items) {
    if (!centered) {
      return ListView(
        keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
        padding: _pad,
        children: items,
      );
    }
    return LayoutBuilder(
      builder: (_, box) => SingleChildScrollView(
        keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
        padding: _pad,
        child: ConstrainedBox(
          constraints: BoxConstraints(minHeight: box.maxHeight - _pad.vertical),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: items,
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Responsive(
          maxWidth: 460,
          child: AutofillGroup(
            child: _layout([
              Row(
                children: [
                  Container(
                    width: 30,
                    height: 30,
                    decoration: BoxDecoration(
                      color: AppColors.accent,
                      borderRadius: BorderRadius.circular(9),
                    ),
                    child: const Icon(
                      CupertinoIcons.bell_fill,
                      color: Colors.white,
                      size: 17,
                    ),
                  ),
                  const SizedBox(width: 8),
                  const Text(
                    'CampusBell',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: _ink,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              Text(
                title,
                style: const TextStyle(
                  fontSize: 27,
                  fontWeight: FontWeight.w700,
                  letterSpacing: -0.5,
                  color: _ink,
                ),
              ),
              const SizedBox(height: 2),
              Text(subtitle, style: const TextStyle(fontSize: 15, color: _sub)),
              const SizedBox(height: 20),
              ...children,
            ]),
          ),
        ),
      ),
    );
  }
}

/// Small bold label above a field (optional trailing link).
class _Label extends StatelessWidget {
  final String text;
  final Widget? trailing;
  const _Label(this.text, {this.trailing});
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(left: 4, right: 4, bottom: 6),
    child: Row(
      children: [
        Expanded(
          child: Text(
            text,
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: _ink,
            ),
          ),
        ),
        ?trailing,
      ],
    ),
  );
}

/// Fully rounded (pill) input: light grey, blue border while typing.
class _Field extends StatefulWidget {
  final TextEditingController controller;
  final String hint;
  final IconData? icon;
  final bool obscure;
  final VoidCallback? onToggleObscure;
  final TextInputType? keyboard;
  final TextCapitalization caps;
  final Iterable<String>? autofill;
  final TextInputAction? action;
  final ValueChanged<String>? onChanged, onSubmitted;

  const _Field({
    required this.controller,
    required this.hint,
    this.icon,
    this.obscure = false,
    this.onToggleObscure,
    this.keyboard,
    this.caps = TextCapitalization.none,
    this.autofill,
    this.action,
    this.onChanged,
    this.onSubmitted,
  });

  @override
  State<_Field> createState() => _FieldState();
}

class _FieldState extends State<_Field> {
  final _focus = FocusNode();

  @override
  void initState() {
    super.initState();
    _focus.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _focus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final w = widget;
    final on = _focus.hasFocus;
    return AnimatedContainer(
      duration: const Duration(milliseconds: 150),
      height: 48,
      padding: EdgeInsets.only(left: w.icon == null ? 18 : 14, right: 6),
      decoration: BoxDecoration(
        color: on ? Colors.white : _fieldBg,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: on ? AppColors.accent : _line,
          width: on ? 1.5 : 1,
        ),
      ),
      child: Row(
        children: [
          if (w.icon != null) ...[
            Icon(w.icon, size: 19, color: on ? AppColors.accent : _hint),
            const SizedBox(width: 10),
          ],
          Expanded(
            child: CupertinoTextField.borderless(
              controller: w.controller,
              focusNode: _focus,
              placeholder: w.hint,
              placeholderStyle: const TextStyle(fontSize: 15.5, color: _hint),
              style: const TextStyle(fontSize: 15.5, color: _ink),
              obscureText: w.obscure,
              keyboardType: w.keyboard,
              textCapitalization: w.caps,
              autofillHints: w.autofill,
              textInputAction: w.action,
              onChanged: w.onChanged,
              onSubmitted: w.onSubmitted,
              autocorrect: false,
              cursorColor: AppColors.accent,
              padding: EdgeInsets.zero,
            ),
          ),
          if (w.onToggleObscure != null)
            CupertinoButton(
              padding: const EdgeInsets.symmetric(horizontal: 10),
              minimumSize: Size.zero,
              onPressed: w.onToggleObscure,
              child: Icon(
                w.obscure ? CupertinoIcons.eye : CupertinoIcons.eye_slash,
                size: 19,
                color: _hint,
              ),
            )
          else
            const SizedBox(width: 10),
        ],
      ),
    );
  }
}

/// Fully rounded blue button.
class _PrimaryButton extends StatelessWidget {
  final String label;
  final bool loading;
  final VoidCallback onPressed;
  const _PrimaryButton({
    required this.label,
    required this.onPressed,
    this.loading = false,
  });

  @override
  Widget build(BuildContext context) => SizedBox(
    height: 50,
    width: double.infinity,
    child: CupertinoButton(
      padding: EdgeInsets.zero,
      color: AppColors.accent,
      disabledColor: AppColors.accent.withValues(alpha: .6),
      borderRadius: BorderRadius.circular(25),
      onPressed: loading ? null : onPressed,
      child: loading
          ? const CupertinoActivityIndicator(color: Colors.white)
          : Text(
              label,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            ),
    ),
  );
}

/// Fully rounded white "Continue with Google" button with the colour G.
class _GoogleButton extends StatelessWidget {
  final bool loading;
  final VoidCallback onPressed;
  const _GoogleButton({required this.onPressed, this.loading = false});

  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: loading ? null : onPressed,
    child: Container(
      height: 50,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(25),
        border: Border.all(color: _line),
      ),
      child: Center(
        child: loading
            ? const CupertinoActivityIndicator()
            : const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  SizedBox(
                    width: 19,
                    height: 19,
                    child: CustomPaint(painter: _GoogleLogo()),
                  ),
                  SizedBox(width: 10),
                  Text(
                    'Continue with Google',
                    style: TextStyle(
                      fontSize: 15.5,
                      fontWeight: FontWeight.w600,
                      color: _ink,
                    ),
                  ),
                ],
              ),
      ),
    ),
  );
}

/// The official four-colour Google "G", drawn from its SVG paths (48x48).
class _GoogleLogo extends CustomPainter {
  const _GoogleLogo();
  @override
  void paint(Canvas canvas, Size size) {
    canvas.scale(size.width / 48, size.height / 48);
    void draw(Color c, Path p) => canvas.drawPath(p, Paint()..color = c);

    draw(
      const Color(0xFFEA4335),
      Path()
        ..moveTo(24, 9.5)
        ..cubicTo(27.5, 9.5, 30.6, 10.7, 33.1, 13.1)
        ..lineTo(39.9, 6.3)
        ..cubicTo(35.8, 2.4, 30.3, 0, 24, 0)
        ..cubicTo(14.6, 0, 6.6, 5.4, 2.7, 13.2)
        ..lineTo(10.6, 19.4)
        ..cubicTo(12.5, 13.7, 17.8, 9.5, 24, 9.5)
        ..close(),
    );
    draw(
      const Color(0xFF4285F4),
      Path()
        ..moveTo(46.5, 24.5)
        ..cubicTo(46.5, 22.9, 46.4, 21.4, 46.1, 20)
        ..lineTo(24, 20)
        ..lineTo(24, 29)
        ..lineTo(36.7, 29)
        ..cubicTo(36.1, 32, 34.4, 34.5, 31.9, 36.2)
        ..lineTo(39.6, 42.2)
        ..cubicTo(44.1, 38, 46.5, 31.9, 46.5, 24.5)
        ..close(),
    );
    draw(
      const Color(0xFFFBBC05),
      Path()
        ..moveTo(10.6, 28.6)
        ..cubicTo(10.1, 27.2, 9.8, 25.6, 9.8, 24)
        ..cubicTo(9.8, 22.4, 10.1, 20.8, 10.6, 19.4)
        ..lineTo(2.7, 13.2)
        ..cubicTo(1, 16.6, 0, 20.2, 0, 24)
        ..cubicTo(0, 27.8, 1, 31.4, 2.7, 34.8)
        ..lineTo(10.6, 28.6)
        ..close(),
    );
    draw(
      const Color(0xFF34A853),
      Path()
        ..moveTo(24, 48)
        ..cubicTo(30.5, 48, 35.9, 45.9, 39.9, 42.2)
        ..lineTo(32.2, 36.2)
        ..cubicTo(30.1, 37.6, 27.3, 38.5, 24, 38.5)
        ..cubicTo(17.8, 38.5, 12.5, 34.3, 10.6, 28.6)
        ..lineTo(2.7, 34.8)
        ..cubicTo(6.6, 42.6, 14.6, 48, 24, 48)
        ..close(),
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _OrDivider extends StatelessWidget {
  const _OrDivider();
  @override
  Widget build(BuildContext context) => const Padding(
    padding: EdgeInsets.symmetric(vertical: 14),
    child: Row(
      children: [
        Expanded(child: Divider(color: Color(0xFFECECF0))),
        Padding(
          padding: EdgeInsets.symmetric(horizontal: 10),
          child: Text('or', style: TextStyle(color: _hint, fontSize: 12.5)),
        ),
        Expanded(child: Divider(color: Color(0xFFECECF0))),
      ],
    ),
  );
}

class _FooterLink extends StatelessWidget {
  final String text, link;
  final VoidCallback onTap;
  const _FooterLink({
    required this.text,
    required this.link,
    required this.onTap,
  });
  @override
  Widget build(BuildContext context) => Row(
    mainAxisAlignment: MainAxisAlignment.center,
    children: [
      Text(text, style: const TextStyle(color: _sub, fontSize: 13.5)),
      GestureDetector(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(6),
          child: Text(
            link,
            style: const TextStyle(
              color: AppColors.accent,
              fontSize: 13.5,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ),
    ],
  );
}

/// Small red message under the form (no big blocks of red text).
class _ErrorText extends StatelessWidget {
  final String? text;
  const _ErrorText(this.text);
  @override
  Widget build(BuildContext context) => text == null
      ? const SizedBox.shrink()
      : Padding(
          padding: const EdgeInsets.only(top: 10, left: 4, right: 4),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Padding(
                padding: EdgeInsets.only(top: 1),
                child: Icon(
                  CupertinoIcons.exclamationmark_circle,
                  size: 15,
                  color: _red,
                ),
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  text!,
                  style: const TextStyle(color: _red, fontSize: 13),
                ),
              ),
            ],
          ),
        );
}
