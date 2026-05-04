"""groundFloorImageFilterPrompt.py

Prompt used to filter user-uploaded images down to only:
- Ground floor plan
- Section X-X
- Section Y-Y

The model must return the selected filenames so the backend can attach ONLY those
images to subsequent extraction prompts.
"""

groundFloorImageFilterPrompt = r'''
ROLE
You are an expert architectural drawing classifier.

TASK
You will receive multiple uploaded plan images. Identify which images correspond to:
1) Ground floor plan (top view)
2) Section X-X
3) Section Y-Y

OUTPUT FORMAT (STRICT)
Return VALID JSON ONLY (no markdown, no extra text):
{{
  "ground_floor": ["<filename>", "<filename>"] ,
  "section_xx": ["<filename>"] ,
  "section_yy": ["<filename>"]
}}

RULES
- Choose filenames ONLY from the provided list.
- If you are not sure for a category, return an empty array for that category.
- Prefer images that visibly contain the title/label (e.g., "GROUND FLOOR PLAN", "SECTION X-X", "SECTION Y-Y").

AVAILABLE IMAGES
{image_list}
'''
