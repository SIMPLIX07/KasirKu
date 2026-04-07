import 'package:flutter/material.dart';
import 'dart:ui';
import 'dart:io';
import 'package:image_picker/image_picker.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';

import 'add_product_page.dart';
import 'home_page.dart';

class _CategoryItem {
  const _CategoryItem({
    required this.id,
    required this.name,
    required this.iconName,
    this.imageUrl,
    this.productCount = 0,
  });

  final String id;
  final String name;
  final String iconName;
  final String? imageUrl;
  final int productCount;
}

class SalesCategoryPage extends StatefulWidget {
  const SalesCategoryPage({super.key});

  @override
  State<SalesCategoryPage> createState() => _SalesCategoryPageState();
}

class _SalesCategoryPageState extends State<SalesCategoryPage> {
  final List<_CategoryItem> _categories = <_CategoryItem>[];
  final TextEditingController _categoryNameController = TextEditingController();
  bool _isLoadingCategories = true;
  String? _selectedCategoryId;
  static const List<IconData> _categoryIcons = <IconData>[
    Icons.restaurant,
    Icons.local_bar,
    Icons.fastfood,
    Icons.icecream,
    Icons.bakery_dining,
  ];

  @override
  void initState() {
    super.initState();
    _loadCategories();
  }

  @override
  void dispose() {
    _categoryNameController.dispose();
    super.dispose();
  }

  String _safeStorageName(String raw) {
    final collapsed = raw.trim().toLowerCase().replaceAll(RegExp(r'\s+'), '_');
    final sanitized = collapsed
        .replaceAll(RegExp(r'[^a-z0-9_-]'), '_')
        .replaceAll(RegExp(r'_+'), '_')
        .replaceAll(RegExp(r'^_|_$'), '');
    return sanitized.isEmpty ? 'category' : sanitized;
  }

