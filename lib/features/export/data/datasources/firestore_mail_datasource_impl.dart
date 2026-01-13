import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:injectable/injectable.dart';

import 'package:trackwise/core/error/exceptions.dart';
import 'firestore_mail_datasource.dart';

/// Implementation of [FirestoreMailDataSource] using Firebase Firestore.
///
/// This works with the Firebase Mail Extension which processes documents
/// in the `/mail` collection and sends emails via configured SMTP.
@LazySingleton(as: FirestoreMailDataSource)
class FirestoreMailDataSourceImpl implements FirestoreMailDataSource {
  final FirebaseFirestore firestore;

  /// Collection name for the Firebase Mail Extension.
  static const String _mailCollection = 'mail';

  FirestoreMailDataSourceImpl({required this.firestore});

  @override
  Future<void> sendEmailWithAttachment({
    required String toEmail,
    required String subject,
    required String body,
    required String csvContent,
    required String filename,
  }) async {
    try {
      // Encode CSV content as base64 for attachment
      final base64Csv = base64Encode(utf8.encode(csvContent));

      // Create mail document for Firebase Mail Extension
      await firestore.collection(_mailCollection).add({
        'to': [toEmail],
        'message': {
          'subject': subject,
          'text': body,
          'html': _generateHtmlBody(body),
          'attachments': [
            {
              'filename': filename,
              'content': base64Csv,
              'encoding': 'base64',
              'contentType': 'text/csv',
            },
          ],
        },
        'createdAt': FieldValue.serverTimestamp(),
      });
    } on FirebaseException catch (e) {
      throw ServerException('Failed to send email: ${e.message}');
    } catch (e) {
      throw ServerException('Failed to send email: ${e.toString()}');
    }
  }

  /// Generate a simple HTML body from plain text.
  String _generateHtmlBody(String plainText) {
    final escapedText = plainText
        .replaceAll('&', '&amp;')
        .replaceAll('<', '&lt;')
        .replaceAll('>', '&gt;')
        .replaceAll('\n', '<br>');

    return '''
<!DOCTYPE html>
<html>
<head>
  <meta charset="utf-8">
</head>
<body style="font-family: Arial, sans-serif; line-height: 1.6; color: #333;">
  <div style="max-width: 600px; margin: 0 auto; padding: 20px;">
    <h2 style="color: #2c3e50;">Trackwise Data Export</h2>
    <p>$escapedText</p>
    <hr style="border: none; border-top: 1px solid #eee; margin: 20px 0;">
    <p style="font-size: 12px; color: #888;">
      This email was sent from Trackwise. The requested data export is attached as a CSV file.
    </p>
  </div>
</body>
</html>
''';
  }
}
