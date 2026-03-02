import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/di/injection.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/utils/app_util.dart';
import '../../../auth/presentation/bloc/auth_bloc.dart';
import '../../../auth/presentation/bloc/auth_state.dart';
import '../../../bluetooth/presentation/bloc/bluetooth_bloc.dart';
import '../../../bluetooth/presentation/bloc/bluetooth_state.dart';
import '../../../categories/domain/entities/category.dart';
import '../../../categories/domain/repositories/category_repository.dart';
import '../../../items/domain/entities/item.dart';
import '../../../items/domain/repositories/item_repository.dart';
import '../../domain/entities/csv_export_config.dart';
import '../bloc/export_bloc.dart';
import '../bloc/export_event.dart';
import '../bloc/export_state.dart';

class ExportPage extends StatefulWidget {
  ExportPage({super.key, this.preselectedItemIds});

  final Set<String>? preselectedItemIds;

  static String routeName = 'ExportPage';
  static String routePath = '/export';

  @override
  State<ExportPage> createState() => _ExportPageState();
}

class _ExportPageState extends State<ExportPage> {
  final scaffoldKey = GlobalKey<ScaffoldState>();
  final formKey = GlobalKey<FormState>();

  late TextEditingController emailController;
  late FocusNode emailFocusNode;

  DateTime _startDate = DateTime.now().subtract(const Duration(days: 30));
  DateTime _endDate = DateTime.now();
  ExportAggregationLevel _aggregationLevel = ExportAggregationLevel.daily;
  bool _latestCycleOnly = false;
  List<Item> _items = [];
  List<Category> _categories = [];
  Set<String> _selectedItemIds = {};
  bool _itemsLoading = true;

  // Theme-aware color getters
  Color _cardBackground(BuildContext context) =>
      AppColors.secondaryBackground(Theme.of(context).brightness);
  Color _inputBackground(BuildContext context) =>
      AppColors.alternate(Theme.of(context).brightness);
  Color _inputText(BuildContext context) =>
      AppColors.primaryText(Theme.of(context).brightness);
  Color _inputHint(BuildContext context) =>
      AppColors.secondaryText(Theme.of(context).brightness);

  int get _dateRangeDays => _endDate.difference(_startDate).inDays + 1;

  bool get _allSelected => _selectedItemIds.length == _items.length;

  @override
  void initState() {
    super.initState();
    emailController = TextEditingController();
    emailFocusNode = FocusNode();
    // Update preview card when email changes
    emailController.addListener(_onEmailChanged);
    _loadItems();
  }

  Future<void> _loadItems() async {
    final authState = context.read<AuthBloc>().state;
    if (authState is! Authenticated) return;

    final userId = authState.user.id;
    final itemsResult = await sl<ItemRepository>().getItems(userId);
    final categoriesResult = await sl<CategoryRepository>().getCategories(userId);

    if (!mounted) return;

    setState(() {
      itemsResult.fold((_) {}, (items) => _items = items);
      categoriesResult.fold((_) {}, (categories) => _categories = categories);
      _selectedItemIds = widget.preselectedItemIds ?? _items.map((i) => i.id).toSet();
      _itemsLoading = false;
    });
  }

  void _onEmailChanged() {
    setState(() {});
  }

  @override
  void dispose() {
    emailController.removeListener(_onEmailChanged);
    emailController.dispose();
    emailFocusNode.dispose();
    super.dispose();
  }