  Future<void> _loadCategories() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      if (!mounted) {
        return;
      }
      setState(() => _isLoadingCategories = false);
      return;
    }

    try {
      final snapshot = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .collection('categories')
          .get();

      final items = <_CategoryItem>[];
      final seenNames = <String>{};

      for (final doc in snapshot.docs) {
        final data = doc.data();
        final rawName = (data['name'] as String? ?? '').trim().replaceAll(
          RegExp(r'\s+'),
          ' ',
        );

        if (rawName.isEmpty) {
          continue;
        }

        final normalized = rawName.toLowerCase();
        if (seenNames.contains(normalized)) {
          continue;
        }
        seenNames.add(normalized);

        final savedId = data['id'] as String?;
        final savedIcon = (data['icon'] as String? ?? '').trim();
        final rawImageUrl = (data['imageUrl'] as String? ?? '').trim();

        // Fetch product count for this category
        final categoryId = (savedId != null && savedId.isNotEmpty)
            ? savedId
            : doc.id;
        int productCount = 0;
        try {
          final productSnapshot = await FirebaseFirestore.instance
              .collection('users')
              .doc(user.uid)
              .collection('products')
              .where('categoryId', isEqualTo: categoryId)
              .count()
              .get();
          productCount = productSnapshot.count ?? 0;
        } catch (e) {
          debugPrint('[PRODUCT_COUNT_ERROR] categoryId=$categoryId error=$e');
        }

        items.add(
          _CategoryItem(
            id: categoryId,
            name: rawName,
            iconName: savedIcon.isEmpty ? 'restaurant' : savedIcon,
            imageUrl: rawImageUrl.isEmpty ? null : rawImageUrl,
            productCount: productCount,
          ),
        );
      }

      if (!mounted) {
        return;
      }

      setState(() {
        _categories
          ..clear()
          ..addAll(items);
        if (_categories.isEmpty) {
          _selectedCategoryId = null;
        } else {
          final hasSelected =
              _selectedCategoryId != null &&
              _categories.any((item) => item.id == _selectedCategoryId);
          _selectedCategoryId = hasSelected
              ? _selectedCategoryId
              : _categories.first.id;
        }
        _isLoadingCategories = false;
      });
    } catch (e) {
      debugPrint('[CATEGORY_LOAD_ERROR] $e');
      if (!mounted) {
        return;
      }
      setState(() => _isLoadingCategories = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Gagal memuat kategori.'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  Future<void> _showAddCategoryDialog() async {
    final controller = _categoryNameController;
    controller.clear();
    IconData selectedIcon = _categoryIcons.first;
    String? errorText;
    File? selectedImage;
    bool isSavingCategory = false;

    Future<void> pickImage() async {
      try {
        final ImagePicker picker = ImagePicker();
        final XFile? image = await picker.pickImage(
          source: ImageSource.gallery,
          maxWidth: 512,
          maxHeight: 512,
        );

        if (image != null) {
          selectedImage = File(image.path);
        }
      } catch (e, st) {
        debugPrint('[CATEGORY_PICK_IMAGE_ERROR] $e');
        debugPrint('$st');
      }
    }

    Future<void> submitCategory(
      BuildContext modalContext,
      StateSetter setModalState,
    ) async {
      if (isSavingCategory) {
        return;
      }

      final normalized = controller.text.trim().replaceAll(RegExp(r'\s+'), ' ');
      if (normalized.isEmpty) {
        setModalState(() => errorText = 'Jenis produk wajib diisi.');
        return;
      }

      final exists = _categories.any(
        (item) => item.name.toLowerCase() == normalized.toLowerCase(),
      );
      if (exists) {
        setModalState(() => errorText = 'Kategori sudah ada.');
        return;
      }

      setModalState(() {
        errorText = null;
        isSavingCategory = true;
      });

      try {
        final saved = await _saveCategoryToFirestore(
          normalized,
          selectedIcon,
          selectedImage,
        );

        if (saved != null) {
          if (modalContext.mounted) {
            Navigator.of(modalContext, rootNavigator: true).pop(saved);
          }
          return;
        }

        if (modalContext.mounted) {
          setModalState(() {
            isSavingCategory = false;
            errorText = 'Gagal simpan kategori. Coba lagi.';
          });
        }
      } catch (e, st) {
        debugPrint('[CATEGORY_SUBMIT_ERROR] $e');
        debugPrint('$st');
        if (modalContext.mounted) {
          setModalState(() {
            isSavingCategory = false;
            errorText = 'Terjadi error saat menyimpan kategori.';
          });
        }
      }
    }

    final savedCategory = await showDialog<_CategoryItem>(
      context: context,
      barrierDismissible: false,
      builder: (_) {
        return StatefulBuilder(
          builder: (modalContext, setModalState) {
            return Material(
              type: MaterialType.transparency,
              child: Stack(
                children: [
                  Positioned.fill(
                    child: BackdropFilter(
                      filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
                      child: Container(color: const Color(0x332D3432)),
                    ),
                  ),
                  SafeArea(
                    child: AnimatedPadding(
                      duration: const Duration(milliseconds: 180),
                      curve: Curves.easeOut,
                      padding: EdgeInsets.only(
                        bottom: MediaQuery.of(modalContext).viewInsets.bottom,
                      ),
                      child: Center(
                        child: SingleChildScrollView(
                          padding: const EdgeInsets.all(16),
                          child: Material(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(28),
                            elevation: 8,
                            child: Container(
                              width: 560,
                              padding: const EdgeInsets.fromLTRB(
                                20,
                                20,
                                20,
                                18,
                              ),
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      const Expanded(
                                        child: Text(
                                          'Tambah Kategori Baru',
                                          style: TextStyle(
                                            fontSize: 24,
                                            fontWeight: FontWeight.w800,
                                            color: Color(0xFF1F2A28),
                                          ),
                                        ),
                                      ),
                                      IconButton(
                                        onPressed: isSavingCategory
                                            ? null
                                            : () => Navigator.of(
                                                modalContext,
                                              ).pop(),
                                        icon: const Icon(Icons.close),
                                        color: const Color(0xFF5C6663),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 10),
                                  Center(
                                    child: GestureDetector(
                                      onTap: () async {
                                        if (isSavingCategory) {
                                          return;
                                        }
                                        await pickImage();
                                        if (modalContext.mounted) {
                                          setModalState(() {});
                                        }
                                      },
                                      child: Container(
                                        width: 210,
                                        height: 210,
                                        decoration: BoxDecoration(
                                          color: const Color(0xFFF1F4F2),
                                          borderRadius: BorderRadius.circular(
                                            28,
                                          ),
                                        ),
                                        child: Center(
                                          child: Container(
                                            width: 150,
                                            height: 150,
                                            decoration: BoxDecoration(
                                              color: const Color(0xFFF8FAF8),
                                              borderRadius:
                                                  BorderRadius.circular(24),
                                              border: Border.all(
                                                color: const Color(0x66ACB4B1),
                                                width: 2,
                                              ),
                                            ),
                                            child: selectedImage != null
                                                ? ClipRRect(
                                                    borderRadius:
                                                        BorderRadius.circular(
                                                          20,
                                                        ),
                                                    child: Image.file(
                                                      selectedImage!,
                                                      fit: BoxFit.cover,
                                                    ),
                                                  )
                                                : Column(
                                                    mainAxisAlignment:
                                                        MainAxisAlignment
                                                            .center,
                                                    children: const [
                                                      Icon(
                                                        Icons.image,
                                                        color: Color(
                                                          0xFF005F49,
                                                        ),
                                                        size: 34,
                                                      ),
                                                      SizedBox(height: 8),
                                                      Text(
                                                        'UPLOAD ICON',
                                                        style: TextStyle(
                                                          color: Color(
                                                            0xFF4E9A84,
                                                          ),
                                                          letterSpacing: 1.2,
                                                          fontWeight:
                                                              FontWeight.w800,
                                                        ),
                                                      ),
                                                    ],
                                                  ),
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(height: 10),
                                  const Center(
                                    child: Text(
                                      'Rekomendasi: PNG transparan 512x512px',
                                      style: TextStyle(
                                        color: Color(0xFF8E9794),
                                        fontSize: 13,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(height: 14),
                                  Row(
                                    children: const [
                                      Expanded(
                                        child: Divider(
                                          color: Color(0x4DACB4B1),
                                          thickness: 1,
                                        ),
                                      ),
                                      Padding(
                                        padding: EdgeInsets.symmetric(
                                          horizontal: 10,
                                        ),
                                        child: Text(
                                          'ATAU PILIH IKON',
                                          style: TextStyle(
                                            color: Color(0x80757C7A),
                                            fontSize: 12,
                                            letterSpacing: 1.2,
                                            fontWeight: FontWeight.w800,
                                          ),
                                        ),
                                      ),
                                      Expanded(
                                        child: Divider(
                                          color: Color(0x4DACB4B1),
                                          thickness: 1,
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 12),
                                  Row(
                                    children: _categoryIcons.map((iconData) {
                                      final selected = selectedIcon == iconData;
                                      return Expanded(
                                        child: Padding(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 3,
                                          ),
                                          child: InkWell(
                                            onTap: () => setModalState(
                                              () => selectedIcon = iconData,
                                            ),
                                            borderRadius: BorderRadius.circular(
                                              16,
                                            ),
                                            child: Container(
                                              height: 66,
                                              decoration: BoxDecoration(
                                                color: selected
                                                    ? const Color(0xFFA2F3D5)
                                                    : const Color(0xFFF1F4F2),
                                                borderRadius:
                                                    BorderRadius.circular(16),
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
                                  const SizedBox(height: 18),
                                  const Padding(
                                    padding: EdgeInsets.only(left: 4),
                                    child: Text(
                                      'JENIS PRODUK',
                                      style: TextStyle(
                                        color: Color(0xFF4F5755),
                                        fontSize: 12,
                                        letterSpacing: 1.8,
                                        fontWeight: FontWeight.w800,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(height: 10),
                                  TextField(
                                    controller: controller,
                                    autofocus: true,
                                    textInputAction: TextInputAction.done,
                                    maxLength: 30,
                                    onChanged: (_) {
                                      if (errorText != null) {
                                        setModalState(() => errorText = null);
                                      }
                                    },
                                    onSubmitted: (_) {
                                      submitCategory(
                                        modalContext,
                                        setModalState,
                                      );
                                    },
                                    decoration: InputDecoration(
                                      hintText: 'Misal: Makanan Penutup',
                                      errorText: errorText,
                                      counterText: '',
                                      suffixIcon: const Icon(
                                        Icons.category,
                                        color: Color(0x66757C7A),
                                      ),
                                      filled: true,
                                      fillColor: const Color(0xFFF1F4F2),
                                      contentPadding:
                                          const EdgeInsets.symmetric(
                                            horizontal: 16,
                                            vertical: 16,
                                          ),
                                      border: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(18),
                                        borderSide: BorderSide.none,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(height: 20),
                                  Row(
                                    children: [
                                      Expanded(
                                        child: TextButton(
                                          onPressed: isSavingCategory
                                              ? null
                                              : () => Navigator.of(
                                                  modalContext,
                                                ).pop(),
                                          style: TextButton.styleFrom(
                                            foregroundColor: const Color(
                                              0xFF505957,
                                            ),
                                            padding: const EdgeInsets.symmetric(
                                              vertical: 16,
                                            ),
                                            textStyle: const TextStyle(
                                              fontSize: 18,
                                              fontWeight: FontWeight.w700,
                                            ),
                                          ),
                                          child: const Text('Batal'),
                                        ),
                                      ),
                                      const SizedBox(width: 12),
                                      Expanded(
                                        child: ElevatedButton(
                                          onPressed: isSavingCategory
                                              ? null
                                              : () async {
                                                  await submitCategory(
                                                    modalContext,
                                                    setModalState,
                                                  );
                                                },
                                          style: ElevatedButton.styleFrom(
                                            backgroundColor: const Color(
                                              0xFF126C55,
                                            ),
                                            foregroundColor: const Color(
                                              0xFFE4FFF2,
                                            ),
                                            elevation: 6,
                                            shadowColor: const Color(
                                              0x40126C55,
                                            ),
                                            padding: const EdgeInsets.symmetric(
                                              vertical: 16,
                                            ),
                                            shape: RoundedRectangleBorder(
                                              borderRadius:
                                                  BorderRadius.circular(18),
                                            ),
                                          ),
                                          child: isSavingCategory
                                              ? const SizedBox(
                                                  width: 22,
                                                  height: 22,
                                                  child:
                                                      CircularProgressIndicator(
                                                        strokeWidth: 2.2,
                                                        color: Color(
                                                          0xFFE4FFF2,
                                                        ),
                                                      ),
                                                )
                                              : const Text(
                                                  'Simpan',
                                                  style: TextStyle(
                                                    fontSize: 18,
                                                    fontWeight: FontWeight.w800,
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
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );

    if (savedCategory == null || !mounted) {
      return;
    }

    final normalizedValue = savedCategory.name.trim().replaceAll(
      RegExp(r'\s+'),
      ' ',
    );
    if (normalizedValue.isEmpty) {
      return;
    }

    final exists = _categories.any(
      (item) => item.name.toLowerCase() == normalizedValue.toLowerCase(),
    );
    if (exists) {
      return;
    }

    try {
      setState(() {
        _categories.add(
          _CategoryItem(
            id: savedCategory.id,
            name: normalizedValue,
            iconName: savedCategory.iconName,
            imageUrl: savedCategory.imageUrl,
            productCount: 0,
          ),
        );
        _selectedCategoryId = savedCategory.id;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Kategori berhasil disimpan'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } catch (e, st) {
      debugPrint('[CATEGORY_POST_SAVE_UI_ERROR] $e');
      debugPrint('$st');
    }
  }

  Future<String?> _uploadImageToStorage(
    File imageFile,
    String categoryName,
  ) async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return null;

      final safeCategory = _safeStorageName(categoryName);
      final fileName =
          '${user.uid}_${safeCategory}_${DateTime.now().millisecondsSinceEpoch}.png';
      final ref = FirebaseStorage.instance.ref().child('categories/$fileName');

      await ref.putFile(imageFile);
      final url = await ref.getDownloadURL();
      debugPrint(
        '[CATEGORY_IMAGE_UPLOAD_OK] path=categories/$fileName url=$url',
      );
      return url;
    } on FirebaseException catch (e) {
      debugPrint(
        '[CATEGORY_IMAGE_UPLOAD_ERROR] code=${e.code} message=${e.message}',
      );
      return null;
    } catch (e) {
      debugPrint('[CATEGORY_IMAGE_UPLOAD_ERROR] $e');
      return null;
    }
  }

  Future<_CategoryItem?> _saveCategoryToFirestore(
    String categoryName,
    IconData selectedIcon,
    File? imageFile,
  ) async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        debugPrint('[CATEGORY_SAVE_ERROR] user is null');
        return null;
      }

      String? imageUrl;
      if (imageFile != null) {
        imageUrl = await _uploadImageToStorage(imageFile, categoryName);
      }

      final iconName = _getCategoryIconName(selectedIcon);
      final categoriesRef = FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .collection('categories');
      final docRef = categoriesRef.doc();
      final payload = <String, dynamic>{
        'id': docRef.id,
        'name': categoryName,
        'icon': iconName,
        'imageUrl': imageUrl,
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      };

      debugPrint(
        '[CATEGORY_SAVE_ATTEMPT] uid=${user.uid} data={name: $categoryName, icon: $iconName, imageUrl: $imageUrl}',
      );

      await docRef.set(payload, SetOptions(merge: true));

      debugPrint('[CATEGORY_SAVE_OK] docId=${docRef.id}');
      return _CategoryItem(
        id: docRef.id,
        name: categoryName,
        iconName: iconName,
        imageUrl: imageUrl,
      );
    } on FirebaseException catch (e) {
      debugPrint('[CATEGORY_SAVE_ERROR] code=${e.code} message=${e.message}');
      return null;
    } catch (e) {
      debugPrint('[CATEGORY_SAVE_ERROR] $e');
      return null;
    }
  }

  IconData _getCategoryIconFromName(String iconName) {
    switch (iconName) {
      case 'restaurant':
        return Icons.restaurant;
      case 'local_bar':
        return Icons.local_bar;
      case 'fastfood':
        return Icons.fastfood;
      case 'icecream':
        return Icons.icecream;
      case 'bakery_dining':
        return Icons.bakery_dining;
      default:
        return Icons.restaurant;
    }
  }

  Widget _buildCategoryThumbnail(_CategoryItem category) {
    if (category.imageUrl != null && category.imageUrl!.isNotEmpty) {
      return Image.network(
        category.imageUrl!,
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) => _buildCategoryFallback(category),
      );
    }
    return _buildCategoryFallback(category);
  }

  Widget _buildCategoryFallback(_CategoryItem category) {
    return DecoratedBox(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFFECF2EF), Color(0xFFE1E9E5)],
        ),
      ),
      child: Center(
        child: Icon(
          _getCategoryIconFromName(category.iconName),
          size: 54,
          color: const Color(0xFF4D8070),
        ),
      ),
    );
  }

  Widget _buildCategoryCard(_CategoryItem category, bool isCompact) {
    final countLabel =
        '${category.productCount} ${category.name.toUpperCase()}';

    return GestureDetector(
      onTap: () {
        _showProductListSheet(category.id, category.name);
      },
      child: Column(
        children: [
          Expanded(
            child: Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(22),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(20),
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    _buildCategoryThumbnail(category),
                    Container(color: const Color(0x1A000000)),
                    Positioned(
                      left: 10,
                      bottom: 10,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(0xF6FFFFFF),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          countLabel,
                          style: const TextStyle(
                            fontSize: 10,
                            letterSpacing: 1,
                            fontWeight: FontWeight.w800,
                            color: Color(0xFF2E3533),
                          ),
                        ),
                      ),
                    ),
                    Positioned(
                      right: 10,
                      bottom: 10,
                      child: Material(
                        color: const Color(0xF6FFFFFF),
                        borderRadius: BorderRadius.circular(12),
                        child: InkWell(
                          borderRadius: BorderRadius.circular(12),
                          onTap: () async {
                            await Navigator.of(context).push(
                              MaterialPageRoute<void>(
                                builder: (_) => AddProductPage(
                                  categoryId: category.id,
                                  categoryName: category.name,
                                ),
                              ),
                            );
                            // Reload categories after returning from AddProductPage
                            await _loadCategories();
                          },
                          child: SizedBox(
                            width: isCompact ? 42 : 46,
                            height: isCompact ? 42 : 46,
                            child: const Icon(
                              Icons.add,
                              color: Color(0xFF126C55),
                              size: 26,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            category.name,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: isCompact ? 16 : 18,
              fontWeight: FontWeight.w500,
              color: const Color(0xFF2D3432),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAddCategoryCard(bool isCompact) {
    return InkWell(
      onTap: _showAddCategoryDialog,
      borderRadius: BorderRadius.circular(22),
      child: Column(
        children: [
          Expanded(
            child: Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(22),
                border: Border.all(color: const Color(0xFFACB4B1), width: 2),
                color: const Color(0x14DDE4E1),
              ),
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: isCompact ? 50 : 56,
                      height: isCompact ? 50 : 56,
                      decoration: const BoxDecoration(
                        shape: BoxShape.circle,
                        color: Color(0xFF126C55),
                      ),
                      child: const Icon(
                        Icons.add,
                        color: Color(0xFFE4FFF2),
                        size: 32,
                      ),
                    ),
                    const SizedBox(height: 10),
                    const Text(
                      'TAMBAH',
                      style: TextStyle(
                        fontSize: 12,
                        letterSpacing: 1.1,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFF2D3432),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: 8),
          const SizedBox(height: 22),
        ],
      ),
    );
  }

  String _getCategoryIconName(IconData icon) {
    for (int i = 0; i < _categoryIcons.length; i++) {
      if (_categoryIcons[i] == icon) {
        return [
          'restaurant',
          'local_bar',
          'fastfood',
          'icecream',
          'bakery_dining',
        ][i];
      }
    }
    return 'restaurant';
  }

  IconData _getProductIconFromName(String iconName) {
    switch (iconName) {
      case 'fastfood':
        return Icons.fastfood;
      case 'coffee':
        return Icons.coffee;
      case 'icecream':
        return Icons.icecream;
      case 'local_pizza':
        return Icons.local_pizza;
      case 'bakery_dining':
        return Icons.bakery_dining;
      default:
        return Icons.fastfood;
    }
  }

  void _goNext() {
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute<void>(builder: (_) => const HomePage()),
      (_) => false,
    );
  }

  Future<void> _showProductListSheet(
    String categoryId,
    String categoryName,
  ) async {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (_) => DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.7,
        maxChildSize: 0.95,
        minChildSize: 0.4,
        builder: (_, scrollController) {
          return StatefulBuilder(
            builder: (sheetContext, setSheetState) {
              return FutureBuilder<List<Map<String, dynamic>>>(
                future: _fetchCategoryProducts(categoryId),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(
                      child: CircularProgressIndicator(
                        color: Color(0xFF126C55),
                      ),
                    );
                  }

                  final products = snapshot.data ?? [];

                  return Column(
                    children: [
                      Padding(
                        padding: const EdgeInsets.fromLTRB(20, 16, 20, 12),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    'Kategori - $categoryName',
                                    style: const TextStyle(
                                      fontSize: 20,
                                      fontWeight: FontWeight.w800,
                                      color: Color(0xFF2D3432),
                                    ),
                                  ),
                                ),
                                IconButton(
                                  onPressed: () =>
                                      Navigator.of(sheetContext).pop(),
                                  icon: const Icon(Icons.close),
                                  color: const Color(0xFF5C6663),
                                ),
                              ],
                            ),
                            Text(
                              'Total: ${products.length} kategori',
                              style: const TextStyle(
                                fontSize: 14,
                                color: Color(0xFF8F9895),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const Divider(height: 1, color: Color(0xFFE4E9E7)),
                      Expanded(
                        child: products.isEmpty
                            ? Center(
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    const Icon(
                                      Icons.inventory_2_outlined,
                                      size: 48,
                                      color: Color(0xFFB9CFC8),
                                    ),
                                    const SizedBox(height: 12),
                                    Text(
                                      'Belum ada kategori',
                                      style: TextStyle(
                                        fontSize: 16,
                                        color: const Color(0xFF8F9895),
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                  ],
                                ),
                              )
                            : ListView.builder(
                                controller: scrollController,
                                padding: const EdgeInsets.all(12),
                                itemCount: products.length,
                                itemBuilder: (_, index) {
                                  final product = products[index];
                                  return _buildProductListItem(
                                    product,
                                    sheetContext,
                                    setSheetState,
                                    categoryId,
                                    categoryName,
                                  );
                                },
                              ),
                      ),
                    ],
                  );
                },
              );
            },
          );
        },
      ),
    );
  }

  Future<List<Map<String, dynamic>>> _fetchCategoryProducts(
    String categoryId,
  ) async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return [];

      QuerySnapshot<Map<String, dynamic>> snapshot;
      try {
        snapshot = await FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .collection('products')
            .where('categoryId', isEqualTo: categoryId)
            .orderBy('createdAt', descending: true)
            .get();
      } on FirebaseException catch (e) {
        // Fallback if index for where+orderBy is not ready yet.
        if (e.code != 'failed-precondition') {
          rethrow;
        }

        snapshot = await FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .collection('products')
            .where('categoryId', isEqualTo: categoryId)
            .get();
      }

      final items = snapshot.docs.map((doc) {
        final data = doc.data();
        return {'id': doc.id, ...data};
      }).toList();

      items.sort((a, b) {
        final aTime = a['createdAt'];
        final bTime = b['createdAt'];

        final aMillis = aTime is Timestamp
            ? aTime.millisecondsSinceEpoch
            : (aTime is int ? aTime : 0);
        final bMillis = bTime is Timestamp
            ? bTime.millisecondsSinceEpoch
            : (bTime is int ? bTime : 0);

        return bMillis.compareTo(aMillis);
      });

      return items;
    } catch (e) {
      debugPrint('[FETCH_PRODUCTS_ERROR] $e');
      return [];
    }
  }

  Widget _buildProductListItem(
    Map<String, dynamic> product,
    BuildContext sheetContext,
    StateSetter setSheetState,
    String categoryId,
    String categoryName,
  ) {
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 8),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            // Product thumbnail
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: Container(
                width: 70,
                height: 70,
                decoration: const BoxDecoration(color: Color(0xFFF1F4F2)),
                child: (product['imageUrl'] as String?)?.isNotEmpty == true
                    ? Image.network(
                        product['imageUrl'],
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) {
                          final iconData = _getProductIconFromName(
                            product['icon'] as String? ?? 'fastfood',
                          );
                          return Center(
                            child: Icon(
                              iconData,
                              size: 32,
                              color: const Color(0xFF4D8070),
                            ),
                          );
                        },
                      )
                    : Center(
                        child: Icon(
                          _getProductIconFromName(
                            product['icon'] as String? ?? 'fastfood',
                          ),
                          size: 32,
                          color: const Color(0xFF4D8070),
                        ),
                      ),
              ),
            ),
            const SizedBox(width: 12),
            // Product info
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    product['name'] as String? ?? 'N/A',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF2D3432),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Rp ${product['price'] ?? 0}',
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF126C55),
                    ),
                  ),
                ],
              ),
            ),
            // Edit button
            IconButton(
              onPressed: () async {
                Navigator.of(sheetContext).pop();
                await Future.delayed(const Duration(milliseconds: 200));
                if (!mounted) return;

                final rawTags = product['tags'];
                final initialTags = rawTags is List
                    ? rawTags
                          .map((tag) => tag.toString().trim())
                          .where((tag) => tag.isNotEmpty)
                          .toList()
                    : <String>[];

                int? initialPrice;
                final rawPrice = product['price'];
                if (rawPrice is int) {
                  initialPrice = rawPrice;
                } else if (rawPrice is num) {
                  initialPrice = rawPrice.toInt();
                } else if (rawPrice is String) {
                  initialPrice = int.tryParse(rawPrice);
                }

                final updated = await Navigator.of(context).push<bool>(
                  MaterialPageRoute<bool>(
                    builder: (_) => AddProductPage(
                      categoryId: categoryId,
                      categoryName: categoryName,
                      productId: (product['id'] as String?) ?? '',
                      initialName: product['name'] as String?,
                      initialPrice: initialPrice,
                      initialTags: initialTags,
                      initialImageUrl: product['imageUrl'] as String?,
                      initialIconName: product['icon'] as String?,
                    ),
                  ),
                );

                if (updated == true) {
                  await _loadCategories();
                  if (!mounted) return;
                  await _showProductListSheet(categoryId, categoryName);
                }
              },
              icon: const Icon(Icons.edit, color: Color(0xFF126C55)),
              splashRadius: 20,
            ),
            // Delete button
            IconButton(
              onPressed: () async {
                final confirm = await showDialog<bool>(
                  context: sheetContext,
                  builder: (dialogContext) => AlertDialog(
                    title: const Text('Hapus Produk?'),
                    content: Text(
                      'Apakah Anda yakin ingin menghapus produk "${product['name']}"?',
                    ),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.of(dialogContext).pop(false),
                        child: const Text('Batal'),
                      ),
                      TextButton(
                        onPressed: () => Navigator.of(dialogContext).pop(true),
                        child: const Text(
                          'Hapus',
                          style: TextStyle(color: Colors.red),
                        ),
                      ),
                    ],
                  ),
                );

                if (confirm == true) {
                  try {
                    final user = FirebaseAuth.instance.currentUser;
                    if (user != null) {
                      await FirebaseFirestore.instance
                          .collection('users')
                          .doc(user.uid)
                          .collection('products')
                          .doc(product['id'] as String)
                          .delete();

                      if (sheetContext.mounted) {
                        setSheetState(() {});
                        await _loadCategories();
                      }

                      if (!mounted) return;
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Produk berhasil dihapus'),
                          behavior: SnackBarBehavior.floating,
                        ),
                      );
                    }
                  } catch (e) {
                    debugPrint('[DELETE_PRODUCT_ERROR] $e');
                    if (!mounted) return;
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Gagal menghapus produk'),
                        behavior: SnackBarBehavior.floating,
                      ),
                    );
                  }
                }
              },
              icon: const Icon(Icons.delete, color: Colors.red),
              splashRadius: 20,
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    const bg = Color(0xFFF8FAF8);
    const textMain = Color(0xFF2D3432);
    const textMuted = Color(0xFF59615F);
    const primary = Color(0xFF126C55);
    const surfaceLow = Color(0xFFF1F4F2);
    const surfaceLowest = Color(0xFFFFFFFF);
    const outlineVariant = Color(0xFFACB4B1);
    final screenHeight = MediaQuery.of(context).size.height;
    final isCompact = screenHeight < 760;

    return Scaffold(
      backgroundColor: bg,
      body: SafeArea(
        child: Column(
          children: [
            SizedBox(
              height: 64,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Row(
                  children: [
                    IconButton(
                      onPressed: () => Navigator.of(context).maybePop(),
                      icon: const Icon(Icons.arrow_back, color: primary),
                      splashRadius: 20,
                    ),
                    const SizedBox(width: 10),
                    const Text(
                      'KATEGORI JUALAN',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.8,
                        color: primary,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(24, 20, 24, 0),
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Jenis Jualan',
                        style: TextStyle(
                          fontSize: isCompact ? 24 : 28,
                          fontWeight: FontWeight.w800,
                          height: 1,
                          color: textMain,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        'Pilih atau tambahkan kategori produk yang Anda jual.',
                        style: TextStyle(
                          fontSize: isCompact ? 14 : 16,
                          fontWeight: FontWeight.w500,
                          height: 1.35,
                          color: textMuted,
                        ),
                      ),
                      SizedBox(height: isCompact ? 16 : 22),
                      SizedBox(
                        child: _isLoadingCategories
                            ? SizedBox(
                                height: isCompact ? 240 : 280,
                                child: const Center(
                                  child: CircularProgressIndicator(
                                    color: Color(0xFF126C55),
                                  ),
                                ),
                              )
                            : _categories.isEmpty
                            ? Column(
                                children: [
                                  SizedBox(height: isCompact ? 10 : 18),
                                  _EmptyIllustration(
                                    primary: primary,
                                    surfaceLow: surfaceLow,
                                    surfaceLowest: surfaceLowest,
                                    compact: isCompact,
                                  ),
                                  SizedBox(height: isCompact ? 22 : 30),
                                  OutlinedButton(
                                    onPressed: _showAddCategoryDialog,
                                    style: OutlinedButton.styleFrom(
                                      minimumSize: Size.fromHeight(
                                        isCompact ? 170 : 210,
                                      ),
                                      side: const BorderSide(
                                        color: outlineVariant,
                                        width: 2,
                                        style: BorderStyle.solid,
                                      ),
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(30),
                                      ),
                                      backgroundColor: Colors.transparent,
                                    ),
                                    child: Column(
                                      mainAxisAlignment:
                                          MainAxisAlignment.center,
                                      children: [
                                        Container(
                                          width: isCompact ? 72 : 84,
                                          height: isCompact ? 72 : 84,
                                          decoration: const BoxDecoration(
                                            shape: BoxShape.circle,
                                            color: surfaceLow,
                                          ),
                                          child: Icon(
                                            Icons.add,
                                            size: isCompact ? 44 : 50,
                                            color: Color(0xFF8C9592),
                                          ),
                                        ),
                                        SizedBox(height: isCompact ? 14 : 22),
                                        Text(
                                          'TAMBAH KATEGORI',
                                          style: TextStyle(
                                            fontSize: isCompact ? 22 : 26,
                                            letterSpacing: 1.5,
                                            fontWeight: FontWeight.w800,
                                            color: textMuted,
                                          ),
                                        ),
                                        SizedBox(height: isCompact ? 8 : 10),
                                        Text(
                                          'Contoh: Makanan, Minuman, dll',
                                          textAlign: TextAlign.center,
                                          style: TextStyle(
                                            fontSize: isCompact ? 12 : 13,
                                            fontWeight: FontWeight.w500,
                                            color: const Color(0xFF8B9491),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  SizedBox(height: isCompact ? 16 : 22),
                                ],
                              )
                            : Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  GridView.builder(
                                    shrinkWrap: true,
                                    physics:
                                        const NeverScrollableScrollPhysics(),
                                    itemCount: _categories.length + 1,
                                    gridDelegate:
                                        SliverGridDelegateWithFixedCrossAxisCount(
                                          crossAxisCount: 2,
                                          mainAxisSpacing: 14,
                                          crossAxisSpacing: 14,
                                          childAspectRatio: isCompact
                                              ? 0.62
                                              : 0.66,
                                        ),
                                    itemBuilder: (_, index) {
                                      if (index == _categories.length) {
                                        return _buildAddCategoryCard(isCompact);
                                      }
                                      return _buildCategoryCard(
                                        _categories[index],
                                        isCompact,
                                      );
                                    },
                                  ),
                                  const SizedBox(height: 18),
                                ],
                              ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: Container(
        padding: const EdgeInsets.fromLTRB(24, 10, 24, 24),
        decoration: const BoxDecoration(color: Color(0xCCF8FAF8)),
        child: SafeArea(
          top: false,
          child: SizedBox(
            height: 68,
            child: ElevatedButton(
              onPressed: _categories.isEmpty ? null : _goNext,
              style: ElevatedButton.styleFrom(
                elevation: 0,
                backgroundColor: const Color(0xFF126C55),
                disabledBackgroundColor: const Color(0xFFE9ECEB),
                foregroundColor: const Color(0xFFE4FFF2),
                disabledForegroundColor: const Color(0xFFB3BBBA),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(22),
                ),
              ),
              child: const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    'Lanjut',
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800),
                  ),
                  SizedBox(width: 8),
                  Icon(Icons.arrow_forward, size: 22),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _EmptyIllustration extends StatelessWidget {
  const _EmptyIllustration({
    required this.primary,
    required this.surfaceLow,
    required this.surfaceLowest,
    required this.compact,
  });

  final Color primary;
  final Color surfaceLow;
  final Color surfaceLowest;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: compact ? 220 : 270,
      height: compact ? 220 : 270,
      child: Stack(
        children: [
          Align(
            alignment: Alignment.center,
            child: Container(
              width: compact ? 166 : 206,
              height: compact ? 166 : 206,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: surfaceLow,
              ),
            ),
          ),
          Align(
            alignment: Alignment.center,
            child: Container(
              width: compact ? 104 : 132,
              height: compact ? 104 : 132,
              decoration: BoxDecoration(
                color: surfaceLowest,
                borderRadius: BorderRadius.circular(24),
                boxShadow: const [
                  BoxShadow(
                    color: Color(0x12000000),
                    blurRadius: 8,
                    offset: Offset(0, 3),
                  ),
                ],
              ),
              child: const Icon(
                Icons.inventory_2_outlined,
                size: 44,
                color: Color(0xFFB9CFC8),
              ),
            ),
          ),
          Positioned(
            right: compact ? 18 : 30,
            top: compact ? 8 : 18,
            child: Transform.rotate(
              angle: 0.22,
              child: Container(
                width: compact ? 50 : 62,
                height: compact ? 50 : 62,
                decoration: BoxDecoration(
                  color: const Color(0x66A2F3D5),
                  borderRadius: BorderRadius.circular(18),
                ),
                child: Icon(Icons.spa, color: primary, size: compact ? 22 : 28),
              ),
            ),
          ),
          Positioned(
            left: compact ? 8 : 20,
            bottom: compact ? 20 : 35,
            child: Transform.rotate(
              angle: -0.22,
              child: Container(
                width: compact ? 44 : 52,
                height: compact ? 44 : 52,
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  color: Color(0x66DCE5DD),
                ),
                child: Icon(
                  Icons.local_mall_outlined,
                  color: Color(0xFF58615B),
                  size: compact ? 20 : 24,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
