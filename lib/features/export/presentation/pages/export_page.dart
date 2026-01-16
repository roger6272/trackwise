import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/di/injection.dart';
import '../../../../core/theme/app_colors.dart';
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

  // FF Colors for consistent styling on light input backgrounds
  static const Color _inputBackground = Color(0xFFE0E3E7);
  static const Color _inputText = Color(0xFF14181B);
  static const Color _inputHint = Color(0xFF57636C);

  @override
  void initState() {
    super.initState();
    emailController = TextEditingController();
    emailFocusNode = FocusNode();
  }

  @override
  void dispose() {
    emailController.dispose();
    emailFocusNode.dispose();
    super.dispose();
  }

  String _formatDate(DateTime date) {
    return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
  }

  String _getAggregationLabel(ExportAggregationLevel level) {
    switch (level) {
      case ExportAggregationLevel.raw:
        return 'Raw Data';
      case ExportAggregationLevel.daily:
        return 'Daily';
      case ExportAggregationLevel.weekly:
        return 'Weekly';
      case ExportAggregationLevel.monthly:
        return 'Monthly';
    }
  }

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (context) => sl<ExportBloc>(),
      child: BlocConsumer<ExportBloc, ExportState>(
        listener: (context, state) {
          if (state is ExportSuccess) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: const Text('Export sent! Check your email.'),
                backgroundColor: AppColors.success,
              ),
            );
            context.pop();
          }
          if (state is ExportError) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(state.message),
                backgroundColor: AppColors.error,
              ),
            );
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
                elevation: 2.0,
              ),
              body: SafeArea(
                top: true,
                child: Padding(
                  padding: const EdgeInsets.all(24.0),
                  child: SingleChildScrollView(
                    child: Form(
                      key: formKey,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Date Range Section
                          Text(
                            'Date Range',
                            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                              fontFamily: 'Inter Tight',
                              letterSpacing: 0.0,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: 12.0),
                          _buildDateTile(
                            context: context,
                            label: 'Start Date',
                            date: _startDate,
                            onTap: () => _selectStartDate(context),
                          ),
                          const SizedBox(height: 8.0),
                          _buildDateTile(
                            context: context,
                            label: 'End Date',
                            date: _endDate,
                            onTap: () => _selectEndDate(context),
                          ),
                          const SizedBox(height: 24.0),

                          // Aggregation Level Section
                          Text(
                            'Aggregation Level',
                            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                              fontFamily: 'Inter Tight',
                              letterSpacing: 0.0,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: 12.0),
                          Container(
                            decoration: BoxDecoration(
                              color: _inputBackground,
                              borderRadius: BorderRadius.circular(8.0),
                              border: Border.all(
                                color: _inputBackground,
                              ),
                            ),
                            child: DropdownButtonHideUnderline(
                              child: DropdownButton<ExportAggregationLevel>(
                                value: _aggregationLevel,
                                isExpanded: true,
                                padding: const EdgeInsets.symmetric(horizontal: 16.0),
                                dropdownColor: _inputBackground,
                                style: const TextStyle(
                                  fontFamily: 'Inter',
                                  fontSize: 16.0,
                                  letterSpacing: 0.0,
                                  color: _inputText,
                                ),
                                icon: const Icon(
                                  Icons.keyboard_arrow_down_rounded,
                                  color: _inputHint,
                                ),
                                items: ExportAggregationLevel.values.map((level) {
                                  return DropdownMenuItem<ExportAggregationLevel>(
                                    value: level,
                                    child: Text(_getAggregationLabel(level)),
                                  );
                                }).toList(),
                                onChanged: (value) {
                                  if (value != null) {
                                    setState(() => _aggregationLevel = value);
                                  }
                                },
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
                          const SizedBox(height: 24.0),

                          // Email Section
                          Text(
                            'Email Address',
                            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                              fontFamily: 'Inter Tight',
                              letterSpacing: 0.0,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: 12.0),
                          TextFormField(
                            controller: emailController,
                            focusNode: emailFocusNode,
                            keyboardType: TextInputType.emailAddress,
                            textInputAction: TextInputAction.done,
                            decoration: InputDecoration(
                              hintText: 'Enter your email address...',
                              hintStyle: const TextStyle(
                                fontFamily: 'Inter',
                                color: _inputHint,
                                fontSize: 16.0,
                                letterSpacing: 0.0,
                              ),
                              enabledBorder: OutlineInputBorder(
                                borderSide: const BorderSide(
                                  color: _inputBackground,
                                  width: 1.0,
                                ),
                                borderRadius: BorderRadius.circular(8.0),
                              ),
                              focusedBorder: OutlineInputBorder(
                                borderSide: BorderSide(
                                  color: AppColors.primary,
                                  width: 1.0,
                                ),
                                borderRadius: BorderRadius.circular(8.0),
                              ),
                              errorBorder: OutlineInputBorder(
                                borderSide: BorderSide(
                                  color: AppColors.error,
                                  width: 1.0,
                                ),
                                borderRadius: BorderRadius.circular(8.0),
                              ),
                              focusedErrorBorder: OutlineInputBorder(
                                borderSide: BorderSide(
                                  color: AppColors.error,
                                  width: 1.0,
                                ),
                                borderRadius: BorderRadius.circular(8.0),
                              ),
                              filled: true,
                              fillColor: _inputBackground,
                              contentPadding: const EdgeInsets.symmetric(
                                horizontal: 16.0,
                                vertical: 12.0,
                              ),
                            ),
                            style: const TextStyle(
                              fontFamily: 'Inter',
                              fontSize: 16.0,
                              letterSpacing: 0.0,
                              color: _inputText,
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
                            height: 52.0,
                            child: ElevatedButton(
                              onPressed: isLoading ? null : () => _handleExport(blocContext),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AppColors.primary,
                                foregroundColor: Colors.white,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(8.0),
                                ),
                              ),
                              child: Text(
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
                              child: Column(
                                children: [
                                  CircularProgressIndicator(
                                    color: AppColors.primary,
                                  ),
                                  const SizedBox(height: 12.0),
                                  Text(
                                    'Generating and sending export...',
                                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                      fontFamily: 'Inter',
                                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                                      letterSpacing: 0.0,
                                    ),
                                  ),
                                ],
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

  Widget _buildDateTile({
    required BuildContext context,
    required String label,
    required DateTime date,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8.0),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
        decoration: BoxDecoration(
          color: _inputBackground,
          borderRadius: BorderRadius.circular(8.0),
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: const TextStyle(
                      fontFamily: 'Inter',
                      color: _inputHint,
                      fontSize: 12.0,
                      letterSpacing: 0.0,
                    ),
                  ),
                  const SizedBox(height: 4.0),
                  Text(
                    _formatDate(date),
                    style: const TextStyle(
                      fontFamily: 'Inter',
                      fontSize: 16.0,
                      letterSpacing: 0.0,
                      color: _inputText,
                    ),
                  ),
                ],
              ),
            ),
            const Icon(
              Icons.calendar_today,
              color: _inputHint,
              size: 24.0,
            ),
          ],
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

  Future<void> _selectStartDate(BuildContext context) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _startDate,
      firstDate: DateTime(2020),
      lastDate: _endDate,
    );
    if (picked != null && picked != _startDate) {
      setState(() => _startDate = picked);
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
    // Simple email validation regex
    final emailRegex = RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$');
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
      email: emailController.text.trim(),
    ));
  }
}
