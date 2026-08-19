## ADDED Requirements

### Requirement: The extraction reads what a mod needs
The system SHALL, for each mod, capture the other mods the post says it will not
run without, by name, as a `needs` extra. Nearly every Starsector mod needs
LazyLib, MagicLib, GraphicsLib or Nexerelin, and the post nearly always says so.

Only mods the post states are required SHALL be captured: one that is merely
recommended, supported or compatible SHALL NOT be. Every name SHALL be grounded
against the post and dropped when the post does not name it, because a model
asked what a mod needs will offer a common library whether the post did or not.
A mod SHALL never need itself, and a mod named twice SHALL be captured once.

#### Scenario: A post that lists its requirements
- **WHEN** a post says "Requires LazyLib and MagicLib"
- **THEN** that mod's `needs` holds "LazyLib" and "MagicLib"

#### Scenario: A name the post never mentions
- **WHEN** the reading names a mod that appears nowhere in the post
- **THEN** that name is dropped and the run logs why

#### Scenario: A mod that is only recommended
- **WHEN** a post says another mod is recommended or works well with this one
- **THEN** it is not captured as something this mod needs

#### Scenario: A post that names no requirement
- **WHEN** a post says nothing about what the mod needs
- **THEN** that mod has no `needs`, rather than a guessed library
