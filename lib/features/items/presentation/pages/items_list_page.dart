import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_slidable/flutter_slidable.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../../../core/di/injection.dart';
import '../../../auth/presentation/bloc/auth_bloc.dart';
import '../../../auth/presentation/bloc/auth_state.dart' as auth;
import '../../../../core/state/app_ui_state.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../bluetooth/domain/usecases/request_device_data_usecase.dart';
import '../../../bluetooth/presentation/bloc/bluetooth_bloc.dart';
import '../../../bluetooth/presentation/bloc/bluetooth_event.dart';
import '../../../bluetooth/presentation/bloc/bluetooth_state.dart';
import '../../domain/entities/item.dart';
import '../../domain/repositories/item_repository.dart';
import '../../../categories/domain/entities/category.dart' as cat;
import '../../../categories/presentation/bloc/categories_bloc.dart';
import '../../../categories/presentation/bloc/categories_event.dart';
import '../../../categories/presentation/bloc/categories_state.dart';
import '../bloc/items_bloc.dart';
import '../bloc/items_event.dart';
import '../bloc/items_state.dart';
import 'item_form_page.dart';

/// Wrapper that rebuilds when auth state changes
class ItemsListPage extends StatelessWidget {
  const ItemsListPage({super.key});

  static String routeName = 'ItemsListPage';
  static String routePath = '/';

  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    final primaryBackground = AppColors.primaryBackground(brightness);

    // Use BlocBuilder to rebuild when auth state changes
    return BlocBuilder<AuthBloc, auth.AuthState>(
      builder: (context, state) {
        // Show loading while waiting for auth
        if (state is! auth.Authenticated) {
          return Scaffold(
            backgroundColor: primaryBackground,
            body: Center(
              child: CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(AppColors.primary),
              ),
            ),
          );
        }
        final userId = state.user.id;
        return _ItemsListContent(key: ValueKey(userId), userId: userId);
      },
    );
  }
}

class _ItemsListContent extends StatefulWidget {
  const _ItemsListContent({super.key, required this.userId});

  final String userId;

  @override
  State<_ItemsListContent> createState() => _ItemsListContentState();
}

