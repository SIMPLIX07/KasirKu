import 'package:flutter/material.dart';

class TransactionSuccessPage extends StatelessWidget {
  const TransactionSuccessPage({
    super.key,
    required this.transactionId,
    required this.totalAmount,
    required this.method,
  });

  final String transactionId;
  final int totalAmount;
  final String method;

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
    return Scaffold(
      backgroundColor: const Color(0xFFF2F4F3),
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 4),
              child: Row(
                children: [
                  IconButton(
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(
                      Icons.close,
                      color: Color(0xFF3E8E75),
                      size: 34,
                    ),
                  ),
                  const Expanded(
                    child: Text(
                      'Transaction Success',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF202A29),
                      ),
                    ),
                  ),
                  const SizedBox(width: 48),
                ],
              ),
            ),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    const SizedBox(height: 28),
                    const Text('🥳', style: TextStyle(fontSize: 130)),
                    const SizedBox(height: 28),
                    const Text(
                      'Yeyyy Transaksi kamu\nberhasil!',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 54 / 2,
                        height: 1.2,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFF1E2827),
                      ),
                    ),
                    const SizedBox(height: 20),
                    const Text(
                      'Pembayaran telah diterima dengan\nsukses.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 20,
                        height: 1.45,
                        fontWeight: FontWeight.w500,
                        color: Color(0xFF5E6664),
                      ),
                    ),
                    const SizedBox(height: 42),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.fromLTRB(22, 24, 22, 24),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF7F8F8),
                        borderRadius: BorderRadius.circular(24),
                        border: Border.all(color: const Color(0xFFDCE3E0)),
                      ),
                      child: Column(
                        children: [
                          const Text(
                            'TOTAL TRANSAKSI',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 4,
                              color: Color(0xFF5E6664),
                            ),
                          ),
                          const SizedBox(height: 12),
                          Text(
                            'Rp ${_formatCurrency(totalAmount)}',
                            style: const TextStyle(
                              fontSize: 60,
                              fontWeight: FontWeight.w800,
                              color: Color(0xFF0F735A),
                              letterSpacing: -1,
                            ),
                          ),
                          const SizedBox(height: 20),
                          const Divider(color: Color(0xFFDDE3E1), height: 1),
                          const SizedBox(height: 18),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text(
                                    'ID TRANSAKSI',
                                    style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w700,
                                      letterSpacing: 1.8,
                                      color: Color(0xFF929997),
                                    ),
                                  ),
                                  const SizedBox(height: 6),
                                  Text(
                                    '#$transactionId',
                                    style: const TextStyle(
                                      fontSize: 17,
                                      fontWeight: FontWeight.w700,
                                      color: Color(0xFF1E2827),
                                    ),
                                  ),
                                ],
                              ),
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.end,
                                children: [
                                  const Text(
                                    'METODE',
                                    style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w700,
                                      letterSpacing: 1.8,
                                      color: Color(0xFF929997),
                                    ),
                                  ),
                                  const SizedBox(height: 6),
                                  Text(
                                    method.toUpperCase(),
                                    style: const TextStyle(
                                      fontSize: 17,
                                      fontWeight: FontWeight.w700,
                                      color: Color(0xFF1E2827),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 54),
                    SizedBox(
                      width: double.infinity,
                      height: 62,
                      child: ElevatedButton(
                        onPressed: () => Navigator.of(context).pop(),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF0E745A),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(20),
                          ),
                          elevation: 8,
                          shadowColor: const Color(0x550E745A),
                        ),
                        child: const Text(
                          'Kembali ke Menu Utama',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 21,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
