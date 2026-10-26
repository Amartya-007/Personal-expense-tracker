import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_haptics.dart';
import '../../../../core/theme/app_palette.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_text.dart';
import '../../../../data/models/khata_person_model.dart';
import '../../../../services/contacts/contact_service.dart';
import '../../../providers/contact_providers.dart';
import '../../../providers/khata_providers.dart';
import '../../../widgets/app_card.dart';
import '../../../widgets/app_sheets.dart';
import '../../../widgets/field_decoration.dart';
import '../../../widgets/primary_button.dart';
import 'add_person_sheet.dart';

class PersonSelectorSheet extends ConsumerStatefulWidget {
  final List<KhataPersonModel> initialSelected;
  final bool multiSelect;
  final String title;

  const PersonSelectorSheet({
    super.key,
    this.initialSelected = const [],
    this.multiSelect = true,
    this.title = 'Select People',
  });

  static Future<List<KhataPersonModel>?> show(
    BuildContext context, {
    List<KhataPersonModel> initialSelected = const [],
    bool multiSelect = true,
    String title = 'Select People',
  }) {
    return AppBottomSheet.show<List<KhataPersonModel>>(
      context,
      title: title,
      builder: (_) => PersonSelectorSheet(
        initialSelected: initialSelected,
        multiSelect: multiSelect,
        title: title,
      ),
    );
  }

  @override
  ConsumerState<PersonSelectorSheet> createState() => _PersonSelectorSheetState();
}

