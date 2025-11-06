# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

**Card Golf** is a 2D roguelike card-based golf game built with Godot 4.5, inspired by games like Slay the Spire and Balatro. Players create D&D-style characters with ability scores that directly affect golf mechanics, then navigate procedurally-generated golf courses using a deck of golf clubs (treated as cards), with each club having unique distance and accuracy characteristics modified by character stats.

## Development Commands

### Running the Game
- Open the project in Godot 4.5+ editor
- Press F5 or click the "Play" button in the Godot editor
- Main scene: `res://title_screen.tscn`

### Project Structure
```
scripts/
  ├── game_screen.gd           # Core game logic, grid management, club mechanics
  ├── character_creation.gd    # D&D-style character creation with point-buy system
  ├── title_screen.gd          # Main menu screen
  ├── character.gd             # Character class with D&D ability scores
  ├── ball.gd                  # Ball movement animation with particle effects
  ├── club.gd                  # Club class (name, distance, accuracy data)
  ├── square.gd                # Grid square with terrain types
  └── hex.gd                   # Legacy file (grid is now square-based, not hex)

*.tscn files                   # Godot scene files
project.godot                  # Godot project configuration
```

## Core Architecture

### Game Flow
1. **Title Screen** (`title_screen.gd`): Main menu with Start and Quit options
2. **Character Creation** (`character_creation.gd`): Simple character creator with 4 sliders
   - Adjust Power (STR), Accuracy (DEX), Stamina (CON), and Luck (CHA)
   - Each stat ranges from 8-15
   - Pixel art golfer displayed
3. **Game Screen** (`game_screen.gd`): Main gameplay with procedurally-generated holes
4. **Hole Completion**: Triggers split-flap display transition to next hole with new club deck

### Character Stats System
Characters have four primary stats (simplified D&D):
- **Power (STR)**: Increases max distance of all clubs (+1 distance per +2 modifier)
- **Accuracy (DEX)**: Reduces accuracy deviation (directly reduces deviation by modifier amount)
- **Stamina (CON)**: Increases starting hand size (+1 club per +3 modifier)
- **Luck (CHA)**: Improves rare club chances (+5% per modifier, rare clubs have perfect accuracy)

Background stats (WIS/INT) are automatically set to 10:
- **Wisdom (WIS)**: Reduces terrain penalties (-1 penalty per +2 modifier)
- **Intelligence (INT)**: Reveals exact shot outcomes (requires INT 12+ to preview)

### Grid System (Square-Based)
- **20x20 grid** of squares with Chebyshev distance (max of dx, dy)
- **Terrain types**: FAIRWAY, ROUGH, GREEN, SAND, TREE, TEEBOX
- **Procedural generation**: Random fairway paths, bunkers near greens, scattered trees
- Grid buttons created dynamically in `_generate_hole()`

### Club Mechanics
- Each club has:
  - `max_distance`: Base shot distance (modified by character STR)
  - `accuracy`: Dictionary mapping distances to possible deviation arrays (modified by character DEX)
  - Terrain penalties: Rough/Sand reduce distance (modified by character WIS)
- **Character stat integration**:
  - Strength bonus added to club base distance during generation
  - Dexterity reduces deviation arrays (caps maximum deviation)
  - Charisma provides chance to generate rare clubs (✨ emoji, perfect accuracy)
  - Wisdom reduces terrain penalties applied during shots via `_calculate_terrain_penalty()`
- **Woods** (clubs with "Wood" or "Driver" in name):
  - Cannot shoot through trees (requires line-of-sight via Bresenham algorithm)
  - Suffer larger distance penalties in rough/sand (mitigated by WIS)
- **Power shots**: Hit one square beyond max distance with increased accuracy penalty
- Clubs are consumed after use (roguelike deckbuilding element)
- Hand size: 10 base + Constitution modifier bonus

### Split-Flap Display Animation System
A signature visual effect that animates hole transitions:
- **Row-by-row animation**: 3 rows at a time cascade from top to bottom
- **Mechanical sound**: Programmatically generated dual-frequency click sounds (600Hz + 1200Hz)
- **Color cycling**: Squares flip through random terrain colors before settling
- **Timing**: ~0.4s per batch, ~7 distinct clacks per full transition
- Blocks player interaction during animation (`is_animating_transition` flag)
- Implemented in `_animate_all_squares_transition()` and `_animate_square_flip()`

### Distance & Shot Calculation
- **Normal shot**: Highlights squares at exact club distance
- **Power shot**: Highlights squares at distance + 1 with accuracy variance shown
- **Variance visualization**: Shows perpendicular spread pattern based on accuracy modifier
- **Distance modifiers**:
  - Rough: -1 distance (woods: -2)
  - Sand: -1 distance (woods: -3)

### Ball Animation
- Arc-based tween animation with shadow effects
- Particle systems for dust (takeoff) and grass (landing)
- Ball sprite scales during flight for depth perception

## Key Implementation Details

### Color Highlighting System
- Playable squares: `COLOR_PLAYABLE` (light blue)
- Power shot range: Blend of `COLOR_PLAYABLE` and `COLOR_VARIANCE` (orange)
- Hole position explicitly restored in `_clear_highlights()` to prevent color bugs
- All terrain colors defined as constants in `game_screen.gd`

### Club Selection UI
- Buttons slide up 20px when selected, down when deselected
- Display club name, emoji, max distance, and max accuracy deviation
- Disabled during hole transitions

### Naming Convention Note
- Some variables/containers still reference "hex" (e.g., `hex_grid_container`) despite the grid being square-based
- This is legacy naming from an earlier hex-grid implementation

## Game Design Context

This project follows roguelike card game design principles:
- Procedural generation for replayability
- Resource management (limited club usage)
- Risk/reward decisions (normal vs power shots)
- Run-based progression (new deck each hole)

Reference games for design inspiration: Slay the Spire, Balatro, Monster Train, Wildrost

## Technical Notes

- **Godot version**: 4.5 (Forward Plus renderer)
- **Scene tree management**: Uses `queue_free()` for scene transitions, `await` for animations
- **Sound generation**: Procedural AudioStreamWAV synthesis (no external audio files needed)
- **Tween animations**: Extensive use of `create_tween()` for smooth transitions
- **Grid rendering**: StyleBoxFlat with borders for each button, dynamic color updates
