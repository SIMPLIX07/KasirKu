import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';

import 'sales_category_page.dart';
import 'local_image_store.dart';

class BusinessNamePage extends StatefulWidget {
  const BusinessNamePage({super.key});

  @override
  State<BusinessNamePage> createState() => _BusinessNamePageState();
}

class _BusinessNamePageState extends State<BusinessNamePage> {
  static const int _maxBusinessNameLength = 30;
  final _businessNameController = TextEditingController();
  bool _isSaving = false;
  bool _hasQris = false;
  File? _selectedQrisImage;
  String? _existingQrisImageUrl;

  @override
  void dispose() {
    _businessNameController.dispose();
    super.dispose();
  }

  Future<void> _continue() async {
    final businessName = _businessNameController.text.trim().replaceAll(
      RegExp(r'\s+'),
      ' ',
    );
    if (businessName.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Nama bisnis wajib diisi.'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    if (businessName.length < 3) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Nama bisnis minimal 3 karakter.'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    if (businessName.length > _maxBusinessNameLength) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Nama bisnis maksimal 30 karakter.'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Sesi login tidak ditemukan. Silakan login ulang.'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    if (_hasQris &&
        _selectedQrisImage == null &&
        (_existingQrisImageUrl == null || _existingQrisImageUrl!.isEmpty)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Silakan upload gambar QRIS terlebih dahulu.'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    setState(() => _isSaving = true);
    try {
      String? qrisImageUrl = _hasQris ? _existingQrisImageUrl : null;
      if (_hasQris && _selectedQrisImage != null) {
        qrisImageUrl = await _saveQrisImageLocally(
          imageFile: _selectedQrisImage!,
          userId: user.uid,
        );
        if (qrisImageUrl == null || qrisImageUrl.isEmpty) {
          throw FirebaseException(
            plugin: 'cloud_firestore',
            code: 'data-verification-failed',
            message: 'Gagal menyimpan gambar QRIS secara lokal.',
          );
        }
      }

      final userRef = FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid);

      await userRef.set({
        'uid': user.uid,
        'email': user.email,
        'businessName': businessName,
        'qrisEnabled': _hasQris,
        'qrisImageUrl': qrisImageUrl ?? '',
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      // Force server read so we can ensure data is actually persisted.
      final serverSnapshot = await userRef.get(
        const GetOptions(source: Source.server),
      );
      final savedName = serverSnapshot.data()?['businessName'] as String?;
      if (!serverSnapshot.exists || savedName != businessName) {
        throw FirebaseException(
          plugin: 'cloud_firestore',
          code: 'data-verification-failed',
          message: 'Data belum terverifikasi di server Firestore.',
        );
      }

      if (!mounted) {
        return;
      }

      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute<void>(builder: (_) => const SalesCategoryPage()),
        (_) => false,
      );
    } on PlatformException catch (e) {
      if (!mounted) {
        return;
      }

      final raw = (e.message ?? '').toLowerCase();
      final msg = raw.contains('unable to establish connection on channel')
          ? 'Koneksi plugin Firestore belum aktif. Stop app lalu jalankan ulang full restart (bukan hot reload).'
          : (e.message ?? 'Error platform saat akses Firestore.');

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(msg), behavior: SnackBarBehavior.floating),
      );
    } on FirebaseException catch (e) {
      if (!mounted) {
        return;
      }

      String msg;
      switch (e.code) {
        case 'permission-denied':
          msg = 'Akses ditolak Firestore. Periksa Security Rules.';
          break;
        case 'unavailable':
          msg = 'Firestore tidak bisa diakses. Periksa koneksi internet.';
          break;
        case 'unauthenticated':
          msg = 'Sesi login tidak valid. Silakan login ulang.';
          break;
        case 'data-verification-failed':
          msg = e.message ?? 'Data belum tersimpan di server Firestore.';
          break;
        default:
          msg = e.message ?? 'Gagal menyimpan nama usaha.';
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(msg), behavior: SnackBarBehavior.floating),
      );
    } catch (_) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Terjadi kesalahan saat menyimpan data.'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }

  Future<void> _pickQrisImage() async {
    final picker = ImagePicker();
    final image = await picker.pickImage(
      source: ImageSource.gallery,
      maxWidth: 1200,
      imageQuality: 85,
    );

    if (image == null || !mounted) {
      return;
    }

    setState(() {
      _selectedQrisImage = File(image.path);
      _existingQrisImageUrl = null;
    });
  }