class _PersonSelectorSheetState extends ConsumerState<PersonSelectorSheet>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;
  final TextEditingController _searchController = TextEditingController();
  final Set<String> _selectedIds = {};
  final Map<String, KhataPersonModel> _selectedMap = {};
  bool _isProcessingContact = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    for (final p in widget.initialSelected) {
      _selectedIds.add(p.id);
      _selectedMap[p.id] = p;
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  void _toggleSelection(KhataPersonModel person) {
    AppHaptics.select();
    setState(() {
      if (_selectedIds.contains(person.id)) {
        _selectedIds.remove(person.id);
        _selectedMap.remove(person.id);
      } else {
        if (!widget.multiSelect) {
          _selectedIds.clear();
          _selectedMap.clear();
        }
        _selectedIds.add(person.id);
        _selectedMap[person.id] = person;
      }
    });

    if (!widget.multiSelect) {
      Navigator.of(context).pop([person]);
    }
  }

  Future<void> _handlePickDeviceContact(DeviceContact contact) async {
    if (_isProcessingContact) return;
    setState(() => _isProcessingContact = true);
    AppHaptics.tap();

    try {
      final person = await ref
          .read(khataControllerProvider.notifier)
          .createPersonFromContact(
            displayName: contact.displayName,
            phone: contact.primaryPhone,
            contactId: contact.id,
            lookupKey: contact.lookupKey,
          );

      if (person != null && mounted) {
        _toggleSelection(person);
      }
    } finally {
      if (mounted) setState(() => _isProcessingContact = false);
    }
  }

  Future<void> _openManualAdd() async {
    final created = await AddPersonSheet.show(context);
    if (created != null && mounted) {
      _toggleSelection(created);
    }
  }

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final peopleAsync = ref.watch(khataPeopleListProvider);
    final contactsPermAsync = ref.watch(contactPermissionStatusProvider);
    final deviceContactsAsync = ref.watch(deviceContactsProvider);

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Search & manual add row
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: _searchController,
                onChanged: (val) {
                  ref.read(khataSearchQueryProvider.notifier).state = val;
                  ref.read(contactSearchQueryProvider.notifier).state = val;
                  setState(() {});
                },
                style: AppText.body(p.ink),
                decoration: appFieldDecoration(p, hint: 'Search by name or phone').copyWith(
                  prefixIcon: const Icon(Icons.search_rounded, size: 20),
                ),
              ),
            ),
            const SizedBox(width: 8),
            IconButton(
              icon: const Icon(Icons.person_add_alt_1_rounded),
              tooltip: 'Add Manually',
              style: IconButton.styleFrom(
                backgroundColor: p.primary.withValues(alpha: 0.12),
                foregroundColor: p.primary,
              ),
              onPressed: _openManualAdd,
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.sm),

        // Tabs: Saved People vs Device Contacts
        TabBar(
          controller: _tabController,
          labelColor: p.primary,
          unselectedLabelColor: p.muted,
          indicatorColor: p.primary,
          tabs: const [
            Tab(text: 'Saved People'),
            Tab(text: 'Device Contacts'),
          ],
        ),
        const SizedBox(height: AppSpacing.sm),

        // Tab Content
        SizedBox(
          height: 320,
          child: TabBarView(
            controller: _tabController,
            children: [
              // Tab 1: Saved People in Khata
              peopleAsync.when(
                data: (people) {
                  if (people.isEmpty) {
                    return Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.people_outline_rounded, size: 40, color: p.muted),
                          const SizedBox(height: 8),
                          Text('No saved people found', style: AppText.body(p.muted)),
                          const SizedBox(height: 12),
                          TextButton.icon(
                            icon: const Icon(Icons.add, size: 18),
                            label: const Text('Add person manually'),
                            onPressed: _openManualAdd,
                          ),
                        ],
                      ),
                    );
                  }

                  return ListView.builder(
                    itemCount: people.length,
                    itemBuilder: (ctx, i) {
                      final person = people[i];
                      final isSelected = _selectedIds.contains(person.id);
                      return ListTile(
                        leading: CircleAvatar(
                          backgroundColor: p.primary.withValues(alpha: 0.15),
                          child: Text(
                            person.name.isNotEmpty ? person.name[0].toUpperCase() : '?',
                            style: AppText.bodyStrong(p.primary),
                          ),
                        ),
                        title: Text(person.name, style: AppText.bodyStrong(p.ink)),
                        subtitle: person.phone != null
                            ? Text(person.phone!, style: AppText.caption(p.muted))
                            : null,
                        trailing: Checkbox(
                          value: isSelected,
                          activeColor: p.primary,
                          onChanged: (_) => _toggleSelection(person),
                        ),
                        onTap: () => _toggleSelection(person),
                      );
                    },
                  );
                },
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (e, _) => Center(child: Text('Error loading people: $e')),
              ),

              // Tab 2: Device Contacts
              contactsPermAsync.when(
                data: (status) {
                  if (status == ContactPermissionState.permanentlyDenied) {
                    return _ContactPermissionBanner(
                      message:
                          'Contact permission was denied. You can open Android Settings to enable contacts, or enter people manually without permission.',
                      buttonLabel: 'Open Android Settings',
                      onAction: () async {
                        await ref
                            .read(contactPermissionControllerProvider.notifier)
                            .openSettings();
                        await ref
                            .read(contactPermissionControllerProvider.notifier)
                            .refreshStatus();
                      },
                    );
                  }

                  if (!status.isGranted) {
                    return _ContactPermissionBanner(
                      message:
                          'Enable contact access to quickly pick friends for expense splitting. Permission is optional; manual entry always works.',
                      buttonLabel: 'Allow Contact Access',
                      onAction: () async {
                        await ref
                            .read(contactPermissionControllerProvider.notifier)
                            .requestPermission();
                      },
                    );
                  }

                  return deviceContactsAsync.when(
                    data: (contacts) {
                      if (contacts.isEmpty) {
                        return Center(
                          child: Text(
                            'No matching contacts found',
                            style: AppText.body(p.muted),
                          ),
                        );
                      }

                      return ListView.builder(
                        itemCount: contacts.length,
                        itemBuilder: (ctx, i) {
                          final contact = contacts[i];
                          return ListTile(
                            leading: CircleAvatar(
                              backgroundColor: p.surface2,
                              child: Icon(Icons.person_outline_rounded, color: p.ink),
                            ),
                            title: Text(contact.displayName, style: AppText.bodyStrong(p.ink)),
                            subtitle: contact.primaryPhone != null
                                ? Text(contact.primaryPhone!, style: AppText.caption(p.muted))
                                : null,
                            trailing: TextButton(
                              child: const Text('Select'),
                              onPressed: () => _handlePickDeviceContact(contact),
                            ),
                            onTap: () => _handlePickDeviceContact(contact),
                          );
                        },
                      );
                    },
                    loading: () => const Center(child: CircularProgressIndicator()),
                    error: (e, _) => Center(child: Text('Error: $e')),
                  );
                },
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (e, _) => Center(child: Text('Error: $e')),
              ),
            ],
          ),
        ),

        const SizedBox(height: AppSpacing.sm),

        // Bottom confirmation bar
        if (widget.multiSelect)
          Row(
            children: [
              Expanded(
                child: Text(
                  '${_selectedIds.length} ${_selectedIds.length == 1 ? 'person' : 'people'} selected',
                  style: AppText.bodyStrong(p.ink),
                ),
              ),
              PrimaryButton(
                label: 'Confirm',
                onPressed: () {
                  Navigator.of(context).pop(_selectedMap.values.toList());
                },
              ),
            ],
          ),
      ],
    );
  }
}

class _ContactPermissionBanner extends StatelessWidget {
  final String message;
  final String buttonLabel;
  final VoidCallback onAction;

  const _ContactPermissionBanner({
    required this.message,
    required this.buttonLabel,
    required this.onAction,
  });

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return Padding(
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Center(
        child: AppCard(
          padding: const EdgeInsets.all(AppSpacing.md),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.contacts_outlined, size: 36, color: p.primary),
              const SizedBox(height: 10),
              Text(
                message,
                textAlign: TextAlign.center,
                style: AppText.body(p.ink),
              ),
              const SizedBox(height: 14),
              PrimaryButton(
                label: buttonLabel,
                onPressed: onAction,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
