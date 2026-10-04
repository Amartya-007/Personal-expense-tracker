import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../../../data/models/tag_model.dart';
import '../../../data/repositories/tag_repository.dart';

final tagRepositoryProvider = Provider((ref) => TagRepository());
final tagsListProvider = FutureProvider<List<TagModel>>((ref) async {
  return await ref.watch(tagRepositoryProvider).getAllTags();
});

class TagsManagementScreen extends ConsumerWidget {
  const TagsManagementScreen({super.key});

  void _showAddTagDialog(BuildContext context, WidgetRef ref) {
    final nameCtrl = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Add Tag'),
        content: TextField(
          controller: nameCtrl,
          decoration: const InputDecoration(
            labelText: 'Tag Name (e.g., College, Travel)',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              final name = nameCtrl.text.trim();
              if (name.isEmpty) return;

              final tag = TagModel(id: const Uuid().v4(), name: name);
              await ref.read(tagRepositoryProvider).createTag(tag);
              ref.invalidate(tagsListProvider);
              // BUG FIX: use ctx.mounted (the dialog context) not context.mounted
              // (the outer widget context). If the dialog was dismissed while
              // createTag was awaiting, Navigator.pop(ctx) would throw on a
              // stale inactive navigator.
              if (ctx.mounted) {
                Navigator.pop(ctx);
              }
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tagsAsync = ref.watch(tagsListProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Tags')),
      body: tagsAsync.when(
        data: (tags) {
          if (tags.isEmpty) {
            return const Center(child: Text('No tags created yet.'));
          }
          return ListView.builder(
            itemCount: tags.length,
            itemBuilder: (context, index) {
              final t = tags[index];
              return ListTile(
                leading: const Icon(Icons.label_outline),
                title: Text(t.name),
                trailing: IconButton(
                  icon: const Icon(Icons.delete_outline, color: Colors.red),
                  onPressed: () async {
                    await ref.read(tagRepositoryProvider).deleteTag(t.id);
                    ref.invalidate(tagsListProvider);
                  },
                ),
              );
            },
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, _) => Center(child: Text('Error: $err')),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showAddTagDialog(context, ref),
        child: const Icon(Icons.add),
      ),
    );
  }
}
