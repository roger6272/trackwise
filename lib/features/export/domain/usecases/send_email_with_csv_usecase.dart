import 'package:dartz/dartz.dart';
import 'package:injectable/injectable.dart';

import 'package:trackwise/core/error/exceptions.dart';
import 'package:trackwise/core/error/failures.dart';
import 'package:trackwise/core/usecases/usecase.dart';
import 'package:trackwise/features/export/data/datasources/firestore_mail_datasource.dart';
import 'package:trackwise/features/export/domain/entities/send_email_params.dart';
import 'package:trackwise/features/export/domain/usecases/generate_csv_usecase.dart';

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
    final startStr = _formatDate(params.startDate);
    final endStr = _formatDate(params.endDate);
    return 'Traxogic Export: $startStr to $endStr';
  }

  /// Generate email body based on export parameters.
  String _generateBody(SendEmailParams params) {
    final startStr = _formatDate(params.startDate);
    final endStr = _formatDate(params.endDate);
    final aggregation = params.aggregationLevel.name;

    return '''
Your Traxogic data export is attached.

Export Details:
- Date Range: $startStr to $endStr
- Aggregation: ${_capitalizeFirst(aggregation)}
${params.itemId != null ? '- Item: Filtered by specific item' : '- Items: All items'}

Thank you for using Traxogic!
''';
  }

  String _formatDate(DateTime date) {
    return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
  }

  String _capitalizeFirst(String text) {
    if (text.isEmpty) return text;
    return text[0].toUpperCase() + text.substring(1);
  }
}
