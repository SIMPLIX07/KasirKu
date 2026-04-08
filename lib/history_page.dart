import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

class HistoryPage extends StatefulWidget {
  const HistoryPage({super.key});

  @override
  State<HistoryPage> createState() => _HistoryPageState();
}

class _HistoryPageState extends State<HistoryPage> {
  static const List<String> _filters = <String>[
    'Hari Ini',
    'Kemarin',
    '7 Hari Terakhir',
    'Pilih Tanggal',
  ];

  String _selectedFilter = '7 Hari Terakhir';

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;

    if (user == null) {
      return const Scaffold(
        backgroundColor: Colors.white,
        body: Center(
          child: Text(
            'Silakan login untuk melihat riwayat transaksi.',
            style: TextStyle(fontSize: 16, color: Color(0xFF59615F)),
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text(
          'KASIRKU',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w800,
            letterSpacing: 2,
            color: Color(0xFF1B6A50),
          ),
        ),
        backgroundColor: Colors.white,
        elevation: 0,
        scrolledUnderElevation: 0,
      ),
      body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .collection('transactions')
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(
              child: CircularProgressIndicator(color: Color(0xFF126C55)),
            );
          }

          final docs =
              snapshot.data?.docs ??
              const <QueryDocumentSnapshot<Map<String, dynamic>>>[];
          final allTransactions =
              docs
                  .map(_TransactionEntry.fromDocument)
                  .whereType<_TransactionEntry>()
                  .toList()
                ..sort((a, b) => b.createdAt.compareTo(a.createdAt));

          final filteredTransactions = _applyFilter(allTransactions);
          final grouped = _groupByDate(filteredTransactions);
          final summary = _buildMonthlySummary(allTransactions);

          return SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(24, 16, 24, 160),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Riwayat Transaksi',
                  style: TextStyle(
                    fontSize: 32,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF2D3432),
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Tinjau kurasi transaksi harian Anda.',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                    color: Color(0xFF59615F),
                  ),
                ),
                const SizedBox(height: 24),
                _buildFilterRow(),
                const SizedBox(height: 28),
                if (filteredTransactions.isEmpty)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 32),
                    child: Center(
                      child: Text(
                        'Belum ada transaksi pada filter ini.',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w500,
                          color: Color(0xFF6B7471),
                        ),
                      ),
                    ),
                  )
                else
                  ...grouped.entries.map((entry) {
                    final group = entry.value;
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 30),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _groupTitle(group.date),
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 2,
                              color: Color(0xFF757C7A),
                            ),
                          ),
                          const SizedBox(height: 14),
                          ...group.transactions.map(
                            (transaction) => Padding(
                              padding: const EdgeInsets.only(bottom: 12),
                              child: _buildTransactionCard(transaction),
                            ),
                          ),
                        ],
                      ),
                    );
                  }),
                _buildPopularMethodCard(filteredTransactions),
                const SizedBox(height: 20),
                _buildSummaryCard(summary),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildFilterRow() {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          ..._filters.map((filter) {
            final isSelected = _selectedFilter == filter;
            return Padding(
              padding: const EdgeInsets.only(right: 8),
              child: ActionChip(
                onPressed: () => setState(() => _selectedFilter = filter),
                label: Text(
                  filter,
                  style: TextStyle(
                    color: isSelected
                        ? const Color(0xFFE4FFF2)
                        : const Color(0xFF59615F),
                    fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                  ),
                ),
                backgroundColor: isSelected
                    ? const Color(0xFF126C55)
                    : const Color(0xFFF1F4F2),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20),
                ),
                side: BorderSide.none,
              ),
            );
          }),
          const SizedBox(width: 8),
          IconButton(
            onPressed: () {},
            icon: const Icon(Icons.filter_list),
            color: const Color(0xFF59615F),
            style: IconButton.styleFrom(
              backgroundColor: const Color(0xFFF1F4F2),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTransactionCard(_TransactionEntry transaction) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF126C55).withValues(alpha: 0.04),
            blurRadius: 40,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: Row(
              children: [
                Container(
                  width: 56,
                  height: 56,
                  decoration: BoxDecoration(
                    color: const Color(0xFFF1F4F2),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Icon(
                    _iconByMethod(transaction.method),
                    color: const Color(0xFF126C55),
                    size: 28,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Transaksi #${transaction.transactionId}',
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF2D3432),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${_timeText(transaction.createdAt)} - ${transaction.totalItems} Item - Pembayaran ${transaction.method}',
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                          color: Color(0xFF59615F),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 16),
          Text(
            'Rp ${_formatCurrency(transaction.totalAmount)}',
            style: const TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w800,
              color: Color(0xFF2D3432),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPopularMethodCard(List<_TransactionEntry> transactions) {
    final methodCount = <String, int>{};
    for (final transaction in transactions) {
      methodCount.update(
        transaction.method,
        (value) => value + 1,
        ifAbsent: () => 1,
      );
    }

    if (methodCount.isEmpty) {
      return const SizedBox.shrink();
    }

    final sorted = methodCount.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    final top = sorted.first;
    final percent = ((top.value / transactions.length) * 100).round();

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFFF1F4F2),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        children: [
          const Icon(Icons.qr_code_2, color: Color(0xFF126C55), size: 32),
          const SizedBox(width: 16),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'METODE TERPOPULER',
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 1.5,
                  color: Color(0xFF757C7A),
                ),
              ),
              Text(
                '${top.key.toUpperCase()} ($percent%)',
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFF126C55),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryCard(_MonthlySummary summary) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: const Color(0xFFF1F4F2),
        borderRadius: BorderRadius.circular(24),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'RINGKASAN BULAN INI',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w800,
              letterSpacing: 1.5,
              color: Color(0xFF126C55),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Rp ${_formatCurrency(summary.currentMonthTotal)}',
            style: const TextStyle(
              fontSize: 48,
              fontWeight: FontWeight.w800,
              height: 1.1,
              color: Color(0xFF2D3432),
            ),
          ),
          const SizedBox(height: 8),
          if (summary.hasComparison)
            Row(
              children: [
                Icon(
                  summary.percentChange >= 0
                      ? Icons.trending_up
                      : Icons.trending_down,
                  color: const Color(0xFF126C55),
                  size: 20,
                ),
                const SizedBox(width: 4),
                Expanded(
                  child: Text(
                    '${summary.percentText} dari bulan lalu',
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF126C55),
                    ),
                  ),
                ),
              ],
            )
          else
            Row(
              children: [
                const Icon(Icons.info, color: Color(0xFF126C55), size: 20),
                const SizedBox(width: 4),
                const Expanded(
                  child: Text(
                    'Belum cukup data 2 bulan untuk perbandingan',
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF126C55),
                    ),
                  ),
                ),
              ],
            ),
        ],
      ),
    );
  }

  List<_TransactionEntry> _applyFilter(List<_TransactionEntry> source) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final yesterday = today.subtract(const Duration(days: 1));

    switch (_selectedFilter) {
      case 'Hari Ini':
        return source.where((t) => _sameDate(t.createdAt, today)).toList();
      case 'Kemarin':
        return source.where((t) => _sameDate(t.createdAt, yesterday)).toList();
      case '7 Hari Terakhir':
        final start = today.subtract(const Duration(days: 6));
        return source
            .where(
              (t) => !DateTime(
                t.createdAt.year,
                t.createdAt.month,
                t.createdAt.day,
              ).isBefore(start),
            )
            .toList();
      case 'Pilih Tanggal':
      default:
        return source;
    }
  }

  Map<String, _DateGroup> _groupByDate(List<_TransactionEntry> transactions) {
    final groups = <String, _DateGroup>{};
    for (final transaction in transactions) {
      final key = _dateKey(transaction.createdAt);
      groups.putIfAbsent(
        key,
        () => _DateGroup(
          date: DateTime(
            transaction.createdAt.year,
            transaction.createdAt.month,
            transaction.createdAt.day,
          ),
          transactions: <_TransactionEntry>[],
        ),
      );
      groups[key]!.transactions.add(transaction);
    }
    return groups;
  }

  _MonthlySummary _buildMonthlySummary(List<_TransactionEntry> transactions) {
    final now = DateTime.now();
    final monthTotals = <String, int>{};

    for (final t in transactions) {
      final key =
          '${t.createdAt.year}-${t.createdAt.month.toString().padLeft(2, '0')}';
      monthTotals.update(
        key,
        (value) => value + t.totalAmount,
        ifAbsent: () => t.totalAmount,
      );
    }

    final currentKey = '${now.year}-${now.month.toString().padLeft(2, '0')}';
    final prevMonth = DateTime(now.year, now.month - 1, 1);
    final prevKey =
        '${prevMonth.year}-${prevMonth.month.toString().padLeft(2, '0')}';

    final currentTotal = monthTotals[currentKey] ?? 0;
    final prevTotal = monthTotals[prevKey] ?? 0;
    final monthCount = monthTotals.keys.length;

    if (monthCount < 2 || prevTotal == 0) {
      return _MonthlySummary(
        currentMonthTotal: currentTotal,
        hasComparison: false,
        percentChange: 0,
      );
    }

    final percent = ((currentTotal - prevTotal) / prevTotal) * 100;
    return _MonthlySummary(
      currentMonthTotal: currentTotal,
      hasComparison: true,
      percentChange: percent,
    );
  }

  String _groupTitle(DateTime date) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final yesterday = today.subtract(const Duration(days: 1));

    if (_sameDate(date, today)) {
      return 'HARI INI - ${_fullDate(date).toUpperCase()}';
    }
    if (_sameDate(date, yesterday)) {
      return 'KEMARIN - ${_fullDate(date).toUpperCase()}';
    }
    return _fullDate(date).toUpperCase();
  }

  IconData _iconByMethod(String method) {
    final value = method.toLowerCase();
    if (value.contains('qris')) return Icons.qr_code_2;
    if (value.contains('tunai')) return Icons.payments;
    return Icons.receipt_long;
  }

  String _timeText(DateTime date) {
    final h = date.hour.toString().padLeft(2, '0');
    final m = date.minute.toString().padLeft(2, '0');
    return '$h:$m';
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

  String _dateKey(DateTime date) {
    final month = date.month.toString().padLeft(2, '0');
    final day = date.day.toString().padLeft(2, '0');
    return '${date.year}-$month-$day';
  }

  String _fullDate(DateTime date) {
    const months = <String>[
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'Mei',
      'Jun',
      'Jul',
      'Agu',
      'Sep',
      'Okt',
      'Nov',
      'Des',
    ];
    final month = months[date.month - 1];
    return '${date.day.toString().padLeft(2, '0')} $month ${date.year}';
  }

  bool _sameDate(DateTime a, DateTime b) {
    return a.year == b.year && a.month == b.month && a.day == b.day;
  }
}

