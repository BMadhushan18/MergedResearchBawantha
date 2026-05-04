import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../constants/app_colors.dart';
import '../constants/app_sizes.dart';

enum CustomButtonType { primary, secondary, ghost }

/// Buildora UI Design System Button
class CustomButton extends StatelessWidget {
  final String label;
  final VoidCallback? onPressed;
  final bool isLoading;
  final CustomButtonType type;
  final IconData? icon;
  final double? width;
  final double? height;

  const CustomButton({
    Key? key,
    required this.label,
    required this.onPressed,
    this.isLoading = false,
    this.type = CustomButtonType.primary,
    this.icon,
    this.width,
    this.height,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final bool isGhost = type == CustomButtonType.ghost;
    final bool isSecondary = type == CustomButtonType.secondary;

    // Determine colors based on type
    Color bgColor;
    Color textColor;
    BorderSide border = BorderSide.none;

    switch (type) {
      case CustomButtonType.primary:
        bgColor = AppColors.flameOrange;
        textColor = Colors.white;
        break;
      case CustomButtonType.secondary:
        bgColor = AppColors.forgeBlackActual;
        textColor = Colors.white;
        break;
      case CustomButtonType.ghost:
        bgColor = Colors.transparent;
        textColor = AppColors.forgeBlackActual;
        border = const BorderSide(color: AppColors.forgeBlackActual, width: 1.5);
        break;
    }

    return SizedBox(
      width: width,
      height: height ?? 44,
      child: OutlinedButton(
        onPressed: isLoading ? null : onPressed,
        style: OutlinedButton.styleFrom(
          backgroundColor: bgColor,
          foregroundColor: textColor,
          side: border,
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppSizes.radiusButton),
          ),
          elevation: 0,
        ),
        child: isLoading
            ? SizedBox(
                height: 20,
                width: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor: AlwaysStoppedAnimation<Color>(textColor),
                ),
              )
            : Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (icon != null) ...[
                    Icon(icon, size: 16),
                    const SizedBox(width: 8),
                  ],
                  Text(
                    label,
                    style: GoogleFonts.inter(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: textColor,
                    ),
                  ),
                ],
              ),
      ),
    );
  }
}
