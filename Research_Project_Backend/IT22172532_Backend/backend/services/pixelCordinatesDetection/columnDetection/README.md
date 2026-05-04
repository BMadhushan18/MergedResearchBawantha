# Pixel Coordinates Detection Backend

This backend provides an API to detect pixel coordinates of ground floor columns in building plan images using Gemini AI.

## Setup

1. Install dependencies:
   ```bash
   pip install -r requirements.txt
   ```

2. Set up Gemini API key:
   - Set environment variable `GEMINI_API_KEY`
   - Or edit `OpenAiManaging/gemini_secrets.py`

3. Run the server:
   ```bash
   uvicorn main:app --reload
   ```

## API

### POST /api/detect-coordinates

Upload a building plan image and detect coordinates.

**Parameters:**
- `plan_image`: Image file (multipart/form-data)
- `pixel_to_meter`: float (default 0.1)
- `grid_step_pixels`: int (default 20)

**Response:**
```json
{
  "parts": [
    {
      "part_id": "column1",
      "coordinates": {
        "image": "image.png",
        "bbox": [x1, y1, x2, y2]
      }
    }
  ],
  "processed_image_b64": "base64_encoded_image"
}
```