  /// Format date as "Jan 21, 2025"
  String _formatDateFriendly(DateTime date) {
    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
    ];
    return '${months[date.month - 1]} ${date.day}, ${date.year}';
  }

  /// Format date as "Jan 21" (short form for preview)
  String _formatDateShort(DateTime date) {
    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
    ];
    return '${months[date.month - 1]} ${date.day}';
  }

  String _getAggregationLabel(ExportAggregationLevel level) {
    switch (level) {
      case ExportAggregationLevel.raw:
        return 'Raw';
      case ExportAggregationLevel.daily:
        return 'By Day';
      case ExportAggregationLevel.byCycle:
        return 'By Cycle';
    }
  }

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (context) => sl<ExportBloc>(),
      child: BlocConsumer<ExportBloc, ExportState>(
        listener: (context, state) {
          if (state is ExportSuccess) {
            showSuccessSnackBar(context, 'Export sent! Check your email.');
            context.pop();
          }
          if (state is ExportError) {
            showErrorSnackBar(context, state.message);
          }
        },
        builder: (context, state) {
          final isLoading = state is ExportInProgress;

          return GestureDetector(
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
                leading: IconButton(
                  tooltip: 'Back',
                  icon: Icon(
                    Icons.arrow_back_rounded,
                    color: Theme.of(context).colorScheme.onSurface,
                    size: 30.0,
                  ),
                  onPressed: () => context.pop(),
                ),
                title: Text(
                  'Export Data',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontFamily: 'Inter Tight',
                    fontSize: 20.0,
                    letterSpacing: 0.0,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                centerTitle: true,
                elevation: 0.0,
              ),
              body: SafeArea(
                top: true,
                child: Padding(
                  padding: const EdgeInsets.all(20.0),
                  child: SingleChildScrollView(
                    child: Form(
                      key: formKey,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Aggregation Level Section
                          _buildSectionHeader(
                            context: context,
                            icon: Icons.layers_rounded,
                            title: 'Aggregation Level',
                          ),
                          const SizedBox(height: 12.0),
                          Row(
                            children: ExportAggregationLevel.values.map((level) {
                              final selected = _aggregationLevel == level;
                              return Expanded(
                                child: Padding(
                                  padding: EdgeInsets.only(
                                    right: level != ExportAggregationLevel.values.last ? 8.0 : 0,
                                  ),
                                  child: ChoiceChip(
                                    label: SizedBox(
                                      width: double.infinity,
                                      child: Text(_getAggregationLabel(level), textAlign: TextAlign.center),
                                    ),
                                    selected: selected,
                                    onSelected: (_) => setState(() {
                                      _aggregationLevel = level;
                                      // Reset cycle toggle when switching away from byCycle
                                      if (level != ExportAggregationLevel.byCycle) {
                                        _latestCycleOnly = false;
                                      }
                                    }),
                                    selectedColor: AppColors.primaryAdaptive(Theme.of(context).brightness),
                                    backgroundColor: _inputBackground(context),
                                    labelStyle: TextStyle(
                                      fontFamily: 'Inter',
                                      fontSize: 13.0,
                                      fontWeight: FontWeight.w500,
                                      letterSpacing: 0.0,
                                      color: selected ? Colors.white : _inputText(context),
                                    ),
                                    showCheckmark: false,
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(20.0),
                                      side: BorderSide(
                                        color: selected
                                            ? AppColors.primaryAdaptive(Theme.of(context).brightness)
                                            : _inputBackground(context),
                                      ),
                                    ),
                                    labelPadding: EdgeInsets.zero,
                                    padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 6.0),
                                  ),
                                ),
                              );
                            }).toList(),
                          ),
                          const SizedBox(height: 8.0),
                          Text(
                            _getAggregationDescription(_aggregationLevel),
                            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              fontFamily: 'Inter',
                              color: Theme.of(context).colorScheme.onSurfaceVariant,
                              letterSpacing: 0.0,
                            ),
                          ),

                          // Conditional section below aggregation
                          if (_aggregationLevel == ExportAggregationLevel.byCycle) ...[
                            // Cycle Scope toggle
                            _buildSectionDivider(context),
                            _buildSectionHeader(
                              context: context,
                              icon: Icons.refresh_rounded,
                              title: 'Cycle Scope',
                            ),
                            const SizedBox(height: 12.0),
                            Row(
                              children: [
                                _buildCycleScopeChip(context, label: 'All Cycles', selected: !_latestCycleOnly, onSelected: () => setState(() => _latestCycleOnly = false)),
                                const SizedBox(width: 8.0),
                                _buildCycleScopeChip(context, label: 'Latest Cycle', selected: _latestCycleOnly, onSelected: () => setState(() => _latestCycleOnly = true)),
                              ],
                            ),
                            const SizedBox(height: 8.0),
                            Text(
                              _latestCycleOnly
                                  ? 'Export only data from the most recent reset cycle.'
                                  : 'Export data from all reset cycles.',
                              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                fontFamily: 'Inter',
                                color: Theme.of(context).colorScheme.onSurfaceVariant,
                                letterSpacing: 0.0,
                              ),
                            ),
                          ] else ...[
                            // Date Range Section for raw / daily
                            _buildSectionDivider(context),
                            _buildSectionHeader(
                              context: context,
                              icon: Icons.date_range_rounded,
                              title: 'Date Range',
                            ),
                            const SizedBox(height: 12.0),
                            _buildDateRangeSelector(context),
                            const SizedBox(height: 8.0),
                            Center(
                              child: Text(
                                '$_dateRangeDays ${_dateRangeDays == 1 ? 'day' : 'days'} selected',
                                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                  fontFamily: 'Inter',
                                  color: AppColors.primary,
                                  fontWeight: FontWeight.w500,
                                  letterSpacing: 0.0,
                                ),
                              ),
                            ),
                          ],

                          _buildSectionDivider(context),

                          // Items Section
                          _buildSectionHeader(
                            context: context,
                            icon: Icons.inventory_2_rounded,
                            title: 'Items',
                          ),
                          const SizedBox(height: 12.0),
                          _buildItemSelector(context),

                          _buildSectionDivider(context),

                          // Email Section
                          _buildSectionHeader(
                            context: context,
                            icon: Icons.email_rounded,
                            title: 'Email Address',
                          ),
                          const SizedBox(height: 12.0),
                          TextFormField(
                            controller: emailController,
                            focusNode: emailFocusNode,
                            keyboardType: TextInputType.emailAddress,
                            textInputAction: TextInputAction.done,
                            decoration: InputDecoration(
                              hintText: 'Enter your email address...',
                              hintStyle: TextStyle(
                                fontFamily: 'Inter',
                                color: _inputHint(context),
                                fontSize: 16.0,
                                letterSpacing: 0.0,
                              ),
                              prefixIcon: Icon(
                                Icons.alternate_email_rounded,
                                color: _inputHint(context),
                                size: 20.0,
                              ),
                              enabledBorder: OutlineInputBorder(
                                borderSide: BorderSide(
                                  color: _inputBackground(context),
                                  width: 1.0,
                                ),
                                borderRadius: BorderRadius.circular(12.0),
                              ),
                              focusedBorder: OutlineInputBorder(
                                borderSide: BorderSide(
                                  color: AppColors.primaryAdaptive(Theme.of(context).brightness),
                                  width: 2.0,
                                ),
                                borderRadius: BorderRadius.circular(12.0),
                              ),
                              errorBorder: OutlineInputBorder(
                                borderSide: const BorderSide(
                                  color: AppColors.error,
                                  width: 1.0,
                                ),
                                borderRadius: BorderRadius.circular(12.0),
                              ),
                              focusedErrorBorder: OutlineInputBorder(
                                borderSide: const BorderSide(
                                  color: AppColors.error,
                                  width: 2.0,
                                ),
                                borderRadius: BorderRadius.circular(12.0),
                              ),
                              filled: true,
                              fillColor: _cardBackground(context),
                              contentPadding: const EdgeInsets.symmetric(
                                horizontal: 16.0,
                                vertical: 16.0,
                              ),
                            ),
                            style: TextStyle(
                              fontFamily: 'Inter',
                              fontSize: 16.0,
                              letterSpacing: 0.0,
                              color: _inputText(context),
                            ),
                            validator: _validateEmail,
                          ),
                          const SizedBox(height: 8.0),
                          Text(
                            'The CSV file will be sent to this email address.',
                            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              fontFamily: 'Inter',
                              color: Theme.of(context).colorScheme.onSurfaceVariant,
                              letterSpacing: 0.0,
                            ),
                          ),

                          _buildSectionDivider(context),

                          // Export Preview Card
                          _buildPreviewCard(context),

                          const SizedBox(height: 32.0),

                          // Export Button
                          Builder(
                            builder: (blocContext) => SizedBox(
                              width: double.infinity,
                              height: 56.0,
                              child: ElevatedButton.icon(
                                onPressed: isLoading || _selectedItemIds.isEmpty
                                    ? null
                                    : () => _handleExport(blocContext),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: AppColors.primaryAdaptive(Theme.of(context).brightness),
                                  foregroundColor: Colors.white,
                                  disabledBackgroundColor: _inputBackground(context),
                                  disabledForegroundColor: _inputHint(context),
                                  elevation: 2,
                                  shadowColor: AppColors.primaryAdaptive(Theme.of(context).brightness).withAlpha(77),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12.0),
                                  ),
                                ),
                                icon: isLoading
                                    ? SizedBox(
                                        width: 20.0,
                                        height: 20.0,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2.0,
                                          color: _inputHint(context),
                                        ),
                                      )
                                    : const Icon(Icons.send_rounded, size: 20.0),
                                label: Text(
                                  isLoading ? 'Exporting...' : 'Export to Email',
                                  style: const TextStyle(
                                    fontFamily: 'Inter Tight',
                                    fontSize: 16.0,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                            ),
                          ),
                          if (isLoading) ...[
                            const SizedBox(height: 16.0),
                            Center(
                              child: Text(
                                'Generating and sending export...',
                                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                  fontFamily: 'Inter',
                                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                                  letterSpacing: 0.0,
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
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

  Widget _buildCycleScopeChip(BuildContext context, {required String label, required bool selected, required VoidCallback onSelected}) {
    return Expanded(
      child: ChoiceChip(
        label: SizedBox(
          width: double.infinity,
          child: Text(label, textAlign: TextAlign.center),
        ),
        selected: selected,
        onSelected: (_) => onSelected(),
        selectedColor: AppColors.primaryAdaptive(Theme.of(context).brightness),
        backgroundColor: _inputBackground(context),
        labelStyle: TextStyle(
          fontFamily: 'Inter',
          fontSize: 13.0,
          fontWeight: FontWeight.w500,
          letterSpacing: 0.0,
          color: selected ? Colors.white : _inputText(context),
        ),
        showCheckmark: false,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20.0),
          side: BorderSide(
            color: selected
                ? AppColors.primaryAdaptive(Theme.of(context).brightness)
                : _inputBackground(context),
          ),
        ),
        labelPadding: EdgeInsets.zero,
        padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 6.0),
      ),
    );
  }

  /// Preview card showing export summary
  Widget _buildPreviewCard(BuildContext context) {
    final hasEmail = emailController.text.isNotEmpty;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16.0),
      decoration: BoxDecoration(
        color: _cardBackground(context),
        borderRadius: BorderRadius.circular(12.0),
        border: Border.all(
          color: _inputBackground(context),
          width: 1.0,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8.0),
                decoration: BoxDecoration(
                  color: AppColors.primary.withAlpha(26),
                  borderRadius: BorderRadius.circular(8.0),
                ),
                child: const Icon(
                  Icons.summarize_rounded,
                  size: 20.0,
                  color: AppColors.primary,
                ),
              ),
              const SizedBox(width: 12.0),
              Text(
                'Export Preview',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontFamily: 'Inter Tight',
                  fontWeight: FontWeight.w600,
                  letterSpacing: 0.0,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16.0),
          if (_aggregationLevel == ExportAggregationLevel.byCycle)
            _buildPreviewRow(
              context: context,
              icon: Icons.refresh_rounded,
              label: _latestCycleOnly ? 'Latest Cycle' : 'All Cycles',
              subtitle: null,
            )
          else
            _buildPreviewRow(
              context: context,
              icon: Icons.calendar_today_rounded,
              label: '${_formatDateShort(_startDate)} → ${_formatDateShort(_endDate)}',
              subtitle: '$_dateRangeDays days',
            ),
          const SizedBox(height: 10.0),
          _buildPreviewRow(
            context: context,
            icon: Icons.layers_rounded,
            label: '${_getAggregationLabel(_aggregationLevel)} aggregation',
            subtitle: null,
          ),
          const SizedBox(height: 10.0),
          _buildPreviewRow(
            context: context,
            icon: Icons.inventory_2_rounded,
            label: _allSelected ? 'All items' : '${_selectedItemIds.length} of ${_items.length} items',
            subtitle: null,
          ),
          if (hasEmail) ...[
            const SizedBox(height: 10.0),
            _buildPreviewRow(
              context: context,
              icon: Icons.email_rounded,
              label: emailController.text,
              subtitle: null,
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildPreviewRow({
    required BuildContext context,
    required IconData icon,
    required String label,
    required String? subtitle,
  }) {
    return Row(
      children: [
        Icon(
          icon,
          size: 16.0,
          color: _inputHint(context),
        ),
        const SizedBox(width: 10.0),
        Expanded(
          child: Row(
            children: [
              Text(
                label,
                style: TextStyle(
                  fontFamily: 'Inter',
                  fontSize: 14.0,
                  color: _inputText(context),
                  letterSpacing: 0.0,
                ),
              ),
              if (subtitle != null) ...[
                const SizedBox(width: 8.0),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 2.0),
                  decoration: BoxDecoration(
                    color: _inputBackground(context),
                    borderRadius: BorderRadius.circular(4.0),
                  ),
                  child: Text(
                    subtitle,
                    style: TextStyle(
                      fontFamily: 'Inter',
                      fontSize: 12.0,
                      color: _inputHint(context),
                      letterSpacing: 0.0,
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }

  /// Item selector — dropdown-style field that opens a searchable bottom sheet
  Widget _buildItemSelector(BuildContext context) {
    if (_itemsLoading) {
      return const Center(child: Padding(
        padding: EdgeInsets.all(16.0),
        child: CircularProgressIndicator(),
      ));
    }

    if (_items.isEmpty) {
      return Text(
        'No items found.',
        style: Theme.of(context).textTheme.bodySmall?.copyWith(
          fontFamily: 'Inter',
          color: Theme.of(context).colorScheme.onSurfaceVariant,
          letterSpacing: 0.0,
        ),
      );
    }

    final String label;
    if (_allSelected) {
      label = 'All items';
    } else if (_selectedItemIds.length == 1) {
      final name = _items.where((i) => i.id == _selectedItemIds.first).firstOrNull?.name;
      label = name ?? '1 item';
    } else {
      label = '${_selectedItemIds.length} of ${_items.length} items';
    }

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => _showItemPickerSheet(context),
        borderRadius: BorderRadius.circular(12.0),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 14.0),
          decoration: BoxDecoration(
            color: _cardBackground(context),
            borderRadius: BorderRadius.circular(12.0),
            border: Border.all(
              color: _inputBackground(context),
              width: 1.0,
            ),
          ),
          child: Row(
            children: [
              Icon(
                Icons.checklist_rounded,
                size: 20.0,
                color: _inputHint(context),
              ),
              const SizedBox(width: 12.0),
              Expanded(
                child: Text(
                  label,
                  style: TextStyle(
                    fontFamily: 'Inter',
                    fontSize: 16.0,
                    letterSpacing: 0.0,
                    color: _inputText(context),
                  ),
                ),
              ),
              Icon(
                Icons.arrow_drop_down_rounded,
                color: _inputHint(context),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showItemPickerSheet(BuildContext context) {
    // Build category name lookup
    final Map<String, String> categoryNames = {
      for (final cat in _categories) cat.id: cat.name,
    };

    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) => _ItemPickerSheet(
        items: _items,
        categoryNames: categoryNames,
        selectedIds: _selectedItemIds,
        cardBackground: _cardBackground(context),
        inputBackground: _inputBackground(context),
        inputText: _inputText(context),
        inputHint: _inputHint(context),
        brightness: Theme.of(context).brightness,
        onChanged: (ids) => setState(() => _selectedItemIds = ids),
      ),
    );
  }

  /// Date range selector with visual connector
  Widget _buildDateRangeSelector(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: _buildDateTile(
            context: context,
            label: 'Start',
            date: _startDate,
            onTap: () => _selectStartDate(context),
          ),
        ),
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: 8.0),
          child: Icon(
            Icons.arrow_forward_rounded,
            color: AppColors.primary,
            size: 24.0,
          ),
        ),
        Expanded(
          child: _buildDateTile(
            context: context,
            label: 'End',
            date: _endDate,
            onTap: () => _selectEndDate(context),
          ),
        ),
      ],
    );
  }

  Widget _buildSectionDivider(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 20.0),
      child: Divider(
        height: 1,
        thickness: 1,
        color: _inputBackground(context),
      ),
    );
  }

  Widget _buildSectionHeader({
    required BuildContext context,
    required IconData icon,
    required String title,
  }) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(6.0),
          decoration: BoxDecoration(
            color: AppColors.primaryAdaptive(Theme.of(context).brightness).withAlpha(26),
            borderRadius: BorderRadius.circular(6.0),
          ),
          child: Icon(
            icon,
            size: 18.0,
            color: AppColors.primaryAdaptive(Theme.of(context).brightness),
          ),
        ),
        const SizedBox(width: 10.0),
        Text(
          title,
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
            fontFamily: 'Inter Tight',
            fontSize: 16.0,
            letterSpacing: 0.0,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }

  Widget _buildDateTile({
    required BuildContext context,
    required String label,
    required DateTime date,
    required VoidCallback onTap,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12.0),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 14.0),
          decoration: BoxDecoration(
            color: _cardBackground(context),
            borderRadius: BorderRadius.circular(12.0),
            border: Border.all(
              color: _inputBackground(context),
              width: 1.0,
            ),
          ),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      label,
                      style: TextStyle(
                        fontFamily: 'Inter',
                        color: _inputHint(context),
                        fontSize: 11.0,
                        fontWeight: FontWeight.w500,
                        letterSpacing: 0.5,
                      ),
                    ),
                    const SizedBox(height: 2.0),
                    Text(
                      _formatDateFriendly(date),
                      style: TextStyle(
                        fontFamily: 'Inter',
                        fontSize: 14.0,
                        fontWeight: FontWeight.w500,
                        letterSpacing: 0.0,
                        color: _inputText(context),
                      ),
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.calendar_today_rounded,
                color: _inputHint(context),
                size: 18.0,
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _getAggregationDescription(ExportAggregationLevel level) {
    switch (level) {
      case ExportAggregationLevel.raw:
        return 'Export each individual event with timestamp.';
      case ExportAggregationLevel.daily:
        return 'Group button presses by day. Resets and initial counts are not included.';
      case ExportAggregationLevel.byCycle:
        return 'Total button presses per reset cycle. Initial counts are not included.';
    }
  }

  Future<void> _selectStartDate(BuildContext context) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _startDate,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
    );
    if (picked != null && picked != _startDate) {
      setState(() {
        _startDate = picked;
        // Ensure end date is not before start date
        if (_endDate.isBefore(_startDate)) {
          _endDate = _startDate;
        }
      });
    }
  }

  Future<void> _selectEndDate(BuildContext context) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _endDate,
      firstDate: _startDate,
      lastDate: DateTime.now(),
    );
    if (picked != null && picked != _endDate) {
      setState(() => _endDate = picked);
    }
  }

  String? _validateEmail(String? value) {
    if (value == null || value.isEmpty) {
      return 'Email is required';
    }
    // Email validation - check basic format, let email service validate fully
    // Supports longer TLDs (.business, .international) and avoids false negatives
    final emailRegex = RegExp(
      r'^[a-zA-Z0-9.!#$%&*+/=?^_`{|}~-]+@[a-zA-Z0-9](?:[a-zA-Z0-9-]{0,61}[a-zA-Z0-9])?(?:\.[a-zA-Z0-9](?:[a-zA-Z0-9-]{0,61}[a-zA-Z0-9])?)+$',
    );
    if (!emailRegex.hasMatch(value)) {
      return 'Please enter a valid email address';
    }
    return null;
  }

  void _handleExport(BuildContext blocContext) {
    if (!formKey.currentState!.validate()) {
      return;
    }
    if (_selectedItemIds.isEmpty) return;

    final isByCycle = _aggregationLevel == ExportAggregationLevel.byCycle;
    // Build device name map from BluetoothState for raw exports
    final isRaw = _aggregationLevel == ExportAggregationLevel.raw;
    Map<String, String> deviceNameMap = {};
    if (isRaw) {
      final btState = context.read<BluetoothBloc>().state;
      for (final pd in btState.pairedDevices) {
        deviceNameMap[pd.deviceInstanceId] = pd.deviceName;
      }
    }
    blocContext.read<ExportBloc>().add(ExportCSV(
      startDate: isByCycle ? DateTime(2020) : _startDate,
      endDate: isByCycle ? DateTime.now() : _endDate,
      aggregationLevel: _aggregationLevel,
      latestCycleOnly: _latestCycleOnly,
      email: emailController.text.trim(),
      itemIds: _allSelected ? null : _selectedItemIds.toList(),
      includeDeviceColumn: isRaw,
      deviceNameMap: deviceNameMap,
    ));
  }
}

