import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../models/blocked_app_info.dart';
import '../../services/focus_blocker_service.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_typography.dart';
import '../focus/mindful_friction_screen.dart';
import '../../widgets/restricted_settings_help.dart';
import '../../widgets/app_back_button.dart';

class AppBlockerSettingsScreen extends StatefulWidget {
  const AppBlockerSettingsScreen({super.key});

  @override
  State<AppBlockerSettingsScreen> createState() =>
      _AppBlockerSettingsScreenState();
}

class _AppBlockerSettingsScreenState extends State<AppBlockerSettingsScreen>
    with WidgetsBindingObserver {
  final FocusBlockerService _service = FocusBlockerService();
  final TextEditingController _searchController = TextEditingController();

  List<BlockedAppInfo> _allApps = [];
  bool _isLoading = true;
  bool _isAccessibilityGranted = false;
  bool _isMasterEnabled = true;
  String _selectedCategory = 'all';
  String _searchQuery = '';

  final List<String> _categories = [
    'all',
    'social',
    'game',
    'entertainment',
    'messaging',
    'other',
  ];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _isMasterEnabled = _service.isShieldEnabled();
    _loadData();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _checkPermission();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _checkPermission() async {
    final granted = await _service.isAccessibilityGranted();
    if (mounted) {
      setState(() => _isAccessibilityGranted = granted);
    }
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    final granted = await _service.isAccessibilityGranted();
    final apps = await _service.getInstalledApps();

    if (mounted) {
      setState(() {
        _isAccessibilityGranted = granted;
        _allApps = apps;
        _isLoading = false;
      });
    }
  }

  Future<void> _toggleApp(BlockedAppInfo app) async {
    HapticFeedback.selectionClick();
    final newBlockedState = !app.isBlocked;
    await _service.toggleAppBlocked(app.packageName, newBlockedState);
    setState(() {
      final index = _allApps.indexWhere(
        (a) => a.packageName == app.packageName,
      );
      if (index != -1) {
        _allApps[index] = app.copyWith(isBlocked: newBlockedState);
      }
    });
  }

  List<BlockedAppInfo> get _filteredApps {
    return _allApps.where((app) {
      if (_selectedCategory != 'all' && app.category != _selectedCategory) {
        return false;
      }
      if (_searchQuery.isNotEmpty) {
        final query = _searchQuery.toLowerCase();
        return app.name.toLowerCase().contains(query);
      }
      return true;
    }).toList();
  }

  int get _totalBlockedCount => _allApps.where((a) => a.isBlocked).length;

  String _categoryDisplayName(String cat) {
    switch (cat) {
      case 'all':
        return 'All';
      case 'social':
        return 'Social';
      case 'game':
        return 'Games';
      case 'entertainment':
        return 'Media';
      case 'messaging':
        return 'Messages';
      default:
        return 'Other';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.appBackground,
      body: SafeArea(
        child: _isLoading
            ? Center(
                child: CircularProgressIndicator(
                  color: AppColors.accentPrimary,
                  strokeWidth: 2,
                ),
              )
            : SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 48),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // ── Apple Top Bar (consistent with ProfileScreen) ───────────
                    Row(
                      children: [
                        const AppBackButton(
                          margin: EdgeInsets.only(right: 12),
                        ),
                        Expanded(
                          child: Text(
                            'Focus Shield',
                            style: AppTypography.displayHeading.copyWith(
                              fontSize: AppColors.isRetro ? 15 : 22,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        // Preview lock screen icon
                        Semantics(
                          label: 'Preview Focus Shield',
                          button: true,
                          child: GestureDetector(
                            onTap: () {
                              HapticFeedback.lightImpact();
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => MindfulFrictionScreen(
                                    packageName: 'com.example.preview',
                                    appName: 'Social Media',
                                    taskName: 'Deep Work Session',
                                    taskEndTime: DateTime.now().add(
                                      const Duration(minutes: 25),
                                    ),
                                  ),
                                ),
                              );
                            },
                            child: Container(
                              width: 48,
                              height: 48,
                              margin: const EdgeInsets.only(right: 8),
                              decoration: BoxDecoration(
                                color: AppColors.cardBackground,
                                borderRadius: AppColors.isRetro
                                    ? BorderRadius.zero
                                    : BorderRadius.circular(12),
                                border: Border.all(
                                  color: AppColors.cardBorder,
                                  width: AppColors.isRetro ? 2.0 : 1.0,
                                ),
                                boxShadow: AppColors.isRetro
                                    ? [
                                        BoxShadow(
                                          color: AppColors.retroShadowColor,
                                          offset: const Offset(2, 2),
                                          blurRadius: 0,
                                        ),
                                      ]
                                    : null,
                              ),
                              child: Icon(
                                Icons.visibility_outlined,
                                color: AppColors.textSecondary,
                                size: 18,
                              ),
                            ),
                          ),
                        ),
                        // Master Switch
                        Semantics(
                          label: 'Enable Focus Shield',
                          child: Switch.adaptive(
                            value: _isMasterEnabled,
                            activeThumbColor: Theme.of(
                              context,
                            ).colorScheme.onPrimary,
                            activeTrackColor: AppColors.accentPrimary,
                            inactiveTrackColor: AppColors.cardHoverActive,
                            onChanged: (val) async {
                              HapticFeedback.lightImpact();
                              setState(() => _isMasterEnabled = val);
                              await _service.setShieldEnabled(val);
                            },
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 8),

                    // Subtitle + counter
                    Wrap(
                      spacing: 12,
                      runSpacing: 8,
                      children: [
                        Text(
                          'Blocks apps during active DND tasks',
                          style: AppTypography.bodyText.copyWith(
                            fontSize: 12.5,
                            color: AppColors.textMuted,
                          ),
                        ),
                        Text(
                          '$_totalBlockedCount blocked',
                          style: AppTypography.cardTime.copyWith(
                            fontSize: 12,
                            color: _totalBlockedCount > 0
                                ? AppColors.accentPrimary
                                : AppColors.textPlaceholder,
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 20),

                    // ── Permission Notice (only if missing) ─────────────────
                    if (!_isAccessibilityGranted) ...[
                      _buildPermissionNotice(),
                      const SizedBox(height: 12),
                      const RestrictedSettingsHelp(),
                      const SizedBox(height: 20),
                    ],

                    // ── Search & Filter ─────────────────────────────────────
                    _buildSectionLabel('SEARCH & CATEGORIES'),
                    _buildSearchBar(),

                    const SizedBox(height: 12),
                    _buildCategoryPills(),

                    const SizedBox(height: 24),

                    // ── Apps Group ──────────────────────────────────────────
                    Wrap(
                      alignment: WrapAlignment.spaceBetween,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      spacing: 12,
                      children: [
                        _buildSectionLabel(
                          'INSTALLED APPS (${_filteredApps.length})',
                        ),
                        if (_filteredApps.isNotEmpty)
                          TextButton(
                            onPressed: _toggleAllInCurrentCategory,
                            child: Text(
                              _isAllCurrentBlocked ? 'Unlock all' : 'Lock all',
                              style: AppTypography.cardTime.copyWith(
                                fontSize: 11.5,
                                color: AppColors.accentPrimary,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                      ],
                    ),

                    // Grouped App Card (consistent with ProfileScreen grouped cards)
                    if (_filteredApps.isEmpty)
                      _buildEmptyState()
                    else
                      Container(
                        decoration: BoxDecoration(
                          color: AppColors.cardBackground,
                          borderRadius: AppColors.isRetro
                              ? BorderRadius.zero
                              : BorderRadius.circular(16),
                          border: Border.all(
                            color: AppColors.cardBorder,
                            width: AppColors.isRetro ? 2.0 : 1.0,
                          ),
                          boxShadow: AppColors.isRetro
                              ? [
                                  BoxShadow(
                                    color: AppColors.retroShadowColor,
                                    offset: const Offset(3, 3),
                                    blurRadius: 0,
                                  ),
                                ]
                              : null,
                        ),
                        child: ClipRRect(
                          borderRadius: AppColors.isRetro
                              ? BorderRadius.zero
                              : BorderRadius.circular(16),
                          child: ListView.separated(
                            shrinkWrap: true,
                            physics: const NeverScrollableScrollPhysics(),
                            itemCount: _filteredApps.length,
                            separatorBuilder: (_, index) => Divider(
                              height: 1,
                              thickness: 1,
                              color: AppColors.subtleBorder,
                              indent: 62,
                            ),
                            itemBuilder: (context, index) =>
                                _buildAppRow(_filteredApps[index]),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
      ),
    );
  }

  bool get _isAllCurrentBlocked {
    return _filteredApps.isNotEmpty && _filteredApps.every((a) => a.isBlocked);
  }

  void _toggleAllInCurrentCategory() {
    final list = _filteredApps;
    final allBlocked = _isAllCurrentBlocked;
    final pkgs = list.map((a) => a.packageName).toList();
    _service.batchSetBlocked(pkgs, !allBlocked);
    setState(() {
      final set = pkgs.toSet();
      _allApps = _allApps.map((a) {
        if (set.contains(a.packageName)) {
          return a.copyWith(isBlocked: !allBlocked);
        }
        return a;
      }).toList();
    });
  }

  Widget _buildSectionLabel(String label) {
    return Padding(
      padding: const EdgeInsets.only(left: 4, bottom: 8),
      child: Text(
        label,
        style: AppTypography.sectionLabel.copyWith(
          fontSize: AppColors.isRetro ? 9.5 : 11,
          letterSpacing: 1.0,
          color: AppColors.textPlaceholder,
        ),
      ),
    );
  }

  Widget _buildPermissionNotice() {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.cardBackground,
        borderRadius: AppColors.isRetro
            ? BorderRadius.zero
            : BorderRadius.circular(16),
        border: Border.all(
          color: AppColors.warningTag.withValues(
            alpha: AppColors.isRetro ? 0.6 : 0.25,
          ),
          width: AppColors.isRetro ? 2.0 : 1.0,
        ),
        boxShadow: AppColors.isRetro
            ? [
                BoxShadow(
                  color: AppColors.retroShadowColor,
                  offset: const Offset(3, 3),
                  blurRadius: 0,
                ),
              ]
            : null,
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () {
            HapticFeedback.selectionClick();
            _service.openAccessibilitySettings();
          },
          borderRadius: AppColors.isRetro
              ? BorderRadius.zero
              : BorderRadius.circular(16),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Row(
              children: [
                Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    color: AppColors.warningTag.withValues(alpha: 0.14),
                    borderRadius: AppColors.isRetro
                        ? BorderRadius.zero
                        : BorderRadius.circular(9),
                    border: AppColors.isRetro
                        ? Border.all(color: AppColors.cardBorder, width: 1.5)
                        : null,
                  ),
                  child: Icon(
                    Icons.shield_outlined,
                    color: AppColors.warningTag,
                    size: 17,
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Accessibility Permission Needed',
                        style: AppTypography.cardTitle.copyWith(
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Tap to enable Focus Shield in system settings',
                        style: AppTypography.bodyText.copyWith(
                          fontSize: 12,
                          color: AppColors.textMuted,
                        ),
                      ),
                    ],
                  ),
                ),
                Icon(
                  Icons.arrow_forward_ios_rounded,
                  size: 13,
                  color: AppColors.textPlaceholder,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSearchBar() {
    return Container(
      constraints: const BoxConstraints(minHeight: 48),
      decoration: BoxDecoration(
        color: AppColors.isRetro
            ? AppColors.inputBackground
            : AppColors.cardBackground,
        borderRadius: AppColors.isRetro
            ? BorderRadius.zero
            : BorderRadius.circular(12),
        border: Border.all(
          color: AppColors.cardBorder,
          width: AppColors.isRetro ? 2.0 : 1.0,
        ),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 14),
      alignment: Alignment.center,
      child: TextField(
        controller: _searchController,
        textAlignVertical: TextAlignVertical.center,
        style: AppTypography.bodyText.copyWith(
          color: AppColors.textPrimary,
          fontSize: 13.5,
        ),
        decoration: InputDecoration(
          isDense: true,
          filled: false,
          fillColor: Colors.transparent,
          contentPadding: EdgeInsets.zero,
          border: InputBorder.none,
          enabledBorder: InputBorder.none,
          focusedBorder: InputBorder.none,
          hintText: 'Search installed apps...',
          hintStyle: AppTypography.bodyText.copyWith(
            color: AppColors.textPlaceholder,
            fontSize: 13.5,
          ),
          prefixIcon: Padding(
            padding: const EdgeInsets.only(right: 10),
            child: Icon(
              Icons.search_rounded,
              size: 18,
              color: AppColors.textPlaceholder,
            ),
          ),
          prefixIconConstraints: const BoxConstraints(
            minWidth: 18,
            minHeight: 18,
          ),
          suffixIcon: _searchQuery.isNotEmpty
              ? IconButton(
                  tooltip: 'Clear app search',
                  onPressed: () {
                    _searchController.clear();
                    setState(() => _searchQuery = '');
                  },
                  icon: Icon(
                    Icons.close_rounded,
                    size: 16,
                    color: AppColors.textPlaceholder,
                  ),
                )
              : null,
          suffixIconConstraints: const BoxConstraints(
            minWidth: 48,
            minHeight: 48,
          ),
        ),
        onChanged: (val) => setState(() => _searchQuery = val.trim()),
      ),
    );
  }

  Widget _buildCategoryPills() {
    return SizedBox(
      height: 24 + MediaQuery.textScalerOf(context).scale(24),
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: _categories.length,
        separatorBuilder: (_, index) => const SizedBox(width: 8),
        itemBuilder: (context, index) {
          final cat = _categories[index];
          final isSelected = _selectedCategory == cat;

          return Semantics(
            button: true,
            selected: isSelected,
            child: GestureDetector(
              onTap: () {
                HapticFeedback.selectionClick();
                setState(() => _selectedCategory = cat);
              },
              child: AnimatedContainer(
                duration: MediaQuery.disableAnimationsOf(context)
                    ? Duration.zero
                    : const Duration(milliseconds: 150),
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: isSelected
                      ? AppColors.accentPrimary
                      : AppColors.cardBackground,
                  borderRadius: AppColors.isRetro
                      ? BorderRadius.zero
                      : BorderRadius.circular(10),
                  border: Border.all(
                    color: isSelected
                        ? (AppColors.isRetro
                              ? AppColors.cardBorder
                              : AppColors.accentPrimary)
                        : AppColors.cardBorder,
                    width: AppColors.isRetro ? 1.5 : 1.0,
                  ),
                  boxShadow: (AppColors.isRetro && isSelected)
                      ? [
                          BoxShadow(
                            color: AppColors.retroShadowColor,
                            offset: const Offset(2, 2),
                            blurRadius: 0,
                          ),
                        ]
                      : null,
                ),
                child: Center(
                  child: Text(
                    _categoryDisplayName(cat),
                    style: AppTypography.tagChip.copyWith(
                      color: isSelected
                          ? (AppColors.isRetro && !AppColors.isDark
                                ? AppColors.textPrimary
                                : Colors.white)
                          : AppColors.textSecondary,
                      fontSize: AppColors.isRetro ? 11 : 12,
                      fontWeight: isSelected
                          ? FontWeight.w600
                          : FontWeight.w400,
                    ),
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildAppRow(BlockedAppInfo app) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => _toggleApp(app),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Row(
            children: [
              ClipRRect(
                borderRadius: AppColors.isRetro
                    ? BorderRadius.zero
                    : BorderRadius.circular(8),
                child: app.iconBytes != null
                    ? Image.memory(
                        app.iconBytes!,
                        width: 34,
                        height: 34,
                        fit: BoxFit.cover,
                      )
                    : Container(
                        width: 34,
                        height: 34,
                        decoration: BoxDecoration(
                          color: AppColors.cardHoverActive,
                          borderRadius: AppColors.isRetro
                              ? BorderRadius.zero
                              : BorderRadius.circular(8),
                          border: AppColors.isRetro
                              ? Border.all(
                                  color: AppColors.cardBorder,
                                  width: 1.0,
                                )
                              : null,
                        ),
                        child: Icon(
                          Icons.apps_rounded,
                          size: 18,
                          color: AppColors.textSecondary,
                        ),
                      ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Text(
                  app.name,
                  style: AppTypography.cardTitle.copyWith(
                    fontSize: 14.5,
                    fontWeight: FontWeight.w500,
                    color: AppColors.textPrimary,
                  ),
                ),
              ),
              Semantics(
                label: 'Block ${app.name}',
                child: Switch.adaptive(
                  value: app.isBlocked,
                  activeThumbColor: Theme.of(context).colorScheme.onPrimary,
                  activeTrackColor: AppColors.accentPrimary,
                  inactiveTrackColor: AppColors.cardHoverActive,
                  onChanged: (_) => _toggleApp(app),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 40),
      alignment: Alignment.center,
      child: Text(
        'No apps found',
        style: AppTypography.bodyText.copyWith(
          color: AppColors.textPlaceholder,
        ),
      ),
    );
  }
}
