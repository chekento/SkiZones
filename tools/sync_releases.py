"""Refresh real APK download totals and newest public APK links (including previews)."""
import argparse
import datetime as dt
import html
import json
import os
from pathlib import Path
import re
import urllib.request


def get(url):
    headers = {'Accept': 'application/vnd.github+json', 'User-Agent': 'kosch-release-sync'}
    if os.environ.get('GH_TOKEN'):
        headers['Authorization'] = 'Bearer ' + os.environ['GH_TOKEN']
    with urllib.request.urlopen(urllib.request.Request(url, headers=headers), timeout=45) as response:
        return json.load(response)


def releases(repo):
    result = []
    page = 1
    while True:
        batch = get(f'https://api.github.com/repos/chekento/{repo}/releases?per_page=100&page={page}')
        result.extend(batch)
        if len(batch) < 100:
            return result
        page += 1


def summarize(rows):
    public = [r for r in rows if not r['draft']]
    pairs = [(r, a) for r in public for a in r['assets']
             if a['name'].lower().endswith('.apk') and a.get('state', 'uploaded') == 'uploaded']
    if not pairs:
        raise ValueError('No published APK asset found; preserve previous links and counts')
    # Asset timestamps also support rolling releases published long ago.
    release, apk = max(pairs, key=lambda pair: (
        pair[1].get('created_at', pair[0]['published_at']),
        pair[0]['published_at'], pair[1]['name']))
    return dict(tag=release['tag_name'], prerelease=release['prerelease'],
                url=apk['browser_download_url'], release=release['html_url'],
                total=sum(a['download_count'] for _, a in pairs),
                latest_downloads=apk['download_count'], asset=apk['name'])


def block(text, marker, content):
    pattern = rf'<!-- {marker}:START -->.*?<!-- {marker}:END -->'
    result, count = re.subn(pattern, lambda _: f'<!-- {marker}:START -->\n{content}\n<!-- {marker}:END -->', text, flags=re.S)
    if count != 1:
        raise ValueError(f'Expected one {marker} block, found {count}')
    return result


def badge(count):
    return f'''<svg xmlns="http://www.w3.org/2000/svg" width="172" height="26" role="img" aria-label="APK downloads: {count}">
<title>APK downloads across all public releases: {count}</title><rect width="172" height="26" rx="6" fill="#173947"/>
<text x="10" y="17" fill="#dce9ec" font-family="Arial,sans-serif" font-size="12">APK downloads</text>
<text x="160" y="17" text-anchor="end" fill="#9be0cb" font-family="Arial,sans-serif" font-size="12" font-weight="700">{count}</text></svg>\n'''


def version_sort_key(tag):
    match = re.fullmatch(r'v?(\d+)\.(\d+)\.(\d+)', tag)
    return tuple(map(int, match.groups())) if match else (-1, -1, -1)


def historical_releases(rows):
    """Published releases that actually contain a downloadable Android APK."""
    selected = []
    for release in rows:
        if release.get('draft'):
            continue
        assets = [a for a in release.get('assets', [])
                  if a.get('state', 'uploaded') == 'uploaded']
        apks = [a for a in assets if a['name'].lower().endswith('.apk')]
        if not apks:
            continue
        apk = next((a for a in apks if 'arm64' in a['name'].lower()), apks[0])
        checksums = next((a for a in assets if a['name'] == apk['name'] + '.sha256'), None)
        manifest = next((a for a in assets if a['name'] == 'manifest.json'), None)
        selected.append((release, apk, checksums, manifest))
    selected.sort(key=lambda item: (version_sort_key(item[0].get('tag_name', '')),
                                    item[0].get('published_at') or ''), reverse=True)
    if not selected:
        raise ValueError('No published releases with APKs; do not overwrite the changelog')
    return selected


def release_notes(release):
    tag = release['tag_name']
    version = tag.removeprefix('v')
    path = Path('docs/releases') / (version + '.md')
    source = path.read_text(encoding='utf-8') if path.exists() else (release.get('body') or '')
    match = re.search(r'^#\s+(.+?)\s*$', source, flags=re.M)
    heading = match.group(1) if match else (release.get('name') or tag)
    topic = re.sub(r'^SkiZones\s+[\d.]+\s*[·—–-]?\s*', '', heading).strip() or 'Release'
    detail_url = path.as_posix() if path.exists() else release['html_url']
    return topic, source, detail_url


