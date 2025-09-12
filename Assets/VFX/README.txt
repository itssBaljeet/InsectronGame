This file is used to track the current convention of script for VFX.

Each VFX scene (e.g. a PackedScene for a slash, fireball, etc.) should implement:

A method play(from: Vector3, to: Vector3) -> void that starts the effect from a source point to a target point.

A signal finished emitted when the effect animation is complete.

Internal handling of its animation/particles/tweens. For example, a projectile scene could move from from to to, play an impact, then emit finished.
