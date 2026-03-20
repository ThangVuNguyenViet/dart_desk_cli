import 'dart:convert';
import 'dart:io';
import 'package:path/path.dart' as p;

class Credentials {
  final String token;
  final DateTime expiresAt;

  Credentials({required this.token, required this.expiresAt});

  bool get isExpired => DateTime.now().isAfter(expiresAt);

  static String get _credentialsDir =>
      p.join(Platform.environment['HOME'] ?? '.', '.dart_desk');

  static String get _credentialsPath =>
      p.join(_credentialsDir, 'credentials.json');

  static Credentials? load() {
    final file = File(_credentialsPath);
    if (!file.existsSync()) return null;

    try {
      final json = jsonDecode(file.readAsStringSync()) as Map<String, dynamic>;
      return Credentials(
        token: json['token'] as String,
        expiresAt: DateTime.parse(json['expiresAt'] as String),
      );
    } catch (_) {
      return null;
    }
  }

  static void save(String token, DateTime expiresAt) {
    final dir = Directory(_credentialsDir);
    if (!dir.existsSync()) dir.createSync(recursive: true);

    final file = File(_credentialsPath);
    file.writeAsStringSync(jsonEncode({
      'token': token,
      'expiresAt': expiresAt.toIso8601String(),
    }));

    Process.runSync('chmod', ['600', _credentialsPath]);
  }

  static void delete() {
    final file = File(_credentialsPath);
    if (file.existsSync()) file.deleteSync();
  }
}