/// Bottom sheet with search and multi-select checkboxes for item picking.
class _ItemPickerSheet extends StatefulWidget {
  final List<Item> items;
  final Map<String, String> categoryNames;
  final Set<String> selectedIds;
  final Color cardBackground;
  final Color inputBackground;
  final Color inputText;
  final Color inputHint;
  final Brightness brightness;
  final ValueChanged<Set<String>> onChanged;

  const _ItemPickerSheet({
    required this.items,
    required this.categoryNames,
    required this.selectedIds,
    required this.cardBackground,
    required this.inputBackground,
    required this.inputText,
    required this.inputHint,
    required this.brightness,
    required this.onChanged,
  });

  @override
  State<_ItemPickerSheet> createState() => _ItemPickerSheetState();
}

class _ItemPickerSheetState extends State<_ItemPickerSheet> {
  late Set<String> _selected;
  String _search = '';

  @override
  void initState() {
    super.initState();
    _selected = Set.of(widget.selectedIds);
  }

  bool get _allSelected => _selected.length == widget.items.length;

  List<Item> get _filteredItems {
    if (_search.isEmpty) return widget.items;
    final query = _search.toLowerCase();
    return widget.items.where((i) => i.name.toLowerCase().contains(query)).toList();
  }

  String _categoryLabel(Item item) {
    if (item.categoryId == null || item.categoryId!.isEmpty) return 'Uncategorized';
    return widget.categoryNames[item.categoryId!] ?? 'Uncategorized';
  }

