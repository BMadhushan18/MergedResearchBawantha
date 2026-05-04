import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/constants/app_colors.dart';
import '../services/session_service.dart';

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final session = SessionService().currentUser;
    final String displayName = session?.displayName ?? "Guest User";
    final String email = session?.email ?? "Not signed in";
    final String role = session?.role.toUpperCase() ?? "VISITOR";
    final String joinedAt = session?.joinedAt != null 
        ? "${session!.joinedAt!.month}/${session!.joinedAt!.year}" 
        : "N/A";

    return Scaffold(
      backgroundColor: AppColors.background,
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            expandedHeight: 200,
            floating: false,
            pinned: true,
            backgroundColor: AppColors.forgeBlackActual,
            flexibleSpace: FlexibleSpaceBar(
              background: Stack(
                fit: StackFit.expand,
                children: [
                  Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [AppColors.forgeBlackActual, const Color(0xFF1A1A1A)],
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                      ),
                    ),
                  ),
                  Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        CircleAvatar(
                          radius: 40,
                          backgroundColor: AppColors.flameOrange,
                          child: const Icon(Icons.person_rounded, size: 48, color: Colors.white),
                        ),
                        const SizedBox(height: 12),
                        Text(
                          displayName,
                          style: GoogleFonts.outfit(
                            fontSize: 20,
                            fontWeight: FontWeight.w800,
                            color: Colors.white,
                          ),
                        ),
                        Text(
                          role,
                          style: GoogleFonts.inter(
                            fontSize: 13,
                            color: Colors.white60,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _sectionTitle("Account Details"),
                  const SizedBox(height: 16),
                  _buildDetailRow(Icons.email_outlined, "Email", email),
                  _buildDetailRow(Icons.verified_user_outlined, "Role", role),
                  _buildDetailRow(Icons.calendar_today_outlined, "Joined", joinedAt),
                  
                  const SizedBox(height: 32),
                  _sectionTitle("Settings & Security"),
                  const SizedBox(height: 16),
                  _buildActionRow(Icons.lock_outline, "Change Password"),
                  _buildActionRow(Icons.notifications_none_rounded, "Notification Settings"),
                  _buildActionRow(Icons.language_rounded, "Language Preference"),
                  
                  const SizedBox(height: 48),
                  SizedBox(
                    width: double.infinity,
                    height: 56,
                    child: OutlinedButton.icon(
                      onPressed: () {
                        // Logout logic
                        Navigator.of(context).pushReplacementNamed('/');
                      },
                      icon: const Icon(Icons.logout_rounded, size: 20),
                      label: Text(
                        "LOGOUT FROM SESSION",
                        style: GoogleFonts.inter(
                          fontWeight: FontWeight.w800,
                          letterSpacing: 1,
                        ),
                      ),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.redAccent,
                        side: const BorderSide(color: Colors.redAccent, width: 1.5),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _sectionTitle(String title) {
    return Text(
      title.toUpperCase(),
      style: GoogleFonts.inter(
        fontSize: 11,
        fontWeight: FontWeight.w800,
        color: AppColors.neutral500,
        letterSpacing: 1.5,
      ),
    );
  }

  Widget _buildDetailRow(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 20),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: AppColors.forgeBlackActual.withOpacity(0.05),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: AppColors.forgeBlackActual, size: 20),
          ),
          const SizedBox(width: 16),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: GoogleFonts.inter(fontSize: 12, color: AppColors.neutral500),
              ),
              Text(
                value,
                style: GoogleFonts.inter(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: AppColors.forgeBlackActual,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildActionRow(IconData icon, String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: InkWell(
        onTap: () {},
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppColors.divider, width: 0.5),
          ),
          child: Row(
            children: [
              Icon(icon, color: AppColors.forgeBlackActual, size: 20),
              const SizedBox(width: 16),
              Text(
                title,
                style: GoogleFonts.inter(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: AppColors.forgeBlackActual,
                ),
              ),
              const Spacer(),
              Icon(Icons.chevron_right_rounded, color: AppColors.neutral500),
            ],
          ),
        ),
      ),
    );
  }
}
