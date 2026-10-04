import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/theme/app_palette.dart';
import '../../../core/theme/app_text.dart';
import '../../../data/models/category_model.dart';
import '../../providers/category_providers.dart';
import '../../widgets/app_sheets.dart';
import '../../widgets/list_widgets.dart';

class CategoriesManagementScreen extends ConsumerWidget {
  const CategoriesManagementScreen({super.key});

  Future<void> _add(
    BuildContext context,
    WidgetRef ref,
    int existingCount,
  ) async {
    final result = await AppBottomSheet.show<({String name, String type})>(
      context,
      title: 'Add category',
      builder: (_) => const _CategoryForm(),
    );
    if (result == null || !context.mounted) return;

    final palette = AppColors.categoryPalette;
    final cat = CategoryModel(
      id: const Uuid().v4(),
      name: result.name,
      icon: 'category',
      color: palette[existingCount % palette.length].toARGB32(),
      type: result.type,
      createdAt: DateTime.now(),
    );

    await ref.read(categoryRepositoryProvider).createCategory(cat);
    ref.invalidate(categoriesListProvider);
  }

  Future<void> _delete(
    BuildContext context,
    WidgetRef ref,
    CategoryModel category,
  ) async {
    final messenger = ScaffoldMessenger.of(context);
    final ok = await confirmDestructive(
      context,
      title: 'Delete ${category.name}?',
      message: 'This category will be removed.',
    );
    if (!ok) return;

    try {
      await ref.read(categoryRepositoryProvider).deleteCategory(category.id);
      ref.invalidate(categoriesListProvider);
    } catch (_) {
      // The repository refuses to delete a category that still has
      // transactions (it would orphan them), so explain instead of failing
      // silently.
      messenger.showSnackBar(
        SnackBar(
          content: Text(
            '${category.name} is used by transactions. Re-categorise them first.',
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final p = context.palette;
    final async = ref.watch(categoriesListProvider);
    final count = async.value?.length ?? 0;

    return ManagementScaffold<CategoryModel>(
      title: 'Categories',
      items: async,
      emptyEmoji: '🗂',
      emptyTitle: 'No categories',
      emptyMessage: 'Add a category to organise your spending.',
      addLabel: 'Add category',
      onAdd: () => _add(context, ref, count),
      rowBuilder: (context, c) => ListRowTile(
        leading: Container(
          width: 42,
          height: 42,
          decoration: BoxDecoration(
            color: Color(c.color).withValues(alpha: 0.18),
            borderRadius: BorderRadius.circular(14),
          ),
          alignment: Alignment.center,
          child: Text(
            AppColors.getCategoryEmoji(c.name),
            style: const TextStyle(fontSize: 19),
          ),
        ),
        title: c.name,
        subtitle: c.type == 'income' ? 'Income' : 'Expense',
        trailing: c.isDefault
            ? null
            : IconButton(
                tooltip: 'Delete category',
                icon: Icon(Icons.delete_outline_rounded, color: p.expense),
                onPressed: () => _delete(context, ref, c),
              ),
      ),
    );
  }
}

class _CategoryForm extends StatefulWidget {
  const _CategoryForm();

  @override
  State<_CategoryForm> createState() => _CategoryFormState();
}

class _CategoryFormState extends State<_CategoryForm> {
  final TextEditingController _name = TextEditingController();
  String _type = 'expense';
  bool _showError = false;

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  void _submit() {
    final name = _name.text.trim();
    if (name.isEmpty) {
      setState(() => _showError = true);
      return;
    }
    Navigator.pop(context, (name: name, type: _type));
  }

  @override
  Widget build(BuildContext context) {
    final p = context.palette;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        TextField(
          controller: _name,
          autofocus: true,
          textInputAction: TextInputAction.done,
          onChanged: (_) {
            if (_showError) setState(() => _showError = false);
          },
          onSubmitted: (_) => _submit(),
          decoration: InputDecoration(
            labelText: 'Category name',
            errorText: _showError ? 'This field is required' : null,
          ),
        ),
        const SizedBox(height: 14),
        Text('Type', style: AppText.section(p.muted)),
        const SizedBox(height: 8),
        SegmentedButton<String>(
          showSelectedIcon: false,
          segments: const [
            ButtonSegment(value: 'expense', label: Text('Expense')),
            ButtonSegment(value: 'income', label: Text('Income')),
          ],
          selected: {_type},
          onSelectionChanged: (s) => setState(() => _type = s.first),
        ),
        const SizedBox(height: 16),
        ElevatedButton(onPressed: _submit, child: const Text('Add category')),
      ],
    );
  }
}
