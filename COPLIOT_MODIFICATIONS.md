# OpenRA Copilot Mod Project Analysis

## Project Structure
The project is based on the OpenRA engine (Red Alert 1).
- **Base Game**: `mods/ra` (Original Red Alert assets and rules).
- **Mod**: `mods/copilot` (Custom modification).
- **Socket API**: Implemented to allow external control via socket connection.

## Copilot Mod Architecture
The `copilot` mod inherits from `ra` but applies specific overrides in its `rules` directory.

### Factions
Defined in `mods/copilot/rules/world.yaml`.
- Currently, most factions are set to `Selectable: False`.
- **Russia** (Soviet) is the primary active faction.
- **Germany** (Allies) is present but likely disabled (`Selectable: False`).

### Units
Defined in `mods/copilot/rules/vehicles.yaml`, `infantry.yaml`, etc.
- **Health**: Units have approximately **3x Health** compared to the original `ra` mod.
- **Cost/Build Speed**: There are global or specific modifiers reducing cost and build time by half (and potentially another half for build speed).

### Socket API
- **Server Entry Point**: `OpenRA.Game/CopilotCommandServer.cs`
  - Handles socket connections, JSON parsing, and command dispatching.
- **Command Logic**: `OpenCodeAlert/OpenRA.Mods.Common/ServerCommands.cs`
  - Contains the actual implementation of game commands (Move, Attack, etc.).
- **Client Library**: `Copilot/openra_ai/OpenRA_Copilot_Library/game_api.py` (Python client for testing/usage).

## Proposed Modifications

### 1. Factions & Units
**Target Files**: 
- `mods/copilot/rules/world.yaml`
- `mods/copilot/rules/vehicles.yaml`

**Tasks**:
- **Enable Germany**: Modify `mods/copilot/rules/world.yaml` to make Germany (`Faction@3`) selectable and ensure it has a stripped-down unit set similar to the Soviet faction.
- **Add APC**: Add the `APC` unit to `mods/copilot/rules/vehicles.yaml`.
  - Base definition from `mods/ra/rules/vehicles.yaml`.
  - Apply **3x Health** rule.
  - Assign to Soviet faction (Russia) prerequisites if needed (or ensure it's buildable).

### 2. Socket API
**Target Files**:
- `OpenCodeAlert/OpenRA.Mods.Common/ServerCommands.cs`

**Tasks**:
- **Fix Error**: Identify and fix the logic error in current socket commands (likely related to movement or target handling).
- **Add New Commands**: Implement additional API commands as required.

## Reference Data
- **APC (Original)**: `mods/ra/rules/vehicles.yaml` (Line 460).
- **Germany (Original)**: `mods/ra/rules/world.yaml`.
