/// Custom Failure Classes for Error Handling
abstract class Failure {
  final String message;
  
  Failure({required this.message});
}

class NetworkFailure extends Failure {
  NetworkFailure({String message = 'Network error occurred'}) : super(message: message);
}

class ServerFailure extends Failure {
  ServerFailure({String message = 'Server error occurred'}) : super(message: message);
}

class CacheFailure extends Failure {
  CacheFailure({String message = 'Cache error occurred'}) : super(message: message);
}

class UnknownFailure extends Failure {
  UnknownFailure({String message = 'Unknown error occurred'}) : super(message: message);
}
