<div align="center">

<img src="https://r2.fivemanage.com/GPYOH8Hq4GPyAY7czrgLe/pulsarbanner.png" alt="Pulsar Framework" width="100%" />

<br/>

# PULSAR-DAMAGE

### Limb damage, medical/hospital, prison, and fire department systems

<br/>

![Lua](https://img.shields.io/badge/Lua_5.4-2C2D72?style=flat-square&logo=lua&logoColor=white)
![FiveM](https://img.shields.io/badge/FiveM-F40552?style=flat-square)

<br/>

<sub>Enjoy the framework? A coffee helps keep active development, hardening, and support going.</sub>

<a href="https://buymeacoffee.com/pulsarframework"><img src="https://cdn.buymeacoffee.com/buttons/v2/default-yellow.png" alt="Buy Me A Coffee" style="height: 50px !important;width: 180px !important;" /></a>

<br/>

[Overview](#overview) · [What's Changed](#whats-changed) · [Configuration](#configuration) · [Dependencies](#dependencies)

</div>

---

## Overview

Per-weapon/per-limb damage, the knockdown/death/bleedout cycle, hospital check-in and treatment (EMS billing split between the EMS and government accounts), ICU admission/release, prison intake, and fire department response — all in one server-authoritative resource, no UI of its own

Death/knockdown state (`isDead`, `deadData`, `isDeadTime`, `releaseTime`) lives on the player's state bag; `pulsar_hud` reads it to drive the death screen but owns none of it — this resource is the single source of truth for both the release timers and the medical price it broadcasts via `GlobalState["Medical:Pricing"]`

---

## What's Changed

Changes made on top of the original Pulsar release (`v1.0.0`):

**Bone injuries** (merged from Xoticz-health) — `server/injuries.lua`, `client/injuries.lua`, `Config.Injuries`
- Server-authoritative per-limb injury (0–100) and bleeding stacks, saved on the character (`Injuries`) and mirrored to the client through the `injuries` player state bag (`plsr.State.flags.injuries`).
- Limping when a leg/lower-body injury reaches `limpThreshold`, using the same limp as low HP (`ApplyLimp`).
- Bleeding ticks drain HP per stack but never below `minHealth`, so bleeding cannot kill on its own. Bleed chance is set per weapon class.
- Fall damage reported on the root bone now lands on a random leg/foot instead of being dropped (`noBoneFallback`).
- Medical items (`bandage`, `firstaid`, `ifak`, `gauze`, `tourniquet`, …) heal limbs and stop bleeding through `Injuries.items`.
- A full revive (hospital, `/heal`, respawn) clears injuries when `clearOnRevive = true`.
- Optional admin test commands: `/hurtbone`, `/showinjuries`, `/clearinjuries` (`testCommands = true`).
- Injury data is exposed to `pulsar_inventory`'s Health & Injuries tab (`plsr.Damage.Injuries:Get`).

---

## Configuration

`config/shared.lua` is client-exposed (all of it is already visible to players in-game one way or another, nothing here is secret) and holds everything owner-tunable: medical/prison prices, release/progress/cooldown timers, health thresholds, and the hospital's ICU/bed/polyzone location data (`Hospital.icuBeds`, `Hospital.bedPolys`, `Hospital.bedModels`, `Hospital.beds`) and the prison check-in zone (`Prison.location`)

`data/weapons.lua` and `data/limbs.lua` hold weapon-class and limb/bone-hash data — content tables, not owner settings, already globbed into both `client_scripts` and `server_scripts`

---

## Dependencies

- `pulsar_core` — framework core
- `pulsar_pwnzor` — anti-cheat check loaded alongside every resource
- `pulsar_hud` — displays this resource's death/knockdown/hospital-price state, doesn't own it
- `pulsar_inventory` — provides the medical items, and its Health & Injuries tab reads this resource's injury data
- `pulsar_animations` — the injury limp shares its limp walk style

---

## License

This resource is free to use and modify under the [Pulsar Framework License](LICENSE.md). Redistribution is welcome as long as it stays free — selling this resource or any derivative of it requires written permission from the Pulsar Framework team.

---

<div align="center">

![Pulsar Framework](https://img.shields.io/badge/Pulsar-Framework-7c3aed?style=flat-square)
![Built for FiveM](https://img.shields.io/badge/Built_for-FiveM-F40552?style=flat-square)

</div>
