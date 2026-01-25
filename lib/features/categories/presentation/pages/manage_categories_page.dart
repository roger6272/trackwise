import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../../core/di/injection.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../auth/presentation/bloc/auth_bloc.dart';
import '../../../auth/presentation/bloc/auth_state.dart' as auth;
import '../../domain/entities/category.dart';
import '../bloc/categories_bloc.dart';
import '../bloc/categories_event.dart';
import '../bloc/categories_state.dart';
import '../widgets/category_form_dialog.dart';
import '../widgets/category_tile.dart';

/// Page for managing categories.
///
/// Allows users to create, edit, delete, and reorder categories.
class ManageCategoriesPage extends StatelessWidget {
  const ManageCategoriesPage({super.key});

  static const String routeName = 'ManageCategoriesPage';
  static const String routePath = '/profile/categories';

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<AuthBloc, auth.AuthState>(
      builder: (context, authState) {
        if (authState is! auth.Authenticated) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        return BlocProvider(
          create: (_) => sl<CategoriesBloc>()
            ..add(WatchCategoriesEvent(authState.user.id)),
          child: _ManageCategoriesContent(userId: authState.user.id),
        );
      },
    );
  }
}

class _ManageCategoriesContent extends StatelessWidget {
  final String userId;

  const _ManageCategoriesContent({required this.userId});

  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    final primaryBackground = AppColors.primaryBackground(brightness);
    final primaryText = AppColors.primaryText(brightness);

    return Scaffold(
      backgroundColor: primaryBackground,
      appBar: AppBar(
        backgroundColor: primaryBackground,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios_rounded, color: primaryText),
          onPressed: () => context.pop(),
        ),
        title: Text(
          'Manage Categories',
          style: GoogleFonts.interTight(
            color: primaryText,
            fontSize: 20,
            fontWeight: FontWeight.w600,
          ),
        ),
        centerTitle: true,
        actions: [
          IconButton(
            icon: Icon(Icons.add_rounded, color: primaryText, size: 28),
            onPressed: () => _showCreateDialog(context),
          ),
        ],
      ),
      body: BlocConsumer<CategoriesBloc, CategoriesState>(
        listener: (context, state) {
          if (state is CategoriesError) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(state.message),
                backgroundColor: Colors.red,
              ),
            );
          }
        },
        builder: (context, state) {
          if (state is CategoriesLoading) {
            return const Center(child: CircularProgressIndicator());
          }

          if (state is CategoriesLoaded) {
            return _buildCategoriesList(context, state.categories);
          }

          return _buildEmptyState(context);
        },
      ),
    );
  }

  Widget _buildCategoriesList(BuildContext context, List<Category> categories) {
    final brightness = Theme.of(context).brightness;
    final secondaryText = AppColors.secondaryText(brightness);

    if (categories.isEmpty) {
      return _buildEmptyState(context);
    }

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(16.0),
          child: Text(
            'Drag to reorder categories. Tap to edit.',
            style: GoogleFonts.inter(
              color: secondaryText,
              fontSize: 14,
            ),
          ),
        ),
        Expanded(
          child: ReorderableListView.builder(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            itemCount: categories.length,
            onReorder: (oldIndex, newIndex) {
              context.read<CategoriesBloc>().add(
                    ReorderCategoriesEvent(
                      oldIndex: oldIndex,
                      newIndex: newIndex,
                    ),
                  );
            },
            itemBuilder: (context, index) {
              final category = categories[index];
              return CategoryTile(
                key: ValueKey(category.id),
                category: category,
                index: index,
                onTap: () => _showEditDialog(context, category),
                onDelete: () => _confirmDelete(context, category),
              );
            },
          ),
        ),
        // Uncategorized info at bottom
        _buildUncategorizedInfo(context),
      ],
    );
  }

  Widget _buildUncategorizedInfo(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    final secondaryText = AppColors.secondaryText(brightness);
    final alternate = AppColors.alternate(brightness);

    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: alternate,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Icon(
            Icons.info_outline_rounded,
            color: secondaryText,
            size: 20,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              'Items without a category appear as "Uncategorized" in the filter.',
              style: GoogleFonts.inter(
                color: secondaryText,
                fontSize: 13,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    final primaryText = AppColors.primaryText(brightness);
    final secondaryText = AppColors.secondaryText(brightness);
    final primary = AppColors.primaryAdaptive(brightness);

    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.category_outlined,
            size: 64,
            color: secondaryText.withValues(alpha: 0.5),
          ),
          const SizedBox(height: 16),
          Text(
            'No categories yet',
            style: GoogleFonts.interTight(
              color: primaryText,
              fontSize: 20,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Create categories to organize your items',
            style: GoogleFonts.inter(
              color: secondaryText.withValues(alpha: 0.7),
              fontSize: 14,
            ),
          ),
          const SizedBox(height: 24),
          FilledButton.icon(
            onPressed: () => _showCreateDialog(context),
            style: FilledButton.styleFrom(
              backgroundColor: primary,
              padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 12.0),
            ),
            icon: const Icon(Icons.add_rounded),
            label: const Text('Create Category'),
          ),
        ],
      ),
    );
  }

  void _showCreateDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (dialogContext) => CategoryFormDialog(
        onSave: (name) {
          context.read<CategoriesBloc>().add(
                CreateCategoryEvent(name: name, userId: userId),
              );
        },
      ),
    );
  }

  void _showEditDialog(BuildContext context, Category category) {
    showDialog(
      context: context,
      builder: (dialogContext) => CategoryFormDialog(
        category: category,
        onSave: (name) {
          context.read<CategoriesBloc>().add(
                UpdateCategoryEvent(category.copyWith(name: name)),
              );
        },
      ),
    );
  }

  void _confirmDelete(BuildContext context, Category category) {
    final brightness = Theme.of(context).brightness;
    final primaryText = AppColors.primaryText(brightness);

    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(
          'Delete Category',
          style: GoogleFonts.interTight(
            fontWeight: FontWeight.w600,
            color: primaryText,
          ),
        ),
        content: Text(
          'Are you sure you want to delete "${category.name}"? '
          'Items in this category will become uncategorized.',
          style: GoogleFonts.inter(color: primaryText),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: Text(
              'Cancel',
              style: GoogleFonts.inter(color: Colors.grey),
            ),
          ),
          TextButton(
            onPressed: () {
              Navigator.of(dialogContext).pop();
              context.read<CategoriesBloc>().add(
                    DeleteCategoryEvent(category.id),
                  );
            },
            child: Text(
              'Delete',
              style: GoogleFonts.inter(color: Colors.red),
            ),
          ),
        ],
      ),
    );
  }
}
