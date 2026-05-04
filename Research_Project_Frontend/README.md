# Research_Project_Frontend

A modern, scalable Flutter application for Smart BOQ Prediction with team-based feature development and clean architecture principles.

## Table of Contents
- [Overview](#overview)
- [Project Structure](#project-structure)
- [Getting Started](#getting-started)
- [Team Guidelines](#team-guidelines)
- [Development Setup](#development-setup)
- [Dependencies](#dependencies)
- [API Integration](#api-integration)
- [State Management](#state-management)
- [Routing](#routing)
- [Contributing](#contributing)

## Overview

**Research_Project_Frontend** is a Flutter-based intelligent prediction system that integrates seamlessly with a Python backend. It follows modern software engineering practices including:

- **Feature-First Architecture**: Each team member owns an isolated feature module
- **Clean Architecture**: Separation of concerns (Presentation, Domain, Data)
- **Scalability**: Easy to add new features without touching existing code
- **Team Collaboration**: Minimal merge conflicts through clear folder structure
- **Professional Standards**: State management, dependency injection, and testing-ready code

## Project Structure

```
lib/
├── main.dart                      # App entry point
├── app.dart                       # MaterialApp configuration
│
├── core/                          # Shared by everyone
│   ├── config/                    # App configuration
│   ├── constants/                 # Colors, strings, routes, sizes
│   ├── di/                        # Dependency injection setup
│   ├── network/                   # API client (Dio)
│   ├── theme/                     # App theming
│   ├── utils/                     # Helpers, extensions, validators
│   ├── errors/                    # Failure classes, exceptions
│   └── widgets/                   # Global reusable widgets
│
├── common/                        # Shared screens and logic
│   ├── screens/
│   │   ├── login_screen.dart
│   │   ├── signup_screen.dart
│   │   ├── home_screen.dart
│   │   └── splash_screen.dart
│   ├── widgets/
│   ├── models/
│   └── repository/
│
├── features/                      # Each team member's module
│   ├── it22196460/                # Smart BOQ Predictor (Frontend Owner)
│   │   ├── data/
│   │   │   ├── models/
│   │   │   ├── datasources/
│   │   │   └── repositories/
│   │   ├── domain/
│   │   └── presentation/
│   │       ├── screens/
│   │       ├── widgets/
│   │       └── providers/
│   │
│   ├── it22150998/                # Member 2
│   ├── it22172532/                # Member 3
│   └── it22574718/                # Member 4
│
├── routing/                       # Central routing
│   └── app_router.dart
│
└── shared/                        # Optional shared utilities
    └── widgets/
```

## Getting Started

### Prerequisites
- Flutter SDK (latest stable version)
- Dart 3.0+
- Git
- IDE: Android Studio, VS Code, or IntelliJ IDEA

### Installation

1. **Clone the repository**
   ```bash
   git clone https://github.com/yourusername/Research_Project_Frontend.git
   cd Research_Project_Frontend
   ```

2. **Install dependencies**
   ```bash
   flutter pub get
   ```

3. **Run the app**
   ```bash
   flutter run
   ```

### First Run
- Android: `flutter run -d android`
- iOS: `flutter run -d ios`
- Web: `flutter run -d chrome`

## Team Guidelines

### For the Frontend Owner (IT22196460)
- Maintain `core/` and `common/` folders
- Manage `routing/app_router.dart`
- Review and coordinate dependency updates
- Own `features/it22196460/` (Smart BOQ Predictor)

### For Other Team Members
- Work **ONLY** inside your feature folder (`features/it[YOUR_ID]/`)
- Follow the same internal structure (data/, domain/, presentation/)
- Tell the Frontend Owner your screen routes
- Never modify other members' code without permission

### Merge Conflict Prevention
- Each member touches only their own feature folder
- Coordinate any changes to `core/` and `common/`
- Use feature branches: `feature/it22[ID]/feature-name`
- Create Pull Requests for review before merging

## Development Setup

### 1. Configure API Connection
Edit `core/network/api_service.dart`:
```dart
const String BACKEND_BASE_URL = 'http://192.168.x.x:8000'; // Python backend
```

### 2. Set Up Local Storage (Hive)
The app uses Hive for offline data. Initialize in `main.dart`:
```dart
await Hive.initFlutter();
await Hive.openBox('app_data');
```

### 3. State Management with Riverpod
Providers are organized inside each feature's `presentation/providers/` folder.

Example:
```dart
// features/it22196460/presentation/providers/prediction_provider.dart
final predictionProvider = FutureProvider((ref) async {
  // Fetch prediction from API
});
```

## Dependencies

Core dependencies managed in `pubspec.yaml`:

```yaml
dependencies:
  flutter:
    sdk: flutter
  
  # Routing
  go_router: ^14.0.0
  
  # State Management
  flutter_riverpod: ^2.5.1
  
  # HTTP Client
  dio: ^5.7.0
  
  # Local Storage
  hive: ^2.2.3
  hive_flutter: ^1.1.0
  
  # UI/UX
  path_provider: ^2.1.4
  
  # Others (add as needed)
```

To add a new dependency:
```bash
flutter pub add package_name
```

## API Integration

### Backend Connection
The Python backend runs at `http://localhost:8000` (or your configured URL).

### Making API Calls
Use the centralized API service in `core/network/`:

```dart
import 'package:dio/dio.dart';

// In your repository
final response = await apiService.post(
  '/api/predict',
  data: {
    'boq_data': boqInput,
  },
);
```

### Example: BOQ Prediction Call
```dart
// features/it22196460/data/repositories/prediction_repository.dart
Future<PredictionResponse> getPrediction(BOQInput input) async {
  try {
    final response = await dio.post(
      '/api/predict',
      data: input.toJson(),
    );
    return PredictionResponse.fromJson(response.data);
  } catch (e) {
    throw Exception('Failed to fetch prediction');
  }
}
```

## State Management

### Using Riverpod

**Provider Definition:**
```dart
final predictionProvider = FutureProvider<PredictionResponse>((ref) async {
  final repository = ref.read(predictionRepositoryProvider);
  return repository.getPrediction(input);
});
```

**Using in UI:**
```dart
@override
Widget build(BuildContext context, WidgetRef ref) {
  final prediction = ref.watch(predictionProvider);
  
  return prediction.when(
    data: (data) => Text(data.cost),
    loading: () => CircularProgressIndicator(),
    error: (err, st) => Text('Error: $err'),
  );
}
```

## Routing

All routes are defined in `routing/app_router.dart`:

```dart
final appRouter = GoRouter(
  routes: [
    GoRoute(
      path: '/login',
      builder: (context, state) => LoginScreen(),
    ),
    GoRoute(
      path: '/home',
      builder: (context, state) => HomeScreen(),
    ),
    GoRoute(
      path: '/prediction',
      builder: (context, state) => PredictionScreen(),
    ),
  ],
);
```

To add a new route:
1. Create your screen in your feature folder
2. Tell the Frontend Owner
3. Frontend Owner adds route in `app_router.dart`

## Testing

Run unit and widget tests:
```bash
flutter test
```

Tests should be placed in `test/` directory, mirroring the `lib/` structure.

## Building for Production

### Android
```bash
flutter build apk --release
# Or for app bundle
flutter build appbundle --release
```

### iOS
```bash
flutter build ios --release
```

### Web
```bash
flutter build web --release
```

## Troubleshooting

### Build Issues
```bash
flutter clean
flutter pub get
flutter pub upgrade
flutter run
```

### Hive Issues
If Hive boxes fail to open:
```bash
flutter clean
flutter pub get
```

### API Connection Issues
- Verify Python backend is running
- Check your `BACKEND_BASE_URL` configuration
- Verify firewall settings

## Contributing

1. Create a feature branch from `develop`:
   ```bash
   git checkout -b feature/it22[YOUR_ID]/feature-name
   ```

2. Make your changes in your feature folder only

3. Commit with clear messages:
   ```bash
   git commit -m "feat(it22[YOUR_ID]): Add new feature"
   ```

4. Push and create a Pull Request:
   ```bash
   git push origin feature/it22[YOUR_ID]/feature-name
   ```

5. Code review by Frontend Owner before merge

## Resources

- [Flutter Documentation](https://flutter.dev/docs)
- [Riverpod Documentation](https://riverpod.dev)
- [GoRouter Documentation](https://pub.dev/packages/go_router)
- [Clean Architecture Guide](https://resocoder.com/flutter-clean-architecture)

## License

This project is part of the Research Project. All rights reserved.

## Contact

For questions or issues, contact the Frontend Owner (IT22196460).

---

**Last Updated**: March 2026
**Version**: 1.0.0
