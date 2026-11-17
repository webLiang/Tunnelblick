# Tunnelblick TOTP 8.0.1.totp.1 (build 6302)

Local release dated November 11, 2026, based on this repository's Tunnelblick 8.0.1 TOTP extension. Superseded by [8.0.2, build 6304](RELEASE-8.0.2.md).

## Changes

- Replaced the saved-password choice dialog with automatic retries for authentication that used an automatic TOTP code and saved credentials.
- Waited for a new 30-second time step before retrying a rejected code, with a limit of two additional attempts and no deletion of saved credentials.
- Deferred automatic submission when a code had five seconds or less remaining.
- Regenerated the automatic code when submitting an open login window.
- Cancelled pending submission on disconnect; exhausted retries stopped the connection and attempted a notification instead of a blocking dialog.
- Corrected local ad hoc signing so bundled frameworks could load without hardened-runtime library-validation failures. Developer ID builds retained their original signing behavior.

## Installation and scope

Use an application built from this fork, install it with Tunnelblick's application installer, and configure **Advanced… → VPN Credentials** for the selected profile. Import the TOTP provisioning seed, then save the username and base password without an appended one-time code.

The supported flow uses six-digit, 30-second HMAC-SHA1 TOTP appended directly to the password. QR images are decoded during setup; this is not a CAPTCHA-recognition feature. Manual authentication and interactive challenges retain their existing UI.

Local builds are Universal for Apple Silicon and Intel, target macOS 13+, and use ad hoc signing without Apple notarization. See the current [setup guide](SETUP.md), [build instructions](../README.md#build-and-test), and [release notes](RELEASE-8.0.2.md) before installing or rebuilding.

## Verification

The offline regression runner compiles production generator/authentication code with in-memory doubles and does not use real Keychain entries or a VPN server. Release packaging checks the app version, CPU architectures, signature, library dependencies, and bundled OpenVPN engine versions. Live authentication must also be validated against the intended server.
