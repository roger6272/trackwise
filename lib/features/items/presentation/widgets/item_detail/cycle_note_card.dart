import 'package:flutter/material.dart';

import '../../../../../core/theme/app_colors.dart';

/// Editable note card for per-cycle annotations.
///
/// Displays a tap-to-edit card that expands into a multiline TextField.
/// Hidden when viewing All Time (notes are per-cycle).
class CycleNoteCard extends StatefulWidget {
  /// Current note text (null/empty = no note).
  final String? note;

  /// Callback when note is saved.
  final ValueChanged<String> onNoteChanged;

  /// Hide for All Time view (notes are per-cycle).
  final bool isAllTime;

  const CycleNoteCard({
    super.key,
    this.note,
    required this.onNoteChanged,
    this.isAllTime = false,
  });

  @override
  State<CycleNoteCard> createState() => _CycleNoteCardState();
}

class _CycleNoteCardState extends State<CycleNoteCard> {
  bool _isEditing = false;
  late TextEditingController _controller;
  late FocusNode _focusNode;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.note ?? '');
    _focusNode = FocusNode();
    _focusNode.addListener(_onFocusChanged);
  }

  @override
  void didUpdateWidget(CycleNoteCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Cycle switched while editing — save current edits and collapse
    if (oldWidget.note != widget.note) {
      if (_isEditing) {
        _saveNote();
      }
      _controller.text = widget.note ?? '';
      _isEditing = false;
    }
  }

  @override
  void dispose() {
    _focusNode.removeListener(_onFocusChanged);
    _focusNode.dispose();
    _controller.dispose();
    super.dispose();
  }

  void _onFocusChanged() {
    if (!_focusNode.hasFocus && _isEditing) {
      _saveNote();
    }
  }

  void _saveNote() {
    final text = _controller.text.trim();
    widget.onNoteChanged(text);
    setState(() {
      _isEditing = false;
    });
  }

  void _enterEditMode() {
    setState(() {
      _isEditing = true;
    });
    // Request focus after the frame so the TextField is rendered
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _focusNode.requestFocus();
    });
  }

  @override
  Widget build(BuildContext context) {
    if (widget.isAllTime) return const SizedBox.shrink();

    final brightness = Theme.of(context).brightness;
    final primaryText = AppColors.primaryText(brightness);
    final secondaryText = AppColors.secondaryText(brightness);
    final alternate = AppColors.alternate(brightness);
    final textTheme = Theme.of(context).textTheme;

    return GestureDetector(
      onTap: _isEditing ? null : _enterEditMode,
      child: Container(
        padding: const EdgeInsets.all(14.0),
        decoration: BoxDecoration(
          color: alternate,
          borderRadius: BorderRadius.circular(12.0),
          border: Border.all(
            color: primaryText.withValues(alpha: 0.06),
            width: 1.0,
          ),
        ),
        child: _isEditing
            ? _buildEditMode(textTheme, primaryText, secondaryText)
            : _buildDisplayMode(textTheme, primaryText, secondaryText),
      ),
    );
  }

  Widget _buildDisplayMode(
    TextTheme textTheme,
    Color primaryText,
    Color secondaryText,
  ) {
    final hasNote = widget.note != null && widget.note!.isNotEmpty;

    return Row(
      children: [
        Icon(
          Icons.edit_note_rounded,
          size: 20.0,
          color: secondaryText,
        ),
        const SizedBox(width: 10.0),
        Expanded(
          child: Text(
            hasNote ? widget.note! : 'Add a note...',
            style: textTheme.bodyMedium?.copyWith(
              color: hasNote
                  ? primaryText
                  : secondaryText.withValues(alpha: 0.6),
              fontStyle: hasNote ? FontStyle.normal : FontStyle.italic,
            ),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }

  Widget _buildEditMode(
    TextTheme textTheme,
    Color primaryText,
    Color secondaryText,
  ) {
    final primary = AppColors.primaryAdaptive(Theme.of(context).brightness);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Header row
        Row(
          children: [
            Icon(
              Icons.edit_note_rounded,
              size: 20.0,
              color: secondaryText,
            ),
            const Spacer(),
            GestureDetector(
              onTap: _saveNote,
              child: Text(
                'Done',
                style: textTheme.bodyMedium?.copyWith(
                  color: primary,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8.0),
        // TextField
        TextField(
          controller: _controller,
          focusNode: _focusNode,
          maxLength: 250,
          maxLines: 3,
          minLines: 1,
          style: textTheme.bodyMedium?.copyWith(
            color: primaryText,
          ),
          decoration: InputDecoration(
            hintText: 'Write a note for this cycle...',
            hintStyle: textTheme.bodyMedium?.copyWith(
              color: secondaryText.withValues(alpha: 0.5),
            ),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8.0),
              borderSide: BorderSide(
                color: secondaryText.withValues(alpha: 0.2),
              ),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8.0),
              borderSide: BorderSide(
                color: secondaryText.withValues(alpha: 0.2),
              ),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8.0),
              borderSide: BorderSide(color: primary),
            ),
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 12.0,
              vertical: 10.0,
            ),
            counterStyle: textTheme.bodySmall?.copyWith(
              color: secondaryText.withValues(alpha: 0.6),
              fontSize: 11.0,
            ),
          ),
        ),
      ],
    );
  }
}
