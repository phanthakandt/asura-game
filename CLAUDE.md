# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

**Asura Game** is a 2D action-combat game in Godot 4.6 with a Sekiro-inspired deflect/posture system. Written entirely in GDScript. Renders at 320×180 upscaled to 960×540 (GL Compatibility).

## Running the Project

Open Godot 4.6, load the project, then press **F5**. Main scene: `res://scenes/levels/level_01.tscn`.

There are no automated tests, linters, or build scripts — development is done entirely through the Godot editor.

## Input Bindings

Defined in `project.godot` under `[input]`:

| Action | Key |
|--------|-----|
| move left/right | Arrow keys |
| jump | Space (`ui_accept`) |
| walk (charge Samadhi) | Shift |
| attack | Z |
| deflect/parry | X |

## Core Systems

### Player (`scripts/player.gd`)

Two interdependent systems:

**Samadhi meter** (0–100): Fills at 80/s while Shift is held, drains at 20/s otherwise. Reaching 100 triggers a 5-second "focus lock" (`samadhi_locked = true`, `is_focused = true`). The lock resets samadhi to 0 when it expires.

**Deflect window**: Pressing X opens a 0.3s window (`can_deflect = true`). If an enemy hitbox hits the player's hurtbox during this window, `try_deflect()` is called. During focus lock, a deflect calls `enemy.receive_deflect(true)` (fills posture instantly); otherwise `receive_deflect(is_perfect)` where `is_perfect` depends on whether `enemy.in_parry_window` is true.

Attack hitbox (`$HitboxAttack`) is only `monitoring = true` for 0.2s during an attack. The hitbox X position is mirrored based on `sprite.flip_h` to face the correct direction.

### Enemy (`scripts/enemy.gd`)

**Posture system**: Tracks a 0–100 meter. Each player hit adds 5 posture (+ 15 HP damage). A successful deflect adds 30 posture (or fills to 100 if focused). Reaching 100 triggers `_enter_stun()`.

**Stun state**: `is_stunned = true` halts all enemy logic in `_physics_process`. A player attack while enemy is stunned triggers `die()` immediately (deathblow). Posture ≥ 100 also stops the enemy from initiating new attacks.

**Parry window (frame-based)**: The "slash" animation drives `Sprite2D.frame` through 0–14 over `ATTACK_DURATION = 1.4s`. `in_parry_window` is `true` only when the current frame falls in `PARRY_FRAMES_1` (2–4) or `PARRY_FRAMES_2` (10–12) — the two sword-swing beats. `$HitboxAttack`'s `monitoring`/`monitorable` are toggled on only during these frame windows, so `area_entered` (edge-triggered) fires within a parry window rather than once at attack start. `_end_attack()` must use `set_deferred()` for these flags since it can run from inside an `area_entered` callback (physics queries are locked at that point).

**Status bars**: `StatusBars` node (above the enemy's head) holds `HealthFill`/`PostureFill` `ColorRect`s. `_update_health_bar()`/`_update_posture_bar()` resize `.size.x` proportionally (`BAR_WIDTH = 28.0`) and are called whenever `hp` or `posture` changes.

### Physics Layers

| Layer | Name | Used by |
|-------|------|---------|
| 1 | Player | Player body |
| 2 | Enemy | Enemy body |
| 3 | Player HitboxAttack | Player attack Area2D |
| 4 | Enemy HitboxAttack | Enemy attack Area2D |
| 5 | Enemy Hurtbox | Enemy damage receiver |
| 6 | Ground | Level terrain |

Player `collision_mask = 42` (layers 2+4+6). Enemy `collision_mask = 37` (layers 1+3+6).

## Code Notes

- Comments and `print()` debug output are written in Thai. Key terms: **สมาธิ** = Samadhi/focus, **ศัตรู** = enemy, **ฟัน** = attack/strike.
- All timers are delta-based floats in `_physics_process`, not Godot `Timer` nodes.
- Hit detection uses `area_entered` signals on Area2D nodes, not `_physics_process` collision checks.
