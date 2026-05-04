# OpenAiManaging

This folder contains Simple Gemini API integration helper.

## Usage


1. Configure Gemini API key/model (choose one):

**A. Local file (recommended for dev):**
	- Edit `OpenAiManaging/gemini_secrets.py` (created for you, gitignored)
	- Set:
		- `GEMINI_API_KEY = "YOUR_KEY_HERE"`
		- `GEMINI_MODEL = "gemini-2.5-flash"` (optional)

**B. Environment variable:**
	- `export GEMINI_API_KEY='YOUR_KEY_HERE'`
	- `export GEMINI_MODEL='gemini-2.5-flash'` (optional)

2. run:

```bash
python gemini_api.py --prompt "Hello world" --model gemini-1.0
```

3. or from python:

```python
from gemini_api import GeminiClient
client = GeminiClient(api_key='YOUR_KEY')
resp = client.chat('Describe a simple plan widget', model='gemini-1.0')
print(resp)
```

## API key mode

- If you pass `--api-key` it will use that.
- Otherwise it expects `GEMINI_API_KEY` env var.
