#!/usr/bin/env python3
"""Validate the built application and package app, corresponding source and checksums."""
from pathlib import Path
import hashlib
import os
import plistlib
import platform
import shutil
import subprocess
import tempfile
import zipfile

root = Path(__file__).resolve().parents[1]
version = (root / 'tunnelblick/TBVersionString.txt').read_text().strip()
build = (root / 'tunnelblick/TBBuildNumber.txt').read_text().strip()
app = root / 'tunnelblick/build/Release/Signed/Tunnelblick.app'
if not app.is_dir():
    raise SystemExit('Signed Release application is missing. Run scripts/build-release.sh first.')
info = plistlib.loads((app / 'Contents/Info.plist').read_bytes())
assert info['CFBundleVersion'] == build
assert info['CFBundleShortVersionString'].startswith(version + ' ')

def run(*command):
    return subprocess.check_output(command, text=True, cwd=root).strip()

def check_portable_libraries(path):
    # otool prints dependencies for every slice of a Universal binary.
    for line in run('otool', '-L', str(path)).splitlines():
        if not line.startswith('\t'):
            continue
        library = line.strip().split(' (compatibility version', 1)[0]
        assert library.startswith(('/System/Library/', '/usr/lib/', '@')), (path, library)

def check_engine_version(engine, intel=False):
    command = (['arch', '-x86_64'] if intel else []) + [str(engine), '--version']
    result = subprocess.run(command, text=True, stdout=subprocess.PIPE, stderr=subprocess.STDOUT)
    # OpenVPN 2.4/2.5 intentionally use the usage exit status (1) for --version.
    assert result.returncode in (0, 1), (command, result.returncode, result.stdout)
    _, vpn_version, _, ssl_version = engine.parent.name.split('-')
    assert result.stdout.startswith(f'OpenVPN {vpn_version} '), result.stdout
    assert f'library versions: OpenSSL {ssl_version} ' in result.stdout, result.stdout

binary = app / 'Contents/MacOS/Tunnelblick'
architectures = run('lipo', '-archs', str(binary))
assert set(architectures.split()) == {'arm64', 'x86_64'}, architectures
subprocess.run(['codesign', '--verify', '--deep', '--strict', str(app)], check=True)
signature = subprocess.run(['codesign', '-dvv', str(app)], text=True,
                           stdout=subprocess.PIPE, stderr=subprocess.STDOUT, check=True).stdout
if 'Signature=adhoc' in signature:
    assert ',runtime)' not in signature, 'Ad hoc app cannot load bundled frameworks with hardened runtime library validation'
for bundled in (
    app / 'Contents/Frameworks/Sparkle.framework/Sparkle',
    app / 'Contents/Library/LoginItems/Tunnelblick Launcher.app/Contents/MacOS/Tunnelblick Launcher',
):
    assert bundled.is_file(), bundled
    assert {'arm64', 'x86_64'} <= set(run('lipo', '-archs', str(bundled)).split()), bundled
resources = app / 'Contents/Resources'
helpers = ['openvpnstart', 'installer', 'atsystemstart', 'tunnelblickd', 'tunnelblick-helper',
           'TunnelblickUpdateHelper', 'process-network-changes', 'standardize-scutil-output']
for name in helpers:
    assert (resources / name).is_file(), name
    assert {'arm64', 'x86_64'} <= set(run('lipo', '-archs', str(resources / name)).split()), name
openvpns = sorted((resources / 'openvpn').glob('openvpn-*/openvpn'))
expected_engines = {
    'openvpn-2.4.12-openssl-1.1.1w', 'openvpn-2.5.9-openssl-1.1.1w',
    'openvpn-2.6.14-openssl-1.1.1w', 'openvpn-2.6.14-openssl-3.0.16',
}
assert expected_engines <= {engine.parent.name for engine in openvpns}, 'Missing OpenVPN engines'
assert (resources / 'openvpn/default').is_file(), 'Missing default OpenVPN engine'
for engine in openvpns:
    assert {'arm64', 'x86_64'} <= set(run('lipo', '-archs', str(engine)).split()), engine
    plugin = engine.parent / 'openvpn-down-root.so'
    assert plugin.is_file(), plugin
    assert {'arm64', 'x86_64'} <= set(run('lipo', '-archs', str(plugin)).split()), plugin
    check_portable_libraries(engine)
    check_portable_libraries(plugin)
    check_engine_version(engine)
    if platform.machine() == 'arm64':
        check_engine_version(engine, intel=True)

