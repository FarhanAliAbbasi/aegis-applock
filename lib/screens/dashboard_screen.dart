import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../state/app_lock_state.dart';
import '../theme/app_theme.dart';
import '../widgets/app_list_tile.dart';
import 'settings_screen.dart';

class DashboardScreen extends StatefulWidget {
  final AppLockState state;

  const DashboardScreen({super.key, required this.state});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  final TextEditingController _searchController = TextEditingController();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: widget.state,
      builder: (context, _) {
        final state = widget.state;

        return Scaffold(
          backgroundColor: AppTheme.background,
          appBar: AppBar(
            leading: Padding(
              padding: const EdgeInsets.only(left: 16),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: Image.asset(
                  'assets/images/logo.jpg',
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => const Icon(
                    Icons.shield_rounded,
                    color: AppTheme.primaryCyan,
                  ),
                ),
              ),
            ),
            title: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Aegis AppLock',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 0.5,
                  ),
                ),
                Row(
                  children: [
                    Container(
                      width: 7,
                      height: 7,
                      decoration: const BoxDecoration(
                        color: AppTheme.accentGreen,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 5),
                    Text(
                      '${state.lockedCount} apps protected',
                      style: const TextStyle(
                        fontSize: 11,
                        color: AppTheme.accentGreen,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ],
            ),
            actions: [
              IconButton(
                icon: const Icon(Icons.security_outlined, color: AppTheme.textPrimary),
                tooltip: 'Settings & Security',
                onPressed: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => SettingsScreen(state: state),
                    ),
                  );
                },
              ),
              const SizedBox(width: 8),
            ],
          ),
          body: state.isLoading
              ? const Center(
                  child: CircularProgressIndicator(color: AppTheme.primaryCyan),
                )
              : RefreshIndicator(
                  color: AppTheme.primaryCyan,
                  backgroundColor: AppTheme.cardColor,
                  onRefresh: () async {
                    await state.refreshApps();
                    await state.refreshPermissions();
                  },
                  child: CustomScrollView(
                    slivers: [
                      // Search Bar & Filter Chips Header
                      SliverToBoxAdapter(
                        child: Padding(
                          padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              _buildSearchBar(state),
                              const SizedBox(height: 12),
                              _buildFilterChips(state),
                              const SizedBox(height: 14),
                              if (state.searchQuery.isEmpty &&
                                  state.currentFilter == AppFilter.all)
                                _buildQuickLockBanner(state),
                            ],
                          ),
                        ),
                      ),

                      // Apps List
                      state.filteredApps.isEmpty
                          ? SliverFillRemaining(
                              hasScrollBody: false,
                              child: _buildEmptyState(),
                            )
                          : SliverList(
                              delegate: SliverChildBuilderDelegate(
                                (context, index) {
                                  final app = state.filteredApps[index];
                                  return AppListTile(
                                    app: app,
                                    onToggle: (_) {
                                      state.toggleAppLock(app.packageName);
                                    },
                                  );
                                },
                                childCount: state.filteredApps.length,
                              ),
                            ),

                      const SliverToBoxAdapter(
                        child: SizedBox(height: 32),
                      ),
                    ],
                  ),
                ),
        );
      },
    );
  }

  Widget _buildSearchBar(AppLockState state) {
    return TextField(
      controller: _searchController,
      onChanged: state.setSearchQuery,
      style: const TextStyle(color: AppTheme.textPrimary, fontSize: 14),
      decoration: InputDecoration(
        hintText: 'Search WhatsApp, Instagram, or any app...',
        prefixIcon: const Icon(Icons.search_rounded, color: AppTheme.textMuted, size: 20),
        suffixIcon: _searchController.text.isNotEmpty
            ? IconButton(
                icon: const Icon(Icons.close_rounded, color: AppTheme.textMuted, size: 18),
                onPressed: () {
                  _searchController.clear();
                  state.setSearchQuery('');
                },
              )
            : null,
      ),
    );
  }

  Widget _buildFilterChips(AppLockState state) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          _filterChip(
            label: 'All (${state.allApps.length})',
            isSelected: state.currentFilter == AppFilter.all,
            onTap: () => state.setFilter(AppFilter.all),
          ),
          const SizedBox(width: 8),
          _filterChip(
            label: 'Locked (${state.lockedCount})',
            isSelected: state.currentFilter == AppFilter.locked,
            onTap: () => state.setFilter(AppFilter.locked),
            accent: AppTheme.primaryCyan,
          ),
          const SizedBox(width: 8),
          _filterChip(
            label: 'Social & Chat',
            isSelected: state.currentFilter == AppFilter.social,
            onTap: () => state.setFilter(AppFilter.social),
            accent: AppTheme.primaryBlue,
          ),
          const SizedBox(width: 8),
          _filterChip(
            label: 'Sensitive & Bank',
            isSelected: state.currentFilter == AppFilter.sensitive,
            onTap: () => state.setFilter(AppFilter.sensitive),
            accent: AppTheme.accentGreen,
          ),
        ],
      ),
    );
  }

  Widget _filterChip({
    required String label,
    required bool isSelected,
    required VoidCallback onTap,
    Color? accent,
  }) {
    final chipAccent = accent ?? AppTheme.primaryCyan;
    return InkWell(
      onTap: () {
        HapticFeedback.selectionClick();
        onTap();
      },
      borderRadius: BorderRadius.circular(20),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected
              ? chipAccent.withValues(alpha: 0.15)
              : AppTheme.cardColor,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected ? chipAccent : const Color(0xFF232F48),
            width: isSelected ? 1.4 : 1,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isSelected ? chipAccent : AppTheme.textSecondary,
            fontSize: 12,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
          ),
        ),
      ),
    );
  }

  Widget _buildQuickLockBanner(AppLockState state) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppTheme.cardColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFF232F48)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: AppTheme.primaryCyan.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(
              Icons.flash_on_rounded,
              color: AppTheme.primaryCyan,
              size: 20,
            ),
          ),
          const SizedBox(width: 12),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'One-Tap Quick Protect',
                  style: TextStyle(
                    color: AppTheme.textPrimary,
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  'Instantly lock WhatsApp, Insta, Photos & Settings',
                  style: TextStyle(color: AppTheme.textMuted, fontSize: 11),
                ),
              ],
            ),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.primaryCyan,
              foregroundColor: const Color(0xFF0B0F19),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              elevation: 0,
            ),
            onPressed: () {
              HapticFeedback.mediumImpact();
              state.lockAllSensitive();
            },
            child: const Text(
              'Lock All',
              style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.search_off_rounded,
              size: 56,
              color: AppTheme.textMuted,
            ),
            const SizedBox(height: 16),
            const Text(
              'No applications found',
              style: TextStyle(
                color: AppTheme.textPrimary,
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 6),
            const Text(
              'Try adjusting your search query or switching category filter tabs.',
              textAlign: TextAlign.center,
              style: TextStyle(color: AppTheme.textMuted, fontSize: 13),
            ),
          ],
        ),
      ),
    );
  }
}
