# SkiZones Iteration 0.26 – Living Resort, Alpine Radio, Crew Life and Piste Atlas

**Draft branch. Not an APK release.** This iteration depends on PR #22 (0.25) → #19 (0.24) → #18 (0.23). Only v0.22.0 is publicly tagged until those ancestors pass full release QA.

## Versioned changes

| Development tag | Implemented first pass | Explicitly *not* shipped yet |
| --- | --- | --- |
| **0.26.1 Alpine Radio MVP** | Camera-focus audio zones for mountain, lift, hotel, restaurants, party and repair/rescue; per-channel synth ambience (wind, mock crowd, machinery); six internally generated loop styles with a user-selectable off default; Android-friendly in-game Jukebox and saved independent volumes | Finished songs, hosted radio, vocal/music models or third-party API |
| **0.26.2 Crew Presence** | Original staff housing 3D model placed non-invasively on maps; staff avatar position based on real assigned workplace/shifts; walking visual paths use obstacle-aware preexisting Foot.path_between; rescue incidents render a responding sled and existing piste groomers remain visible | Staff sleep need/contract, allocated beds, actual staff housing economics, fully navigated rescue/snowcats |
| **0.26.3 Graphic Themes** | Sixth **Pistenatlas** look with paper/stone tones, relief shading, contour overlay and orthographic oblique perspective; original five remain selectable and their palette contents are unchanged; Comic can flash a panel split and expressive editorial caption during dedicated scenic map focus; cinematic adds mild letterboxing | Entire new authored cinematics, arbitrary split-screen 3D gameplay |
| **0.26.4 Asset Deepening** | 12 additional original micro-prop geometries (snow fence, cairn, rest bench, alpine plants, winter branches, drift, trail marker, rope, logs, mailbox, lantern, arch) and up to 1,200 placed natural details in cleared areas. Classic Alpine can show 18 types, alternate themes 24 | Every individual asset unique, 1000 authored models, dynamic interiors or collision-ready props |
| **0.26.5 Suno Partnership** | Licensing comparison, rights gate and draft request below | No contact has been sent or partnership promised |

### 0.26.1 Music rights and zero-cost strategy

The game code does **not** call Suno, SoundCloud or any streaming endpoint. It plays only original algorithmically generated placeholder sounds: not copied tracks, songs or recognizable third-party melodies. This provides a completely offline and free fallback for every player.

Provider rules:
1. **Suno free** is personal/noncommercial; its paid tier grants some game/film use rights to downloaded tracks. The newly introduced Suno **MCP Beta** connects an assistant to the customer's Suno account, but is **not evidence** of an embeddable free API/licensed redistribution or game-wide generation endpoint.
2. **SoundCloud** allows widgets but its API terms disallow embedding/synchronizing tracks within a game without relevant rights, including sync licenses. Do not integrate as a bundled game station by default.
3. For an external track library, use verified **CC0**, independently licensed works, or original author compositions only. Before accepting any third-party asset record its copyright owner, exact SPDX/CC license and URL, download date, third-party performer/recording rights, redistribution terms and credits.
4. Do not treat every SoundCloud track or every file labeled “royalty-free” as verified. Never assume a provider’s artist upload has the necessary third-party rights.

**Sources checked November 3, 2026:**
- https://help.suno.com/en/articles/9601601
- https://help.suno.com/en/articles/9601665
- https://help.suno.com/en/articles/14486145
- https://developers.soundcloud.com/docs/api/terms-of-use
- https://creativecommons.org/publicdomain/zero/1.0/
- https://opengameart.org/content/vintage-collection-vgm-sfx-tracks-stuff-vol-i

**Suno partnership inquiry to prepare, not send yet:**

Recipient: support@suno.com

Subject: SkiZones – request for no-cost/indie game music generation integration

Hello Suno team,

I develop SkiZones, an indie Android ski resort management game with its own in-game Alpine Radio. Players would love to create original winter tracks in several genres: alpine folk, techno, hip-hop, punk, classical and meditative. Is there an approved partner or developer API that can support user-authorized generation inside a distributed Android game?

Please clarify: (1) whether the current MCP Beta is permitted for embedding in an Android game rather than connecting an AI assistant; (2) API/authentication availability and production quotas; (3) whether any free/indie developer tier or sponsored credits exist; (4) exact commercial rights to soundtrack sync, streaming, caching, download, reuse and redistribution per player; (5) whether the developer or the player is the licensee; (6) attribution, takedown and content-moderation obligations; and (7) a public policy/contact for a small noncommercial prototype evolving into a possible commercial release.

We will not ship a Suno-backed player until we have written permission and a suitable integration contract.

Best regards,
The SkiZones developer

## Crew simulation roadmap

The first visible staff accommodation is a **presentation-only landmark**: it does not charge a player's funds or change map saves/IDs. Staff positions reflect existing staffing assignments and shift windows, using the game's obstacle-aware foot planner; this avoids inventing new hotel bed inventory. Subsequent versions should explicitly add employee beds, duty handovers, residence capacity, wages/shifts, family and work-related needs; automatic staffed rescue stations; fully route-based sleds/snowcats; true equipment depots; accessibility and mobile performance monitoring.

## Camera looks / style rules

- **Alpin (classic):** unchanged core palette and world, more small alpine assets.
- **Comic:** more colorful angular trees and rocks, brief split-panel editorial effect in scenic focus only.
- **Pastell:** rounded, lavender-tinted props and soft light.
- **Filmisch:** deeper shadows, cinematic editorial bars during scenic focus.
- **Winterklar:** hard, high-contrast snow/glass silhouettes.
- **Pistenatlas:** sixth distinct cartographic relief style, 20m elevation lines and piste labels; actual simulation and placement geometry preserved.

Style maps should never change physics, valid routes, save hashes or NPC positions. Editor overlays must have mouse_filter=IGNORE.

## Release gate

- [ ] All 0.26 headless/audio/crew tests pass.
- [ ] Android build, career migration and background/resume pass on the full dependency stack.
- [ ] Six visual styles capture actual in-game screenshots; Pistenatlas is visually legible.
- [ ] No significant FPS regression from extra detail geometry or worker routing; lower-quality LOD remains viable.
- [ ] UI is bilingual, touch-safe and modal state does not accidentally place buildings.
- [ ] Audio can be turned off, does not play when system is muted, and does not start streaming.
- [ ] Rights documentation is included for every future external track before bundling.
