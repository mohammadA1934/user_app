import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import 'change_password_page.dart';

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

  final _formKey = GlobalKey<FormState>();

  // Controllers
  final _emailCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController(text: '********');
  final _bankAccCtrl = TextEditingController();
  final _holderNameCtrl = TextEditingController();
  final _ibanCtrl = TextEditingController();

  String _selectedBank = 'Arab Bank';
  final _banks = const [
    'Arab Bank',
    'Housing Bank',
    'Cairo Amman Bank',
    'Bank al Etihad',
  ];

  bool _loading = true;
  bool _saving = false;
  String? _photoUrl;
  User? _user;

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  @override
  void dispose() {
    _emailCtrl.dispose();
    _passwordCtrl.dispose();
    _bankAccCtrl.dispose();
    _holderNameCtrl.dispose();
    _ibanCtrl.dispose();
    super.dispose();
  }

  void _snack(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(msg)));
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
        _holderNameCtrl.text = (d['fullName'] ?? d['holderName'] ?? '') as String;
        _bankAccCtrl.text = (d['bankAccount'] ?? '') as String;
        _selectedBank = (d['bankName'] ?? _selectedBank) as String;
        _ibanCtrl.text = (d['iban'] ?? '') as String;
        _photoUrl = (d['photoUrl'] ?? '') as String?;
      }
    } catch (e) {
      _snack('تعذر تحميل البيانات: $e');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _pickAndUploadImage() async {
    if (_user == null) {
      _snack('سجّل الدخول أولاً.');
      return;
    }
    try {
      final picker = ImagePicker();
      final x = await picker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 85,
      );
      if (x == null) return;

      _snack('جاري رفع الصورة...');
      final file = File(x.path);
      final ref =
      FirebaseStorage.instance.ref('users/${_user!.uid}/avatar.jpg');
      await ref.putFile(file);
      final url = await ref.getDownloadURL();

      await FirebaseFirestore.instance
          .collection('users')
          .doc(_user!.uid)
          .set({'photoUrl': url, 'updatedAt': FieldValue.serverTimestamp()},
          SetOptions(merge: true));

      if (mounted) {
        setState(() => _photoUrl = url);
      }
      _snack('تم تحديث الصورة.');
    } catch (e) {
      _snack('تعذر رفع الصورة: $e');
    }
  }

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
        'fullName': _holderNameCtrl.text.trim(),
        'bankAccount': _bankAccCtrl.text.trim(),
        'bankName': _selectedBank,
        'iban': _ibanCtrl.text.trim(),
        'photoUrl': _photoUrl,
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      _snack('تم حفظ الملف الشخصي بنجاح.');
      if (mounted) Navigator.pop(context);
    } catch (e) {
      _snack('تعذر الحفظ: $e');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
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

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    // لو المستخدم غير مسجل
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
              // Header
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

              const Text(
                'Bank Account Details',
                style: TextStyle(
                  color: kTextDark,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 12),

              TextFormField(
                controller: _bankAccCtrl,
                keyboardType: TextInputType.number,
                decoration: _dec('Bank Account Number',
                    prefix: const Icon(Icons.credit_card_outlined, color: kHint)),
                validator: (v) =>
                (v == null || v.trim().isEmpty) ? 'Required' : null,
              ),
              const SizedBox(height: 12),

              TextFormField(
                controller: _holderNameCtrl,
                decoration: _dec("Account Holder's Name",
                    prefix: const Icon(Icons.person_outline, color: kHint)),
                validator: (v) =>
                (v == null || v.trim().isEmpty) ? 'Required' : null,
              ),
              const SizedBox(height: 12),

              InputDecorator(
                decoration: _dec('Bank Branch'),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<String>(
                    isExpanded: true,
                    value: _selectedBank,
                    items: _banks
                        .map((b) => DropdownMenuItem(
                      value: b,
                      child: Text(b),
                    ))
                        .toList(),
                    onChanged: (v) {
                      if (v != null) setState(() => _selectedBank = v);
                    },
                  ),
                ),
              ),
              const SizedBox(height: 12),

              TextFormField(
                controller: _ibanCtrl,
                decoration: _dec('IBAN',
                    prefix: const Icon(Icons.account_balance, color: kHint)),
                validator: (v) =>
                (v == null || v.trim().isEmpty) ? 'Required' : null,
              ),

              const SizedBox(height: 24),

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
