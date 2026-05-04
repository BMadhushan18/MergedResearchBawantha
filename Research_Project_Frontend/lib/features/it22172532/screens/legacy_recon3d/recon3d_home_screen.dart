import 'package:flutter/material.dart';

import 'package:boq_frontend/features/it22172532/utils/constants.dart';
import 'recon3d_upload_screen.dart';

/// Entry screen for the 3D Reconstruction feature.
/// Launched from the main shell's camera FAB.
class Recon3DHomeScreen extends StatelessWidget {
  const Recon3DHomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        title: const Text('Recon3D Site Tools'),
        elevation: 0,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 24),
              Container(
                width: 72,
                height: 72,
                decoration: BoxDecoration(
                  color: AppColors.primary.withAlpha(25),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: const Icon(
                  Icons.view_in_ar_rounded,
                  size: 40,
                  color: AppColors.primary,
                ),
              ),
              const SizedBox(height: 20),
              const Text(
                'Create a 3D Model of Your Site',
                style: TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                  height: 1.2,
                ),
              ),
              const SizedBox(height: 12),
              const Text(
                'Simply record a short video walking around the site or object. '
                'We will turn it into a 3D model for you automatically.',
                style: TextStyle(
                  color: AppColors.textSecondary,
                  fontSize: 15,
                  height: 1.6,
                ),
              ),
              const SizedBox(height: 32),
              const _StepTile(
                  icon: Icons.videocam_outlined,
                  step: '01',
                  label: 'Record a short video of your site'),
              const _StepTile(
                  icon: Icons.cloud_upload_outlined,
                  step: '02',
                  label: 'Upload the video'),
              const _StepTile(
                  icon: Icons.auto_fix_high_outlined,
                  step: '03',
                  label: 'Wait while we process it'),
              const _StepTile(
                  icon: Icons.threed_rotation_rounded,
                  step: '04',
                  label: 'View your 3D model'),
              const SizedBox(height: 32),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                        builder: (_) => const Recon3DUploadScreen()),
                  ),
                  icon: const Icon(Icons.play_arrow_rounded),
                  label: const Text(
                    'Start Reconstruction',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }
}

class _StepTile extends StatelessWidget {
  final IconData icon;
  final String step;
  final String label;

  const _StepTile({
    required this.icon,
    required this.step,
    required this.label,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 20),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: AppColors.primary.withAlpha(25),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: AppColors.primary, size: 22),
          ),
          const SizedBox(width: 16),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                step,
                style: TextStyle(
                    color: AppColors.primary.withAlpha(180),
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 1),
              ),
              Text(
                label,
                style: const TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 15,
                    fontWeight: FontWeight.w500),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