def history_table(entries):
    result = ['| Version | Datum (UTC) | Schwerpunkt | APK | Detaillierte Notizen |',
              '|---|---|---|---|---|']
    for release, apk, _, _ in entries:
        topic, _, detail_url = release_notes(release)
        topic = topic.replace('|', r'\|').replace('\n', ' ')
        date = '.'.join(reversed((release.get('published_at') or '')[:10].split('-')))
        result.append(f"| **[{release['tag_name']}]({release['html_url']})** | {date} | {topic} | "
                      f"[APK ARM64]({apk['browser_download_url']}) | [Details]({detail_url}) |")
    return '\n'.join(result)


def archive_block(rows):
    entries = historical_releases(rows)
    total = len(entries)
    return (f'Für **{total} veröffentlichte Android-Preview-Versionen** sind APK-Dateien vorhanden. '
            'Jede Version kann separat heruntergeladen werden.\n\n'
            '**[Vollständiges, detailliertes Changelog](CHANGELOG.md)** · '
            '[GitHub-Releases](https://github.com/chekento/SkiZones/releases)\n\n'
            + history_table(entries[:5])
            + f'\n\n<details>\n<summary>Ältere APK-Versionen anzeigen ({max(total - 5, 0)})</summary>\n\n'
            + history_table(entries[5:])
            + '\n\n</details>\n\n'
            'Alle APKs sind Android-ARM64-Previews. Prüfsummen, Versionshinweise, '
            'Einschränkungen und Tests sind in den jeweiligen Release-Notizen dokumentiert. '
            'Die Tabelle wird nach Veröffentlichungen und beim stündlichen Release-Abgleich erneuert.')


def normalize_note_links(body):
    """Make relative links from docs/releases/*.md work in root CHANGELOG.md."""
    def replace(match):
        target = match.group(1)
        if target.startswith(('http:', 'https:', 'mailto:', '#', '/', 'data:')):
            return match.group(0)
        path, sep, fragment = target.partition('#')
        parts = ['docs', 'releases']
        for component in path.split('/'):
            if component == '..':
                if parts:
                    parts.pop()
            elif component not in ('', '.'):
                parts.append(component)
        return '](' + '/'.join(parts) + (sep + fragment if sep else '') + ')'
    return re.sub(r'\]\(([^)]+)\)', replace, body)


def complete_changelog(rows):
    entries = historical_releases(rows)
    output = [
        '# SkiZones – vollständiges Changelog und APK-Versionsarchiv',
        '',
        (f'Dieses Dokument enthält die ausführlichen technischen Release-Notizen für '
         f'**{len(entries)} veröffentlichte Android-Previews**. Die Einträge stammen '
         'aus versionierten Dateien unter docs/releases/ oder, falls keine Datei '
         'vorliegt, aus dem jeweiligen GitHub-Release. Die tatsächlich vorhandenen '
         'APK-Dateien werden direkt verlinkt. Neueste Version zuerst.'),
        '',
        '[Spielübersicht](README.md) · '
        '[Alle GitHub-Releases](https://github.com/chekento/SkiZones/releases)',
        '',
        '## Versionen und Downloads',
        '',
        history_table(entries),
        '',
        '## Ausführliches Änderungsprotokoll',
        ''
    ]
    for release, apk, checksum, manifest in entries:
        tag = release['tag_name']
        topic, body, detail_url = release_notes(release)
        date = '.'.join(reversed((release.get('published_at') or '')[:10].split('-')))
        output.extend([
            f'## {tag} · {topic} ({date})',
            '',
            f"**Veröffentlichung:** [GitHub Release]({release['html_url']}) · "
            f"**[APK herunterladen]({apk['browser_download_url']})** "
            f"({apk.get('size', 0) / 1048576:.1f} MiB, ARM64)"
        ])
        links = []
        if checksum:
            links.append(f"[SHA-256-Datei]({checksum['browser_download_url']})")
        if manifest:
            links.append(f"[Build-Manifest]({manifest['browser_download_url']})")
        links.extend([f'[Originalnotizen]({detail_url})',
                      f'[Quellcode zum Tag](https://github.com/chekento/SkiZones/tree/{tag})'])
        output[-1] += ' · ' + ' · '.join(links)
        output.append('')
        if body.strip():
            body = re.sub(r'^#\s+[^\n]+\n?', '', body, count=1).strip()
            body = re.sub(r'^(#{1,5})[ \t]+', lambda match: '#' + match.group(0),
                          body, flags=re.M)
            output.append(normalize_note_links(body) if body else
                          '_Für dieses Release sind keine weiteren Details angegeben._')
        else:
            output.append('_Für dieses Release sind keine technischen Notizen vorhanden._')
        output.extend(['', '---', ''])
    return '\n'.join(output)




