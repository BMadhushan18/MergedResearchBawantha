import 'package:flutter/material.dart';

/// Prediction Input Widget for IT22196460 Feature
class PredictionInputWidget extends StatefulWidget {
  const PredictionInputWidget({Key? key}) : super(key: key);
  
  @override
  State<PredictionInputWidget> createState() => _PredictionInputWidgetState();
}

class _PredictionInputWidgetState extends State<PredictionInputWidget> {
  late TextEditingController _inputController;
  
  @override
  void initState() {
    super.initState();
    _inputController = TextEditingController();
  }
  
  @override
  void dispose() {
    _inputController.dispose();
    super.dispose();
  }
  
  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        TextField(
          controller: _inputController,
          decoration: const InputDecoration(
            labelText: 'BOQ Data',
            border: OutlineInputBorder(),
          ),
          maxLines: 5,
        ),
        const SizedBox(height: 16),
        ElevatedButton(
          onPressed: () {
            // Handle prediction
          },
          child: const Text('Predict'),
        ),
      ],
    );
  }
}
