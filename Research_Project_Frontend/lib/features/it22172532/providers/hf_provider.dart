import 'ai_provider_base.dart';

class HfProvider extends AiProviderBase {
  HfProvider()
      : super(
          apiKeyStorageKey: 'hf_api_key',
          modelStorageKey: 'hf_model_name',
        );

  @override
  Future<String> testPrompt(String prompt, {String? model}) async {
    final activeModel = model ?? savedModel ?? 'meta-llama/Llama-4-Scout-17B-16E-Instruct:groq';
    if ((apiKey ?? '').isEmpty) {
      throw Exception('No HuggingFace API key saved.');
    }
    return 'HuggingFace key is saved for model: $activeModel\nTest requests are not implemented in this build.';
  }
}