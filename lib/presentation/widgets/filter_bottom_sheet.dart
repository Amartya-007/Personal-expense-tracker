import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../core/constants/app_colors.dart';

class FilterBottomSheet extends StatefulWidget {
  final String? initialType;
  final String? initialPaymentMethod;
  final Function({String? type, String? paymentMethod, String? dateFilter}) onApply;
  final VoidCallback onReset;

  const FilterBottomSheet({
    super.key,
    this.initialType,
    this.initialPaymentMethod,
    required this.onApply,
    required this.onReset,
  });

  @override
  State<FilterBottomSheet> createState() => _FilterBottomSheetState();
}

class _FilterBottomSheetState extends State<FilterBottomSheet> {
  String _dateFilter = 'All';
  String _paymentMethod = 'All';
  String _type = 'All';

  @override
  void initState() {
    super.initState();
    if (widget.initialType != null) {
      _type = widget.initialType!.capitalize();
    }
    if (widget.initialPaymentMethod != null) {
      _paymentMethod = widget.initialPaymentMethod!;
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      decoration: BoxDecoration(
        color: isDark ? AppColors.surfaceDark : AppColors.surfaceLight,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
      ),
      padding: const EdgeInsets.fromLTRB(20, 14, 20, 28),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 5,
                decoration: BoxDecoration(
                  color: isDark ? AppColors.borderDark : AppColors.borderLight,
                  borderRadius: BorderRadius.circular(3),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'Filters',
              style: GoogleFonts.sora(fontSize: 18, fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 16),

            // Date section
            _buildSectionTitle('Date', isDark),
            const SizedBox(height: 8),
            _buildChips(
              ['All', 'Today', 'This Week', 'This Month', 'Last Month'],
              _dateFilter,
              (val) => setState(() => _dateFilter = val),
              isDark,
            ),
            const SizedBox(height: 16),

            // Payment section
            _buildSectionTitle('Payment', isDark),
            const SizedBox(height: 8),
            _buildChips(
              ['All', 'UPI', 'Cash', 'Debit Card'],
              _paymentMethod,
              (val) => setState(() => _paymentMethod = val),
              isDark,
            ),
            const SizedBox(height: 16),

            // Type section
            _buildSectionTitle('Type', isDark),
            const SizedBox(height: 8),
            _buildChips(
              ['All', 'Expense', 'Income', 'Transfer'],
              _type,
              (val) => setState(() => _type = val),
              isDark,
            ),
            const SizedBox(height: 24),

            // Buttons
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    style: OutlinedButton.styleFrom(
                      backgroundColor: isDark ? AppColors.surface2Dark : AppColors.surface2Light,
                      side: BorderSide.none,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
                    ),
                    onPressed: () {
                      setState(() {
                        _dateFilter = 'All';
                        _paymentMethod = 'All';
                        _type = 'All';
                      });
                      widget.onReset();
                      Navigator.pop(context);
                    },
                    child: Text(
                      'Reset',
                      style: GoogleFonts.sora(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: isDark ? AppColors.textPrimaryDark : AppColors.textPrimaryLight,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
                    ),
                    onPressed: () {
                      widget.onApply(
                        type: _type == 'All' ? null : _type.toLowerCase(),
                        paymentMethod: _paymentMethod == 'All' ? null : _paymentMethod,
                        dateFilter: _dateFilter == 'All' ? null : _dateFilter,
                      );
                      Navigator.pop(context);
                    },
                    child: Text(
                      'Show results',
                      style: GoogleFonts.sora(fontSize: 15, fontWeight: FontWeight.w800),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionTitle(String title, bool isDark) {
    return Text(
      title,
      style: GoogleFonts.sora(
        fontSize: 14,
        fontWeight: FontWeight.w700,
        color: isDark ? AppColors.textPrimaryDark : AppColors.textPrimaryLight,
      ),
    );
  }

  Widget _buildChips(List<String> options, String current, ValueChanged<String> onSelected, bool isDark) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: options.map((opt) {
        final isSelected = opt == current;
        return GestureDetector(
          onTap: () => onSelected(opt),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 9),
            decoration: BoxDecoration(
              color: isSelected
                  ? (isDark ? AppColors.primaryDark : AppColors.primary)
                  : (isDark ? AppColors.surfaceDark : AppColors.surfaceLight),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: isSelected
                    ? Colors.transparent
                    : (isDark ? AppColors.borderDark : AppColors.borderLight),
              ),
              boxShadow: isSelected
                  ? [
                      BoxShadow(
                        color: (isDark ? AppColors.primaryDark : AppColors.primary).withValues(alpha: 0.3),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ]
                  : null,
            ),
            child: Text(
              opt,
              style: GoogleFonts.sora(
                fontSize: 12.5,
                fontWeight: FontWeight.w600,
                color: isSelected
                    ? (isDark ? const Color(0xFF12102E) : Colors.white)
                    : (isDark ? AppColors.textPrimaryDark : AppColors.textPrimaryLight),
              ),
            ),
          ),
        );
      }).toList(),
    );
  }
}

extension StringExtension on String {
  String capitalize() {
    if (isEmpty) return this;
    return '${this[0].toUpperCase()}${substring(1)}';
  }
}

