# LAST LIGHT — Project Guide

> *Fire. Shadow. Time. One survives.*
> A third-person 1v1 arena duel built in Godot 4.7.2 for Windows.

This document is the single place to understand the project: what the game is, how to play and share it, how it is built, how the code is organised, and what any software project needs around it (versioning, testing, licensing, releases). It is written for both non-technical readers (sections 1–5) and developers (sections 6–15).

---

## Table of contents

1. [What the game is](#1-what-the-game-is)
2. [How to play](#2-how-to-play)
3. [How to share it with a friend](#3-how-to-share-it-with-a-friend)
4. [System requirements](#4-system-requirements)
5. [The MVP — what is in, what is out](#5-the-mvp--what-is-in-what-is-out)
6. [Technology stack](#6-technology-stack)
7. [Project hierarchy (folders and files)](#7-project-hierarchy-folders-and-files)
8. [Scene hierarchy (how the game is assembled)](#8-scene-hierarchy-how-the-game-is-assembled)
9. [Game design — rules and numbers](#9-game-design--rules-and-numbers)
10. [Technical design — how each system works](#10-technical-design--how-each-system-works)
11. [Asset pipeline — where everything came from](#11-asset-pipeline--where-everything-came-from)
12. [Building and releasing](#12-building-and-releasing)
13. [Testing](#13-testing)
14. [Known issues and limitations](#14-known-issues-and-limitations)
15. [Roadmap](#15-roadmap)
16. [Software essentials every project needs](#16-software-essentials-every-project-needs)
17. [Licences and credits](#17-licences-and-credits)
18. [Glossary](#18-glossary)

---

## 1. What the game is

Two fighters meet in a ruined arena around a dead lighthouse. They shoot at range, switch to knives up close, shove each other with punches, and use two optional powers. A red zone slowly shrinks, forcing every fight to end face to face.

| Theme | How it appears in the game |
|---|---|
| **Fire** | A homing **fireball** power: damage plus burning over time |
| **Shadow** | A **shadow orb** power: blinds the opponent's screen and ruins their aim |
| **Time** | The **red zone**: after 20 seconds it shrinks; standing outside it drains health |

**Modes:** *Versus Bot* (one player against an AI) and *2 Players* (split screen on one PC).
**Match format:** best of 3 rounds. Each fighter has 100 HP.

---

## 2. How to play

### Starting
- Double-click `build/LastLight.exe` (or open the project in Godot and press **F5**).
- Choose **VERSUS BOT** or **2 PLAYERS (SPLIT SCREEN)**.

### Controls

| Action | Player 1 | Player 2 | Gamepad |
|---|---|---|---|
| Move | W A S D | Arrow keys or I J K L | Left stick |
| Jump | Space | Numpad 0 or M | A |
| Sprint | Shift | Numpad Enter or B | Left-stick click |
| Shoot (far) / Knife (near) | Left mouse or F | Numpad 1 or O | X |
| Punch (shove) | Right mouse or G | Numpad 2 or U | Y |
| **Fire** power | Q | Numpad 4 or Y | Left bumper |
| **Shadow** power | E | Numpad 5 or H | Right bumper |
| Dodge roll | C or Ctrl | Numpad 3 or N | B |
| Reload | R | Numpad 6 or P | D-pad down |
| Pause | Esc | Esc | Start |

Gamepad 1 controls Player 1, gamepad 2 controls Player 2.

### Tips
- The camera always faces your opponent (**lock-on**), so "forward" means "towards them".
- Rolling makes you **untouchable** for its first 0.35 s — roll through a fireball.
- Use the lighthouse, walls and pillars as cover: bullets and powers cannot pass through.
- When the zone gets small, guns stop mattering. Save a punch to knock the opponent out of the zone.

---

## 3. How to share it with a friend

The game is **one file**: `build/LastLight.exe` (~138 MB). Your friend does **not** need Godot.

**Step 1 — zip it (optional, saves a little space).** Right-click `LastLight.exe` → *Send to* → *Compressed (zipped) folder*.

**Step 2 — upload it somewhere.** The file is too big for e-mail (25 MB limit) and normal Discord (10 MB). Use one of:

| Service | Cost | How |
|---|---|---|
| **Google Drive** / **OneDrive** | Free | Upload → *Share* → *Anyone with the link* → send the link |
| **WeTransfer** | Free up to 2 GB | Upload, enter friend's e-mail or copy the link |
| **itch.io** | Free | Create a game page, upload the zip, set it to *Restricted* or *Public*. Best if you want a proper game page later |

**Step 3 — tell your friend about the Windows warning.** The game is not code-signed (signing certificates cost money), so Windows SmartScreen will show *"Windows protected your PC"*. They click **More info → Run anyway**. Some antivirus programs flag unsigned new `.exe` files too; this is a false positive.

**Step 4 — first launch is slow.** The first run compiles graphics shaders and can take up to a minute. Later runs are quick.

---

## 4. System requirements

| | Minimum |
|---|---|
| OS | Windows 10 or 11, 64-bit |
| Graphics | A GPU with **DirectX 12** support (most cards from 2016 onwards, and Intel integrated graphics from 6th gen) |
| RAM | 4 GB |
| Disk | 150 MB |
| Input | Keyboard + mouse; optional Xbox/PlayStation-style gamepads |

If a friend's PC cannot run DirectX 12, the game can be exported with the **Compatibility** renderer (OpenGL) instead — see [§14](#14-known-issues-and-limitations).

---

## 5. The MVP — what is in, what is out

**MVP (Minimum Viable Product)** = the smallest version that proves the game is fun. Everything else waits.

### In the MVP (done)
- [x] Two playable fighters with full animation (idle, run, sprint, jump, shoot, reload, knife, punches, cast, hit, roll, death)
- [x] Automatic weapon switching: pistol beyond 4 m, knife within 4 m; punch always available
- [x] Two powers: Fire (damage + burn) and Shadow (blind)
- [x] Shrinking red zone (Time)
- [x] AI opponent that keeps range, strafes, takes cover-aware shots, dodges, uses powers and stays in the zone
- [x] Local 2-player split screen, keyboard and gamepad
- [x] Best-of-3 rounds, K.O. slow-motion, match-end screen, rematch
- [x] Menus: title, controls, pause
- [x] HUD: health bars, round pips, ammo, power cooldowns, zone warning, hit flash, blindness overlay
- [x] Sound effects and music
- [x] Windows `.exe` build

### Out of the MVP (later)
- Online multiplayer
- Character selection, outfits, more characters
- Multiple arenas
- Difficulty settings for the bot
- Settings menu (volume, resolution, key rebinding)
- Achievements, statistics, save data

---

## 6. Technology stack

| Layer | Technology | Why |
|---|---|---|
| **Game engine** | Godot **4.7.2** (standard, not .NET) | Free, open source (MIT), small, scenes are plain text so code tools can edit them |
| **Language** | **GDScript** | Godot's built-in Python-like language; short code, no compiling |
| **Renderer** | Forward+ on **Direct3D 12** | Modern lighting, shadows, glow, SSAO, fog |
| **Physics** | **Jolt Physics** | Fast and stable 3D physics (Godot's default in 4.4+) |
| **3D modelling** | **Blender 5.2** + Python scripts | Props (ruins, lighthouse, weapons) are generated by code, so they can be rebuilt |
| **Characters & animation** | **Quaternius** Universal Base Characters + Universal Animation Library (CC0) | Free, professional rigged models with 43 animations on one shared skeleton |
| **Audio** | Synthesised in GDScript (`tools/synth.gd`) → `.wav` | No licensing worries; every sound is generated from maths |
| **Shaders** | Godot Shading Language | Screen effects for blindness and the zone warning |
| **AI pathfinding** | Godot **NavigationServer3D** (navmesh baked at start) | The bot walks around cover instead of into it |
| **Platform** | Windows x86-64 | Export templates 4.7.2 |
| **Dev tools** | Claude Code, PowerShell, Godot headless mode | Automated building, testing and screenshots |

---

## 7. Project hierarchy (folders and files)

```
as-hat/                         ← the Godot project ("res://")
├── project.godot               Project settings, input map, main scene
├── main.tscn                   ★ The game's root scene — start here
├── export_presets.cfg          How the Windows .exe is built
├── arena_environment.tres      Lighting, fog, glow, ambient settings
├── PROJECT_GUIDE.md            This document
│
├── scripts/                    All game logic (GDScript)
│   ├── game.gd                 Match flow, rounds, split screen, cameras, effects
│   ├── fighter.gd              One fighter: movement, weapons, powers, health, animation
│   ├── fighter_input.gd        "Brain" for a human player (reads keys/gamepad)
│   ├── fighter_ai.gd           "Brain" for the bot
│   ├── projectile.gd           Fireball and shadow orb
│   ├── zone.gd                 The shrinking red zone (Time)
│   ├── view_hud.gd             One player's on-screen HUD
│   ├── ui.gd                   Shared UI: health bars, banners, menus
│   └── sfx.gd                  Sound effects and music
│
├── scenes/                     Reusable building blocks
│   ├── arena.tscn              The arena: floor, lighthouse, cover, torches, horizon
│   ├── fighter_1.tscn          Player 1 (male model, fire-orange)
│   ├── fighter_2.tscn          Player 2 / Bot (female model, shadow-violet)
│   ├── projectile_fire.tscn    Fireball
│   ├── projectile_shadow.tscn  Shadow orb
│   └── zone.tscn               Red zone wall and edge
│
├── ui/                         hud.tscn, ui.tscn, theme.tres (fonts, colours, buttons)
├── shaders/                    blind.gdshader, vignette.gdshader
├── materials/                  Stone, metal, shadow, ember materials (.tres)
├── models/                     props.glb, weapons.glb and extracted meshes (models/meshes/*.res)
├── assets/
│   ├── characters/             Quaternius character models + textures
│   └── animations/             UAL1_Standard.glb + ual_library.res (all animations)
├── audio/                      18 .wav sound effects and music loops
│
├── tools/                      Not shipped in the game
│   ├── bake_arena.gd           Generates the scenes, input map, animation tree and sounds
│   ├── make_models.py          Blender script: ruins, lighthouse, rocks, shrine
│   ├── make_weapons.py         Blender script: pistol and knife
│   ├── synth.gd                Sound synthesiser
│   └── probe.gd                Debug helper (lists animation names)
├── art/                        Blender source files (.blend) — ignored by Godot
├── build/                      LastLight.exe (and the old TheLastEmber.exe)
├── _old_ember/                 Local archive of The Last Ember (not in this repo — see github.com/huzii-iizuh/the-last-ember)
└── _downloads/                 Original Quaternius zips — ignored by Godot
```

Folders containing a `.gdignore` file (`art/`, `_old_ember/`, `_downloads/`) are invisible to Godot.

---

## 8. Scene hierarchy (how the game is assembled)

Godot builds games from **scenes** (`.tscn`) made of **nodes**. Scenes can contain other scenes.

### main.tscn
```
Main (game.gd)                         runs always, even when paused
├── Views (HBoxContainer)              the split screen; pauses with the game
│   ├── View1 (SubViewportContainer)   Player 1's half (or the whole screen vs the bot)
│   │   └── Viewport (SubViewport)
│   │       ├── World                  ← the one shared 3D world
│   │       │   ├── WorldEnvironment   lighting / fog / glow
│   │       │   ├── Moon               shadow-casting light
│   │       │   ├── Arena              (arena.tscn)
│   │       │   ├── Zone               (zone.tscn)
│   │       │   ├── Fighter1           (fighter_1.tscn)
│   │       │   ├── Fighter2           (fighter_2.tscn)
│   │       │   └── Effects            bullets tracers, sparks, projectiles spawn here
│   │       ├── Camera                 Player 1's camera
│   │       └── Hud                    (hud.tscn) Player 1's HUD
│   └── View2 (SubViewportContainer)   Player 2's half — hidden vs the bot
│       └── Viewport                   shares View1's world
│           ├── Camera
│           └── Hud
├── Sfx (sfx.gd)
│   └── Music
└── UI (ui.tscn)                       health bars, banners, menus — on top of both views
```

### fighter_1.tscn / fighter_2.tscn
```
Fighter (CharacterBody3D, fighter.gd)
├── Shape                  capsule collider (radius 0.35, height 1.8)
├── Model                  the Quaternius character
│   └── Armature/Skeleton3D
│       └── HandR (BoneAttachment3D on bone "hand_r")
│           └── WeaponMount
│               ├── Pistol → Gun, Muzzle
│               └── Knife  → Blade, Handle
├── AnimationTree          blends all animations (see §10.4)
├── TeamRing               glowing ring under the feet
├── BurnFx                 fire particles while burning
├── BlindFx                shadow particles while blinded
└── Agent                  NavigationAgent3D (used by the bot)
```

### arena.tscn
```
Arena
├── Navigation (NavigationRegion3D)   everything inside is used to bake the bot's walkable map
│   ├── Floor          38 m radius stone disc
│   ├── Lighthouse     central cover + warm beacon light
│   ├── Cover          6 walls (r 11 m), 8 pillars (r 19 m), 4 arches (r 27 m)
│   └── Rim            32 invisible fence pieces + ruined wall (r 37.5 m)
├── Inlay ×2           glowing ember rings on the floor
├── Rubble ×14         decoration only
├── Torch ×8           fire bowls lighting the arena edge
├── Horizon            distant ruins + moon
└── Embers             floating ember particles
```

---

## 9. Game design — rules and numbers

All numbers live as constants at the top of `scripts/fighter.gd`, `scripts/zone.gd` and `scenes/projectile_*.tscn`, so balancing means changing one line.

### Fighters
| Stat | Value |
|---|---|
| Health | 100 |
| Run / sprint speed | 5.5 / 8.5 m/s |
| Jump | 7 m/s upward, gravity 20 m/s² |
| Dodge roll | 10 m/s for 0.5 s; invulnerable for the first 0.35 s; 0.9 s cooldown |
| Slowed while attacking or reloading | to 45 % speed |

### Weapons
| Weapon | When | Damage | Rate | Other |
|---|---|---|---|---|
| Pistol | Opponent further than 4 m | 8 per hit | 1 shot / 0.33 s | 12-round magazine, 1.4 s reload. Spread 2.5°, +3° while moving, +4° if target is rolling, +14° while blinded |
| Knife | Within 4 m | 18 | 1 / 0.55 s | Reach 2.4 m, 70° in front |
| Punch | Any time | 10 | 1 / 0.7 s | Reach 2.1 m, knocks back 8 m/s and stuns 0.45 s |

### Powers
| Power | Cooldown | Projectile | Effect on hit |
|---|---|---|---|
| **Fire** | 7 s | 18 m/s, homing 1.2 rad/s | 15 damage + burning 4 HP/s for 3 s |
| **Shadow** | 12 s | 14 m/s, homing 2.0 rad/s | 5 damage + blind for 3.5 s |

Both are stopped by cover and dodged by a well-timed roll.

### Time — the zone
| Phase | Value |
|---|---|
| Start radius | 32 m |
| Grace period | 20 s (HUD counts down) |
| Shrinks to | 5 m over 90 s |
| Damage outside | 6 HP/s |

### Match flow
`Menu → Round banner → 3-2-1 → FIGHT → (K.O. + slow motion) → round winner → next round … → first to 2 wins → Rematch / Main menu`

A double K.O. in the same frame is a draw and nobody scores.

---

## 10. Technical design — how each system works

### 10.1 The "brain" pattern
A fighter never reads the keyboard itself. Every frame it asks its **brain** for an *intent* — a small dictionary such as `{move, sprint, jump, attack, punch, fire, shadow, roll, reload}`.
- `fighter_input.gd` builds the intent from input actions (`p1_*` or `p2_*`).
- `fighter_ai.gd` builds the same intent from decisions.

This means the bot obeys exactly the same rules, cooldowns and physics as a human, and a mode is just "which brain is plugged in".

### 10.2 Lock-on movement
"Forward" is always the direction to the opponent; "right" is perpendicular to it. Pressing *left/right* circles the opponent. The fighter faces where it runs, but snaps to face the opponent while attacking, standing still or in knife range.

### 10.3 Combat
- **Pistol** is *hitscan*: a ray from the muzzle towards the opponent's chest, rotated by a random spread. The ray stops at cover (physics layer 1) or a fighter (layer 2). A bright tracer and muzzle flash show the shot.
- **Knife and punch** check distance and the angle in front of the attacker after a short wind-up (0.22 s / 0.18 s), so the hit lands mid-animation.
- **Projectiles** are `Area3D` nodes that steer gently towards the target each frame and explode on the first body they touch.
- All damage goes through one function, `take_hit(amount, kind, attacker, knock, stun)`, which handles i-frames, hit reactions, knock-back and death.

### 10.4 Animation tree
One `AnimationTree` per fighter blends the 43 Quaternius animations:

```
loco (Idle ↔ Jog ↔ Sprint by speed)
  → air (blend to Jump while airborne)
    → gun (upper body holds the pistol pose when in gun range)
      → upper (one-shot, upper body only: Shoot / Reload / Cast)
        → full (one-shot, whole body: Knife / Jab / Cross / Hit / Hit_Head / Roll)
          → life (Alive ↔ Death)
            → output
```
"Upper body only" uses a **bone filter**, so a fighter can shoot while the legs keep running.

### 10.5 The bot (AI)
Every 0.2 s it re-plans:
- **Range:** keeps ~10 m while it has ammo; closes to 2 m (knife) if it leads by 15+ HP, the zone is under 11 m, or it is out of ammo; backs off to 14 m while blinded.
- **Movement:** circle-strafes, switching direction every 1.2–2.8 s; target points are clamped inside the zone; a **NavigationAgent3D** finds a path around cover on a navmesh baked when the game starts.
- **Actions:** shoots when it has line of sight; fires Fire (25 % chance per think at 5–22 m) and Shadow (18 % at under 15 m) when ready; rolls away from incoming projectiles (60 %); punches at under 2.3 m; reloads early when safe.

### 10.6 Split screen
Two `SubViewport`s render the **same** 3D world (`View2.world_3d = View1.world_3d`) from two cameras. Each viewport has its own HUD layer, so blindness only darkens the victim's half. Against the bot, View2 is hidden and View1 fills the screen.

### 10.7 Physics layers
| Layer | Used by |
|---|---|
| 1 — World | Floor, cover, fence, lighthouse |
| 2 — Fighters | Both fighters |

Bullets and projectiles test layers 1 + 2; the camera and line-of-sight checks test only layer 1.

### 10.8 Pausing
`Main`, `UI` and `Sfx` run *always*; `Views` (the world) is *pausable*. Pausing freezes the fight while menus keep working.

### 10.9 Input map
All actions are defined in **Project → Project Settings → Input Map**: `p1_*`, `p2_*` and `pause`. Keyboard events apply to any device; gamepad events are bound to device 0 (P1) or 1 (P2).

---

## 11. Asset pipeline — where everything came from

| Asset | Source | How it gets into the game |
|---|---|---|
| Fighters (2 models) | Quaternius *Universal Base Characters* (CC0) | Copied to `assets/characters/`, given team-coloured bodysuit materials |
| Animations (43) | Quaternius *Universal Animation Library* (CC0) | Same skeleton as the fighters, so they play directly. Extracted into `assets/animations/ual_library.res` |
| Ruins, lighthouse, rocks, shrine, flame | `tools/make_models.py` (Blender) | → `models/props.glb` → `models/meshes/*.res` |
| Pistol and knife | `tools/make_weapons.py` (Blender) | → `models/weapons.glb` → `models/meshes/*.res` |
| Stone materials | Procedural noise textures in Godot | `materials/*.tres` |
| Sounds and music | `tools/synth.gd` | → `audio/*.wav` |
| Scenes, input map, animation tree, UI | `tools/bake_arena.gd` | → `main.tscn`, `scenes/`, `ui/`, `project.godot` |

> ⚠️ **The scenes are now the source of truth.** Edit them in the Godot editor. Re-running `bake_arena.gd` regenerates every scene and **overwrites** editor changes.

Regenerating everything from scratch (only if needed):
```
blender -b -P tools/make_models.py  -- <project>/models
blender -b -P tools/make_weapons.py -- <project>/models
godot --headless --path . --import
godot --headless --path . -s res://tools/bake_arena.gd
godot --headless --path . --import
```

---

## 12. Building and releasing

### Build the .exe
- **In the editor:** *Project → Export… → Windows Desktop → Export Project* → `build/LastLight.exe`.
- **From the command line:**
  ```
  godot --headless --path . --export-release "Windows Desktop" build/LastLight.exe
  ```
The export embeds all game data inside the `.exe` (`embed_pck = true`) and excludes `tools/` and `art/`. Export templates for 4.7.2 are installed in `%APPDATA%\Godot\export_templates\4.7.2.stable\`.

### Release checklist
1. Play a full match vs the bot and a full 2-player match.
2. Check the menu buttons: Versus Bot, 2 Players, Controls, Quit, Pause → Resume / Restart / Main Menu, Rematch.
3. Export the `.exe` and launch it from `build/` (not from the editor).
4. Increase the version number (see §16.2) and note changes in a changelog.
5. Zip and upload (see §3).

---

## 13. Testing

### Automated screenshot tests
`game.gd` has a test mode used during development. It starts the game, waits, saves a screenshot and quits:
```
godot --path . -- --shot=out.png [--wait=8] [--two] [--dist=3] [--closeup] [--menu]
```
| Flag | Meaning |
|---|---|
| `--shot=file.png` | Save a screenshot and quit (starts a bot match) |
| `--wait=N` | Seconds to wait before the screenshot |
| `--two` | Two-player split screen |
| `--dist=N` | Start the bot N metres away (e.g. 3 to test the knife) |
| `--closeup` | Camera in front of Player 1 (to check the weapon in the hand) |
| `--menu` | Stay on the title menu |

The same flags work on the exported `.exe`: `LastLight.exe -- --shot=out.png --two`.

### Headless smoke test
```
godot --headless --path . --quit-after 300
```
Runs 300 frames with no window; any script error is printed.

### What has been verified
Menu, bot behaviour (moving, shooting, Shadow, closing to knife range), HP loss, K.O., round progression, match end, split screen, and the exported `.exe` — via screenshots.

### What still needs human playtesting
Game feel, balance (damage, cooldowns, bot difficulty), camera comfort, gamepad support and sound levels.

---

## 14. Known issues and limitations

| Issue | Detail / workaround |
|---|---|
| Only 2 character models | The free tier of the character pack has two models in underwear; they wear generated bodysuits. Quaternius sells outfit packs. |
| Bot difficulty is fixed | One difficulty level. A standing-still player loses quickly. |
| DirectX 12 required | For old PCs, set *Project Settings → Rendering → Renderer* to **Compatibility** and re-export. |
| Unsigned .exe | SmartScreen / antivirus warning on first launch (see §3). |
| First launch is slow | Shader compilation; later launches are fast. |
| Shared keyboard limits | Some keyboards cannot register many keys at once (key "ghosting"); gamepads avoid this. |
| No settings menu | Volume, resolution and key rebinding are not yet adjustable in-game. |
| Not under version control | The folder is not a Git repository yet — see §16.1. |

---

## 15. Roadmap

| Priority | Feature |
|---|---|
| **Next** | Playtest and tune balance; bot difficulty levels (Easy / Normal / Hard) |
| **Next** | Settings menu: master/music/SFX volume, fullscreen, mouse sensitivity |
| Soon | Character select + outfits; more animations (strafe, block) |
| Soon | Second arena; hazards in the arena tied to the themes |
| Later | Online multiplayer (Godot high-level multiplayer / ENet) |
| Later | Steam or itch.io release page, trailer, code signing |

---

## 16. Software essentials every project needs

These are not specific to this game — they are habits every software project should have.

### 16.1 Version control (Git)
Version control records every change, lets you undo mistakes and share code safely. **This project is not yet in Git.** To start:
```
cd C:\Users\Administrator\Documents\as-hat
git init
git add .
git commit -m "Last Light MVP"
```
Make sure `.gitignore` excludes `.godot/`, `build/`, and `_downloads/` (generated or large files). Push to a private GitHub repository for an off-site backup.

### 16.2 Versioning (Semantic Versioning)
Use `MAJOR.MINOR.PATCH`, e.g. `0.1.0` for this MVP.
- **PATCH** (0.1.1): bug fixes only.
- **MINOR** (0.2.0): new features, nothing broken.
- **MAJOR** (1.0.0): first full release, or changes that break saves/compatibility.

### 16.3 Changelog
Keep a `CHANGELOG.md` listing what changed in each version. Players and teammates read it; you will too, six months later.

### 16.4 Backups
Rule of 3-2-1: **3** copies, on **2** different devices, **1** off-site (e.g. GitHub or cloud drive).

### 16.5 Bug reports
A useful bug report has: **what you did**, **what you expected**, **what happened**, the **version**, and a **screenshot**. Track them in a list (GitHub Issues, Trello, or a simple spreadsheet).

### 16.6 Playtesting
Watch people play **without helping them**. Note where they get confused, stuck or bored. Five fresh players find most problems.

### 16.7 Code quality
- One script per responsibility (see §7).
- Tunable numbers as named constants at the top of a file.
- Comments explain *why*, not *what*.
- Test after every change (§13).

### 16.8 Licensing
Every asset needs a licence that allows your use. Keep the licence files (see §17). Never ship assets you cannot prove you may use.

### 16.9 Accessibility
Readable text, colour plus a second cue (the HUD uses text and colour), remappable controls (planned), and subtitles for any future dialogue.

### 16.10 Performance budget
Target **60 FPS**. In the editor, *Debugger → Monitors* shows FPS and draw calls. Split screen renders the world twice, so it is the heaviest mode — test it on the weakest target PC.

### 16.11 Privacy and security
The game collects no data and needs no internet. If online features are added later, they will need a privacy policy and secure server code.

---

## 17. Licences and credits

| Item | Licence | Credit |
|---|---|---|
| Godot Engine | MIT | Godot Engine contributors — godotengine.org |
| Universal Base Characters | CC0 (public domain) | Quaternius — quaternius.com |
| Universal Animation Library | CC0 (public domain) | Quaternius (with Gonzalo Furnier) |
| Props, weapons, sounds, scenes, code | Original to this project | Made with Claude Code |

CC0 means no attribution is legally required, but crediting the artist is good practice. Licence files: `assets/characters/LICENSE_CC0.txt`, `assets/animations/README_CC0.txt`. Godot's licence must be included if you redistribute the engine; it is embedded in the exported `.exe`.

---

## 18. Glossary

| Term | Meaning |
|---|---|
| **MVP** | Minimum Viable Product — the smallest version that proves the idea works |
| **Engine** | Software that handles rendering, physics, input and audio so you only write the game rules (here: Godot) |
| **Scene / Node** | Godot's building blocks: a scene is a tree of nodes, and scenes can contain other scenes |
| **GDScript** | Godot's scripting language |
| **Hitscan** | A shot that hits instantly along a straight line (no flying bullet) |
| **Projectile** | Something that travels through the world over time (fireball, shadow orb) |
| **i-frames** | "Invulnerability frames" — a short time where hits do nothing (during a roll) |
| **Lock-on** | Camera and controls always oriented towards the opponent |
| **Navmesh** | A map of walkable ground the AI uses to find paths |
| **AnimationTree** | Godot node that blends many animations together |
| **Bone filter** | Restricting an animation to some bones (e.g. upper body) |
| **SubViewport** | An extra screen/render target — used for split screen |
| **Export template** | The pre-built engine Godot packs your game into to make an `.exe` |
| **CC0** | A licence that puts work in the public domain — free for any use |
| **Headless** | Running a program with no window, for automation |
| **SmartScreen** | Windows' warning for downloaded programs without a paid signature |
| **Semantic versioning** | The `MAJOR.MINOR.PATCH` version-numbering scheme |
