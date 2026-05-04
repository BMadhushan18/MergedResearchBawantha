class HardcodedPixelCoordinates {
  HardcodedPixelCoordinates._();

  static Map<String, dynamic> get data => {
        'processedAt': DateTime.now().toUtc().toIso8601String(),
        'images': [
          {
            'imageIndex': 0,
            'detectedObjects': [
              // Walls - ground floor exterior
              {
                'class': 'wall',
                'confidence': 0.91,
                'polygon': [
                  [82, 140], [620, 140], [620, 165], [82, 165]
                ],
                'bbox': [82, 140, 620, 165],
              },
              {
                'class': 'wall',
                'confidence': 0.89,
                'polygon': [
                  [82, 140], [107, 140], [107, 580], [82, 580]
                ],
                'bbox': [82, 140, 107, 580],
              },
              {
                'class': 'wall',
                'confidence': 0.88,
                'polygon': [
                  [620, 140], [645, 140], [645, 580], [620, 580]
                ],
                'bbox': [620, 140, 645, 580],
              },
              {
                'class': 'wall',
                'confidence': 0.90,
                'polygon': [
                  [82, 555], [620, 555], [620, 580], [82, 580]
                ],
                'bbox': [82, 555, 620, 580],
              },
              // Interior partition walls
              {
                'class': 'wall',
                'confidence': 0.84,
                'polygon': [
                  [280, 140], [305, 140], [305, 380], [280, 380]
                ],
                'bbox': [280, 140, 305, 380],
              },
              {
                'class': 'wall',
                'confidence': 0.82,
                'polygon': [
                  [82, 370], [480, 370], [480, 395], [82, 395]
                ],
                'bbox': [82, 370, 480, 395],
              },
              {
                'class': 'wall',
                'confidence': 0.81,
                'polygon': [
                  [460, 370], [485, 370], [485, 580], [460, 580]
                ],
                'bbox': [460, 370, 485, 580],
              },
              {
                'class': 'wall',
                'confidence': 0.80,
                'polygon': [
                  [280, 370], [460, 370], [460, 395], [280, 395]
                ],
                'bbox': [280, 370, 460, 395],
              },
              // Doors
              {
                'class': 'door',
                'confidence': 0.86,
                'polygon': [
                  [200, 555], [260, 555], [260, 580], [200, 580]
                ],
                'bbox': [200, 555, 260, 580],
              },
              {
                'class': 'door',
                'confidence': 0.83,
                'polygon': [
                  [280, 230], [305, 230], [305, 290], [280, 290]
                ],
                'bbox': [280, 230, 305, 290],
              },
              {
                'class': 'door',
                'confidence': 0.80,
                'polygon': [
                  [460, 440], [485, 440], [485, 500], [460, 500]
                ],
                'bbox': [460, 440, 485, 500],
              },
              {
                'class': 'door',
                'confidence': 0.79,
                'polygon': [
                  [350, 370], [410, 370], [410, 395], [350, 395]
                ],
                'bbox': [350, 370, 410, 395],
              },
              {
                'class': 'door',
                'confidence': 0.77,
                'polygon': [
                  [530, 555], [580, 555], [580, 580], [530, 580]
                ],
                'bbox': [530, 555, 580, 580],
              },
              // Windows
              {
                'class': 'window',
                'confidence': 0.85,
                'polygon': [
                  [130, 140], [220, 140], [220, 165], [130, 165]
                ],
                'bbox': [130, 140, 220, 165],
              },
              {
                'class': 'window',
                'confidence': 0.83,
                'polygon': [
                  [340, 140], [440, 140], [440, 165], [340, 165]
                ],
                'bbox': [340, 140, 440, 165],
              },
              {
                'class': 'window',
                'confidence': 0.81,
                'polygon': [
                  [500, 140], [600, 140], [600, 165], [500, 165]
                ],
                'bbox': [500, 140, 600, 165],
              },
              {
                'class': 'window',
                'confidence': 0.80,
                'polygon': [
                  [620, 200], [645, 200], [645, 280], [620, 280]
                ],
                'bbox': [620, 200, 645, 280],
              },
              {
                'class': 'window',
                'confidence': 0.79,
                'polygon': [
                  [620, 410], [645, 410], [645, 500], [620, 500]
                ],
                'bbox': [620, 410, 645, 500],
              },
              {
                'class': 'window',
                'confidence': 0.77,
                'polygon': [
                  [130, 555], [190, 555], [190, 580], [130, 580]
                ],
                'bbox': [130, 555, 190, 580],
              },
            ],
          },
        ],
        'summary': {
          'totalWalls': 8,
          'totalDoors': 5,
          'totalWindows': 6,
          'source': 'hardcoded pixel coordinates demo record',
        },
      };
}
