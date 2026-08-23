import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

const authOrange = Color(0xFFD97706);
const authGreen = Color(0xFF16A34A);
const maqaniAuthRedirect = 'io.maqani.app://auth-callback/';

class AuthScreen extends StatefulWidget {
  const AuthScreen({super.key});

  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> {
  final formKey = GlobalKey<FormState>();
  final email = TextEditingController();
  final password = TextEditingController();
  final name = TextEditingController();
  bool isSignUp = false;
  bool busy = false;
  String? error;

  Future<void> submit() async {
    if (!formKey.currentState!.validate()) return;
    setState(() {
      busy = true;
      error = null;
    });
    try {
      final auth = Supabase.instance.client.auth;
      if (isSignUp) {
        final response = await auth.signUp(
          email: email.text.trim(),
          password: password.text,
          data: {'display_name': name.text.trim()},
          emailRedirectTo: maqaniAuthRedirect,
        );
        if (!mounted) return;
        if (response.session == null) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('تم إنشاء الحساب. افتح رسالة البريد واضغط رابط التأكيد.'),
              backgroundColor: authGreen,
            ),
          );
        }
      } else {
        await auth.signInWithPassword(
          email: email.text.trim(),
          password: password.text,
        );
      }
    } on AuthException catch (e) {
      if (mounted) setState(() => error = _arabicError(e.message));
    } catch (_) {
      if (mounted) setState(() => error = 'تعذر الاتصال بالخدمة. حاول مرة أخرى.');
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  String _arabicError(String message) {
    final value = message.toLowerCase();
    if (value.contains('invalid login')) return 'البريد الإلكتروني أو كلمة المرور غير صحيحة.';
    if (value.contains('already registered')) return 'هذا البريد مسجل مسبقاً.';
    if (value.contains('email not confirmed')) return 'يجب تأكيد البريد الإلكتروني قبل تسجيل الدخول.';
    if (value.contains('password')) return 'يجب أن تتكون كلمة المرور من 6 أحرف على الأقل.';
    return message;
  }

  Future<void> signInSocial(OAuthProvider provider) async {
    setState(() {
      busy = true;
      error = null;
    });
    try {
      await Supabase.instance.client.auth.signInWithOAuth(
        provider,
        redirectTo: maqaniAuthRedirect,
      );
    } on AuthException catch (e) {
      if (mounted) setState(() => error = e.message);
    } catch (_) {
      if (mounted) setState(() => error = 'تعذر بدء تسجيل الدخول الاجتماعي.');
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  void dispose() {
    email.dispose();
    password.dispose();
    name.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFFFBF5),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(22),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 460),
              child: Form(
                key: formKey,
                child: Column(
                  children: [
                    Container(
                      width: 82,
                      height: 82,
                      decoration: BoxDecoration(
                        color: authOrange.withOpacity(.12),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.pets, size: 46, color: authOrange),
                    ),
                    const SizedBox(height: 14),
                    const Text('مقاني', style: TextStyle(fontSize: 30, fontWeight: FontWeight.w900)),
                    const SizedBox(height: 6),
                    Text(
                      isSignUp ? 'أنشئ حساب مزرعتك' : 'سجل الدخول إلى مزرعتك',
                      style: TextStyle(color: Colors.grey.shade700),
                    ),
                    const SizedBox(height: 28),
                    if (isSignUp) ...[
                      TextFormField(
                        controller: name,
                        decoration: const InputDecoration(
                          labelText: 'اسم المزرعة أو المستخدم',
                          prefixIcon: Icon(Icons.person_outline),
                        ),
                        validator: (v) => v == null || v.trim().isEmpty ? 'اكتب الاسم' : null,
                      ),
                      const SizedBox(height: 13),
                    ],
                    TextFormField(
                      controller: email,
                      keyboardType: TextInputType.emailAddress,
                      decoration: const InputDecoration(
                        labelText: 'البريد الإلكتروني',
                        prefixIcon: Icon(Icons.email_outlined),
                      ),
                      validator: (v) => v == null || !v.contains('@') ? 'أدخل بريداً صحيحاً' : null,
                    ),
                    const SizedBox(height: 13),
                    TextFormField(
                      controller: password,
                      obscureText: true,
                      decoration: const InputDecoration(
                        labelText: 'كلمة المرور',
                        prefixIcon: Icon(Icons.lock_outline),
                      ),
                      validator: (v) => v == null || v.length < 6 ? '6 أحرف على الأقل' : null,
                    ),
                    const SizedBox(height: 18),
                    if (error != null)
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(12),
                        margin: const EdgeInsets.only(bottom: 14),
                        decoration: BoxDecoration(
                          color: Colors.red.withOpacity(.08),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(error!, style: const TextStyle(color: Colors.red)),
                      ),
                    SizedBox(
                      width: double.infinity,
                      height: 52,
                      child: FilledButton(
                        onPressed: busy ? null : submit,
                        style: FilledButton.styleFrom(
                          backgroundColor: authGreen,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                        ),
                        child: busy
                            ? const SizedBox(
                                width: 22,
                                height: 22,
                                child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                              )
                            : Text(
                                isSignUp ? 'إنشاء الحساب' : 'تسجيل الدخول',
                                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                              ),
                      ),
                    ),
                    if (!isSignUp) ...[
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Expanded(child: Divider(color: Colors.grey.shade300)),
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 10),
                            child: Text('أو', style: TextStyle(color: Colors.grey.shade600)),
                          ),
                          Expanded(child: Divider(color: Colors.grey.shade300)),
                        ],
                      ),
                      const SizedBox(height: 10),
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton.icon(
                              onPressed: busy ? null : () => signInSocial(OAuthProvider.google),
                              icon: const Icon(Icons.account_circle_outlined),
                              label: const Text('Google'),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: OutlinedButton.icon(
                              onPressed: busy ? null : () => signInSocial(OAuthProvider.apple),
                              icon: const Icon(Icons.apple),
                              label: const Text('Apple'),
                            ),
                          ),
                        ],
                      ),
                      TextButton(
                        onPressed: busy
                            ? null
                            : () => Navigator.push(
                                context,
                                MaterialPageRoute(builder: (_) => const PasswordResetRequestScreen()),
                              ),
                        child: const Text('نسيت كلمة المرور؟'),
                      ),
                    ],
                    const SizedBox(height: 4),
                    TextButton(
                      onPressed: busy
                          ? null
                          : () => setState(() {
                                isSignUp = !isSignUp;
                                error = null;
                              }),
                      child: Text(isSignUp ? 'لديك حساب؟ سجل الدخول' : 'ليس لديك حساب؟ أنشئ حساباً'),
                    ),
                    if (isSignUp)
                      TextButton(
                        onPressed: busy
                            ? null
                            : () => Navigator.push(
                                context,
                                MaterialPageRoute(builder: (_) => const ResendConfirmationScreen()),
                              ),
                        child: const Text('إعادة إرسال رسالة التأكيد'),
                      ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class PasswordResetRequestScreen extends StatefulWidget {
  const PasswordResetRequestScreen({super.key});

  @override
  State<PasswordResetRequestScreen> createState() => _PasswordResetRequestScreenState();
}

class _PasswordResetRequestScreenState extends State<PasswordResetRequestScreen> {
  final email = TextEditingController();
  bool busy = false;
  String? message;

  Future<void> send() async {
    if (!email.text.contains('@')) {
      setState(() => message = 'أدخل بريداً صحيحاً');
      return;
    }
    setState(() => busy = true);
    try {
      await Supabase.instance.client.auth.resetPasswordForEmail(
        email.text.trim(),
        redirectTo: maqaniAuthRedirect,
      );
      if (mounted) setState(() => message = 'تم إرسال رابط إعادة التعيين إلى بريدك الإلكتروني.');
    } on AuthException catch (e) {
      if (mounted) setState(() => message = e.message);
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  void dispose() {
    email.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return _AuthScaffold(
      title: 'استعادة كلمة المرور',
      child: Column(
        children: [
          TextField(
            controller: email,
            keyboardType: TextInputType.emailAddress,
            decoration: const InputDecoration(labelText: 'البريد الإلكتروني', prefixIcon: Icon(Icons.email_outlined)),
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            height: 52,
            child: FilledButton(
              onPressed: busy ? null : send,
              style: FilledButton.styleFrom(backgroundColor: authGreen),
              child: busy ? const CircularProgressIndicator(color: Colors.white) : const Text('إرسال رابط الاستعادة'),
            ),
          ),
          if (message != null)
            Padding(
              padding: const EdgeInsets.only(top: 16),
              child: Text(message!, textAlign: TextAlign.center, style: const TextStyle(color: authGreen)),
            ),
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('العودة لتسجيل الدخول')),
        ],
      ),
    );
  }
}

class ResendConfirmationScreen extends StatefulWidget {
  const ResendConfirmationScreen({super.key});

  @override
  State<ResendConfirmationScreen> createState() => _ResendConfirmationScreenState();
}

class _ResendConfirmationScreenState extends State<ResendConfirmationScreen> {
  final email = TextEditingController();
  bool busy = false;
  String? message;

  Future<void> resend() async {
    if (!email.text.contains('@')) {
      setState(() => message = 'أدخل بريداً صحيحاً');
      return;
    }
    setState(() => busy = true);
    try {
      await Supabase.instance.client.auth.resend(
        type: OtpType.signup,
        email: email.text.trim(),
        emailRedirectTo: maqaniAuthRedirect,
      );
      if (mounted) setState(() => message = 'تمت إعادة إرسال رسالة التأكيد.');
    } on AuthException catch (e) {
      if (mounted) setState(() => message = e.message);
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  void dispose() {
    email.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return _AuthScaffold(
      title: 'تأكيد البريد الإلكتروني',
      child: Column(
        children: [
          const Text('اكتب بريد الحساب لإرسال رسالة تأكيد جديدة.'),
          const SizedBox(height: 16),
          TextField(
            controller: email,
            keyboardType: TextInputType.emailAddress,
            decoration: const InputDecoration(labelText: 'البريد الإلكتروني', prefixIcon: Icon(Icons.email_outlined)),
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            height: 52,
            child: FilledButton(
              onPressed: busy ? null : resend,
              style: FilledButton.styleFrom(backgroundColor: authOrange),
              child: busy ? const CircularProgressIndicator(color: Colors.white) : const Text('إعادة إرسال الرسالة'),
            ),
          ),
          if (message != null)
            Padding(
              padding: const EdgeInsets.only(top: 16),
              child: Text(message!, textAlign: TextAlign.center, style: const TextStyle(color: authGreen)),
            ),
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('العودة')),
        ],
      ),
    );
  }
}

class UpdatePasswordScreen extends StatefulWidget {
  const UpdatePasswordScreen({super.key});

  @override
  State<UpdatePasswordScreen> createState() => _UpdatePasswordScreenState();
}

class _UpdatePasswordScreenState extends State<UpdatePasswordScreen> {
  final password = TextEditingController();
  final confirm = TextEditingController();
  bool busy = false;
  String? message;

  Future<void> update() async {
    if (password.text.length < 6 || password.text != confirm.text) {
      setState(() => message = 'تأكد من تطابق كلمتي المرور وكونهما 6 أحرف على الأقل.');
      return;
    }
    setState(() => busy = true);
    try {
      await Supabase.instance.client.auth.updateUser(UserAttributes(password: password.text));
      if (mounted) setState(() => message = 'تم تحديث كلمة المرور بنجاح.');
    } on AuthException catch (e) {
      if (mounted) setState(() => message = e.message);
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  void dispose() {
    password.dispose();
    confirm.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return _AuthScaffold(
      title: 'تعيين كلمة مرور جديدة',
      child: Column(
        children: [
          TextField(
            controller: password,
            obscureText: true,
            decoration: const InputDecoration(labelText: 'كلمة المرور الجديدة', prefixIcon: Icon(Icons.lock_outline)),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: confirm,
            obscureText: true,
            decoration: const InputDecoration(labelText: 'تأكيد كلمة المرور', prefixIcon: Icon(Icons.lock_reset_outlined)),
          ),
          const SizedBox(height: 18),
          SizedBox(
            width: double.infinity,
            height: 52,
            child: FilledButton(
              onPressed: busy ? null : update,
              style: FilledButton.styleFrom(backgroundColor: authGreen),
              child: busy ? const CircularProgressIndicator(color: Colors.white) : const Text('حفظ كلمة المرور'),
            ),
          ),
          if (message != null)
            Padding(
              padding: const EdgeInsets.only(top: 16),
              child: Text(message!, textAlign: TextAlign.center, style: const TextStyle(color: authGreen)),
            ),
        ],
      ),
    );
  }
}

class _AuthScaffold extends StatelessWidget {
  const _AuthScaffold({required this.title, required this.child});
  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFFFBF5),
      appBar: AppBar(title: Text(title)),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(22),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 460),
            child: Card(
              elevation: 0,
              color: Colors.white,
              child: Padding(padding: const EdgeInsets.all(20), child: child),
            ),
          ),
        ),
      ),
    );
  }
}
