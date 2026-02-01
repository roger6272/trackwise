import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';


import '../../../../core/di/injection.dart';
import '../../../auth/presentation/bloc/auth_bloc.dart';
import '../../../auth/presentation/bloc/auth_state.dart' as auth;
import '../../../../core/state/app_ui_state.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../bluetooth/presentation/bloc/bluetooth_bloc.dart';
import '../../../bluetooth/presentation/bloc/bluetooth_state.dart';
import '../../../bluetooth/presentation/utils/device_sync_helper.dart';
import '../../../categories/domain/repositories/category_repository.dart';
import '../../domain/entities/item.dart';
import '../../domain/repositories/item_repository.dart';
import '../bloc/deleted_items_bloc.dart';
import '../bloc/deleted_items_event.dart';
import '../bloc/deleted_items_state.dart';

/// Page displaying soft-deleted items that can be restored.
///
/// Items are shown with their deletion date and days remaining before
/// permanent deletion (90-day retention period).
class DeletedItemsPage extends StatefulWidget {
  const DeletedItemsPage({super.key});

  static String routeName = 'DeletedItemsPage';
  static String routePath = '/deleted-items';

  @override
  State<DeletedItemsPage> createState() => _DeletedItemsPageState();
}

class _DeletedItemsPageState extends State<DeletedItemsPage> {
  late final DeletedItemsBloc _deletedItemsBloc;

  /// Gets the current user ID from AuthBloc
  String _getUserId() {
    final authState = context.read<AuthBloc>().state;
    if (authState is auth.Authenticated) {
      return authState.user.id;
    }
    return '';
  }

