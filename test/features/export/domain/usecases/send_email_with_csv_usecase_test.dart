import 'package:dartz/dartz.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:traxelos/core/error/exceptions.dart';
import 'package:traxelos/core/error/failures.dart';
import 'package:traxelos/features/export/domain/entities/csv_export_config.dart';
import 'package:traxelos/features/export/domain/usecases/send_email_with_csv_usecase.dart';

import '../../helpers/test_helper.dart';
import '../../helpers/test_fixtures.dart';

void main() {
  late SendEmailWithCSVUseCase useCase;
  late MockFirestoreMailDataSource mockMailDataSource;
  late MockGenerateCSVUseCase mockGenerateCSV;

  setUp(() {
    mockMailDataSource = MockFirestoreMailDataSource();
    mockGenerateCSV = MockGenerateCSVUseCase();
    useCase = SendEmailWithCSVUseCase(
      mailDataSource: mockMailDataSource,
      generateCSV: mockGenerateCSV,
    );
  });

  setUpAll(() {
    registerFallbackValue(testCSVConfig);
  });

  group('SendEmailWithCSVUseCase', () {
    test('should send email with CSV attachment when successful', () async {
      // Arrange
      when(() => mockGenerateCSV(any()))
          .thenAnswer((_) async => const Right(testCSVContent));
      when(() => mockMailDataSource.sendEmailWithAttachment(
            toEmail: any(named: 'toEmail'),
            subject: any(named: 'subject'),
            body: any(named: 'body'),
            csvContent: any(named: 'csvContent'),
            filename: any(named: 'filename'),
          )).thenAnswer((_) async {});

      // Act
      final result = await useCase(testSendEmailParams);

      // Assert
      expect(result.isRight(), true);
      verify(() => mockGenerateCSV(any())).called(1);
      verify(() => mockMailDataSource.sendEmailWithAttachment(
            toEmail: testEmail,
            subject: any(named: 'subject'),
            body: any(named: 'body'),
            csvContent: testCSVContent,
            filename: any(named: 'filename'),
          )).called(1);
    });

    test('should return failure when CSV generation fails', () async {
      // Arrange
      const failure = ServerFailure('Failed to generate CSV');
      when(() => mockGenerateCSV(any()))
          .thenAnswer((_) async => const Left(failure));

      // Act
      final result = await useCase(testSendEmailParams);

      // Assert
      expect(result, const Left(failure));
      verifyNever(() => mockMailDataSource.sendEmailWithAttachment(
            toEmail: any(named: 'toEmail'),
            subject: any(named: 'subject'),
            body: any(named: 'body'),
            csvContent: any(named: 'csvContent'),
            filename: any(named: 'filename'),
          ));
    });

    test('should return failure when email sending fails', () async {
      // Arrange
      when(() => mockGenerateCSV(any()))
          .thenAnswer((_) async => const Right(testCSVContent));
      when(() => mockMailDataSource.sendEmailWithAttachment(
            toEmail: any(named: 'toEmail'),
            subject: any(named: 'subject'),
            body: any(named: 'body'),
            csvContent: any(named: 'csvContent'),
            filename: any(named: 'filename'),
          )).thenThrow(ServerException('SMTP error'));

      // Act
      final result = await useCase(testSendEmailParams);

      // Assert
      expect(result.isLeft(), true);
      result.fold(
        (failure) => expect(failure.message, 'SMTP error'),
        (_) => fail('Should be failure'),
      );
    });

    test('should generate correct filename from params', () async {
      // Arrange
      when(() => mockGenerateCSV(any()))
          .thenAnswer((_) async => const Right(testCSVContent));
      when(() => mockMailDataSource.sendEmailWithAttachment(
            toEmail: any(named: 'toEmail'),
            subject: any(named: 'subject'),
            body: any(named: 'body'),
            csvContent: any(named: 'csvContent'),
            filename: any(named: 'filename'),
          )).thenAnswer((_) async {});

      // Act
      await useCase(testSendEmailParams);

      // Assert
      verify(() => mockMailDataSource.sendEmailWithAttachment(
            toEmail: any(named: 'toEmail'),
            subject: any(named: 'subject'),
            body: any(named: 'body'),
            csvContent: any(named: 'csvContent'),
            filename: 'tally_export_2024-01-01_to_2024-01-31_daily.csv',
          )).called(1);
    });

    test('should generate subject with date range', () async {
      // Arrange
      when(() => mockGenerateCSV(any()))
          .thenAnswer((_) async => const Right(testCSVContent));
      when(() => mockMailDataSource.sendEmailWithAttachment(
            toEmail: any(named: 'toEmail'),
            subject: any(named: 'subject'),
            body: any(named: 'body'),
            csvContent: any(named: 'csvContent'),
            filename: any(named: 'filename'),
          )).thenAnswer((_) async {});

      // Act
      await useCase(testSendEmailParams);

      // Assert
      verify(() => mockMailDataSource.sendEmailWithAttachment(
            toEmail: any(named: 'toEmail'),
            subject: 'Traxelos Export: 2024-01-01 to 2024-01-31',
            body: any(named: 'body'),
            csvContent: any(named: 'csvContent'),
            filename: any(named: 'filename'),
          )).called(1);
    });

    test('should pass correct CSVExportConfig to generateCSV', () async {
      // Arrange
      when(() => mockGenerateCSV(any()))
          .thenAnswer((_) async => const Right(testCSVContent));
      when(() => mockMailDataSource.sendEmailWithAttachment(
            toEmail: any(named: 'toEmail'),
            subject: any(named: 'subject'),
            body: any(named: 'body'),
            csvContent: any(named: 'csvContent'),
            filename: any(named: 'filename'),
          )).thenAnswer((_) async {});

      // Act
      await useCase(testSendEmailParamsWithItem);

      // Assert
      verify(() => mockGenerateCSV(any(
            that: isA<CSVExportConfig>()
                .having((c) => c.itemId, 'itemId', testItemId)
                .having((c) => c.aggregationLevel, 'aggregationLevel',
                    ExportAggregationLevel.daily),
          ))).called(1);
    });
  });

  group('SendEmailParams', () {
    test('should convert to CSVExportConfig correctly', () {
      final config = testSendEmailParams.toCSVExportConfig();

      expect(config.startDate, testStartDate);
      expect(config.endDate, testEndDate);
      expect(config.aggregationLevel, ExportAggregationLevel.daily);
      expect(config.itemId, isNull);
    });

    test('should convert to CSVExportConfig with itemId', () {
      final config = testSendEmailParamsWithItem.toCSVExportConfig();

      expect(config.itemId, testItemId);
    });
  });
}
