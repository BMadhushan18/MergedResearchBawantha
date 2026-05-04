import 'ai_provider_base.dart';
import '../services/ai_service.dart';

class AiProvider extends AiProviderBase {
  AiProvider()
      : super(
          apiKeyStorageKey: 'ai_api_key',
          modelStorageKey: 'ai_model_name',
        );

  @override
  Future<String> testPrompt(String prompt, {String? model}) async {
    final result = await AiService().generateContent(
      preferredModel: model ?? savedModel ?? 'gemini-2.0-flash',
      contents: [
        {
          'role': 'user',
          'parts': [
            {'text': prompt},
          ],
        }
      ],
    );

    return result.text;
  }
}