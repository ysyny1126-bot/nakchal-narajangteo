extends SceneTree

## Dev-only: turns the Unity-rendered JPG frames of one clip
## (build/unity_frames/<clip>/frame_00000.jpg …) into an .ogv the game can play.
## Run (windowed, with Godot's movie writer):
##   Godot --path . --resolution 1280x720 --fixed-fps 30 --write-movie assets/cine/intro.ogv \
##         -s res://scripts/dev/frames_to_video.gd -- --clip=intro

var _files: PackedStringArray = []
var _index := 0
var _rect: TextureRect


func _init() -> void:
	var clip := "intro"
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--clip="):
			clip = arg.trim_prefix("--clip=")
	var dir := ProjectSettings.globalize_path("res://build/unity_frames/%s/" % clip)
	for file in DirAccess.get_files_at(dir):
		if file.begins_with("frame_") and file.ends_with(".jpg"):
			_files.append(dir + file)
	_files.sort()
	_rect = TextureRect.new()
	_rect.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_rect.stretch_mode = TextureRect.STRETCH_SCALE
	get_root().add_child.call_deferred(_rect)
	print("FRAMES ", clip, " ", _files.size())


func _process(_delta: float) -> bool:
	if _index >= _files.size():
		return true
	_rect.texture = ImageTexture.create_from_image(Image.load_from_file(_files[_index]))
	_index += 1
	return false