  void _toggle(String id) {
    setState(() {
      if (_selected.contains(id)) {
        _selected.remove(id);
      } else {
        _selected.add(id);
      }
    });
    widget.onChanged(_selected);
  }

  void _toggleAll() {
    setState(() {
      if (_allSelected) {
        _selected.clear();
      } else {
        _selected = widget.items.map((i) => i.id).toSet();
      }
    });
    widget.onChanged(_selected);
  }

  @override
  Widget build(BuildContext context) {
    final filtered = _filteredItems;
    final primaryColor = AppColors.primaryAdaptive(widget.brightness);

    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.6,
      ),
      decoration: BoxDecoration(
        color: widget.cardBackground,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(16.0)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Handle bar
          Padding(
            padding: const EdgeInsets.only(top: 12.0, bottom: 4.0),
            child: Container(
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                color: widget.inputBackground,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          // Header row
          Padding(
            padding: const EdgeInsets.fromLTRB(16.0, 8.0, 8.0, 0.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Select Items',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontFamily: 'Inter Tight',
                    fontWeight: FontWeight.w600,
                    letterSpacing: 0.0,
                  ),
                ),
                TextButton(
                  onPressed: _toggleAll,
                  child: Text(
                    _allSelected ? 'Deselect All' : 'Select All',
                    style: TextStyle(
                      fontFamily: 'Inter',
                      fontSize: 13.0,
                      fontWeight: FontWeight.w500,
                      letterSpacing: 0.0,
                      color: primaryColor,
                    ),
                  ),
                ),
              ],
            ),
          ),
          // Search field
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
            child: TextField(
              autofocus: false,
              onChanged: (v) => setState(() => _search = v),
              decoration: InputDecoration(
                hintText: 'Search items...',
                hintStyle: TextStyle(
                  fontFamily: 'Inter',
                  color: widget.inputHint,
                  fontSize: 14.0,
                  letterSpacing: 0.0,
                ),
                prefixIcon: Icon(Icons.search_rounded, size: 20.0, color: widget.inputHint),
                isDense: true,
                contentPadding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 10.0),
                enabledBorder: OutlineInputBorder(
                  borderSide: BorderSide(color: widget.inputBackground),
                  borderRadius: BorderRadius.circular(10.0),
                ),
                focusedBorder: OutlineInputBorder(
                  borderSide: BorderSide(color: primaryColor, width: 1.5),
                  borderRadius: BorderRadius.circular(10.0),
                ),
                filled: true,
                fillColor: widget.inputBackground.withAlpha(77),
              ),
              style: TextStyle(
                fontFamily: 'Inter',
                fontSize: 14.0,
                letterSpacing: 0.0,
                color: widget.inputText,
              ),
            ),
          ),
          // Item list
          Flexible(
            child: filtered.isEmpty
                ? Padding(
                    padding: const EdgeInsets.all(24.0),
                    child: Text(
                      'No items match your search.',
                      style: TextStyle(
                        fontFamily: 'Inter',
                        fontSize: 14.0,
                        color: widget.inputHint,
                        letterSpacing: 0.0,
                      ),
                    ),
                  )
                : ListView.builder(
                    shrinkWrap: true,
                    padding: const EdgeInsets.only(bottom: 16.0),
                    itemCount: filtered.length,
                    itemBuilder: (context, index) {
                      final item = filtered[index];
                      final selected = _selected.contains(item.id);
                      return ListTile(
                        dense: true,
                        visualDensity: VisualDensity.compact,
                        leading: Checkbox(
                          value: selected,
                          onChanged: (_) => _toggle(item.id),
                          activeColor: primaryColor,
                          materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        ),
                        title: Text(
                          item.name,
                          style: TextStyle(
                            fontFamily: 'Inter',
                            fontSize: 14.0,
                            letterSpacing: 0.0,
                            color: widget.inputText,
                          ),
                        ),
                        subtitle: Text(
                          _categoryLabel(item),
                          style: TextStyle(
                            fontFamily: 'Inter',
                            fontSize: 12.0,
                            color: widget.inputHint,
                            letterSpacing: 0.0,
                          ),
                        ),
                        onTap: () => _toggle(item.id),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}
