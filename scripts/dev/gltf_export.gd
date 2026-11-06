extends SceneTree

## Dev-only: exports the rooms (incl. the PPS career office) and both mascots as .glb files so the
## same assets can be staged in other tools (e.g. a Unity opening cinematic).
## Run (windowed, so mesh data is available):
##   Godot --path . -s res://scripts/dev/gltf_export.gd

const RoomBuilder = preload("res://scripts/world/room_builder.gd")
const Mascot = preload("res://scripts/actors/mascot_actor.gd")
const Career = preload("res://scripts/core/career_data.gd")

const OUT := "res://build/unity_export/"


func _init() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT))
	call_deferred("_run")


func _run() -> void:
	await process_frame
	for room in ["city", "office", "review", "showroom", "pps_office"]:
		var root := Node3D.new()
		root.name = "Room_" + room
		get_root().add_child(root)
		RoomBuilder.build(room, root)
		_strip(root)
		_export(root, "room_%s.glb" % room)
		root.queue_free()
	# The career office as each episode dresses it (room_pps_office_<ep>.glb),
	# with that episode's lead and colleague, for the story clips.
	for ep in [1, 2, 3]:
		var info: Dictionary = Career.EPISODES[ep]
		RoomBuilder.office_theme = ep
		RoomBuilder.office_dept = info.dept
		RoomBuilder.office_lead = str(info.lead)
		RoomBuilder.office_name = Career.RANKS[ep].split(" ")[0]
		RoomBuilder.office_items = []
		var office := Node3D.new()
		office.name = "Room_pps_office_%d" % ep
		get_root().add_child(office)
		RoomBuilder.build("pps_office", office)
		_strip(office)
		_export(office, "room_pps_office_%d.glb" % ep)
		office.queue_free()
	for kind in ["nareumi", "dali"]:
		var actor: Node3D = Mascot.new()
		actor.name = kind.capitalize()
		get_root().add_child(actor)
		actor.build(kind)
		_strip(actor)
		_export(actor, "mascot_%s.glb" % kind)
		actor.queue_free()
	quit()


## Remove nodes glTF cannot carry (physics bodies, text labels).
func _strip(node: Node) -> void:
	for child in node.get_children():
		if child is CollisionObject3D or child is Label3D:
			child.free()
		else:
			_strip(child)


func _export(node: Node, file: String) -> void:
	var doc := GLTFDocument.new()
	var state := GLTFState.new()
	var err := doc.append_from_scene(node, state)
	if err == OK:
		err = doc.write_to_filesystem(state, ProjectSettings.globalize_path(OUT + file))
	print("EXPORT ", file, " ", error_string(err))
