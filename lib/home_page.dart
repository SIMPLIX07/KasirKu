import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import 'order_summary_page.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  late Future<_HomeData> _homeDataFuture;
  final Map<String, int> _quantities = <String, int>{};

  @override
  void initState() {
    super.initState();
    _homeDataFuture = _loadHomeData();
  }

  Future<_HomeData> _loadHomeData() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      return const _HomeData(categories: <_CategorySectionData>[]);
    }

    try {
      final firestore = FirebaseFirestore.instance;
      final categoriesSnapshot = await firestore
          .collection('users')
          .doc(user.uid)
          .collection('categories')
          .get();

      QuerySnapshot<Map<String, dynamic>> productsSnapshot;
      try {
        productsSnapshot = await firestore
            .collection('users')
            .doc(user.uid)
            .collection('products')
            .orderBy('createdAt', descending: true)
            .get();
      } on FirebaseException catch (e) {
        if (e.code != 'failed-precondition') {
          rethrow;
        }

        productsSnapshot = await firestore
            .collection('users')
            .doc(user.uid)
            .collection('products')
            .get();
      }

      final categoryById = <String, _CategorySectionData>{};
      final categoryByName = <String, String>{};
      final orderedCategories = <_CategorySectionData>[];

      for (final doc in categoriesSnapshot.docs) {
        final data = doc.data();
        final categoryId = (data['id'] as String? ?? doc.id).trim();
        final categoryName = (data['name'] as String? ?? '').trim();
        if (categoryName.isEmpty) {
          continue;
        }

        final section = _CategorySectionData(
          id: categoryId,
          name: categoryName,
          iconName: (data['icon'] as String? ?? 'restaurant').trim(),
          imageUrl: (data['imageUrl'] as String? ?? '').trim(),
          items: <_MenuItemData>[],
        );
        categoryById[categoryId] = section;
        categoryByName[categoryName.toLowerCase()] = categoryId;
        orderedCategories.add(section);
      }

      final extras = <String, _CategorySectionData>{};

      for (final doc in productsSnapshot.docs) {
        final data = doc.data();
        final productId = doc.id;
        final productName = (data['name'] as String? ?? '').trim();
        final categoryId = (data['categoryId'] as String? ?? '').trim();
        final categoryName = (data['categoryName'] as String? ?? '').trim();
        final price = _readPrice(data['price']);
        if (productName.isEmpty || price == null) {
          continue;
        }

        final item = _MenuItemData(
          id: productId,
          name: productName,
          price: price,
          imageUrl: (data['imageUrl'] as String? ?? '').trim(),
          iconName: (data['icon'] as String? ?? 'fastfood').trim(),
          categoryId: categoryId,
          categoryName: categoryName.isEmpty ? 'Kategori' : categoryName,
        );

        _CategorySectionData? section = categoryById[categoryId];
        if (section == null && categoryName.isNotEmpty) {
          final mappedId = categoryByName[categoryName.toLowerCase()];
          if (mappedId != null) {
            section = categoryById[mappedId];
          }
        }

        section ??= extras.putIfAbsent(
          categoryId.isNotEmpty ? categoryId : categoryName.toLowerCase(),
          () => _CategorySectionData(
            id: categoryId.isNotEmpty ? categoryId : categoryName,
            name: categoryName.isNotEmpty ? categoryName : 'Kategori',
            iconName: 'restaurant',
            imageUrl: '',
            items: <_MenuItemData>[],
          ),
        );

        section.items.add(item);
      }

      final categories = [
        ...orderedCategories,
        ...extras.values,
      ].where((section) => section.items.isNotEmpty).toList();

      return _HomeData(categories: categories);
    } catch (e) {
      debugPrint('[HOME_LOAD_ERROR] $e');
      return const _HomeData(categories: <_CategorySectionData>[]);
    }
  }

  int? _readPrice(dynamic value) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    if (value is String)
      return int.tryParse(value.replaceAll(RegExp(r'[^0-9]'), ''));
    return null;
  }

  void _addItem(_MenuItemData item) {
    setState(() {
      _quantities[item.id] = (_quantities[item.id] ?? 0) + 1;
    });
  }

  void _removeItem(_MenuItemData item) {
    final current = _quantities[item.id] ?? 0;
    if (current <= 0) {
      return;
    }

    setState(() {
      if (current == 1) {
        _quantities.remove(item.id);
      } else {
        _quantities[item.id] = current - 1;
      }
    });
  }

  int get _selectedCount {
    return _quantities.values.fold<int>(0, (sum, value) => sum + value);
  }

  int _totalAmountFor(List<_CategorySectionData> categories) {
    int total = 0;
    for (final category in categories) {
      for (final item in category.items) {
        final quantity = _quantities[item.id] ?? 0;
        total += quantity * item.price;
      }
    }
    return total;
  }

  List<OrderSummaryItem> _selectedOrderItems(
    List<_CategorySectionData> categories,
  ) {
    final result = <OrderSummaryItem>[];
    for (final category in categories) {
      for (final item in category.items) {
        final quantity = _quantities[item.id] ?? 0;
        if (quantity <= 0) {
          continue;
        }
        result.add(
          OrderSummaryItem(
            name: item.name,
            price: item.price,
            quantity: quantity,
            imageUrl: item.imageUrl,
          ),
        );
      }
    }
    return result;
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

  IconData _iconFromName(String name) {
    switch (name) {
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
      case 'coffee':
        return Icons.coffee;
      case 'local_pizza':
        return Icons.local_pizza;
      default:
        return Icons.fastfood;
    }
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<_HomeData>(
      future: _homeDataFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            backgroundColor: Color(0xFFF6F7F7),
            body: Center(
              child: CircularProgressIndicator(color: Color(0xFF3E8E75)),
            ),
          );
        }

        final data =
            snapshot.data ??
            const _HomeData(categories: <_CategorySectionData>[]);
        final totalAmount = _totalAmountFor(data.categories);
        final selectedItems = _selectedOrderItems(data.categories);

        return Scaffold(
          backgroundColor: const Color(0xFFF6F7F7),
          body: Stack(
            children: [
              CustomScrollView(
                slivers: [
                  SliverToBoxAdapter(
                    child: Container(
                      color: Colors.white,
                      padding: const EdgeInsets.fromLTRB(24, 20, 24, 28),
                      child: SafeArea(
                        bottom: false,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                const Text(
                                  'KASIRKU',
                                  style: TextStyle(
                                    fontSize: 20,
                                    fontWeight: FontWeight.w800,
                                    letterSpacing: 3,
                                    color: Color(0xFF206B55),
                                  ),
                                ),
                                CircleAvatar(
                                  radius: 20,
                                  backgroundColor: const Color(0xFFE8F2EE),
                                  child: GestureDetector(
                                    onLongPress: () async {
                                      await FirebaseAuth.instance.signOut();
                                    },
                                    child: const Icon(
                                      Icons.people,
                                      color: Color(0xFF206B55),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 92),
                            const Center(
                              child: Text(
                                'TOTAL TAGIHAN',
                                style: TextStyle(
                                  letterSpacing: 4,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w500,
                                  color: Color(0xFF525B58),
                                ),
                              ),
                            ),
                            const SizedBox(height: 10),
                            Center(
                              child: Text(
                                'Rp ${_formatCurrency(totalAmount)}',
                                style: const TextStyle(
                                  fontSize: 52,
                                  height: 1,
                                  fontWeight: FontWeight.w800,
                                  color: Color(0xFF2D6A4F),
                                ),
                              ),
                            ),
                            const SizedBox(height: 24),
                            Center(
                              child: Wrap(
                                spacing: 12,
                                runSpacing: 12,
                                alignment: WrapAlignment.center,
                                children: [
                                  _BadgePill(
                                    label: '${_selectedCount} Items Selected',
                                    backgroundColor: const Color(0xFFF1F1F1),
                                    textColor: const Color(0xFF3A3F3D),
                                  ),
                                  _BadgePill(
                                    label: 'ORDER #882',
                                    backgroundColor: const Color(0xFFDDF5E6),
                                    textColor: const Color(0xFF206B55),
                                    bold: true,
                                    uppercase: true,
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  SliverToBoxAdapter(
                    child: Transform.translate(
                      offset: const Offset(0, -18),
                      child: Container(
                        decoration: const BoxDecoration(
                          color: Color(0xFFF4F4F4),
                          borderRadius: BorderRadius.vertical(
                            top: Radius.circular(48),
                          ),
                        ),
                        padding: const EdgeInsets.only(top: 26, bottom: 240),
                        child: Column(
                          children: [
                            if (data.categories.isEmpty)
                              const Padding(
                                padding: EdgeInsets.symmetric(
                                  horizontal: 24,
                                  vertical: 80,
                                ),
                                child: Text(
                                  'Belum ada kategori atau produk.',
                                  style: TextStyle(
                                    fontSize: 16,
                                    color: Color(0xFF6B7471),
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              )
                            else
                              ...data.categories.map(
                                (category) => _CategorySection(
                                  title: category.name,
                                  items: category.items,
                                  quantities: _quantities,
                                  onAdd: _addItem,
                                  onRemove: _removeItem,
                                  icon: _iconFromName(category.iconName),
                                  imageUrl: category.imageUrl,
                                ),
                              ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              Positioned(
                left: 0,
                right: 0,
                bottom: 124,
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: Container(
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [Color(0xFF1F5B49), Color(0xFF154B3C)],
                      ),
                      borderRadius: BorderRadius.circular(18),
                      boxShadow: const [
                        BoxShadow(
                          color: Color(0x33154B3C),
                          blurRadius: 18,
                          offset: Offset(0, 8),
                        ),
                      ],
                    ),
                    child: SizedBox(
                      height: 56,
                      child: ElevatedButton.icon(
                        onPressed: selectedItems.isEmpty
                            ? null
                            : () {
                                final transactionId =
                                    (DateTime.now().millisecondsSinceEpoch %
                                                90000 +
                                            10000)
                                        .toString();
                                Navigator.of(context).push(
                                  MaterialPageRoute<void>(
                                    builder: (_) => OrderSummaryPage(
                                      transactionId: transactionId,
                                      items: selectedItems,
                                    ),
                                  ),
                                );
                              },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.transparent,
                          disabledBackgroundColor: Colors.transparent,
                          shadowColor: Colors.transparent,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(18),
                          ),
                        ),
                        icon: const Icon(
                          Icons.payments_outlined,
                          color: Colors.white,
                        ),
                        label: const Text(
                          'Bayar Sekarang',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w800,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              Align(
                alignment: Alignment.bottomCenter,
                child: _BottomNavBar(
                  onLogout: () async {
                    await FirebaseAuth.instance.signOut();
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _HomeData {
  const _HomeData({required this.categories});

  final List<_CategorySectionData> categories;
}

class _CategorySectionData {
  _CategorySectionData({
    required this.id,
    required this.name,
    required this.iconName,
    required this.imageUrl,
    required this.items,
  });

  final String id;
  final String name;
  final String iconName;
  final String imageUrl;
  final List<_MenuItemData> items;
}

class _MenuItemData {
  const _MenuItemData({
    required this.id,
    required this.name,
    required this.price,
    required this.imageUrl,
    required this.iconName,
    required this.categoryId,
    required this.categoryName,
  });

  final String id;
  final String name;
  final int price;
  final String imageUrl;
  final String iconName;
  final String categoryId;
  final String categoryName;
}

class _CategorySection extends StatelessWidget {
  const _CategorySection({
    required this.title,
    required this.items,
    required this.quantities,
    required this.onAdd,
    required this.onRemove,
    required this.icon,
    required this.imageUrl,
  });

  final String title;
  final List<_MenuItemData> items;
  final Map<String, int> quantities;
  final ValueChanged<_MenuItemData> onAdd;
  final ValueChanged<_MenuItemData> onRemove;
  final IconData icon;
  final String imageUrl;

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

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 28),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF111111),
                  ),
                ),
                TextButton(
                  onPressed: () {},
                  child: const Text(
                    'View All',
                    style: TextStyle(
                      color: Color(0xFF3E8E75),
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          SizedBox(
            height: 252,
            child: ListView.separated(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              scrollDirection: Axis.horizontal,
              itemCount: items.length,
              separatorBuilder: (_, __) => const SizedBox(width: 14),
              itemBuilder: (context, index) {
                final item = items[index];
                final quantity = quantities[item.id] ?? 0;
                final hasQuantity = quantity > 0;

                return SizedBox(
                  width: 132,
                  child: InkWell(
                    borderRadius: BorderRadius.circular(18),
                    onTap: () => onAdd(item),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Stack(
                          children: [
                            ClipRRect(
                              borderRadius: BorderRadius.circular(16),
                              child: Container(
                                height: 128,
                                width: 132,
                                color: const Color(0xFFE4E8E6),
                                child: (item.imageUrl.isNotEmpty)
                                    ? Image.network(
                                        item.imageUrl,
                                        fit: BoxFit.cover,
                                        errorBuilder: (_, __, ___) => Center(
                                          child: Icon(
                                            item.iconName.isEmpty
                                                ? Icons.fastfood
                                                : Icons.fastfood,
                                            size: 44,
                                            color: const Color(0xFF8AA39A),
                                          ),
                                        ),
                                      )
                                    : Center(
                                        child: Icon(
                                          item.iconName.isEmpty
                                              ? Icons.fastfood
                                              : Icons.fastfood,
                                          size: 44,
                                          color: const Color(0xFF8AA39A),
                                        ),
                                      ),
                              ),
                            ),
                            if (hasQuantity)
                              Positioned(
                                top: 10,
                                left: 10,
                                child: GestureDetector(
                                  onTap: () => onRemove(item),
                                  child: Container(
                                    width: 24,
                                    height: 24,
                                    decoration: const BoxDecoration(
                                      color: Color(0xFFE94B4B),
                                      shape: BoxShape.circle,
                                    ),
                                    child: const Icon(
                                      Icons.remove,
                                      size: 14,
                                      color: Colors.white,
                                    ),
                                  ),
                                ),
                              ),
                            Positioned(
                              top: 10,
                              right: 10,
                              child: AnimatedSwitcher(
                                duration: const Duration(milliseconds: 150),
                                child: hasQuantity
                                    ? Container(
                                        key: ValueKey<int>(quantity),
                                        width: 24,
                                        height: 24,
                                        decoration: const BoxDecoration(
                                          color: Color(0xFF3E8E75),
                                          shape: BoxShape.circle,
                                        ),
                                        alignment: Alignment.center,
                                        child: Text(
                                          '$quantity',
                                          style: const TextStyle(
                                            fontSize: 11,
                                            fontWeight: FontWeight.w700,
                                            color: Colors.white,
                                          ),
                                        ),
                                      )
                                    : const SizedBox.shrink(
                                        key: ValueKey<String>('empty'),
                                      ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),
                        Text(
                          item.name,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                            color: Color(0xFF2B2B2B),
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Rp ${_formatCurrency(item.price)}',
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w800,
                            color: Color(0xFF206B55),
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _BadgePill extends StatelessWidget {
  const _BadgePill({
    required this.label,
    required this.backgroundColor,
    required this.textColor,
    this.bold = false,
    this.uppercase = false,
  });

  final String label;
  final Color backgroundColor;
  final Color textColor;
  final bool bold;
  final bool uppercase;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        uppercase ? label.toUpperCase() : label,
        style: TextStyle(
          fontSize: 13,
          fontWeight: bold ? FontWeight.w800 : FontWeight.w500,
          color: textColor,
          letterSpacing: uppercase ? 0.8 : 0,
        ),
      ),
    );
  }
}

class _BottomNavBar extends StatelessWidget {
  const _BottomNavBar({required this.onLogout});

  final Future<void> Function() onLogout;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Color(0xFFF8FAF8),
        boxShadow: [
          BoxShadow(
            color: Color(0x14000000),
            blurRadius: 24,
            offset: Offset(0, -6),
          ),
        ],
      ),
      padding: const EdgeInsets.fromLTRB(18, 12, 18, 18),
      child: SafeArea(
        top: false,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: const [
            _NavItem(
              icon: Icons.calculate,
              label: 'REGISTER',
              active: true,
              onTap: _noop,
            ),
            _NavItem(
              icon: Icons.history,
              label: 'HISTORY',
              active: false,
              onTap: _noop,
            ),
            _NavItem(
              icon: Icons.settings,
              label: 'SETTINGS',
              active: false,
              onTap: _noop,
            ),
          ],
        ),
      ),
    );
  }
}

void _noop() {}

class _NavItem extends StatelessWidget {
  const _NavItem({
    required this.icon,
    required this.label,
    required this.active,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final bool active;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color = active ? const Color(0xFF206B55) : const Color(0xFF9AA3A0);

    return InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: color),
            const SizedBox(height: 4),
            Text(
              label,
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w800,
                letterSpacing: 1.3,
                color: color,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
