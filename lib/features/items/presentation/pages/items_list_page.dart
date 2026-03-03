import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_slidable/flutter_slidable.dart';
import 'package:go_router/go_router.dart';

import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../../../core/di/injection.dart';
import '../../../auth/domain/repositories/user_repository.dart';
import '../../../auth/presentation/bloc/auth_bloc.dart';
import '../../../auth/presentation/bloc/auth_state.dart' as auth;
import '../../../../core/state/app_ui_state.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/utils/app_util.dart';
import '../../../bluetooth/presentation/bloc/bluetooth_bloc.dart';
import '../../../bluetooth/presentation/bloc/bluetooth_event.dart';
import '../../../bluetooth/presentation/bloc/bluetooth_state.dart';
import '../../../bluetooth/presentation/bloc/device_connection_state.dart';
import '../../../bluetooth/domain/entities/paired_device.dart';
import '../../domain/entities/item.dart';
import '../../../categories/domain/entities/category.dart' as cat;
import '../../../categories/presentation/bloc/categories_bloc.dart';
import '../../../categories/presentation/bloc/categories_event.dart';
import '../../../categories/presentation/bloc/categories_state.dart';
import '../bloc/items_bloc.dart';
import '../../../bluetooth/presentation/utils/device_sync_helper.dart';
import '../bloc/items_event.dart';
import '../bloc/items_state.dart';
import '../widgets/device_selector_sheet.dart';
import '../widgets/unlock_confirm_dialog.dart';
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
  AnimationController? _reorderHintController;
  Animation<double>? _liftAnimation;
  bool _reorderHintTriggered = false;
  bool _activationHintTriggered = false;
  OverlayEntry? _activationHintOverlay;
  OverlayEntry? _reorderHintOverlay;
  AppUiState? _activationHintAppUiState; // For pin tap callback

  // Search state
  bool _isSearching = false;
  final _searchController = TextEditingController();
  String _searchQuery = '';
  Timer? _searchDebounceTimer;

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
  // Suppress _checkDeviceSync after connection (BLoC handles initial push)
  DateTime? _deviceConnectedAt;

  // Key to force category dropdown rebuild after returning from Manage Categories
  int _categoryDropdownKey = 0;

  @override
  void initState() {
    super.initState();
    // Mark user as existing (completed onboarding) when they reach items page
    _markOnboardingComplete();

    // Load paired devices so the "Connect Your Device" card knows whether to show
    context.read<BluetoothBloc>().add(const LoadPairedDevices());

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

  /// Marks the user as having completed onboarding when they reach the items page.
  /// This ensures existing users who skipped or didn't see onboarding are marked appropriately.
  Future<void> _markOnboardingComplete() async {
    final userRepository = sl<UserRepository>();
    await userRepository.completeOnboarding(primaryUseCase: 'existing_user');
  }

  // Number formatter for count display
  static final NumberFormat _countFormat = NumberFormat.decimalPattern();
  static const int _maxItems = 100;

  @override
  Widget build(BuildContext context) {
    final appUiState = context.watch<AppUiState>();
    final brightness = Theme.of(context).brightness;
    final textTheme = Theme.of(context).textTheme;

    // Theme-aware colors
    final primaryBackground = AppColors.primaryBackground(brightness);
    final primaryText = AppColors.primaryText(brightness);
    final secondaryText = AppColors.secondaryText(brightness);
    final alternate = AppColors.alternate(brightness);
    final activatedColor = AppColors.activated(brightness);

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
            // Suppress _checkDeviceSync for a few seconds — BLoC handles initial push
            _deviceConnectedAt = DateTime.now();
            // When device connects, show all categories view
            // (device sync sends correct category-filtered items regardless of app view)
            context.read<ItemsBloc>().add(FilterByCategoryEvent(null));
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (!mounted) return;
              context.read<AppUiState>().selectedCategoryId = null;
            });
          },
          // Sync AppUiState.activeItemId whenever BluetoothState.selectedItemId changes
          // (from device prefs, override completion, or any other source)
          child: BlocListener<BluetoothBloc, BluetoothState>(
            listenWhen: (previous, current) =>
                previous.selectedItemId != current.selectedItemId,
            listener: (context, bluetoothState) {
              final selectedItemId = bluetoothState.selectedItemId;
              WidgetsBinding.instance.addPostFrameCallback((_) {
                if (!mounted) return;
                final appUiState = context.read<AppUiState>();
                if (selectedItemId == null || selectedItemId.isEmpty) {
                  appUiState.clearActiveItem();
                } else if (appUiState.activeItemId != selectedItemId) {
                  appUiState.activeItemId = selectedItemId;
                }
              });
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
                    style: textTheme.titleLarge?.copyWith(
                      color: primaryText,
                    ),
                  ),
                  centerTitle: true,
                  elevation: 0.0,
                  actions: [
                    // Search icon (opens search, X in search bar closes it)
                    IconButton(
                      tooltip: 'Search items',
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
                            tooltip: 'Create item',
                            onPressed: () async {
                              // Check item limit
                              if (hasReachedLimit) {
                                await _showItemLimitDialog(context);
                                return;
                              }
                              await context.pushNamed<Item>(ItemFormPage.routeName);
                            },
                            style: IconButton.styleFrom(
                              backgroundColor: AppColors.primary,
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
                  child: Column(
                        mainAxisSize: MainAxisSize.max,
                        crossAxisAlignment: CrossAxisAlignment.stretch,
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
                          // Active item chips (one per connected device)
                          BlocSelector<ItemsBloc, ItemsState, ItemsLoaded?>(
                            selector: (state) => state is ItemsLoaded ? state : null,
                            builder: (context, itemsState) {
                              if (!isConnected || itemsState == null) {
                                return const SizedBox.shrink();
                              }
                              return _buildActiveItemChips(
                                context,
                                itemsState,
                                bluetoothState,
                                appUiState,
                                primaryText,
                                secondaryText,
                              );
                            },
                          ),
                          // Connection status banner
                          if (!isConnected)
                            _buildDisconnectedBanner(context)
                          else if (bluetoothState.isSyncing)
                            _buildSyncingBanner(context),
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
                                showErrorSnackBar(context, state.message);
                              }
                            },
                            buildWhen: (previous, current) {
                              // Rebuild on any state change, but also check if we need to sync device
                              if (previous is ItemsLoaded && current is ItemsLoaded) {
                                _checkDeviceSync(context, previous, current);
                              } else if (current is ItemsLoaded && _lastSyncedSignature == null) {
                                // Initialize tracking after a non-ItemsLoaded → ItemsLoaded
                                // transition (e.g., returning from another page, stream reconnect).
                                // Don't sync — just set the baseline so future changes are detected.
                                _initSyncTracking(context, current);
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
                                      valueColor: AlwaysStoppedAnimation<Color>(AppColors.primary),
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
                                  return _buildEmptyState(context, primaryText, secondaryText);
                                }

                                // Show "no results" if search has no matches
                                if (filteredItems.isEmpty && _searchQuery.isNotEmpty) {
                                  return _buildNoSearchResults(context, primaryText, secondaryText);
                                }

                                // Use ReorderableListView when connected and not searching
                                // During search, use ListView with "Move to Top" action instead
                                if (_searchQuery.isEmpty) {
                                  // Trigger activation hint when connected but no item selected
                                  final deviceSelectedId = context.read<BluetoothBloc>().state.selectedItemId;
                                  final hasNoDeviceSelection = deviceSelectedId == null || deviceSelectedId.isEmpty;

                                  if (isConnected && hasNoDeviceSelection && !appUiState.hasShownActivationHint && !_activationHintTriggered && filteredItems.isNotEmpty) {
                                    WidgetsBinding.instance.addPostFrameCallback((_) {
                                      _showActivationHint(appUiState, context);
                                    });
                                  }
                                  // Trigger reorder hint when 2+ items (independent of activation hint)
                                  else if (filteredItems.length >= 2 && !appUiState.hasShownReorderHint && !_reorderHintTriggered) {
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
                                        // Dismiss reorder hint when user actually drags
                                        _dismissReorderHint(appUiState);
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
                                        connectedDevices: bluetoothState.connectedDevices,
                                        pairedDevices: bluetoothState.pairedDevices,
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
                                        connectedDevices: bluetoothState.connectedDevices,
                                        pairedDevices: bluetoothState.pairedDevices,
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
                                  // Regular ListView when disconnected or searching
                                  // No hints shown when disconnected (device connection required for actions)
                                  final listWidget = RefreshIndicator(
                                    color: AppColors.primary,
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
                                          categoryLabel: categoryLabelText,
                                          connectedDevices: bluetoothState.connectedDevices,
                                          pairedDevices: bluetoothState.pairedDevices,
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
              width: 84.0, // Fixed width to prevent layout shift
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
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: secondaryText.withValues(alpha: 0.7),
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
        style: Theme.of(context).textTheme.bodySmall?.copyWith(
          color: secondaryText.withValues(alpha: 0.7),
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
        style: Theme.of(context).textTheme.bodySmall?.copyWith(
          color: secondaryText.withValues(alpha: 0.7),
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  /// Calculates which category should be sticky based on scroll offset.
  /// Iterates through all categories (including empty ones) to match the
  /// actual list layout, preventing the sticky header from skipping empty
  /// categories.
  String? _calculateStickyCategory(List<Item> filteredItems, double scrollOffset) {
    if (filteredItems.isEmpty) return null;

    // Approximate heights - labels and items are now separate entries
    const double itemHeight = 76.0; // tile + padding
    const double labelHeight = 28.0; // label widget height

    // Group items by category
    final itemsByCategory = <String, List<Item>>{};
    for (final item in filteredItems) {
      final catId = item.categoryId ?? '';
      itemsByCategory.putIfAbsent(catId, () => []).add(item);
    }

    // Build ordered category list matching the actual list layout
    final orderedCategories = <String>[];
    final sortedCategoryIds = _cachedCategoryOrder.keys.toList()
      ..sort((a, b) => (_cachedCategoryOrder[a] ?? 0).compareTo(_cachedCategoryOrder[b] ?? 0));
    for (final catId in sortedCategoryIds) {
      orderedCategories.add(catId);
    }
    orderedCategories.add(''); // Uncategorized always last

    double currentOffset = 0.0;
    String? lastCategory;

    for (final catId in orderedCategories) {
      final categoryName = catId.isEmpty
          ? 'Uncategorized'
          : _cachedCategoryNames[catId] ?? 'Unknown';

      // Check if the next label is below the scroll position
      if (currentOffset > scrollOffset) {
        return lastCategory;
      }
      lastCategory = categoryName;
      currentOffset += labelHeight;

      // Add item heights for this category
      final catItems = itemsByCategory[catId] ?? [];
      for (int i = 0; i < catItems.length; i++) {
        currentOffset += itemHeight;
        if (currentOffset > scrollOffset + 40) {
          return lastCategory;
        }
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
        style: Theme.of(context).textTheme.bodyLarge?.copyWith(
          color: primaryText,
        ),
        decoration: InputDecoration(
          hintText: 'Search items...',
          hintStyle: Theme.of(context).textTheme.bodyLarge?.copyWith(
            color: secondaryText,
          ),
          prefixIcon: Icon(Icons.search_rounded, color: secondaryText),
          suffixIcon: IconButton(
            tooltip: 'Clear search',
            icon: Icon(Icons.close_rounded, color: secondaryText),
            onPressed: () {
              if (_searchQuery.isNotEmpty) {
                // Clear text first
                _searchDebounceTimer?.cancel();
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
          _searchDebounceTimer?.cancel();
          _searchDebounceTimer = Timer(const Duration(milliseconds: 300), () {
            if (mounted) setState(() => _searchQuery = value.toLowerCase());
          });
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
    // Validate selectedCategoryId exists in available options
    // Valid values: null (All), '' (Uncategorized), or a category.id that exists
    final categoryExists = selectedCategoryId == null ||
        selectedCategoryId == '' ||
        categories.any((c) => c.id == selectedCategoryId);
    final validCategoryId = categoryExists ? selectedCategoryId : null;

    // If selected category was deleted, reset filter in BLoC and AppUiState
    if (!categoryExists) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        context.read<ItemsBloc>().add(FilterByCategoryEvent(null));
        context.read<AppUiState>().selectedCategoryId = null;
      });
    }

    return Container(
      height: 48.0,
      padding: const EdgeInsets.symmetric(horizontal: 16.0),
      decoration: BoxDecoration(
        color: alternate,
        borderRadius: BorderRadius.circular(12.0),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String?>(
          key: ValueKey(_categoryDropdownKey),
          value: validCategoryId,
          isExpanded: true,
          icon: Icon(Icons.expand_more_rounded, color: secondaryText),
          style: Theme.of(context).textTheme.bodyLarge?.copyWith(
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
                    style: Theme.of(context).textTheme.bodyLarge?.copyWith(
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
                          style: Theme.of(context).textTheme.bodyLarge?.copyWith(
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
                    style: Theme.of(context).textTheme.bodyLarge?.copyWith(
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
                    style: Theme.of(context).textTheme.bodyLarge?.copyWith(
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
              context.push('/profile/categories').then((_) {
                // Increment key to force dropdown rebuild with correct value
                if (mounted) setState(() => _categoryDropdownKey++);
              });
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

  Widget _buildActiveItemChips(
    BuildContext context,
    ItemsLoaded itemsState,
    BluetoothState bluetoothState,
    AppUiState appUiState,
    Color primaryText,
    Color secondaryText,
  ) {
    final brightness = Theme.of(context).brightness;
    final currentCategoryId = itemsState.selectedCategoryId;

    // Build one chip per connected device that has a selected item.
    final chips = <Widget>[];
    for (final entry in bluetoothState.connectedDevices.entries) {
      final deviceId = entry.key;
      final selectedItemId = entry.value.selectedItemId;
      if (selectedItemId == null || selectedItemId.isEmpty) continue;

      final activeItem = itemsState.items.where((i) => i.id == selectedItemId).firstOrNull;
      if (activeItem == null) continue;

      // Resolve device color
      final pairedIdx = bluetoothState.pairedDevices.indexWhere((d) => d.deviceInstanceId == deviceId);
      final chipColor = pairedIdx >= 0
          ? AppColors.deviceColor(bluetoothState.pairedDevices[pairedIdx].color, brightness)
          : AppColors.actionActivate;

      // Category info
      final activeCategoryId = activeItem.categoryId;
      final isUncategorized = activeCategoryId == null || activeCategoryId.isEmpty;
      final isInCurrentCategory =
          (currentCategoryId == '' && isUncategorized) ||
          (currentCategoryId != null && currentCategoryId == activeCategoryId);

      String categoryName = 'Uncategorized';
      if (activeCategoryId != null && activeCategoryId.isNotEmpty) {
        categoryName = _cachedCategoryNames[activeCategoryId] ?? 'Uncategorized';
      }

      chips.add(_buildSingleActiveChip(
        context,
        itemName: activeItem.name,
        categoryName: categoryName,
        chipColor: chipColor,
        isInCurrentCategory: isInCurrentCategory,
        secondaryText: secondaryText,
        onTap: isInCurrentCategory ? null : () {
          final targetCategoryId = isUncategorized ? '' : activeCategoryId!;
          context.read<ItemsBloc>().add(FilterByCategoryEvent(targetCategoryId));
          context.read<AppUiState>().selectedCategoryId = targetCategoryId;
        },
      ));
    }

    // Fallback: single-device mode without connectedDevices entry.
    // Only use fallback when no devices are connected — if devices ARE
    // connected but none selected an item, show nothing (empty start).
    if (chips.isEmpty && bluetoothState.connectedDevices.isEmpty) {
      final activeId = appUiState.activeItemId;
      if (activeId.isEmpty) return const SizedBox.shrink();
      final activeItem = itemsState.items.where((i) => i.id == activeId).firstOrNull;
      if (activeItem == null) return const SizedBox.shrink();

      final activeCategoryId = activeItem.categoryId;
      final isUncategorized = activeCategoryId == null || activeCategoryId.isEmpty;
      final isInCurrentCategory =
          (currentCategoryId == '' && isUncategorized) ||
          (currentCategoryId != null && currentCategoryId == activeCategoryId);

      String categoryName = 'Uncategorized';
      if (activeCategoryId != null && activeCategoryId.isNotEmpty) {
        categoryName = _cachedCategoryNames[activeCategoryId] ?? 'Uncategorized';
      }

      chips.add(_buildSingleActiveChip(
        context,
        itemName: activeItem.name,
        categoryName: categoryName,
        chipColor: AppColors.actionActivate,
        isInCurrentCategory: isInCurrentCategory,
        secondaryText: secondaryText,
        onTap: isInCurrentCategory ? null : () {
          final targetCategoryId = isUncategorized ? '' : activeCategoryId!;
          context.read<ItemsBloc>().add(FilterByCategoryEvent(targetCategoryId));
          context.read<AppUiState>().selectedCategoryId = targetCategoryId;
        },
      ));
    }

    if (chips.isEmpty) return const SizedBox.shrink();

    // Single chip: no scroll needed
    if (chips.length == 1) {
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16.0),
        child: chips.first,
      );
    }

    // Multiple chips: horizontal scroll row
    return SizedBox(
      height: 28.0,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16.0),
        itemCount: chips.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8.0),
        itemBuilder: (_, i) => chips[i],
      ),
    );
  }

  Widget _buildSingleActiveChip(
    BuildContext context, {
    required String itemName,
    required String categoryName,
    required Color chipColor,
    required bool isInCurrentCategory,
    required Color secondaryText,
    VoidCallback? onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 4.0),
        decoration: BoxDecoration(
          color: chipColor.withAlpha(15),
          borderRadius: BorderRadius.circular(12.0),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.push_pin_rounded,
              size: 11.0,
              color: chipColor,
            ),
            const SizedBox(width: 4.0),
            Text(
              '$itemName · $categoryName',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: secondaryText,
                fontSize: 11.0,
                fontWeight: FontWeight.w500,
              ),
              overflow: TextOverflow.ellipsis,
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
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: secondaryText,
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

  Widget _buildSyncingBanner(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    final secondaryText = AppColors.secondaryText(brightness);

    return Center(
      child: Padding(
        padding: const EdgeInsets.only(top: 12.0),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
          decoration: BoxDecoration(
            color: secondaryText.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(20.0),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox(
                width: 12.0,
                height: 12.0,
                child: CircularProgressIndicator(
                  strokeWidth: 1.5,
                  color: secondaryText,
                ),
              ),
              const SizedBox(width: 6.0),
              Text(
                'Syncing...',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: secondaryText,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _handleActivate(BuildContext context, Item item,
      AppUiState appUiState, String? selectedItemId) async {
    final btBloc = context.read<BluetoothBloc>();
    final btState = btBloc.state;
    if (btState.hasMultipleDevices) {
      final devicesList = btState.connectedDevices.entries
          .where((e) => e.value.isOnline)
          .map((e) {
            final pd = btState.pairedDevices.firstWhere(
              (p) => p.deviceInstanceId == e.key,
              orElse: () => PairedDevice(deviceInstanceId: e.key, deviceName: e.key, pairedAt: DateTime.now()));
            return (instanceId: e.key, name: pd.deviceName, color: pd.color);
          }).toList();
      if (devicesList.isEmpty || !context.mounted) return;
      await showModalBottomSheet<void>(
        context: context,
        builder: (_) => DeviceSelectorSheet(
          devices: devicesList,
          onDeviceSelected: (deviceId) {
            Navigator.of(context).pop();
            _claimForDevice(context, item, deviceId, appUiState, btBloc.state);
          },
        ),
      );
      return;
    }
    // Single device — claim immediately
    final deviceId = btState.connectedDeviceInstanceId ?? '';
    if (deviceId.isEmpty) return;
    _claimForDevice(context, item, deviceId, appUiState, btState);
  }

  void _claimForDevice(BuildContext context, Item item, String deviceId,
      AppUiState appUiState, BluetoothState btState) {
    appUiState.activeItemId = item.id;
    final itemsState = context.read<ItemsBloc>().state;
    List<Item>? categoryItems;
    if (itemsState is ItemsLoaded) {
      final catId = item.categoryId;
      categoryItems = itemsState.items.where((i) {
        final sameCat = catId == null || catId.isEmpty
            ? (i.categoryId == null || i.categoryId!.isEmpty)
            : i.categoryId == catId;
        return sameCat && (i.claimedBy == null || i.claimedBy == deviceId);
      }).toList()..sort((a, b) => a.categoryOrder.compareTo(b.categoryOrder));

      // In multi-device mode, _checkDeviceSync uses a global signature (all
      // items sorted by id). Set the same format here so the Firestore stream
      // echo (claimedBy change only) doesn't look like a signature mismatch.
      final btState2 = context.read<BluetoothBloc>().state;
      if (btState2.connectedDevices.length > 1) {
        _lastSyncedSignature = _computeCategorySignature(
          itemsState.items.toList()..sort((a, b) => a.id.compareTo(b.id)),
        );
        _lastSyncedCategoryId = null;
      } else {
        _lastSyncedCategoryId = catId ?? '';
        _lastSyncedSignature = _computeCategorySignature(categoryItems);
      }
      _lastSyncTime = DateTime.now();
    }
    // Source previousItemId from actual Firestore state (items in memory),
    // not BLoC selectedItemId which can be null on first activation after reconnect.
    final prevId = (itemsState is ItemsLoaded)
        ? itemsState.items.cast<Item?>().firstWhere(
            (i) => i!.claimedBy == deviceId && i.id != item.id,
            orElse: () => null,
          )?.id
        : btState.connectedDevices[deviceId]?.selectedItemId;
    final btBloc = context.read<BluetoothBloc>();
    if (categoryItems != null) {
      btBloc.add(SendItemsToDevice(
        categoryItems, deviceInstanceId: deviceId, categoryNames: _cachedCategoryNames));
    }
    btBloc.add(SendSelectedItem(item.id, item.deviceItemId ?? 0, deviceInstanceId: deviceId));
    btBloc.add(ClaimItem(itemId: item.id, deviceInstanceId: deviceId, previousItemId: prevId, categoryId: item.categoryId ?? ''));
  }

  Future<void> _handleUnlock(BuildContext context, Item item,
      Map<String, DeviceConnectionState> connectedDevices,
      List<PairedDevice> pairedDevices) async {
    if (item.claimedBy == null) return;
    final idx = pairedDevices.indexWhere((d) => d.deviceInstanceId == item.claimedBy);
    final deviceName = idx >= 0 ? pairedDevices[idx].deviceName : item.claimedBy!;
    final isOnline = connectedDevices[item.claimedBy!]?.isOnline == true;
    if (!context.mounted) return;
    final confirmed = await showUnlockConfirmDialog(
      context: context,
      itemName: item.name,
      deviceName: deviceName,
      isBreakGlass: !isOnline,
    );
    if (confirmed && context.mounted) {
      context.read<BluetoothBloc>().add(ReleaseItem(
        itemId: item.id,
        claimedBy: item.claimedBy,
        itemName: item.name,
      ));
    }
  }

  /// Returns claiming device name (+ "· disconnected" if offline), or null.
  String? _claimDeviceName(Item item, Map<String, DeviceConnectionState> connectedDevices,
      List<PairedDevice> pairedDevices) {
    if (item.claimedBy == null) return null;
    final idx = pairedDevices.indexWhere((d) => d.deviceInstanceId == item.claimedBy);
    final name = idx >= 0 ? pairedDevices[idx].deviceName : item.claimedBy!;
    final isOnline = connectedDevices[item.claimedBy!]?.isOnline == true;
    return isOnline ? name : '$name \u00B7 disconnected';
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
    Animation<double>? liftAnimation,
    String? categoryLabel,
    bool isDragProxy = false,
    Map<String, DeviceConnectionState> connectedDevices = const {},
    List<PairedDevice> pairedDevices = const [],
  }) {
    // Check ALL devices' selections for instant color.
    final isActivated = isConnected &&
        connectedDevices.values.any((d) => d.selectedItemId == item.id);
    final displayCount = appUiState.isTodayToggle ? item.todayCount : item.count;

    final brightness = Theme.of(context).brightness;

    // Resolve device color: prefer Firestore claim, then optimistic selection
    final activateColor = () {
      if (item.claimedBy != null) {
        final idx = pairedDevices.indexWhere((d) => d.deviceInstanceId == item.claimedBy);
        if (idx >= 0) return AppColors.deviceColor(pairedDevices[idx].color, brightness);
      }
      // Optimistic: find which device currently has this item selected
      for (final entry in connectedDevices.entries) {
        if (entry.value.selectedItemId == item.id) {
          final idx = pairedDevices.indexWhere((d) => d.deviceInstanceId == entry.key);
          if (idx >= 0) return AppColors.deviceColor(pairedDevices[idx].color, brightness);
        }
      }
      // Single-device fallback (only 1 device connected, no ambiguity)
      if (connectedDevices.length == 1) {
        final deviceId = connectedDevices.keys.first;
        final idx = pairedDevices.indexWhere((d) => d.deviceInstanceId == deviceId);
        if (idx >= 0) return AppColors.deviceColor(pairedDevices[idx].color, brightness);
      }
      return null;
    }();

    // Claim state — applies regardless of how many devices are connected.
    // Suppress stale Firestore claimedBy when the claiming device is online
    // and has actively selected a different item (claim is being released).
    final isClaimed = item.claimedBy != null;
    final claimDevice = isClaimed ? connectedDevices[item.claimedBy!] : null;
    final claimBeingReleased = claimDevice != null && claimDevice.isOnline &&
        claimDevice.selectedItemId != null && claimDevice.selectedItemId != item.id;
    final isClaimedOnline = claimDevice != null && claimDevice.isOnline && !claimBeingReleased;
    final isClaimedOffline = isClaimed && !claimBeingReleased &&
        (claimDevice == null || !claimDevice.isOnline);
    final effectivelyActivated = isActivated || isClaimedOnline;
    final claimedColor = isClaimedOffline
        ? activateColor?.withValues(alpha: 0.35)
        : activateColor;

    // The tile content - wrapped in ReorderableDelayedDragStartListener
    // to enable long-press-to-drag without a visible handle
    final tileContainer = Container(
          decoration: BoxDecoration(
            color: effectivelyActivated
                ? (claimedColor?.withValues(alpha: 0.2) ?? activatedColor)
                : isClaimedOffline
                    ? (claimedColor?.withValues(alpha: 0.1) ?? alternate)
                    : alternate,
            border: effectivelyActivated
                ? Border(left: BorderSide(color: claimedColor ?? AppColors.actionActivate, width: 4.0))
                : isClaimedOffline
                    ? Border(left: BorderSide(color: claimedColor ?? AppColors.actionActivate, width: 4.0))
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
              padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 6.0),
              child: Row(
                children: [
                  // Item name (expanded to take remaining space)
                  Expanded(
                    child: Builder(builder: (context) {
                      final subtitleStyle = Theme.of(context).textTheme.bodySmall?.copyWith(
                        fontSize: 11.0, fontStyle: FontStyle.italic);
                      // Resolve claiming device: Firestore claim (suppressed
                      // when being released), then optimistic selection.
                      final claimDeviceId = (item.claimedBy != null && !claimBeingReleased)
                          ? item.claimedBy
                          : connectedDevices.entries
                              .where((e) => e.value.selectedItemId == item.id)
                              .map((e) => e.key)
                              .firstOrNull;
                      final nameWidget = Text(
                        item.name,
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          color: !isConnected ? secondaryText : primaryText,
                          fontSize: 17.0,
                        ),
                        overflow: TextOverflow.ellipsis,
                      );
                      if (claimDeviceId == null) {
                        // Pad equally above and below to match claimed tile
                        // height (subtitle line ≈ 11pt × 1.4 line-height).
                        const halfSubtitle = 7.5;
                        return Padding(
                          padding: const EdgeInsets.symmetric(vertical: halfSubtitle),
                          child: nameWidget,
                        );
                      }
                      final idx = pairedDevices.indexWhere((d) => d.deviceInstanceId == claimDeviceId);
                      final claimName = () {
                        final name = idx >= 0 ? pairedDevices[idx].deviceName : claimDeviceId;
                        final online = connectedDevices[claimDeviceId]?.isOnline == true;
                        return online ? name : '$name \u00B7 disconnected';
                      }();
                      final claimStyle = subtitleStyle?.copyWith(
                        color: isClaimedOffline
                                ? AppColors.secondaryText(brightness).withValues(alpha: 0.6)
                                : claimedColor ?? AppColors.secondaryText(brightness),
                      );
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          nameWidget,
                          Text(claimName,
                            style: claimStyle,
                            overflow: TextOverflow.ellipsis),
                        ],
                      );
                    }),
                  ),
                  const SizedBox(width: 16.0),
                  // Accent bar + count column
                  Builder(
                    builder: (context) {
                      // Colors for accent bar and text
                      final accentColor = (effectivelyActivated || isClaimedOffline)
                          ? (claimedColor ?? AppColors.accentActive(brightness))
                          : AppColors.accentInactive(brightness);
                      final textColor = (effectivelyActivated || isClaimedOffline)
                          ? (claimedColor ?? AppColors.accentActive(brightness))
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
                                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                    color: textColor,
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
        );

    Widget tileContent = ClipRRect(
      borderRadius: BorderRadius.circular(8.0),
      child: isClaimedOffline
          ? Stack(children: [
              tileContainer,
              Positioned.fill(
                child: IgnorePointer(
                  child: CustomPaint(
                    painter: _DiagonalStripesPainter(
                      color: (claimedColor ?? AppColors.secondaryText(brightness))
                          .withValues(alpha: 0.12),
                    ),
                  ),
                ),
              ),
            ])
          : tileContainer,
    );

    // For drag proxy, return just the tile content without padding/slidable
    if (isDragProxy) {
      return tileContent;
    }

    // Wrap with ReorderableDelayedDragStartListener for long-press drag
    tileContent = ReorderableDelayedDragStartListener(
      index: index,
      child: tileContent,
    );

    // Claim-aware action state
    final editable = isClaimed ? isItemEditable(item.claimedBy, connectedDevices) : true;
    final showUnlock = isClaimed;
    // Resolve claiming device's color for unlock action
    final claimColor = isClaimed ? () {
      final idx = pairedDevices.indexWhere((d) => d.deviceInstanceId == item.claimedBy);
      if (idx < 0) return null;
      return AppColors.deviceColor(pairedDevices[idx].color, brightness);
    }() : null;

    Widget result = Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Slidable(
          endActionPane: ActionPane(
            motion: const ScrollMotion(),
            extentRatio: (showUnlock && !editable) ? 0.2 : 0.5,
            children: [
            // Multi-device + claimed → Unlock. Otherwise when connected → Activate.
            if (showUnlock)
              CustomSlidableAction(
                backgroundColor: claimColor ?? AppColors.actionActivate,
                foregroundColor: Colors.white,
                autoClose: false,
                onPressed: (ctx) async {
                  HapticFeedback.lightImpact();
                  Slidable.of(ctx)?.close();
                  await _handleUnlock(context, item, connectedDevices, pairedDevices);
                },
                child: const Icon(Icons.lock_open_rounded, size: 24),
              )
            else if (isConnected)
              CustomSlidableAction(
                backgroundColor: activateColor ?? AppColors.actionActivate,
                foregroundColor: Colors.white,
                autoClose: false,
                onPressed: (ctx) async {
                  HapticFeedback.lightImpact();
                  _dismissActivationHintIfShowing();
                  await _handleActivate(context, item, appUiState, selectedItemId);
                  Slidable.of(ctx)?.close();
                },
                child: const Icon(Icons.push_pin_rounded, size: 24),
              ),
            // Edit — hidden for claimed items when claiming device is offline
            if (editable)
            CustomSlidableAction(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
              autoClose: false,
              onPressed: (ctx) async {
                HapticFeedback.lightImpact();
                _dismissActivationHintIfShowing();
                Slidable.of(ctx)?.close();
                context.pushNamed(ItemFormPage.routeName, extra: {'item': item});
              },
              child: const Icon(Icons.edit, size: 24),
            ),
            // Delete — hidden for claimed items when claiming device is offline
            if (editable)
            CustomSlidableAction(
              backgroundColor: AppColors.actionDelete,
              foregroundColor: Colors.white,
              autoClose: false,
              onPressed: (ctx) async {
                HapticFeedback.mediumImpact();
                _dismissActivationHintIfShowing();

                // Capture references BEFORE the async dialog
                final itemsBloc = context.read<ItemsBloc>();
                final bluetoothBloc = context.read<BluetoothBloc>();
                final appUiStateRef = appUiState;
                final deviceSelectedId = selectedItemId;

                final currentState = itemsBloc.state;
                final currentItems = currentState is ItemsLoaded ? currentState.items : <Item>[];

                final confirmed = await _showDeleteConfirmation(context, item.name);
                if (confirmed) {
                  if (appUiStateRef.activeItemId == item.id) {
                    appUiStateRef.activeItemId = 'none';
                  }
                  final newSelectedId = (deviceSelectedId == item.id || deviceSelectedId == null)
                      ? 'none' : deviceSelectedId;
                  itemsBloc.add(DeleteItemEvent(item.id));

                  final deletedCatId = item.categoryId ?? '';
                  String? selectedCatId;
                  if (newSelectedId != 'none') {
                    final selectedItem = currentItems.where((i) => i.id == newSelectedId).firstOrNull;
                    selectedCatId = selectedItem?.categoryId ?? '';
                  }
                  if (newSelectedId == 'none' || deletedCatId == selectedCatId) {
                    _syncDeviceWithSelectedCategory(
                      bluetoothBloc: bluetoothBloc, allItems: currentItems,
                      deviceSelectedId: newSelectedId, excludeItemId: item.id,
                      fallbackCategoryId: item.categoryId);
                    final targetCatId = selectedCatId ?? deletedCatId;
                    final postDeleteItems = currentItems
                        .where((i) => i.id != item.id && (i.categoryId ?? '') == targetCatId)
                        .toList()..sort((a, b) => a.categoryOrder.compareTo(b.categoryOrder));
                    _lastSyncedSignature = _computeCategorySignature(postDeleteItems);
                    _lastSyncedCategoryId = targetCatId;
                    _lastSyncTime = DateTime.now();
                  }
                }
                Slidable.of(ctx)?.close();
              },
              child: const Icon(Icons.delete_outline_rounded, size: 24),
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
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
              color: primaryText,
            ),
          ),
          const SizedBox(height: 8.0),
          Text(
            'Try a different search term',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: secondaryText,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context, Color primaryText, Color secondaryText) {
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
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
              color: primaryText,
            ),
          ),
          const SizedBox(height: 8.0),
          Text(
            'Create your first item to start tracking',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: secondaryText,
            ),
          ),
          const SizedBox(height: 24.0),
          FilledButton.icon(
            onPressed: () async {
              await context.pushNamed<Item>(ItemFormPage.routeName);
            },
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.primary,
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
              style: TextButton.styleFrom(foregroundColor: AppColors.actionDelete),
              child: const Text('Delete'),
            ),
          ],
        );
      },
    ) ?? false;
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
        builder: (context) => IgnorePointer(
          // Don't block taps - hint dismisses only when user actually drags
          child: Stack(
            children: [
              // Tooltip at bottom
              Positioned(
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
                            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                              color: Colors.white,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      );
      overlay.insert(_reorderHintOverlay!);

      // Lift up animation (stays lifted until dismissed)
      _reorderHintController?.forward();
    });
  }

  /// Dismisses the reorder hint overlay
  void _dismissReorderHint(AppUiState appUiState) {
    if (_reorderHintOverlay == null) return;
    _reorderHintController?.reverse();
    _reorderHintOverlay?.remove();
    _reorderHintOverlay = null;
    appUiState.markReorderHintShown();
  }

  /// Shows an activation hint for new users who just created their first item.
  /// Displays a tooltip until user taps the pin icon.
  void _showActivationHint(AppUiState appUiState, BuildContext context) {
    if (_activationHintTriggered || appUiState.hasShownActivationHint) return;
    _activationHintTriggered = true;

    // Store reference for listener callback
    _activationHintAppUiState = appUiState;

    // Delay to let the list render first
    Future.delayed(const Duration(milliseconds: 600), () {
      if (!mounted) return;

      // Show tooltip overlay (dismisses only when pin is tapped)
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
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: Colors.white,
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
    });
  }

  /// Dismisses the activation hint overlay
  void _dismissActivationHint(AppUiState appUiState) {
    if (_activationHintOverlay == null) return;
    _activationHintAppUiState = null;
    _activationHintOverlay?.remove();
    _activationHintOverlay = null;
    appUiState.markActivationHintShown();
  }

  /// Dismisses activation hint if showing (called when any item is swiped/actioned)
  void _dismissActivationHintIfShowing() {
    if (_activationHintOverlay != null && _activationHintAppUiState != null) {
      _dismissActivationHint(_activationHintAppUiState!);
    }
  }

  /// Computes which categories were affected by an items state change.
  /// Returns the set of categoryIds ('' for Uncategorized) that differ
  /// between [previous] and [current] — either an item moved, was added,
  /// removed, or had its properties changed within that category.
  Set<String> _computeAffectedCategories(List<Item> previous, List<Item> current) {
    final affected = <String>{};
    final prevMap = {for (final i in previous) i.id: i};
    final currMap = {for (final i in current) i.id: i};

    for (final item in current) {
      final prev = prevMap[item.id];
      if (prev == null) {
        // New item
        affected.add(item.categoryId ?? '');
      } else if ((prev.categoryId ?? '') != (item.categoryId ?? '')) {
        // Moved between categories
        affected.add(prev.categoryId ?? '');
        affected.add(item.categoryId ?? '');
      } else if (prev.categoryOrder != item.categoryOrder ||
          prev.name != item.name ||
          prev.incrementBy != item.incrementBy ||
          prev.reminder != item.reminder ||
          prev.reminderValue != item.reminderValue) {
        // Changed within same category
        affected.add(item.categoryId ?? '');
      }
    }
    // Deleted items
    for (final item in previous) {
      if (!currMap.containsKey(item.id)) {
        affected.add(item.categoryId ?? '');
      }
    }
    return affected;
  }

  /// Computes a signature string for the given category items.
  /// Used to detect whether the device-relevant item list has changed.
  String _computeCategorySignature(List<Item> categoryItems) {
    return categoryItems
        .map((i) => '${i.id}:${i.categoryId ?? ''}:${i.categoryOrder}:${i.name}:${i.incrementBy}:${i.reminder.index}:${i.reminderValue}')
        .join(',');
  }

  /// Initializes sync tracking without sending data to the device.
  /// Called on non-ItemsLoaded → ItemsLoaded transitions (e.g., returning
  /// from another page) so that future buildWhen calls have a baseline.
  void _initSyncTracking(BuildContext context, ItemsLoaded current) {
    final bluetoothState = context.read<BluetoothBloc>().state;
    if (!bluetoothState.isConnected) return;

    final isMultiDevice = bluetoothState.connectedDevices.length > 1;

    if (isMultiDevice) {
      _lastSyncedSignature = _computeCategorySignature(
        current.items.toList()..sort((a, b) => a.id.compareTo(b.id)),
      );
      _lastSyncedCategoryId = null;
      _lastSyncTime = DateTime.now();
      return;
    }

    final selectedId = bluetoothState.selectedItemId;
    if (selectedId == null || selectedId.isEmpty) return;

    final selectedItem = current.items
        .where((i) => i.id == selectedId)
        .firstOrNull;
    if (selectedItem == null) return;

    final selectedCatId = selectedItem.categoryId ?? '';
    final categoryItems = current.items
        .where((i) => (i.categoryId ?? '') == selectedCatId)
        .toList()
      ..sort((a, b) => a.categoryOrder.compareTo(b.categoryOrder));

    _lastSyncedSignature = _computeCategorySignature(categoryItems);
    _lastSyncedCategoryId = selectedCatId;
    _lastSyncTime = DateTime.now();
  }

  /// Checks whether device sync is needed and sends items if so.
  /// Called on ItemsLoaded → ItemsLoaded transitions in buildWhen.
  ///
  /// Only active in single-device mode. In multi-device mode, all pushes go
  /// through RefreshDeviceItemsUseCase (which applies claim filtering).
  /// _checkDeviceSync doesn't know about per-device selections or claims,
  /// so it would send unfiltered items with the wrong selection.
  void _checkDeviceSync(BuildContext context, ItemsLoaded previous, ItemsLoaded current) {
    final bluetoothState = context.read<BluetoothBloc>().state;
    if (!bluetoothState.isConnected) return;

    final isMultiDevice = bluetoothState.connectedDevices.length > 1;

    // Debounce: skip if synced recently (within 500ms)
    final now = DateTime.now();
    final recentlySynced = _lastSyncTime != null &&
        now.difference(_lastSyncTime!).inMilliseconds < 500;
    // After connection, suppress for 5s — BLoC handles initial push via
    // override or _refreshDeviceItems; this prevents a redundant second push.
    final justConnected = _deviceConnectedAt != null &&
        now.difference(_deviceConnectedAt!).inSeconds < 5;

    if (isMultiDevice) {
      // Multi-device: use a global items signature. Each device's
      // RefreshDeviceItemsUseCase resolves its own category independently,
      // so we just need to detect *any* items change and push to all.
      final globalSignature = _computeCategorySignature(
        current.items.toList()..sort((a, b) => a.id.compareTo(b.id)),
      );
      if (globalSignature != _lastSyncedSignature) {
        if (!recentlySynced && !justConnected) {
          _lastSyncTime = now;
          final affected = _computeAffectedCategories(previous.items, current.items);
          // Only push when at least one category is actually affected.
          // Signature can change due to field reordering or claim-only
          // changes (claimedBy not in signature but items list order may
          // shift) — in those cases affected is empty and no push is needed.
          if (affected.isNotEmpty) {
            context.read<BluetoothBloc>().add(RefreshAllDevices(
              affectedCategories: affected,
            ));
          }
        }
        _lastSyncedSignature = globalSignature;
        _lastSyncedCategoryId = null;
      }
      return;
    }

    // Single-device: category-scoped signature detection
    final selectedId = bluetoothState.selectedItemId;
    if (selectedId == null || selectedId.isEmpty) {
      // No selection — fall back to global signature like multi-device path.
      // RefreshDeviceItemsUseCase resolves category from claimedBy or cache.
      final globalSignature = _computeCategorySignature(
        current.items.toList()..sort((a, b) => a.id.compareTo(b.id)),
      );
      if (globalSignature != _lastSyncedSignature) {
        if (!recentlySynced && !justConnected) {
          _lastSyncTime = now;
          context.read<BluetoothBloc>().add(const RefreshAllDevices());
        }
        _lastSyncedSignature = globalSignature;
        _lastSyncedCategoryId = null;
      }
      return;
    }

    final selectedItem = current.items
        .where((i) => i.id == selectedId)
        .firstOrNull;
    if (selectedItem == null) return;

    final selectedCatId = selectedItem.categoryId ?? '';
    final currentCategoryItems = current.items
        .where((i) => (i.categoryId ?? '') == selectedCatId)
        .toList()
      ..sort((a, b) => a.categoryOrder.compareTo(b.categoryOrder));

    final currentSignature = _computeCategorySignature(currentCategoryItems);

    final categoryChanged = _lastSyncedCategoryId != selectedCatId;
    final signatureChanged = currentSignature != _lastSyncedSignature;

    if (signatureChanged || categoryChanged) {
      if (!recentlySynced && !justConnected) {
        _lastSyncTime = now;
        final btBloc = context.read<BluetoothBloc>();
        btBloc.add(SendItemsToDevice(
          currentCategoryItems,
          deviceInstanceId: btBloc.state.connectedDeviceInstanceId ?? '',
          categoryNames: _cachedCategoryNames,
        ));
        Future.delayed(const Duration(milliseconds: 100), () {
          if (!mounted) return;
          final btBloc2 = context.read<BluetoothBloc>();
          btBloc2.add(SendSelectedItem(
            selectedId,
            selectedItem.deviceItemId ?? 0,
            deviceInstanceId: btBloc2.state.connectedDeviceInstanceId ?? '',
          ));
        });
      }
      _lastSyncedSignature = currentSignature;
      _lastSyncedCategoryId = selectedCatId;
    }
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
    syncItemsToDevice(
      bluetoothBloc: bluetoothBloc,
      allItems: allItems,
      deviceSelectedId: deviceSelectedId,
      categoryNames: _cachedCategoryNames,
      excludeItemId: excludeItemId,
      includeItem: includeItem,
      fallbackCategoryId: fallbackCategoryId,
      deviceInstanceId: bluetoothBloc.state.connectedDeviceInstanceId ?? '',
    );
  }

  @override
  void dispose() {
    _activationHintOverlay?.remove();
    _activationHintOverlay = null;
    _reorderHintOverlay?.remove();
    _reorderHintOverlay = null;
    _reorderHintController?.dispose();
    _searchDebounceTimer?.cancel();
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

/// Paints thin diagonal stripes across a widget to signal "locked / unavailable".
class _DiagonalStripesPainter extends CustomPainter {
  _DiagonalStripesPainter({required this.color, this.spacing = 12.0, this.strokeWidth = 1.0});

  final Color color;
  final double spacing;
  final double strokeWidth;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = strokeWidth
      ..style = PaintingStyle.stroke;

    // Draw diagonal lines from top-left to bottom-right
    final total = size.width + size.height;
    for (double d = 0; d < total; d += spacing) {
      canvas.drawLine(
        Offset(d <= size.width ? d : size.width, d <= size.width ? 0 : d - size.width),
        Offset(d <= size.height ? 0 : d - size.height, d <= size.height ? d : size.height),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(_DiagonalStripesPainter oldDelegate) =>
      color != oldDelegate.color || spacing != oldDelegate.spacing || strokeWidth != oldDelegate.strokeWidth;
}
