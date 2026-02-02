import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/utils/app_util.dart';
import '../../../../core/utils/logger.dart';

/// Combined Help Center and Contact Us page.
class HelpSupportPage extends StatefulWidget {
  const HelpSupportPage({super.key});

  static const String routeName = 'HelpSupportPage';
  static const String routePath = '/profile/help';

  @override
  State<HelpSupportPage> createState() => _HelpSupportPageState();
}

class _HelpSupportPageState extends State<HelpSupportPage> {
  static const String _supportEmail = 'support@digi1st.com';

  String _appVersion = '';

  @override
  void initState() {
    super.initState();
    _loadAppVersion();
  }

  Future<void> _loadAppVersion() async {
    try {
      final packageInfo = await PackageInfo.fromPlatform();
      if (mounted) {
        setState(() {
          _appVersion = 'v${packageInfo.version} (${packageInfo.buildNumber})';
        });
      }
    } catch (e) {
      AppLogger.debug('Failed to load app version: $e');
      if (mounted) {
        setState(() => _appVersion = 'v1.0.0');
      }
    }
  }

  Future<void> _sendSupportEmail() async {
    final uri = Uri(
      scheme: 'mailto',
      path: _supportEmail,
      queryParameters: {
        'subject': 'Traxelos Support Request',
        'body': '\n\n---\nApp Version: $_appVersion',
      },
    );

    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    } else {
      if (mounted) {
        showErrorSnackBar(context, 'Could not open email app',
          actionLabel: 'Retry',
          onAction: () => _sendSupportEmail(),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    final textTheme = Theme.of(context).textTheme;
    final primaryBackground = AppColors.primaryBackground(brightness);
    final primaryText = AppColors.primaryText(brightness);
    final secondaryText = AppColors.secondaryText(brightness);
    final secondaryBackground = AppColors.secondaryBackground(brightness);

    return Scaffold(
      backgroundColor: primaryBackground,
      appBar: AppBar(
        backgroundColor: primaryBackground,
        leading: IconButton(
          tooltip: 'Back',
          icon: Icon(Icons.arrow_back_rounded, color: primaryText, size: 30.0),
          onPressed: () => context.pop(),
        ),
        title: Text(
          'Help & Support',
          style: textTheme.titleLarge?.copyWith(
            color: primaryText,
          ),
        ),
        centerTitle: true,
        elevation: 0.0,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Quick Tips Section
              _buildSectionTitle(context, 'Quick Tips', primaryText),
              const SizedBox(height: 16.0),
              _buildFaqCard(context, secondaryBackground, primaryText, secondaryText),
              const SizedBox(height: 32.0),

              // Contact Support Section
              _buildSectionTitle(context, 'Contact Support', primaryText),
              const SizedBox(height: 16.0),
              _buildContactCard(context, secondaryBackground, primaryText, secondaryText),
              const SizedBox(height: 32.0),

              // App Info
              Center(
                child: Column(
                  children: [
                    Text(
                      'Traxelos',
                      style: textTheme.titleSmall?.copyWith(
                        color: secondaryText,
                        fontSize: 14.0,
                      ),
                    ),
                    const SizedBox(height: 4.0),
                    Text(
                      _appVersion,
                      style: textTheme.bodySmall?.copyWith(
                        color: secondaryText,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSectionTitle(BuildContext context, String title, Color primaryText) {
    return Text(
      title,
      style: Theme.of(context).textTheme.titleMedium?.copyWith(
        color: primaryText,
      ),
    );
  }

  Widget _buildFaqCard(
    BuildContext context,
    Color secondaryBackground,
    Color primaryText,
    Color secondaryText,
  ) {
    final faqs = [
      (
        question: 'How do I connect my device?',
        answer: 'Go to the Bluetooth tab and tap "Find Device". Make sure your Traxelos device is powered on and nearby. Select it from the list to connect.',
      ),
      (
        question: 'How do I add a new item to track?',
        answer: 'On the Items tab, tap the "+" button in the top right corner. Enter a name for your item and configure the settings as needed.',
      ),
      (
        question: 'How do I reset my count?',
        answer: 'Daily counts reset automatically at midnight. You can also manually reset by going to the item details and tapping the reset option, which resets both the total count and daily count.',
      ),
      (
        question: 'How do I export my data?',
        answer: 'Go to Profile > Export My Data. This will generate a CSV file containing all your items and event logs that you can save or share.',
      ),
      (
        question: 'What happens to deleted items?',
        answer: 'Deleted items are moved to "Recently Deleted" where they stay for 90 days. You can restore them anytime before they are permanently removed.',
      ),
      (
        question: 'How do I reorder my items?',
        answer: 'Long press on any item in the list, then drag it to your desired position. Release to save the new order.',
      ),
    ];

    return Container(
      decoration: BoxDecoration(
        color: secondaryBackground,
        borderRadius: BorderRadius.circular(12.0),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12.0),
        child: ExpansionPanelList.radio(
          elevation: 0,
          expandedHeaderPadding: EdgeInsets.zero,
          children: faqs.asMap().entries.map((entry) {
            final index = entry.key;
            final faq = entry.value;
            return ExpansionPanelRadio(
              value: index,
              canTapOnHeader: true,
              headerBuilder: (context, isExpanded) {
                return ListTile(
                  title: Text(
                    faq.question,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: primaryText,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                );
              },
              body: Padding(
                padding: const EdgeInsets.fromLTRB(16.0, 0.0, 16.0, 16.0),
                child: Text(
                  faq.answer,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: secondaryText,
                    height: 1.5,
                  ),
                ),
              ),
            );
          }).toList(),
        ),
      ),
    );
  }

  Widget _buildContactCard(
    BuildContext context,
    Color secondaryBackground,
    Color primaryText,
    Color secondaryText,
  ) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20.0),
      decoration: BoxDecoration(
        color: secondaryBackground,
        borderRadius: BorderRadius.circular(12.0),
      ),
      child: Column(
        children: [
          Icon(
            Icons.support_agent_rounded,
            size: 48.0,
            color: AppColors.primary,
          ),
          const SizedBox(height: 16.0),
          Text(
            'Need more help?',
            style: Theme.of(context).textTheme.titleSmall?.copyWith(
              color: primaryText,
            ),
          ),
          const SizedBox(height: 8.0),
          Text(
            'Our support team is here to help you with any questions or issues.',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: secondaryText,
            ),
          ),
          const SizedBox(height: 20.0),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: _sendSupportEmail,
              icon: const Icon(Icons.email_outlined, size: 20.0),
              label: Text(
                'Email Support',
                style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14.0),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12.0),
                ),
              ),
            ),
          ),
          const SizedBox(height: 12.0),
          Text(
            _supportEmail,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: secondaryText,
            ),
          ),
        ],
      ),
    );
  }
}
