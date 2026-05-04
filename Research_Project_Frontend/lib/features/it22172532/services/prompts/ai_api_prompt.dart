import 'package:flutter/services.dart' show rootBundle;

/// Loads building-plan prompts from asset text files.
class AiApiPrompt {
  AiApiPrompt._();

  // Backward-compatible constants used by existing screens/services.
  static const String prompt = 'Extract walling, doors, windows, and foundation-relevant measurements from the uploaded building plan images. Return strict JSON only.';

  static const String structuralFramePrompt = 'Extract structural frame column measurements from the same building plan images. Return strict JSON only.';

  static Future<String> loadPrompt() => rootBundle.loadString('assets/OpenAiPrompt/building_plan_prompt.txt');

  static Future<String> loadStructuralFramePrompt() => rootBundle.loadString('assets/OpenAiPrompt/structural_frame_prompt.txt');

}
