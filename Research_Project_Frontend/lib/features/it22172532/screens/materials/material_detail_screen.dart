import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:boq_frontend/features/it22172532/utils/constants.dart';

class MaterialDetailScreen extends StatefulWidget {
  final String surfaceType;
  final List<String> options;

  const MaterialDetailScreen({
    super.key,
    required this.surfaceType,
    required this.options,
  });

  @override
  State<MaterialDetailScreen> createState() => _MaterialDetailScreenState();
}

class _MaterialDetailScreenState extends State<MaterialDetailScreen>
    with SingleTickerProviderStateMixin {
  String? selectedMaterial;
  final TextEditingController _lengthController = TextEditingController();
  final TextEditingController _widthController = TextEditingController();
  final TextEditingController _priceController = TextEditingController();
  double? estimatedCost;

  String _getImageForMaterial(String material) {
    switch (material.toLowerCase()) {
      case 'paint':
        return 'AppImages/paint.jpg';
      case 'putty':
        return 'AppImages/putty.jpeg';
      case 'tile':
        return 'AppImages/tile.jpg';
      case 'tile paste':
        return 'AppImages/tile_pasting.png';
      default:
        return '';
    }
  }

  @override
  void dispose() {
    _lengthController.dispose();
    _widthController.dispose();
    _priceController.dispose();
    super.dispose();
  }

  void _calculateEstimate() {
    final length = double.tryParse(_lengthController.text);
    final width = double.tryParse(_widthController.text);
    final price = double.tryParse(_priceController.text);

    if (length != null &&
        width != null &&
        price != null &&
        length > 0 &&
        width > 0 &&
        price > 0) {
      final area = length * width;
      setState(() {
        estimatedCost = area * price;
      });
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please enter valid measurements and price'),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('${widget.surfaceType} Materials'),
        backgroundColor: AppColors.primary,
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              AppColors.surface,
              AppColors.surface.withOpacity(0.8),
            ],
          ),
        ),
          child: SafeArea(
          child: RefreshIndicator(
            onRefresh: () async {
              setState(() {});
              await Future.delayed(const Duration(milliseconds: 300));
            },
            child: SingleChildScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.all(24),
              child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Icon(
                  Icons.calculate_outlined,
                  size: 64,
                  color: AppColors.primary,
                ),
                const SizedBox(height: 16),
                Text(
                  'Select ${widget.surfaceType} Material',
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 32),

                // Material Selection Cards - Grid
                GridView.count(
                  crossAxisCount: 2,
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  mainAxisSpacing: 16,
                  crossAxisSpacing: 16,
                  childAspectRatio: 1.0,
                  children: widget.options.asMap().entries.map((entry) {
                    int index = entry.key;
                    String option = entry.value;
                    return _buildAnimatedMaterialCard(option, index * 150);
                  }).toList(),
                ),

                if (selectedMaterial != null) ...[
                  const SizedBox(height: 32),
                  const Divider(color: Colors.white24),
                  const SizedBox(height: 16),

                  // Measurement Inputs
                  Text(
                    'Enter Measurements (${widget.surfaceType == 'Wall' ? 'Height x Width' : 'Length x Width'})',
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 16),

                  TextField(
                    controller: _lengthController,
                    keyboardType:
                        const TextInputType.numberWithOptions(decimal: true),
                    style: const TextStyle(color: Colors.white),
                    decoration: InputDecoration(
                      labelText: widget.surfaceType == 'Wall'
                          ? 'Height (ft)'
                          : 'Length (ft)',
                      labelStyle: const TextStyle(color: Colors.white70),
                      prefixIcon:
                          const Icon(Icons.straighten, color: Colors.white70),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide:
                            BorderSide(color: Colors.white.withOpacity(0.3)),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide:
                            const BorderSide(color: Colors.white, width: 2),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),

                  TextField(
                    controller: _widthController,
                    keyboardType:
                        const TextInputType.numberWithOptions(decimal: true),
                    style: const TextStyle(color: Colors.white),
                    decoration: InputDecoration(
                      labelText: 'Width (ft)',
                      labelStyle: const TextStyle(color: Colors.white70),
                      prefixIcon:
                          const Icon(Icons.straighten, color: Colors.white70),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide:
                            BorderSide(color: Colors.white.withOpacity(0.3)),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide:
                            const BorderSide(color: Colors.white, width: 2),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),

                  TextField(
                    controller: _priceController,
                    keyboardType:
                        const TextInputType.numberWithOptions(decimal: true),
                    style: const TextStyle(color: Colors.white),
                    decoration: InputDecoration(
                      labelText: 'Price per sq ft (\$)',
                      labelStyle: const TextStyle(color: Colors.white70),
                      prefixIcon:
                          const Icon(Icons.attach_money, color: Colors.white70),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide:
                            BorderSide(color: Colors.white.withOpacity(0.3)),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide:
                            const BorderSide(color: Colors.white, width: 2),
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Calculate Button
                  ElevatedButton.icon(
                    onPressed: _calculateEstimate,
                    icon: const Icon(Icons.calculate),
                    label: const Text('Calculate Estimate'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),

                  // Result Display
                  if (estimatedCost != null) ...[
                    const SizedBox(height: 24),
                    Container(
                      padding: const EdgeInsets.all(24),
                      decoration: BoxDecoration(
                        color: Colors.green.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: Colors.green),
                      ),
                      child: Column(
                        children: [
                          const Icon(
                            Icons.check_circle,
                            color: Colors.green,
                            size: 48,
                          ),
                          const SizedBox(height: 16),
                          const Text(
                            'Estimated Cost',
                            style: TextStyle(
                              fontSize: 18,
                              color: Colors.white70,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            '\$${estimatedCost!.toStringAsFixed(2)}',
                            style: const TextStyle(
                              fontSize: 36,
                              fontWeight: FontWeight.bold,
                              color: Colors.green,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Area: ${(double.parse(_lengthController.text) * double.parse(_widthController.text)).toStringAsFixed(2)} sq ft',
                            style: const TextStyle(
                              fontSize: 14,
                              color: Colors.white70,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ],
              ],
            ),
          ),
        ),
      ),
    ));
  }

  Widget _buildAnimatedMaterialCard(String material, int delay) {
    final isSelected = selectedMaterial == material;
    final String imagePath = _getImageForMaterial(material);

    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0.0, end: 1.0),
      duration: Duration(milliseconds: 500 + delay),
      curve: Curves.easeOutBack,
      builder: (context, value, child) {
        return Transform.scale(
          scale: value,
          child: Opacity(
            opacity: value,
            child: child,
          ),
        );
      },
      child: GestureDetector(
        onTap: () {
          setState(() {
            selectedMaterial = material;
            estimatedCost = null;
            _lengthController.clear();
            _widthController.clear();
            _priceController.clear();
          });
        },
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: isSelected ? AppColors.primary : Colors.transparent,
              width: 3,
            ),
            boxShadow: [
              BoxShadow(
                color: isSelected
                    ? AppColors.primary.withOpacity(0.5)
                    : Colors.black.withOpacity(0.3),
                blurRadius: isSelected ? 15 : 8,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(16),
            child: Stack(
              fit: StackFit.expand,
              children: [
                // Background Image
                if (imagePath.isNotEmpty)
                  Image.asset(
                    imagePath,
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stackTrace) {
                      return Container(
                        color: AppColors.primary.withOpacity(0.3),
                        child: const Icon(
                          Icons.image_not_supported,
                          size: 40,
                          color: Colors.white54,
                        ),
                      );
                    },
                  )
                else
                  Container(
                    color: AppColors.primary.withOpacity(0.3),
                    child: const Icon(
                      Icons.construction,
                      size: 40,
                      color: Colors.white54,
                    ),
                  ),
                // Gradient Overlay
                Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Colors.black.withOpacity(0.2),
                        Colors.black.withOpacity(0.7),
                      ],
                    ),
                  ),
                ),
                // Title
                Positioned(
                  bottom: 0,
                  left: 0,
                  right: 0,
                  child: Container(
                    padding: const EdgeInsets.all(12),
                    color: Colors.black.withOpacity(0.4),
                    child: Text(
                      material,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                        shadows: const [
                          Shadow(
                            color: Colors.black,
                            blurRadius: 4,
                            offset: Offset(0, 2),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                // Selection Check
                if (isSelected)
                  Positioned(
                    top: 8,
                    right: 8,
                    child: Container(
                      padding: const EdgeInsets.all(4),
                      decoration: BoxDecoration(
                        color: AppColors.primary,
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.3),
                            blurRadius: 4,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: const Icon(
                        Icons.check,
                        color: Colors.white,
                        size: 20,
                      ),
                    ),
                  ),
                // Tap Effect
                Material(
                  color: Colors.transparent,
                  child: InkWell(
                    onTap: () {
                      setState(() {
                        selectedMaterial = material;
                        estimatedCost = null;
                        _lengthController.clear();
                        _widthController.clear();
                        _priceController.clear();
                      });
                    },
                    borderRadius: BorderRadius.circular(16),
                    splashColor: Colors.white.withOpacity(0.3),
                    highlightColor: Colors.white.withOpacity(0.1),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildMaterialCard(String material) {
    final isSelected = selectedMaterial == material;
    final IconData icon = _getIconForMaterial(material);

    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Card(
        elevation: isSelected ? 8 : 4,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(
            color: isSelected ? AppColors.primary : Colors.transparent,
            width: 2,
          ),
        ),
        color:
            isSelected ? AppColors.primary.withOpacity(0.3) : AppColors.surface,
        child: InkWell(
          onTap: () {
            setState(() {
              selectedMaterial = material;
              estimatedCost = null;
              _lengthController.clear();
              _widthController.clear();
              _priceController.clear();
            });
          },
          borderRadius: BorderRadius.circular(16),
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Row(
              children: [
                Container(
                  width: 60,
                  height: 60,
                  decoration: BoxDecoration(
                    color: isSelected
                        ? AppColors.primary
                        : Colors.white.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    icon,
                    size: 32,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Text(
                    material,
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight:
                          isSelected ? FontWeight.bold : FontWeight.normal,
                      color: Colors.white,
                    ),
                  ),
                ),
                if (isSelected)
                  const Icon(
                    Icons.check_circle,
                    color: AppColors.primary,
                    size: 32,
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  IconData _getIconForMaterial(String material) {
    switch (material.toLowerCase()) {
      case 'paint':
        return Icons.format_paint;
      case 'putty':
        return Icons.texture;
      case 'tile':
        return Icons.grid_on;
      case 'tile paste':
        return Icons.layers;
      default:
        return Icons.construction;
    }
  }
}
