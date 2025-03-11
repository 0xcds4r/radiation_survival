# Radiation Survival Mod

![icon](https://github.com/user-attachments/assets/ca231f7b-1413-45a0-8394-3a1bac27dc03)


*Survive the wasteland. Watch your health. Radiation is your enemy.*

A survival mode extension pack for [VoxelCore](https://github.com/MihailRis/VoxelEngine-Cpp), built on top of [MihailRis/base_survival](https://github.com/MihailRis/base_survival). Introduces radiation mechanics, immersive audio-visual feedback, and enhanced survival gameplay.

---

## About

Radiation Survival Mod enhances the base survival experience in VoxelCore by adding a post-apocalyptic twist. Players must navigate a hazardous world where altitude increases radiation levels, damaging health over time. Stay low to survive, manage your resources, and brace for the consequences of the wasteland.

This is my first modification for VoxelCore, inspired by and extending the work of MihailRis. Thanks to [base_survival](https://github.com/MihailRis/base_survival) for the foundation!

---

## Features

Currently implemented:

- **Modules**:
  - `gamemodes`: Switch between `survival` and `developer` modes.
  - `survival_hud`: Visual health bar with full, half, and empty hearts.
- **Game Mode Switching**: Use the `gamemode` console command to toggle modes.
- **Slow Block Destruction**: Break blocks with visual cracks and particle effects.
- **Health System**:
  - Fall damage based on impact force.
  - Death with inventory drop (configurable via `keep-inventory` rule).
- **Radiation Mechanics**:
  - Radiation levels increase with altitude (0 at y<50, 100 at y>100).
  - Visual 3D text displaying current radiation level.
  - Particle effects (radiation fog) when radiation exceeds 50.
  - Continuous health damage from high radiation.
- **Audio Immersion**:
  - Ambient wasteland sound (`ambience.ogg`).
  - Geiger counter ticking (`geyger.ogg`) at radiation > 50.
  - Death sounds (`death.ogg`, `radiation.ogg`) for dramatic effect.
  - Damage and block-breaking sound effects.

---

## Installation

### Prerequisites

- [VoxelCore](https://github.com/MihailRis/VoxelEngine-Cpp) installed and built (see [VoxelCore README](https://github.com/MihailRis/VoxelEngine-Cpp#build-project-in-linux) for instructions).
- Basic familiarity with Lua scripting and VoxelCore modding.

### Steps

1. **Clone the Repository**:
   ```bash
   git clone https://github.com/0xcds4r/radiation_survival.git
   cd radiation_survival