class _TransactionEntry {
  const _TransactionEntry({
    required this.transactionId,
    required this.method,
    required this.totalAmount,
    required this.totalItems,
    required this.createdAt,
  });

  final String transactionId;
  final String method;
  final int totalAmount;
  final int totalItems;
  final DateTime createdAt;

  static _TransactionEntry? fromDocument(
    QueryDocumentSnapshot<Map<String, dynamic>> doc,
  ) {
    final data = doc.data();

    final id = (data['transactionId'] as String? ?? doc.id).trim();
    if (id.isEmpty) {
      return null;
    }

    final method = (data['method'] as String? ?? 'Tunai').trim();
    final totalAmount = _readInt(data['totalAmount']);
    final totalItems = _readInt(data['totalItems']);

    final createdAtField = data['createdAt'];
    DateTime createdAt;
    if (createdAtField is Timestamp) {
      createdAt = createdAtField.toDate();
    } else {
      final ms = _readInt(data['createdAtMs']);
      createdAt = ms > 0
          ? DateTime.fromMillisecondsSinceEpoch(ms)
          : DateTime.now();
    }

    return _TransactionEntry(
      transactionId: id,
      method: method,
      totalAmount: totalAmount,
      totalItems: totalItems,
      createdAt: createdAt,
    );
  }

  static int _readInt(dynamic value) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    if (value is String) {
      return int.tryParse(value.replaceAll(RegExp(r'[^0-9]'), '')) ?? 0;
    }
    return 0;
  }
}

class _DateGroup {
  _DateGroup({required this.date, required this.transactions});

  final DateTime date;
  final List<_TransactionEntry> transactions;
}

class _MonthlySummary {
  const _MonthlySummary({
    required this.currentMonthTotal,
    required this.hasComparison,
    required this.percentChange,
  });

  final int currentMonthTotal;
  final bool hasComparison;
  final double percentChange;

  String get percentText {
    final sign = percentChange >= 0 ? '+' : '';
    return '$sign${percentChange.toStringAsFixed(1)}%';
  }
}
