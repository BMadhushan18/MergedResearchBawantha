import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:boq_frontend/features/it22172532/utils/constants.dart';
final String _kApiBase = AppConstants.baseUrl;



class FeedbackScreen extends StatefulWidget {
  const FeedbackScreen({super.key});

  @override
  State<FeedbackScreen> createState() => _FeedbackScreenState();
}

class _FeedbackScreenState extends State<FeedbackScreen>
    with SingleTickerProviderStateMixin {
  bool _loading = false;
  String? _syncingDataset;
  late AnimationController _controller;
  late Animation<double> _fadeAnim;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
        duration: const Duration(milliseconds: 700), vsync: this);
    _fadeAnim = CurvedAnimation(parent: _controller, curve: Curves.easeIn);
    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _sync(String? dataset) async {
    if (_loading) return;
    setState(() {
      _loading = true;
      _syncingDataset = dataset;
    });

    try {
      final uri = dataset == null
          ? Uri.parse('$_kApiBase/feedback/sync/all')
          : Uri.parse('$_kApiBase/feedback/sync/$dataset');

      final response = await http
          .post(uri, headers: {'Content-Type': 'application/json'}, body: '{}')
          .timeout(const Duration(seconds: 30));

      if (!mounted) return;

      if (response.statusCode >= 200 && response.statusCode < 300) {
        Map<String, dynamic> body = {};
        try {
          body = json.decode(response.body) as Map<String, dynamic>;
        } catch (_) {}
        _showResult(
          true,
          dataset == null
              ? 'All datasets synced successfully'
              : '${_datasetLabel(dataset)} synced successfully',
          body.isNotEmpty ? _formatBody(body) : null,
        );
      } else {
        _showResult(false, 'Sync failed (HTTP ${response.statusCode})', null);
      }
    } catch (e) {
      if (!mounted) return;
      _showResult(false, 'Connection error', e.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  String _datasetLabel(String ds) {
    switch (ds) {
      case 'paint':
        return 'Paint form';
      case 'skimcoat':
        return 'Skimcoat form';
      case 'wood':
        return 'Wood form';
      default:
        return ds;
    }
  }

  String _formatBody(Map<String, dynamic> body) {
    return body.entries.map((e) => '${e.key}: ${e.value}').join('\n');
  }

  void _showResult(bool success, String message, String? detail) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => _ResultSheet(
          success: success, message: message, detail: detail),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            expandedHeight: 200,
            pinned: true,
            backgroundColor: AppColors.primary,
            foregroundColor: Colors.white,
            flexibleSpace: FlexibleSpaceBar(
              title: const Text(
                'Feedback Sync',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
              ),
              background: Stack(
                fit: StackFit.expand,
                children: [
                  Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [AppColors.primary, AppColors.primaryLight],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                    ),
                  ),
                  Positioned.fill(
                    child: Center(
                      child: Icon(
                        Icons.feedback_rounded,
                        size: 100,
                        color: Colors.white.withOpacity(0.12),
                      ),
                    ),
                  ),
                  Positioned(
                    left: 24,
                    bottom: 56,
                    right: 24,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.2),
                            borderRadius: BorderRadius.circular(14),
                          ),
                          child: const Icon(Icons.sync_rounded,
                              color: Colors.white, size: 26),
                        ),
                        const SizedBox(height: 8),
                        const Text(
                          'Sync spreadsheet data back to the ML models',
                          style: TextStyle(
                              color: Colors.white70,
                              fontSize: 13,
                              height: 1.3),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          SliverToBoxAdapter(
            child: FadeTransition(
              opacity: _fadeAnim,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 24, 20, 40),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _sectionLabel('Bulk Action'),
                    const SizedBox(height: 12),
                    _SyncCard(
                      icon: Icons.sync_rounded,
                      iconColor: AppColors.primary,
                      title: 'Sync All Datasets',
                      subtitle: 'Trigger sync for Paint, Skimcoat & Wood forms',
                      isSyncing:
                          _loading && _syncingDataset == null,
                      onTap: () => _sync(null),
                    ),
                    const SizedBox(height: 24),
                    _sectionLabel('Dataset Sync'),
                    const SizedBox(height: 12),
                    _SyncCard(
                      icon: Icons.format_paint_rounded,
                      iconColor: const Color(0xFF1565C0),
                      title: 'Paint Form',
                      subtitle: 'Sync feedback data from paint prediction form',
                      isSyncing:
                          _loading && _syncingDataset == 'paint',
                      onTap: () => _sync('paint'),
                    ),
                    const SizedBox(height: 12),
                    _SyncCard(
                      icon: Icons.layers_rounded,
                      iconColor: const Color(0xFF6A1B9A),
                      title: 'Skimcoat Form',
                      subtitle: 'Sync feedback data from skimcoat prediction form',
                      isSyncing:
                          _loading && _syncingDataset == 'skimcoat',
                      onTap: () => _sync('skimcoat'),
                    ),
                    const SizedBox(height: 12),
                    _SyncCard(
                      icon: Icons.park_rounded,
                      iconColor: Colors.brown,
                      title: 'Wood Form',
                      subtitle: 'Sync feedback data from wood prediction form',
                      isSyncing:
                          _loading && _syncingDataset == 'wood',
                      onTap: () => _sync('wood'),
                    ),
                    const SizedBox(height: 28),
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: AppColors.primary.withOpacity(0.06),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                            color: AppColors.primary.withOpacity(0.18)),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.info_outline_rounded,
                              color: AppColors.primary, size: 20),
                          const SizedBox(width: 12),
                          const Expanded(
                            child: Text(
                              'Syncing writes the Google Sheet feedback entries '
                              'back to the training dataset for model retraining.',
                              style: TextStyle(
                                  fontSize: 12,
                                  color: AppColors.textSecondary,
                                  height: 1.4),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _sectionLabel(String text) {
    return Text(
      text,
      style: const TextStyle(
        fontSize: 13,
        fontWeight: FontWeight.w700,
        letterSpacing: 0.5,
        color: AppColors.textSecondary,
      ),
    );
  }
}

// ── Sync Card ────────────────────────────────────────────────────────────────

class _SyncCard extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String title;
  final String subtitle;
  final bool isSyncing;
  final VoidCallback onTap;

  const _SyncCard({
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.subtitle,
    required this.isSyncing,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.cardBackground,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: isSyncing ? null : onTap,
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            boxShadow: const [
              BoxShadow(
                  color: AppColors.cardShadow,
                  blurRadius: 10,
                  offset: Offset(0, 3)),
            ],
          ),
          child: Row(
            children: [
              AnimatedContainer(
                duration: const Duration(milliseconds: 300),
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: isSyncing
                      ? iconColor.withOpacity(0.25)
                      : iconColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(13),
                ),
                child: isSyncing
                    ? Padding(
                        padding: const EdgeInsets.all(12),
                        child: CircularProgressIndicator(
                          strokeWidth: 2.5,
                          valueColor:
                              AlwaysStoppedAnimation<Color>(iconColor),
                        ),
                      )
                    : Icon(icon, color: iconColor, size: 22),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      isSyncing ? 'Syncing…' : subtitle,
                      style: TextStyle(
                        fontSize: 12,
                        color: isSyncing ? iconColor : AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              if (!isSyncing)
                Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: iconColor.withOpacity(0.08),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(Icons.sync_rounded, color: iconColor, size: 16),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Result Bottom Sheet ───────────────────────────────────────────────────────

class _ResultSheet extends StatelessWidget {
  final bool success;
  final String message;
  final String? detail;

  const _ResultSheet(
      {required this.success,
      required this.message,
      this.detail});

  @override
  Widget build(BuildContext context) {
    final color = success ? Colors.green : Colors.red;
    final icon =
        success ? Icons.check_circle_rounded : Icons.error_rounded;

    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: AppColors.cardBackground,
        borderRadius: BorderRadius.circular(20),
        boxShadow: const [
          BoxShadow(
              color: AppColors.cardShadow, blurRadius: 20, offset: Offset(0, -4))
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: color.withOpacity(0.12),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: color, size: 36),
          ),
          const SizedBox(height: 16),
          Text(
            message,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: AppColors.textPrimary,
            ),
          ),
          if (detail != null) ...[
            const SizedBox(height: 8),
            Text(
              detail!,
              textAlign: TextAlign.center,
              style: const TextStyle(
                  fontSize: 12,
                  color: AppColors.textSecondary,
                  height: 1.4),
            ),
          ],
          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () => Navigator.pop(context),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
                padding: const EdgeInsets.symmetric(vertical: 14),
              ),
              child: const Text('Done',
                  style: TextStyle(fontWeight: FontWeight.w600)),
            ),
          ),
        ],
      ),
    );
  }
}
