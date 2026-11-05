extends SceneTree
## Ground motion must follow rendered faces, including shared edges and rebuilds.
const Ground=preload("res://src/world/ground_surface.gd")
var passed:=0
var failed:=0
func _init()->void:call_deferred("run")
func check(ok:bool,label_value:String)->void:
 if ok:passed+=1;print("PASS ",label_value)
 else:failed+=1;push_error("FAIL "+label_value)
func mesh_at(raise_by:float=0.0,shift:Vector2=Vector2.ZERO)->ArrayMesh:
 var vertices:=PackedVector3Array()
 # Two triangles with opposite projected winding, on y=10+x/2+z/4.
 for at in [Vector2(0,0),Vector2(20,0),Vector2(0,20),Vector2(20,0),Vector2(0,20),Vector2(20,20)]:
  vertices.append(Vector3(at.x+shift.x,10+at.x*.5+at.y*.25+raise_by,at.y+shift.y))
 var data:=[];data.resize(Mesh.ARRAY_MAX);data[Mesh.ARRAY_VERTEX]=vertices
 var result:=ArrayMesh.new();result.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,data)
 return result
func run()->void:
 var ground:=Ground.new();ground.configure(mesh_at())
 for at in [Vector2(1,1),Vector2(18,1),Vector2(18,18),Vector2(1,18),Vector2(10,10),Vector2(0,0),Vector2(20,20)]:
  var expected:=Vector3(at.x,10+at.x*.5+at.y*.25,at.y)
  check(ground.position(at,-99).is_equal_approx(expected),"Rendered-plane height at "+str(at))
  check(ground.position(at,-99,2).is_equal_approx(expected+Vector3.UP*2),"Cached point preserves independent offset at "+str(at))
 check(ground.position(Vector2(21,10),37).y==37,"Outside mesh uses caller fallback")
 var patch:=ground.clip(PackedVector2Array([Vector2(3,3),Vector2(15,3),Vector2(15,15),Vector2(3,15)]))
 var aligned:bool=not patch.is_empty()
 for p in patch:aligned=aligned and absf(p.y-(10+p.x*.5+p.z*.25))<.0001
 check(aligned,"Clipped snow corridor shares the same exact ground plane")
 var shift:=Vector2(24000,-18000)
 ground.configure(mesh_at(0,shift))
 check(is_equal_approx(ground.position(shift+Vector2(7.125,9.25),-99).y,15.875),"Distant real-map coordinates retain sub-metre precision")
 check(is_equal_approx(ground.position(shift,-99).y,10.0),"Distant shared vertex stays on the rendered terrain")
 ground.configure(mesh_at(50))
 check(is_equal_approx(ground.position(Vector2(10,10)).y,67.5),"Replacing terrain invalidates cached heights and coefficients")
 print("RESULT: %d passed; %d failed" % [passed,failed]);quit(1 if failed else 0)
