import 'package:flutter/material.dart';
import '../../core/constants/app_colors.dart';

class FabActionSheet extends StatelessWidget {
  final Function(String type) onSelectType;

  const FabActionSheet({
    super.key,
    required this.onSelectType,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: const BoxDecoration(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.grey.shade400,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 16),
          const Text(
            'Add New Record',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 20),
          _buildActionTile(
            context,
            title: 'Expense',
            subtitle: 'Money going out',
            icon: Icons.arrow_upward,
            color: AppColors.expense,
            type: 'expense',
          ),
          const SizedBox(height: 10),
          _buildActionTile(
            context,
            title: 'Income',
            subtitle: 'Money coming in',
            icon: Icons.arrow_downward,
            color: AppColors.income,
            type: 'income',
          ),
          const SizedBox(height: 10),
          _buildActionTile(
            context,
            title: 'Transfer',
            subtitle: 'Move money between accounts',
            icon: Icons.swap_horiz,
            color: AppColors.transfer,
            type: 'transfer',
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }

  Widget _buildActionTile(
    BuildContext context, {
    required String title,
    required String subtitle,
    required IconData icon,
    required Color color,
    required String type,
  }) {
    return Card(
      elevation: 0,
      color: color.withValues(alpha: 0.08),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: color.withValues(alpha: 0.3)),
      ),
      child: ListTile(
        onTap: () {
          Navigator.pop(context);
          onSelectType(type);
        },
        leading: CircleAvatar(
          backgroundColor: color,
          child: Icon(icon, color: Colors.white, size: 20),
        ),
        title: Text(title, style: TextStyle(fontWeight: FontWeight.bold, color: color)),
        subtitle: Text(subtitle, style: const TextStyle(fontSize: 12)),
        trailing: Icon(Icons.chevron_right, color: color),
      ),
    );
  }
}
