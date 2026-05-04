class UpperFloorAnalyis {
  UpperFloorAnalyis._();

  static Map<String, dynamic> get groundFloorWalling => {
        'output': {
          'scaleText': '1/8" = 1\'-0"',
          'units': 'ft',
          'defaultWallHeight': '10\'-0"',
          'floorAreaReported': '1735.87 sq.ft.',
          'totalWalls': 12,
        },
        'groundFloor': {
          'floorArea': {
            'value': 1735.87,
            'unit': 'sq.ft',
            'source': 'hardcoded ground floor analysis',
          },
          'rooms': {
            'A': {'name': 'Living & Dining'},
            'B': {'name': 'Bedroom', 'width': '13\'-0"', 'depth': '11\'-3"'},
            'C': {'name': 'Bedroom', 'width': '17\'-0"', 'depth': '14\'-1"'},
            'D': {
              'name': 'Kitchen & Pantry',
              'width': '14\'-0"',
              'depth': '13\'-6"'
            },
            'GF_TOILET_1': {
              'name': 'Toilet',
              'width': '6\'-0"',
              'depth': '5\'-6"'
            },
            'GF_TOILET_2': {
              'name': 'Toilet',
              'width': '9\'-6"',
              'depth': '4\'-10"'
            },
            'LAUNDRY': {
              'name': 'Laundry',
              'width': '7\'-2"',
              'depth': '4\'-2"'
            },
          },
          'walls': {
            'GF_NORTH_01': {
              'location': 'north exterior, living/kitchen side',
              'length': '14\'-0"',
              'width': '9 inch',
              'material': 'brick masonry',
              'type': 'exterior',
              'confidence': 0.9,
            },
            'GF_NORTH_02': {
              'location': 'north exterior, open-to-sky bay',
              'length': '9\'-0"',
              'width': '9 inch',
              'material': 'brick masonry',
              'type': 'exterior',
              'confidence': 0.9,
            },
            'GF_NORTH_03': {
              'location': 'north exterior, bedroom C',
              'length': '17\'-0"',
              'width': '9 inch',
              'material': 'brick masonry',
              'type': 'exterior',
              'confidence': 0.9,
            },
            'GF_NORTH_04': {
              'location': 'north exterior, bedroom B',
              'length': '13\'-0"',
              'width': '9 inch',
              'material': 'brick masonry',
              'type': 'exterior',
              'confidence': 0.9,
            },
            'GF_SOUTH_01': {
              'location': 'south exterior, living frontage',
              'length': '25\'-0"',
              'width': '9 inch',
              'material': 'brick masonry',
              'type': 'exterior',
              'confidence': 0.92,
            },
            'GF_SOUTH_02': {
              'location': 'south exterior, toilet bay',
              'length': '6\'-0"',
              'width': '9 inch',
              'material': 'brick masonry',
              'type': 'exterior',
              'confidence': 0.88,
            },
            'GF_SOUTH_03': {
              'location': 'south exterior, laundry bay',
              'length': '7\'-2"',
              'width': '9 inch',
              'material': 'brick masonry',
              'type': 'exterior',
              'confidence': 0.88,
            },
            'GF_EAST_01': {
              'location': 'east exterior near bedroom B/passage',
              'length': '13\'-11"',
              'width': '9 inch',
              'material': 'brick masonry',
              'type': 'exterior',
              'confidence': 0.86,
            },
            'GF_WEST_01': {
              'location': 'west exterior living side',
              'length': '29\'-6"',
              'width': '9 inch',
              'material': 'brick masonry',
              'type': 'exterior',
              'confidence': 0.86,
            },
            'GF_PARTITION_01': {
              'location': 'kitchen to passage partition',
              'length': '3\'-11"',
              'width': '4.5 inch',
              'material': 'brick partition',
              'type': 'interior',
              'confidence': 0.82,
            },
            'GF_PARTITION_02': {
              'location': 'passage at laundry/toilet',
              'length': '3\'-6"',
              'width': '4.5 inch',
              'material': 'brick partition',
              'type': 'interior',
              'confidence': 0.82,
            },
            'GF_PARTITION_03': {
              'location': 'toilet divider',
              'length': '2\'-8"',
              'width': '4.5 inch',
              'material': 'brick partition',
              'type': 'interior',
              'confidence': 0.78,
            },
          },
        },
        'doors': {
          'D1': {
            'width': '4\'-6"',
            'height': '9\'-0"',
            'material': 'Timber Paneled Door',
            'location': 'Ground floor main entrance',
          },
          'D2': {
            'width': '3\'-0"',
            'height': '9\'-0"',
            'material': 'Timber Paneled Door',
            'location': 'External side doors',
          },
          'D3': {
            'width': '2\'-9"',
            'height': '7\'-6"',
            'material': 'Aluminium Door',
            'location': 'Bedroom and internal room doors',
          },
          'D4': {
            'width': '2\'-6"',
            'height': '6\'-6"',
            'material': 'Aluminium Door',
            'location': 'Toilet doors',
          },
        },
        'windows': {
          'FW': {
            'width': '13\'-6"',
            'height': '9\'-0"',
            'material': 'Timber Glazed French Window',
            'location': 'French window openings',
          },
          'FW1': {
            'width': '12\'-0"',
            'height': '9\'-0"',
            'material': 'Timber Glazed French Window',
            'location': 'Ground frontage openings',
          },
          'W5': {
            'width': '7\'-0"',
            'height': '6\'-0"',
            'material': 'Timber Glazed Window',
            'location': 'Open-to-sky / kitchen window',
          },
          'FL': {
            'width': '1\'-6"',
            'height': '4\'-0"',
            'material': 'Timber Glazed Fanlight',
            'location': 'Toilet/laundry fanlights',
          },
        },
        'extractionWarnings': [
          'Hardcoded ground floor measurement record used for demo analysis.',
        ],
      };

  static Map<String, dynamic> get upperFloorWalling {
    final data = groundFloorWalling;
    data['output'] = {
      ...Map<String, dynamic>.from(data['output'] as Map),
      'totalWalls': 18,
    };
    data['upperFloor'] = {
      'floorArea': {
        'value': 1735.87,
        'unit': 'sq.ft',
        'source': 'hardcoded upper floor analysis',
      },
      'rooms': {
        'F': {
          'name': 'Master Bedroom',
          'width': '16\'-1 1/2"',
          'depth': '21\'-8"'
        },
        'G': {'name': 'Bedroom', 'width': '14\'-0"', 'depth': '15\'-10"'},
        'H': {'name': 'Bedroom', 'width': '17\'-0"', 'depth': '11\'-3"'},
        'I': {'name': 'Pantry', 'depth': '15\'-9"'},
        'E': {'name': 'Lobby', 'width': '8\'-6"'},
      },
      'walls': {
        'UF_NORTH_01': {
          'location': 'upper north exterior left',
          'length': '14\'-1"',
          'height': '7\'-0"',
          'width': '9 inch',
          'type': 'exterior',
          'confidence': 0.86,
        },
        'UF_NORTH_02': {
          'location': 'upper north exterior mid-left',
          'length': '10\'-10 1/2"',
          'width': '9 inch',
          'type': 'exterior',
          'confidence': 0.84,
        },
        'UF_NORTH_03': {
          'location': 'upper north exterior bedroom G',
          'length': '14\'-0"',
          'width': '9 inch',
          'type': 'exterior',
          'confidence': 0.86,
        },
        'UF_NORTH_04': {
          'location': 'upper north exterior open-to-sky',
          'length': '9\'-0"',
          'width': '9 inch',
          'type': 'exterior',
          'confidence': 0.86,
        },
        'UF_NORTH_05': {
          'location': 'upper north exterior bedroom H',
          'length': '17\'-0"',
          'width': '9 inch',
          'type': 'exterior',
          'confidence': 0.86,
        },
        'UF_NORTH_06': {
          'location': 'upper north exterior pantry',
          'length': '13\'-0"',
          'height': '7\'-0"',
          'width': '9 inch',
          'type': 'exterior',
          'confidence': 0.82,
        },
      },
    };
    data['extractionWarnings'] = [
      'Hardcoded ground and upper floor measurement record used for demo analysis.',
    ];
    return data;
  }

  static Map<String, dynamic> get groundFloorStructuralFrame => {
        'output': {
          'units': 'm',
          'totalColumns': 5,
          'columnHeight': 3.05,
        },
        'groundFloor': {
          'floorAreaReported': '1735.87 sq.ft.',
          'columnHeight': '10\'-0" typical above slab',
          'slab': {
            'groundFloor': {
              'thickness': '5 inch',
              'material': 'R.C.C. slab',
              'source': 'hardcoded analysis',
            },
          },
          'columns': {
            'C1': {
              'width': 0.225,
              'length': 0.225,
              'height': 3.35,
              'size': '9x9 inch',
              'material': 'RCC',
              'location': 'living/dining left bay',
            },
            'C2': {
              'width': 0.225,
              'length': 0.225,
              'height': 3.35,
              'size': '9x9 inch',
              'material': 'RCC',
              'location': 'kitchen/living junction',
            },
            'C3': {
              'width': 0.225,
              'length': 0.225,
              'height': 3.05,
              'size': '9x9 inch',
              'material': 'RCC',
              'location': 'open-to-sky/toilet bay',
            },
            'C4': {
              'width': 0.225,
              'length': 0.225,
              'height': 3.05,
              'size': '9x9 inch',
              'material': 'RCC',
              'location': 'bedroom C/B divider',
            },
            'C5': {
              'width': 0.225,
              'length': 0.225,
              'height': 3.05,
              'size': '9x9 inch',
              'material': 'RCC',
              'location': 'east end passage/bedroom B',
            },
          },
        },
        'notes': ['Hardcoded ground floor structural frame record.'],
      };

  static Map<String, dynamic> get upperFloorStructuralFrame {
    final data = groundFloorStructuralFrame;
    data['upperFloor'] = {
      'slab': {
        'thickness': '5 inch',
        'material': 'R.C.C. slab',
        'source': 'hardcoded analysis',
      },
      'columns': {
        'UC1': {
          'width': 0.225,
          'length': 0.225,
          'height': 3.05,
          'material': 'RCC'
        },
        'UC2': {
          'width': 0.225,
          'length': 0.225,
          'height': 3.05,
          'material': 'RCC'
        },
        'UC3': {
          'width': 0.225,
          'length': 0.225,
          'height': 3.05,
          'material': 'RCC'
        },
      },
    };
    data['notes'] = [
      'Hardcoded ground and upper floor structural frame record.'
    ];
    return data;
  }

  static Map<String, dynamic> get groundFloorBuildingStructure => {
        ...groundFloorWalling,
        'levels': {
          'groundFloor': {
            'plinthHeight': '1\'-6"',
            'clearHeight': '10\'-0"',
            'slabThickness': '5 inch',
          },
        },
        'foundation': {
          'type': 'rubble masonry strip foundation',
          'depth': '2\'-6"',
          'width': '2\'-0"',
          'source': 'hardcoded analysis',
        },
      };

  static Map<String, dynamic> get upperFloorBuildingStructure => {
        ...upperFloorWalling,
        'levels': {
          'groundFloor': {
            'plinthHeight': '1\'-6"',
            'clearHeight': '10\'-0"',
            'slabThickness': '5 inch',
          },
          'upperFloor': {
            'clearHeight': '10\'-0"',
            'slabThickness': '5 inch',
          },
        },
        'foundation': {
          'type': 'rubble masonry strip foundation',
          'depth': '2\'-6"',
          'width': '2\'-0"',
          'source': 'hardcoded analysis',
        },
      };

  static Map<String, dynamic> get finishing => {
        'roof': [
          {
            'description': 'Asbestos sheet roof',
            'material': 'Asbestos sheet',
            'specification': 'Sloped roof covering from sections',
          },
          {
            'description': 'Ridge tile',
            'material': 'Ridge tile',
            'specification': 'Roof ridge finish',
          },
        ],
        'flooring': [
          {
            'description': '3 inch thick concrete paving',
            'thickness': '3 inch',
            'material': 'Concrete',
          },
          {
            'description': 'Dry earth filling',
            'material': 'Earth fill',
          },
        ],
        'slabs': [
          {
            'description': '5 inch thick R.C.C. slab',
            'thickness': '5 inch',
            'material': 'Reinforced cement concrete',
          },
        ],
        'walls': [
          {
            'description': '7\'-0" high parapet wall',
            'height': '7\'-0"',
            'material': 'Masonry',
          },
        ],
      };
}