  Future<String?> _saveQrisImageLocally({
    required File imageFile,
    required String userId,
  }) async {
    return LocalImageStore.instance.saveImageCopy(
      sourceFile: imageFile,
      ownerId: userId,
      recordType: 'business',
      recordId: 'qris',
      filePrefix: 'qris',
    );
  }

  @override
  Widget build(BuildContext context) {
    const bgColor = Color(0xFFF3F5F4);
    const textMain = Color(0xFF263230);
    const textSecondary = Color(0xFF586260);
    const lineColor = Color(0xFFCED5D2);
    const primary = Color(0xFF126C55);

    return Scaffold(
      backgroundColor: bgColor,
      body: Stack(
        children: [
          Positioned(
            top: 0,
            bottom: 0,
            right: 0,
            child: Container(
              width: MediaQuery.of(context).size.width * 0.45,
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Color(0x16FFFFFF), Color(0x4CF1F4F2)],
                ),
              ),
            ),
          ),
          SafeArea(
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(14, 6, 18, 14),
                  child: Row(
                    children: [
                      IconButton(
                        onPressed: () => Navigator.of(context).maybePop(),
                        icon: const Icon(Icons.arrow_back, color: primary),
                        splashRadius: 22,
                      ),
                      const SizedBox(width: 8),
                      const Text(
                        'Kasirku',
                        style: TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.w700,
                          color: primary,
                        ),
                      ),
                    ],
                  ),
                ),
                const Divider(height: 1, color: lineColor),
                Expanded(
                  child: LayoutBuilder(
                    builder: (context, constraints) {
                      return SingleChildScrollView(
                        padding: const EdgeInsets.fromLTRB(26, 18, 26, 12),
                        child: ConstrainedBox(
                          constraints: BoxConstraints(
                            minHeight: constraints.maxHeight,
                          ),
                          child: Column(
                            children: [
                              const SizedBox(height: 34),
                              Container(
                                width: 110,
                                height: 110,
                                decoration: const BoxDecoration(
                                  color: Color(0xFFE8ECEA),
                                  shape: BoxShape.circle,
                                ),
                                child: const Icon(
                                  Icons.storefront_rounded,
                                  size: 48,
                                  color: primary,
                                ),
                              ),
                              const SizedBox(height: 30),
                              const Text(
                                'Nama Usaha Anda',
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  fontSize: 28,
                                  fontWeight: FontWeight.w800,
                                  color: textMain,
                                ),
                              ),
                              const SizedBox(height: 16),
                              const Text(
                                'Beri tahu kami nama bisnis Anda agar kami bisa menyesuaikan pengalaman Anda.',
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  fontSize: 16,
                                  color: textSecondary,
                                  height: 1.45,
                                ),
                              ),
                              const SizedBox(height: 42),
                              const Align(
                                alignment: Alignment.centerLeft,
                                child: Text(
                                  'NAMA BISNIS',
                                  style: TextStyle(
                                    color: primary,
                                    fontSize: 12,
                                    letterSpacing: 2.6,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ),
                              const SizedBox(height: 12),
                              Container(
                                decoration: BoxDecoration(
                                  color: const Color(0xFFFCFDFC),
                                  borderRadius: BorderRadius.circular(18),
                                ),
                                child: TextField(
                                  controller: _businessNameController,
                                  textInputAction: TextInputAction.done,
                                  maxLength: _maxBusinessNameLength,
                                  style: const TextStyle(
                                    fontSize: 16,
                                    color: textMain,
                                    fontWeight: FontWeight.w500,
                                  ),
                                  decoration: InputDecoration(
                                    hintText: 'Contoh: Kedai Kopi Minimalis',
                                    hintStyle: const TextStyle(
                                      fontSize: 16,
                                      color: Color(0xFFB4BAB7),
                                    ),
                                    border: InputBorder.none,
                                    counterText:
                                        '${_businessNameController.text.trim().replaceAll(RegExp(r'\s+'), ' ').length}/$_maxBusinessNameLength',
                                    contentPadding: const EdgeInsets.symmetric(
                                      horizontal: 22,
                                      vertical: 22,
                                    ),
                                  ),
                                  onChanged: (_) => setState(() {}),
                                ),
                              ),
                              const SizedBox(height: 8),
                              Container(
                                margin: const EdgeInsets.symmetric(
                                  horizontal: 18,
                                ),
                                height: 2,
                                color: lineColor,
                              ),
                              const SizedBox(height: 26),
                              Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  const Expanded(
                                    child: Text(
                                      'MENYEDIAKAN PEMBAYARAN QRIS?',
                                      style: TextStyle(
                                        color: primary,
                                        fontSize: 12,
                                        letterSpacing: 2.2,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                  ),
                                  Switch(
                                    value: _hasQris,
                                    onChanged: _isSaving
                                        ? null
                                        : (value) {
                                            setState(() {
                                              _hasQris = value;
                                              if (!value) {
                                                _selectedQrisImage = null;
                                              }
                                            });
                                          },
                                    activeColor: primary,
                                  ),
                                ],
                              ),
                              AnimatedCrossFade(
                                firstChild: const SizedBox.shrink(),
                                secondChild: Column(
                                  children: [
                                    const SizedBox(height: 14),
                                    Center(
                                      child: GestureDetector(
                                        onTap: _isSaving
                                            ? null
                                            : _pickQrisImage,
                                        child: ConstrainedBox(
                                          constraints: const BoxConstraints(
                                            maxWidth: 340,
                                          ),
                                          child: AspectRatio(
                                            aspectRatio: 1,
                                            child: DecoratedBox(
                                              decoration: BoxDecoration(
                                                color: const Color(0xFFF1F4F2),
                                                borderRadius:
                                                    BorderRadius.circular(26),
                                                border: Border.all(
                                                  color: const Color(
                                                    0xFFBFC8C5,
                                                  ),
                                                  width: 1.4,
                                                ),
                                              ),
                                              child: _selectedQrisImage == null
                                                  ? (_existingQrisImageUrl !=
                                                                null &&
                                                            _existingQrisImageUrl!
                                                                .isNotEmpty
                                                        ? ClipRRect(
                                                            borderRadius:
                                                                BorderRadius.circular(
                                                                  26,
                                                                ),
                                                            child: buildStoredImage(
                                                              _existingQrisImageUrl!,
                                                              fit: BoxFit.cover,
                                                              fallback: () =>
                                                                  const Icon(
                                                                    Icons
                                                                        .qr_code_2,
                                                                    size: 54,
                                                                    color:
                                                                        primary,
                                                                  ),
                                                            ),
                                                          )
                                                        : const Column(
                                                            mainAxisAlignment:
                                                                MainAxisAlignment
                                                                    .center,
                                                            children: [
                                                              Icon(
                                                                Icons.qr_code_2,
                                                                size: 54,
                                                                color: primary,
                                                              ),
                                                              SizedBox(
                                                                height: 12,
                                                              ),
                                                              Text(
                                                                'Upload Gambar QRIS',
                                                                style: TextStyle(
                                                                  fontSize: 18,
                                                                  fontWeight:
                                                                      FontWeight
                                                                          .w700,
                                                                  color:
                                                                      textMain,
                                                                ),
                                                              ),
                                                            ],
                                                          ))
                                                  : ClipRRect(
                                                      borderRadius:
                                                          BorderRadius.circular(
                                                            26,
                                                          ),
                                                      child: Image.file(
                                                        _selectedQrisImage!,
                                                        fit: BoxFit.cover,
                                                      ),
                                                    ),
                                            ),
                                          ),
                                        ),
                                      ),
                                    ),
                                    const SizedBox(height: 10),
                                    const Center(
                                      child: Text(
                                        'Gambar QRIS akan dipakai saat pembayaran QRIS.',
                                        textAlign: TextAlign.center,
                                        style: TextStyle(
                                          color: textSecondary,
                                          fontSize: 13,
                                          height: 1.35,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                crossFadeState: _hasQris
                                    ? CrossFadeState.showSecond
                                    : CrossFadeState.showFirst,
                                duration: const Duration(milliseconds: 180),
                              ),
                              const SizedBox(height: 24),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
      bottomNavigationBar: Padding(
        padding: const EdgeInsets.fromLTRB(22, 0, 22, 20),
        child: Container(
          decoration: BoxDecoration(
            color: const Color(0xFFF8FAF8),
            borderRadius: BorderRadius.circular(24),
            boxShadow: const [
              BoxShadow(
                color: Color(0x14000000),
                blurRadius: 30,
                offset: Offset(0, 10),
              ),
            ],
          ),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: ElevatedButton(
              onPressed: _isSaving ? null : _continue,
              style: ElevatedButton.styleFrom(
                backgroundColor: primary,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(18),
                ),
                padding: const EdgeInsets.symmetric(vertical: 20),
                elevation: 0,
              ),
              child: _isSaving
                  ? const SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(
                        strokeWidth: 2.2,
                        color: Colors.white,
                      ),
                    )
                  : const Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          'Lanjut',
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        SizedBox(width: 10),
                        Icon(Icons.arrow_forward, size: 28),
                      ],
                    ),
            ),
          ),
        ),
      ),
    );
  }
}