  @override
  void initState() {
    super.initState();
    _deletedItemsBloc = sl<DeletedItemsBloc>();

    // Load items using userId from AuthBloc
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final userId = _getUserId();
      if (userId.isNotEmpty) {
        _deletedItemsBloc.add(LoadDeletedItems(userId: userId));
      }
    });
  }

  @override
  void dispose() {
    _deletedItemsBloc.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    final textTheme = Theme.of(context).textTheme;
    final primaryBackground = AppColors.primaryBackground(brightness);
    final primaryText = AppColors.primaryText(brightness);

    return BlocProvider.value(
      value: _deletedItemsBloc,
      child: GestureDetector(
        onTap: () {
          FocusScope.of(context).unfocus();
          FocusManager.instance.primaryFocus?.unfocus();
        },
        child: Scaffold(
          backgroundColor: primaryBackground,
          appBar: AppBar(
            backgroundColor: primaryBackground,
            automaticallyImplyLeading: false,
            leading: IconButton(
              tooltip: 'Back',
              icon: Icon(
                Icons.arrow_back_rounded,
                color: primaryText,
                size: 30.0,
              ),
              onPressed: () => context.pop(),
            ),
            title: Text(
              'Recently Deleted',
              style: textTheme.titleLarge?.copyWith(
                color: primaryText,
              ),
            ),
            centerTitle: true,
            elevation: 0.0,
          ),
          body: SafeArea(
            top: true,
            child: BlocBuilder<BluetoothBloc, BluetoothState>(
              builder: (context, bluetoothState) {
                final isConnected = bluetoothState.isConnected;

                return BlocConsumer<DeletedItemsBloc, DeletedItemsState>(
                  listener: (context, state) {
                    if (state is ItemRestored) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: const Text('Item restored successfully'),
                          backgroundColor: AppColors.success,
                        ),
                      );
                      // Set restored item as active in app
                      context.read<AppUiState>().activeItemId = state.itemId;

                      // Sync with device after restoration
                      if (isConnected) {
                        _syncWithDeviceAfterRestore(
                          bluetoothBloc: context.read<BluetoothBloc>(),
                          restoredItemId: state.itemId,
                        );
                      }
                    }
                    if (state is DeletedItemsError) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(state.message),
                          backgroundColor: AppColors.error,
                        ),
                      );
                    }
                  },
                  builder: (context, state) {
                    if (state is DeletedItemsLoading ||
                        state is DeletedItemsInitial) {
                      return const Center(
                        child: CircularProgressIndicator(),
                      );
                    }

                    final items = _getItemsFromState(state);

                    if (items.isEmpty) {
                      return _buildEmptyState(context);
                    }

                    return _buildItemsList(context, items, state, isConnected);
                  },
                );
              },
            ),
          ),
        ),
      ),
    );
  }

  List<Item> _getItemsFromState(DeletedItemsState state) {
    if (state is DeletedItemsLoaded) return state.items;
    if (state is ItemRestored) return state.remainingItems;
    if (state is ItemRestoring) return state.items;
    return [];
  }

  Widget _buildEmptyState(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    final secondaryText = AppColors.secondaryText(brightness);

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.delete_outline,
              size: 64.0,
              color: secondaryText,
            ),
            const SizedBox(height: 16.0),
            Text(
              'No Deleted Items',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                color: secondaryText,
              ),
            ),
            const SizedBox(height: 8.0),
            Text(
              'Items you delete will appear here for 90 days before being permanently removed.',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: secondaryText,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildItemsList(
    BuildContext context,
    List<Item> items,
    DeletedItemsState state,
    bool isConnected,
  ) {
    return ListView.builder(
      padding: const EdgeInsets.all(16.0),
      itemCount: items.length + 1, // +1 for header
      itemBuilder: (context, index) {
        if (index == 0) {
          return _buildHeader(context, items.length, isConnected);
        }
        final item = items[index - 1];
        final isRestoring =
            state is ItemRestoring && state.itemId == item.id;
        return _buildItemCard(context, item, isRestoring, isConnected);
      },
    );
  }

  Widget _buildHeader(BuildContext context, int count, bool isConnected) {
    final brightness = Theme.of(context).brightness;
    final secondaryText = AppColors.secondaryText(brightness);

    return Padding(
      padding: const EdgeInsets.only(bottom: 16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '$count item${count == 1 ? '' : 's'} will be permanently deleted after 90 days',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: secondaryText,
            ),
          ),
          if (!isConnected) ...[
            const SizedBox(height: 8.0),
            Center(
              child: GestureDetector(
                onTap: () => context.go('/bluetooth'),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16.0,
                    vertical: 8.0,
                  ),
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
                        'Connect to restore items',
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
          ],
        ],
      ),
    );
  }

  Widget _buildItemCard(
    BuildContext context,
    Item item,
    bool isRestoring,
    bool isConnected,
  ) {
    final brightness = Theme.of(context).brightness;
    final primaryText = AppColors.primaryText(brightness);
    final secondaryText = AppColors.secondaryText(brightness);
    final secondaryBackground = AppColors.secondaryBackground(brightness);

    final daysRemaining = _getDaysRemaining(item.deletedAt);
    final deletedDateStr = _formatDeletedDate(item.deletedAt);
    final canRestore = isConnected && !isRestoring;

    return Container(
      margin: const EdgeInsets.only(bottom: 12.0),
      decoration: BoxDecoration(
        color: secondaryBackground,
        borderRadius: BorderRadius.circular(12.0),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    item.name,
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      color: primaryText,
                    ),
                  ),
                  const SizedBox(height: 4.0),
                  Text(
                    'Deleted $deletedDateStr',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: secondaryText,
                    ),
                  ),
                  const SizedBox(height: 2.0),
                  Text(
                    '$daysRemaining days remaining',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: daysRemaining <= 7
                          ? AppColors.error
                          : secondaryText,
                      fontWeight: daysRemaining <= 7
                          ? FontWeight.w600
                          : FontWeight.normal,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12.0),
            SizedBox(
              width: 80.0,
              child: ElevatedButton(
                onPressed: canRestore
                    ? () => _deletedItemsBloc.add(
                          RestoreDeletedItem(
                            itemId: item.id,
                            userId: _getUserId(),
                          ),
                        )
                    : null,
                style: ElevatedButton.styleFrom(
                  backgroundColor:
                      isConnected ? AppColors.primary : Colors.grey,
                  foregroundColor: Colors.white,
                  disabledBackgroundColor: Colors.grey.shade400,
                  disabledForegroundColor: Colors.white70,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12.0,
                    vertical: 8.0,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8.0),
                  ),
                ),
                child: isRestoring
                    ? const SizedBox(
                        width: 16.0,
                        height: 16.0,
                        child: CircularProgressIndicator(
                          strokeWidth: 2.0,
                          color: Colors.white,
                        ),
                      )
                    : Text(
                        'Restore',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  int _getDaysRemaining(DateTime? deletedAt) {
    if (deletedAt == null) return 90;
    final now = DateTime.now();
    final deleteDate = deletedAt.add(const Duration(days: 90));
    final remaining = deleteDate.difference(now).inDays;
    return remaining > 0 ? remaining : 0;
  }

  String _formatDeletedDate(DateTime? deletedAt) {
    if (deletedAt == null) return 'Unknown';
    final now = DateTime.now();
    final diff = now.difference(deletedAt);

    if (diff.inDays == 0) {
      return 'today';
    } else if (diff.inDays == 1) {
      return 'yesterday';
    } else if (diff.inDays < 7) {
      return '${diff.inDays} days ago';
    } else {
      return '${deletedAt.month}/${deletedAt.day}/${deletedAt.year}';
    }
  }

  /// Syncs the device with items from the selected item's category after restore.
  Future<void> _syncWithDeviceAfterRestore({
    required BluetoothBloc bluetoothBloc,
    required String restoredItemId,
  }) async {
    try {
      // Wait for Firestore propagation
      await Future.delayed(const Duration(milliseconds: 300));

      // Get device's selected item
      final deviceSelectedId = bluetoothBloc.state.selectedItemId;

      // If no device selection, skip sync (restore doesn't set selected item)
      if (deviceSelectedId == null || deviceSelectedId.isEmpty || deviceSelectedId == 'none') {
        return;
      }

      // Fetch ALL active items from Firestore
      final itemRepository = sl<ItemRepository>();
      final itemsResult = await itemRepository.getItems(_getUserId());

      final allItems = itemsResult.fold(
        (failure) => <Item>[],
        (items) => items,
      );

      // Only sync if restored item is in the same category as selected item
      final restoredItem = allItems.where((i) => i.id == restoredItemId).firstOrNull;
      final selectedItem = allItems.where((i) => i.id == deviceSelectedId).firstOrNull;
      if (restoredItem == null || selectedItem == null) return;

      final restoredCatId = restoredItem.categoryId ?? '';
      final selectedCatId = selectedItem.categoryId ?? '';
      if (restoredCatId != selectedCatId) return;

      // Fetch category names for device sync
      final categoryRepository = sl<CategoryRepository>();
      final categoriesResult = await categoryRepository.getCategories(_getUserId());
      final categoryNames = categoriesResult.fold(
        (failure) => <String, String>{},
        (categories) => {for (final c in categories) c.id: c.name},
      );

      syncItemsToDevice(
        bluetoothBloc: bluetoothBloc,
        allItems: allItems,
        deviceSelectedId: deviceSelectedId,
        categoryNames: categoryNames,
      );
    } catch (e) {
      // Silently handle sync errors - device sync is best-effort
    }
  }
}
