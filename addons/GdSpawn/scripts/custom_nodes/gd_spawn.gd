@tool
@icon("res://addons/GdSpawn/icons/GdSpawn.svg")
extends Node3D
class_name GdSpawn

@export_category("Surface Placement")
@export_flags_3d_physics var surface_placement_collision_mask: int = 0xFFFFFFFF

@export_category("Curve Placement")
@export_flags_3d_physics var curve_placement_collision_mask: int = 0xFFFFFFFF
@export var curve_spawn_profile: GdSpawnCurveSpawnProfile
@export var curve_spawn_settings: GdSpawnCurveSpawnSettings


@export_category("Physics Placement")
@export var random_spawn_profile: GdSpawnRandomSpawnProfile
@export_flags_3d_physics var physics_placement_collision_mask: int = 0xFFFFFFFF


