## HazardResource.gd
## Defines a field hazard that can be placed on board cells
class_name HazardResource
extends Resource

@export var hazardName: String = "Unknown"
@export var icon: Texture2D
@export var vfxScene: PackedScene  # Visual effect to display on the cell

## Duration and stacking
@export var baseDuration: int = 3  # turns
@export var maxStacks: int = 1
@export var stackable: bool = false

## Effects
@export var damageOnEnter: int = 0  # Instant damage when stepping on it
@export var damagePerTurn: int = 0  # Damage at turn end if standing on it
@export var statusEffectOnEnter: StatusEffectResource  # Apply status when entering
@export var statusEffectPerTurn: StatusEffectResource  # Apply status each turn

## Clearing
@export var clearableByTypes: Array[String] = []  # e.g. ["water", "wind"] attacks can clear fire
@export var clearsOnExit: bool = false  # Disappears when unit leaves (like a trap)

## Interaction rules
@export var affectsFactions: int = -1  # Bitmask: -1 affects all, or specific faction bits
@export var blockMovement: bool = false  # Can't move through it
@export var blockVision: bool = false  # Blocks line of sight
