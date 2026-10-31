extends RefCounted
## Strict, offline-testable selection of this project's published ARM64 builds.
const API="https://api.github.com/repos/chekento/SkiZones/releases?per_page=30"
const RELEASES="https://github.com/chekento/SkiZones/releases"
const PACKAGE="cloud.kosch.skizones"
static func version_parts(value: Variant) -> Array:
	if not value is String: return []
	var regex:=RegEx.new();regex.compile("^v?([0-9]+)\\.([0-9]+)\\.([0-9]+)$")
	var match=regex.search(value)
	if match==null: return []
	var parts: Array=[]
	for index in range(1,4):
		if match.get_string(index).length()>5: return []
		parts.append(match.get_string(index).to_int())
	return parts
static func newer(candidate: Variant, current: Variant) -> bool:
	var left:=version_parts(candidate);var right:=version_parts(current)
	if left.is_empty() or right.is_empty(): return false
	for i in range(3):
		if left[i]!=right[i]:return left[i]>right[i]
	return false
static func select(releases: Variant, current: String) -> Dictionary:
	if not releases is Array: return {}
	var chosen: Dictionary={}
	for release in releases:
		if not release is Dictionary or release.get("draft",true)!=false: continue
		var tag=release.get("tag_name","")
		if not newer(tag,current) or not chosen.is_empty() and not newer(tag,chosen.version): continue
		var version: String=tag.trim_prefix("v")
		var apk: String="SkiZones-%s-android-arm64.apk" % version
		var base: String=RELEASES+"/download/"+tag+"/"
		var assets=release.get("assets",[])
		if not assets is Array:continue
		var found: Dictionary={}
		for asset in assets:
			if not asset is Dictionary:continue
			var name=asset.get("name","")
			if name in [apk,"manifest.json"] and asset.get("browser_download_url","")==base+name:
				found[name]=base+name
		if found.size()==2:chosen={"version":version,"apk":found[apk],"manifest":found["manifest.json"],"file_name":apk,"release":RELEASES+"/tag/"+tag}
	return chosen
static func manifest(value: Variant, release: Dictionary, installed_code: int) -> Dictionary:
	if not value is Dictionary or release.is_empty():return {}
	for key in ["version","file_name"]:
		if value.get(key)!=release.get(key):return {}
	if value.get("package")!=PACKAGE or value.get("architecture")!="arm64-v8a":return {}
	for key in ["version_code","size_bytes"]:
		if not value.get(key) is float and not value.get(key) is int:return {}
		if not is_finite(float(value[key])) or value[key]!=floorf(value[key]):return {}
	if value.version_code<=installed_code or value.version_code>2147483647 or value.size_bytes<1000000 or value.size_bytes>536870912:return {}
	var regex:=RegEx.new();regex.compile("^[0-9a-f]{64}$")
	if not value.get("sha256") is String or regex.search(value.sha256)==null:return {}
	return value.duplicate(true)
