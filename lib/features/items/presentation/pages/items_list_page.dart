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
import '../../../bluetooth/domain/entities/ble_message.dart';
import '../../../bluetooth/presentation/bloc/bluetooth_bloc.dart';
import '../../../bluetooth/presentation/bloc/bluetooth_event.dart';
import '../../../bluetooth/presentation/bloc/bluetooth_state.dart';
import '../../domain/entities/item.dart';
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
  SlidableController? _firstItemController;
  AnimationController? _reorderHintController;
  Animation<double>? _liftAnimation;
  bool _swipeHintTriggered = false;
  bool _reorderHintTriggered = false;
  bool _activationHintTriggered = false;
  OverlayEntry? _activationHintOverlay;
  OverlayEntry? _reorderHintOverlay;

  // Search state
  bool _isSearching = false;
  final _searchController = TextEditingController();
  String _searchQuery = '';

  // Cached category maps (updated via BlocListener when categories change)
  Map<String, String> _cachedCategoryNames = {};
  Map<String, int> _cachedCategoryOrder = {};

  // Scroll controller for sticky headers
  final _scrollController = ScrollController();
  String? _stickyCategory;

  // Track last synced category items to prevent duplicate syncs
  String? _lastSyncedSignature;
  String? _lastSyncedCategoryId;
  DateTime? _lastSyncTime;

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
      CurvedAnimation(parent: _reorderHintController!, curve: Curves.easeOutCubic),
    );
  }

  /// Updates the cached category maps from CategoriesBloc state.
  void _updateCategoryCache(CategoriesState state) {
    if (state is CategoriesLoaded) {
      _cachedCategoryNames = {
        for (final category in state.categories)
          category.id: category.name,
      };
      _cachedCategoryOrder = {
        for (final category in state.categories)
          category.id: category.order,
      };
    }
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
      child: BlocListener<CategoriesBloc, CategoriesState>(
        listener: (context, state) {
          _updateCategoryCache(state);
        },
        child: BlocListener<BluetoothBloc, BluetoothState>(
          listenWhen: (previous, current) =>
              !previous.isConnected && current.isConnected,
          listener: (context, bluetoothState) {
            // When device connects, navigate to selected item's category
            final selectedItemId = bluetoothState.selectedItemId;
            if (selectedItemId != null && selectedItemId.isNotEmpty && selectedItemId != 'none') {
              final itemsState = context.read<ItemsBloc>().state;
              if (itemsState is ItemsLoaded) {
                final selectedItem = itemsState.items
                    .where((i) => i.id == selectedItemId)
                    .firstOrNull;
                if (selectedItem != null) {
                  final targetCategoryId =
                      (selectedItem.categoryId == null || selectedItem.categoryId!.isEmpty)
                          ? ''
                          : selectedItem.categoryId!;
                  context.read<ItemsBloc>().add(FilterByCategoryEvent(targetCategoryId));
                  // Defer AppUiState update to next frame to avoid rebuild during callback
                  WidgetsBinding.instance.addPostFrameCallback((_) {
                    if (!mounted) return;
                    context.read<AppUiState>().selectedCategoryId = targetCategoryId;
                  });
                }
              }
            }
          },
          // Listen for prefs message with no selection (selected_id: -1)
          child: BlocListener<BluetoothBloc, BluetoothState>(
            listenWhen: (previous, current) {
              // Fire when lastMessage changes to a prefs message
              final prevMsg = previous.lastMessage;
              final currMsg = current.lastMessage;
              return currMsg != null &&
                  currMsg != prevMsg &&
                  currMsg.type == BleMessageType.prefs;
            },
            listener: (context, bluetoothState) {
              // Prefs received - check if device says no selection
              final selectedItemId = bluetoothState.selectedItemId;
              if (selectedItemId == null || selectedItemId.isEmpty) {
                // Device has no selection - clear app's persisted selection
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  if (!mounted) return;
                  context.read<AppUiState>().clearActiveItem();
                });
              }
            },
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
                      child: BlocSelector<ItemsBloc, ItemsState, bool>(
                        selector: (state) => state is ItemsLoaded && state.items.length >= _maxItems,
                        builder: (context, hasReachedLimit) {
                          return IconButton(
                            onPressed: () async {
                              if (!isConnected) {
                                await _showConnectDeviceDialog(context);
                                return;
                              }
                              // Check item limit
                              if (hasReachedLimit) {
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
                          BlocSelector<CategoriesBloc, CategoriesState, List<cat.Category>>(
                            selector: (state) => state is CategoriesLoaded ? state.categories : [],
                            builder: (context, categories) {
                              // Update cache when categories change
                              if (categories.isNotEmpty && _cachedCategoryNames.isEmpty) {
                                WidgetsBinding.instance.addPostFrameCallback((_) {
                                  if (mounted) {
                                    setState(() {
                                      _cachedCategoryNames = {
                                        for (final category in categories)
                                          category.id: category.name,
                                      };
                                      _cachedCategoryOrder = {
                                        for (final category in categories)
                                          category.id: category.order,
                                      };
                                    });
                                  }
                                });
                              }

                              if (categories.isEmpty) return const SizedBox.shrink();

                              return Padding(
                                padding: const EdgeInsets.fromLTRB(16.0, 16.0, 16.0, 12.0),
                                child: BlocSelector<ItemsBloc, ItemsState, String?>(
                                  selector: (state) => state is ItemsLoaded ? state.selectedCategoryId : null,
                                  builder: (context, selectedCategoryId) {
                                    return _buildCategoryDropdown(
                                      context,
                                      categories,
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
                          // Search field (between category filter and pin chip)
                          if (_isSearching)
                            _buildSearchField(context, primaryText, secondaryText, alternate),
                          // Active item chip (shows when connected with active item)
                          BlocSelector<ItemsBloc, ItemsState, ItemsLoaded?>(
                            selector: (state) => state is ItemsLoaded ? state : null,
                            builder: (context, itemsState) {
                              if (!isConnected || itemsState == null) {
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
                            listenWhen: (previous, current) {
                              // Only listen for errors
                              return current is ItemsError;
                            },
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
                            buildWhen: (previous, current) {
                              // Rebuild on any state change, but also check if we need to sync device
                              if (previous is ItemsLoaded && current is ItemsLoaded) {
                                final bluetoothState = context.read<BluetoothBloc>().state;
                                if (bluetoothState.isConnected) {
                                  final selectedId = bluetoothState.selectedItemId;
                                  if (selectedId != null && selectedId.isNotEmpty) {
                                    // Find selected item's category
                                    final selectedItem = current.items
                                        .where((i) => i.id == selectedId)
                                        .firstOrNull;
                                    if (selectedItem != null) {
                                      final selectedCatId = selectedItem.categoryId ?? '';

                                      // Get items in selected category, sorted by categoryOrder
                                      final currentCategoryItems = current.items
                                          .where((i) => (i.categoryId ?? '') == selectedCatId)
                                          .toList()
                                        ..sort((a, b) => a.categoryOrder.compareTo(b.categoryOrder));

                                      // Create signature from current category items (config fields only, not counts)
                                      // Include categoryId so category changes trigger sync
                                      final currentSignature = currentCategoryItems
                                          .map((i) => '${i.id}:${i.categoryId ?? ''}:${i.categoryOrder}:${i.name}:${i.incrementBy}:${i.reminder.index}:${i.reminderValue}')
                                          .join(',');

                                      // First time seeing items - just initialize signature, don't sync
                                      // (App can't configure anything while disconnected, so nothing to sync)
                                      if (_lastSyncedSignature == null) {
                                        _lastSyncedSignature = currentSignature;
                                        _lastSyncedCategoryId = selectedCatId;
                                        _lastSyncTime = DateTime.now();
                                        return true;
                                      }

                                      // Debounce: skip if synced recently (within 500ms)
                                      final now = DateTime.now();
                                      final recentlySynced = _lastSyncTime != null &&
                                          now.difference(_lastSyncTime!).inMilliseconds < 500;

                                      // Check if category changed (selected item moved to different category)
                                      final categoryChanged = _lastSyncedCategoryId != selectedCatId;
                                      final signatureChanged = currentSignature != _lastSyncedSignature;

                                      // Sync if signature changed OR if selected item's category changed
                                      // Category change means item was edited to be in a different category
                                      if (signatureChanged || categoryChanged) {
                                        if (!recentlySynced) {
                                          _lastSyncedSignature = currentSignature;
                                          _lastSyncedCategoryId = selectedCatId;
                                          _lastSyncTime = now;
                                          context.read<BluetoothBloc>().add(SendItemsToDevice(
                                            currentCategoryItems,
                                            categoryNames: _cachedCategoryNames,
                                          ));
                                          Future.delayed(const Duration(milliseconds: 100), () {
                                            if (!mounted) return;
                                            context.read<BluetoothBloc>().add(SendSelectedItem(
                                              selectedId,
                                              selectedItem.deviceItemId ?? 0,
                                            ));
                                          });
                                        } else {
                                          // Update signature/category but skip sync (debounced)
                                          _lastSyncedSignature = currentSignature;
                                          _lastSyncedCategoryId = selectedCatId;
                                        }
                                      }
                                    }
                                  }
                                }
                              }
                              return true; // Always rebuild
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
                                // Use category order map for proper sorting in "All" view
                                final categoryFilteredItems = state.getFilteredItemsWithCategoryOrder(_cachedCategoryOrder);
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
                                  // Trigger reorder hint when connected, 2+ items, and hint not yet shown
                                  if (filteredItems.length >= 2 &&
                                      !appUiState.hasShownReorderHint &&
                                      _searchQuery.isEmpty) {
                                    WidgetsBinding.instance.addPostFrameCallback((_) {
                                      _showReorderHint(appUiState, isConnected, context);
                                    });
                                  }

                                  // Build mixed list with labels and items for "All" view
                                  // Labels act as drop zone separators between categories
                                  // Show ALL categories (including empty ones) to allow drag-drop into them
                                  final List<_ListEntry> listEntries = [];
                                  if (!state.isFilteredByCategory) {
                                    // Group items by category for efficient lookup
                                    final itemsByCategory = <String, List<Item>>{};
                                    for (final item in filteredItems) {
                                      final catId = item.categoryId ?? '';
                                      itemsByCategory.putIfAbsent(catId, () => []).add(item);
                                    }

                                    // Get all categories sorted by order
                                    final sortedCategoryIds = _cachedCategoryOrder.keys.toList()
                                      ..sort((a, b) => (_cachedCategoryOrder[a] ?? 0).compareTo(_cachedCategoryOrder[b] ?? 0));

                                    // Add each category (even if empty) with its items
                                    for (final catId in sortedCategoryIds) {
                                      final labelText = _cachedCategoryNames[catId] ?? 'Unknown';
                                      listEntries.add(_ListEntry.label(catId, labelText));
                                      final catItems = itemsByCategory[catId] ?? [];
                                      for (final item in catItems) {
                                        listEntries.add(_ListEntry.item(item));
                                      }
                                    }

                                    // Always add Uncategorized at the end
                                    listEntries.add(_ListEntry.label('', 'Uncategorized'));
                                    final uncategorizedItems = itemsByCategory[''] ?? [];
                                    for (final item in uncategorizedItems) {
                                      listEntries.add(_ListEntry.item(item));
                                    }
                                  } else {
                                    // Single category view - just items
                                    for (final item in filteredItems) {
                                      listEntries.add(_ListEntry.item(item));
                                    }
                                  }

                                  final listWidget = ReorderableListView.builder(
                                    scrollController: _scrollController,
                                    padding: const EdgeInsets.only(
                                      top: 0.0,
                                      bottom: 80.0,
                                    ),
                                    physics: const AlwaysScrollableScrollPhysics(),
                                    buildDefaultDragHandles: false,
                                    itemCount: listEntries.length,
                                    onReorderStart: (index) {
                                      // Only trigger haptic for items, not labels
                                      if (!listEntries[index].isLabel) {
                                        HapticFeedback.mediumImpact();
                                      }
                                    },
                                    proxyDecorator: (child, index, animation) {
                                      final entry = listEntries[index];
                                      if (entry.isLabel) return child;

                                      final dragProxy = _buildItemTile(
                                        context,
                                        entry.item!,
                                        index,
                                        appUiState,
                                        isConnected,
                                        bluetoothState.selectedItemId,
                                        primaryText,
                                        secondaryText,
                                        alternate,
                                        activatedColor,
                                        isDragProxy: true,
                                      );

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
                                        child: dragProxy,
                                      );
                                    },
                                    onReorder: (oldIndex, newIndex) {
                                      final oldEntry = listEntries[oldIndex];
                                      // Don't allow reordering labels
                                      if (oldEntry.isLabel) return;

                                      // Capture references BEFORE any async operations
                                      final itemsBloc = context.read<ItemsBloc>();
                                      final itemRepository = itemsBloc.itemRepository;
                                      final currentState = state;
                                      final isFilteredByCategory = currentState.isFilteredByCategory;

                                      if (!isFilteredByCategory) {
                                        final movedItem = oldEntry.item!;
                                        final movedItemCat = movedItem.categoryId ?? '';

                                        // Create virtual list without the moved item
                                        final virtualList = listEntries
                                            .where((e) => e.isLabel || e.item!.id != movedItem.id)
                                            .toList();

                                        // Adjust newIndex for Flutter's ReorderableListView behavior
                                        // When dragging down (oldIndex < newIndex), newIndex is off by 1
                                        int adjustedNewIndex = newIndex;
                                        if (oldIndex < newIndex) {
                                          adjustedNewIndex = newIndex - 1;
                                        }

                                        // Clamp to valid range
                                        final clampedNewIndex = adjustedNewIndex.clamp(0, virtualList.length);

                                        // What we're inserting before (null if at end)
                                        final insertBefore = clampedNewIndex < virtualList.length
                                            ? virtualList[clampedNewIndex]
                                            : null;

                                        // What we're inserting after (null if at start)
                                        final insertAfter = clampedNewIndex > 0
                                            ? virtualList[clampedNewIndex - 1]
                                            : null;

                                        String targetCat;
                                        int insertPos;

                                        if (insertBefore == null) {
                                          // Inserting at end of list
                                          if (insertAfter != null) {
                                            if (!insertAfter.isLabel) {
                                              final lastItem = insertAfter.item!;
                                              targetCat = lastItem.categoryId ?? '';
                                              final categoryItems = filteredItems
                                                  .where((i) => (i.categoryId ?? '') == targetCat && i.id != movedItem.id)
                                                  .toList();
                                              insertPos = categoryItems.length;
                                            } else {
                                              // Edge case: list ends with orphaned label (empty category at end)
                                              // Insert into this empty category
                                              targetCat = insertAfter.categoryId!;
                                              insertPos = 0;
                                            }
                                          } else {
                                            return; // Empty list edge case
                                          }
                                        } else if (insertBefore.isLabel) {
                                          // Inserting before a label
                                          if (insertAfter != null && !insertAfter.isLabel) {
                                            // There's an item before the label → end of that item's category
                                            final prevItem = insertAfter.item!;
                                            targetCat = prevItem.categoryId ?? '';
                                            final categoryItems = filteredItems
                                                .where((i) => (i.categoryId ?? '') == targetCat && i.id != movedItem.id)
                                                .toList();
                                            insertPos = categoryItems.length;
                                          } else if (insertAfter != null && insertAfter.isLabel) {
                                            // Between two labels → insert into the category of insertAfter (the empty one)
                                            targetCat = insertAfter.categoryId!;
                                            insertPos = 0;
                                          } else {
                                            // No item before label (at start) → start of label's category
                                            targetCat = insertBefore.categoryId!;
                                            insertPos = 0;
                                          }
                                        } else {
                                          // Inserting before an item
                                          final targetItem = insertBefore.item!;
                                          targetCat = targetItem.categoryId ?? '';

                                          final categoryItems = filteredItems
                                              .where((i) => (i.categoryId ?? '') == targetCat && i.id != movedItem.id)
                                              .toList();
                                          final targetPosInCat = categoryItems.indexWhere((i) => i.id == targetItem.id);
                                          insertPos = targetPosInCat >= 0 ? targetPosInCat : categoryItems.length;
                                        }

                                        // Check for no-op (same category, same position)
                                        if (targetCat == movedItemCat) {
                                          final originalCategoryItems = filteredItems
                                              .where((i) => (i.categoryId ?? '') == movedItemCat)
                                              .toList();
                                          final originalPos = originalCategoryItems.indexWhere((i) => i.id == movedItem.id);
                                          if (insertPos == originalPos) {
                                            return; // No-op
                                          }
                                        }

                                        // Use BLoC for both same-category and cross-category moves
                                        // MoveItemToCategoryEvent handles optimistic updates
                                        itemsBloc.add(MoveItemToCategoryEvent(
                                          itemId: movedItem.id,
                                          targetCategoryId: targetCat.isEmpty ? null : targetCat,
                                          insertPosition: insertPos,
                                          sourceCategoryId: movedItemCat.isEmpty ? null : movedItemCat,
                                        ));
                                        return;
                                      }

                                      // Viewing a specific category - update categoryOrder
                                      // Device sync is handled by BlocListener when state changes
                                      itemsBloc.add(
                                        ReorderItemsInCategoryEvent(
                                          oldIndex: oldIndex,
                                          newIndex: newIndex,
                                        ),
                                      );
                                    },
                                    itemBuilder: (context, index) {
                                      final entry = listEntries[index];

                                      if (entry.isLabel) {
                                        // Build non-draggable category label
                                        return KeyedSubtree(
                                          key: ValueKey('label_${entry.categoryId}'),
                                          child: _buildCategoryLabel(entry.labelText!, secondaryText),
                                        );
                                      }

                                      final item = entry.item!;
                                      // Find actual item index for reorder hint
                                      final itemIndex = filteredItems.indexWhere((i) => i.id == item.id);
                                      final needsReorderHint = itemIndex == 0 && !appUiState.hasShownReorderHint && _searchQuery.isEmpty;

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

                                  // Wrap in Stack for sticky header in "All" view
                                  if (!state.isFilteredByCategory) {
                                    return NotificationListener<ScrollNotification>(
                                      onNotification: (notification) {
                                        if (notification is ScrollUpdateNotification) {
                                          final newStickyCategory = _calculateStickyCategory(
                                            filteredItems,
                                            notification.metrics.pixels,
                                          );
                                          if (newStickyCategory != _stickyCategory) {
                                            setState(() {
                                              _stickyCategory = newStickyCategory;
                                            });
                                          }
                                        }
                                        return false;
                                      },
                                      child: Stack(
                                        children: [
                                          listWidget,
                                          if (_stickyCategory != null)
                                            Positioned(
                                              top: 0,
                                              left: 0,
                                              right: 0,
                                              child: _buildStickyHeader(
                                                _stickyCategory!,
                                                secondaryText,
                                                primaryBackground,
                                              ),
                                            ),
                                        ],
                                      ),
                                    );
                                  }
                                  return listWidget;
                                } else {
                                  // Trigger hints only in regular ListView (not during reorder, not searching)
                                  if (_searchQuery.isEmpty) {
                                    // Show activation hint when connected but no item selected on device
                                    final deviceSelectedId = context.read<BluetoothBloc>().state.selectedItemId;
                                    final hasNoDeviceSelection = deviceSelectedId == null || deviceSelectedId.isEmpty;

                                    if (isConnected && hasNoDeviceSelection && !appUiState.hasShownActivationHint) {
                                      WidgetsBinding.instance.addPostFrameCallback((_) {
                                        _showActivationHint(appUiState, context);
                                      });
                                    } else if (!appUiState.hasShownSwipeHint) {
                                      // Regular swipe hint for returning users
                                      WidgetsBinding.instance.addPostFrameCallback((_) {
                                        _showSwipeHint(appUiState);
                                      });
                                    }
                                  }
                                  final listWidget = RefreshIndicator(
                                    color: _primary,
                                    onRefresh: () async {
                                      context.read<ItemsBloc>().add(WatchItemsEvent(widget.userId));
                                      // Wait a bit for the stream to emit
                                      await Future.delayed(const Duration(milliseconds: 500));
                                    },
                                    child: ListView.builder(
                                      controller: _scrollController,
                                      padding: const EdgeInsets.only(
                                        top: 0.0,
                                        bottom: 80.0,
                                      ),
                                      physics: const AlwaysScrollableScrollPhysics(),
                                      itemCount: filteredItems.length,
                                      itemBuilder: (context, index) {
                                        final item = filteredItems[index];
                                        // Only pass controller for hint animation when not yet shown (and not searching)
                                        final needsController = index == 0 && !appUiState.hasShownSwipeHint && _searchQuery.isEmpty;

                                        // Determine if this item needs a category label (first in its group)
                                        String? categoryLabelText;
                                        if (!state.isFilteredByCategory) {
                                          final currentCat = item.categoryId ?? '';
                                          final prevCat = index > 0 ? (filteredItems[index - 1].categoryId ?? '') : null;
                                          if (prevCat == null || currentCat != prevCat) {
                                            categoryLabelText = currentCat.isEmpty
                                                ? 'Uncategorized'
                                                : _cachedCategoryNames[currentCat] ?? 'Unknown';
                                          }
                                        }

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
                                          categoryLabel: categoryLabelText,
                                        );
                                      },
                                    ),
                                  );

                                  // Wrap in Stack for sticky header in "All" view
                                  if (!state.isFilteredByCategory) {
                                    return NotificationListener<ScrollNotification>(
                                      onNotification: (notification) {
                                        if (notification is ScrollUpdateNotification) {
                                          final newStickyCategory = _calculateStickyCategory(
                                            filteredItems,
                                            notification.metrics.pixels,
                                          );
                                          if (newStickyCategory != _stickyCategory) {
                                            setState(() {
                                              _stickyCategory = newStickyCategory;
                                            });
                                          }
                                        }
                                        return false;
                                      },
                                      child: Stack(
                                        children: [
                                          listWidget,
                                          if (_stickyCategory != null)
                                            Positioned(
                                              top: 0,
                                              left: 0,
                                              right: 0,
                                              child: _buildStickyHeader(
                                                _stickyCategory!,
                                                secondaryText,
                                                primaryBackground,
                                              ),
                                            ),
                                        ],
                                      ),
                                    );
                                  }
                                  return listWidget;
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
        ),  // closes new BlocListener (clear selection)
        ),  // closes first BlocListener (connect)
      ),
    );
  }

  Widget _buildLabeledDivider(AppUiState appUiState, Color secondaryText) {
    final isToday = appUiState.isTodayToggle;
    final label = isToday ? 'Today' : 'Total';
    return Padding(
      padding: const EdgeInsets.fromLTRB(16.0, 4.0, 16.0, 4.0),
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
              width: 74.0, // Fixed width to prevent layout shift
              padding: const EdgeInsets.symmetric(horizontal: 10.0, vertical: 4.0),
              decoration: BoxDecoration(
                border: Border.all(
                  color: secondaryText.withValues(alpha: 0.3),
                  width: 1.0,
                ),
                borderRadius: BorderRadius.circular(12.0),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                mainAxisAlignment: MainAxisAlignment.center,
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

  /// Builds a category label for "All" view, showing the category name
  Widget _buildCategoryLabel(String categoryName, Color secondaryText) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(0.0, 8.0, 16.0, 4.0),
      child: Text(
        categoryName,
        style: GoogleFonts.inter(
          color: secondaryText.withValues(alpha: 0.7),
          fontSize: 12.0,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  /// Builds a sticky category header for "All" view
  Widget _buildStickyHeader(String categoryName, Color secondaryText, Color backgroundColor) {
    return Container(
      width: double.infinity,
      color: backgroundColor,
      padding: const EdgeInsets.fromLTRB(0.0, 8.0, 16.0, 4.0),
      child: Text(
        categoryName,
        style: GoogleFonts.inter(
          color: secondaryText.withValues(alpha: 0.7),
          fontSize: 12.0,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  /// Calculates which category should be sticky based on scroll offset
  String? _calculateStickyCategory(List<Item> filteredItems, double scrollOffset) {
    if (filteredItems.isEmpty) return null;

    // Approximate heights - labels and items are now separate entries
    const double itemHeight = 76.0; // tile + padding
    const double labelHeight = 28.0; // label widget height

    double currentOffset = 0.0;
    String? lastCategory;

    for (int i = 0; i < filteredItems.length; i++) {
      final item = filteredItems[i];
      final currentCat = item.categoryId ?? '';
      final prevCat = i > 0 ? (filteredItems[i - 1].categoryId ?? '') : null;
      final isFirstInCategory = prevCat == null || currentCat != prevCat;

      // Add label height if first in category (labels are separate entries)
      if (isFirstInCategory) {
        final categoryName = currentCat.isEmpty
            ? 'Uncategorized'
            : _cachedCategoryNames[currentCat] ?? 'Unknown';
        if (currentOffset > scrollOffset) {
          return lastCategory;
        }
        lastCategory = categoryName;
        currentOffset += labelHeight;
      }

      currentOffset += itemHeight;

      if (currentOffset > scrollOffset + 40) {
        return lastCategory;
      }
    }

    return lastCategory;
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
    final isUncategorized = activeCategoryId == null || activeCategoryId.isEmpty;
    // Show navigation arrow unless already viewing the exact category
    // In "All" view (null), always show arrow to navigate to the specific category
    final isInCurrentCategory =
        (currentCategoryId == '' && isUncategorized) || // viewing uncategorized filter
        (currentCategoryId != null && currentCategoryId == activeCategoryId); // viewing exact category

    // Get category name from cached map
    String categoryName = 'Uncategorized';
    if (activeCategoryId != null && activeCategoryId.isNotEmpty) {
      categoryName = _cachedCategoryNames[activeCategoryId] ?? 'Uncategorized';
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
    String? categoryLabel,
    bool isDragProxy = false,
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
                  'lastUpdated': item.lastUpdated.toIso8601String(),
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

    // For drag proxy, return just the tile content without padding/slidable
    if (isDragProxy) {
      return tileContent;
    }

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
                      categoryNames: _cachedCategoryNames,
                    ));

                    // Update sync tracking so buildWhen doesn't duplicate the sync
                    final catId = activatedCategoryId ?? '';
                    _lastSyncedCategoryId = catId;
                    _lastSyncedSignature = categoryItems
                        .map((i) => '${i.id}:${i.categoryId ?? ''}:${i.categoryOrder}:${i.name}:${i.incrementBy}:${i.reminder.index}:${i.reminderValue}')
                        .join(',');
                    _lastSyncTime = DateTime.now();
                  }
                  // Then send selected item to device
                  context.read<BluetoothBloc>().add(SendSelectedItem(
                    item.id,
                    item.deviceItemId ?? 0,
                  ));
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
                  final itemsState = itemsBloc.state;
                  if (itemsState is ItemsLoaded) {
                    // Get item's category and find its position within that category
                    final itemCategoryId = item.categoryId ?? '';
                    final categoryItems = itemsState.items
                        .where((i) => (i.categoryId ?? '') == itemCategoryId)
                        .toList()
                      ..sort((a, b) => a.categoryOrder.compareTo(b.categoryOrder));
                    final categoryIndex = categoryItems.indexWhere((i) => i.id == item.id);

                    if (categoryIndex > 0) {
                      // Move item to top of its category using cross-category move event
                      // This works for both "All" view and category view without filter switching
                      itemsBloc.add(MoveItemToCategoryEvent(
                        itemId: item.id,
                        targetCategoryId: itemCategoryId.isEmpty ? null : itemCategoryId,
                        insertPosition: 0,
                        sourceCategoryId: itemCategoryId.isEmpty ? null : itemCategoryId,
                      ));
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
                  // Capture references BEFORE the async dialog
                  final itemsBloc = context.read<ItemsBloc>();
                  final bluetoothBloc = context.read<BluetoothBloc>();
                  final appUiStateRef = appUiState;
                  final deviceSelectedId = selectedItemId;

                  // Capture current items list BEFORE deletion
                  final currentState = itemsBloc.state;
                  final currentItems = currentState is ItemsLoaded
                      ? currentState.items
                      : <Item>[];

                  final confirmed = await _showDeleteConfirmation(context, item.name);
                  if (confirmed) {
                    if (appUiStateRef.activeItemId == item.id) {
                      appUiStateRef.activeItemId = 'none';
                    }

                    // Determine new selected item
                    final newSelectedId = (deviceSelectedId == item.id || deviceSelectedId == null)
                        ? 'none'
                        : deviceSelectedId;

                    itemsBloc.add(DeleteItemEvent(item.id));

                    // Only sync if deleted item is in selected item's category
                    final deletedCatId = item.categoryId ?? '';
                    String? selectedCatId;
                    if (newSelectedId != 'none') {
                      final selectedItem = currentItems.where((i) => i.id == newSelectedId).firstOrNull;
                      selectedCatId = selectedItem?.categoryId ?? '';
                    }

                    // Sync only if deleted item was in selected category
                    // (or if selected item was the one deleted)
                    if (newSelectedId == 'none' || deletedCatId == selectedCatId) {
                      _syncDeviceWithSelectedCategory(
                        bluetoothBloc: bluetoothBloc,
                        allItems: currentItems,
                        deviceSelectedId: newSelectedId,
                        excludeItemId: item.id,
                        fallbackCategoryId: item.categoryId,
                      );
                    }
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
    // If there's a category label, include it above the tile
    final finalWidget = categoryLabel != null
        ? Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildCategoryLabel(categoryLabel, secondaryText),
              result,
            ],
          )
        : result;

    return KeyedSubtree(
      key: ValueKey(item.id),
      child: finalWidget,
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
            onPressed: isConnected
                ? () => context.pushNamed(ItemFormPage.routeName)
                : null,
            style: FilledButton.styleFrom(
              backgroundColor: _primary,
              disabledBackgroundColor: _primary.withValues(alpha: 0.3),
              padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 12.0),
            ),
            icon: const Icon(Icons.add_rounded),
            label: const Text('Create Item'),
          ),
          if (!isConnected) ...[
            const SizedBox(height: 8.0),
            Text(
              'Connect device to create items',
              style: GoogleFonts.inter(
                color: secondaryText.withValues(alpha: 0.7),
                fontSize: 12.0,
              ),
            ),
          ],
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
      _firstItemController?.openEndActionPane();

      // Close after showing the actions briefly
      Future.delayed(const Duration(milliseconds: 1200), () {
        if (!mounted) return;
        _firstItemController?.close();
        appUiState.markSwipeHintShown();
      });
    });
  }

  /// Shows a reorder hint animation on the first item (lift effect) with tooltip.
  /// Only triggers when connected (reordering requires device connection).
  void _showReorderHint(AppUiState appUiState, bool isConnected, BuildContext context) {
    // Only show when connected and if not already shown
    if (_reorderHintTriggered ||
        appUiState.hasShownReorderHint ||
        !isConnected) {
      return;
    }
    _reorderHintTriggered = true;

    // Delay to let the list render
    Future.delayed(const Duration(milliseconds: 600), () {
      if (!mounted) return;

      // Show tooltip overlay
      final overlay = Overlay.of(context);
      _reorderHintOverlay = OverlayEntry(
        builder: (context) => Positioned(
          bottom: 120,
          left: 20,
          right: 20,
          child: Material(
            color: Colors.transparent,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
              decoration: BoxDecoration(
                color: Colors.black.withOpacity(0.9),
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.3),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.drag_indicator_rounded,
                    color: Colors.white,
                    size: 28,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'Long press and drag to reorder items',
                      style: GoogleFonts.inter(
                        color: Colors.white,
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
      overlay.insert(_reorderHintOverlay!);

      // Lift up animation
      _reorderHintController?.forward().then((_) {
        if (!mounted) return;

        // Hold briefly, then lower
        Future.delayed(const Duration(milliseconds: 1200), () {
          if (!mounted) return;
          _reorderHintController?.reverse().then((_) {
            if (!mounted) return;
            // Remove overlay and mark hint as shown
            _reorderHintOverlay?.remove();
            _reorderHintOverlay = null;
            appUiState.markReorderHintShown();
          });
        });
      });
    });
  }

  /// Shows an activation hint for new users who just created their first item.
  /// Opens the swipe pane and shows a tooltip explaining how to activate.
  void _showActivationHint(AppUiState appUiState, BuildContext context) {
    if (_activationHintTriggered || appUiState.hasShownActivationHint) return;
    _activationHintTriggered = true;

    // Delay to let the list render first
    Future.delayed(const Duration(milliseconds: 600), () {
      if (!mounted) return;

      // Open the swipe action pane
      _firstItemController?.openEndActionPane();

      // Show tooltip overlay
      final overlay = Overlay.of(context);
      _activationHintOverlay = OverlayEntry(
        builder: (context) => Positioned(
          bottom: 120,
          left: 20,
          right: 20,
          child: Material(
            color: Colors.transparent,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
              decoration: BoxDecoration(
                color: Colors.black.withOpacity(0.9),
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.3),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.swipe_left_rounded,
                    color: Colors.white,
                    size: 28,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'Swipe left and tap the pin icon to activate this item on your device',
                      style: GoogleFonts.inter(
                        color: Colors.white,
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
      overlay.insert(_activationHintOverlay!);

      // Close after showing
      Future.delayed(const Duration(milliseconds: 3500), () {
        if (!mounted) return;
        _activationHintOverlay?.remove();
        _activationHintOverlay = null;
        _firstItemController?.close();
        appUiState.markActivationHintShown();
        // Also mark swipe hint as shown since we just showed swipe actions
        appUiState.markSwipeHintShown();
      });
    });
  }

  /// Syncs the device with items from the selected item's category.
  /// Used after create/update/delete/restore to keep device in sync with app.
  void _syncDeviceWithSelectedCategory({
    required BluetoothBloc bluetoothBloc,
    required List<Item> allItems,
    required String? deviceSelectedId,
    String? excludeItemId,
    Item? includeItem,
    String? fallbackCategoryId,
  }) {
    // Find the selected item and its category
    // Fallback to provided category if no device selection
    String? selectedCategoryId;
    Item? selectedItem;
    if (deviceSelectedId != null && deviceSelectedId != 'none') {
      selectedItem = allItems.where((i) => i.id == deviceSelectedId).firstOrNull;
      selectedCategoryId = selectedItem?.categoryId;
    } else if (fallbackCategoryId != null) {
      selectedCategoryId = fallbackCategoryId;
    }

    // Get items from the selected item's category
    var categoryItems = allItems.where((i) {
      final cat = i.categoryId;
      final targetCat = selectedCategoryId;
      // Match category (treat null and empty as same - uncategorized)
      final catEmpty = cat == null || cat.isEmpty;
      final targetEmpty = targetCat == null || targetCat.isEmpty;
      if (catEmpty && targetEmpty) return true;
      if (catEmpty || targetEmpty) return false;
      return cat == targetCat;
    }).toList();

    // Exclude item if specified (for delete)
    if (excludeItemId != null) {
      categoryItems = categoryItems.where((i) => i.id != excludeItemId).toList();
    }

    // Include/update item if specified (for create/update/restore)
    if (includeItem != null) {
      categoryItems = categoryItems.map((i) => i.id == includeItem.id ? includeItem : i).toList();
      if (!categoryItems.any((i) => i.id == includeItem.id)) {
        categoryItems.add(includeItem);
      }
    }

    // Sort by categoryOrder to match app's order
    categoryItems.sort((a, b) => a.categoryOrder.compareTo(b.categoryOrder));

    bluetoothBloc.add(SendItemsToDevice(
      categoryItems,
      categoryNames: _cachedCategoryNames,
    ));

    // Update selected item on device (including 'none' to clear selection)
    if (deviceSelectedId != null) {
      final deviceItemId = (deviceSelectedId == 'none' || selectedItem == null)
          ? -1
          : selectedItem.deviceItemId ?? 0;
      bluetoothBloc.add(SendSelectedItem(deviceSelectedId, deviceItemId));
    }
  }

  @override
  void dispose() {
    _activationHintOverlay?.remove();
    _activationHintOverlay = null;
    _reorderHintOverlay?.remove();
    _reorderHintOverlay = null;
    _firstItemController?.dispose();
    _reorderHintController?.dispose();
    _searchController.dispose();
    _scrollController.dispose();
    super.dispose();
  }
}

/// Helper class to represent either a category label or an item in the list
class _ListEntry {
  final bool isLabel;
  final String? categoryId;
  final String? labelText;
  final Item? item;

  _ListEntry._({
    required this.isLabel,
    this.categoryId,
    this.labelText,
    this.item,
  });

  factory _ListEntry.label(String categoryId, String labelText) {
    return _ListEntry._(
      isLabel: true,
      categoryId: categoryId,
      labelText: labelText,
    );
  }

  factory _ListEntry.item(Item item) {
    return _ListEntry._(
      isLabel: false,
      item: item,
    );
  }
}
