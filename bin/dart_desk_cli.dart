import 'dart:io';

import 'package:args/command_runner.dart';
import 'package:dart_desk_cli/src/commands/deploy_command.dart';
import 'package:dart_desk_cli/src/commands/deployments_command.dart';
import 'package:dart_desk_cli/src/commands/login_command.dart';
import 'package:dart_desk_cli/src/commands/logout_command.dart';

void main(List<String> args) async {
  final runner = CommandRunner('dartdesk', 'Dart Desk CLI tool')
    ..addCommand(LoginCommand())
    ..addCommand(LogoutCommand())
    ..addCommand(DeployCommand())
    ..addCommand(DeploymentsCommand());

  try {
    await runner.run(args);
  } on UsageException catch (e) {
    stderr.writeln(e);
    exit(64);
  } catch (e) {
    stderr.writeln('Error: $e');
    exit(1);
  }
}
