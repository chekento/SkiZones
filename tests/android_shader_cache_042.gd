extends SceneTree
## 0.42 native GLES3 cold-start cache policy smoke test.
## This is a configuration test; Android emulator Kaltstarts validate runtime.
var passed := 0
var failed := 0
func check(value: bool, label: String) -> void:
	if value: passed += 1; print("PASS ",label)
	else: failed += 1; push_error("FAIL " + label)
func run() -> void:
	var key := "rendering/shader_compiler/shader_cache/enabled"
	check(ProjectSettings.has_setting(key + ".android"), "Explicit Android-only GLES3 shader cache policy exists")
	check(ProjectSettings.get_setting(key + ".android", true) == false, "Android persistent GLES3 shader binary cache disabled")
	var actual: bool = bool(ProjectSettings.get_setting_with_override(key))
	check(actual == (not OS.has_feature("android")), "Feature override leaves desktop shader caching on and Android caching off")
	check(str(ProjectSettings.get_setting("application/config/version", "")) == "0.42.0", "Same 0.42 app version and save identity used")
	print("RESULT: %d passed; %d failed" % [passed,failed])
	quit(1 if failed else 0)
func _init() -> void: call_deferred("run")