class _ItemsListContentState extends State<_ItemsListContent>
    with TickerProviderStateMixin {
  final scaffoldKey = GlobalKey<ScaffoldState>();
  late final SlidableController _firstItemController;
  late final AnimationController _reorderHintController;
  late final Animation<double> _liftAnimation;
  bool _swipeHintTriggered = false;
  bool _reorderHintTriggered = false;

  // Search state
  bool _isSearching = false;
  final _searchController = TextEditingController();
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _firstItemController = SlidableController(this);

    // Animation for reorder hint: lift effect
    _reorderHintController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    _liftAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _reorderHintController, curve: Curves.easeOutCubic),
    );
  }

  /// Builds a map of categoryId -> categoryName from the CategoriesBloc state.
  Map<String, String> _buildCategoryNamesMap(BuildContext context) {
    final categoriesState = context.read<CategoriesBloc>().state;
    if (categoriesState is CategoriesLoaded) {
      return {
        for (final category in categoriesState.categories)
          category.id: category.name,
      };
    }
    return {};
  }

  // Static colors (theme-independent)
  static const Color _primary = Color(0xFF4B39EF);

  // Number formatter for count display
  static final NumberFormat _countFormat = NumberFormat.decimalPattern();
  static const Color _activatedColorLight = Color(0xFFCAC6FF);
  static const Color _activatedColorDark = Color(0xFF3D3A6D);
  static const Color _activateActionColor = Color(0xFF3C38B5);
  static const Color _moveToTopActionColor = Color(0xFF0891B2);
  static const Color _deleteActionColor = Color(0xFFD11F43);
  static const Color _disabledActionColor = Color(0xFF565656);
  static const int _maxItems = 100;

  @override
  Widget build(BuildContext context) {
    final appUiState = context.watch<AppUiState>();
    final brightness = Theme.of(context).brightness;

    // Theme-aware colors
    final primaryBackground = AppColors.primaryBackground(brightness);
    final primaryText = AppColors.primaryText(brightness);
    final secondaryText = AppColors.secondaryText(brightness);
    final alternate = AppColors.alternate(brightness);
    final activatedColor = brightness == Brightness.dark
        ? _activatedColorDark
        : _activatedColorLight;

    // Auth is guaranteed to be ready by parent BlocBuilder
    // Restore saved category filter from AppUiState
    final savedCategoryId = appUiState.selectedCategoryId;

    return MultiBlocProvider(
      providers: [
        BlocProvider(
          create: (context) => sl<ItemsBloc>()
            ..add(WatchItemsEvent(
              widget.userId,
              initialCategoryId: savedCategoryId,
            )),
        ),
        BlocProvider(
          create: (context) => sl<CategoriesBloc>()
            ..add(WatchCategoriesEvent(widget.userId)),
        ),
      ],
      child: BlocBuilder<BluetoothBloc, BluetoothState>(
        builder: (context, bluetoothState) {
          final isConnected = bluetoothState.isConnected;

          return GestureDetector(
            onTap: () {
              FocusScope.of(context).unfocus();
              FocusManager.instance.primaryFocus?.unfocus();
            },
            child: Scaffold(
              key: scaffoldKey,
              backgroundColor: primaryBackground,
              appBar: AppBar(
                backgroundColor: primaryBackground,
                automaticallyImplyLeading: false,
                title: Text(
                  'Items',
                  style: GoogleFonts.interTight(
                    color: primaryText,
                    fontWeight: FontWeight.w600,
                    fontSize: 20.0,
                  ),
                ),
                centerTitle: true,
                elevation: 0.0,
                actions: [
                  // Search icon (opens search, X in search bar closes it)
                  IconButton(
                    onPressed: () {
                      if (!_isSearching) {
                        setState(() => _isSearching = true);
                      }
                    },
                    icon: Icon(
                      Icons.search_rounded,
                      color: _isSearching ? secondaryText : primaryText,
                      size: 24.0,
                    ),
                  ),
                  // Add item button
                  Padding(
                    padding: const EdgeInsets.only(right: 8.0),
                    child: BlocBuilder<ItemsBloc, ItemsState>(
                      builder: (context, itemsState) {
                        return IconButton(
                          onPressed: () async {
                            if (!isConnected) {
                              await _showConnectDeviceDialog(context);
                              return;
                            }
                            // Check item limit
                            if (itemsState is ItemsLoaded && itemsState.items.length >= _maxItems) {
                              await _showItemLimitDialog(context);
                              return;
                            }
                            context.pushNamed(ItemFormPage.routeName);
                          },
                          style: IconButton.styleFrom(
                            backgroundColor: _primary,
                            shape: const CircleBorder(),
                          ),
                          icon: const Icon(
                            Icons.add_rounded,
                            color: Colors.white,
                            size: 24.0,
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ),
              body: SafeArea(
                top: true,
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 600.0),
                    child: Column(
                      mainAxisSize: MainAxisSize.max,
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        // Category Filter Row (only when categories exist)
                        BlocBuilder<CategoriesBloc, CategoriesState>(
                          builder: (context, categoriesState) {
                            final hasCategories = categoriesState is CategoriesLoaded &&
                                categoriesState.categories.isNotEmpty;

                            if (!hasCategories) return const SizedBox.shrink();

                            return Padding(
                              padding: const EdgeInsets.fromLTRB(16.0, 16.0, 16.0, 12.0),
                              child: BlocBuilder<ItemsBloc, ItemsState>(
                                builder: (context, itemsState) {
                                  final selectedCategoryId = itemsState is ItemsLoaded
                                      ? itemsState.selectedCategoryId
                                      : null;
                                  return _buildCategoryDropdown(
                                    context,
                                    categoriesState.categories,
                                    selectedCategoryId,
                                    primaryText,
                                    secondaryText,
                                    alternate,
                                  );
                                },
                              ),
                            );
                          },
                        ),
                        // Active item chip (shows when connected with active item)
                        BlocBuilder<ItemsBloc, ItemsState>(
                          builder: (context, itemsState) {
                            if (!isConnected || itemsState is! ItemsLoaded) {
                              return const SizedBox.shrink();
                            }
                            return _buildActiveItemChip(
                              context,
                              itemsState,
                              bluetoothState,
                              appUiState,
                              primaryText,
                              secondaryText,
                              alternate,
                            );
                          },
                        ),
                        // Search field
                        if (_isSearching)
                          _buildSearchField(context, primaryText, secondaryText, alternate),
                        // Connection status banner
                        if (!isConnected)
                          _buildDisconnectedBanner(context),
                        // Labeled divider showing Today/Total mode
                        _buildLabeledDivider(appUiState, secondaryText),
                        // Items List
                        Expanded(
                          child: Padding(
                            padding: const EdgeInsets.fromLTRB(16.0, 0.0, 16.0, 0.0),
                        child: BlocConsumer<ItemsBloc, ItemsState>(
                          listener: (context, state) {
                            if (state is ItemsError) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text(state.message),
                                  backgroundColor: _deleteActionColor,
                                ),
                              );
                            }
                          },
                          builder: (context, state) {
                            if (state is ItemsLoading) {
                              return Center(
                                child: SizedBox(
                                  width: 50.0,
                                  height: 50.0,
                                  child: CircularProgressIndicator(
                                    valueColor: AlwaysStoppedAnimation<Color>(_primary),
                                  ),
                                ),
                              );
                            }

                            if (state is ItemsLoaded) {
                              // Filter items based on category and search query
                              final categoryFilteredItems = state.filteredItems;
                              final filteredItems = _searchQuery.isEmpty
                                  ? categoryFilteredItems
                                  : categoryFilteredItems.where((item) =>
                                      item.name.toLowerCase().contains(_searchQuery)
                                    ).toList();

                              if (state.items.isEmpty) {
                                return _buildEmptyState(context, primaryText, secondaryText, isConnected);
                              }

                              // Show "no results" if search has no matches
                              if (filteredItems.isEmpty && _searchQuery.isNotEmpty) {
                                return _buildNoSearchResults(context, primaryText, secondaryText);
                              }

                              // Use ReorderableListView when connected and not searching
                              // During search, use ListView with "Move to Top" action instead
                              if (isConnected && _searchQuery.isEmpty) {
                                // Trigger reorder hint when connected and swipe hint already shown
                                if (appUiState.hasShownSwipeHint && !appUiState.hasShownReorderHint && _searchQuery.isEmpty) {
                                  WidgetsBinding.instance.addPostFrameCallback((_) {
                                    _showReorderHint(appUiState, isConnected);
                                  });
                                }
                                return ReorderableListView.builder(
                                  padding: const EdgeInsets.only(top: 8.0, bottom: 80.0),
                                  physics: const AlwaysScrollableScrollPhysics(),
                                  buildDefaultDragHandles: false,
                                  itemCount: filteredItems.length,
                                  onReorderStart: (_) => HapticFeedback.mediumImpact(),
                                  proxyDecorator: (child, index, animation) {
                                    return AnimatedBuilder(
                                      animation: animation,
                                      builder: (context, child) {
                                        final scale = Tween<double>(begin: 1.0, end: 1.03).animate(
                                          CurvedAnimation(parent: animation, curve: Curves.easeInOut),
                                        );
                                        return Transform.scale(
                                          scale: scale.value,
                                          child: Material(
                                            elevation: 4.0 * animation.value,
                                            borderRadius: BorderRadius.circular(8.0),
                                            child: child,
                                          ),
                                        );
                                      },
                                      child: child,
                                    );
                                  },
                                  onReorder: (oldIndex, newIndex) {
                                    // Capture references BEFORE any async operations
                                    final itemsBloc = context.read<ItemsBloc>();
                                    final bluetoothBloc = context.read<BluetoothBloc>();
                                    final selectedId = bluetoothState.selectedItemId;
                                    final currentState = state;
                                    final isFilteredByCategory = currentState.isFilteredByCategory;

                                    // Use appropriate reorder event based on view mode
                                    if (isFilteredByCategory) {
                                      // Viewing a specific category - update categoryOrder
                                      itemsBloc.add(
                                        ReorderItemsInCategoryEvent(
                                          oldIndex: oldIndex,
                                          newIndex: newIndex,
                                        ),
                                      );
                                    } else {
                                      // Viewing all items - update global order
                                      itemsBloc.add(
                                        ReorderItemsEvent(oldIndex: oldIndex, newIndex: newIndex),
                                      );
                                    }

                                    // Sync to device after reorder
                                    // Small delay to let BLoC process the reorder
                                    Future.delayed(const Duration(milliseconds: 100), () {
                                      if (!mounted) return;
                                      final itemsState = itemsBloc.state;
                                      if (itemsState is ItemsLoaded) {
                                        // Sync filtered items to device when category is selected
                                        // Otherwise sync all items
                                        final itemsToSync = isFilteredByCategory
                                            ? itemsState.filteredItems
                                            : itemsState.items;
                                        bluetoothBloc.add(SendItemsToDevice(
                                          itemsToSync,
                                          categoryNames: _buildCategoryNamesMap(context),
                                        ));
                                        // Re-send selected item to update device's index
                                        // (firmware stores selected by index, not just ID)
                                        if (selectedId != null && selectedId.isNotEmpty) {
                                          Future.delayed(const Duration(milliseconds: 200), () {
                                            if (!mounted) return;
                                            bluetoothBloc.add(SendSelectedItem(selectedId));
                                          });
                                        }
                                      }
                                    });
                                  },
                                  itemBuilder: (context, index) {
                                    final item = filteredItems[index];
                                    // Pass animation for first item's reorder hint (only when not searching)
                                    final needsReorderHint = index == 0 && !appUiState.hasShownReorderHint && _searchQuery.isEmpty;
                                    return _buildItemTile(
                                      context,
                                      item,
                                      index,
                                      appUiState,
                                      isConnected,
                                      bluetoothState.selectedItemId,
                                      primaryText,
                                      secondaryText,
                                      alternate,
                                      activatedColor,
                                      liftAnimation: needsReorderHint ? _liftAnimation : null,
                                    );
                                  },
                                );
                              } else {
                                // Trigger swipe hint only in regular ListView (not during reorder, not searching)
                                if (!appUiState.hasShownSwipeHint && _searchQuery.isEmpty) {
                                  WidgetsBinding.instance.addPostFrameCallback((_) {
                                    _showSwipeHint(appUiState);
                                  });
                                }
                                return RefreshIndicator(
                                  color: _primary,
                                  onRefresh: () async {
                                    context.read<ItemsBloc>().add(WatchItemsEvent(widget.userId));
                                    // Wait a bit for the stream to emit
                                    await Future.delayed(const Duration(milliseconds: 500));
                                  },
                                  child: ListView.builder(
                                    padding: const EdgeInsets.only(top: 8.0, bottom: 80.0),
                                    physics: const AlwaysScrollableScrollPhysics(),
                                    itemCount: filteredItems.length,
                                    itemBuilder: (context, index) {
                                      final item = filteredItems[index];
                                      // Only pass controller for hint animation when not yet shown (and not searching)
                                      final needsController = index == 0 && !appUiState.hasShownSwipeHint && _searchQuery.isEmpty;
                                      return _buildItemTile(
                                        context,
                                        item,
                                        index,
                                        appUiState,
                                        isConnected,
                                      bluetoothState.selectedItemId,
                                      primaryText,
                                      secondaryText,
                                      alternate,
                                      activatedColor,
                                      controller: needsController ? _firstItemController : null,
                                    );
                                    },
                                  ),
                                );
                              }
                            }

                            return const SizedBox();
                          },
                        ),
                      ),
                    ),
                      ],
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

  Widget _buildLabeledDivider(AppUiState appUiState, Color secondaryText) {
    final isToday = appUiState.isTodayToggle;
    final label = isToday ? 'Today' : 'Total';
    return Padding(
      padding: const EdgeInsets.fromLTRB(16.0, 8.0, 16.0, 8.0),
      child: Row(
        children: [
          Expanded(
            child: Container(
              height: 0.5,
              color: secondaryText.withValues(alpha: 0.2),
            ),
          ),
          const SizedBox(width: 8),
          GestureDetector(
            onTap: () => appUiState.isTodayToggle = !isToday,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10.0, vertical: 4.0),
              decoration: BoxDecoration(
                color: secondaryText.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(12.0),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.swap_horiz_rounded,
                    size: 14.0,
                    color: secondaryText.withValues(alpha: 0.7),
                  ),
                  const SizedBox(width: 4),
                  Text(
                    label,
                    style: GoogleFonts.inter(
                      color: secondaryText.withValues(alpha: 0.7),
                      fontSize: 12.0,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSearchField(BuildContext context, Color primaryText, Color secondaryText, Color alternate) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16.0, 0.0, 16.0, 12.0),
      child: TextField(
        controller: _searchController,
        autofocus: true,
        style: GoogleFonts.inter(
          color: primaryText,
          fontSize: 16.0,
        ),
        decoration: InputDecoration(
          hintText: 'Search items...',
          hintStyle: GoogleFonts.inter(
            color: secondaryText,
            fontSize: 16.0,
          ),
          prefixIcon: Icon(Icons.search_rounded, color: secondaryText),
          suffixIcon: IconButton(
            icon: Icon(Icons.close_rounded, color: secondaryText),
            onPressed: () {
              if (_searchQuery.isNotEmpty) {
                // Clear text first
                _searchController.clear();
                setState(() => _searchQuery = '');
              } else {
                // Close search when empty
                setState(() => _isSearching = false);
              }
            },
          ),
          filled: true,
          fillColor: alternate,
          contentPadding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12.0),
            borderSide: BorderSide.none,
          ),
        ),
        onChanged: (value) {
          setState(() => _searchQuery = value.toLowerCase());
        },
      ),
    );
  }

  Widget _buildCategoryDropdown(
    BuildContext context,
    List<cat.Category> categories,
    String? selectedCategoryId,
    Color primaryText,
    Color secondaryText,
    Color alternate,
  ) {
    return Container(
      height: 48.0,
      padding: const EdgeInsets.symmetric(horizontal: 16.0),
      decoration: BoxDecoration(
        color: alternate,
        borderRadius: BorderRadius.circular(12.0),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String?>(
          value: selectedCategoryId,
          isExpanded: true,
          icon: Icon(Icons.expand_more_rounded, color: secondaryText),
          style: GoogleFonts.inter(
            color: primaryText,
            fontSize: 15.0,
            fontWeight: FontWeight.w500,
          ),
          dropdownColor: alternate,
          items: [
            // All Categories option
            DropdownMenuItem<String?>(
              value: null,
              child: Row(
                children: [
                  Icon(Icons.list_rounded, color: secondaryText, size: 20),
                  const SizedBox(width: 12),
                  Text(
                    'All Categories',
                    style: GoogleFonts.inter(
                      color: primaryText,
                      fontSize: 15.0,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
            // User categories
            ...categories.map((category) => DropdownMenuItem<String?>(
                  value: category.id,
                  child: Row(
                    children: [
                      Icon(Icons.folder_outlined, color: secondaryText, size: 20),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          category.name,
                          style: GoogleFonts.inter(
                            color: primaryText,
                            fontSize: 15.0,
                            fontWeight: FontWeight.w500,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                )),
            // Uncategorized option
            DropdownMenuItem<String?>(
              value: '',
              child: Row(
                children: [
                  Icon(Icons.folder_off_outlined, color: secondaryText, size: 20),
                  const SizedBox(width: 12),
                  Text(
                    'Uncategorized',
                    style: GoogleFonts.inter(
                      color: secondaryText,
                      fontSize: 15.0,
                      fontWeight: FontWeight.w500,
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                ],
              ),
            ),
            // Manage Categories option
            DropdownMenuItem<String?>(
              value: '__manage__',
              child: Row(
                children: [
                  Icon(Icons.settings_outlined, color: AppColors.primary, size: 20),
                  const SizedBox(width: 12),
                  Text(
                    'Manage Categories',
                    style: GoogleFonts.inter(
                      color: AppColors.primary,
                      fontSize: 15.0,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
          ],
          onChanged: (value) {
            // Handle "Manage Categories" navigation
            if (value == '__manage__') {
              context.push('/profile/categories');
              return;
            }

            // Update UI filter only - no device sync
            // Device is only updated when user explicitly activates (pins) an item
            context.read<ItemsBloc>().add(FilterByCategoryEvent(value));
            context.read<AppUiState>().selectedCategoryId = value;
          },
        ),
      ),
    );
  }

  Widget _buildActiveItemChip(
    BuildContext context,
    ItemsLoaded itemsState,
    BluetoothState bluetoothState,
    AppUiState appUiState,
    Color primaryText,
    Color secondaryText,
    Color alternate,
  ) {
    // Get the active item ID from device or fallback to app state
    final activeId = bluetoothState.selectedItemId ?? appUiState.activeItemId;
    if (activeId.isEmpty) return const SizedBox.shrink();

    // Find the active item in the items list
    final activeItem = itemsState.items.where((i) => i.id == activeId).firstOrNull;
    if (activeItem == null) return const SizedBox.shrink();

    // Check if we're already viewing the active item's category
    final currentCategoryId = itemsState.selectedCategoryId;
    final activeCategoryId = activeItem.categoryId;
    final isInCurrentCategory = currentCategoryId == null || // viewing "All"
        (currentCategoryId == '' && (activeCategoryId == null || activeCategoryId.isEmpty)) || // both uncategorized
        currentCategoryId == activeCategoryId;

    // Get category name
    final categoriesState = context.read<CategoriesBloc>().state;
    String categoryName = 'Uncategorized';
    if (activeCategoryId != null && activeCategoryId.isNotEmpty && categoriesState is CategoriesLoaded) {
      final category = categoriesState.categories.where((c) => c.id == activeCategoryId).firstOrNull;
      if (category != null) categoryName = category.name;
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0),
      child: GestureDetector(
        onTap: () {
          if (!isInCurrentCategory) {
            // Navigate to the active item's category
            final targetCategoryId = (activeCategoryId == null || activeCategoryId.isEmpty)
                ? '' // uncategorized
                : activeCategoryId;
            context.read<ItemsBloc>().add(FilterByCategoryEvent(targetCategoryId));
            context.read<AppUiState>().selectedCategoryId = targetCategoryId;
          }
        },
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 4.0),
          decoration: BoxDecoration(
            color: _activateActionColor.withAlpha(15),
            borderRadius: BorderRadius.circular(12.0),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.push_pin_rounded,
                size: 11.0,
                color: _activateActionColor,
              ),
              const SizedBox(width: 4.0),
              Flexible(
                child: Text(
                  '${activeItem.name} · $categoryName',
                  style: GoogleFonts.inter(
                    color: secondaryText,
                    fontSize: 11.0,
                    fontWeight: FontWeight.w500,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              if (!isInCurrentCategory) ...[
                const SizedBox(width: 4.0),
                Icon(
                  Icons.arrow_forward_rounded,
                  size: 11.0,
                  color: secondaryText,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDisconnectedBanner(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    final secondaryText = AppColors.secondaryText(brightness);

    return Center(
      child: Padding(
        padding: const EdgeInsets.only(top: 12.0),
        child: GestureDetector(
          onTap: () => context.go('/bluetooth'),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
            decoration: BoxDecoration(
              color: secondaryText.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(20.0),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.bluetooth_disabled_rounded,
                  size: 14.0,
                  color: secondaryText,
                ),
                const SizedBox(width: 6.0),
                Text(
                  'Tap to connect device',
                  style: GoogleFonts.inter(
                    color: secondaryText,
                    fontSize: 12.0,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildItemTile(
    BuildContext context,
    Item item,
    int index,
    AppUiState appUiState,
    bool isConnected,
    String? selectedItemId,
    Color primaryText,
    Color secondaryText,
    Color alternate,
    Color activatedColor, {
    SlidableController? controller,
    Animation<double>? liftAnimation,
  }) {
    // Use Bluetooth selectedItemId from device, fallback to appUiState
    final activeId = selectedItemId ?? appUiState.activeItemId;
    final isActivated = activeId == item.id && isConnected;
    final displayCount = appUiState.isTodayToggle ? item.todayCount : item.count;

    // The tile content - wrapped in ReorderableDelayedDragStartListener when connected
    // to enable long-press-to-drag without a visible handle
    Widget tileContent = Opacity(
      opacity: isConnected ? 1.0 : 0.5,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(8.0),
        child: Container(
          decoration: BoxDecoration(
            color: isActivated ? activatedColor : alternate,
            border: isActivated
                ? Border(left: BorderSide(color: _activateActionColor, width: 4.0))
                : null,
          ),
          child: InkWell(
            onTap: () {
              context.pushNamed(
                'ItemDetailPage',
                pathParameters: {'id': item.id},
                queryParameters: {
                  'name': item.name,
                  'count': item.count.toString(),
                  if (item.lastResetTime != null)
                    'resetTime': item.lastResetTime!.toIso8601String(),
                  'initialCount': item.initialCount.toString(),
                  'incrementBy': item.incrementBy.toString(),
                  'reminderType': item.reminder.name,
                  'reminderValue': item.reminderValue.toString(),
                  if (item.goal != null) 'goal': item.goal.toString(),
                  'resetNumber': item.resetNumber.toString(),
                },
              );
            },
            borderRadius: BorderRadius.circular(8.0),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 16.0),
              child: Row(
                children: [
                  // Item name (expanded to take remaining space)
                  Expanded(
                    child: Text(
                      item.name,
                      style: GoogleFonts.interTight(
                        color: !isConnected ? secondaryText : primaryText,
                        fontWeight: FontWeight.w600,
                        fontSize: 17.0,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const SizedBox(width: 16.0),
                  // Accent bar + count column
                  Builder(
                    builder: (context) {
                      final isDark = Theme.of(context).brightness == Brightness.dark;
                      // Colors for accent bar and text
                      final accentColor = isActivated
                          ? (isDark ? const Color(0xFFB8B4FF) : const Color(0xFF8580E0))
                          : (isDark ? const Color(0xFF6B7280) : const Color(0xFFD1D5DB));
                      final textColor = isActivated
                          ? (isDark ? const Color(0xFFB8B4FF) : _activateActionColor)
                          : primaryText;
                      return Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            // Accent bar
                            Container(
                              width: 4.0,
                              height: 24.0,
                              decoration: BoxDecoration(
                                color: accentColor,
                                borderRadius: BorderRadius.circular(2.0),
                              ),
                            ),
                            // Count (centered between bar and chevron)
                            Padding(
                              padding: const EdgeInsets.only(left: 4.0),
                              child: SizedBox(
                                width: 72.0,  // Fixed width for alignment
                                child: Text(
                                  _countFormat.format(displayCount),
                                  textAlign: TextAlign.center,
                                  style: GoogleFonts.inter(
                                    color: textColor,
                                    fontSize: 18.0,
                                    fontWeight: FontWeight.w600,
                                    fontFeatures: const [FontFeature.tabularFigures()],
                                  ),
                                ),
                              ),
                            ),
                          ],
                      );
                    },
                  ),
                  const SizedBox(width: 8.0),
                  // Chevron indicator
                  Icon(
                    Icons.chevron_right_rounded,
                    color: secondaryText.withOpacity(0.4),
                    size: 22.0,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );

    // Wrap with ReorderableDelayedDragStartListener when connected for long-press drag
    if (isConnected) {
      tileContent = ReorderableDelayedDragStartListener(
        index: index,
        child: tileContent,
      );
    }

    Widget result = Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Slidable(
        controller: controller,
        endActionPane: ActionPane(
          motion: const ScrollMotion(),
          extentRatio: 0.65,
          children: [
            // Activate (pin) action
            SlidableAction(
              backgroundColor: isConnected ? _activateActionColor : _disabledActionColor,
              icon: Icons.push_pin_rounded,
              autoClose: false,
              onPressed: (slidableContext) async {
                HapticFeedback.lightImpact();
                if (isConnected) {
                  appUiState.activeItemId = item.id;
                  // Send only items from the activated item's category to device
                  final itemsState = context.read<ItemsBloc>().state;
                  if (itemsState is ItemsLoaded) {
                    // Filter items by the activated item's category
                    final activatedCategoryId = item.categoryId;
                    final categoryItems = itemsState.items.where((i) {
                      // Match items with same categoryId (including uncategorized)
                      final itemCategoryId = i.categoryId;
                      if (activatedCategoryId == null || activatedCategoryId.isEmpty) {
                        // Activated item is uncategorized - get all uncategorized
                        return itemCategoryId == null || itemCategoryId.isEmpty;
                      }
                      return itemCategoryId == activatedCategoryId;
                    }).toList();

                    // Sort by categoryOrder for consistent device ordering
                    categoryItems.sort((a, b) => a.categoryOrder.compareTo(b.categoryOrder));

                    context.read<BluetoothBloc>().add(SendItemsToDevice(
                      categoryItems,
                      categoryNames: _buildCategoryNamesMap(context),
                    ));
                  }
                  // Then send selected item to device
                  context.read<BluetoothBloc>().add(SendSelectedItem(item.id));
                } else {
                  await _showConnectDeviceDialog(context);
                }
                Slidable.of(slidableContext)?.close();
              },
            ),
            // Move to Top action
            SlidableAction(
              backgroundColor: isConnected ? _moveToTopActionColor : _disabledActionColor,
              icon: Icons.vertical_align_top_rounded,
              autoClose: false,
              onPressed: (slidableContext) async {
                HapticFeedback.lightImpact();
                if (isConnected) {
                  final itemsBloc = context.read<ItemsBloc>();
                  final bluetoothBloc = context.read<BluetoothBloc>();
                  final itemsState = itemsBloc.state;
                  if (itemsState is ItemsLoaded) {
                    final isInCategory = itemsState.isFilteredByCategory;
                    if (isInCategory) {
                      // Move to top within category
                      final filteredIndex = itemsState.filteredItems.indexWhere((i) => i.id == item.id);
                      if (filteredIndex > 0) {
                        itemsBloc.add(ReorderItemsInCategoryEvent(oldIndex: filteredIndex, newIndex: 0));
                        // Sync filtered items to device
                        Future.delayed(const Duration(milliseconds: 100), () {
                          if (!mounted) return;
                          final updatedState = itemsBloc.state;
                          if (updatedState is ItemsLoaded) {
                            bluetoothBloc.add(SendItemsToDevice(
                              updatedState.filteredItems,
                              categoryNames: _buildCategoryNamesMap(context),
                            ));
                          }
                        });
                      }
                    } else {
                      // Move to top globally
                      final actualIndex = itemsState.items.indexWhere((i) => i.id == item.id);
                      if (actualIndex > 0) {
                        itemsBloc.add(ReorderItemsEvent(oldIndex: actualIndex, newIndex: 0));
                        // Sync all items to device
                        Future.delayed(const Duration(milliseconds: 100), () {
                          if (!mounted) return;
                          final updatedState = itemsBloc.state;
                          if (updatedState is ItemsLoaded) {
                            bluetoothBloc.add(SendItemsToDevice(
                              updatedState.items,
                              categoryNames: _buildCategoryNamesMap(context),
                            ));
                          }
                        });
                      }
                    }
                  }
                  // Clear search to show item at top
                  if (_searchQuery.isNotEmpty) {
                    setState(() {
                      _searchController.clear();
                      _searchQuery = '';
                      _isSearching = false;
                    });
                  }
                } else {
                  await _showConnectDeviceDialog(context);
                }
                Slidable.of(slidableContext)?.close();
              },
            ),
            SlidableAction(
              backgroundColor: isConnected ? _primary : _disabledActionColor,
              icon: Icons.edit,
              autoClose: false,
              onPressed: (slidableContext) async {
                HapticFeedback.lightImpact();
                Slidable.of(slidableContext)?.close();
                if (isConnected) {
                  context.pushNamed(
                    ItemFormPage.routeName,
                    extra: {'item': item},
                  );
                } else {
                  await _showConnectDeviceDialog(context);
                }
              },
            ),
            SlidableAction(
              backgroundColor: isConnected ? _deleteActionColor : _disabledActionColor,
              icon: Icons.delete_outline_rounded,
              autoClose: false,
              onPressed: (slidableContext) async {
                HapticFeedback.mediumImpact();
                if (isConnected) {
                  // Capture ALL references BEFORE the async dialog
                  final itemsBloc = context.read<ItemsBloc>();
                  final bluetoothBloc = context.read<BluetoothBloc>();
                  final appUiStateRef = appUiState;
                  // Use device's selected item, not just appUiState
                  final deviceSelectedId = selectedItemId;

                  final confirmed = await _showDeleteConfirmation(context, item.name);
                  if (confirmed) {
                    // Check both appUiState and device selection
                    if (appUiStateRef.activeItemId == item.id) {
                      appUiStateRef.activeItemId = 'none';
                    }
                    // Determine what selected item to send after delete
                    final newSelectedId = (deviceSelectedId == item.id || deviceSelectedId == null)
                        ? 'none'
                        : deviceSelectedId;

                    itemsBloc.add(DeleteItemEvent(item.id));
                    // Sync with device after deletion using captured references
                    await _syncWithDeviceAfterDelete(
                      bluetoothBloc: bluetoothBloc,
                      activeItemId: newSelectedId,
                      userId: widget.userId,
                    );
                  }
                } else {
                  await _showConnectDeviceDialog(context);
                }
                Slidable.of(slidableContext)?.close();
              },
            ),
          ],
        ),
        child: tileContent,
      ),
    );

    // Apply lift animation for reorder hint (simulates long-press drag start)
    if (liftAnimation != null) {
      result = AnimatedBuilder(
        animation: liftAnimation,
        builder: (context, child) {
          final scale = 1.0 + (0.02 * liftAnimation.value);
          final elevation = 6.0 * liftAnimation.value;
          final yOffset = -4.0 * liftAnimation.value;
          return Transform.translate(
            offset: Offset(0, yOffset),
            child: Transform.scale(
              scale: scale,
              child: Material(
                elevation: elevation,
                borderRadius: BorderRadius.circular(8.0),
                color: Colors.transparent,
                child: child,
              ),
            ),
          );
        },
        child: result,
      );
    }

    // Key must be at the root for ReorderableListView
    return KeyedSubtree(
      key: ValueKey(item.id),
      child: result,
    );
  }

  Widget _buildNoSearchResults(BuildContext context, Color primaryText, Color secondaryText) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.search_off_rounded,
            size: 64.0,
            color: secondaryText,
          ),
          const SizedBox(height: 16.0),
          Text(
            'No items found',
            style: GoogleFonts.interTight(
              color: primaryText,
              fontSize: 20.0,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8.0),
          Text(
            'Try a different search term',
            style: GoogleFonts.inter(
              color: secondaryText,
              fontSize: 14.0,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context, Color primaryText, Color secondaryText, bool isConnected) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.inbox_outlined,
            size: 72.0,
            color: secondaryText,
          ),
          const SizedBox(height: 16.0),
          Text(
            'No items yet',
            style: GoogleFonts.interTight(
              color: primaryText,
              fontSize: 24.0,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8.0),
          Text(
            'Create your first item to start tracking',
            style: GoogleFonts.inter(
              color: secondaryText,
              fontSize: 14.0,
            ),
          ),
          const SizedBox(height: 24.0),
          FilledButton.icon(
            onPressed: () async {
              if (isConnected) {
                context.pushNamed(ItemFormPage.routeName);
              } else {
                await _showConnectDeviceDialog(context);
              }
            },
            style: FilledButton.styleFrom(
              backgroundColor: _primary,
              padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 12.0),
            ),
            icon: const Icon(Icons.add_rounded),
            label: const Text('Create Item'),
          ),
        ],
      ),
    );
  }

  Future<void> _showConnectDeviceDialog(BuildContext context) async {
    await showDialog(
      context: context,
      builder: (alertDialogContext) {
        return AlertDialog(
          content: const Text('Please connect your device first'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(alertDialogContext),
              child: const Text('Ok'),
            ),
          ],
        );
      },
    );
  }

  Future<void> _showItemLimitDialog(BuildContext context) async {
    await showDialog(
      context: context,
      builder: (alertDialogContext) {
        return AlertDialog(
          title: const Text('Item Limit Reached'),
          content: Text('You can only create up to $_maxItems items. Please delete some items to create new ones.'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(alertDialogContext),
              child: const Text('Ok'),
            ),
          ],
        );
      },
    );
  }

  /// Syncs the updated items list to the device after deletion.
  /// Takes pre-captured references to avoid deactivated widget errors.
  Future<void> _syncWithDeviceAfterDelete({
    required BluetoothBloc bluetoothBloc,
    required String activeItemId,
    required String userId,
  }) async {
    try {
      // Small delay to allow Firestore to propagate the delete
      await Future.delayed(const Duration(milliseconds: 300));

      // Fetch all items from repository
      final itemRepository = sl<ItemRepository>();
      final itemsResult = await itemRepository.getItems(userId);

      final items = itemsResult.fold(
        (failure) {
          debugPrint('❌ Failed to fetch items after delete: ${failure.message}');
          return <Item>[];
        },
        (items) => items,
      );

      debugPrint('📦 Fetched ${items.length} items after delete');

      // Send updated items list to device
      debugPrint('📤 Sending ${items.length} items to device after delete');
      bluetoothBloc.add(SendItemsToDevice(
        items,
        categoryNames: _buildCategoryNamesMap(context),
      ));

      // Send selected item to device (may have changed if deleted item was active)
      bluetoothBloc.add(SendSelectedItem(activeItemId));

      // Request prefs from device to get updated counts
      debugPrint('📥 Requesting prefs from device after delete');
      bluetoothBloc.add(const RequestDeviceData(type: DeviceDataType.prefs));
    } catch (e) {
      debugPrint('❌ Error syncing with device after delete: $e');
    }
  }

  Future<bool> _showDeleteConfirmation(BuildContext context, String itemName) async {
    return await showDialog<bool>(
      context: context,
      builder: (alertDialogContext) {
        return AlertDialog(
          title: const Text('Delete Item'),
          content: Text('Are you sure you want to delete "$itemName"?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(alertDialogContext, false),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(alertDialogContext, true),
              style: TextButton.styleFrom(foregroundColor: _deleteActionColor),
              child: const Text('Delete'),
            ),
          ],
        );
      },
    ) ?? false;
  }

  /// Shows a swipe hint animation on the first item
  void _showSwipeHint(AppUiState appUiState) {
    if (_swipeHintTriggered || appUiState.hasShownSwipeHint) return;
    _swipeHintTriggered = true;

    // Delay to let the list render first
    Future.delayed(const Duration(milliseconds: 500), () {
      if (!mounted) return;
      _firstItemController.openEndActionPane();

      // Close after showing the actions briefly
      Future.delayed(const Duration(milliseconds: 1200), () {
        if (!mounted) return;
        _firstItemController.close();
        appUiState.markSwipeHintShown();
      });
    });
  }

  /// Shows a reorder hint animation on the first item (lift effect)
  /// Only triggers when connected (reordering requires device connection)
  void _showReorderHint(AppUiState appUiState, bool isConnected) {
    // Only show after swipe hint, when connected, and if not already shown
    if (!appUiState.hasShownSwipeHint ||
        _reorderHintTriggered ||
        appUiState.hasShownReorderHint ||
        !isConnected) {
      return;
    }
    _reorderHintTriggered = true;

    // Delay after swipe hint completes
    Future.delayed(const Duration(milliseconds: 800), () {
      if (!mounted) return;

      // Lift up
      _reorderHintController.forward().then((_) {
        if (!mounted) return;

        // Hold briefly, then lower
        Future.delayed(const Duration(milliseconds: 600), () {
          if (!mounted) return;
          _reorderHintController.reverse().then((_) {
            if (!mounted) return;
            appUiState.markReorderHintShown();
          });
        });
      });
    });
  }

  @override
  void dispose() {
    _firstItemController.dispose();
    _reorderHintController.dispose();
    _searchController.dispose();
    super.dispose();
  }
}
