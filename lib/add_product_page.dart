import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';

class AddProductPage extends StatefulWidget {
  const AddProductPage({
    super.key,
    required this.categoryId,
    required this.categoryName,
    this.productId,
    this.initialName,
    this.initialPrice,
    this.initialTags,
    this.initialImageUrl,
    this.initialIconName,
  });

  final String categoryId;
  final String categoryName;
  final String? productId;
  final String? initialName;
  final int? initialPrice;
  final List<String>? initialTags;
  final String? initialImageUrl;
  final String? initialIconName;

  @override
  State<AddProductPage> createState() => _AddProductPageState();
}

class _AddProductPageState extends State<AddProductPage> {
  final _nameController = TextEditingController();
  final _priceController = TextEditingController();
  late Future<List<String>> _categoryCategoryTagsFuture;
  final List<String> _tags = <String>[];
  bool _isSaving = false;
  File? _selectedImage;
  String? _existingImageUrl;
  late IconData _selectedIcon;
  static const int _maxTags = 3;

  bool get _isEditMode =>
      widget.productId != null && widget.productId!.trim().isNotEmpty;

  static const List<IconData> _productIcons = <IconData>[
    Icons.fastfood,
    Icons.coffee,
    Icons.icecream,
    Icons.local_pizza,
    Icons.bakery_dining,
  ];

  @override
  void initState() {
    super.initState();
    _nameController.text = widget.initialName?.trim() ?? '';
    if (widget.initialPrice != null && widget.initialPrice! > 0) {
      _priceController.text = widget.initialPrice.toString();
    }

    _tags
      ..clear()
      ..addAll((widget.initialTags ?? <String>[]).take(_maxTags));

    _existingImageUrl = widget.initialImageUrl?.trim();
    _selectedIcon = _getProductIconFromName(widget.initialIconName ?? '');
    _categoryCategoryTagsFuture = _fetchCategoryTags();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _priceController.dispose();
    super.dispose();
  }

  Future<List<String>> _fetchCategoryTags() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return [];

      final productsSnapshot = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .collection('products')
          .where('categoryId', isEqualTo: widget.categoryId)
          .get();

      final tagsSet = <String>{};
      for (final doc in productsSnapshot.docs) {
        final tags =
            (doc.data()['tags'] as List<dynamic>?)?.cast<String>() ?? [];
        tagsSet.addAll(tags);
      }

      final tagsList = tagsSet.toList()..sort();

