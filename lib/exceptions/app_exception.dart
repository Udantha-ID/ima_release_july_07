import 'dart:async';
import 'dart:io';

class AppException implements Exception {
  final String message;
  const AppException(this.message);

  @override
  String toString() => message;

  static AppException handle(dynamic e) {
    if (e is AppException) return e;
    if (e is TimeoutException) {
      return const AppException('Request timed out. Please check your connection and retry.');
    }
    if (e is SocketException) {
      return const AppException('No internet connection. Please check your Wi-Fi or mobile data.');
    }
    final msg = e.toString();
    if (msg.contains('Connection timed out') || msg.contains('errno = 110')) {
      return const AppException('Server is unreachable. Please check your internet connection and try again.');
    }
    if (msg.contains('SocketException') || msg.contains('NetworkException')) {
      return const AppException('No internet connection. Please check your Wi-Fi or mobile data.');
    }
    if (msg.contains('TimeoutException') || msg.contains('timed out')) {
      return const AppException('Request timed out. Please check your connection and retry.');
    }
    if (msg.contains('404')) return const AppException('Service not found. Please contact support.');
    if (msg.contains('500')) return const AppException('Server error. Please try again later.');
    return const AppException('Something went wrong. Please try again.');
  }
}
