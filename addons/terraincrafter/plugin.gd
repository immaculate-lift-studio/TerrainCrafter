@tool
extends EditorPlugin

func _enter_tree():
	# Register the TerrainGenerator node
	var terrain_crafter_icon = preload("res://addons/terraincrafter/assets/icons/terraincrafter_node.png")
	add_custom_type("TerrainCrafter", "Node3D", preload("res://addons/terraincrafter/terrain_crafter.gd"), terrain_crafter_icon)

func _exit_tree():
	# Unregister the TerrainGenerator node
	remove_custom_type("TerrainGenerator")
