import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import 'add_product_page.dart';

class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  bool _isUploadingQris = false;
  bool _isSavingBusinessName = false;
  bool _isPickingQrisImage = false;

  String get _uid => FirebaseAuth.instance.currentUser?.uid ?? '';

  DocumentReference<Map<String, dynamic>> get _userRef =>
      FirebaseFirestore.instance.collection('users').doc(_uid);

  CollectionReference<Map<String, dynamic>> get _categoriesRef =>
      _userRef.collection('categories');

  CollectionReference<Map<String, dynamic>> get _productsRef =>
      _userRef.collection('products');

  Future<void> _saveBusinessName(String currentName) async {
    if (_uid.isEmpty || _isSavingBusinessName) {
      return;
    }

    final controller = TextEditingController(text: currentName);
    final value = await showDialog<String>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Ubah Nama Usaha'),
          content: TextField(
            controller: controller,
            maxLength: 30,
            autofocus: true,
            decoration: const InputDecoration(hintText: 'Masukkan nama usaha'),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: const Text('Batal'),
            ),
            FilledButton(
              onPressed: () {
                Navigator.of(dialogContext).pop(controller.text);
              },
              child: const Text('Simpan'),
            ),
          ],
        );
      },
    );

    if (!mounted || value == null) {
      return;
    }

    final normalized = value.trim().replaceAll(RegExp(r'\s+'), ' ');
    if (normalized.length < 3) {
      _showMessage('Nama usaha minimal 3 karakter.');
      return;
    }

    setState(() => _isSavingBusinessName = true);
    try {
      await _userRef.set({
        'businessName': normalized,
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
      _showMessage('Nama usaha berhasil diperbarui.');
    } on FirebaseException catch (e) {
      _showMessage(e.message ?? 'Gagal menyimpan nama usaha.');
    } finally {
      if (mounted) {
        setState(() => _isSavingBusinessName = false);
      }
    }
  }

  Future<void> _pickAndSaveQris() async {
    if (_uid.isEmpty || _isUploadingQris || _isPickingQrisImage) {
      return;
    }

    setState(() => _isPickingQrisImage = true);
    try {
      final picker = ImagePicker();
      final image = await picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 1200,
        imageQuality: 85,
      );
      if (image == null || !mounted) {
        return;
      }

      setState(() => _isUploadingQris = true);
      try {
        final ref = FirebaseStorage.instance.ref().child(
          'business/$_uid/qris.jpg',
        );
        await ref.putFile(File(image.path));
        final url = await ref.getDownloadURL();

        await _userRef.set({
          'qrisEnabled': true,
          'qrisImageUrl': url,
          'updatedAt': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));

        _showMessage('Metode pembayaran QRIS berhasil diperbarui.');
      } on FirebaseException catch (e) {
        _showMessage(e.message ?? 'Gagal upload QRIS.');
      } catch (_) {
        _showMessage('Terjadi kesalahan saat mengunggah QRIS.');
      } finally {
        if (mounted) {
          setState(() => _isUploadingQris = false);
        }
      }
    } catch (_) {
      if (mounted) {
        _showMessage('Terjadi kesalahan saat membuka galeri.');
      }
    } finally {
      if (mounted) {
        setState(() => _isPickingQrisImage = false);
      }
    }
  }

  Future<void> _showAddCategoryDialog(
    List<_CategoryData> existingCategories,
  ) async {
    if (_uid.isEmpty) {
      return;
    }

    final controller = TextEditingController();
    final result = await showDialog<String>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Tambah Kategori Baru'),
          content: TextField(
            controller: controller,
            maxLength: 25,
            autofocus: true,
            decoration: const InputDecoration(hintText: 'Contoh: Makanan'),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: const Text('Batal'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(dialogContext).pop(controller.text),
              child: const Text('Tambah'),
            ),
          ],
        );
      },
    );

    if (!mounted || result == null) {
      return;
    }

    final normalized = result.trim().replaceAll(RegExp(r'\s+'), ' ');
    if (normalized.isEmpty) {
      _showMessage('Nama kategori wajib diisi.');
      return;
    }

    final alreadyExists = existingCategories.any(
      (category) => category.name.toLowerCase() == normalized.toLowerCase(),
    );
    if (alreadyExists) {
      _showMessage('Kategori sudah ada.');
      return;
    }

    final docRef = _categoriesRef.doc();
    await docRef.set({
      'id': docRef.id,
      'name': normalized,
      'icon': _iconNameForCategory(normalized),
      'imageUrl': '',
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    });

    _showMessage('Kategori berhasil ditambahkan.');
  }

  Future<void> _deleteCategory(_CategoryData category) async {
    if (_uid.isEmpty) {
      return;
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Hapus Kategori'),
          content: Text(
            'Kategori ${category.name} beserta semua produknya akan dihapus.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: const Text('Batal'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(dialogContext).pop(true),
              style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFFA83836),
              ),
              child: const Text('Hapus'),
            ),
          ],
        );
      },
    );

    if (confirmed != true) {
      return;
    }

    try {
      final productDocs = await _productsRef
          .where('categoryId', isEqualTo: category.id)
          .get();
      final batch = FirebaseFirestore.instance.batch();
      for (final doc in productDocs.docs) {
        batch.delete(doc.reference);
      }
      batch.delete(_categoriesRef.doc(category.docId));
      await batch.commit();
      _showMessage('Kategori berhasil dihapus.');
    } on FirebaseException catch (e) {
      _showMessage(e.message ?? 'Gagal menghapus kategori.');
    }
  }

  Future<void> _deleteProduct(_ProductData product) async {
    if (_uid.isEmpty) {
      return;
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Hapus Produk'),
          content: Text('Produk ${product.name} akan dihapus.'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: const Text('Batal'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(dialogContext).pop(true),
              style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFFA83836),
              ),
              child: const Text('Hapus'),
            ),
          ],
        );
      },
    );

    if (confirmed != true) {
      return;
    }

    try {
      await _productsRef.doc(product.id).delete();
      _showMessage('Produk berhasil dihapus.');
    } on FirebaseException catch (e) {
      _showMessage(e.message ?? 'Gagal menghapus produk.');
    }
  }

  Future<void> _openAddProduct(_CategoryData category) async {
    await Navigator.of(context).push<bool>(
      MaterialPageRoute<bool>(
        builder: (_) => AddProductPage(
          categoryId: category.id,
          categoryName: category.name,
        ),
      ),
    );
  }

  Future<void> _openEditProduct(
    _CategoryData category,
    _ProductData product,
  ) async {
    await Navigator.of(context).push<bool>(
      MaterialPageRoute<bool>(
        builder: (_) => AddProductPage(
          categoryId: category.id,
          categoryName: category.name,
          productId: product.id,
          initialName: product.name,
          initialPrice: product.price,
          initialTags: product.tags,
          initialImageUrl: product.imageUrl,
          initialIconName: product.iconName,
        ),
      ),
    );
  }

  int _readPrice(dynamic value) {
    if (value is int) {
      return value;
    }
    if (value is num) {
      return value.toInt();
    }
    if (value is String) {
      return int.tryParse(value.replaceAll(RegExp(r'[^0-9]'), '')) ?? 0;
    }
    return 0;
  }

  String _formatCurrency(int value) {
    final digits = value.toString();
    final buffer = StringBuffer();
    for (int i = 0; i < digits.length; i++) {
      final indexFromEnd = digits.length - i;
      buffer.write(digits[i]);
      if (indexFromEnd > 1 && indexFromEnd % 3 == 1) {
        buffer.write('.');
      }
    }
    return buffer.toString();
  }

  IconData _categoryIconFromName(String name) {
    switch (name) {
      case 'local_bar':
        return Icons.local_bar;
      case 'fastfood':
        return Icons.fastfood;
      case 'icecream':
        return Icons.icecream;
      case 'bakery_dining':
        return Icons.bakery_dining;
      case 'cookie':
        return Icons.cookie;
      case 'local_cafe':
        return Icons.local_cafe;
      case 'restaurant':
      default:
        return Icons.restaurant;
    }
  }

  String _iconNameForCategory(String categoryName) {
    final name = categoryName.toLowerCase();
    if (name.contains('minum') || name.contains('kopi')) {
      return 'local_cafe';
    }
    if (name.contains('cemil') || name.contains('snack')) {
      return 'cookie';
    }
    return 'restaurant';
  }

  IconData _productIconFromName(String name) {
    switch (name) {
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

  List<_CategoryData> _mapCategories(
    QuerySnapshot<Map<String, dynamic>> snapshot,
  ) {
    final categories = snapshot.docs
        .map((doc) {
          final data = doc.data();
          final name = (data['name'] as String? ?? '').trim();
          if (name.isEmpty) {
            return null;
          }
          return _CategoryData(
            docId: doc.id,
            id: (data['id'] as String? ?? doc.id).trim(),
            name: name,
            iconName: (data['icon'] as String? ?? 'restaurant').trim(),
          );
        })
        .whereType<_CategoryData>()
        .toList();
    categories.sort(
      (a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()),
    );
    return categories;
  }

  List<_ProductData> _mapProducts(
    QuerySnapshot<Map<String, dynamic>> snapshot,
  ) {
    final products = snapshot.docs
        .map((doc) {
          final data = doc.data();
          final name = (data['name'] as String? ?? '').trim();
          final categoryId = (data['categoryId'] as String? ?? '').trim();
          if (name.isEmpty || categoryId.isEmpty) {
            return null;
          }
          return _ProductData(
            id: doc.id,
            name: name,
            categoryId: categoryId,
            price: _readPrice(data['price']),
            imageUrl: (data['imageUrl'] as String? ?? '').trim(),
            iconName: (data['icon'] as String? ?? 'fastfood').trim(),
            tags: (data['tags'] as List<dynamic>? ?? const <dynamic>[])
                .map((tag) => tag.toString())
                .toList(),
          );
        })
        .whereType<_ProductData>()
        .toList();

    products.sort(
      (a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()),
    );
    return products;
  }

  void _showMessage(String message) {
    if (!mounted) {
      return;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), behavior: SnackBarBehavior.floating),
    );
  }

  @override
  Widget build(BuildContext context) {
    final uid = _uid;
    if (uid.isEmpty) {
      return const Scaffold(
        backgroundColor: Color(0xFFF8FAF8),
        body: Center(
          child: Text(
            'Sesi login tidak ditemukan.',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAF8),
      body: SafeArea(
        bottom: false,
        child: StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
          stream: _userRef.snapshots(),
          builder: (context, userSnapshot) {
            final userData =
                userSnapshot.data?.data() ?? const <String, dynamic>{};
            final businessName =
                (userData['businessName'] as String? ?? '').trim().isEmpty
                ? 'Nama usaha belum diatur'
                : (userData['businessName'] as String).trim();
            final qrisEnabled = userData['qrisEnabled'] as bool? ?? false;
            final qrisImageUrl = (userData['qrisImageUrl'] as String? ?? '')
                .trim();
            final hasQris = qrisEnabled && qrisImageUrl.isNotEmpty;

            return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
              stream: _categoriesRef.snapshots(),
              builder: (context, categorySnapshot) {
                final categories = categorySnapshot.hasData
                    ? _mapCategories(categorySnapshot.data!)
                    : <_CategoryData>[];

                return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                  stream: _productsRef.snapshots(),
                  builder: (context, productSnapshot) {
                    final products = productSnapshot.hasData
                        ? _mapProducts(productSnapshot.data!)
                        : <_ProductData>[];
                    final productsByCategory = <String, List<_ProductData>>{};
                    for (final product in products) {
                      productsByCategory
                          .putIfAbsent(
                            product.categoryId,
                            () => <_ProductData>[],
                          )
                          .add(product);
                    }

                    return CustomScrollView(
                      slivers: [
                        SliverToBoxAdapter(
                          child: Container(
                            padding: const EdgeInsets.fromLTRB(22, 12, 22, 10),
                            color: Colors.white,
                            child: Row(
                              children: const [
                                Icon(
                                  Icons.settings,
                                  color: Color(0xFF126C55),
                                  size: 26,
                                ),
                                SizedBox(width: 10),
                                Text(
                                  'Pengaturan',
                                  style: TextStyle(
                                    fontSize: 24,
                                    fontWeight: FontWeight.w800,
                                    color: Color(0xFF126C55),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        SliverPadding(
                          padding: const EdgeInsets.fromLTRB(18, 16, 18, 120),
                          sliver: SliverList.list(
                            children: [
                              const _SectionHeader(
                                overline: 'Identitas Visual',
                                title: 'Profil Bisnis',
                              ),
                              const SizedBox(height: 12),
                              LayoutBuilder(
                                builder: (context, constraints) {
                                  final isCompact = constraints.maxWidth < 760;
                                  if (isCompact) {
                                    return Column(
                                      children: [
                                        _BusinessNameCard(
                                          businessName: businessName,
                                          onEdit: _isSavingBusinessName
                                              ? null
                                              : () => _saveBusinessName(
                                                  businessName,
                                                ),
                                          isSaving: _isSavingBusinessName,
                                        ),
                                        const SizedBox(height: 12),
                                        _QrisCard(
                                          hasQris: hasQris,
                                          qrisImageUrl: qrisImageUrl,
                                          isUploading: _isUploadingQris,
                                          isPickingImage: _isPickingQrisImage,
                                          onTapAction: _pickAndSaveQris,
                                        ),
                                      ],
                                    );
                                  }

                                  return Row(
                                    children: [
                                      Expanded(
                                        flex: 2,
                                        child: _BusinessNameCard(
                                          businessName: businessName,
                                          onEdit: _isSavingBusinessName
                                              ? null
                                              : () => _saveBusinessName(
                                                  businessName,
                                                ),
                                          isSaving: _isSavingBusinessName,
                                        ),
                                      ),
                                      const SizedBox(width: 12),
                                      Expanded(
                                        child: _QrisCard(
                                          hasQris: hasQris,
                                          qrisImageUrl: qrisImageUrl,
                                          isUploading: _isUploadingQris,
                                          isPickingImage: _isPickingQrisImage,
                                          onTapAction: _pickAndSaveQris,
                                        ),
                                      ),
                                    ],
                                  );
                                },
                              ),
                              const SizedBox(height: 26),
                              LayoutBuilder(
                                builder: (context, constraints) {
                                  final vertical = constraints.maxWidth < 620;
                                  return Flex(
                                    direction: vertical
                                        ? Axis.vertical
                                        : Axis.horizontal,
                                    crossAxisAlignment: vertical
                                        ? CrossAxisAlignment.start
                                        : CrossAxisAlignment.center,
                                    mainAxisAlignment:
                                        MainAxisAlignment.spaceBetween,
                                    children: [
                                      const _SectionHeader(
                                        overline: 'Katalog Produk',
                                        title: 'Kategori & Menu',
                                      ),
                                      if (vertical) const SizedBox(height: 12),
                                      FilledButton.icon(
                                        onPressed: () =>
                                            _showAddCategoryDialog(categories),
                                        style: FilledButton.styleFrom(
                                          backgroundColor: const Color(
                                            0xFF126C55,
                                          ),
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 16,
                                            vertical: 12,
                                          ),
                                          shape: RoundedRectangleBorder(
                                            borderRadius: BorderRadius.circular(
                                              14,
                                            ),
                                          ),
                                        ),
                                        icon: const Icon(
                                          Icons.add_circle_outline,
                                        ),
                                        label: const Text(
                                          'Tambah Kategori Baru',
                                        ),
                                      ),
                                    ],
                                  );
                                },
                              ),
                              const SizedBox(height: 8),
                              if (categories.isEmpty)
                                const _EmptyDataCard(
                                  text:
                                      'Belum ada kategori. Tambahkan kategori baru.',
                                )
                              else
                                ...categories.map((category) {
                                  final categoryProducts =
                                      productsByCategory[category.id] ??
                                      const <_ProductData>[];
                                  return _CategoryAccordion(
                                    category: category,
                                    products: categoryProducts,
                                    onDeleteCategory: () =>
                                        _deleteCategory(category),
                                    onAddProduct: () =>
                                        _openAddProduct(category),
                                    onEditProduct: (product) =>
                                        _openEditProduct(category, product),
                                    onDeleteProduct: _deleteProduct,
                                    categoryIcon: _categoryIconFromName(
                                      category.iconName,
                                    ),
                                    productIconFromName: _productIconFromName,
                                    formatCurrency: _formatCurrency,
                                  );
                                }),
                            ],
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
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.overline, required this.title});

  final String overline;
  final String title;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          overline.toUpperCase(),
          style: const TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w800,
            letterSpacing: 1.2,
            color: Color(0x99126C55),
          ),
        ),
        const SizedBox(height: 2),
        Text(
          title,
          style: const TextStyle(
            fontSize: 28,
            fontWeight: FontWeight.w800,
            color: Color(0xFF232B29),
          ),
        ),
      ],
    );
  }
}

class _BusinessNameCard extends StatelessWidget {
  const _BusinessNameCard({
    required this.businessName,
    required this.onEdit,
    required this.isSaving,
  });

  final String businessName;
  final VoidCallback? onEdit;
  final bool isSaving;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        boxShadow: const [
          BoxShadow(
            color: Color(0x0C000000),
            blurRadius: 12,
            offset: Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Expanded(
                child: Text(
                  'Nama Usaha',
                  style: TextStyle(
                    fontSize: 12,
                    color: Color(0xFF5A615F),
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              IconButton(
                onPressed: onEdit,
                icon: isSaving
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.edit, color: Color(0xFF126C55)),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            businessName,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontSize: 26,
              fontWeight: FontWeight.w800,
              color: Color(0xFF2D3432),
            ),
          ),
          const SizedBox(height: 16),
          const Divider(height: 1, color: Color(0x1A757C7A)),
          const SizedBox(height: 14),
          const Row(
            children: [
              CircleAvatar(
                radius: 20,
                backgroundColor: Color(0xFFA2F3D5),
                child: Icon(Icons.storefront, color: Color(0xFF126C55)),
              ),
              SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Kelola informasi publik dan identitas merek Anda di sini.',
                  style: TextStyle(
                    fontSize: 12,
                    color: Color(0xFF59615F),
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _QrisCard extends StatelessWidget {
  const _QrisCard({
    required this.hasQris,
    required this.qrisImageUrl,
    required this.isUploading,
    required this.isPickingImage,
    required this.onTapAction,
  });

  final bool hasQris;
  final String qrisImageUrl;
  final bool isUploading;
  final bool isPickingImage;
  final VoidCallback onTapAction;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        boxShadow: const [
          BoxShadow(
            color: Color(0x0C000000),
            blurRadius: 12,
            offset: Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: hasQris
                      ? const Color(0x19126C55)
                      : const Color(0x1AA83836),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  hasQris ? 'Status: Aktif' : 'Status: Belum Aktif',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    color: hasQris
                        ? const Color(0xFF126C55)
                        : const Color(0xFFA83836),
                  ),
                ),
              ),
              const Spacer(),
              IconButton(
                onPressed: (isUploading || isPickingImage) ? null : onTapAction,
                icon: (isUploading || isPickingImage)
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.edit, color: Color(0xFF126C55)),
              ),
            ],
          ),
          const SizedBox(height: 4),
          const Text(
            'Pembayaran QRIS',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: Color(0xFF2D3432),
            ),
          ),
          const SizedBox(height: 12),
          AspectRatio(
            aspectRatio: 1,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(14),
              child: Container(
                color: const Color(0xFFF1F4F2),
                child: hasQris
                    ? Image.network(
                        qrisImageUrl,
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => const Icon(
                          Icons.qr_code_2,
                          color: Color(0xFF126C55),
                          size: 64,
                        ),
                      )
                    : const Icon(
                        Icons.qr_code_2,
                        color: Color(0xFF7C8481),
                        size: 64,
                      ),
              ),
            ),
          ),
          const SizedBox(height: 10),
          SizedBox(
            width: double.infinity,
            child: hasQris
                ? const Text(
                    'QRIS aktif. Tekan ikon edit untuk mengganti gambar.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 11,
                      color: Color(0xFF5A615F),
                      fontWeight: FontWeight.w500,
                    ),
                  )
                : OutlinedButton.icon(
                    onPressed: isUploading ? null : onTapAction,
                    style: OutlinedButton.styleFrom(
                      side: const BorderSide(color: Color(0xFF126C55)),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                    icon: const Icon(Icons.add_card, color: Color(0xFF126C55)),
                    label: const Text(
                      'Tambahkan metode pembayaran QRIS',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: Color(0xFF126C55),
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
          ),
        ],
      ),
    );
  }
}

class _CategoryAccordion extends StatelessWidget {
  const _CategoryAccordion({
    required this.category,
    required this.products,
    required this.onDeleteCategory,
    required this.onAddProduct,
    required this.onEditProduct,
    required this.onDeleteProduct,
    required this.categoryIcon,
    required this.productIconFromName,
    required this.formatCurrency,
  });

  final _CategoryData category;
  final List<_ProductData> products;
  final VoidCallback onDeleteCategory;
  final VoidCallback onAddProduct;
  final ValueChanged<_ProductData> onEditProduct;
  final ValueChanged<_ProductData> onDeleteProduct;
  final IconData categoryIcon;
  final IconData Function(String name) productIconFromName;
  final String Function(int value) formatCurrency;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(top: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: const [
          BoxShadow(
            color: Color(0x0A000000),
            blurRadius: 10,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: ExpansionTile(
        tilePadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
        collapsedShape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            Icon(categoryIcon, color: const Color(0xFF126C55), size: 24),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                category.name,
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFF2D3432),
                ),
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: const Color(0xFFF1F4F2),
                borderRadius: BorderRadius.circular(999),
              ),
              child: Text(
                '${products.length} Produk',
                style: const TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF59615F),
                ),
              ),
            ),
          ],
        ),
        trailing: IconButton(
          onPressed: onDeleteCategory,
          icon: const Icon(Icons.delete_outline, color: Color(0xFFA83836)),
        ),
        childrenPadding: const EdgeInsets.fromLTRB(12, 0, 12, 14),
        children: [
          const Divider(height: 1, color: Color(0x1A757C7A)),
          const SizedBox(height: 12),
          if (products.isEmpty)
            _AddProductTile(onTap: onAddProduct)
          else
            LayoutBuilder(
              builder: (context, constraints) {
                final width = constraints.maxWidth;
                final crossAxisCount = width >= 980
                    ? 4
                    : width >= 700
                    ? 3
                    : 2;

                return GridView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: products.length + 1,
                  gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: crossAxisCount,
                    mainAxisSpacing: 10,
                    crossAxisSpacing: 10,
                    childAspectRatio: 0.88,
                  ),
                  itemBuilder: (context, index) {
                    if (index == products.length) {
                      return _AddProductTile(onTap: onAddProduct);
                    }

                    final product = products[index];
                    return _ProductCard(
                      product: product,
                      productIcon: productIconFromName(product.iconName),
                      formatCurrency: formatCurrency,
                      onEdit: () => onEditProduct(product),
                      onDelete: () => onDeleteProduct(product),
                    );
                  },
                );
              },
            ),
        ],
      ),
    );
  }
}

