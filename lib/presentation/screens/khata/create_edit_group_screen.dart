import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_haptics.dart';
import '../../../core/theme/app_palette.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_text.dart';
import '../../../data/models/expense_group_model.dart';
import '../../../data/models/khata_person_model.dart';
import '../../providers/expense_group_providers.dart';
import '../../widgets/app_card.dart';
import '../../widgets/field_decoration.dart';
import '../../widgets/primary_button.dart';
import 'widgets/person_selector_sheet.dart';

class CreateEditGroupScreen extends ConsumerStatefulWidget {
  final ExpenseGroupModel? groupToEdit;

  const CreateEditGroupScreen({super.key, this.groupToEdit});

  @override
  ConsumerState<CreateEditGroupScreen> createState() =>
      _CreateEditGroupScreenState();
}

class _CreateEditGroupScreenState extends ConsumerState<CreateEditGroupScreen> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameController;
  late final TextEditingController _descriptionController;

  String _selectedEmoji = '👥';
  final List<String> _emojis = [
    '👥', '🏠', '✈️', '💼', '🍽️', '🎉', '🏖️', '🚗', '🎓', '🛍️'
  ];

  final Map<String, KhataPersonModel> _members = {};
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    final g = widget.groupToEdit;
    _nameController = TextEditingController(text: g?.name ?? '');
    _descriptionController = TextEditingController(text: g?.description ?? '');
    if (g?.icon != null && g!.icon!.isNotEmpty) {
      _selectedEmoji = g.icon!;
    }
    if (g?.members != null) {
      for (final m in g!.members) {
        _members[m.id] = m;
      }
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  Future<void> _openMemberPicker() async {
    final selected = await PersonSelectorSheet.show(
      context,
      initialSelected: _members.values.toList(),
      multiSelect: true,
      title: 'Add Members to Group',
    );

    if (selected != null && mounted) {
      setState(() {
        for (final p in selected) {
          _members[p.id] = p;
        }
      });
    }
  }

  void _removeMember(String personId) {
    AppHaptics.select();
    setState(() {
      _members.remove(personId);
    });
  }

  Future<void> _handleSave() async {
    if (_isSaving) return;
    if (!_formKey.currentState!.validate()) {
      AppHaptics.warning();
      return;
    }

    setState(() => _isSaving = true);
    AppHaptics.tap();

    try {
      final name = _nameController.text.trim();
      final desc = _descriptionController.text.trim();
      final memberIds = _members.keys.toList();

      if (widget.groupToEdit != null) {
        final success = await ref
            .read(expenseGroupControllerProvider.notifier)
            .updateGroup(
              id: widget.groupToEdit!.id,
              name: name,
              description: desc.isEmpty ? null : desc,
              icon: _selectedEmoji,
              memberPersonIds: memberIds,
            );
        if (mounted && success) {
          Navigator.of(context).pop();
        }
      } else {
        final created = await ref
            .read(expenseGroupControllerProvider.notifier)
            .createGroup(
              name: name,
              description: desc.isEmpty ? null : desc,
              icon: _selectedEmoji,
              memberPersonIds: memberIds,
            );
        if (mounted && created != null) {
          Navigator.of(context).pop(created);
        }
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final isEditing = widget.groupToEdit != null;

    return Scaffold(
      backgroundColor: p.background,
      appBar: AppBar(
        backgroundColor: p.background,
        elevation: 0,
        title: Text(
          isEditing ? 'Edit Group' : 'New Group',
          style: AppText.title(p.ink),
        ),
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: EdgeInsets.fromLTRB(
            AppSpacing.md,
            AppSpacing.sm,
            AppSpacing.md,
            MediaQuery.of(context).padding.bottom + 90,
          ),
          children: [
            // Icon Selector
            Text('Group Icon', style: AppText.caption(p.muted)),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: _emojis.map((em) {
                final isSelected = _selectedEmoji == em;
                return InkWell(
                  borderRadius: BorderRadius.circular(12),
                  onTap: () => setState(() => _selectedEmoji = em),
                  child: Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: isSelected
                          ? p.primary.withValues(alpha: 0.18)
                          : p.surface2,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: isSelected ? p.primary : p.border,
                        width: isSelected ? 2 : 1,
                      ),
                    ),
                    child: Text(em, style: const TextStyle(fontSize: 24)),
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: AppSpacing.lg),

            // Group Name (Required)
            TextFormField(
              controller: _nameController,
              textCapitalization: TextCapitalization.words,
              style: AppText.body(p.ink),
              decoration: appFieldDecoration(
                p,
                hint: 'e.g., Goa Trip, Flat 402, Office Lunch',
              ).copyWith(
                labelText: 'Group Name *',
                prefixIcon: const Icon(Icons.group_outlined),
              ),
              validator: (val) {
                if (val == null || val.trim().isEmpty) {
                  return 'Please enter a group name';
                }
                return null;
              },
            ),
            const SizedBox(height: AppSpacing.md),

            // Description (Optional)
            TextFormField(
              controller: _descriptionController,
              maxLines: 2,
              style: AppText.body(p.ink),
              decoration: appFieldDecoration(
                p,
                hint: 'e.g., Shared household bills and grocery splits',
              ).copyWith(
                labelText: 'Description (Optional)',
                prefixIcon: const Icon(Icons.notes_rounded),
              ),
            ),
            const SizedBox(height: AppSpacing.xl),

            // Members Header & Add button
            Row(
              children: [
                Expanded(
                  child: Text(
                    'Members (${_members.length})',
                    style: AppText.bodyStrong(p.ink),
                  ),
                ),
                TextButton.icon(
                  icon: const Icon(Icons.person_add_rounded, size: 18),
                  label: const Text('Add Members'),
                  onPressed: _openMemberPicker,
                ),
              ],
            ),
            const SizedBox(height: 8),

            // Members List or Empty state
            if (_members.isEmpty)
              AppCard(
                padding: const EdgeInsets.all(AppSpacing.md),
                child: Center(
                  child: Column(
                    children: [
                      Icon(Icons.group_add_outlined, size: 36, color: p.muted),
                      const SizedBox(height: 8),
                      Text(
                        'No members added yet',
                        style: AppText.body(p.muted),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Select from device contacts or your saved people',
                        style: AppText.caption(p.muted),
                      ),
                      const SizedBox(height: 12),
                      OutlinedButton.icon(
                        icon: const Icon(Icons.add, size: 18),
                        label: const Text('Select People'),
                        onPressed: _openMemberPicker,
                      ),
                    ],
                  ),
                ),
              )
            else
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: _members.values.map((m) {
                  return Chip(
                    avatar: CircleAvatar(
                      backgroundColor: p.primary.withValues(alpha: 0.15),
                      child: Text(
                        m.name.isNotEmpty ? m.name[0].toUpperCase() : '?',
                        style: AppText.caption(p.primary),
                      ),
                    ),
                    label: Text(m.name, style: AppText.body(p.ink)),
                    deleteIcon: const Icon(Icons.close, size: 16),
                    onDeleted: () => _removeMember(m.id),
                    backgroundColor: p.surface2,
                    side: BorderSide(color: p.border),
                  );
                }).toList(),
              ),

            const SizedBox(height: AppSpacing.xxl),

            PrimaryButton(
              label: isEditing ? 'Save Changes' : 'Create Group',
              loading: _isSaving,
              icon: isEditing ? Icons.check_rounded : Icons.group_add_rounded,
              onPressed: _handleSave,
            ),
          ],
        ),
      ),
    );
  }
}
