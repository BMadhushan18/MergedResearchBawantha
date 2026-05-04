import os
from typing import Optional, Dict, Any, List, Tuple

from google import genai


class GeminiClient:
    """
    Gemini API client.

    API key/model priority:
    1. Explicit argument (api_key/model)
    2. Environment variable (GEMINI_API_KEY, GEMINI_MODEL)
    3. OpenAiManaging/gemini_secrets.py (local, gitignored)
    """
    def __init__(self, api_key: Optional[str] = None, model: Optional[str] = None):
        try:
            from . import gemini_secrets as _secrets
            _local_key = getattr(_secrets, "GEMINI_API_KEY", None)
            _local_model = getattr(_secrets, "GEMINI_MODEL", None)
        except Exception:
            _local_key = None
            _local_model = None

        self.api_key = (
            api_key or os.getenv("GEMINI_API_KEY") or _local_key or None
        )
        self.model = (
            model or os.getenv("GEMINI_MODEL") or _local_model or "gemini-2.5-flash"
        )
        if not self.api_key:
            raise ValueError(
                "Gemini API key is required. Set GEMINI_API_KEY, pass api_key, or edit OpenAiManaging/gemini_secrets.py."
            )

        # Official Google GenAI client
        self.client = genai.Client(api_key=self.api_key)

    def chat(self, prompt: str, model: Optional[str] = None, max_tokens: int = 512, temperature: float = 0.0) -> Dict[str, Any]:
        # Prefer passing config when available.
        try:
            from google.genai import types

            config = types.GenerateContentConfig(
                max_output_tokens=max_tokens,
                temperature=temperature,
            )
            response = self.client.models.generate_content(
                model=model or self.model,
                contents=prompt,
                config=config,
            )
        except Exception:
            response = self.client.models.generate_content(
                model=model or self.model,
                contents=prompt,
            )

        text = getattr(response, 'text', None)
        return {
            'model': model or self.model,
            'text': text,
        }

    def generate_with_images(
        self,
        prompt: str,
        images: List[Tuple[bytes, str]],
        model: Optional[str] = None,
        max_tokens: int = 4096,
        temperature: float = 0.0,
    ) -> Dict[str, Any]:
        """Generate content from a text prompt plus one or more images.

        Args:
            prompt: Text prompt.
            images: List of (image_bytes, mime_type) tuples.
        """
        from google.genai import types

        parts: List[types.Part] = [types.Part.from_text(text=prompt)]
        for data, mime in images:
            parts.append(types.Part.from_bytes(data=data, mime_type=mime or 'application/octet-stream'))

        contents = [types.Content(role='user', parts=parts)]
        config = types.GenerateContentConfig(
            max_output_tokens=max_tokens,
            temperature=temperature,
        )
        response = self.client.models.generate_content(
            model=model or self.model,
            contents=contents,
            config=config,
        )

        text = getattr(response, 'text', None)
        return {
            'model': model or self.model,
            'text': text,
        }


if __name__ == '__main__':
    import argparse

    parser = argparse.ArgumentParser(description='Call Gemini API.')
    parser.add_argument('--api-key', help='Gemini API key (or set GEMINI_API_KEY)')
    parser.add_argument('--prompt', required=True, help='Text prompt to send')
    parser.add_argument('--model', default='gemini-2.5-flash', help='Model name')
    parser.add_argument('--max-tokens', type=int, default=512)
    parser.add_argument('--temperature', type=float, default=0.0)
    args = parser.parse_args()

    client = GeminiClient(api_key=args.api_key, model=args.model)
    result = client.chat(args.prompt, max_tokens=args.max_tokens, temperature=args.temperature)
    print(result)
