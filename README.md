# Blackwood Valley: Outbreak

A **Godot 4.3 survival RPG vertical slice** targeting **Web/HTML5** (desktop browsers + landscape Android tablets). Frozen pine woods, a ranger cabin, three Blighted Shamblers, and one flashlight that keeps you alive — and gives you away.

**Zero external assets.** Every sprite, light, particle, UI panel and sound effect is generated procedurally at runtime (`_draw()` calls, generated textures, synthesized PCM audio), so the repository is pure code and exports cleanly from a headless CI runner.

---

## Quick start (local)

1. Install [Godot 4.3](https://godotengine.org/download) (standard build, no addons).
2. Open this folder as a project (`project.godot`).
3. Press **F5** / Play. First import takes a few seconds.

### Desktop controls

| Input | Action |
|---|---|
| WASD / Arrows | Move (8-way) |
| Mouse | Aim flashlight + hatchet |
| Left click / Space | Hatchet attack |
| Shift | Sprint (drains stamina, loud footsteps) |
| C | Sneak (slow, quiet) |
| E | Interact (door, chest, stove) |
| 1 / 2 | Use bandage / eat ration |
| F5 / F9 | Quick save / quick load |
| T | Toggle touch controls |
| R | Restart after death |

### Touch controls (auto-shown on touchscreens)

- **Bottom-left**: virtual analog joystick.
- **Bottom-right**: ATK / USE / RUN / SNK / HEAL / EAT buttons (all well above the 48px minimum touch target).
- Aim follows your movement direction automatically.

## The loop

1. You spawn at a dying campfire with failing body temperature.
2. **Sprint drains stamina and makes noise** — shamblers hear it. Sneaking is quiet.
3. Reach the cabin, close the door behind you (it blocks movement **and** enemy sight), search the chest.
4. Rest at the woodstove: restores warmth, **saves the game** (also F5).
5. Slay all three Blighted Shamblers. Your flashlight cone reveals you at range — darkness is a tool.
6. Dropped rations heal hunger; bandages heal HP; the cold and hunger never stop.

## Deploy to GitHub Pages

1. **Push this folder's contents to a GitHub repository** (branch `main`).
2. In the repo: **Settings → Pages → Build and deployment → Source: GitHub Actions**.
3. That's it. Every push to `main` triggers `.github/workflows/export.yml`, which:
   - runs a **headless smoke test** that boots the whole game and fails CI on any script error,
   - exports the Web build with `barichello/godot-ci:4.3`,
   - deploys it to Pages.
4. Play at `https://<your-user>.github.io/<repo>/` about two minutes after the push.

> The workflow artifact `web-build` can also be downloaded and hosted anywhere (itch.io, Netlify, etc. — it is a static `index.html` + `.wasm` bundle).

### Exporting locally

Project → Export → preset **"Web"** → Export (requires the Godot 4.3 export templates). Output goes to `build/web/`.

## Project structure

```
project.godot            # 1280x720, canvas_items/keep stretch, Compatibility renderer
export_presets.cfg       # "Web" preset -> build/web/index.html
.github/workflows/export.yml
scenes/main.tscn         # nearly empty: one Node2D + main.gd
scripts/
  main.gd                # world assembler: builds everything at runtime
  player.gd              # movement, stats, combat, flashlight, camera juice
  shambler.gd            # Idle/Alert/Chase AI, raycast steering, telegraphed attacks
  autoload/
    game_manager.gd      # input map (runtime), noise bus, objectives
    save_manager.gd      # user://save.json I/O
    sfx.gd               # 11 procedurally synthesized sounds
  world/                 # ground, cabin walls, hinged door, chest, stove, pines, pickups
  ui/                    # HUD, virtual joystick, touch buttons
  fx/vignette.gd         # low-HP / low-temp screen effects
  util/procgen.gd        # generated textures (flashlight cone, soft dots, gradients)
  dev/smoke_test.gd      # headless-only CI self-test
```

## Tuning knobs

- World size / cabin position / enemy spawns: constants at the top of `scripts/main.gd`.
- Player speeds and stat drain rates: constants at the top of `scripts/player.gd`.
- Enemy senses and aggression: constants at the top of `scripts/shambler.gd`.

## Notes

- Web browsers unlock audio only after the first click/tap — the wind ambience starts on your first input by design.
- The smoke-test autoload is inert outside headless CI (`DisplayServer.get_name() != "headless"`), it never runs in your game.
- Saves live in `user://save.json` (browser: IndexedDB-backed persistent storage).
