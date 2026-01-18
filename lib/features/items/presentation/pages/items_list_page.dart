import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_slidable/flutter_slidable.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import '/auth/firebase_auth/auth_util.dart';
import '/auth/firebase_auth/firebase_user_provider.dart' show trackwiseFirebaseUserStream;
import '../../../../core/di/injection.dart';
import '../../../../core/state/app_ui_state.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../bluetooth/domain/usecases/request_device_data_usecase.dart';
import '../../../bluetooth/presentation/bloc/bluetooth_bloc.dart';
import '../../../bluetooth/presentation/bloc/bluetooth_event.dart';
import '../../../bluetooth/presentation/bloc/bluetooth_state.dart';
import '../../domain/entities/item.dart';
import '../../domain/repositories/item_repository.dart';
import '../bloc/items_bloc.dart';
import '../bloc/items_event.dart';
import '../bloc/items_state.dart';
import 'item_form_page.dart';

/// Wrapper that rebuilds when auth state changes
class ItemsListPage extends StatelessWidget {
  const ItemsListPage({super.key});

  static String routeName = 'ItemsListPage';
  static String routePath = '/items';

  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    final primaryBackground = AppColors.primaryBackground(brightness);

    // Use StreamBuilder on trackwiseFirebaseUserStream to ensure we rebuild
    // when auth state changes. This stream also sets currentUser which
    // populates currentUserUid.
    return StreamBuilder(
      stream: trackwiseFirebaseUserStream(),
      builder: (context, snapshot) {
        // Show loading while waiting for auth
        if (snapshot.connectionState == ConnectionState.waiting ||
            !snapshot.hasData ||
            currentUserUid.isEmpty) {
          return Scaffold(
            backgroundColor: primaryBackground,
            body: Center(
              child: CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(AppColors.primary),
              ),
            ),
          );
        }
        return _ItemsListContent(key: ValueKey(currentUserUid));
      },
    );
  }
}

class _ItemsListContent extends StatefulWidget {
  const _ItemsListContent({super.key});

  @override
  State<_ItemsListContent> createState() => _ItemsListContentState();
}

