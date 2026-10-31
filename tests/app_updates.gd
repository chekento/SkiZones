extends SceneTree
const Catalog=preload("res://src/core/update_catalog.gd")
var passed:=0
var failed:=0
func check(ok: bool,title: String) -> void:
	if ok:passed+=1;print("PASS ",title)
	else:failed+=1;push_error("FAIL "+title)
func release(version: String) -> Dictionary:
	var tag: String="v"+version;var file: String="SkiZones-%s-android-arm64.apk"%version
	var base: String=Catalog.RELEASES+"/download/"+tag+"/"
	return {"tag_name":tag,"draft":false,"prerelease":true,"assets":[{"name":file,"browser_download_url":base+file},{"name":"manifest.json","browser_download_url":base+"manifest.json"}]}
func _init() -> void:
	check(Catalog.newer("v0.17.0","0.16.9") and Catalog.newer("0.10.0","0.9.99"),"Numeric versions are ordered correctly including two-digit components")
	check(not Catalog.newer("0.17.0","0.17.0") and not Catalog.newer("0.16.99","0.17.0"),"The updater never reinstalls the same version or selects a downgrade")
	check(not Catalog.newer("v0.18.0/../attack","0.17.0") and not Catalog.newer(null,"0.17.0"),"Malformed versions and path injection cannot become update targets")
	var old:=release("0.16.0");var fresh:=release("0.18.0");var chosen:=Catalog.select([old,fresh,release("0.17.0")],"0.17.0")
	check(chosen.get("version")=="0.18.0","The newest complete published build is selected even when GitHub labels the preview a prerelease")
	var draft:=release("0.20.0");draft.draft=true
	check(Catalog.select([draft,fresh],"0.17.0").version=="0.18.0","Drafts are excluded from the update channel")
	var bad:=release("0.21.0");bad.assets[0].browser_download_url="https://another.example/update.apk"
	check(Catalog.select([bad],"0.17.0").is_empty(),"Only APK URLs inside this repository's exact release are accepted")
	bad=release("0.21.0");bad.assets.pop_back()
	check(Catalog.select([bad],"0.17.0").is_empty() and Catalog.select({"message":"rate limit"},"0.17.0").is_empty(),"Incomplete releases and API error objects are not installable")
	var build: Dictionary={"version":"0.18.0","version_code":23,"file_name":chosen.file_name,"package":Catalog.PACKAGE,"architecture":"arm64-v8a","size_bytes":33000000,"sha256":"a".repeat(64)}
	check(not Catalog.manifest(build,chosen,22).is_empty(),"The matching architecture, package, size, version and checksum permit a newer build")
	for key in ["version","file_name","package","architecture","sha256"]:
		var invalid:=build.duplicate(true);invalid[key]="wrong"
		check(Catalog.manifest(invalid,chosen,22).is_empty(),"The manifest rejects a mismatched "+key)
	for value in [0,22,23.5,INF,"24"]:
		var invalid:=build.duplicate(true);invalid.version_code=value
		check(Catalog.manifest(invalid,chosen,22).is_empty(),"Invalid or old Android version code is rejected: "+str(value))
	for value in [-1,536870913,123.5,"33000000"]:
		var invalid:=build.duplicate(true);invalid.size_bytes=value
		check(Catalog.manifest(invalid,chosen,22).is_empty(),"Invalid APK size is rejected: "+str(value))
	print("APP UPDATES: %d passed; %d failed"%[passed,failed]);quit(1 if failed else 0)
