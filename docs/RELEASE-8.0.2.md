# Tunnelblick TOTP 8.0.2 (build 6304)

Published on November 17, 2026; first validated locally on November 12, 2026. This independent TOTP fork is based on Tunnelblick 8.0.1; version 8.0.2 is specific to this fork.

## Changes

- Automatic TOTP authentication failures wait for a fresh code and retry up to two times. Saved usernames, base passwords, and seeds are retained, without the saved-password choice dialog on this automatic path.
- Automatic connections defer codes with five seconds or less remaining. Submitting a login window regenerates the code instead of using a stale prefilled value.
- Waiting is asynchronous. Disconnect cancels pending credential submission, and obsolete callbacks cannot start a new connection.
- Exhausted retries stop the connection, add a log entry, and attempt a system notification. Missing saved credentials and manual/interactive challenge flows continue to use the existing UI.
- The Info page uses native contributor text with manual scrolling, removing the HTML table and 0.03-second animation timer responsible for sustained redraw work. License and TOTP text wrap and scroll; the version field is a read-only label.
- Local ad hoc signing avoids hardened-runtime library validation that prevented the bundled Sparkle framework from loading. Developer ID signing retains its existing hardened-runtime settings.
- The fork version is 8.0.2 and the build number is 6304.

## Installation and configuration

1. Quit Tunnelblick and extract the application ZIP.
2. Open the extracted `Tunnelblick.app` and follow its installer to install or replace the application. Administrator authorization may be required.
3. Select a VPN profile and open **Configurations → Advanced… → VPN Credentials**.
4. Import the standard TOTP provisioning secret or QR image and confirm automatic security codes are enabled.
5. Save the VPN username and **base password**, without an appended one-time code.
6. Connect. If automatic TOTP authentication fails, the next code is normally attempted after a wait of about 1–31 seconds, up to two retries. Disconnect cancels the wait.

See the [illustrated setup guide](SETUP.md) and [project README](../README.md) for supported provisioning formats and server requirements. Codes are generated as six-digit, 30-second HMAC-SHA1 TOTP. The supported server format is `base password + code`.

## Build and signing

The application is Universal for Apple Silicon and Intel, with a macOS 13 deployment target. The local build uses ad hoc signing and is not signed with an Apple Developer ID or notarized by Apple. If macOS blocks first launch because it cannot verify the developer, use the system's **Privacy & Security → Open Anyway** flow after verifying the source and checksum. Do not disable system-wide security protections.

The release workflow uses Xcode 16.4 through the command-line `xcodebuild` tool. Running the build script does not require opening Xcode's GUI.

```sh
python3 tests/run-tests.py
bash scripts/build-release.sh
```

The release script isolates host Homebrew build flags and runs the project's Release build. OpenSSL generated headers are completed before dependent compilation. The packager verifies the version, Universal architecture, signature, bundled library paths, and all four OpenVPN engines before producing:

- `Tunnelblick-8.0.2-macos-universal.zip`
- `Tunnelblick-8.0.2-source.zip`
- `SHA256SUMS.txt`

The application archive includes English and Simplified Chinese READMEs, these installation/release notes, the illustrated guides, and the GPL-2.0 license. The source archive contains the corresponding source tree, without build products or Git configuration/history. On Apple Silicon, engine verification runs both native and Intel executables through Rosetta.

## Validation

Offline regression tests cover the production TOTP generator and authentication handlers, including retries, cancellation, and manual/challenge isolation. They do not read real Keychain secrets or connect to a real VPN. Native and Intel engine startup, application signatures, archive checksums, and installed version consistency were also checked for the local release.

The local application was exercised through repeated Info/Configurations page switches, manual scrolling, and window resizing, and a saved-credential VPN connection succeeded. This verifies the tested local configuration; other servers still require their own compatibility check. Automatic retries do not correct invalid passwords, revoked seeds, or unsupported OTP parameters.
