import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../../../core/theme/app_theme.dart';
import '../services/club_service.dart';

class CreatePostSheet extends StatefulWidget {
  const CreatePostSheet({
    super.key,
    required this.clubId,
  });

  final String clubId;

  @override
  State<CreatePostSheet> createState() => _CreatePostSheetState();
}

class _CreatePostSheetState extends State<CreatePostSheet> {
  final _captionCtrl = TextEditingController();
  File? _image;
  bool _submitting = false;

  @override
  void dispose() {
    _captionCtrl.dispose();
    super.dispose();
  }

  bool get _canPost =>
      !_submitting &&
      (_image != null || _captionCtrl.text.trim().isNotEmpty);

  Future<void> _pickImage(ImageSource source) async {
    Navigator.pop(context); // close picker bottom sheet
    final picked = await ImagePicker().pickImage(
      source: source,
      imageQuality: 85,
      maxWidth: 1920,
    );
    if (picked != null && mounted) {
      setState(() => _image = File(picked.path));
    }
  }

  void _showImageSourceSheet() {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: AppTheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 8),
            ListTile(
              leading: const Icon(Icons.camera_alt_outlined,
                  color: AppTheme.textPrimary, size: 22),
              title: const Text('Camera',
                  style: TextStyle(
                      color: AppTheme.textPrimary,
                      fontSize: 14,
                      fontWeight: FontWeight.w500)),
              onTap: () => _pickImage(ImageSource.camera),
            ),
            ListTile(
              leading: const Icon(Icons.photo_library_outlined,
                  color: AppTheme.textPrimary, size: 22),
              title: const Text('Gallery',
                  style: TextStyle(
                      color: AppTheme.textPrimary,
                      fontSize: 14,
                      fontWeight: FontWeight.w500)),
              onTap: () => _pickImage(ImageSource.gallery),
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  Future<void> _submit() async {
    setState(() => _submitting = true);
    try {
      await clubService.createPost(
        clubId: widget.clubId,
        body: _captionCtrl.text.trim(),
        imageFile: _image,
      );
      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Failed to post: $e'),
          backgroundColor: AppTheme.speedRed,
        ));
        setState(() => _submitting = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding:
          EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: Container(
        decoration: const BoxDecoration(
          color: AppTheme.surface,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Row(
              children: [
                const Text(
                  'New post',
                  style: TextStyle(
                    color: AppTheme.textPrimary,
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const Spacer(),
                _submitting
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                            color: AppTheme.accent, strokeWidth: 2),
                      )
                    : TextButton(
                        onPressed: _canPost ? _submit : null,
                        style: TextButton.styleFrom(
                          foregroundColor: AppTheme.accent,
                          disabledForegroundColor: AppTheme.textSecondary,
                          padding: EdgeInsets.zero,
                          minimumSize: Size.zero,
                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        ),
                        child: const Text(
                          'Post',
                          style: TextStyle(
                              fontSize: 15, fontWeight: FontWeight.w600),
                        ),
                      ),
              ],
            ),
            const SizedBox(height: 16),

            // Image area
            _image == null
                ? GestureDetector(
                    onTap: _showImageSourceSheet,
                    child: Container(
                      width: double.infinity,
                      height: 120,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: AppTheme.textSecondary,
                          style: BorderStyle.solid,
                          width: 1.5,
                        ),
                      ),
                      child: const Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.add_photo_alternate_outlined,
                              color: AppTheme.accent, size: 32),
                          SizedBox(height: 8),
                          Text(
                            'Add photo',
                            style: TextStyle(
                                color: AppTheme.textSecondary, fontSize: 13),
                          ),
                        ],
                      ),
                    ),
                  )
                : Stack(
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: Image.file(
                          _image!,
                          width: double.infinity,
                          height: 220,
                          fit: BoxFit.cover,
                        ),
                      ),
                      Positioned(
                        top: 8,
                        right: 8,
                        child: GestureDetector(
                          onTap: () => setState(() => _image = null),
                          child: Container(
                            width: 26,
                            height: 26,
                            decoration: const BoxDecoration(
                              color: AppTheme.accent,
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(Icons.close,
                                color: AppTheme.background, size: 16),
                          ),
                        ),
                      ),
                    ],
                  ),
            const SizedBox(height: 14),

            // Caption field
            TextField(
              controller: _captionCtrl,
              maxLines: null,
              maxLength: 300,
              cursorColor: AppTheme.accent,
              style: const TextStyle(color: AppTheme.textPrimary, fontSize: 14),
              onChanged: (_) => setState(() {}),
              decoration: InputDecoration(
                hintText: 'Write a caption... (optional)',
                hintStyle: const TextStyle(
                    color: AppTheme.textSecondary, fontSize: 14),
                filled: true,
                fillColor: AppTheme.surfaceHigh,
                counterStyle: const TextStyle(
                    color: AppTheme.textSecondary, fontSize: 11),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide:
                      const BorderSide(color: AppTheme.accent, width: 1.5),
                ),
                contentPadding: const EdgeInsets.symmetric(
                    horizontal: 14, vertical: 12),
              ),
            ),
          ],
        ),
      ),
    );
  }
}