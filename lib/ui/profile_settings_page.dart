import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
// ✅ 1. حل تعارض User: استخدام البادئة sb لـ Supabase
import 'package:supabase_flutter/supabase_flutter.dart' as sb;

import 'change_password_page.dart';

// ------------------------------------------------------------------
// Formatter لتنسيق تاريخ الانتهاء تلقائيًا (MM/YY)
// ------------------------------------------------------------------
class CardMonthInputFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
      TextEditingValue oldValue,
      TextEditingValue newValue,
      ) {
    var text = newValue.text;

    if (newValue.selection.start == 0) {
      return newValue;
    }

    var buffer = StringBuffer();
    for (int i = 0; i < text.length; i++) {
      buffer.write(text[i]);
      var nonZeroIndex = i + 1;
      if (nonZeroIndex % 2 == 0 && nonZeroIndex != text.length) {
        buffer.write('/');
      }
    }

    var string = buffer.toString();
    return newValue.copyWith(
      text: string,
      selection: TextSelection.collapsed(offset: string.length),
    );
  }
}

// ------------------------------------------------------------------
// AddCardDialog - صندوق الحوار لإضافة بطاقة جديدة
// ------------------------------------------------------------------
class AddCardDialog extends StatefulWidget {
  const AddCardDialog({super.key});

  @override
  State<AddCardDialog> createState() => _AddCardDialogState();
}

class _AddCardDialogState extends State<AddCardDialog> {
  final _formKey = GlobalKey<FormState>();
  final _cardNumberCtrl = TextEditingController();
  final _expiryCtrl = TextEditingController();
  final _cvvCtrl = TextEditingController();
  bool _saving = false;

  // الألوان المستخدمة لضمان التناسق
  static const kPrimary = Color(0xFF34D399);
  static const kHint = Color(0xFF9AA0A6);
  static const kBorder = Color(0xFFE5E7EB);
  static const kTextDark = Color(0xFF222222);

  // دالة لإخفاء عداد الحروف (maxLength)
  Widget _buildCounter(BuildContext context, {required int currentLength, required bool isFocused, required int? maxLength}) {
    return const SizedBox.shrink();
  }

