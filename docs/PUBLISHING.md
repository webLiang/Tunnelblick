# Maintaining the TOTP release line

The public repository is **[webLiang/Tunnelblick](https://github.com/webLiang/Tunnelblick)**, an independent fork of the official Tunnelblick project.

## Branches and source history

**`totp-8`** is the default branch for this fork's 8.x TOTP extension. It starts from the official **8.0.1 / build 6301** baseline, commit `ba7d57c175c61caceb7faa66ca0bcc4d69ce0c77`, with the extension maintained as public commits. Upstream copyright notices, license, contributor credits, and translations are retained.

The existing **`main`** branch retains its upstream 9.0 beta snapshot. Porting the extension to a newer upstream release is a separate change; do not replace that branch with the older 8.x source tree.

## Release naming

- Version: **8.0.2**
- Build: **6304**
- Tag: **`totp-8.0.2-build6304`**
- Release title: **Tunnelblick TOTP 8.0.2 (build 6304)**

This naming identifies the fork's release line and must not imply an official Tunnelblick release.

## Build and publish

Build from a clean, reviewed public commit with the [documented build workflow](../README.md#build-and-test). `scripts/build-release.sh` runs offline tests, the Universal Xcode Release build, and packaging checks. The app records the source commit in `TBGitHash`; confirm `TBGitStatus` is empty for a published build.

Attach these outputs to the same GitHub Release:

- `Tunnelblick-8.0.2-macos-universal.zip`
- `Tunnelblick-8.0.2-source.zip`
- `SHA256SUMS.txt`

The application package contains the application, English and Simplified Chinese READMEs, illustrated documentation, release notes, and license. The source package contains the corresponding public source without Git configuration/history or build products. Keep binary archives in Releases rather than Git commits.

Use [RELEASE-8.0.2.md](RELEASE-8.0.2.md) as the technical release notes and include direct links to the tagged documentation in the GitHub release body. Describe signing status accurately: current local builds are ad hoc signed and are not Apple-notarized. The fork does not provide its own automatic-update feed.

## Documentation and validation

Keep [README.md](../README.md) and [README.zh-CN.md](../README.zh-CN.md) aligned on supported authentication parameters, package links, signing status, and setup instructions. Public illustrations use generic labels and contain no real enrollment secrets or private network details.

Before publication, verify checksums, archive contents, source-commit metadata, signatures, both CPU architectures, and bundled engine startup. Offline authentication tests do not validate every server or replace manual QR/Keychain UI checks. Report the actual validation performed for the published build.