def sync(snapshot=None, ski=False):
    def fetch(repo):
        return summarize(snapshot[repo] if snapshot is not None else releases(repo))
    if ski:
        ski_rows = snapshot['SkiZones'] if snapshot is not None else releases('SkiZones')
        release = summarize(ski_rows)
        text = Path('README.md').read_text()
        content = f'''[![Download APK · neueste veröffentlichte Android-Preview](docs/images/download-apk.svg)]({release['url']})

**Aktueller Download: {release['tag']} · Android ARM64 · Preview**

[Release & Installation]({release['release']}) · [Alle Versionen](https://github.com/chekento/SkiZones/releases) · [Download-Statistik](docs/downloads.json)

![APK-Downloads über alle öffentlichen Releases](docs/images/apk-downloads.svg)

*Nur APK-Dateien werden gezählt, einschließlich Previews. Prüfsummen und Metadaten sind ausgeschlossen. Downloads sind keine eindeutigen Installationen. Der Download-Link wird nach dem Build und zusätzlich stündlich aktualisiert; GitHub-Bildcaches können verzögern.*'''
        text = block(text, 'APK-DOWNLOAD', content)
        text = block(text, 'VERSION-ARCHIVE', archive_block(ski_rows))
        Path('README.md').write_text(text)
        Path('CHANGELOG.md').write_text(complete_changelog(ski_rows))
        Path('docs/images').mkdir(parents=True, exist_ok=True)
        Path('docs/images/apk-downloads.svg').write_text(badge(release['total']))
        Path('docs/downloads.json').write_text(json.dumps(release, indent=2)+'\n')
        print(f"SkiZones: {release['tag']}, {release['total']} APK downloads")
        return

    apps = json.loads(Path('tools/apps.json').read_text())
    # Complete every read before mutating generated files. API errors must not become zeroes.
    metadata = {app['id']: fetch(app['repo']) for app in apps}
    text = Path('README.md').read_text()
    total = sum(value['total'] for value in metadata.values())
    lines = [f'**{total} APK downloads** across the 11 projects.', '',
             '| Project | Explore | Android APK | APK downloads |',
             '|---|---|---|---:|']
    for app in apps:
        r = metadata[app['id']]
        label = r['tag'] + (' · Preview' if r['prerelease'] else '')
        lines.append(f"| **[{app['name']}](https://github.com/chekento/{app['repo']})** | {app['description']} | [↓ {label}]({r['url']}) | ![{r['total']} APK downloads](assets/downloads/{app['id']}.svg) |")
    text = block(text, 'APP-CATALOG', '\n'.join(lines))
    ski_release = metadata['skizones']
    text = block(text, 'SKIZONES-DOWNLOAD', f'''[![Download SkiZones APK](https://raw.githubusercontent.com/chekento/SkiZones/main/docs/images/download-apk.svg)]({ski_release['url']})

[{ski_release['tag']} · Android Preview]({ski_release['release']}) · [Game & documentation](https://github.com/chekento/SkiZones) · ![{ski_release['total']} APK downloads](assets/downloads/skizones.svg)''')
    store = Path('docs/store.html').read_text()
    store, count = re.subn(r'// RELEASE-DATA:START.*?// RELEASE-DATA:END',
        lambda _: '// RELEASE-DATA:START\nconst releaseData = '+json.dumps(metadata, ensure_ascii=False)+';\n// RELEASE-DATA:END', store, flags=re.S)
    if count != 1:
        raise ValueError('Expected one store release-data block')
    for app in apps:
        p = Path('assets/downloads') / (app['id'] + '.svg')
        p.parent.mkdir(parents=True, exist_ok=True)
        p.write_text(badge(metadata[app['id']]['total']))
        card = Path('assets/app-gallery') / (app['id']+'.svg')
        if card.exists():
            card.write_text(re.sub(r'(<text id="apk-download-count"[^>]*>↓ )\d+( APK downloads</text>)',
                lambda m: m[1]+str(metadata[app['id']]['total'])+m[2], card.read_text()))
    Path('README.md').write_text(text)
    Path('docs/store.html').write_text(store)
    Path('docs/downloads.json').write_text(json.dumps(metadata, ensure_ascii=False, indent=2)+'\n')
    print(f'{len(apps)} projects; {total} APK downloads')


if __name__ == '__main__':
    parser = argparse.ArgumentParser()
    parser.add_argument('--snapshot', type=Path, help='Use a saved API response for deterministic validation')
    parser.add_argument('--ski', action='store_true')
    args = parser.parse_args()
    sync(json.loads(args.snapshot.read_text()) if args.snapshot else None, args.ski)
