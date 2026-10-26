import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_haptics.dart';
import '../../../../core/theme/app_palette.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_text.dart';
import '../../../../core/utils/keyboard.dart';
import '../../../../data/models/khata_person_model.dart';
import '../../../../services/contacts/contact_service.dart';
import '../../../providers/contact_providers.dart';
import '../../../providers/khata_providers.dart';
import '../../../widgets/app_card.dart';
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
    dismissKeyboard();
    return showModalBottomSheet<List<KhataPersonModel>>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        final p = ctx.palette;
        final media = MediaQuery.of(ctx);
        final sheetHeight = media.size.height * 0.85;

        return Padding(
          padding: EdgeInsets.only(bottom: media.viewInsets.bottom),
          child: Container(
            height: sheetHeight,
            decoration: BoxDecoration(
              color: p.surface,
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(28),
              ),
            ),
            child: SafeArea(
              top: false,
              child: PersonSelectorSheet(
                initialSelected: initialSelected,
                multiSelect: multiSelect,
                title: title,
              ),
            ),
          ),
        );
      },
    );
  }

  @override
  ConsumerState<PersonSelectorSheet> createState() =>
      _PersonSelectorSheetState();
}

class _PersonSelectorSheetState extends ConsumerState<PersonSelectorSheet>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;
  final TextEditingController _searchController = TextEditingController();
  final Set<String> _selectedIds = {};
  final Map<String, KhataPersonModel> _selectedMap = {};
  String? _processingContactId;

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

  String _normalizePhone(String phone) {
    return phone.replaceAll(RegExp(r'[\s\-\(\)\+]'), '');
  }

  bool _isContactSelected(DeviceContact contact) {
    return _selectedMap.values.any((p) {
      if (contact.id.isNotEmpty && p.contactId == contact.id) return true;
      if (contact.primaryPhone != null &&
          p.phone != null &&
          _normalizePhone(p.phone!) ==
              _normalizePhone(contact.primaryPhone!)) {
        return true;
      }
      return p.name.trim().toLowerCase() ==
          contact.displayName.trim().toLowerCase();
    });
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
    final alreadySelected = _isContactSelected(contact);

    if (alreadySelected) {
      AppHaptics.select();
      setState(() {
        _selectedMap.removeWhere((key, p) {
          if (contact.id.isNotEmpty && p.contactId == contact.id) return true;
          if (contact.primaryPhone != null &&
              p.phone != null &&
              _normalizePhone(p.phone!) ==
                  _normalizePhone(contact.primaryPhone!)) {
            return true;
          }
          return p.name.trim().toLowerCase() ==
              contact.displayName.trim().toLowerCase();
        });
        _selectedIds.clear();
        _selectedIds.addAll(_selectedMap.keys);
      });
      return;
    }

    if (_processingContactId != null) return;
    setState(() => _processingContactId = contact.id);
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
      if (mounted) setState(() => _processingContactId = null);
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
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Handle bar
        Padding(
          padding: const EdgeInsets.only(top: 12),
          child: Center(
            child: Container(
              width: 40,
              height: 5,
              decoration: BoxDecoration(
                color: p.border,
                borderRadius: BorderRadius.circular(3),
              ),
            ),
          ),
        ),

        // Header: Title & Close
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 10, 10, 4),
          child: Row(
            children: [
              Expanded(
                child: Text(widget.title, style: AppText.title(p.ink)),
              ),
              IconButton(
                icon: const Icon(Icons.close_rounded),
                color: p.muted,
                tooltip: 'Close',
                onPressed: () => Navigator.of(context).pop(),
              ),
            ],
          ),
        ),

        // Search & Manual Add Row
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Row(
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
                  decoration: appFieldDecoration(
                    p,
                    hint: 'Search by name or phone',
                  ).copyWith(
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

        // Bounded, smoothly scrolling Tab Content
        Expanded(
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
                          Icon(
                            Icons.people_outline_rounded,
                            size: 44,
                            color: p.muted,
                          ),
                          const SizedBox(height: 10),
                          Text(
                            'No saved people found',
                            style: AppText.body(p.muted),
                          ),
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
                        selected: isSelected,
                        selectedTileColor: p.primary.withValues(alpha: 0.08),
                        leading: CircleAvatar(
                          backgroundColor: isSelected
                              ? p.primary
                              : p.primary.withValues(alpha: 0.15),
                          child: Text(
                            person.name.isNotEmpty
                                ? person.name[0].toUpperCase()
                                : '?',
                            style: AppText.bodyStrong(
                              isSelected ? p.onPrimary : p.primary,
                            ),
                          ),
                        ),
                        title:
                            Text(person.name, style: AppText.bodyStrong(p.ink)),
                        subtitle: person.phone != null
                            ? Text(person.phone!,
                                style: AppText.caption(p.muted))
                            : null,
                        trailing: widget.multiSelect
                            ? Checkbox(
                                value: isSelected,
                                activeColor: p.primary,
                                onChanged: (_) => _toggleSelection(person),
                              )
                            : (isSelected
                                ? Icon(Icons.check_circle_rounded,
                                    color: p.primary, size: 22)
                                : const Icon(Icons.chevron_right_rounded,
                                    size: 20)),
                        onTap: () => _toggleSelection(person),
                      );
                    },
                  );
                },
                loading: () =>
                    const Center(child: CircularProgressIndicator()),
                error: (e, _) =>
                    Center(child: Text('Error loading people: $e')),
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
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.contacts_outlined,
                                size: 44,
                                color: p.muted,
                              ),
                              const SizedBox(height: 10),
                              Text(
                                'No matching contacts found',
                                style: AppText.body(p.muted),
                              ),
                            ],
                          ),
                        );
                      }

                      return ListView.builder(
                        itemCount: contacts.length,
                        itemBuilder: (ctx, i) {
                          final contact = contacts[i];
                          final isSelected = _isContactSelected(contact);
                          final isProcessing =
                              _processingContactId == contact.id;

                          return ListTile(
                            selected: isSelected,
                            selectedTileColor:
                                p.primary.withValues(alpha: 0.08),
                            leading: CircleAvatar(
                              backgroundColor: isSelected
                                  ? p.primary
                                  : p.surface2,
                              child: isSelected
                                  ? Icon(
                                      Icons.check_rounded,
                                      color: p.onPrimary,
                                      size: 20,
                                    )
                                  : Icon(
                                      Icons.person_outline_rounded,
                                      color: p.ink,
                                      size: 20,
                                    ),
                            ),
                            title: Text(
                              contact.displayName,
                              style: AppText.bodyStrong(p.ink),
                            ),
                            subtitle: contact.primaryPhone != null
                                ? Text(
                                    contact.primaryPhone!,
                                    style: AppText.caption(p.muted),
                                  )
                                : null,
                            trailing: isProcessing
                                ? const SizedBox(
                                    width: 20,
                                    height: 20,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                    ),
                                  )
                                : (widget.multiSelect
                                    ? Checkbox(
                                        value: isSelected,
                                        activeColor: p.primary,
                                        onChanged: (_) =>
                                            _handlePickDeviceContact(contact),
                                      )
                                    : (isSelected
                                        ? Icon(
                                            Icons.check_circle_rounded,
                                            color: p.primary,
                                            size: 22,
                                          )
                                        : const Icon(
                                            Icons.chevron_right_rounded,
                                            size: 20,
                                          ))),
                            onTap: isProcessing
                                ? null
                                : () => _handlePickDeviceContact(contact),
                          );
                        },
                      );
                    },
                    loading: () =>
                        const Center(child: CircularProgressIndicator()),
                    error: (e, _) => Center(child: Text('Error: $e')),
                  );
                },
                loading: () =>
                    const Center(child: CircularProgressIndicator()),
                error: (e, _) => Center(child: Text('Error: $e')),
              ),
            ],
          ),
        ),

        // Bottom confirmation bar for multi-select
        if (widget.multiSelect)
          Container(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 12),
            decoration: BoxDecoration(
              color: p.surface,
              border: Border(top: BorderSide(color: p.border)),
            ),
            child: Row(
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
