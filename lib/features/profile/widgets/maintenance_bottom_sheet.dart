import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_theme.dart';
import '../models/maintenance_entry.dart';
import '../providers/maintenance_provider.dart';

const _presetTypes = [
  'Oil Change',
  'General Checkup',
  'Yearly Inspection',
  'Brake Service',
  'Tire Rotation',
  'Air Filter',
  'Other',
];

Future<void> showMaintenanceBottomSheet(
  BuildContext context,
  WidgetRef ref, {
  MaintenanceEntry? existing,
}) {
  return showModalBottomSheet(
    context: context,
    backgroundColor: AppTheme.surface,
    isScrollControlled: true,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (_) => UncontrolledProviderScope(
      container: ProviderScope.containerOf(context),
      child: _MaintenanceSheet(existing: existing),
    ),
  );
}

class _MaintenanceSheet extends ConsumerStatefulWidget {
  final MaintenanceEntry? existing;
  const _MaintenanceSheet({this.existing});

  @override
  ConsumerState<_MaintenanceSheet> createState() => _MaintenanceSheetState();
}

class _MaintenanceSheetState extends ConsumerState<_MaintenanceSheet> {
  late String _selectedPreset;
  final _customTypeController = TextEditingController();
  final _notesController = TextEditingController();

  DateTime? _lastDoneDate;
  DateTime? _nextDueDate;
  bool _setDueDate = false;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final e = widget.existing;
    if (e != null) {
      _selectedPreset = _presetTypes.contains(e.type) ? e.type : 'Other';
      if (_selectedPreset == 'Other') _customTypeController.text = e.type;
      _lastDoneDate = e.lastDoneDate;
      _nextDueDate = e.nextDueDate;
      _setDueDate = e.nextDueDate != null;
      _notesController.text = e.notes ?? '';
    } else {
      _selectedPreset = _presetTypes.first;
    }
  }

  @override
  void dispose() {
    _customTypeController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  String get _effectiveType =>
      _selectedPreset == 'Other' ? _customTypeController.text.trim() : _selectedPreset;

  Future<void> _pickDate({required bool isDueDate}) async {
    final initial = isDueDate
        ? (_nextDueDate ?? DateTime.now().add(const Duration(days: 90)))
        : (_lastDoneDate ?? DateTime.now());
    final picked = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
      builder: (ctx, child) => Theme(
        data: ThemeData.dark().copyWith(
          colorScheme: const ColorScheme.dark(
            primary: AppTheme.accent,
            surface: AppTheme.surface,
          ),
        ),
        child: child!,
      ),
    );
    if (picked == null) return;
    setState(() {
      if (isDueDate) {
        _nextDueDate = picked;
      } else {
        _lastDoneDate = picked;
      }
    });
  }

  Future<void> _save() async {
    if (_lastDoneDate == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select a last done date.')),
      );
      return;
    }
    if (_selectedPreset == 'Other' && _customTypeController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a maintenance type.')),
      );
      return;
    }

    setState(() => _saving = true);
    try {
      final notifier = ref.read(maintenanceProvider.notifier);
      if (widget.existing != null) {
        await notifier.updateEntry(
          widget.existing!.copyWith(
            type: _effectiveType,
            lastDoneDate: _lastDoneDate,
            nextDueDate: _setDueDate ? _nextDueDate : null,
            notes: _notesController.text.trim().isEmpty
                ? null
                : _notesController.text.trim(),
            clearNextDueDate: !_setDueDate,
            clearNotes: _notesController.text.trim().isEmpty,
          ),
        );
      } else {
        await notifier.addEntry(
          MaintenanceEntry(
            entryId: '',
            type: _effectiveType,
            lastDoneDate: _lastDoneDate!,
            nextDueDate: _setDueDate ? _nextDueDate : null,
            notes: _notesController.text.trim().isEmpty
                ? null
                : _notesController.text.trim(),
            createdAt: DateTime.now(),
          ),
        );
      }
      if (mounted) Navigator.of(context).pop();
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to save. Please try again.')),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final bottomPad = MediaQuery.of(context).viewInsets.bottom;
    return Padding(
      padding: EdgeInsets.fromLTRB(20, 0, 20, 20 + bottomPad),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Handle
          Center(
            child: Container(
              margin: const EdgeInsets.symmetric(vertical: 12),
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                color: AppTheme.textSecondary.withValues(alpha: 0.3),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          Text(
            widget.existing != null ? 'EDIT MAINTENANCE' : 'ADD MAINTENANCE',
            style: const TextStyle(
              color: AppTheme.textPrimary,
              fontSize: 14,
              fontWeight: FontWeight.w700,
              letterSpacing: 2,
            ),
          ),
          const SizedBox(height: 20),

          // Type dropdown
          _label('TYPE'),
          const SizedBox(height: 8),
          _buildTypeDropdown(),
          if (_selectedPreset == 'Other') ...[
            const SizedBox(height: 10),
            _buildTextField(
              controller: _customTypeController,
              hint: 'Custom type name',
            ),
          ],

          const SizedBox(height: 16),

          // Last done date
          _label('LAST DONE DATE  ·  required'),
          const SizedBox(height: 8),
          _buildDateTile(
            value: _lastDoneDate,
            placeholder: 'Select date',
            onTap: () => _pickDate(isDueDate: false),
          ),

          const SizedBox(height: 16),

          // Due date toggle
          Row(
            children: [
              Switch(
                value: _setDueDate,
                activeThumbColor: AppTheme.accent,
                onChanged: (v) => setState(() {
                  _setDueDate = v;
                  if (!v) _nextDueDate = null;
                }),
              ),
              const SizedBox(width: 8),
              const Text(
                'Set due date',
                style: TextStyle(color: AppTheme.textSecondary, fontSize: 14),
              ),
            ],
          ),
          if (_setDueDate) ...[
            const SizedBox(height: 8),
            _buildDateTile(
              value: _nextDueDate,
              placeholder: 'Select due date',
              onTap: () => _pickDate(isDueDate: true),
            ),
          ],

          const SizedBox(height: 16),

          // Notes
          _label('NOTES  ·  optional'),
          const SizedBox(height: 8),
          _buildTextField(
            controller: _notesController,
            hint: 'e.g. Used synthetic 5W-30',
            maxLines: 3,
          ),

          const SizedBox(height: 24),

          // Save button
          SizedBox(
            height: 52,
            child: ElevatedButton(
              onPressed: _saving ? null : _save,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.accent,
                disabledBackgroundColor: AppTheme.accent.withValues(alpha: 0.4),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                elevation: 0,
              ),
              child: _saving
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: AppTheme.background,
                      ),
                    )
                  : Text(
                      widget.existing != null ? 'SAVE CHANGES' : 'ADD ENTRY',
                      style: const TextStyle(
                        color: AppTheme.background,
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 2,
                      ),
                    ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _label(String text) {
    return Text(
      text,
      style: const TextStyle(
        color: AppTheme.textSecondary,
        fontSize: 10,
        fontWeight: FontWeight.w600,
        letterSpacing: 1.5,
      ),
    );
  }

  Widget _buildTypeDropdown() {
    return Container(
      decoration: BoxDecoration(
        color: AppTheme.surfaceHigh,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.accent.withValues(alpha: 0.15)),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: _selectedPreset,
          dropdownColor: AppTheme.surfaceHigh,
          style: const TextStyle(color: AppTheme.textPrimary, fontSize: 14),
          iconEnabledColor: AppTheme.textSecondary,
          isExpanded: true,
          items: _presetTypes
              .map((t) => DropdownMenuItem(value: t, child: Text(t)))
              .toList(),
          onChanged: (v) {
            if (v != null) setState(() => _selectedPreset = v);
          },
        ),
      ),
    );
  }

  Widget _buildDateTile({
    required DateTime? value,
    required String placeholder,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 52,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        decoration: BoxDecoration(
          color: AppTheme.surfaceHigh,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppTheme.accent.withValues(alpha: 0.15)),
        ),
        child: Row(
          children: [
            const Icon(Icons.calendar_today_outlined,
                color: AppTheme.textSecondary, size: 16),
            const SizedBox(width: 12),
            Text(
              value != null ? _formatDate(value) : placeholder,
              style: TextStyle(
                color:
                    value != null ? AppTheme.textPrimary : AppTheme.textSecondary,
                fontSize: 14,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String hint,
    int maxLines = 1,
  }) {
    return TextField(
      controller: controller,
      maxLines: maxLines,
      style: const TextStyle(color: AppTheme.textPrimary, fontSize: 15),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: const TextStyle(color: AppTheme.textSecondary, fontSize: 14),
        filled: true,
        fillColor: AppTheme.surfaceHigh,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide:
              BorderSide(color: AppTheme.accent.withValues(alpha: 0.15)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide:
              BorderSide(color: AppTheme.accent.withValues(alpha: 0.15)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppTheme.accent, width: 1.5),
        ),
      ),
    );
  }

  String _formatDate(DateTime d) {
    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
    ];
    return '${months[d.month - 1]} ${d.day}, ${d.year}';
  }
}