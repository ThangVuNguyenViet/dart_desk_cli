import 'dart:async';
import 'dart:io';

import 'package:args/command_runner.dart';

import '../config.dart';
import '../credentials.dart';

class LoginCommand extends Command {
  @override
  String get name => 'login';

  @override
  String get description => 'Authenticate with Dart Desk cloud via browser';

  LoginCommand() {
    argParser.addOption('server', help: 'Server URL (overrides dart_desk.yaml)');
  }

  @override
  Future<void> run() async {
    String server;
    try {
      final config = CmsConfig.load();
      server = config.server;
    } catch (_) {
      server = argResults?['server'] ?? 'https://api.dartdesk.dev';
    }

    if (argResults?['server'] != null) {
      server = argResults!['server'];
    }

    stdout.writeln('Opening browser for authentication...');

    final httpServer = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    final port = httpServer.port;
    final completer = Completer<String>();

    httpServer.listen((request) {
      if (request.uri.path == '/callback') {
        final token = request.uri.queryParameters['token'];
        if (token != null) {
          request.response
            ..statusCode = HttpStatus.ok
            ..headers.contentType = ContentType.html
            ..write('<html><body><h2>Authenticated!</h2>'
                '<p>You can close this window and return to the terminal.</p>'
                '</body></html>');
          request.response.close();
          completer.complete(token);
        } else {
          request.response
            ..statusCode = HttpStatus.badRequest
            ..write('Missing token');
          request.response.close();
          completer.completeError('No token received');
        }
      }
    });

    final authUrl = '$server/auth/cli?redirect=http://localhost:$port/callback';
    await _openBrowser(authUrl);
    stdout.writeln('Waiting for authentication (URL: $authUrl)...');

    try {
      final token = await completer.future.timeout(
        const Duration(minutes: 5),
        onTimeout: () => throw TimeoutException('Authentication timed out'),
      );

      final expiresAt = DateTime.now().add(const Duration(days: 90));
      Credentials.save(token, expiresAt);

      stdout.writeln('Authenticated successfully!');
    } finally {
      await httpServer.close();
    }
  }

  Future<void> _openBrowser(String url) async {
    if (Platform.isMacOS) {
      await Process.run('open', [url]);
    } else if (Platform.isLinux) {
      await Process.run('xdg-open', [url]);
    } else if (Platform.isWindows) {
      await Process.run('start', [url], runInShell: true);
    }
  }
}
