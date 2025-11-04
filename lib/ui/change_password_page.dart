import 'package:flutter/material.dart';

class ChangePasswordPage extends StatefulWidget {
  const ChangePasswordPage({super.key});

  @override
  State<ChangePasswordPage> createState() => _ChangePasswordPageState();
}

class _ChangePasswordPageState extends State<ChangePasswordPage> {
  // ألوان موحّدة
  static const kPrimary = Color(0xFF34D399);
  static const kTextDark = Color(0xFF222222);
  static const kHint = Color(0xFF9AA0A6);
  static const kBorder = Color(0xFFE5E7EB);

  final _formKey = GlobalKey<FormState>();
  final _oldCtrl = TextEditingController();
  final _newCtrl = TextEditingController();
  final _confirmCtrl = TextEditingController();

  bool _obscOld = true;
  bool _obscNew = true;
  bool _obscConfirm = true;

  @override
  void dispose() {
    _oldCtrl.dispose();
    _newCtrl.dispose();
    _confirmCtrl.dispose();
    super.dispose();
  }

  InputDecoration _dec(String hint,
      {Widget? prefix, Widget? suffix, EdgeInsets? contentPadding}) {
    return InputDecoration(
      hintText: hint,
      hintStyle: const TextStyle(color: kHint, fontSize: 13.5),
      prefixIcon: prefix,
      suffixIcon: suffix,
      isDense: true,
      filled: true,
      fillColor: Colors.white,
      contentPadding:
      contentPadding ?? const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: kBorder),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: kPrimary, width: 1.4),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: Colors.redAccent),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: Colors.redAccent, width: 1.4),
      ),
    );
  }

  void _submit() {
    if (!(_formKey.currentState?.validate() ?? false)) return;

    // TODO: اربطها لاحقاً بـ API تغيير كلمة السر
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Password changed successfully')),
    );
    Navigator.pop(context); // رجوع للصفحة السابقة (Profile Settings)
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
          children: [
            // هيدر بسيط
            Row(
              children: [
                IconButton(
                  icon: const Icon(Icons.arrow_back_ios_new_rounded),
                  onPressed: () => Navigator.pop(context),
                ),
                const SizedBox(width: 8),
                const Text(
                  'Change password',
                  style: TextStyle(
                    color: kTextDark,
                    fontWeight: FontWeight.w800,
                    fontSize: 28,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),

            Form(
              key: _formKey,
              child: Column(
                children: [
                  // Old Password
                  TextFormField(
                    controller: _oldCtrl,
                    obscureText: _obscOld,
                    decoration: _dec(
                      'Old Password',
                      prefix: const Icon(Icons.lock_outline, color: kHint),
                      suffix: IconButton(
                        icon: Icon(
                          _obscOld
                              ? Icons.visibility_outlined
                              : Icons.visibility_off_outlined,
                          color: kHint,
                        ),
                        onPressed: () => setState(() => _obscOld = !_obscOld),
                      ),
                    ),
                    validator: (v) =>
                    (v == null || v.isEmpty) ? 'Please enter old password' : null,
                  ),
                  const SizedBox(height: 14),

                  // New Password
                  TextFormField(
                    controller: _newCtrl,
                    obscureText: _obscNew,
                    decoration: _dec(
                      'New Password',
                      prefix: const Icon(Icons.lock_outline, color: kHint),
                      suffix: IconButton(
                        icon: Icon(
                          _obscNew
                              ? Icons.visibility_outlined
                              : Icons.visibility_off_outlined,
                          color: kHint,
                        ),
                        onPressed: () => setState(() => _obscNew = !_obscNew),
                      ),
                    ),
                    validator: (v) {
                      if (v == null || v.isEmpty) {
                        return 'Please enter new password';
                      }
                      if (v.length < 6) {
                        return 'Password must be at least 6 characters';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 14),

                  // Confirm New Password
                  TextFormField(
                    controller: _confirmCtrl,
                    obscureText: _obscConfirm,
                    decoration: _dec(
                      'Confirm New Password',
                      prefix: const Icon(Icons.lock_outline, color: kHint),
                      suffix: IconButton(
                        icon: Icon(
                          _obscConfirm
                              ? Icons.visibility_outlined
                              : Icons.visibility_off_outlined,
                          color: kHint,
                        ),
                        onPressed: () =>
                            setState(() => _obscConfirm = !_obscConfirm),
                      ),
                    ),
                    validator: (v) {
                      if (v == null || v.isEmpty) {
                        return 'Please confirm new password';
                      }
                      if (v != _newCtrl.text) {
                        return 'Passwords do not match';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 28),

                  // Submit
                  SizedBox(
                    width: double.infinity,
                    height: 48,
                    child: ElevatedButton(
                      onPressed: _submit,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: kPrimary,
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                      child: const Text(
                        'Submit',
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
          ],
        ),
      ),
    );
  }
}
