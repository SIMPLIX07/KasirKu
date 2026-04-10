import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import 'transaction_success_page.dart';
import 'local_image_store.dart';

class _BusinessPaymentConfig {
  const _BusinessPaymentConfig({
    required this.qrisEnabled,
    required this.qrisImageUrl,
  });

  final bool qrisEnabled;
  final String qrisImageUrl;
}

class OrderSummaryItem {
  const OrderSummaryItem({
    required this.name,
    required this.price,
    required this.quantity,
    this.imageUrl,
  });

  final String name;
  final int price;
  final int quantity;
  final String? imageUrl;
}

class OrderSummaryPage extends StatelessWidget {
  const OrderSummaryPage({
    super.key,
    required this.transactionId,
    required this.items,
  });

  final String transactionId;
  final List<OrderSummaryItem> items;

  Future<_BusinessPaymentConfig> _loadBusinessPaymentConfig() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      return const _BusinessPaymentConfig(qrisEnabled: false, qrisImageUrl: '');
    }

    try {
      final snapshot = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get();
      final data = snapshot.data();
      return _BusinessPaymentConfig(
        qrisEnabled: data?['qrisEnabled'] as bool? ?? false,
        qrisImageUrl: (data?['qrisImageUrl'] as String? ?? '').trim(),
      );
    } catch (_) {
      return const _BusinessPaymentConfig(qrisEnabled: false, qrisImageUrl: '');
    }
  }

  int get _totalItems {
    return items.fold<int>(0, (sum, item) => sum + item.quantity);
  }

  int get _subtotal {
    return items.fold<int>(
      0,
      (sum, item) => sum + (item.price * item.quantity),
    );
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

  Future<void> _saveTransaction(String method) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      return;
    }

    final firestore = FirebaseFirestore.instance;
    final now = DateTime.now();

    final payload = <String, dynamic>{
      'userId': user.uid,
      'transactionId': transactionId,
      'method': method,
      'totalAmount': _subtotal,
      'totalItems': _totalItems,
      'items': items
          .map(
            (item) => <String, dynamic>{
              'name': item.name,
              'price': item.price,
              'quantity': item.quantity,
              'imageUrl': item.imageUrl ?? '',
            },
          )
          .toList(),
      'createdAt': FieldValue.serverTimestamp(),
      'createdAtMs': now.millisecondsSinceEpoch,
    };

    await firestore
        .collection('users')
        .doc(user.uid)
        .collection('transactions')
        .doc(transactionId)
        .set(payload, SetOptions(merge: true));
  }

  Future<void> _showPaymentConfirmationSheet(
    BuildContext context,
    String method,
    _BusinessPaymentConfig config,
  ) async {
    var cashInput = '';

    int parseCash() {
      return int.tryParse(cashInput.replaceAll('.', '').trim()) ?? 0;
    }

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      barrierColor: const Color(0x660B0F0E),
      builder: (sheetContext) {
        return StatefulBuilder(
          builder: (context, setSheetState) {
            final isQris = method == 'qris';
            final cashAmount = parseCash();
            final isCashEnough = !isQris && cashAmount >= _subtotal;

            return Container(
              decoration: const BoxDecoration(
                color: Color(0xFFFFFFFF),
                borderRadius: BorderRadius.vertical(top: Radius.circular(40)),
              ),
              padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
              child: SafeArea(
                top: false,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        IconButton(
                          onPressed: () => Navigator.of(sheetContext).pop(),
                          icon: const Icon(
                            Icons.close,
                            color: Color(0xFF126C55),
                            size: 34,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          isQris ? 'Scan QRIS' : 'Pembayaran Tunai',
                          style: const TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFF126C55),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    if (isQris) ...[
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF6F8F7),
                          borderRadius: BorderRadius.circular(24),
                        ),
                        child: Column(
                          children: [
                            Container(
                              width: 220,
                              height: 220,
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(20),
                                border: Border.all(
                                  color: const Color(0xFFE0E7E4),
                                ),
                              ),
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(20),
                                child: buildStoredImage(
                                  config.qrisImageUrl,
                                  fit: BoxFit.cover,
                                  fallback: () => const Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Icon(
                                        Icons.qr_code_2,
                                        size: 120,
                                        color: Color(0xFF126C55),
                                      ),
                                      SizedBox(height: 8),
                                      Text(
                                        'QRIS',
                                        style: TextStyle(
                                          fontSize: 12,
                                          fontWeight: FontWeight.w700,
                                          letterSpacing: 1.4,
                                          color: Color(0xFF5F6865),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(height: 14),
                            Text(
                              'Total: Rp ${_formatCurrency(_subtotal)}',
                              style: const TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.w700,
                                color: Color(0xFF25302E),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ] else ...[
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF6F8F7),
                          borderRadius: BorderRadius.circular(24),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Row(
                              children: [
                                Icon(
                                  Icons.payments_rounded,
                                  size: 26,
                                  color: Color(0xFF126C55),
                                ),
                                SizedBox(width: 8),
                                Text(
                                  'Uang Diterima',
                                  style: TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.w700,
                                    color: Color(0xFF25302E),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 14),
                            TextField(
                              keyboardType: TextInputType.number,
                              onChanged: (value) {
                                setSheetState(() => cashInput = value);
                              },
                              decoration: InputDecoration(
                                prefixText: 'Rp ',
                                hintText: 'Masukkan nominal tunai',
                                filled: true,
                                fillColor: Colors.white,
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(16),
                                  borderSide: const BorderSide(
                                    color: Color(0xFFD2DBD8),
                                  ),
                                ),
                                enabledBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(16),
                                  borderSide: const BorderSide(
                                    color: Color(0xFFD2DBD8),
                                  ),
                                ),
                                focusedBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(16),
                                  borderSide: const BorderSide(
                                    color: Color(0xFF126C55),
                                    width: 1.4,
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(height: 12),
                            Text(
                              'Total tagihan: Rp ${_formatCurrency(_subtotal)}',
                              style: const TextStyle(
                                fontSize: 14,
                                color: Color(0xFF606866),
                              ),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              cashAmount > 0
                                  ? 'Kembalian: Rp ${_formatCurrency(cashAmount - _subtotal < 0 ? 0 : cashAmount - _subtotal)}'
                                  : 'Kembalian: Rp 0',
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w700,
                                color: Color(0xFF126C55),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                    const SizedBox(height: 18),
                    const Text(
                      'Sudah dibayar?',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF25302E),
                      ),
                    ),
                    const SizedBox(height: 12),
                    SizedBox(
                      width: double.infinity,
                      height: 56,
                      child: ElevatedButton(
                        onPressed: isQris || isCashEnough
                            ? () async {
                                final method = isQris ? 'QRIS' : 'Tunai';
                                final sheetNavigator = Navigator.of(
                                  sheetContext,
                                );
                                final pageNavigator = Navigator.of(context);
                                final messenger = ScaffoldMessenger.of(context);

                                try {
                                  await _saveTransaction(method);
                                } catch (e) {
                                  messenger.showSnackBar(
                                    SnackBar(
                                      content: Text(
                                        'Gagal menyimpan transaksi: $e',
                                      ),
                                      behavior: SnackBarBehavior.floating,
                                    ),
                                  );
                                  return;
                                }

                                sheetNavigator.pop();
                                pageNavigator.pushReplacement<void, bool>(
                                  MaterialPageRoute<void>(
                                    builder: (_) => TransactionSuccessPage(
                                      transactionId: transactionId,
                                      totalAmount: _subtotal,
                                      method: method,
                                    ),
                                  ),
                                  result: true,
                                );
                              }
                            : null,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF2D5A4C),
                          disabledBackgroundColor: const Color(0xFFA9B8B3),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(22),
                          ),
                        ),
                        child: const Text(
                          'Sudah',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 18,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 1.2,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  Future<void> _showPaymentSheet(
    BuildContext context,
    _BusinessPaymentConfig config,
  ) async {
    String? selectedMethod = config.qrisEnabled ? null : 'tunai';

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      barrierColor: const Color(0x660B0F0E),
      builder: (sheetContext) {
        return StatefulBuilder(
          builder: (context, setSheetState) {
            Widget paymentCard({
              required String keyName,
              required Widget visual,
              required String label,
            }) {
              final selected = selectedMethod == keyName;
              return InkWell(
                borderRadius: BorderRadius.circular(28),
                onTap: () => setSheetState(() => selectedMethod = keyName),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 180),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 18,
                  ),
                  decoration: BoxDecoration(
                    color: selected
                        ? const Color(0xFF14775C)
                        : const Color(0xFFFFFFFF),
                    borderRadius: BorderRadius.circular(28),
                    border: Border.all(
                      color: const Color(0xFFE3E8E6),
                      width: selected ? 0 : 1.2,
                    ),
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 118,
                        height: 118,
                        decoration: BoxDecoration(
                          color: selected
                              ? const Color(0xFF4AA28B)
                              : const Color(0xFFD5DAD8),
                          borderRadius: BorderRadius.circular(30),
                        ),
                        child: visual,
                      ),
                      const SizedBox(height: 18),
                      Text(
                        label,
                        style: TextStyle(
                          fontSize: 44 / 2,
                          fontWeight: FontWeight.w700,
                          color: selected
                              ? const Color(0xFFE5FFF4)
                              : const Color(0xFF25302E),
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }

            return Container(
              decoration: const BoxDecoration(
                color: Color(0xFFFFFFFF),
                borderRadius: BorderRadius.vertical(top: Radius.circular(40)),
              ),
              padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
              child: SafeArea(
                top: false,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        IconButton(
                          onPressed: () => Navigator.of(sheetContext).pop(),
                          icon: const Icon(
                            Icons.close,
                            color: Color(0xFF126C55),
                            size: 34,
                          ),
                        ),
                        const SizedBox(width: 8),
                        const Text(
                          'Mau bayar dengan apa?',
                          style: TextStyle(
                            fontSize: 48 / 2,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFF126C55),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        if (config.qrisEnabled) ...[
                          Expanded(
                            child: paymentCard(
                              keyName: 'qris',
                              label: 'QRIS',
                              visual: Icon(
                                Icons.qr_code_2,
                                size: 58,
                                color: selectedMethod == 'qris'
                                    ? const Color(0xFFE5FFF4)
                                    : const Color(0xFF25302E),
                              ),
                            ),
                          ),
                          const SizedBox(width: 14),
                        ],
                        Expanded(
                          child: paymentCard(
                            keyName: 'tunai',
                            label: 'Tunai',
                            visual: Icon(
                              Icons.payments,
                              size: 58,
                              color: selectedMethod == 'tunai'
                                  ? const Color(0xFFE5FFF4)
                                  : const Color(0xFF25302E),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),
                    Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF0F3F2),
                        borderRadius: BorderRadius.circular(22),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'TOTAL PEMBAYARAN',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w800,
                                  letterSpacing: 2,
                                  color: Color(0xFF606866),
                                ),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                'Rp ${_formatCurrency(_subtotal)}',
                                style: const TextStyle(
                                  fontSize: 46 / 2,
                                  fontWeight: FontWeight.w800,
                                  color: Color(0xFF25302E),
                                ),
                              ),
                            ],
                          ),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              const Text(
                                'ITEMS',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w800,
                                  letterSpacing: 2,
                                  color: Color(0xFF606866),
                                ),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                '$_totalItems Produk',
                                style: const TextStyle(
                                  fontSize: 20,
                                  fontWeight: FontWeight.w600,
                                  color: Color(0xFF25302E),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),
                    SizedBox(
                      width: double.infinity,
                      height: 56,
                      child: ElevatedButton(
                        onPressed: selectedMethod == null
                            ? null
                            : () {
                                final method = selectedMethod;
                                if (method == null) {
                                  return;
                                }
                                Navigator.of(sheetContext).pop();
                                _showPaymentConfirmationSheet(
                                  context,
                                  method,
                                  config,
                                );
                              },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF2D5A4C),
                          disabledBackgroundColor: const Color(0xFFA9B8B3),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(22),
                          ),
                        ),
                        child: const Text(
                          'Lanjutkan',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 36 / 2,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 1.8,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<_BusinessPaymentConfig>(
      future: _loadBusinessPaymentConfig(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            backgroundColor: Color(0xFFFFFFFF),
            body: Center(
              child: CircularProgressIndicator(color: Color(0xFF126C55)),
            ),
          );
        }

        final config =
            snapshot.data ??
            const _BusinessPaymentConfig(qrisEnabled: false, qrisImageUrl: '');

        return Scaffold(
          backgroundColor: const Color(0xFFFFFFFF),
          body: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(24, 48, 24, 48),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'KASIRKU',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF126C55),
                  ),
                ),
                const SizedBox(height: 32),
                const Text(
                  'Ringkasan\nPesanan',
                  style: TextStyle(
                    fontSize: 42,
                    fontWeight: FontWeight.w800,
                    height: 1.1,
                    color: Color(0xFF1F2827),
                    letterSpacing: -0.5,
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  'TRANSAKSI #$transactionId',
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    letterSpacing: 0.5,
                    color: Color(0xFF9AA09E),
                  ),
                ),
                const SizedBox(height: 32),
                ...items.map(
                  (item) => Padding(
                    padding: const EdgeInsets.only(bottom: 24),
                    child: Row(
                      children: [
                        ClipRRect(
                          borderRadius: BorderRadius.circular(12),
                          child: Container(
                            width: 64,
                            height: 64,
                            color: const Color(0xFFECEFF0),
                            child: buildStoredImage(
                              item.imageUrl ?? '',
                              fit: BoxFit.cover,
                              fallback: () => const Icon(
                                Icons.fastfood,
                                size: 28,
                                color: Color(0xFF8AA39A),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Text(
                            item.name,
                            style: const TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.w600,
                              color: Color(0xFF1F2827),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Text(
                              'Rp ${_formatCurrency(item.price)}',
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w700,
                                color: Color(0xFF1F2827),
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              'x${item.quantity}',
                              style: const TextStyle(
                                fontSize: 16,
                                color: Color(0xFF6F7775),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                const Divider(color: Color(0xFFDCE2E0), thickness: 1),
                const SizedBox(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Subtotal',
                      style: TextStyle(fontSize: 14, color: Color(0xFF59615F)),
                    ),
                    Text(
                      'Rp ${_formatCurrency(_subtotal)}',
                      style: const TextStyle(
                        fontSize: 14,
                        color: Color(0xFF59615F),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                const Divider(color: Color(0xFFDCE2E0), thickness: 1),
                const SizedBox(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Total',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF1F2827),
                      ),
                    ),
                    Text(
                      'Rp ${_formatCurrency(_subtotal)}',
                      style: const TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFF1F2827),
                        letterSpacing: -0.5,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          bottomNavigationBar: Container(
            padding: const EdgeInsets.fromLTRB(24, 16, 24, 8),
            decoration: const BoxDecoration(
              color: Color(0xFFFFFFFF),
              border: Border(top: BorderSide(color: Color(0xFFDCE2E0))),
            ),
            child: SafeArea(
              top: false,
              child: Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.of(context).pop(),
                      style: OutlinedButton.styleFrom(
                        side: const BorderSide(
                          color: Color(0xFF126C55),
                          width: 2,
                        ),
                        minimumSize: const Size(0, 56),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(20),
                        ),
                      ),
                      child: const FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Text(
                          'Edit Pesanan',
                          maxLines: 1,
                          softWrap: false,
                          overflow: TextOverflow.visible,
                          style: TextStyle(
                            color: Color(0xFF126C55),
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () => _showPaymentSheet(context, config),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF126C55),
                        minimumSize: const Size(0, 56),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(20),
                        ),
                      ),
                      child: const FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Text(
                          'Bayar Sekarang',
                          maxLines: 1,
                          softWrap: false,
                          overflow: TextOverflow.visible,
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
