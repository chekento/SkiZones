# SkiZones Alpine Radio – six original loop arrangements

All six instrumentals are **original compositions** created for SkiZones on 2026-11-04 and rendered offline with custom software synthesis. They do **not** sample commercial recordings, public-domain songs, Suno outputs, third-party instrument samples or copyrighted music.

| File | Radio station | Track | Tempo | Bars | Duration |
| --- | --- | --- | --- | --- | --- |
| `alpine.wav` | AlpenWelle FM | Hüttenmorgen | 116 BPM | 8 | 16.55 s |
| `techno.wav` | SnowBeat Radio | Gipfelpuls | 136 BPM | 8 | 14.12 s |
| `hiphop.wav` | Powder Flow | Park Lines | 94 BPM | 8 | 20.43 s |
| `punk.wav` | PistenPunk | Kantenwind | 164 BPM | 8 | 11.71 s |
| `classical.wav` | Alpine Classic | Schneelicht | 104 BPM | 8 | 18.46 s |
| `meditative.wav` | Mountain Chill | Wolkenmeer | 78 BPM | 8 | 24.62 s |

Format: 22,050 Hz mono 16-bit PCM WAV; the Godot radio player sets forward-loop boundaries. The project retains the 0.27 dual-player crossfade, preferences and opt-out behavior.

**Production-quality limitation:** These are deliberately composed, multitrack **synthesized** loop beds, not live accordion, guitar, orchestral recordings or broadcast-ready mastered songs. The next production pass should feature longer arrangements, transitions, nonrepetitive variants, and separately verified original or licensed recordings before external redistribution.

## Real offline radio – 87 recordings, 15 selectable winter stations

The separate CC0 folder contains **87 unique third-party OGG tracks** (including eleven new source-checked additions in the 0.34 development branch) and **15 selectable, offline radio programmes** plus the contextual Hotel Lobby FM programme. Tracks have individual CC0 source links and pinned Git blob SHA-1 checksums, and are never fetched from the internet when SkiZones runs. Programme slots may reuse an authorized recording; `library.json` is the authoritative station lineup, with exact measured stream lengths in `durations.json`.

The new playlists are grouped more tightly by feel: authentic acoustic **mountain-lodge** atmospheres (not mislabeled regional folk), **Freeride** synth/board beats, **PistenRock** guitars, **Powder Flow** hip-hop/lo-fi, **SnowBeat** techno/house, **Alpenglühen FM** après-ski house/funk, and quieter classical, ambient, winter/sunrise, lo-fi, Nordic and hotel-lounge streams.

**No SoundCloud album stations, browser-open buttons or embed assets** are shipped by the revised radio. Old preferences pointing to ERG0SPHERE Journey or Ska'radise Lost are migrated to the actual offline stations Cosmic Drift and Alpenglühen FM; career data, sound opt-out and immediate tuner settings are not reset. The owner-provided albums were never bundled into earlier versions.

For individual licenses, metadata and source hashes see [CC0 music rights](cc0/RIGHTS.md) and [machine-readable catalog](cc0/library.json). The original six short synthesized WAV loops above remain optional offline fallback beds rather than the main radio schedule. Track-level rights and technical checks have been performed; subjective musical quality and mix balance require separate listening checks before the final APK is signed.