class _ItemsListContentState extends State<_ItemsListContent>
    with SingleTickerProviderStateMixin {
  final scaffoldKey = GlobalKey<ScaffoldState>();
  late final SlidableController _firstItemController;
  bool _hintAnimationTriggered = false;

  @override
  void initState() {
    super.initState();
    _firstItemController = SlidableController(this);
  }

  // Static colors (theme-independent)
  static const Color _primary = Color(0xFF4B39EF);
  static const Color _activatedColorLight = Color(0xFFCAC6FF);
  static const Color _activatedColorDark = Color(0xFF3D3A6D);
  static const Color _activateActionColor = Color(0xFF3C38B5);
  static const Color _deleteActionColor = Color(0xFFD11F43);
  static const Color _disabledActionColor = Color(0xFF565656);

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

    // Auth is guaranteed to be ready by parent StreamBuilder
    return BlocProvider(
      create: (context) => sl<ItemsBloc>()
        ..add(WatchItemsEvent(currentUserUid)),
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
                elevation: 2.0,
                actions: [
                  Padding(
                    padding: const EdgeInsets.only(right: 8.0),
                    child: IconButton(
                      onPressed: () async {
                        if (isConnected) {
                          context.pushNamed(ItemFormPage.routeName);
                        } else {
                          await _showConnectDeviceDialog(context);
                        }
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
                    ),
                  ),
                ],
              ),
              body: SafeArea(
                top: true,
                child: Column(
                  mainAxisSize: MainAxisSize.max,
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    // Total/Today Toggle
                    Padding(
                      padding: const EdgeInsets.fromLTRB(10.0, 20.0, 10.0, 0.0),
                      child: _buildToggle(context, appUiState, primaryBackground, primaryText, secondaryText, alternate),
                    ),
                    // Connection status banner
                    if (!isConnected)
                      _buildDisconnectedBanner(context),
                    // Items List
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(10.0, 0.0, 10.0, 0.0),
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
                              if (state.items.isEmpty) {
                                return _buildEmptyState(context, primaryText, secondaryText, isConnected);
                              }

                              // Use ReorderableListView when connected, regular ListView when not
                              if (isConnected) {
                                return ReorderableListView.builder(
                                  padding: const EdgeInsets.only(top: 8.0, bottom: 80.0),
                                  physics: const AlwaysScrollableScrollPhysics(),
                                  buildDefaultDragHandles: false,
                                  itemCount: state.items.length,
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

                                    itemsBloc.add(
                                      ReorderItemsEvent(oldIndex: oldIndex, newIndex: newIndex),
                                    );
                                    // Sync to device after reorder
                                    // Small delay to let BLoC process the reorder
                                    Future.delayed(const Duration(milliseconds: 100), () {
                                      if (!mounted) return;
                                      final itemsState = itemsBloc.state;
                                      if (itemsState is ItemsLoaded) {
                                        bluetoothBloc.add(SendItemsToDevice(itemsState.items));
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
                                    final item = state.items[index];
                                    // Don't pass controller in ReorderableListView - causes issues during drag
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
                                    );
                                  },
                                );
                              } else {
                                // Trigger swipe hint only in regular ListView (not during reorder)
                                if (!appUiState.hasShownSwipeHint) {
                                  WidgetsBinding.instance.addPostFrameCallback((_) {
                                    _showSwipeHint(appUiState);
                                  });
                                }
                                return RefreshIndicator(
                                  color: _primary,
                                  onRefresh: () async {
                                    context.read<ItemsBloc>().add(WatchItemsEvent(currentUserUid));
                                    // Wait a bit for the stream to emit
                                    await Future.delayed(const Duration(milliseconds: 500));
                                  },
                                  child: ListView.builder(
                                    padding: const EdgeInsets.only(top: 8.0, bottom: 80.0),
                                    physics: const AlwaysScrollableScrollPhysics(),
                                    itemCount: state.items.length,
                                    itemBuilder: (context, index) {
                                      final item = state.items[index];
                                      // Only pass controller for hint animation when not yet shown
                                      final needsController = index == 0 && !appUiState.hasShownSwipeHint;
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
          );
        },
      ),
    );
  }

  Widget _buildToggle(BuildContext context, AppUiState appUiState, Color primaryBackground, Color primaryText, Color secondaryText, Color alternate) {
    final isToday = appUiState.isTodayToggle;
    return Padding(
      padding: const EdgeInsets.only(bottom: 20.0),
      child: Container(
        height: 50.0,
        padding: const EdgeInsets.all(4.0),
        decoration: BoxDecoration(
          color: alternate,
          borderRadius: BorderRadius.circular(12.0),
        ),
        child: Row(
          children: [
            for (final (label, value) in [('Total', false), ('Today', true)])
              Expanded(
                child: GestureDetector(
                  onTap: () => appUiState.isTodayToggle = value,
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      color: isToday == value ? _primary : Colors.transparent,
                      borderRadius: BorderRadius.circular(10.0),
                    ),
                    child: Center(
                      child: Text(
                        label,
                        style: GoogleFonts.inter(
                          color: isToday == value ? Colors.white : secondaryText,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
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
        padding: const EdgeInsets.only(bottom: 12.0),
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
  }) {
    // Use Bluetooth selectedItemId from device, fallback to appUiState
    final activeId = selectedItemId ?? appUiState.activeItemId;
    final isActivated = activeId == item.id && isConnected;
    final displayCount = appUiState.isTodayToggle ? item.todayCount : item.count;

    // Build the drag handle widget with larger touch area
    // Uses ReorderableDelayedDragStartListener for long-press-to-drag pattern
    Widget dragHandle;
    if (isConnected) {
      dragHandle = ReorderableDelayedDragStartListener(
        index: index,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 16.0),
          child: Icon(
            Icons.drag_handle,
            color: secondaryText,
            size: 24.0,
          ),
        ),
      );
    } else {
      dragHandle = Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 16.0),
        child: Icon(
          Icons.drag_handle,
          color: secondaryText.withOpacity(0.3),
          size: 24.0,
        ),
      );
    }

    return Padding(
      key: ValueKey(item.id),
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Slidable(
        controller: controller,
        endActionPane: ActionPane(
          motion: const ScrollMotion(),
          extentRatio: 0.5,
          children: [
            SlidableAction(
              backgroundColor: isConnected ? _activateActionColor : _disabledActionColor,
              icon: Icons.check_circle,
              autoClose: false,
              onPressed: (slidableContext) async {
                HapticFeedback.lightImpact();
                if (isConnected) {
                  appUiState.activeItemId = item.id;
                  // First sync all items to device (ensures new items are known)
                  final itemsState = context.read<ItemsBloc>().state;
                  if (itemsState is ItemsLoaded) {
                    context.read<BluetoothBloc>().add(SendItemsToDevice(itemsState.items));
                  }
                  // Then send selected item to device
                  context.read<BluetoothBloc>().add(SendSelectedItem(item.id));
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

                  final confirmed = await _showDeleteConfirmation(context, item.name);
                  if (confirmed) {
                    if (appUiStateRef.activeItemId == item.id) {
                      appUiStateRef.activeItemId = 'none';
                    }
                    itemsBloc.add(DeleteItemEvent(item.id));
                    // Sync with device after deletion using captured references
                    await _syncWithDeviceAfterDelete(
                      bluetoothBloc: bluetoothBloc,
                      activeItemId: appUiStateRef.activeItemId,
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
        child: Opacity(
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
              child: ListTile(
            onTap: () {
              debugPrint('📊 Navigating to detail - item.goal: ${item.goal}');
              context.pushNamed(
                'ItemDetailPage',
                pathParameters: {'id': item.id},
                queryParameters: {
                  'name': item.name,
                  'count': item.count.toString(),
                  'resetTime': item.lastResetTime.toIso8601String(),
                  'initialCount': item.initialCount.toString(),
                  if (item.goal != null) 'goal': item.goal.toString(),
                },
              );
            },
            title: Text(
              item.name,
              style: GoogleFonts.interTight(
                color: !isConnected ? secondaryText : primaryText,
                fontWeight: FontWeight.w600,
                fontSize: 18.0,
              ),
            ),
            subtitle: Text(
              displayCount.toString(),
              style: GoogleFonts.inter(
                color: secondaryText,
                fontSize: 20.0,
              ),
            ),
            trailing: dragHandle,
            tileColor: Colors.transparent,
            dense: false,
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 15.0,
              vertical: 7.0,
            ),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8.0),
            ),
          ),
            ),
          ),
        ),
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

  /// Syncs the updated items list to the device after deletion.
  /// Takes pre-captured references to avoid deactivated widget errors.
  Future<void> _syncWithDeviceAfterDelete({
    required BluetoothBloc bluetoothBloc,
    required String activeItemId,
  }) async {
    try {
      // Small delay to allow Firestore to propagate the delete
      await Future.delayed(const Duration(milliseconds: 300));

      // Fetch all items from repository
      final itemRepository = sl<ItemRepository>();
      final itemsResult = await itemRepository.getItems(currentUserUid);

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
      bluetoothBloc.add(SendItemsToDevice(items));

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
    if (_hintAnimationTriggered || appUiState.hasShownSwipeHint) return;
    _hintAnimationTriggered = true;

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

  @override
  void dispose() {
    _firstItemController.dispose();
    super.dispose();
  }
}
