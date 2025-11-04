import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';

class ForgotPasswordPage extends StatefulWidget {
  const ForgotPasswordPage({super.key});

  @override
  State<ForgotPasswordPage> createState() => _ForgotPasswordPageState();
}

class _ForgotPasswordPageState extends State<ForgotPasswordPage> {
  // ألوان موحّدة
  static const Color kPrimary = Color(0xFF34D399);
  static const Color kTextDark = Color(0xFF222222);
  static const Color kHint = Color(0xFF9AA0A6);
  static const Color kBorder = Color(0xFFE5E7EB);

  final _formKey = GlobalKey<FormState>();
  final _emailCtrl = TextEditingController();

  bool _sending = false;

  @override
  void dispose() {
    _emailCtrl.dispose();
    super.dispose();
  }

  InputDecoration _inputDecoration(String hint, IconData icon) {
    return InputDecoration(
      hintText: hint,
      hintStyle: const TextStyle(color: kHint, fontSize: 13.5),
      isDense: true,
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      prefixIcon: Icon(icon, color: kHint),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: const BorderSide(color: kBorder),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: const BorderSide(color: kPrimary, width: 1.4),
      ),
      filled: true,
      fillColor: const Color(0xFFF5F5F5),
    );
  }

  void _toast(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  bool _isEmail(String v) =>
      RegExp(r'^[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}$').hasMatch(v);

  String _mapAuthError(FirebaseAuthException e) {
    switch (e.code) {
      case 'invalid-email':
        return 'البريد الإلكتروني غير صالح.';
      case 'user-not-found':
        return 'لا يوجد مستخدم بهذا البريد.';
      case 'network-request-failed':
        return 'مشكلة في الشبكة. حاول لاحقًا.';
      default:
        return 'حدث خطأ: ${e.code}';
    }
  }

  /// إرسال رابط إعادة التعيين (بدون ActionCodeSettings) + الرجوع للّوجين.
  Future<void> _sendResetSimple() async {
    final email = _emailCtrl.text.trim();
    if (email.isEmpty || !_isEmail(email)) {
      _toast('أدخل بريدًا إلكترونيًا صحيحًا.');
      return;
    }

    FocusScope.of(context).unfocus();
    setState(() => _sending = true);

    try {
      await FirebaseAuth.instance.sendPasswordResetEmail(email: email);

      if (!mounted) return;
      // رسالة نجاح قصيرة…
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'تم إرسال رابط إعادة تعيين كلمة السر إلى $email.\n'
                'تحقق من Inbox و/أو Spam/Promotions.',
          ),
          duration: const Duration(seconds: 2),
        ),
      );

      // …ثم رجوع للّوجين
      await Future.delayed(const Duration(milliseconds: 600));
      if (mounted) Navigator.pop(context);
    } on FirebaseAuthException catch (e) {
      if (!mounted) return;
      _toast(_mapAuthError(e));
    } catch (_) {
      if (!mounted) return;
      _toast('تعذّر الإرسال. حاول مجددًا.');
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  "Forgot\npassword?",
                  style: TextStyle(
                    color: kTextDark,
                    fontSize: 30,
                    fontWeight: FontWeight.w800,
                    height: 1.2,
                  ),
                ),
                const SizedBox(height: 22),

                TextFormField(
                  controller: _emailCtrl,
                  keyboardType: TextInputType.emailAddress,
                  decoration: _inputDecoration(
                    "Enter your email address",
                    Icons.email_outlined,
                  ),
                  validator: (v) {
                    if (v == null || v.isEmpty) return "Please enter your email";
                    if (!_isEmail(v.trim())) return 'Invalid email';
                    return null;
                  },
                ),
                const SizedBox(height: 8),
                const Text(
                  "* سنرسل إليك رسالة تحتوي على رابط لإعادة تعيين كلمة السر. "
                      "تفقد البريد الوارد و/أو Spam/Promotions.",
                  style: TextStyle(color: Colors.redAccent, fontSize: 11.5),
                ),
                const SizedBox(height: 18),

                SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: ElevatedButton(
                    onPressed: _sending ? null : _sendResetSimple,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: kPrimary,
                      disabledBackgroundColor: kPrimary.withOpacity(0.6),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                      elevation: 0,
                    ),
                    child: _sending
                        ? const SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(
                        strokeWidth: 2.3,
                        valueColor:
                        AlwaysStoppedAnimation<Color>(Colors.white),
                      ),
                    )
                        : const Text(
                      "Send reset link",
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w700,
                        fontSize: 16,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
