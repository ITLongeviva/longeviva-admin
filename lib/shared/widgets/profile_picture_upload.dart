import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:longeviva_admin_v1/shared/utils/context_extensions.dart';


import '../utils/colors.dart';

class ProfilePictureUpload extends StatefulWidget {
  final String? currentPictureUrl;
  final Function(Uint8List) onImageSelected;
  final bool isLoading;

  const ProfilePictureUpload({
    Key? key,
    this.currentPictureUrl,
    required this.onImageSelected,
    this.isLoading = false,
  }) : super(key: key);

  @override
  State<ProfilePictureUpload> createState() => _ProfilePictureUploadState();
}

class _ProfilePictureUploadState extends State<ProfilePictureUpload> {
  Uint8List? _selectedImage;
  bool _isLocalLoading = false;

  @override
  Widget build(BuildContext context) {
    final bool isLoading = widget.isLoading || _isLocalLoading;

    return Row(
      children: [
        SizedBox(
          width: 120,
          height: 120,
          child: ClipOval(
            child: Stack(
              children: [
                _buildProfileImage(),
                if (isLoading)
                  Container(
                    color: Colors.black.withOpacity(0.5),
                    child: const Center(
                      child: CircularProgressIndicator(
                        color: CustomColors.biancoPuro,
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.start,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              InkWell(
                onTap: isLoading ? null : _pickImage,
                child: Container(
                  decoration: BoxDecoration(
                    border: Border.all(
                      color: isLoading ? Colors.grey : CustomColors.verdeMare,
                      width: 1,
                    ),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8.0),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                            isLoading ? Icons.hourglass_empty : Icons.cloud_upload_outlined,
                            color: isLoading ? Colors.grey : CustomColors.verdeMare,
                            size: 16
                        ),
                        const SizedBox(width: 8),
                        Text(
                          isLoading ? 'Processing...' : 'Upload new photo',
                          style: TextStyle(
                            fontFamily: 'Montserrat',
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: isLoading ? Colors.grey : Colors.black,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 24),
                  // Image requirements
                  Text(
                    'At least 800x800 px recommended.',
                    style: TextStyle(
                      fontFamily: 'Montserrat',
                      fontSize: 12,
                      color: Colors.grey[600],
                    ),
                  ),
                  Text(
                    'JPG, JPEG or PNG is allowed',
                    style: TextStyle(
                      fontFamily: 'Montserrat',
                      fontSize: 12,
                      color: Colors.grey[600],
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildProfileImage() {
    if (_selectedImage != null) {
      return Image.memory(
        _selectedImage!,
        fit: BoxFit.cover,
        width: double.infinity,
        height: double.infinity,
      );
    } else if (widget.currentPictureUrl != null && widget.currentPictureUrl!.isNotEmpty) {
      return Image.network(
        widget.currentPictureUrl!,
        fit: BoxFit.cover,
        width: double.infinity,
        height: double.infinity,
        loadingBuilder: (context, child, loadingProgress) {
          if (loadingProgress == null) return child;
          return Center(
            child: CircularProgressIndicator(
              value: loadingProgress.expectedTotalBytes != null
                  ? loadingProgress.cumulativeBytesLoaded / loadingProgress.expectedTotalBytes!
                  : null,
              color: CustomColors.verdeAbisso,
            ),
          );
        },
        errorBuilder: (context, error, stackTrace) {
          return _buildPlaceholderIcon();
        },
      );
    } else {
      return _buildPlaceholderIcon();
    }
  }

  Widget _buildPlaceholderIcon() {
    return Center(
      child: SvgPicture.asset("assets/icons/generals/user_first_login.svg")
    );
  }

  Future<void> _pickImage() async {
    try {
      setState(() {
        _isLocalLoading = true;
      });

      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowMultiple: false,
        allowedExtensions: ['jpg', 'jpeg', 'png'],
      );

      if (result != null && result.files.isNotEmpty) {
        final file = result.files.first;

        if (file.bytes != null) {
          setState(() {
            _selectedImage = file.bytes!;
          });

          // Process image validation
          if (_validateImage(file.bytes!)) {
            // Call the callback to notify parent about the selected image
            widget.onImageSelected(file.bytes!);
          } else {
            // Show error message for invalid image
            if (mounted) {
              context.showErrorAlert('Invalid image file. Please select a JPG, JPEG or PNG file.');
            }
          }
        }
      }
    } catch (e) {
      if (mounted) {
        context.showErrorAlert('Error selecting image: $e');
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLocalLoading = false;
        });
      }
    }
  }

  bool _validateImage(Uint8List bytes) {
    try {
      // Log the image size for debugging
      print('Validating image with size: ${bytes.length} bytes');

      // Check for minimum size
      if (bytes.length < 100) {
        print('Image too small: ${bytes.length} bytes');
        return false;
      }

      // Basic signature checks for common image formats
      if (bytes.length >= 4) {
        // Check for PNG signature
        if (bytes[0] == 0x89 && bytes[1] == 0x50 && bytes[2] == 0x4E && bytes[3] == 0x47) {
          print('Valid PNG signature detected');
          return true;
        }

        // Check for JPG signature
        if (bytes[0] == 0xFF && bytes[1] == 0xD8 && bytes[2] == 0xFF) {
          print('Valid JPG signature detected');
          return true;
        }
      }

      print('No valid image signature detected');
      return false;
    } catch (e) {
      print('Error validating image: $e');
      return false;
    }
  }
}