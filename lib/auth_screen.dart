import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

const authOrange = Color(0xFFD97706);
const authGreen = Color(0xFF16A34A);

class AuthScreen extends StatefulWidget {
  const AuthScreen({super.key});
  @override State<AuthScreen> createState() => _AuthScreenState();
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
    setState(() { busy = true; error = null; });
    try {
      final auth = Supabase.instance.client.auth;
      if (isSignUp) {
        final response = await auth.signUp(email: email.text.trim(), password: password.text, data: {'display_name': name.text.trim()});
        if (!mounted) return;
        if (response.session == null) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('تم إنشاء الحساب. تحقق من بريدك الإلكتروني لتفعيل الحساب.'), backgroundColor: authGreen));
        }
      } else {
        await auth.signInWithPassword(email: email.text.trim(), password: password.text);
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
    if (value.contains('password')) return 'يجب أن تتكون كلمة المرور من 6 أحرف على الأقل.';
    return message;
  }

  @override Widget build(BuildContext context) => Scaffold(backgroundColor: const Color(0xFFFFFBF5), body: SafeArea(child: Center(child: SingleChildScrollView(padding: const EdgeInsets.all(22), child: ConstrainedBox(constraints: const BoxConstraints(maxWidth: 460), child: Form(key: formKey, child: Column(children: [Container(width: 82, height: 82, decoration: BoxDecoration(color: authOrange.withOpacity(.12), shape: BoxShape.circle), child: const Icon(Icons.pets, size: 46, color: authOrange)), const SizedBox(height: 14), const Text('مقاني', style: TextStyle(fontSize: 30, fontWeight: FontWeight.w900)), const SizedBox(height: 6), Text(isSignUp ? 'أنشئ حساب مزرعتك' : 'سجل الدخول إلى مزرعتك', style: TextStyle(color: Colors.grey.shade700)), const SizedBox(height: 28), if (isSignUp) ...[TextFormField(controller: name, decoration: const InputDecoration(labelText: 'اسم المزرعة أو المستخدم', prefixIcon: Icon(Icons.person_outline)), validator: (v) => v == null || v.trim().isEmpty ? 'اكتب الاسم' : null), const SizedBox(height: 13)], TextFormField(controller: email, keyboardType: TextInputType.emailAddress, decoration: const InputDecoration(labelText: 'البريد الإلكتروني', prefixIcon: Icon(Icons.email_outlined)), validator: (v) => v == null || !v.contains('@') ? 'أدخل بريداً صحيحاً' : null), const SizedBox(height: 13), TextFormField(controller: password, obscureText: true, decoration: const InputDecoration(labelText: 'كلمة المرور', prefixIcon: Icon(Icons.lock_outline)), validator: (v) => v == null || v.length < 6 ? '6 أحرف على الأقل' : null), const SizedBox(height: 18), if (error != null) Container(width: double.infinity, padding: const EdgeInsets.all(12), margin: const EdgeInsets.only(bottom: 14), decoration: BoxDecoration(color: Colors.red.withOpacity(.08), borderRadius: BorderRadius.circular(12)), child: Text(error!, style: const TextStyle(color: Colors.red))), SizedBox(width: double.infinity, height: 52, child: FilledButton(onPressed: busy ? null : submit, style: FilledButton.styleFrom(backgroundColor: authGreen, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14))), child: busy ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)) : Text(isSignUp ? 'إنشاء الحساب' : 'تسجيل الدخول', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)))), const SizedBox(height: 12), TextButton(onPressed: busy ? null : () => setState(() { isSignUp = !isSignUp; error = null; }), child: Text(isSignUp ? 'لديك حساب؟ سجل الدخول' : 'ليس لديك حساب؟ أنشئ حساباً'))]))))));
}
