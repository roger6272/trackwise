import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_slidable/flutter_slidable.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import '/auth/firebase_auth/auth_util.dart';
import '/auth/firebase_auth/firebase_user_provider.dart' show trackwiseFirebaseUserStream;
import '/flutter_flow/nav/nav.dart' show AppStateNotifier;
import '../../../../core/di/injection.dart';
import '../../../../core/state/app_ui_state.dart';
import '../../../bluetooth/presentation/bloc/bluetooth_bloc.dart';
import '../../../bluetooth/presentation/bloc/bluetooth_event.dart';
import '../../../bluetooth/presentation/bloc/bluetooth_state.dart';
import '../../domain/entities/item.dart';
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
            backgroundColor: const Color(0xFFF1F4F8),
            body: Center(
              child: CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(const Color(0xFF4B39EF)),
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

  // FF Colors
  static const Color _primary = Color(0xFF4B39EF);
  static const Color _alternate = Color(0xFFE0E3E7);
  static const Color _primaryBackground = Color(0xFFF1F4F8);
  static const Color _primaryText = Color(0xFF14181B);
  static const Color _secondaryText = Color(0xFF57636C);
  static const Color _activatedColor = Color(0xFFCAC6FF);
  static const Color _activateActionColor = Color(0xFF3C38B5);
  static const Color _deleteActionColor = Color(0xFFD11F43);
  static const Color _disabledActionColor = Color(0xFF565656);

  @override
  Widget build(BuildContext context) {
    final appUiState = context.watch<AppUiState>();

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
              backgroundColor: _primaryBackground,
              appBar: AppBar(
                backgroundColor: _primaryBackground,
                automaticallyImplyLeading: false,
                title: Text(
                  'Items',
                  style: GoogleFonts.interTight(
                    color: _primaryText,
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
                        child: _buildAddButton(context, isConnected),
                      ),
                    ),
                    // Total/Today Toggle
                    Padding(
                      padding: const EdgeInsets.fromLTRB(10.0, 16.0, 10.0, 0.0),
                      child: _buildToggle(context, appUiState),
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
                                return _buildEmptyState(context);
                              }

                              return ListView.builder(
                                padding: const EdgeInsets.only(top: 8.0, bottom: 80.0),
                                physics: const AlwaysScrollableScrollPhysics(),
                                itemCount: state.items.length,
                                itemBuilder: (context, index) {
                                  final item = state.items[index];
                                  return _buildItemTile(
                                    context,
                                    item,
                                    appUiState,
                                    isConnected,
                                    bluetoothState.selectedItemId,
                                  );
                                },
                              );
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

  Widget _buildAddButton(BuildContext context, bool isConnected) {
    return Container(
      width: 40.0,
      height: 40.0,
      decoration: BoxDecoration(
        color: _primaryBackground,
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

  Widget _buildToggle(BuildContext context, AppUiState appUiState) {
    return Container(
      decoration: const BoxDecoration(
        color: _primaryBackground,
      ),
      child: Padding(
        padding: const EdgeInsets.only(bottom: 20.0),
        child: Container(
          height: 50.0,
          decoration: BoxDecoration(
            color: _alternate,
            borderRadius: BorderRadius.circular(12.0),
            border: Border.all(
              color: _alternate,
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
                        color: !appUiState.isTodayToggle ? _primary : _alternate,
                        borderRadius: BorderRadius.circular(10.0),
                        border: Border.all(
                          color: !appUiState.isTodayToggle ? _primary : _alternate,
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
                                    ? _primaryText
                                    : _secondaryText,
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
                        color: appUiState.isTodayToggle ? _primary : _alternate,
                        borderRadius: BorderRadius.circular(10.0),
                        border: Border.all(
                          color: appUiState.isTodayToggle ? _primary : _alternate,
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
                                    ? _primaryText
                                    : _secondaryText,
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
    AppUiState appUiState,
    bool isConnected,
    String? selectedItemId,
  ) {
    // Use Bluetooth selectedItemId from device, fallback to appUiState
    final activeId = selectedItemId ?? appUiState.activeItemId;
    final isActivated = activeId == item.id && isConnected;
    final displayCount = appUiState.isTodayToggle ? item.todayCount : item.count;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: InkWell(
        splashColor: Colors.transparent,
        focusColor: Colors.transparent,
        hoverColor: Colors.transparent,
        highlightColor: Colors.transparent,
        onTap: () {
          context.pushNamed(
            'ItemDetailPage',
            pathParameters: {'id': item.id},
            queryParameters: {'name': item.name},
          );
        },
        child: Slidable(
          endActionPane: ActionPane(
            motion: const ScrollMotion(),
            extentRatio: 0.85,
            children: [
              SlidableAction(
                label: 'Activate',
                backgroundColor: isConnected ? _activateActionColor : _disabledActionColor,
                icon: Icons.star_sharp,
                onPressed: (_) async {
                  if (isConnected) {
                    appUiState.activeItemId = item.id;
                    // Send selected item to device
                    context.read<BluetoothBloc>().add(SendSelectedItem(item.id));
                  } else {
                    await _showConnectDeviceDialog(context);
                  }
                },
              ),
              SlidableAction(
                label: 'Update',
                backgroundColor: isConnected ? _primary : _disabledActionColor,
                icon: Icons.settings_sharp,
                onPressed: (_) async {
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
                onPressed: (_) async {
                  if (isConnected) {
                    final confirmed = await _showDeleteConfirmation(context);
                    if (confirmed && context.mounted) {
                      if (appUiState.activeItemId == item.id) {
                        appUiState.activeItemId = 'none';
                      }
                      context.read<ItemsBloc>().add(DeleteItemEvent(item.id));
                      // TODO: Send updated item list to device
                    }
                  } else {
                    await _showConnectDeviceDialog(context);
                  }
                },
              ),
            ],
          ),
          child: Material(
            color: Colors.transparent,
            child: ListTile(
              title: Text(
                item.name,
                style: GoogleFonts.interTight(
                  color: !isConnected ? const Color(0xFF787878) : Colors.black,
                  fontWeight: FontWeight.w600,
                  fontSize: 18.0,
                ),
              ),
              subtitle: Text(
                displayCount.toString(),
                style: GoogleFonts.inter(
                  color: _secondaryText,
                  fontSize: 20.0,
                ),
              ),
              trailing: Icon(
                Icons.drag_handle,
                color: _secondaryText,
                size: 22.0,
              ),
              tileColor: isActivated ? _activatedColor : _alternate,
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
    );
  }

  Widget _buildEmptyState(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.inbox_outlined,
            size: 72.0,
            color: _secondaryText,
          ),
          const SizedBox(height: 16.0),
          Text(
            'No items yet',
            style: GoogleFonts.interTight(
              color: _primaryText,
              fontSize: 24.0,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8.0),
          Text(
            'Tap + to create your first item',
            style: GoogleFonts.inter(
              color: _secondaryText,
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
