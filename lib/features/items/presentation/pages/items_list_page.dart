import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '/auth/firebase_auth/auth_util.dart';
import '../../../../core/di/injection.dart';
import '../../../../core/theme/app_colors.dart';
import '../bloc/items_bloc.dart';
import '../bloc/items_event.dart';
import '../bloc/items_state.dart';
import '../widgets/item_card.dart';
import 'item_form_page.dart';

class ItemsListPage extends StatefulWidget {
  const ItemsListPage({super.key});

  static String routeName = 'ItemsListPage';
  static String routePath = '/items';

  @override
  State<ItemsListPage> createState() => _ItemsListPageState();
}

class _ItemsListPageState extends State<ItemsListPage> {
  final scaffoldKey = GlobalKey<ScaffoldState>();

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (context) => sl<ItemsBloc>()
        ..add(WatchItemsEvent(currentUserUid)),
      child: GestureDetector(
        onTap: () {
          FocusScope.of(context).unfocus();
          FocusManager.instance.primaryFocus?.unfocus();
        },
        child: Scaffold(
          key: scaffoldKey,
          backgroundColor: Theme.of(context).scaffoldBackgroundColor,
          appBar: AppBar(
            backgroundColor: Theme.of(context).scaffoldBackgroundColor,
            automaticallyImplyLeading: false,
            title: Text(
              'My Items',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            centerTitle: true,
            elevation: 2.0,
          ),
          floatingActionButton: FloatingActionButton(
            onPressed: () {
              context.pushNamed(ItemFormPage.routeName);
            },
            backgroundColor: AppColors.primary,
            child: Icon(
              Icons.add,
              color: Colors.white,
              size: 24.0,
            ),
          ),
          body: SafeArea(
            top: true,
            child: BlocConsumer<ItemsBloc, ItemsState>(
              listener: (context, state) {
                if (state is ItemsError) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(state.message),
                      backgroundColor: AppColors.error,
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
                        valueColor: AlwaysStoppedAnimation<Color>(
                          AppColors.primary,
                        ),
                      ),
                    ),
                  );
                }

                if (state is ItemsLoaded) {
                  if (state.items.isEmpty) {
                    return Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.inbox_outlined,
                            size: 72.0,
                            color: Theme.of(context).colorScheme.onSurfaceVariant,
                          ),
                          SizedBox(height: 16.0),
                          Text(
                            'No items yet',
                            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                              fontFamily: 'Inter Tight',
                              letterSpacing: 0.0,
                            ),
                          ),
                          SizedBox(height: 8.0),
                          Text(
                            'Tap + to create your first item',
                            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                              fontFamily: 'Inter',
                              color: Theme.of(context).colorScheme.onSurfaceVariant,
                              letterSpacing: 0.0,
                            ),
                          ),
                        ],
                      ),
                    );
                  }

                  return RefreshIndicator(
                    onRefresh: () async {
                      context.read<ItemsBloc>().add(
                        WatchItemsEvent(currentUserUid),
                      );
                    },
                    child: ListView.builder(
                      padding: EdgeInsets.all(16.0),
                      itemCount: state.items.length,
                      itemBuilder: (context, index) {
                        final item = state.items[index];
                        return ItemCard(
                          item: item,
                          onUpdate: () {
                            context.pushNamed(
                              ItemFormPage.routeName,
                              extra: item,
                            );
                          },
                          onDelete: () async {
                            final confirmed = await _showDeleteConfirmation(context);
                            if (confirmed) {
                              context.read<ItemsBloc>().add(
                                DeleteItemEvent(item.id),
                              );
                            }
                          },
                          onIncrement: () {
                            context.read<ItemsBloc>().add(
                              IncrementItemEvent(itemId: item.id),
                            );
                          },
                        );
                      },
                    ),
                  );
                }

                return SizedBox();
              },
            ),
          ),
        ),
      ),
    );
  }

  Future<bool> _showDeleteConfirmation(BuildContext context) async {
    return await showDialog<bool>(
      context: context,
      builder: (alertDialogContext) {
        return AlertDialog(
          title: Text('Delete Item'),
          content: Text('Are you sure you want to delete this item? This action cannot be undone.'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(alertDialogContext, false),
              child: Text('Cancel'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(alertDialogContext, true),
              child: Text(
                'Delete',
                style: TextStyle(color: AppColors.error),
              ),
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
