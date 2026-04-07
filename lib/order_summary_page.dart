import 'package:flutter/material.dart';

import 'transaction_success_page.dart';

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

  Future<void> _showPaymentConfirmationSheet(
    BuildContext context,
    String method,
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
                              child: const Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(
                                    Icons.qr_code_2,
                                    size: 120,
                                    color: Color(0xFF126C55),
                                  ),
                                  SizedBox(height: 8),
                                  Text(
                                    'QR DUMMY',
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
                            ? () {
                                Navigator.of(sheetContext).pop();
                                Navigator.of(context).pushReplacement(
                                  MaterialPageRoute<void>(
                                    builder: (_) => TransactionSuccessPage(
                                      transactionId: transactionId,
                                      totalAmount: _subtotal,
                                      method: isQris ? 'QRIS' : 'Tunai',
                                    ),
                                  ),
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

  Future<void> _showPaymentSheet(BuildContext context) async {
    String? selectedMethod;

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
              required IconData icon,
              required String label,
            }) {
              final selected = selectedMethod == keyName;
              return Expanded(
                child: InkWell(
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
                          child: Icon(
                            icon,
                            size: 58,
                            color: selected
                                ? const Color(0xFFE5FFF4)
                                : const Color(0xFF25302E),
                          ),
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
                        paymentCard(
                          keyName: 'qris',
                          icon: Icons.qr_code_2,
                          label: 'QRIS',
                        ),
                        const SizedBox(width: 14),
                        paymentCard(
                          keyName: 'tunai',
                          icon: Icons.payments,
                          label: 'Tunai',
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
                                _showPaymentConfirmationSheet(context, method);
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
    return Scaffold(
      backgroundColor: const Color(0xFFFFFFFF),
      body: Stack(
        children: [
          SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(24, 48, 24, 180),
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
                const SizedBox(height: 72),
                const Text(
                  'Ringkasan\nPesanan',
                  style: TextStyle(
                    fontSize: 68,
                    fontWeight: FontWeight.w800,
                    height: 0.95,
                    color: Color(0xFF1F2827),
                    letterSpacing: -1.2,
                  ),
                ),
                const SizedBox(height: 20),
                Text(
                  'TRANSAKSI #$transactionId',
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w500,
                    letterSpacing: 1,
                    color: Color(0xFF9AA09E),
                  ),
                ),
                const SizedBox(height: 56),
                ...items.map(
                  (item) => Padding(
                    padding: const EdgeInsets.only(bottom: 34),
                    child: Row(
                      children: [
                        ClipRRect(
                          borderRadius: BorderRadius.circular(16),
                          child: Container(
                            width: 76,
                            height: 76,
                            color: const Color(0xFFECEFF0),
                            child: (item.imageUrl ?? '').isNotEmpty
                                ? Image.network(
                                    item.imageUrl!,
                                    fit: BoxFit.cover,
                                    errorBuilder: (_, __, ___) => const Icon(
                                      Icons.fastfood,
                                      size: 36,
                                      color: Color(0xFF8AA39A),
                                    ),
                                  )
                                : const Icon(
                                    Icons.fastfood,
                                    size: 36,
                                    color: Color(0xFF8AA39A),
                                  ),
                          ),
                        ),
                        const SizedBox(width: 18),
                        Expanded(
                          child: Text(
                            item.name,
                            style: const TextStyle(
                              fontSize: 30,
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
                                fontSize: 24,
                                fontWeight: FontWeight.w700,
                                color: Color(0xFF1F2827),
                              ),
                            ),
                            const SizedBox(height: 4),
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
                const SizedBox(height: 16),
                const Divider(color: Color(0xFFDCE2E0), thickness: 1),
                const SizedBox(height: 24),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Subtotal',
                      style: TextStyle(fontSize: 20, color: Color(0xFF59615F)),
                    ),
                    Text(
                      'Rp ${_formatCurrency(_subtotal)}',
                      style: const TextStyle(
                        fontSize: 20,
                        color: Color(0xFF59615F),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 18),
                const Divider(color: Color(0xFFDCE2E0), thickness: 1),
                const SizedBox(height: 18),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Total',
                      style: TextStyle(
                        fontSize: 30,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF1F2827),
                      ),
                    ),
                    Text(
                      'Rp ${_formatCurrency(_subtotal)}',
                      style: const TextStyle(
                        fontSize: 42,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFF1F2827),
                        letterSpacing: -0.8,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: Container(
              padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
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
                        child: const Text(
                          'Edit Pesanan',
                          style: TextStyle(
                            color: Color(0xFF126C55),
                            fontSize: 20,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: () => _showPaymentSheet(context),
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
                              fontSize: 20,
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
          ),
        ],
      ),
    );
  }
}
