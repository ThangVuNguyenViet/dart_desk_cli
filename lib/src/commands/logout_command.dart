import 'package:args/command_runner.dart';
import 'dart:io';

import '../credentials.dart';

class LogoutCommand extends Command {
  @override
  String get name => 'logout';

  @override
  String get description => 'Clear saved credentials';

  @override
  void run() {
    Credentials.delete();
    stdout.writeln('Logged out successfully.');
  }
}
