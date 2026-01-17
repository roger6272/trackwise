import 'package:flutter/material.dart';
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

class _ItemsListContentState extends State<_ItemsListContent> {
  final scaffoldKey = GlobalKey<ScaffoldState>();

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
              ),
              body: SafeArea(
                top: true,
                child: Column(
                  mainAxisSize: MainAxisSize.max,
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    // Add button at top-right
                    Align(
                      alignment: Alignment.centerRight,
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(16.0, 20.0, 16.0, 0.0),
                        child: _buildAddButton(context, isConnected, primaryBackground),
                      ),
                    ),
                    // Total/Today Toggle
                    Padding(
                      padding: const EdgeInsets.fromLTRB(10.0, 16.0, 10.0, 0.0),
                      child: _buildToggle(context, appUiState, primaryBackground, primaryText, secondaryText, alternate),
                    ),
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
                                return _buildEmptyState(context, primaryText, secondaryText);
                              }

                              // Use ReorderableListView when connected, regular ListView when not
                              if (isConnected) {
                                return ReorderableListView.builder(
                                  padding: const EdgeInsets.only(top: 8.0, bottom: 80.0),
                                  physics: const AlwaysScrollableScrollPhysics(),
                                  buildDefaultDragHandles: false,
                                  itemCount: state.items.length,
                                  onReorder: (oldIndex, newIndex) {
                                    context.read<ItemsBloc>().add(
                                      ReorderItemsEvent(oldIndex: oldIndex, newIndex: newIndex),
                                    );
                                    // Sync to device after reorder
                                    final bluetoothBloc = context.read<BluetoothBloc>();
                                    final itemsBloc = context.read<ItemsBloc>();
                                    // Small delay to let BLoC process the reorder
                                    Future.delayed(const Duration(milliseconds: 100), () {
                                      final itemsState = itemsBloc.state;
                                      if (itemsState is ItemsLoaded) {
                                        bluetoothBloc.add(SendItemsToDevice(itemsState.items));
                                      }
                                    });
                                  },
                                  itemBuilder: (context, index) {
                                    final item = state.items[index];
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
                                return ListView.builder(
                                  padding: const EdgeInsets.only(top: 8.0, bottom: 80.0),
                                  physics: const AlwaysScrollableScrollPhysics(),
                                  itemCount: state.items.length,
                                  itemBuilder: (context, index) {
                                    final item = state.items[index];
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

  Widget _buildAddButton(BuildContext context, bool isConnected, Color primaryBackground) {
    return Container(
      width: 40.0,
      height: 40.0,
      decoration: BoxDecoration(
        color: primaryBackground,
      ),
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
          padding: EdgeInsets.zero,
        ),
        icon: const Icon(
          Icons.add_rounded,
          color: Colors.white,
          size: 25.0,
        ),
      ),
    );
  }

  Widget _buildToggle(BuildContext context, AppUiState appUiState, Color primaryBackground, Color primaryText, Color secondaryText, Color alternate) {
    return Container(
      decoration: BoxDecoration(
        color: primaryBackground,
      ),
      child: Padding(
        padding: const EdgeInsets.only(bottom: 20.0),
        child: Container(
          height: 50.0,
          decoration: BoxDecoration(
            color: alternate,
            borderRadius: BorderRadius.circular(12.0),
            border: Border.all(
              color: alternate,
              width: 1.0,
            ),
          ),
          child: Padding(
            padding: const EdgeInsets.all(4.0),
            child: Row(
              mainAxisSize: MainAxisSize.max,
              mainAxisAlignment: MainAxisAlignment.start,
              children: [
                // Total button
                Expanded(
                  child: InkWell(
                    splashColor: Colors.transparent,
                    focusColor: Colors.transparent,
                    hoverColor: Colors.transparent,
                    highlightColor: Colors.transparent,
                    onTap: () {
                      appUiState.isTodayToggle = false;
                    },
                    child: Container(
                      height: 100.0,
                      decoration: BoxDecoration(
                        color: !appUiState.isTodayToggle ? _primary : alternate,
                        borderRadius: BorderRadius.circular(10.0),
                        border: Border.all(
                          color: !appUiState.isTodayToggle ? _primary : alternate,
                          width: 1.0,
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.max,
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Padding(
                            padding: const EdgeInsets.only(left: 4.0),
                            child: Text(
                              'Total ',
                              style: GoogleFonts.inter(
                                color: !appUiState.isTodayToggle
                                    ? Colors.white
                                    : secondaryText,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                // Today button
                Expanded(
                  child: InkWell(
                    splashColor: Colors.transparent,
                    focusColor: Colors.transparent,
                    hoverColor: Colors.transparent,
                    highlightColor: Colors.transparent,
                    onTap: () {
                      appUiState.isTodayToggle = true;
                    },
                    child: Container(
                      height: 100.0,
                      decoration: BoxDecoration(
                        color: appUiState.isTodayToggle ? _primary : alternate,
                        borderRadius: BorderRadius.circular(10.0),
                        border: Border.all(
                          color: appUiState.isTodayToggle ? _primary : alternate,
                          width: 1.0,
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.max,
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Padding(
                            padding: const EdgeInsets.only(left: 4.0),
                            child: Text(
                              'Today',
                              style: GoogleFonts.inter(
                                color: appUiState.isTodayToggle
                                    ? Colors.white
                                    : secondaryText,
                                fontWeight: FontWeight.bold,
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
    Color activatedColor,
  ) {
    // Use Bluetooth selectedItemId from device, fallback to appUiState
    final activeId = selectedItemId ?? appUiState.activeItemId;
    final isActivated = activeId == item.id && isConnected;
    final displayCount = appUiState.isTodayToggle ? item.todayCount : item.count;

    // Build the drag handle widget
    Widget dragHandle;
    if (isConnected) {
      dragHandle = ReorderableDragStartListener(
        index: index,
        child: Icon(
          Icons.drag_handle,
          color: secondaryText,
          size: 22.0,
        ),
      );
    } else {
      dragHandle = Icon(
        Icons.drag_handle,
        color: secondaryText.withOpacity(0.3),
        size: 22.0,
      );
    }

    return Padding(
      key: ValueKey(item.id),
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Slidable(
        endActionPane: ActionPane(
          motion: const ScrollMotion(),
          extentRatio: 0.85,
          children: [
            SlidableAction(
              label: 'Activate',
              backgroundColor: isConnected ? _activateActionColor : _disabledActionColor,
              icon: Icons.star_sharp,
              autoClose: false,
              onPressed: (slidableContext) async {
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
              label: 'Update',
              backgroundColor: isConnected ? _primary : _disabledActionColor,
              icon: Icons.settings_sharp,
              autoClose: false,
              onPressed: (slidableContext) async {
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
              label: 'Delete',
              backgroundColor: isConnected ? _deleteActionColor : _disabledActionColor,
              icon: Icons.delete_outline_rounded,
              autoClose: false,
              onPressed: (slidableContext) async {
                if (isConnected) {
                  // Capture ALL references BEFORE the async dialog
                  final itemsBloc = context.read<ItemsBloc>();
                  final bluetoothBloc = context.read<BluetoothBloc>();
                  final appUiStateRef = appUiState;

                  final confirmed = await _showDeleteConfirmation(context);
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
        child: Container(
          decoration: BoxDecoration(
            color: isActivated ? activatedColor : alternate,
            borderRadius: BorderRadius.circular(8.0),
          ),
          child: ListTile(
            onTap: () {
              context.pushNamed(
                'ItemDetailPage',
                pathParameters: {'id': item.id},
                queryParameters: {
                  'name': item.name,
                  'count': item.count.toString(),
                  'resetTime': item.lastResetTime.toIso8601String(),
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
            style: GoogleFonts.interTight(
              color: primaryText,
              fontSize: 24.0,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8.0),
          Text(
            'Tap + to create your first item',
            style: GoogleFonts.inter(
              color: secondaryText,
              fontSize: 14.0,
            ),
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

  Future<bool> _showDeleteConfirmation(BuildContext context) async {
    return await showDialog<bool>(
      context: context,
      builder: (alertDialogContext) {
        return AlertDialog(
          content: const Text('Are you sure you want to delete the item?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(alertDialogContext, false),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(alertDialogContext, true),
              child: const Text('Confirm'),
            ),
          ],
        );
      },
    ) ?? false;
  }

  @override
  void dispose() {
    super.dispose();
  }
}
