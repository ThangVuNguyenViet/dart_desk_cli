# dart_desk_cli

Command-line interface for deploying and managing self-hosted Dart Desk CMS instances.

## Installation

```bash
dart pub global activate dart_desk_cli
```

## Configuration

Create a `dart_desk.yaml` file in your project root:

```yaml
server_url: https://your-server.example.com
```

## Commands

| Command | Description |
|---------|-------------|
| `dart_desk login` | Authenticate with your Dart Desk server |
| `dart_desk logout` | Clear stored credentials |
| `dart_desk deploy` | Deploy your CMS studio to the server |
| `dart_desk deployments` | List existing deployments |

## Usage

```bash
# Log in to your server
dart_desk login

# Deploy the current project
dart_desk deploy

# View deployments
dart_desk deployments
```

## License

Business Source License 1.1 - see [LICENSE](LICENSE) for details.
