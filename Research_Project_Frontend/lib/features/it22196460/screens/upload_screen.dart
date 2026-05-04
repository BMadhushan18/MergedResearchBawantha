import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:file_picker/file_picker.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_sizes.dart';
import '../../../core/widgets/custom_button.dart';
import '../widgets/loading_overlay.dart';
import '../models/boq_input.dart';
import '../models/dashboard_models.dart';
import '../services/api_service.dart';
import '../services/hive_service.dart';
import '../utils/constants.dart';
import '../widgets/file_preview_widget.dart';
import 'result_screen.dart';

class UploadScreen extends StatefulWidget {
  final ApiService apiService;
  final HiveService hiveService;
  final VoidCallback onUploaded;

  const UploadScreen({
    super.key,
    required this.apiService,
    required this.hiveService,
    required this.onUploaded,
  });

  @override
  State<UploadScreen> createState() => _UploadScreenState();
}

class _UploadScreenState extends State<UploadScreen> {
  PlatformFile? _file;
  final TextEditingController _siteLocationController = TextEditingController();
  final TextEditingController _boqTextController = TextEditingController();

  List<ProjectCatalogItem> _projects = [];
  String? _selectedProjectId;
  BoqSourceMode _sourceMode = BoqSourceMode.uploadFile;
  bool _isLoadingProjects = false;
  String? _projectsError;

  @override
  void initState() {
    super.initState();
    _loadProjects();
  }

  @override
  void dispose() {
    _siteLocationController.dispose();
    _boqTextController.dispose();
    super.dispose();
  }

  Future<void> _loadProjects() async {
    setState(() {
      _isLoadingProjects = true;
      _projectsError = null;
    });

    try {
      final baseUrl = widget.hiveService.getBaseUrl() ?? AppConstants.defaultBaseUrl;
      final projects = await widget.apiService.getProjectsCatalog(baseUrl: baseUrl);
      if (!mounted) return;

      setState(() {
        _projects = projects;
        _projectsError = projects.isEmpty ? 'No records found in projects collection.' : null;
        if (_projects.isNotEmpty) {
          _selectedProjectId = _projects.first.projectId;
          _siteLocationController.text = _projects.first.siteLocation;
        }
        _isLoadingProjects = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _projects = [];
        _selectedProjectId = null;
        _projectsError = 'Project fetch failed: $e';
        _isLoadingProjects = false;
      });
      _toast(_projectsError!);
    }
  }

  ProjectCatalogItem? get _selectedProject {
    for (final project in _projects) {
      if (project.projectId == _selectedProjectId) return project;
    }
    return null;
  }

