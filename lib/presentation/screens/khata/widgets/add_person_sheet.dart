import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_haptics.dart';
import '../../../../core/theme/app_palette.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_text.dart';
import '../../../../data/models/khata_person_model.dart';
import '../../../providers/khata_providers.dart';
import '../../../widgets/app_sheets.dart';
import '../../../widgets/field_decoration.dart';
import '../../../widgets/primary_button.dart';

class AddPersonSheet extends ConsumerStatefulWidget {
  final KhataPersonModel? personToEdit;

  const AddPersonSheet({super.key, this.personToEdit});

  static Future<KhataPersonModel?> show(
    BuildContext context, {
    KhataPersonModel? personToEdit,
  }) {
    return AppBottomSheet.show<KhataPersonModel?>(
      context,
      title: personToEdit != null ? 'Edit Person' : 'Add Person to Khata',
      builder: (_) => AddPersonSheet(personToEdit: personToEdit),
    );
  }

  @override
  ConsumerState<AddPersonSheet> createState() => _AddPersonSheetState();
}

class _AddPersonSheetState extends ConsumerState<AddPersonSheet> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameController;
  late final TextEditingController _phoneController;
  late final TextEditingController _notesController;
  bool _isSubmitting = false;

  @override
  void initState() {
    super.initState();
    final p = widget.personToEdit;
    _nameController = TextEditingController(text: p?.name ?? '');
    _phoneController = TextEditingController(text: p?.phone ?? '');
    _notesController = TextEditingController(text: p?.notes ?? '');
  }

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _handleSubmit() async {
    if (_isSubmitting) return;
    if (!_formKey.currentState!.validate()) {
      AppHaptics.warning();
      return;
    }

    setState(() => _isSubmitting = true);
    AppHaptics.tap();

    try {
      final name = _nameController.text.trim();
      final phone = _phoneController.text.trim();
      final notes = _notesController.text.trim();

      if (widget.personToEdit != null) {
        final updated = widget.personToEdit!.copyWith(
          name: name,
          phone: phone.isEmpty ? null : phone,
          notes: notes.isEmpty ? null : notes,
        );
        final success = await ref
            .read(khataControllerProvider.notifier)
            .updatePerson(updated);
        if (mounted && success) {
          Navigator.of(context).pop(updated);
        }
      } else {
        final created = await ref
            .read(khataControllerProvider.notifier)
            .createPerson(
              name: name,
              phone: phone.isEmpty ? null : phone,
              notes: notes.isEmpty ? null : notes,
            );
        if (mounted && created != null) {
          Navigator.of(context).pop(created);
        }
      }
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final isEditing = widget.personToEdit != null;

    return Form(
      key: _formKey,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Keep an offline ledger of who you lent money to or borrowed money from. No contacts upload or internet needed.',
            style: AppText.caption(p.muted),
          ),
          const SizedBox(height: AppSpacing.md),

          // Name field (Required)
          TextFormField(
            controller: _nameController,
            textCapitalization: TextCapitalization.words,
            style: AppText.body(p.ink),
            decoration: appFieldDecoration(p, hint: 'e.g., Rahul Sharma').copyWith(
              labelText: 'Full Name *',
              prefixIcon: const Icon(Icons.person_outline_rounded),
            ),
            validator: (val) {
              if (val == null || val.trim().isEmpty) {
                return 'Please enter a name';
              }
              return null;
            },
          ),
          const SizedBox(height: AppSpacing.md),

          // Phone field (Optional)
          TextFormField(
            controller: _phoneController,
            keyboardType: TextInputType.phone,
            style: AppText.body(p.ink),
            decoration: appFieldDecoration(p, hint: 'e.g., +91 98765 43210').copyWith(
              labelText: 'Phone Number (Optional)',
              prefixIcon: const Icon(Icons.phone_outlined),
            ),
          ),
          const SizedBox(height: AppSpacing.md),

          // Notes field (Optional)
          TextFormField(
            controller: _notesController,
            maxLines: 2,
            style: AppText.body(p.ink),
            decoration: appFieldDecoration(p, hint: 'e.g., Flatmate, College friend').copyWith(
              labelText: 'Notes (Optional)',
              prefixIcon: const Icon(Icons.notes_rounded),
            ),
          ),
          const SizedBox(height: AppSpacing.xl),

          PrimaryButton(
            label: isEditing ? 'Save Changes' : 'Add Person',
            loading: _isSubmitting,
            icon: isEditing ? Icons.check_rounded : Icons.person_add_rounded,
            onPressed: _handleSubmit,
          ),
        ],
      ),
    );
  }
}
