/// Interface for sending emails via Firestore Mail Extension.
abstract class FirestoreMailDataSource {
  /// Send an email with a CSV attachment.
  ///
  /// [toEmail] - The recipient email address.
  /// [subject] - The email subject.
  /// [body] - The email body text.
  /// [csvContent] - The CSV content as a string.
  /// [filename] - The filename for the attachment.
  Future<void> sendEmailWithAttachment({
    required String toEmail,
    required String subject,
    required String body,
    required String csvContent,
    required String filename,
  });
}