class _ProductCard extends StatelessWidget {
  const _ProductCard({
    required this.product,
    required this.productIcon,
    required this.formatCurrency,
    required this.onEdit,
    required this.onDelete,
  });

  final _ProductData product;
  final IconData productIcon;
  final String Function(int value) formatCurrency;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0x1A757C7A)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: Container(
                color: const Color(0xFFF1F4F2),
                width: double.infinity,
                child: product.imageUrl.isNotEmpty
                    ? Image.network(
                        product.imageUrl,
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => Icon(
                          productIcon,
                          size: 36,
                          color: const Color(0xFF8AA39A),
                        ),
                      )
                    : Icon(
                        productIcon,
                        size: 36,
                        color: const Color(0xFF8AA39A),
                      ),
              ),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            product.name,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: Color(0xFF2D3432),
            ),
          ),
          const SizedBox(height: 2),
          Text(
            'Rp ${formatCurrency(product.price)}',
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: Color(0xFF126C55),
            ),
          ),
          const SizedBox(height: 6),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              IconButton(
                onPressed: onEdit,
                icon: const Icon(Icons.edit_outlined, color: Color(0xFF59615F)),
                iconSize: 20,
                visualDensity: VisualDensity.compact,
              ),
              IconButton(
                onPressed: onDelete,
                icon: const Icon(
                  Icons.delete_outline,
                  color: Color(0xFFA83836),
                ),
                iconSize: 20,
                visualDensity: VisualDensity.compact,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _AddProductTile extends StatelessWidget {
  const _AddProductTile({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: const Color(0x4DACB4B1), width: 2),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: const [
            CircleAvatar(
              radius: 18,
              backgroundColor: Color(0xFFF1F4F2),
              child: Icon(Icons.add, color: Color(0xFF126C55)),
            ),
            SizedBox(height: 8),
            Text(
              'Tambah Produk',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: Color(0xFF126C55),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _EmptyDataCard extends StatelessWidget {
  const _EmptyDataCard({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(top: 10),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Center(
        child: Text(
          text,
          textAlign: TextAlign.center,
          style: const TextStyle(
            color: Color(0xFF59615F),
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }
}

class _CategoryData {
  const _CategoryData({
    required this.docId,
    required this.id,
    required this.name,
    required this.iconName,
  });

  final String docId;
  final String id;
  final String name;
  final String iconName;
}

class _ProductData {
  const _ProductData({
    required this.id,
    required this.name,
    required this.categoryId,
    required this.price,
    required this.imageUrl,
    required this.iconName,
    required this.tags,
  });

  final String id;
  final String name;
  final String categoryId;
  final int price;
  final String imageUrl;
  final String iconName;
  final List<String> tags;
}
