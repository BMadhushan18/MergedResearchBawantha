import 'package:flutter/material.dart';
import '../../services/mongo_api_service.dart';
import '../../utils/constants.dart';
import '../plan_analysis/upload_building_plan_screen.dart';

class CreateProjectFlow extends StatefulWidget {
  const CreateProjectFlow({super.key});

  @override
  State<CreateProjectFlow> createState() => _CreateProjectFlowState();
}

class _CreateProjectFlowState extends State<CreateProjectFlow> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _provinceController = TextEditingController();
  final _districtController = TextEditingController();
  final _cityController = TextEditingController();
  bool _loading = false;

  @override
  void dispose() {
    _nameController.dispose();
    _provinceController.dispose();
    _districtController.dispose();
    _cityController.dispose();
    super.dispose();
  }

  Future<void> _createProject() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    setState(() => _loading = true);
    try {
      final api = MongoApiService();
      await api.loadToken();
      if (!api.hasToken) {
        throw Exception('Please sign in again before creating a project.');
      }
      final result = await api.createProject({
        'projectName': _nameController.text.trim(),
        'location':
            '${_cityController.text.trim()}, ${_districtController.text.trim()}, ${_provinceController.text.trim()}',
        'province': _provinceController.text.trim(),
        'district': _districtController.text.trim(),
        'city': _cityController.text.trim(),
      });
      if (!mounted) return;
      final projectId = (result['projectId'] ?? result['_id'] ?? '').toString();
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) => UploadBuildingPlanScreen(projectId: projectId),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to create project: $e'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Create Project'),
        backgroundColor: AppColors.primary,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Project Information',
                style: TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 24),
              TextFormField(
                controller: _nameController,
                decoration: const InputDecoration(
                  labelText: 'Project Name',
                  hintText: 'Enter project name',
                  border: OutlineInputBorder(),
                ),
                validator: (v) => (v == null || v.trim().isEmpty)
                    ? 'Project name is required'
                    : null,
              ),
              const SizedBox(height: 24),
              Text(
                'Land Details',
                style: TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _provinceController,
                decoration: const InputDecoration(
                  labelText: 'Province',
                  hintText: 'Enter province',
                  border: OutlineInputBorder(),
                ),
                validator: (v) => (v == null || v.trim().isEmpty)
                    ? 'Province is required'
                    : null,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _districtController,
                decoration: const InputDecoration(
                  labelText: 'District',
                  hintText: 'Enter district',
                  border: OutlineInputBorder(),
                ),
                validator: (v) => (v == null || v.trim().isEmpty)
                    ? 'District is required'
                    : null,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _cityController,
                decoration: const InputDecoration(
                  labelText: 'City',
                  hintText: 'Enter city',
                  border: OutlineInputBorder(),
                ),
                validator: (v) => (v == null || v.trim().isEmpty)
                    ? 'City is required'
                    : null,
              ),
              const SizedBox(height: 32),
              ElevatedButton(
                onPressed: _loading ? null : _createProject,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
                child: _loading
                    ? const CircularProgressIndicator(color: Colors.white)
                    : const Text(
                        'Create Project',
                        style: TextStyle(
                            fontSize: 18, fontWeight: FontWeight.bold),
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
