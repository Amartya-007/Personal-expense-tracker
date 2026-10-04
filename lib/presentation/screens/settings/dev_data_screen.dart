import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/constants/app_colors.dart';
import '../../../services/seed/dev_data_generator.dart';
import '../../providers/transaction_providers.dart';

class DevDataScreen extends ConsumerStatefulWidget {
  const DevDataScreen({super.key});

  @override
  ConsumerState<DevDataScreen> createState() => _DevDataScreenState();
}

class _DevDataScreenState extends ConsumerState<DevDataScreen> {
  bool _isGenerating = false;

  Future<void> _seedData(int count) async {
    setState(() => _isGenerating = true);
    await DevDataGenerator.seedLargeDataset(count);
    setState(() => _isGenerating = false);

    ref.read(transactionListProvider.notifier).fetchInitial();

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Seeded $count transactions successfully!')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Large Dataset Generator'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Performance & Stress Testing',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            const Text(
              'Seed large realistic transaction datasets to verify pagination, search performance, and smooth scrolling without memory leaks.',
              style: TextStyle(color: Colors.grey, fontSize: 13),
            ),
            const SizedBox(height: 24),
            _buildSeedTile('Seed 1,000 Transactions', 1000),
            const SizedBox(height: 12),
            _buildSeedTile('Seed 10,000 Transactions', 10000),
            const SizedBox(height: 12),
            _buildSeedTile('Seed 50,000 Transactions', 50000),
            if (_isGenerating) ...[
              const SizedBox(height: 32),
              const Center(child: CircularProgressIndicator()),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildSeedTile(String label, int count) {
    return Card(
      child: ListTile(
        title: Text(label, style: const TextStyle(fontWeight: FontWeight.bold)),
        subtitle: Text('Inserts $count random indexed transactions'),
        trailing: ElevatedButton(
          style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary, foregroundColor: Colors.white),
          onPressed: _isGenerating ? null : () => _seedData(count),
          child: const Text('Seed'),
        ),
      ),
    );
  }
}