      debugPrint(
        '[CATEGORY_TAGS_LOADED] categoryId=${widget.categoryId} count=${tagsList.length} tags=$tagsList',
      );
      return tagsList;
    } catch (e) {
      debugPrint('[FETCH_CATEGORY_TAGS_ERROR] $e');
      return [];
    }
  }

  Future<void> _pickProductImage() async {
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
      _selectedImage = File(image.path);
      _existingImageUrl = null;
    });
  }

  Future<void> _addTag() async {
    try {
      if (_tags.length >= _maxTags) {
        _showMessage('Maksimal $_maxTags tag per produk.');
        return;
      }

      final categoryTags = await _fetchCategoryTags();
      if (!mounted) {
        return;
      }

      final existingLower = _tags.map((tag) => tag.toLowerCase()).toSet();
      final availableTags = categoryTags
          .where((tag) => !existingLower.contains(tag.toLowerCase()))
          .toList();

      String enteredTag = '';
      String? dialogError;

      final value = await showDialog<String>(
        context: context,
        builder: (dialogContext) {
          return StatefulBuilder(
            builder: (context, setDialogState) {
              String normalize(String raw) =>
                  raw.trim().replaceAll(RegExp(r'\s+'), ' ');

              void submitFromInput() {
                final normalized = normalize(enteredTag);
                if (normalized.isEmpty) {
                  if (!dialogContext.mounted) return;
                  setDialogState(() {
                    dialogError = 'Tag tidak boleh kosong.';
                  });
                  return;
                }
                if (!dialogContext.mounted) return;
                Navigator.of(dialogContext).pop(normalized);
              }

              return AlertDialog(
                title: const Text('Tambah Tag'),
                content: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Pilih tag yang sudah ada atau tambah tag baru.',
                        style: TextStyle(
                          fontSize: 13,
                          color: Color(0xFF6F7875),
                        ),
                      ),
                      if (availableTags.isNotEmpty) ...[
                        const SizedBox(height: 12),
                        SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          child: Row(
                            children: availableTags
                                .map(
                                  (tag) => Padding(
                                    padding: const EdgeInsets.only(right: 8),
                                    child: ActionChip(
                                      label: Text(tag),
                                      onPressed: () {
                                        if (!dialogContext.mounted) return;
                                        Navigator.of(dialogContext).pop(tag);
                                      },
                                      shape: const StadiumBorder(),
                                      side: const BorderSide(
                                        color: Color(0xFFD0D9D5),
                                      ),
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 12,
                                        vertical: 6,
                                      ),
                                    ),
                                  ),
                                )
                                .toList(),
                          ),
                        ),
                      ],
                      const SizedBox(height: 12),
                      TextField(
                        autofocus: true,
                        maxLength: 20,
                        textInputAction: TextInputAction.done,
                        onChanged: (text) {
                          enteredTag = text;
                          if (dialogError != null) {
                            setDialogState(() {
                              dialogError = null;
                            });
                          }
                        },
                        onSubmitted: (_) => submitFromInput(),
                        decoration: InputDecoration(
                          hintText: 'Contoh: Gurih',
                          counterText: '',
                          errorText: dialogError,
                        ),
                      ),
                    ],
                  ),
                ),
                actions: [
                  TextButton(
                    onPressed: () {
                      if (!dialogContext.mounted) return;
                      Navigator.of(dialogContext).pop();
                    },
                    child: const Text('Batal'),
                  ),
                  FilledButton(
                    onPressed: submitFromInput,
                    child: const Text('Tambah'),
                  ),
                ],
              );
            },
          );
        },
      );

      if (!mounted || value == null) {
        return;
      }

      final normalizedTag = value.trim().replaceAll(RegExp(r'\s+'), ' ');
      if (normalizedTag.isEmpty) {
        return;
      }

      final alreadyExists = _tags.any(
        (tag) => tag.toLowerCase() == normalizedTag.toLowerCase(),
      );
      if (alreadyExists) {
        _showMessage('Tag sudah ada.');
        return;
      }

      if (_tags.length >= _maxTags) {
        _showMessage('Maksimal $_maxTags tag per produk.');
        return;
      }

      setState(() {
        _tags.add(normalizedTag);
      });
    } catch (e) {
      debugPrint('[ADD_TAG_ERROR] $e');
      _showMessage('Gagal menambahkan tag. Coba lagi.');
    }
  }

  Future<void> _saveAndFinish() async {
    if (_isSaving) {
      return;
    }

    if (widget.categoryId.trim().isEmpty) {
      _showMessage('Kategori tidak valid. Silakan pilih ulang kategori.');
      return;
    }

    final productName = _nameController.text.trim().replaceAll(
      RegExp(r'\s+'),
      ' ',
    );
    if (productName.isEmpty) {
      _showMessage('Nama produk wajib diisi.');
      return;
    }

    final priceOnlyDigits = _priceController.text.replaceAll(
      RegExp(r'[^0-9]'),
      '',
    );
    final price = int.tryParse(priceOnlyDigits);
    if (price == null || price <= 0) {
      _showMessage('Harga produk wajib diisi dan harus lebih dari 0.');
      return;
    }

    final normalizedTags = _tags
        .map((tag) => tag.trim().replaceAll(RegExp(r'\s+'), ' '))
        .where((tag) => tag.isNotEmpty)
        .toSet()
        .toList();
    if (normalizedTags.length > _maxTags) {
      _showMessage('Maksimal $_maxTags tag per produk.');
      return;
    }

    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      _showMessage('Sesi login tidak ditemukan. Silakan login ulang.');
      return;
    }

    setState(() => _isSaving = true);

    try {
      String? imageUrl;
      if (_selectedImage != null) {
        imageUrl = await _uploadProductImageToStorage(
          imageFile: _selectedImage!,
          userId: user.uid,
        );
      }

      final cleanedTags = normalizedTags;

      final iconName = _getProductIconName(_selectedIcon);
      final productsRef = FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .collection('products');
      final docRef = _isEditMode
          ? productsRef.doc(widget.productId!.trim())
          : productsRef.doc();

      final payload = <String, dynamic>{
        'id': docRef.id,
        'name': productName,
        'price': price,
        'categoryId': widget.categoryId,
        'categoryName': widget.categoryName,
        'tags': cleanedTags,
        'imageUrl': imageUrl ?? _existingImageUrl,
        'icon': iconName,
        'updatedAt': FieldValue.serverTimestamp(),
      };

      if (!_isEditMode) {
        payload['createdAt'] = FieldValue.serverTimestamp();
      }

      await docRef.set(payload, SetOptions(merge: true));

      debugPrint(
        '[PRODUCT_SAVE_OK] uid=${user.uid} docId=${docRef.id} categoryId=${widget.categoryId}',
      );

      if (!mounted) {
        return;
      }

      _showMessage(
        _isEditMode
            ? 'Produk $productName berhasil diperbarui.'
            : 'Produk $productName berhasil disimpan.',
      );
      if (Navigator.of(context).canPop()) {
        Navigator.of(context).pop(true);
      }
    } on FirebaseException catch (e) {
      debugPrint('[PRODUCT_SAVE_ERROR] code=${e.code} message=${e.message}');
      if (!mounted) {
        return;
      }

      String errorMessage;
      switch (e.code) {
        case 'permission-denied':
          errorMessage = 'Akses Firestore ditolak. Periksa Security Rules.';
          break;
        case 'unavailable':
          errorMessage =
              'Firestore tidak bisa diakses. Periksa koneksi internet.';
          break;
        case 'unauthenticated':
          errorMessage = 'Sesi login tidak valid. Silakan login ulang.';
          break;
        default:
          errorMessage = e.message ?? 'Gagal menyimpan produk.';
      }
      _showMessage(errorMessage);
    } catch (e) {
      debugPrint('[PRODUCT_SAVE_ERROR] $e');
      if (!mounted) {
        return;
      }
      _showMessage('Terjadi kesalahan saat menyimpan produk.');
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }

  Future<String?> _uploadProductImageToStorage({
    required File imageFile,
    required String userId,
  }) async {
    try {
      final fileName =
          '${widget.categoryId}_${DateTime.now().millisecondsSinceEpoch}.jpg';
      final ref = FirebaseStorage.instance.ref().child(
        'products/$userId/$fileName',
      );

      await ref.putFile(imageFile);
      final url = await ref.getDownloadURL();
      debugPrint('[PRODUCT_IMAGE_UPLOAD_OK] path=products/$userId/$fileName');
      return url;
    } catch (e) {
      debugPrint('[PRODUCT_IMAGE_UPLOAD_ERROR] $e');
      return null;
    }
  }

  void _showMessage(String message) {
    if (!mounted) {
      return;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), behavior: SnackBarBehavior.floating),
    );
  }

  String _getProductIconName(IconData icon) {
    final iconNames = [
      'fastfood',
      'coffee',
      'icecream',
      'local_pizza',
      'bakery_dining',
    ];
    for (int i = 0; i < _productIcons.length; i++) {
      if (_productIcons[i] == icon) {
        return iconNames[i];
      }
    }
    return 'fastfood';
  }

  IconData _getProductIconFromName(String iconName) {
    switch (iconName) {
      case 'coffee':
        return Icons.coffee;
      case 'icecream':
        return Icons.icecream;
      case 'local_pizza':
        return Icons.local_pizza;
      case 'bakery_dining':
        return Icons.bakery_dining;
      case 'fastfood':
      default:
        return Icons.fastfood;
    }
  }

  @override
  Widget build(BuildContext context) {
    const bg = Color(0xFFF8FAF8);
    const line = Color(0xFFE4E9E7);
    const textMain = Color(0xFF2D3432);
    const textMuted = Color(0xFF8F9895);
    const primary = Color(0xFF126C55);
    const uploadSurface = Color(0xFFF1F4F2);

    return Scaffold(
      backgroundColor: bg,
      body: Column(
        children: [
          SafeArea(
            bottom: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(10, 10, 14, 12),
              child: Row(
                children: [
                  IconButton(
                    onPressed: () => Navigator.of(context).maybePop(),
                    icon: const Icon(
                      Icons.arrow_back,
                      color: Color(0xFF3E8E75),
                    ),
                    splashRadius: 22,
                  ),
                  const SizedBox(width: 8),
                  const Expanded(
                    child: Text(
                      'Kasirku',
                      style: TextStyle(
                        fontSize: 46 / 2,
                        fontWeight: FontWeight.w700,
                        color: primary,
                      ),
                    ),
                  ),
                  TextButton(
                    onPressed: _isSaving ? null : _saveAndFinish,
                    child: const Text(
                      'Lanjut',
                      style: TextStyle(
                        color: primary,
                        fontSize: 18,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const Divider(height: 1, color: line),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(42, 28, 42, 170),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _isEditMode ? 'Edit Produk' : 'Tambah Produk Pertama',
                    style: const TextStyle(
                      fontSize: 26,
                      fontWeight: FontWeight.w800,
                      color: textMain,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    _isEditMode
                        ? 'Perbarui detail produk Anda.'
                        : 'Lengkapi detail produk Anda agar bisa\nlangsung berjualan.',
                    style: const TextStyle(
                      fontSize: 16,
                      color: textMuted,
                      height: 1.45,
                    ),
                  ),
                  const SizedBox(height: 32),
                  const _FieldLabel(text: 'PILIH ICON PRODUK'),
                  const SizedBox(height: 14),
                  Row(
                    children: _productIcons.map((iconData) {
                      final selected = _selectedIcon == iconData;
                      return Expanded(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 3),
                          child: InkWell(
                            onTap: _isSaving
                                ? null
                                : () =>
                                      setState(() => _selectedIcon = iconData),
                            borderRadius: BorderRadius.circular(16),
                            child: Container(
                              height: 66,
                              decoration: BoxDecoration(
                                color: selected
                                    ? const Color(0xFFA2F3D5)
                                    : const Color(0xFFF1F4F2),
                                borderRadius: BorderRadius.circular(16),
                              ),
                              child: Icon(
                                iconData,
                                size: 30,
                                color: const Color(0xFF005F49),
                              ),
                            ),
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 32),
                  const _FieldLabel(text: 'FOTO PRODUK (Opsional)'),
                  const SizedBox(height: 14),
                  Center(
                    child: GestureDetector(
                      onTap: _isSaving ? null : _pickProductImage,
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 340),
                        child: AspectRatio(
                          aspectRatio: 1,
                          child: DecoratedBox(
                            decoration: BoxDecoration(
                              color: uploadSurface,
                              borderRadius: BorderRadius.circular(26),
                            ),
                            child: _selectedImage == null
                                ? (_existingImageUrl != null &&
                                          _existingImageUrl!.isNotEmpty
                                      ? ClipRRect(
                                          borderRadius: BorderRadius.circular(
                                            26,
                                          ),
                                          child: Image.network(
                                            _existingImageUrl!,
                                            fit: BoxFit.cover,
                                            errorBuilder: (_, __, ___) => Stack(
                                              children: [
                                                Positioned.fill(
                                                  child: DecoratedBox(
                                                    decoration: BoxDecoration(
                                                      borderRadius:
                                                          BorderRadius.circular(
                                                            26,
                                                          ),
                                                      gradient: LinearGradient(
                                                        begin:
                                                            Alignment.topCenter,
                                                        end: Alignment
                                                            .bottomCenter,
                                                        colors: [
                                                          Colors.white
                                                              .withValues(
                                                                alpha: 0.46,
                                                              ),
                                                          Colors.transparent,
                                                          Colors.white
                                                              .withValues(
                                                                alpha: 0.42,
                                                              ),
                                                        ],
                                                      ),
                                                    ),
                                                  ),
                                                ),
                                                const Center(
                                                  child: Column(
                                                    mainAxisSize:
                                                        MainAxisSize.min,
                                                    children: [
                                                      Icon(
                                                        Icons
                                                            .add_a_photo_outlined,
                                                        color: primary,
                                                        size: 52,
                                                      ),
                                                      SizedBox(height: 14),
                                                      Text(
                                                        'UPLOAD FOTO',
                                                        style: TextStyle(
                                                          color: Color(
                                                            0xFF5C9D8B,
                                                          ),
                                                          fontSize: 18,
                                                          fontWeight:
                                                              FontWeight.w700,
                                                          letterSpacing: 2,
                                                        ),
                                                      ),
                                                    ],
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                        )
                                      : Stack(
                                          children: [
                                            Positioned.fill(
                                              child: DecoratedBox(
                                                decoration: BoxDecoration(
                                                  borderRadius:
                                                      BorderRadius.circular(26),
                                                  gradient: LinearGradient(
                                                    begin: Alignment.topCenter,
                                                    end: Alignment.bottomCenter,
                                                    colors: [
                                                      Colors.white.withValues(
                                                        alpha: 0.46,
                                                      ),
                                                      Colors.transparent,
                                                      Colors.white.withValues(
                                                        alpha: 0.42,
                                                      ),
                                                    ],
                                                  ),
                                                ),
                                              ),
                                            ),
                                            const Center(
                                              child: Column(
                                                mainAxisSize: MainAxisSize.min,
                                                children: [
                                                  Icon(
                                                    Icons.add_a_photo_outlined,
                                                    color: primary,
                                                    size: 52,
                                                  ),
                                                  SizedBox(height: 14),
                                                  Text(
                                                    'UPLOAD FOTO',
                                                    style: TextStyle(
                                                      color: Color(0xFF5C9D8B),
                                                      fontSize: 18,
                                                      fontWeight:
                                                          FontWeight.w700,
                                                      letterSpacing: 2,
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ),
                                          ],
                                        ))
                                : ClipRRect(
                                    borderRadius: BorderRadius.circular(26),
                                    child: Image.file(
                                      _selectedImage!,
                                      fit: BoxFit.cover,
                                    ),
                                  ),
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 14),
                  const Center(
                    child: Text(
                      'Rekomendasi: JPG 512x512px atau lebih',
                      style: TextStyle(
                        color: Color(0xFF8E9794),
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                  const SizedBox(height: 32),
                  const _FieldLabel(text: 'NAMA PRODUK'),
                  TextField(
                    controller: _nameController,
                    enabled: !_isSaving,
                    textInputAction: TextInputAction.next,
                    decoration: const InputDecoration(
                      hintText: 'Contoh: Es Kopi Susu Aren',
                      hintStyle: TextStyle(
                        color: Color(0xFFC0C7C4),
                        fontSize: 20,
                      ),
                      border: UnderlineInputBorder(
                        borderSide: BorderSide(color: line),
                      ),
                      enabledBorder: UnderlineInputBorder(
                        borderSide: BorderSide(color: line),
                      ),
                      focusedBorder: UnderlineInputBorder(
                        borderSide: BorderSide(color: primary, width: 1.3),
                      ),
                    ),
                    style: const TextStyle(fontSize: 20, color: textMain),
                  ),
                  const SizedBox(height: 34),
                  const _FieldLabel(text: 'HARGA PRODUK'),
                  Row(
                    children: [
                      const Padding(
                        padding: EdgeInsets.only(top: 6),
                        child: Text(
                          'Rp',
                          style: TextStyle(
                            color: Color(0xFFAAB1AE),
                            fontSize: 44 / 2,
                          ),
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: TextField(
                          controller: _priceController,
                          enabled: !_isSaving,
                          keyboardType: TextInputType.number,
                          inputFormatters: [
                            FilteringTextInputFormatter.digitsOnly,
                          ],
                          decoration: const InputDecoration(
                            hintText: '0',
                            hintStyle: TextStyle(
                              color: Color(0xFFC0C7C4),
                              fontSize: 20,
                            ),
                            border: UnderlineInputBorder(
                              borderSide: BorderSide(color: line),
                            ),
                            enabledBorder: UnderlineInputBorder(
                              borderSide: BorderSide(color: line),
                            ),
                            focusedBorder: UnderlineInputBorder(
                              borderSide: BorderSide(
                                color: primary,
                                width: 1.3,
                              ),
                            ),
                          ),
                          style: const TextStyle(fontSize: 20, color: textMain),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 34),
                  const _FieldLabel(text: 'TAG PRODUK'),
                  const SizedBox(height: 12),
                  Text(
                    'Maksimal $_maxTags tag',
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                      color: Color(0xFF8F9895),
                    ),
                  ),
                  const SizedBox(height: 10),
                  FutureBuilder<List<String>>(
                    future: _categoryCategoryTagsFuture,
                    builder: (context, snapshot) {
                      if (snapshot.connectionState == ConnectionState.waiting) {
                        return const SizedBox(
                          height: 40,
                          child: Center(
                            child: SizedBox(
                              width: 24,
                              height: 24,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            ),
                          ),
                        );
                      }

                      return SizedBox(
                        height: 56,
                        child: ListView(
                          scrollDirection: Axis.horizontal,
                          children: [
                            ..._tags.map(
                              (tag) => Padding(
                                padding: const EdgeInsets.only(right: 10),
                                child: InputChip(
                                  label: Text(tag),
                                  selected: false,
                                  onPressed: _isSaving ? null : () {},
                                  onDeleted: _isSaving
                                      ? null
                                      : () {
                                          setState(() {
                                            _tags.remove(tag);
                                          });
                                        },
                                  deleteIconColor: const Color(0xFF7F8885),
                                  labelStyle: const TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.w600,
                                    color: primary,
                                  ),
                                  side: BorderSide.none,
                                  backgroundColor: const Color(0xFFF0F3F1),
                                  shape: const StadiumBorder(),
                                  materialTapTargetSize:
                                      MaterialTapTargetSize.shrinkWrap,
                                  visualDensity: VisualDensity.compact,
                                  labelPadding: const EdgeInsets.symmetric(
                                    horizontal: 8,
                                  ),
                                ),
                              ),
                            ),
                            ActionChip(
                              onPressed: _isSaving ? null : _addTag,
                              avatar: const Icon(
                                Icons.add,
                                color: primary,
                                size: 22,
                              ),
                              label: const Text(
                                'Tambah Tag',
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.w600,
                                  color: primary,
                                ),
                              ),
                              side: const BorderSide(
                                color: Color(0xFFACCEC3),
                                width: 1.4,
                              ),
                              backgroundColor: const Color(0xFFF1F7F5),
                              shape: const StadiumBorder(),
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 10,
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
      bottomNavigationBar: Container(
        padding: const EdgeInsets.fromLTRB(24, 14, 24, 24),
        decoration: const BoxDecoration(
          color: Color(0xCCF8FAF8),
          border: Border(top: BorderSide(color: Color(0x1A757C7A))),
        ),
        child: SafeArea(
          top: false,
          child: SizedBox(
            height: 76,
            child: DecoratedBox(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(20),
                gradient: const LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Color(0xFF126C55), Color(0xFF005F49)],
                ),
                boxShadow: const [
                  BoxShadow(
                    color: Color(0x29126C55),
                    blurRadius: 14,
                    offset: Offset(0, 6),
                  ),
                ],
              ),
              child: ElevatedButton(
                onPressed: _isSaving ? null : _saveAndFinish,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.transparent,
                  disabledBackgroundColor: Colors.transparent,
                  shadowColor: Colors.transparent,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20),
                  ),
                ),
                child: _isSaving
                    ? const SizedBox(
                        width: 24,
                        height: 24,
                        child: CircularProgressIndicator(
                          strokeWidth: 2.3,
                          color: Color(0xFFE4FFF2),
                        ),
                      )
                    : const Text(
                        'Simpan & Selesai',
                        style: TextStyle(
                          color: Color(0xFFE4FFF2),
                          fontSize: 24 / 2,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 0.4,
                        ),
                      ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _FieldLabel extends StatelessWidget {
  const _FieldLabel({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: const TextStyle(
        color: Color(0xFF929996),
        fontSize: 14,
        fontWeight: FontWeight.w700,
        letterSpacing: 3.2,
      ),
    );
  }
}
