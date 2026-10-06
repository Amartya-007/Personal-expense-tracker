import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../../../core/theme/app_palette.dart';
import '../../../data/models/tag_model.dart';
import '../../providers/tag_providers.dart';
import '../../widgets/app_sheets.dart';
import '../../widgets/list_widgets.dart';

class TagsManagementScreen extends ConsumerWidget {
  const TagsManagementScreen({super.key});

  Future<void> _add(BuildContext context, WidgetRef ref) async {
    final values = await showFieldsSheet(
      context,
      title: 'Add tag',
      submitLabel: 'Add tag',
      fields: const [
        FieldSpec(
          label: 'Tag name',
          hint: 'e.g. College, Travel',
          required: true,
        ),
      ],
    );
    if (values == null || !context.mounted) return;

    await ref
        .read(tagRepositoryProvider)
        .createTag(TagModel(id: const Uuid().v4(), name: values[0]));
    ref.invalidate(tagsListProvider);
  }

  Future<void> _delete(
    BuildContext context,
    WidgetRef ref,
    TagModel tag,
  ) async {
    final ok = await confirmDestructive(
      context,
      title: 'Delete #${tag.name}?',
      message: 'It will be removed from any transactions that use it.',
    );
    if (!ok) return;
    await ref.read(tagRepositoryProvider).deleteTag(tag.id);
    ref.invalidate(tagsListProvider);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final p = context.palette;

    return ManagementScaffold<TagModel>(
      title: 'Tags',
      items: ref.watch(tagsListProvider),
      emptyEmoji: '#️⃣',
      emptyTitle: 'No tags yet',
      emptyMessage:
          'Tags let you group transactions across categories, like a trip.',
      addLabel: 'Add tag',
      onAdd: () => _add(context, ref),
      rowBuilder: (context, tag) => ListRowTile(
        emoji: '🏷',
        title: tag.name,
        trailing: IconButton(
          tooltip: 'Delete tag',
          icon: Icon(Icons.delete_outline_rounded, color: p.expense),
          onPressed: () => _delete(context, ref, tag),
        ),
      ),
    );
  }
}