out = root / 'dist'
out.mkdir(exist_ok=True)
name = f'Tunnelblick-{version}-macos-universal'
appzip = out / (name + '.zip')
sourcezip = out / f'Tunnelblick-{version}-source.zip'
# Include modified tracked files and new source files; git ignores build outputs.
if (root / '.git').exists():
    source_base = run('git', 'rev-parse', 'HEAD')
    files = [Path(raw.decode()) for raw in subprocess.check_output(
        ['git', 'ls-files', '-z', '--cached', '--others', '--exclude-standard'], cwd=root).split(b'\0') if raw]
else:
    # An extracted source archive must also be buildable without a Git checkout.
    source_info = root / 'SOURCE-INFO.txt'
    source_base = source_info.read_text().strip() if source_info.exists() else 'unversioned sources'
    excluded = {'dist', 'tunnelblick/build', 'tunnelblick/com.apple.DeveloperTools',
                'third_party/build', 'third_party/products'}
    files = []
    for directory, folders, names in os.walk(root):
        base = Path(directory).relative_to(root)
        folders[:] = [name for name in folders if name not in {'.git', '__pycache__'}
                      and (base / name).as_posix() not in excluded]
        for name in names:
            if name not in {'.DS_Store', 'build-log.txt', 'do-not-clean'} and not name.startswith('built-'):
                files.append(base / name)
with zipfile.ZipFile(sourcezip, 'w', zipfile.ZIP_DEFLATED) as archive:
    archive.writestr(f'Tunnelblick-{version}-source/SOURCE-INFO.txt', source_base + '\n')
    for relative in files:
        path = root / relative
        if path.is_file() and relative.as_posix() != 'SOURCE-INFO.txt':
            archive.write(path, f'Tunnelblick-{version}-source/{relative}')
with tempfile.TemporaryDirectory(prefix='tunnelblick-release-') as temporary:
    staging = Path(temporary) / name
    staging.mkdir()
    subprocess.run(['ditto', str(app), str(staging / 'Tunnelblick.app')], check=True)
    # Keep the installation guide and its illustrations available offline.
    shutil.copy2(root / 'README.md', staging / 'README.md')
    shutil.copy2(root / 'README.zh-CN.md', staging / 'README.zh-CN.md')
    shutil.copy2(root / 'Building Tunnelblick from Source Code.markdown',
                 staging / 'Building Tunnelblick from Source Code.markdown')
    shutil.copytree(root / 'docs', staging / 'docs')
    notes = (root / f'docs/RELEASE-{version}.md').read_text()
    notes = notes.replace('(SETUP.md)', '(docs/SETUP.md)').replace('(../README.md)', '(README.md)')
    (staging / 'INSTALL-AND-RELEASE-NOTES.md').write_text(notes)
    shutil.copy2(root / 'COPYING', staging / 'LICENSE-GPL-2.0.txt')
    shutil.copy2(root / 'COPYING', staging / 'COPYING')
    (staging / 'BUILD-INFO.txt').write_text(
        f'Version: {version}\nBuild: {build}\nArchitectures: {architectures}\n'
        f'Source base: {source_base} (release source)\n'
        f'{run("xcodebuild", "-version")}\n'
        'Signing: local ad hoc; no Developer ID / Apple notarization\n'
        'Validation: offline regression tests, Release build, codesign verification, all OpenVPN engines --version (native and Intel on Apple Silicon)\n'
        'Live VPN authentication: requires validation with your server and saved credentials\n'
        f'Corresponding source archive: {sourcezip.name}\n')
    subprocess.run(['ditto', '-c', '-k', '--sequesterRsrc', '--keepParent', str(staging), str(appzip)], check=True)
checksums = []
for path in (appzip, sourcezip):
    checksums.append(f'{hashlib.sha256(path.read_bytes()).hexdigest()}  {path.name}\n')
    print(f'{path.name}: {path.stat().st_size / 1024 / 1024:.1f} MiB')
(out / 'SHA256SUMS.txt').write_text(''.join(checksums))
print('Application, source and checksums packaged in', out)
