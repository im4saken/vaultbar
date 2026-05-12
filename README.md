# VaultBar

Minimalist macOS menu bar app for storing, searching, and copying API keys.

## Build

```sh
./scripts/build-app.sh
```

The app bundle is created at:

```text
.build/VaultBar.app
```

## Architecture

- API key values are stored in the system Keychain as `kSecClassGenericPassword`.
- Search metadata is stored as encrypted JSON in Application Support:
  `~/Library/Application Support/VaultBar/metadata.json.enc`
- The metadata encryption key is generated with `SecRandomCopyBytes` and stored separately in Keychain.
- Decrypted API keys are read only at copy time and are not cached globally.
- Clipboard contents are cleared after the configured timeout if the user has not changed the clipboard.
- The app is configured as an accessory app with `LSUIElement = true`.
- Sandbox entitlements disable client and server network access.

## UI

- The floating search capsule opens directly below the macOS menu bar.
- The capsule includes add, search, copy, and settings controls.
- **Focus-aware search bar** — the capsule and its results disappear immediately when you click away to another app, then reappear on the next ⌘N.
- Settings provides API key edit/delete and clipboard clear timeout options.

## Importing Keys

### Batch import from file

Open Settings, tap the **download** icon to open a file picker. Import plain text files (`.csv` or `.md`) with one key per line in the format:

```
label,api_key
```

Lines starting with `#` or `//` are treated as comments and skipped. The file picker accepts `.txt`, `.csv`, and `.md` files, shows a preview before import, and reports the number of successfully imported keys along with any errors.

## Main Files

- `Sources/VaultBar/Security/KeychainHelper.swift`: Keychain CRUD and metadata encryption key management.
- `Sources/VaultBar/Storage/MetadataStore.swift`: encrypted metadata persistence.
- `Sources/VaultBar/App/KeyRepository.swift`: add/search/copy orchestration, batch import.
- `Sources/VaultBar/Window/CapsulePanel.swift`: borderless floating Spotlight-style panel.
- `Sources/VaultBar/UI/CapsuleSearchView.swift`: capsule UI, search field, add and copy controls.
- `Sources/VaultBar/UI/SettingsView.swift`: edit/delete, clipboard timeout settings, and file-based batch import.