  Future<void> _pickFile() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: AppConstants.allowedExtensions,
      withData: true,
    );
    if (result != null && result.files.isNotEmpty) {
      setState(() {
        _file = result.files.first;
      });
    }
  }

  Future<void> _submit() async {
    final project = _selectedProject;
    if (project == null || project.projectId.isEmpty) {
      _toast('Select a project from projects collection.');
      return;
    }

    final siteLocation = _siteLocationController.text.trim();
    if (siteLocation.isEmpty) {
      _toast('Type the site location.');
      return;
    }

    if (_sourceMode == BoqSourceMode.uploadFile && _file == null) {
      _toast('Select a BOQ file.');
      return;
    }

    if (_sourceMode == BoqSourceMode.directText && _boqTextController.text.trim().isEmpty) {
      _toast('Enter BOQ text lines.');
      return;
    }

    final baseUrl = widget.hiveService.getBaseUrl() ?? AppConstants.defaultBaseUrl;
    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (_) => const LoadingOverlay(message: 'Running prediction...'),
    );

    try {
      final input = BOQInput(
        projectId: project.projectId,
        projectName: project.projectName,
        projectType: project.projectType,
        siteLocation: siteLocation,
      );

      final prediction = switch (_sourceMode) {
        BoqSourceMode.uploadFile => await widget.apiService.uploadBOQ(
            baseUrl: baseUrl,
            file: _file!,
            input: input,
          ),
        BoqSourceMode.directText => await widget.apiService.predictFromText(
            baseUrl: baseUrl,
            projectId: project.projectId,
            siteLocation: siteLocation,
            boqText: _boqTextController.text,
          ),
        BoqSourceMode.fromBoqReport => await widget.apiService.predictFromBoqReport(
            baseUrl: baseUrl,
            projectId: project.projectId,
            siteLocation: siteLocation,
          ),
      };

      await widget.hiveService.saveOfflineUpload(
        OfflineUploadRecord(
          id: DateTime.now().millisecondsSinceEpoch.toString(),
          projectId: prediction.projectId,
          projectName: prediction.projectName,
          fileName: _sourceMode == BoqSourceMode.uploadFile
              ? (_file?.name ?? 'upload')
              : (_sourceMode == BoqSourceMode.directText ? 'manual-text' : 'boqReport-db'),
          uploadedAt: DateTime.now(),
          prediction: prediction.toHiveMap(),
        ),
      );

      widget.onUploaded();

      if (!mounted) return;

      Navigator.pop(context);
      Navigator.push(
        context,
        MaterialPageRoute(
          settings: RouteSettings(arguments: {'prediction': prediction}),
          builder: (_) => ResultScreen(
            apiService: widget.apiService,
            hiveService: widget.hiveService,
            prediction: prediction,
            projectId: prediction.projectId,
            projectName: prediction.projectName,
            fileName: _sourceMode == BoqSourceMode.uploadFile ? (_file?.name ?? 'upload') : 'db/text source',
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      Navigator.pop(context);
      _toast('Prediction failed: $e');
    }
  }

  void _toast(String text) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(text),
        backgroundColor: AppColors.flameOrange,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final project = _selectedProject;

    return ListView(
      padding: const EdgeInsets.all(AppSizes.s24),
      children: [
        _buildSectionTitle('Project Information'),
        const SizedBox(height: AppSizes.s12),
        _buildCard(
          child: Column(
            children: [
              DropdownButtonFormField<String>(
                isExpanded: true,
                value: _selectedProjectId,
                decoration: _inputDecoration('Project (projects collection)', Icons.business),
                items: _projects
                    .map((p) => DropdownMenuItem<String>(
                          value: p.projectId,
                          child: Text(
                            p.projectName,
                            style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.forgeBlackActual),
                            overflow: TextOverflow.ellipsis,
                            maxLines: 1,
                          ),
                        ))
                    .toList(),
                hint: Text(_isLoadingProjects ? 'Loading projects...' : 'Select a project'),
                onChanged: (value) {
                  setState(() {
                    _selectedProjectId = value;
                    ProjectCatalogItem? selected;
                    for (final project in _projects) {
                      if (project.projectId == value) {
                        selected = project;
                        break;
                      }
                    }
                    _siteLocationController.text = selected?.siteLocation ?? '';
                  });
                },
              ),
              const SizedBox(height: AppSizes.s16),
              TextField(
                readOnly: true,
                controller: TextEditingController(text: project?.projectName ?? ''),
                decoration: _inputDecoration('Project Name (auto)', Icons.badge),
                style: GoogleFonts.inter(color: AppColors.textTertiary),
              ),
              const SizedBox(height: AppSizes.s16),
              TextField(
                readOnly: true,
                controller: TextEditingController(text: project?.projectType ?? ''),
                decoration: _inputDecoration('Project Type (auto)', Icons.apartment),
                style: GoogleFonts.inter(color: AppColors.textTertiary),
              ),
              const SizedBox(height: AppSizes.s16),
              TextField(
                controller: _siteLocationController,
                decoration: _inputDecoration('Site Location (type)', Icons.location_on),
              ),
            ],
          ),
        ),
        const SizedBox(height: AppSizes.s32),
        _buildSectionTitle('BOQ Configuration'),
        const SizedBox(height: AppSizes.s12),
        _buildCard(
          child: Column(
            children: [
              DropdownButtonFormField<BoqSourceMode>(
                value: _sourceMode,
                isExpanded: true,
                decoration: _inputDecoration('BOQ Source', Icons.source),
                items: const [
                  DropdownMenuItem(value: BoqSourceMode.uploadFile, child: Text('Upload file (.xlsx/.xls/.pdf/.txt)', overflow: TextOverflow.ellipsis, maxLines: 1, style: TextStyle(fontSize: 12))),
                  DropdownMenuItem(value: BoqSourceMode.directText, child: Text('Enter BOQ text manually', overflow: TextOverflow.ellipsis, maxLines: 1, style: TextStyle(fontSize: 12))),
                  DropdownMenuItem(value: BoqSourceMode.fromBoqReport, child: Text('Load from MongoDB boqReport', overflow: TextOverflow.ellipsis, maxLines: 1, style: TextStyle(fontSize: 12))),
                ],
                onChanged: (value) => setState(() => _sourceMode = value ?? BoqSourceMode.uploadFile),
              ),
              const SizedBox(height: AppSizes.s16),
              if (_sourceMode == BoqSourceMode.uploadFile) ...[
                _buildFileUploadArea(),
                if (_file != null) ...[
                  const SizedBox(height: 12),
                  FilePreviewWidget(file: _file!),
                ],
              ],
              if (_sourceMode == BoqSourceMode.directText)
                TextField(
                  controller: _boqTextController,
                  minLines: 6,
                  maxLines: 12,
                  decoration: _inputDecoration('BOQ Text', Icons.text_snippet).copyWith(
                    hintText: 'One item per line, optionally: Description | Amount',
                    alignLabelWithHint: true,
                  ),
                ),
              if (_sourceMode == BoqSourceMode.fromBoqReport)
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: AppColors.statusProcessingBg,
                    borderRadius: BorderRadius.circular(AppSizes.radiusCard),
                    border: Border.all(color: AppColors.statusProcessingText.withOpacity(0.1)),
                  ),
                  child: Text(
                    'BOQ rows will be loaded from MongoDB collection: boqReport for the selected project.',
                    style: GoogleFonts.inter(color: AppColors.statusProcessingText, fontSize: 13),
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(height: AppSizes.s32),
        CustomButton(
          label: 'GENERATE PREDICTION',
          icon: Icons.rocket_launch,
          onPressed: (_isLoadingProjects || _projects.isEmpty) ? null : _submit,
          type: CustomButtonType.primary,
          width: double.infinity,
          height: 52,
        ),
      ],
    );
  }

  Widget _buildSectionTitle(String title) {
    return Text(
      title.toUpperCase(),
      style: GoogleFonts.inter(
        fontSize: 11,
        fontWeight: FontWeight.w700,
        color: AppColors.forgeBlackActual,
        letterSpacing: 1.5,
      ),
    );
  }

  Widget _buildCard({required Widget child}) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSizes.s24),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppSizes.radiusCard),
        border: Border.all(color: AppColors.divider, width: 0.5),
      ),
      child: child,
    );
  }

  InputDecoration _inputDecoration(String label, IconData icon) {
    return InputDecoration(
      labelText: label,
      labelStyle: GoogleFonts.inter(color: AppColors.neutral500, fontSize: 13, fontWeight: FontWeight.w500),
      prefixIcon: Icon(icon, color: AppColors.forgeBlackActual, size: 18),
      filled: true,
      fillColor: AppColors.background,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: const BorderSide(color: AppColors.divider),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: const BorderSide(color: AppColors.divider),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: const BorderSide(color: AppColors.flameOrange, width: 1.5),
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
    );
  }

  Widget _buildFileUploadArea() {
    return InkWell(
      onTap: _pickFile,
      borderRadius: BorderRadius.circular(AppSizes.radiusCard),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(32),
        decoration: BoxDecoration(
          color: AppColors.background,
          borderRadius: BorderRadius.circular(AppSizes.radiusCard),
          border: Border.all(color: AppColors.divider, style: BorderStyle.solid),
        ),
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.flameOrange.withOpacity(0.08),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.cloud_upload_outlined, color: AppColors.flameOrange, size: 28),
            ),
            const SizedBox(height: 16),
            Text(
              _file?.name ?? 'Select BOQ File',
              style: GoogleFonts.outfit(fontWeight: FontWeight.w700, color: AppColors.textPrimary, fontSize: 15),
            ),
            const SizedBox(height: 8),
            Text(
              'Supports .xlsx, .xls, .pdf, .txt',
              style: GoogleFonts.inter(fontSize: 12, color: AppColors.textTertiary),
            ),
          ],
        ),
      ),
    );
  }
}
