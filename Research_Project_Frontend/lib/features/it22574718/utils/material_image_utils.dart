String? matImagePath(String materialName) {
  final slug = _slug(materialName);
  if (slug.isEmpty) return null;
  return 'AppImages/materials/$slug.png';
}

String? brandLogoPath(String brandName) {
  final slug = _slug(brandName);
  if (slug.isEmpty) return null;
  return 'AppImages/brands/$slug.png';
}

String _slug(String value) {
  return value
      .trim()
      .toLowerCase()
      .replaceAll('&', 'and')
      .replaceAll(RegExp(r'[^a-z0-9]+'), '_')
      .replaceAll(RegExp(r'_+'), '_')
      .replaceAll(RegExp(r'^_|_$'), '');
}