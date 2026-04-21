import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_theme.dart';
import '../../../features/auth/services/auth_service.dart';
import '../../../features/friends/providers/friend_provider.dart';
import '../../../features/friends/services/friend_service.dart';
import '../models/maintenance_entry.dart';
import '../providers/maintenance_provider.dart';
import '../providers/profile_provider.dart';
import '../widgets/maintenance_bottom_sheet.dart';

// Year list: 2025 down to 1970
final _years = List.generate(
  2026 - 1970,
  (i) => (2025 - i).toString(),
);

class ProfileScreen extends ConsumerStatefulWidget {
  const ProfileScreen({super.key});

  @override
  ConsumerState<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends ConsumerState<ProfileScreen> {
  final _formKey = GlobalKey<FormState>();

  // Text controllers
  final _usernameController = TextEditingController();
  final _trimController = TextEditingController();
  final _notesController = TextEditingController();

  // Fallback text controllers (used when NHTSA fails)
  final _makeFallbackController = TextEditingController();
  final _modelFallbackController = TextEditingController();

  // Dropdown selections
  String? _selectedMake;
  String? _selectedModel;
  String? _selectedYear;

  // Make search filter
  String _makeSearch = '';

  bool _saving = false;
  String? _saveError;
  bool _saved = false;

  // Whether profile has been pre-populated from Firestore
  bool _hydrated = false;

  @override
  void initState() {
    super.initState();
    // Kick off NHTSA makes fetch immediately
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(nhtsaMakesProvider.notifier).load();
    });
  }

  @override
  void dispose() {
    _usernameController.dispose();
    _trimController.dispose();
    _notesController.dispose();
    _makeFallbackController.dispose();
    _modelFallbackController.dispose();
    super.dispose();
  }

  // Pre-populate fields once Firestore data arrives (only the first time)
  void _hydrateIfNeeded(UserProfile profile) {
    if (_hydrated) return;
    _hydrated = true;
    _usernameController.text = profile.username;
    _trimController.text = profile.carTrim ?? '';
    _notesController.text = profile.carNotes ?? '';
    _selectedYear = profile.carYear;

    final makesState = ref.read(nhtsaMakesProvider);
    if (makesState.fallback) {
      _makeFallbackController.text = profile.carMake ?? '';
      _modelFallbackController.text = profile.carModel ?? '';
    } else {
      _selectedMake = profile.carMake;
      if (profile.carMake != null && profile.carMake!.isNotEmpty) {
        // Trigger model fetch, then set selected model once loaded
        ref
            .read(nhtsaModelsProvider.notifier)
            .loadForMake(profile.carMake!)
            .then((_) {
          if (mounted && profile.carModel != null) {
            setState(() => _selectedModel = profile.carModel);
          }
        });
      }
    }
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    final makesState = ref.read(nhtsaMakesProvider);

    setState(() {
      _saving = true;
      _saveError = null;
      _saved = false;
    });

    try {
      final make =
          makesState.fallback ? _makeFallbackController.text : _selectedMake;
      final model = makesState.fallback
          ? _modelFallbackController.text
          : _selectedModel;

      await saveProfile(
        username: _usernameController.text,
        make: make,
        model: model,
        year: _selectedYear,
        trim: _trimController.text.trim().isEmpty
            ? null
            : _trimController.text.trim(),
        notes: _notesController.text.trim().isEmpty
            ? null
            : _notesController.text.trim(),
      );
      if (mounted) setState(() => _saved = true);
    } catch (e) {
      if (mounted) setState(() => _saveError = 'Save failed. Please try again.');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _signOut() async {
    await AuthService().signOut();
    if (mounted) context.go('/login');
  }

  @override
  Widget build(BuildContext context) {
    final profileAsync = ref.watch(userProfileProvider);

    return Scaffold(
      backgroundColor: AppTheme.background,
      body: SafeArea(
        child: profileAsync.when(
          loading: () => const Center(
            child: CircularProgressIndicator(color: AppTheme.accent),
          ),
          error: (e, _) => Center(
            child: Text(
              'Failed to load profile.',
              style: const TextStyle(color: AppTheme.speedRed),
            ),
          ),
          data: (profile) {
            if (profile != null) _hydrateIfNeeded(profile);
            return _buildBody(profile);
          },
        ),
      ),
    );
  }

  Widget _buildBody(UserProfile? profile) {
    return CustomScrollView(
      slivers: [
        SliverToBoxAdapter(child: _buildHeader(profile)),
        SliverToBoxAdapter(child: _buildStatsRow(profile)),
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 24, 20, 8),
            child: _buildSectionLabel('ACCOUNT'),
          ),
        ),
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: _buildGlassCard(child: _buildUsernameField()),
          ),
        ),
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 24, 20, 8),
            child: _buildSectionLabel('YOUR CAR'),
          ),
        ),
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: _buildGlassCard(child: _buildCarForm()),
          ),
        ),
        SliverToBoxAdapter(child: _buildSaveArea()),
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 32, 20, 8),
            child: Row(
              children: [
                Expanded(child: _buildSectionLabel('MAINTENANCE')),
                IconButton(
                  onPressed: () =>
                      showMaintenanceBottomSheet(context, ref),
                  icon: const Icon(Icons.add, color: AppTheme.accent),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                  splashRadius: 20,
                ),
              ],
            ),
          ),
        ),
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: _buildMaintenanceSection(),
          ),
        ),
        SliverToBoxAdapter(child: _buildPendingRequestsSection()),
        SliverToBoxAdapter(child: _buildFriendsSection()),
        SliverToBoxAdapter(child: _buildSignOutButton()),
        const SliverToBoxAdapter(child: SizedBox(height: 40)),
      ],
    );
  }

  // ---------------------------------------------------------------------------
  // Header
  // ---------------------------------------------------------------------------

  Widget _buildHeader(UserProfile? profile) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 28, 20, 0),
      child: Row(
        children: [
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              color: AppTheme.accent.withValues(alpha: 0.12),
              shape: BoxShape.circle,
              border: Border.all(
                color: AppTheme.accent.withValues(alpha: 0.35),
                width: 1.5,
              ),
            ),
            child: Center(
              child: Text(
                profile != null && profile.username.isNotEmpty
                    ? profile.username[0].toUpperCase()
                    : '?',
                style: const TextStyle(
                  color: AppTheme.accent,
                  fontSize: 22,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  profile?.username ?? '—',
                  style: const TextStyle(
                    color: AppTheme.textPrimary,
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.3,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  profile?.email ?? '',
                  style: const TextStyle(
                    color: AppTheme.textSecondary,
                    fontSize: 13,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Stats row
  // ---------------------------------------------------------------------------

  Widget _buildStatsRow(UserProfile? profile) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
      child: Row(
        children: [
          Expanded(
            child: _buildStatTile(
              label: 'TRIPS',
              value: (profile?.totalTrips ?? 0).toString(),
              icon: Icons.route_outlined,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: _buildStatTile(
              label: 'KM DRIVEN',
              value: _formatDistance(profile?.totalDistance ?? 0),
              icon: Icons.straighten_outlined,
            ),
          ),
        ],
      ),
    );
  }

  String _formatDistance(double km) {
    if (km >= 1000) return '${(km / 1000).toStringAsFixed(1)}k';
    return km.toStringAsFixed(1);
  }

  Widget _buildStatTile({
    required String label,
    required String value,
    required IconData icon,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 18),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: AppTheme.accent.withValues(alpha: 0.15),
          width: 1,
        ),
      ),
      child: Row(
        children: [
          Icon(icon, color: AppTheme.accent, size: 20),
          const SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                value,
                style: const TextStyle(
                  color: AppTheme.textPrimary,
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                  letterSpacing: -0.5,
                ),
              ),
              Text(
                label,
                style: const TextStyle(
                  color: AppTheme.textSecondary,
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 1.2,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Section label
  // ---------------------------------------------------------------------------

  Widget _buildSectionLabel(String text) {
    return Text(
      text,
      style: const TextStyle(
        color: AppTheme.textSecondary,
        fontSize: 11,
        fontWeight: FontWeight.w600,
        letterSpacing: 2,
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Glass card wrapper
  // ---------------------------------------------------------------------------

  Widget _buildGlassCard({required Widget child}) {
    return Container(
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: AppTheme.accent.withValues(alpha: 0.15),
          width: 1,
        ),
      ),
      padding: const EdgeInsets.all(20),
      child: child,
    );
  }

  // ---------------------------------------------------------------------------
  // Username field
  // ---------------------------------------------------------------------------

  Widget _buildUsernameField() {
    return Form(
      key: _formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _fieldLabel('USERNAME'),
          const SizedBox(height: 8),
          TextFormField(
            controller: _usernameController,
            autocorrect: false,
            style: const TextStyle(
              color: AppTheme.textPrimary,
              fontSize: 15,
            ),
            decoration: _inputDecoration(hint: 'Your username'),
            validator: (v) {
              if (v == null || v.trim().isEmpty) return 'Username is required';
              if (v.trim().length < 3) return 'Must be at least 3 characters';
              return null;
            },
          ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Car form
  // ---------------------------------------------------------------------------

  Widget _buildCarForm() {
    final makesState = ref.watch(nhtsaMakesProvider);
    final modelsState = ref.watch(nhtsaModelsProvider);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Make
        _fieldLabel('MAKE'),
        const SizedBox(height: 8),
        makesState.fallback
            ? _buildFallbackField(
                controller: _makeFallbackController,
                hint: 'e.g. Mercedes',
                errorText: 'Could not load data, type manually',
              )
            : _buildMakeDropdown(makesState),

        const SizedBox(height: 16),

        // Model
        _fieldLabel('MODEL'),
        const SizedBox(height: 8),
        makesState.fallback
            ? _buildFallbackField(
                controller: _modelFallbackController,
                hint: 'e.g. E320',
              )
            : _buildModelDropdown(modelsState),

        const SizedBox(height: 16),

        // Year
        _fieldLabel('YEAR'),
        const SizedBox(height: 8),
        _buildYearDropdown(),

        const SizedBox(height: 16),

        // Trim
        _fieldLabel('TRIM / VARIANT  ·  optional'),
        const SizedBox(height: 8),
        TextField(
          controller: _trimController,
          style: const TextStyle(color: AppTheme.textPrimary, fontSize: 15),
          decoration: _inputDecoration(hint: 'e.g. AMG Line'),
        ),

        const SizedBox(height: 16),

        // Mods / Notes
        _fieldLabel('MODS / NOTES  ·  optional'),
        const SizedBox(height: 8),
        TextField(
          controller: _notesController,
          maxLines: 3,
          style: const TextStyle(color: AppTheme.textPrimary, fontSize: 15),
          decoration: _inputDecoration(hint: 'e.g. Stage 2 tune, coilovers'),
        ),
      ],
    );
  }

  // ---------------------------------------------------------------------------
  // Make dropdown with search
  // ---------------------------------------------------------------------------

  Widget _buildMakeDropdown(NhtsaMakesState state) {
    final isLoading = state.loadState == NhtsaLoadState.loading ||
        state.loadState == NhtsaLoadState.idle;

    if (isLoading) return _loadingDropdownPlaceholder();

    final filteredMakes = _makeSearch.isEmpty
        ? state.items
        : state.items
            .where((m) => m.toLowerCase().contains(_makeSearch.toLowerCase()))
            .toList();

    return _StyledDropdown<String>(
      value: _selectedMake,
      hint: 'Select make',
      items: filteredMakes,
      itemLabel: (m) => m,
      onChanged: (make) {
        setState(() {
          _selectedMake = make;
          _selectedModel = null;
          _makeSearch = '';
        });
        if (make != null) {
          ref.read(nhtsaModelsProvider.notifier).loadForMake(make);
        } else {
          ref.read(nhtsaModelsProvider.notifier).reset();
        }
      },
      searchHint: 'Search makes…',
      onSearchChanged: (q) => setState(() => _makeSearch = q),
      searchValue: _makeSearch,
      filteredItems: filteredMakes,
    );
  }

  // ---------------------------------------------------------------------------
  // Model dropdown
  // ---------------------------------------------------------------------------

  Widget _buildModelDropdown(NhtsaModelsState state) {
    final makeSelected = _selectedMake != null && _selectedMake!.isNotEmpty;
    if (!makeSelected) {
      return _disabledDropdownPlaceholder('Select a make first');
    }

    final isLoading = state.loadState == NhtsaLoadState.loading;
    if (isLoading) return _loadingDropdownPlaceholder();

    if (state.fallback) {
      return _buildFallbackField(
        controller: _modelFallbackController,
        hint: 'e.g. E320',
        errorText: 'Could not load data, type manually',
      );
    }

    return _StyledDropdown<String>(
      value: _selectedModel,
      hint: 'Select model',
      items: state.items,
      itemLabel: (m) => m,
      onChanged: (model) => setState(() => _selectedModel = model),
    );
  }

  // ---------------------------------------------------------------------------
  // Year dropdown
  // ---------------------------------------------------------------------------

  Widget _buildYearDropdown() {
    return _StyledDropdown<String>(
      value: _selectedYear,
      hint: 'Select year',
      items: _years,
      itemLabel: (y) => y,
      onChanged: (y) => setState(() => _selectedYear = y),
    );
  }

  // ---------------------------------------------------------------------------
  // Helpers
  // ---------------------------------------------------------------------------

  Widget _loadingDropdownPlaceholder() {
    return Container(
      height: 52,
      decoration: BoxDecoration(
        color: AppTheme.surfaceHigh,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: AppTheme.accent.withValues(alpha: 0.15),
        ),
      ),
      child: const Center(
        child: SizedBox(
          width: 18,
          height: 18,
          child: CircularProgressIndicator(
            strokeWidth: 2,
            color: AppTheme.accent,
          ),
        ),
      ),
    );
  }

  Widget _disabledDropdownPlaceholder(String text) {
    return Container(
      height: 52,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: AppTheme.surfaceHigh.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: AppTheme.accent.withValues(alpha: 0.08),
        ),
      ),
      alignment: Alignment.centerLeft,
      child: Text(
        text,
        style: const TextStyle(
          color: AppTheme.textSecondary,
          fontSize: 14,
        ),
      ),
    );
  }

  Widget _buildFallbackField({
    required TextEditingController controller,
    required String hint,
    String? errorText,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TextField(
          controller: controller,
          style: const TextStyle(color: AppTheme.textPrimary, fontSize: 15),
          decoration: _inputDecoration(hint: hint),
        ),
        if (errorText != null) ...[
          const SizedBox(height: 4),
          Text(
            errorText,
            style: const TextStyle(
              color: AppTheme.textSecondary,
              fontSize: 11,
              fontStyle: FontStyle.italic,
            ),
          ),
        ],
      ],
    );
  }

  // ---------------------------------------------------------------------------
  // Save area
  // ---------------------------------------------------------------------------

  Widget _buildSaveArea() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 28, 20, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (_saveError != null) ...[
            Text(
              _saveError!,
              style: const TextStyle(color: AppTheme.speedRed, fontSize: 13),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
          ],
          if (_saved) ...[
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: const [
                Icon(Icons.check_circle_outline,
                    color: AppTheme.accent, size: 16),
                SizedBox(width: 6),
                Text(
                  'Profile saved.',
                  style: TextStyle(color: AppTheme.accent, fontSize: 13),
                ),
              ],
            ),
            const SizedBox(height: 8),
          ],
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
                  : const Text(
                      'SAVE PROFILE',
                      style: TextStyle(
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

  // ---------------------------------------------------------------------------
  // Maintenance section
  // ---------------------------------------------------------------------------

  Widget _buildMaintenanceSection() {
    final state = ref.watch(maintenanceProvider);
    return state.when(
      loading: () => const Center(
        child: Padding(
          padding: EdgeInsets.all(16),
          child: CircularProgressIndicator(color: AppTheme.accent),
        ),
      ),
      error: (_, s) => const Text(
        'Failed to load maintenance records.',
        style: TextStyle(color: AppTheme.speedRed, fontSize: 13),
      ),
      data: (entries) {
        if (entries.isEmpty) {
          return const Center(
            child: Padding(
              padding: EdgeInsets.symmetric(vertical: 12),
              child: Text(
                'No maintenance records yet',
                style: TextStyle(color: AppTheme.textSecondary, fontSize: 13),
              ),
            ),
          );
        }
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: entries
              .map((e) => Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: _MaintenanceCard(
                      entry: e,
                      onEdit: () => showMaintenanceBottomSheet(
                        context,
                        ref,
                        existing: e,
                      ),
                      onDelete: () => _confirmDelete(e),
                    ),
                  ))
              .toList(),
        );
      },
    );
  }

  Future<void> _confirmDelete(MaintenanceEntry entry) async {
    await ref.read(maintenanceProvider.notifier).deleteEntry(entry.entryId);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('${entry.type} deleted'),
        backgroundColor: AppTheme.surfaceHigh,
        action: SnackBarAction(
          label: 'UNDO',
          textColor: AppTheme.accent,
          onPressed: () async {
            await ref.read(maintenanceProvider.notifier).addEntry(entry);
          },
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Pending friend requests
  // ---------------------------------------------------------------------------

  Widget _buildPendingRequestsSection() {
    final async = ref.watch(pendingReceivedProvider);
    return async.when(
      loading: () => const SizedBox.shrink(),
      error: (e, st) => const SizedBox.shrink(),
      data: (requests) {
        if (requests.isEmpty) return const SizedBox.shrink();
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 32, 20, 8),
              child: _buildSectionLabel('FRIEND REQUESTS'),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Column(
                children: requests
                    .map((r) => Padding(
                          padding: const EdgeInsets.only(bottom: 10),
                          child: _FriendRequestCard(request: r),
                        ))
                    .toList(),
              ),
            ),
          ],
        );
      },
    );
  }

  // ---------------------------------------------------------------------------
  // Friends list
  // ---------------------------------------------------------------------------

  Widget _buildFriendsSection() {
    final async = ref.watch(friendsProvider);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Padding(
          padding: EdgeInsets.fromLTRB(20, 32, 20, 8),
          child: Text(
            'FRIENDS',
            style: TextStyle(
              color: AppTheme.textSecondary,
              fontSize: 11,
              fontWeight: FontWeight.w600,
              letterSpacing: 2,
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: async.when(
            loading: () => const Center(
              child: Padding(
                padding: EdgeInsets.all(16),
                child: CircularProgressIndicator(color: AppTheme.accent),
              ),
            ),
            error: (e, st) => const Text(
              'Failed to load friends.',
              style: TextStyle(color: AppTheme.speedRed, fontSize: 13),
            ),
            data: (friends) {
              if (friends.isEmpty) {
                return const Padding(
                  padding: EdgeInsets.symmetric(vertical: 12),
                  child: Text(
                    'No friends yet. Find drivers on the leaderboard.',
                    style: TextStyle(
                      color: AppTheme.textSecondary,
                      fontSize: 13,
                    ),
                  ),
                );
              }
              return Column(
                children: friends
                    .map((f) => Padding(
                          padding: const EdgeInsets.only(bottom: 10),
                          child: _FriendCard(entry: f),
                        ))
                    .toList(),
              );
            },
          ),
        ),
      ],
    );
  }

  // ---------------------------------------------------------------------------
  // Sign out
  // ---------------------------------------------------------------------------

  Widget _buildSignOutButton() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
      child: SizedBox(
        height: 48,
        child: OutlinedButton.icon(
          onPressed: _signOut,
          icon: const Icon(Icons.logout_rounded, size: 18),
          label: const Text(
            'SIGN OUT',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              letterSpacing: 1.5,
            ),
          ),
          style: OutlinedButton.styleFrom(
            foregroundColor: AppTheme.textSecondary,
            side: BorderSide(
              color: AppTheme.textSecondary.withValues(alpha: 0.25),
            ),
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Shared styling helpers
  // ---------------------------------------------------------------------------

  Widget _fieldLabel(String text) {
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

  InputDecoration _inputDecoration({required String hint}) {
    return InputDecoration(
      hintText: hint,
      hintStyle:
          const TextStyle(color: AppTheme.textSecondary, fontSize: 14),
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
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: AppTheme.speedRed),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide:
            const BorderSide(color: AppTheme.speedRed, width: 1.5),
      ),
      errorStyle:
          const TextStyle(color: AppTheme.speedRed, fontSize: 12),
    );
  }
}

// =============================================================================
// Reusable styled dropdown with optional search
// =============================================================================

class _StyledDropdown<T> extends StatefulWidget {
  final T? value;
  final String hint;
  final List<T> items;
  final String Function(T) itemLabel;
  final void Function(T?) onChanged;
  final String? searchHint;
  final void Function(String)? onSearchChanged;
  final String? searchValue;
  final List<T>? filteredItems;

  const _StyledDropdown({
    required this.value,
    required this.hint,
    required this.items,
    required this.itemLabel,
    required this.onChanged,
    this.searchHint,
    this.onSearchChanged,
    this.searchValue,
    this.filteredItems,
  });

  @override
  State<_StyledDropdown<T>> createState() => _StyledDropdownState<T>();
}

class _StyledDropdownState<T> extends State<_StyledDropdown<T>> {
  final _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    if (widget.searchValue != null) {
      _searchController.text = widget.searchValue!;
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _openSheet() {
    _searchController.text = widget.searchValue ?? '';
    showModalBottomSheet<T>(
      context: context,
      backgroundColor: AppTheme.surface,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => _DropdownSheet<T>(
        items: widget.filteredItems ?? widget.items,
        allItems: widget.items,
        itemLabel: widget.itemLabel,
        searchHint: widget.searchHint,
        searchController: _searchController,
        onSearchChanged: widget.onSearchChanged,
        onSelected: (val) {
          Navigator.pop(ctx);
          widget.onChanged(val);
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final hasValue = widget.value != null;
    return GestureDetector(
      onTap: _openSheet,
      child: Container(
        height: 52,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        decoration: BoxDecoration(
          color: AppTheme.surfaceHigh,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: AppTheme.accent.withValues(alpha: 0.15),
          ),
        ),
        child: Row(
          children: [
            Expanded(
              child: Text(
                hasValue ? widget.itemLabel(widget.value as T) : widget.hint,
                style: TextStyle(
                  color: hasValue
                      ? AppTheme.textPrimary
                      : AppTheme.textSecondary,
                  fontSize: 14,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const Icon(
              Icons.keyboard_arrow_down_rounded,
              color: AppTheme.textSecondary,
              size: 20,
            ),
          ],
        ),
      ),
    );
  }
}

// Bottom sheet content
class _DropdownSheet<T> extends StatefulWidget {
  final List<T> items;
  final List<T> allItems;
  final String Function(T) itemLabel;
  final String? searchHint;
  final TextEditingController searchController;
  final void Function(String)? onSearchChanged;
  final void Function(T) onSelected;

  const _DropdownSheet({
    required this.items,
    required this.allItems,
    required this.itemLabel,
    required this.searchController,
    required this.onSelected,
    this.searchHint,
    this.onSearchChanged,
  });

  @override
  State<_DropdownSheet<T>> createState() => _DropdownSheetState<T>();
}

class _DropdownSheetState<T> extends State<_DropdownSheet<T>> {
  late List<T> _filtered;

  @override
  void initState() {
    super.initState();
    _filtered = widget.allItems;
    widget.searchController.addListener(_onSearch);
  }

  @override
  void dispose() {
    widget.searchController.removeListener(_onSearch);
    super.dispose();
  }

  void _onSearch() {
    final q = widget.searchController.text.toLowerCase();
    setState(() {
      _filtered = q.isEmpty
          ? widget.allItems
          : widget.allItems
              .where((i) => widget.itemLabel(i).toLowerCase().contains(q))
              .toList();
    });
    widget.onSearchChanged?.call(widget.searchController.text);
  }

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.6,
      maxChildSize: 0.92,
      minChildSize: 0.4,
      expand: false,
      builder: (_, scrollController) {
        return Column(
          children: [
            // Handle bar
            Container(
              margin: const EdgeInsets.symmetric(vertical: 12),
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                color: AppTheme.textSecondary.withValues(alpha: 0.3),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            // Search field
            if (widget.searchHint != null)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                child: TextField(
                  controller: widget.searchController,
                  autofocus: true,
                  style: const TextStyle(
                    color: AppTheme.textPrimary,
                    fontSize: 14,
                  ),
                  decoration: InputDecoration(
                    hintText: widget.searchHint,
                    hintStyle: const TextStyle(
                      color: AppTheme.textSecondary,
                      fontSize: 14,
                    ),
                    prefixIcon: const Icon(
                      Icons.search_rounded,
                      color: AppTheme.textSecondary,
                      size: 18,
                    ),
                    filled: true,
                    fillColor: AppTheme.surfaceHigh,
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 12,
                    ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: BorderSide(
                        color: AppTheme.accent.withValues(alpha: 0.15),
                      ),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: BorderSide(
                        color: AppTheme.accent.withValues(alpha: 0.15),
                      ),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: const BorderSide(
                        color: AppTheme.accent,
                        width: 1.5,
                      ),
                    ),
                  ),
                ),
              ),
            // List
            Expanded(
              child: _filtered.isEmpty
                  ? const Center(
                      child: Text(
                        'No results.',
                        style: TextStyle(color: AppTheme.textSecondary),
                      ),
                    )
                  : ListView.builder(
                      controller: scrollController,
                      itemCount: _filtered.length,
                      itemBuilder: (_, i) {
                        final item = _filtered[i];
                        return InkWell(
                          onTap: () => widget.onSelected(item),
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 20,
                              vertical: 14,
                            ),
                            decoration: BoxDecoration(
                              border: Border(
                                bottom: BorderSide(
                                  color: AppTheme.accent
                                      .withValues(alpha: 0.06),
                                  width: 1,
                                ),
                              ),
                            ),
                            child: Text(
                              widget.itemLabel(item),
                              style: const TextStyle(
                                color: AppTheme.textPrimary,
                                fontSize: 14,
                              ),
                            ),
                          ),
                        );
                      },
                    ),
            ),
          ],
        );
      },
    );
  }
}

// =============================================================================
// Maintenance entry card
// =============================================================================

class _MaintenanceCard extends StatelessWidget {
  final MaintenanceEntry entry;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const _MaintenanceCard({
    required this.entry,
    required this.onEdit,
    required this.onDelete,
  });

  Color _dueDateColor(DateTime due) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final dueDay = DateTime(due.year, due.month, due.day);
    if (dueDay.isBefore(today)) return AppTheme.speedRed;
    if (dueDay.difference(today).inDays <= 30) return AppTheme.speedYellow;
    return AppTheme.speedGreen;
  }

  String _formatDate(DateTime d) {
    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
    ];
    return '${months[d.month - 1]} ${d.day}, ${d.year}';
  }

  @override
  Widget build(BuildContext context) {
    return Dismissible(
      key: ValueKey(entry.entryId),
      direction: DismissDirection.endToStart,
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        decoration: BoxDecoration(
          color: AppTheme.speedRed.withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(14),
        ),
        child: const Icon(Icons.delete_outline, color: AppTheme.speedRed),
      ),
      onDismissed: (_) => onDelete(),
      child: GestureDetector(
        onTap: onEdit,
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppTheme.surface,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: AppTheme.accent.withValues(alpha: 0.15),
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                entry.type,
                style: const TextStyle(
                  color: AppTheme.textPrimary,
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                'Last done: ${_formatDate(entry.lastDoneDate)}',
                style: const TextStyle(
                  color: AppTheme.textSecondary,
                  fontSize: 13,
                ),
              ),
              if (entry.nextDueDate != null) ...[
                const SizedBox(height: 4),
                Text(
                  'Next due: ${_formatDate(entry.nextDueDate!)}',
                  style: TextStyle(
                    color: _dueDateColor(entry.nextDueDate!),
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
              if (entry.notes != null && entry.notes!.isNotEmpty) ...[
                const SizedBox(height: 6),
                Text(
                  entry.notes!,
                  style: const TextStyle(
                    color: AppTheme.textSecondary,
                    fontSize: 13,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

// =============================================================================
// Friend request card
// =============================================================================

class _FriendRequestCard extends ConsumerWidget {
  final FriendRequest request;

  const _FriendRequestCard({required this.request});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppTheme.accent.withValues(alpha: 0.15)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              request.fromUsername,
              style: const TextStyle(
                color: AppTheme.textPrimary,
                fontSize: 15,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          const SizedBox(width: 8),
          TextButton(
            onPressed: () async {
              await friendService.rejectRequest(request.requestId);
            },
            style: TextButton.styleFrom(
              foregroundColor: AppTheme.textSecondary,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              minimumSize: Size.zero,
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
            child: const Text('Reject', style: TextStyle(fontSize: 13)),
          ),
          const SizedBox(width: 4),
          ElevatedButton(
            onPressed: () async {
              await friendService.acceptRequest(
                request.requestId,
                request.fromUid,
                FirebaseAuth.instance.currentUser!.uid,
              );
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.accent,
              foregroundColor: AppTheme.background,
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              minimumSize: Size.zero,
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            child: const Text(
              'Accept',
              style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }
}

// =============================================================================
// Friend card
// =============================================================================

class _FriendCard extends StatelessWidget {
  final FriendEntry entry;

  const _FriendCard({required this.entry});

  @override
  Widget build(BuildContext context) {
    final carLine = [entry.carMake, entry.carModel]
        .where((s) => s.isNotEmpty)
        .join(' ');
    return GestureDetector(
      onTap: () => context.push('/friends/compare/${entry.uid}'),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppTheme.surface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppTheme.accent.withValues(alpha: 0.15)),
        ),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: AppTheme.accent.withValues(alpha: 0.12),
                shape: BoxShape.circle,
                border: Border.all(
                  color: AppTheme.accent.withValues(alpha: 0.35),
                  width: 1.5,
                ),
              ),
              child: Center(
                child: Text(
                  entry.username.isNotEmpty
                      ? entry.username[0].toUpperCase()
                      : '?',
                  style: const TextStyle(
                    color: AppTheme.accent,
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    entry.username,
                    style: const TextStyle(
                      color: AppTheme.textPrimary,
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  if (carLine.isNotEmpty) ...[
                    const SizedBox(height: 2),
                    Text(
                      carLine,
                      style: const TextStyle(
                        color: AppTheme.textSecondary,
                        fontSize: 13,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            const Icon(
              Icons.chevron_right_rounded,
              color: AppTheme.textSecondary,
              size: 20,
            ),
          ],
        ),
      ),
    );
  }
}
