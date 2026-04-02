# dart_desk_cli

Command-line interface for deploying and managing Dart Desk CMS studios.

## Installation

```bash
dart pub global activate dart_desk_cli
```

## Configuration

Create a `dart_desk.yaml` file in your project root:

```yaml
project_id: my-project
# server: https://api.dartdesk.dev  # Optional. Defaults to Dart Desk Cloud.
```

## Commands

| Command | Description |
|---------|-------------|
| `dartdesk login` | Authenticate with your Dart Desk server |
| `dartdesk logout` | Clear stored credentials |
| `dartdesk deploy` | Build and deploy your CMS studio |
| `dartdesk deployments list` | List deployment history |
| `dartdesk deployments rollback -v <version>` | Activate a previous deployment |

## Usage

```bash
# Log in to your server
dartdesk login

# Deploy the current project
dartdesk deploy

# Skip build and upload existing build/web/
dartdesk deploy --skip-build

# View deployments
dartdesk deployments list
```

## GitHub Actions

Use the `--token` flag to deploy from CI without interactive login. Store your API token as a repository secret.

```yaml
name: Deploy Dart Desk Studio

on:
  push:
    branches: [main]

jobs:
  deploy:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4

      - uses: subosito/flutter-action@v2
        with:
          channel: stable

      - name: Install Dart Desk CLI
        run: dart pub global activate dart_desk_cli

      - name: Install dependencies
        run: flutter pub get

      - name: Deploy
        run: dartdesk deploy --token ${{ secrets.DART_DESK_TOKEN }}
```

### Self-hosted server

For self-hosted instances, add `server` to your `dart_desk.yaml`:

```yaml
project_id: my-project
server: https://cms.yourcompany.com
```

## License

Business Source License 1.1 - see [LICENSE](LICENSE) for details.
