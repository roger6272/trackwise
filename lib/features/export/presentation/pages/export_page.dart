import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/di/injection.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/utils/app_util.dart';
import '../../domain/entities/csv_export_config.dart';
import '../bloc/export_bloc.dart';
import '../bloc/export_event.dart';
import '../bloc/export_state.dart';

class ExportPage extends StatefulWidget {
  const ExportPage({super.key});

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
  ExportDataScope _dataScope = ExportDataScope.total;

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

  @override
  void initState() {
    super.initState();
    emailController = TextEditingController();
    emailFocusNode = FocusNode();
    // Update preview card when email changes
    emailController.addListener(_onEmailChanged);
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
        return 'Daily';
      case ExportAggregationLevel.weekly:
        return 'Weekly';
      case ExportAggregationLevel.monthly:
        return 'Monthly';
    }
  }

  String _getDataScopeLabel(ExportDataScope scope) {
    switch (scope) {
      case ExportDataScope.total:
        return 'All data';
      case ExportDataScope.latestCycle:
        return 'Latest cycle';
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
                          // Export Preview Card
                          _buildPreviewCard(context),
                          const SizedBox(height: 24.0),

                          // Date Range Section
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

                          _buildSectionDivider(context),

                          // Aggregation Level Section
                          _buildSectionHeader(
                            context: context,
                            icon: Icons.layers_rounded,
                            title: 'Aggregation Level',
                          ),
                          const SizedBox(height: 12.0),
                          SizedBox(
                            width: double.infinity,
                            child: SegmentedButton<ExportAggregationLevel>(
                              segments: ExportAggregationLevel.values.map((level) {
                                return ButtonSegment<ExportAggregationLevel>(
                                  value: level,
                                  label: Text(_getAggregationLabel(level)),
                                );
                              }).toList(),
                              selected: {_aggregationLevel},
                              onSelectionChanged: (selected) {
                                setState(() => _aggregationLevel = selected.first);
                              },
                              showSelectedIcon: false,
                              style: ButtonStyle(
                                backgroundColor: WidgetStateProperty.resolveWith((states) {
                                  if (states.contains(WidgetState.selected)) {
                                    return AppColors.primaryAdaptive(Theme.of(context).brightness);
                                  }
                                  return _inputBackground(context);
                                }),
                                foregroundColor: WidgetStateProperty.resolveWith((states) {
                                  if (states.contains(WidgetState.selected)) {
                                    return Colors.white;
                                  }
                                  return _inputText(context);
                                }),
                                textStyle: const WidgetStatePropertyAll(
                                  TextStyle(
                                    fontFamily: 'Inter',
                                    fontSize: 13.0,
                                    letterSpacing: 0.0,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ),
                            ),
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

                          _buildSectionDivider(context),

                          // Data Scope Section
                          _buildSectionHeader(
                            context: context,
                            icon: Icons.filter_list_rounded,
                            title: 'Data Scope',
                          ),
                          const SizedBox(height: 12.0),
                          SizedBox(
                            width: double.infinity,
                            child: SegmentedButton<ExportDataScope>(
                              segments: const [
                                ButtonSegment<ExportDataScope>(
                                  value: ExportDataScope.total,
                                  label: Text('Total'),
                                ),
                                ButtonSegment<ExportDataScope>(
                                  value: ExportDataScope.latestCycle,
                                  label: Text('Latest Cycle'),
                                ),
                              ],
                              selected: {_dataScope},
                              onSelectionChanged: (selected) {
                                setState(() => _dataScope = selected.first);
                              },
                              showSelectedIcon: false,
                              style: ButtonStyle(
                                backgroundColor: WidgetStateProperty.resolveWith((states) {
                                  if (states.contains(WidgetState.selected)) {
                                    return AppColors.primaryAdaptive(Theme.of(context).brightness);
                                  }
                                  return _inputBackground(context);
                                }),
                                foregroundColor: WidgetStateProperty.resolveWith((states) {
                                  if (states.contains(WidgetState.selected)) {
                                    return Colors.white;
                                  }
                                  return _inputText(context);
                                }),
                                textStyle: const WidgetStatePropertyAll(
                                  TextStyle(
                                    fontFamily: 'Inter',
                                    fontSize: 13.0,
                                    letterSpacing: 0.0,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(height: 8.0),
                          Text(
                            _getDataScopeDescription(_dataScope),
                            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              fontFamily: 'Inter',
                              color: Theme.of(context).colorScheme.onSurfaceVariant,
                              letterSpacing: 0.0,
                            ),
                          ),

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
                          const SizedBox(height: 32.0),

                          // Export Button
                          Builder(
                            builder: (blocContext) => SizedBox(
                              width: double.infinity,
                              height: 56.0,
                              child: ElevatedButton.icon(
                                onPressed: isLoading ? null : () => _handleExport(blocContext),
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

  /// Preview card showing export summary
  Widget _buildPreviewCard(BuildContext context) {
    final hasEmail = emailController.text.isNotEmpty;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16.0),
      decoration: BoxDecoration(
        color: _cardBackground(context),
        borderRadius: BorderRadius.circular(16.0),
        border: Border.all(
          color: AppColors.primary.withAlpha(51),
          width: 1.0,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(13),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
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
            subtitle: _getDataScopeLabel(_dataScope),
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
            isStart: true,
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
            isStart: false,
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
    required bool isStart,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12.0),
        child: Container(
          padding: const EdgeInsets.all(12.0),
          decoration: BoxDecoration(
            color: _cardBackground(context),
            borderRadius: BorderRadius.circular(12.0),
            border: Border.all(
              color: _inputBackground(context),
              width: 1.0,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withAlpha(8),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Row(
            children: [
              Container(
                width: 4,
                height: 36,
                decoration: BoxDecoration(
                  color: isStart ? AppColors.primary : AppColors.primaryLight,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(width: 12.0),
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
        return 'Group events by day with totals.';
      case ExportAggregationLevel.weekly:
        return 'Group events by week with totals.';
      case ExportAggregationLevel.monthly:
        return 'Group events by month with totals.';
    }
  }

  String _getDataScopeDescription(ExportDataScope scope) {
    switch (scope) {
      case ExportDataScope.total:
        return 'Export all data within the selected date range, regardless of resets.';
      case ExportDataScope.latestCycle:
        return 'Export only data from the most recent reset cycle.';
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

    blocContext.read<ExportBloc>().add(ExportCSV(
      startDate: _startDate,
      endDate: _endDate,
      aggregationLevel: _aggregationLevel,
      dataScope: _dataScope,
      email: emailController.text.trim(),
    ));
  }
}
