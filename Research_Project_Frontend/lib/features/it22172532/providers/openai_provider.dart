import 'ai_provider_base.dart';

class OpenAIProvider extends AiProviderBase {
  OpenAIProvider()
      : super(
          apiKeyStorageKey: 'openai_api_key',
          modelStorageKey: 'openai_model_name',
        );

  @override
  Future<String> testPrompt(String prompt, {String? model}) async {
    final activeModel = model ?? savedModel ?? 'gpt-5.2';
    if ((apiKey ?? '').isEmpty) {
      throw Exception('No OpenAI API key saved.');
    }
    return 'OpenAI key is saved for model: $activeModel\nTest requests are not implemented in this build.';
  }
}