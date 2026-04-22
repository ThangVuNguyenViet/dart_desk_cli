# dart_desk_cli

Command-line interface for deploying and managing Dart Desk CMS studios.

## Getting Started

The fastest way to get up and running is with Dart Desk Cloud.

**1. Sign up**

Create a project at [manage.dartdesk.dev](https://manage.dartdesk.dev). Note your project ID — you'll need it in the next step.

**2. Install the CLI**

```bash
dart pub global activate dart_desk_cli
```

**3. Add `dart_desk.yaml` to your project root**

```yaml
project_id: my-project
```

**4. Log in**

```bash
dartdesk login
```

This opens a browser window for OAuth. Your credentials are saved to `~/.dart_desk/credentials.json`.

**5. Deploy**

```bash
dartdesk deploy
```

The CLI builds your Flutter web app, tars `build/web/`, and uploads it to Dart Desk Cloud. Your studio is live.

---

## Command Reference

### `dartdesk login`

Opens a browser window for OAuth authentication against the Dart Desk server. Credentials are saved to `~/.dart_desk/credentials.json`.

```bash
dartdesk login
```

| Option | Description |
|--------|-------------|
| `--server <url>` | Override the server URL (defaults to `https://api.dartdesk.dev`) |

---

### `dartdesk logout`

Clears stored credentials by deleting `~/.dart_desk/credentials.json`.

```bash
dartdesk logout
```

---

### `dartdesk deploy`

Builds your Flutter web app, tars `build/web/`, and uploads the archive to your Dart Desk project.

```bash
dartdesk deploy
```

| Option | Description |
|--------|-------------|
| `--token <token>` | API token for non-interactive / CI environments (skips credential file) |
| `--skip-build` | Skip `flutter build web` and upload the existing `build/web/` directory |
| `--commit <sha>` | Associate this deployment with a specific git commit SHA |

---

### `dartdesk deployments list`

Lists the deployment history for the current project.

```bash
dartdesk deployments list
```

| Option | Description |
|--------|-------------|
| `--token <token>` | API token for non-interactive / CI environments |

---

### `dartdesk deployments rollback`

Activates a previous deployment version, making it the live studio.

```bash
dartdesk deployments rollback --version <version>
dartdesk deployments rollback -v <version>
```

| Option | Description |
|--------|-------------|
| `--version <version>`, `-v <version>` | **(Required)** The version number to roll back to |
| `--token <token>` | API token for non-interactive / CI environments |

---

## CI/CD

Use `--token` to deploy from CI without interactive login. Store your API token as a repository secret.

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

---

## Self-Hosting

To deploy against a self-hosted Dart Desk instance, set the `server` key in `dart_desk.yaml`. All CLI commands will target this server instead of Dart Desk Cloud.

```yaml
project_id: my-project
server: https://cms.yourcompany.com
```

---

## License

Business Source License 1.1 — see [LICENSE](LICENSE) for details.
