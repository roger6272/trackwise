import 'package:dartz/dartz.dart';
import 'package:injectable/injectable.dart';

import 'package:traxelos/core/error/exceptions.dart';
import 'package:traxelos/core/error/failures.dart';
import 'package:traxelos/core/usecases/usecase.dart';
import 'package:traxelos/features/export/data/datasources/firestore_mail_datasource.dart';
import 'package:traxelos/features/export/domain/entities/csv_export_config.dart';
import 'package:traxelos/features/export/domain/entities/send_email_params.dart';
import 'package:traxelos/features/export/domain/usecases/generate_csv_usecase.dart';

/// Use case for sending an email with CSV export attached.
@injectable
class SendEmailWithCSVUseCase implements UseCase<void, SendEmailParams> {
  final FirestoreMailDataSource mailDataSource;
  final GenerateCSVUseCase generateCSV;

  SendEmailWithCSVUseCase({
    required this.mailDataSource,
    required this.generateCSV,
  });

  @override
  Future<Either<Failure, void>> call(SendEmailParams params) async {
    // First generate the CSV
    final csvConfig = params.toCSVExportConfig();
    final csvResult = await generateCSV(csvConfig);

    return csvResult.fold(
      (failure) => Left(failure),
      (csvContent) async {
        try {
          // Generate filename from config
          final filename = csvConfig.filename;

          // Generate email subject with date range
          final subject = _generateSubject(params);

          // Generate email body
          final body = _generateBody(params);

          // Send email with CSV attachment
          await mailDataSource.sendEmailWithAttachment(
            toEmail: params.email,
            subject: subject,
            body: body,
            csvContent: csvContent,
            filename: filename,
          );

          return const Right(null);
        } on ServerException catch (e) {
          return Left(ServerFailure(e.message));
        } catch (e) {
          return Left(ServerFailure('Failed to send email: ${e.toString()}'));
        }
      },
    );
  }

  /// Generate email subject based on export parameters.
  String _generateSubject(SendEmailParams params) {
    if (params.aggregationLevel == ExportAggregationLevel.byCycle && params.latestCycleOnly) {
      return 'Traxelos Export: Latest Cycle';
    }
    if (params.aggregationLevel == ExportAggregationLevel.byCycle) {
      return 'Traxelos Export: All Cycles';
    }
    final startStr = _formatDate(params.startDate);
    final endStr = _formatDate(params.endDate);
    return 'Traxelos Export: $startStr to $endStr';
  }

  /// Generate email body based on export parameters.
  String _generateBody(SendEmailParams params) {
    final String aggregationLabel;
    switch (params.aggregationLevel) {
      case ExportAggregationLevel.raw:
        aggregationLabel = 'Raw';
      case ExportAggregationLevel.daily:
        aggregationLabel = 'Daily';
      case ExportAggregationLevel.byCycle:
        aggregationLabel = 'By Cycle';
    }

    final String dateRange;
    if (params.aggregationLevel == ExportAggregationLevel.byCycle) {
      dateRange = params.latestCycleOnly ? 'Latest cycle' : 'All cycles';
    } else {
      dateRange = '${_formatDate(params.startDate)} to ${_formatDate(params.endDate)}';
    }

    return '''
Your Traxelos data export is attached.

Export Details:
- Date Range: $dateRange
- Aggregation: $aggregationLabel
${params.itemIds != null ? '- Items: ${params.itemIds!.length} items selected' : '- Items: All items'}

Thank you for using Traxelos!
''';
  }

  String _formatDate(DateTime date) {
    return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
  }
}
