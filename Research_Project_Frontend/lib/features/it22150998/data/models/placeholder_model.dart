/// Placeholder Model for IT22150998 Feature
class PlaceholderModel {
  final String id;
  final String name;
  final String description;
  
  PlaceholderModel({
    required this.id,
    required this.name,
    required this.description,
  });
  
  factory PlaceholderModel.fromJson(Map<String, dynamic> json) {
    return PlaceholderModel(
      id: json['id'] as String,
      name: json['name'] as String,
      description: json['description'] as String,
    );
  }
  
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'description': description,
    };
  }
}
