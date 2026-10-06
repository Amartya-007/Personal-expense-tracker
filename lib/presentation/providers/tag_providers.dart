import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/models/tag_model.dart';
import '../../data/repositories/tag_repository.dart';

final tagRepositoryProvider = Provider((ref) => TagRepository());

final tagsListProvider = FutureProvider<List<TagModel>>((ref) async {
  return await ref.watch(tagRepositoryProvider).getAllTags();
});