  InputDecoration _dec(String hint, {Widget? prefix, Widget? suffix}) {
    return InputDecoration(
      hintText: hint,
      prefixIcon: prefix,
      suffixIcon: suffix,
      isDense: true,
      filled: true,
      fillColor: Colors.white,
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      hintStyle: const TextStyle(color: kHint, fontSize: 13.5),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: kBorder),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: kPrimary, width: 1.4),
      ),
    );
  }

  void _snack(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(msg)));
  }

  Future<void> _saveCard() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      _snack('يجب تسجيل الدخول أولاً.');
      return;
    }

    setState(() => _saving = true);
    try {
      final cardNumber = _cardNumberCtrl.text.trim();
      final rawCardNumber = cardNumber.replaceAll(RegExp(r'[^\d]'), '');
      final expiry = _expiryCtrl.text.trim();
      final cvv = _cvvCtrl.text.trim();

      await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .collection('cards')
          .add({
        'cardNumber': rawCardNumber,
        'last4Digits': rawCardNumber.length >= 4 ? rawCardNumber.substring(rawCardNumber.length - 4) : '',
        'expiry': expiry,
        'cvv': cvv,
        'createdAt': FieldValue.serverTimestamp(),
      });

      if (mounted) Navigator.pop(context, true);
      _snack('تم حفظ البطاقة بنجاح.');

    } catch (e) {
      _snack('تعذر حفظ البطاقة: $e');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(15),
        ),
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  'Enter card details',
                  style: TextStyle(
                    color: kTextDark,
                    fontWeight: FontWeight.w700,
                    fontSize: 18,
                  ),
                ),
              ),
              const SizedBox(height: 18),

              // Card number
              TextFormField(
                controller: _cardNumberCtrl,
                keyboardType: TextInputType.number,
                maxLength: 12,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                decoration: _dec('Card number',
                    prefix: const Icon(Icons.credit_card, color: kHint)),
                buildCounter: _buildCounter,
                validator: (v) => (v == null || v.trim().length != 12) ? 'Enter a valid 12-digit card number' : null,
              ),
              const SizedBox(height: 12),

              Row(
                children: [
                  // Expiry
                  Expanded(
                    child: TextFormField(
                      controller: _expiryCtrl,
                      keyboardType: TextInputType.number,
                      maxLength: 5,
                      inputFormatters: [
                        FilteringTextInputFormatter.digitsOnly,
                        CardMonthInputFormatter(),
                      ],
                      decoration: _dec('MM/YY'),
                      buildCounter: _buildCounter,
                      validator: (v) => (v == null || v.trim().length != 5 || !v.contains('/')) ? 'Enter a valid expiry date (MM/YY)' : null,
                    ),
                  ),
                  const SizedBox(width: 12),
                  // CVV
                  Expanded(
                    child: TextFormField(
                      controller: _cvvCtrl,
                      keyboardType: TextInputType.number,
                      obscureText: true,
                      maxLength: 3,
                      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                      decoration: _dec('CVV code',
                          suffix: const Icon(Icons.credit_card_outlined, color: kHint)),
                      buildCounter: _buildCounter,
                      validator: (v) => (v == null || v.trim().length != 3) ? 'Enter a valid 3-digit CVV' : null,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),

              // Buttons: Save & Cancel
              Row(
                children: [
                  Expanded(
                    child: SizedBox(
                      height: 48,
                      child: ElevatedButton(
                        onPressed: _saving ? null : _saveCard,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: kPrimary,
                          disabledBackgroundColor: kPrimary.withOpacity(0.6),
                          elevation: 0,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                        child: _saving
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
                          'Save',
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w700,
                            fontSize: 16,
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: SizedBox(
                      height: 48,
                      child: OutlinedButton(
                        onPressed: () => Navigator.pop(context, false),
                        style: OutlinedButton.styleFrom(
                          side: const BorderSide(color: kPrimary),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                        child: const Text(
                          'Cancel',
                          style: TextStyle(
                            color: kPrimary,
                            fontWeight: FontWeight.w700,
                            fontSize: 16,
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ------------------------------------------------------------------
// ProfileSettingsPage
// ------------------------------------------------------------------

class ProfileSettingsPage extends StatefulWidget {
  const ProfileSettingsPage({super.key});

  @override
  State<ProfileSettingsPage> createState() => _ProfileSettingsPageState();
}

class _ProfileSettingsPageState extends State<ProfileSettingsPage> {
  // Colors
  static const kPrimary = Color(0xFF34D399);
  static const kTextDark = Color(0xFF222222);
  static const kHint = Color(0xFF9AA0A6);
  static const kBorder = Color(0xFFE5E7EB);
  static const kError = Color(0xFFEF4444);

  final _formKey = GlobalKey<FormState>();

  // Controllers
  final _emailCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController(text: '');

  bool _loading = true;
  bool _saving = false;
  String? _photoUrl;
  User? _user; // 👈 هنا يتم استخدام User من Firebase Auth

  // قائمة البطاقات المحفوظة
  List<Map<String, dynamic>> _cards = [];

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  @override
  void dispose() {
    _emailCtrl.dispose();
    _passwordCtrl.dispose();
    super.dispose();
  }

  void _snack(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(msg)));
  }

  InputDecoration _dec(String hint, {Widget? prefix, Widget? suffix}) {
    return InputDecoration(
      hintText: hint,
      prefixIcon: prefix,
      suffixIcon: suffix,
      isDense: true,
      filled: true,
      fillColor: Colors.white,
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      hintStyle: const TextStyle(color: kHint, fontSize: 13.5),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: kBorder),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: kPrimary, width: 1.4),
      ),
    );
  }

  Future<void> _loadCards() async {
    if (_user == null) return;
    try {
      final snapshot = await FirebaseFirestore.instance
          .collection('users')
          .doc(_user!.uid)
          .collection('cards')
          .orderBy('createdAt', descending: true)
          .get();

      _cards = snapshot.docs
          .map((doc) => {
        ...doc.data(),
        'id': doc.id,
      })
          .toList();

    } catch (e) {
      _snack('تعذر تحميل البطاقات: $e');
    }
  }

  Future<void> _loadProfile() async {
    try {
      _user = FirebaseAuth.instance.currentUser;
      if (_user == null) {
        setState(() {
          _loading = false;
        });
        _snack('يجب تسجيل الدخول أولاً لعرض الملف الشخصي.');
        return;
      }

      _emailCtrl.text = _user!.email ?? '';

      final doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(_user!.uid)
          .get();

      if (doc.exists) {
        final d = doc.data()!;
        _photoUrl = (d['photoUrl'] ?? '') as String?;
      }

      await _loadCards();

    } catch (e) {
      _snack('تعذر تحميل البيانات: $e');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _deleteCard(String cardId) async {
    if (_user == null) {
      _snack('سجّل الدخول أولاً.');
      return;
    }

    try {
      await FirebaseFirestore.instance
          .collection('users')
          .doc(_user!.uid)
          .collection('cards')
          .doc(cardId)
          .delete();

      await _loadCards();
      setState(() {});
      _snack('تم حذف البطاقة بنجاح.');

    } catch (e) {
      _snack('تعذر حذف البطاقة: $e');
    }
  }

  Future<void> _showDeleteConfirmationDialog(String cardId, String last4Digits) async {
    final bool? confirm = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
          backgroundColor: Colors.white,
          title: Text(
            'Confirm Delete',
            style: TextStyle(color: kTextDark, fontWeight: FontWeight.bold),
          ),
          content: Text(
            'Are you sure you want to delete card ending in $last4Digits?',
            style: TextStyle(color: kTextDark),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false), // Cancel
              child: Text('Cancel', style: TextStyle(color: kPrimary)),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(context, true), // Delete
              style: ElevatedButton.styleFrom(
                backgroundColor: kError,
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              child: Text(
                'Delete',
                style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
              ),
            ),
          ],
        );
      },
    );

    if (confirm == true) {
      await _deleteCard(cardId);
    }
  }

  // ✅ 2. دالة رفع الصورة باستخدام Supabase Storage وفتح المعرض
  Future<void> _pickAndUploadImage() async {
    if (_user == null) {
      _snack('سجّل الدخول أولاً.');
      return;
    }
    try {
      final picker = ImagePicker();
      final x = await picker.pickImage(
        source: ImageSource.gallery, // 👈 هنا يفتح المعرض
        imageQuality: 85,
      );
      if (x == null) return;

      _snack('جاري رفع الصورة...');

      final file = File(x.path);
      // استخدام Supabase client
      final supabase = sb.Supabase.instance.client; // 👈 استخدام sb.Supabase
      final filePath = 'users/${_user!.uid}/avatar_${DateTime.now().millisecondsSinceEpoch}.jpg';

      // رفع الملف إلى باكت "shop-logos"
      await supabase.storage
          .from('shop-logos')
          .upload(filePath, file, fileOptions: const sb.FileOptions(upsert: true)); // 👈 استخدام sb.FileOptions

      // الحصول على رابط الملف العام
      final publicUrl = supabase.storage.from('shop-logos').getPublicUrl(filePath);

      // حفظ الرابط في Firestore
      await FirebaseFirestore.instance
          .collection('users')
          .doc(_user!.uid)
          .set({'photoUrl': publicUrl, 'updatedAt': FieldValue.serverTimestamp()},
          SetOptions(merge: true));

      // تحديث واجهة المستخدم بالرابط الجديد
      if (mounted) {
        setState(() => _photoUrl = publicUrl);
      }
      _snack('تم تحديث الصورة.');
    } catch (e) {
      _snack('تعذر رفع الصورة: $e');
    }
  }
  // ----------------------------------------------------------------

  Future<void> _onSave() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    if (_user == null) {
      _snack('سجّل الدخول أولاً.');
      return;
    }

    setState(() => _saving = true);
    try {
      await FirebaseFirestore.instance
          .collection('users')
          .doc(_user!.uid)
          .set({
        'email': _user!.email,
        'photoUrl': _photoUrl,
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      _snack('تم حفظ الملف الشخصي بنجاح.');

    } catch (e) {
      _snack('تعذر الحفظ: $e');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _showAddCardDialog() async {
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => const AddCardDialog(),
    );
    if (result == true) {
      await _loadCards();
      setState(() {});
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    if (_user == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Profile Settings')),
        body: const Center(
          child: Text('يرجى تسجيل الدخول لعرض الملف الشخصي.'),
        ),
      );
    }

    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Form(
          key: _formKey,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
            children: [
              // ... (Header and Personal Details)
              Row(
                children: [
                  IconButton(
                    tooltip: 'Back',
                    icon: const Icon(Icons.arrow_back_ios_new_rounded),
                    onPressed: () => Navigator.pop(context),
                  ),
                  const Expanded(
                    child: Text(
                      'Profile Settings',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: kTextDark,
                        fontWeight: FontWeight.w700,
                        fontSize: 18,
                      ),
                    ),
                  ),
                  const SizedBox(width: 40),
                ],
              ),
              const SizedBox(height: 8),

              // Avatar with edit
              Center(
                child: Stack(
                  children: [
                    CircleAvatar(
                      radius: 44,
                      backgroundColor: const Color(0xFFE8F7F1),
                      backgroundImage:
                      _photoUrl != null && _photoUrl!.isNotEmpty
                          ? NetworkImage(_photoUrl!)
                          : null,
                      child: (_photoUrl == null || _photoUrl!.isEmpty)
                          ? const Icon(Icons.person, color: kPrimary, size: 48)
                          : null,
                    ),
                    Positioned(
                      right: 0,
                      bottom: 0,
                      child: Material(
                        color: kPrimary,
                        shape: const CircleBorder(),
                        child: InkWell(
                          customBorder: const CircleBorder(),
                          onTap: _pickAndUploadImage,
                          child: const Padding(
                            padding: EdgeInsets.all(6),
                            child: Icon(Icons.edit, size: 16, color: Colors.white),
                          ),
                        ),
                      ),
                    )
                  ],
                ),
              ),
              const SizedBox(height: 18),

              const Text(
                'Personal Details',
                style: TextStyle(
                  color: kTextDark,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 12),

              // Email (read-only from FirebaseAuth)
              TextFormField(
                controller: _emailCtrl,
                readOnly: true,
                decoration: _dec('Email Address',
                    prefix: const Icon(Icons.email_outlined, color: kHint)),
              ),
              const SizedBox(height: 12),

              // Password (not editable here)
              TextFormField(
                controller: _passwordCtrl,
                readOnly: true,
                obscureText: true,
                decoration: _dec('Password',
                    prefix: const Icon(Icons.lock_outline, color: kHint)),
              ),
              Align(
                alignment: Alignment.centerRight,
                child: TextButton(
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const ChangePasswordPage(),
                      ),
                    );
                  },
                  child: const Text(
                    'Change Password',
                    style: TextStyle(
                      color: kPrimary,
                      decoration: TextDecoration.underline,
                    ),
                  ),
                ),
              ),
              const Divider(height: 24),


              // Payment Settings
              const Text(
                'Payment Settings',
                style: TextStyle(
                  color: kTextDark,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 12),

              // عرض البطاقات المحفوظة
              if (_cards.isNotEmpty)
                ..._cards.map((card) {
                  return CardItem(
                    last4: card['last4Digits'] ?? '',
                    onDelete: () {
                      _showDeleteConfirmationDialog(
                        card['id'] as String,
                        card['last4Digits'] ?? '',
                      );
                    },
                  );
                }),

              // زر إضافة بطاقة جديدة
              _AddCardButton(
                onPressed: _showAddCardDialog,
              ),

              const SizedBox(height: 24),

              // زر Save
              SizedBox(
                height: 48,
                child: ElevatedButton(
                  onPressed: _saving ? null : _onSave,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: kPrimary,
                    disabledBackgroundColor: kPrimary.withOpacity(0.6),
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  child: _saving
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
                    'Save',
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
    );
  }
}

// ------------------------------------------------------------------
// CardItem - عنصر البطاقة المحفوظة (مع زر الحذف وتنسيق النجوم)
// ------------------------------------------------------------------
class CardItem extends StatelessWidget {
  final String last4;
  final VoidCallback onDelete;

  static const kTextDark = Color(0xFF222222);
  static const kBorder = Color(0xFFE5E7EB);
  static const kError = Color(0xFFEF4444);

  const CardItem({
    super.key,
    required this.last4,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: kBorder),
        ),
        child: Row(
          children: [
            const Icon(Icons.credit_card_outlined, color: kTextDark),
            const SizedBox(width: 10),
            Text(
              // *التنسيق الجديد: نجوم لتغطية أول 12 رقم وإظهار آخر 4*
              '•••• •••• •••• $last4',
              style: const TextStyle(
                color: kTextDark,
                fontWeight: FontWeight.w600,
                fontSize: 15,
                letterSpacing: 1.5, // إضافة تباعد لتنسيق البطاقة
              ),
            ),
            const Spacer(),

            // زر الحذف
            InkWell(
              onTap: onDelete,
              customBorder: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              child: const Padding(
                padding: EdgeInsets.all(4.0),
                child: Icon(Icons.delete_outline, color: kError, size: 24),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ------------------------------------------------------------------
// _AddCardButton - زر إضافة بطاقة جديدة
// ------------------------------------------------------------------
class _AddCardButton extends StatelessWidget {
  final VoidCallback onPressed;
  static const kPrimary = Color(0xFF34D399);
  static const kBorder = Color(0xFFE5E7EB);

  const _AddCardButton({required this.onPressed});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onPressed,
      borderRadius: BorderRadius.circular(10),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: kBorder),
        ),
        child: Row(
          children: [
            const Icon(Icons.add_circle_outline_rounded, color: kPrimary),
            const SizedBox(width: 10),
            const Text(
              '+ Add New Card',
              style: TextStyle(
                color: kPrimary,
                fontWeight: FontWeight.w600,
                fontSize: 15,
              ),
            ),
          ],
        ),
      ),
    );
  }
}