extends SceneTree
## Diagnostic inventory: reports actual full return circuits; no source or save edits.
const Resort=preload("res://src/core/resort.gd")
const Maps=preload("res://src/core/maps.gd")
const Geo=preload("res://src/core/real_resorts.gd")
const Ops=preload("res://src/core/operations.gd")
func _init():call_deferred("run")
func run():
 var selected: Array=Maps.FANTASY_MAPS.keys()+Geo.IDS
 for argument in OS.get_cmdline_user_args():
  if argument.begins_with("--map="):selected=[argument.trim_prefix("--map=")]
 for map_id in selected:
  var model=Resort.new()
  model.new_game(true,20261027,map_id)
  model.weather_index=0
  model.minute=600
  for lift in model.lifts:
   Ops.fill_stations(model,int(lift.id),true)
   lift.fault=""
  Ops.refresh_duty(model)
  model._operational_change()
  var routes: Array=model.routes_for(2)
  var ids: Dictionary={}
  for route in routes:ids[int(route.target)]=true
  var missing: Array=[]
  var closed: Array=[]
  for piste in model.pistes:
   if not model.piste_open(piste):closed.append({"id":piste.id,"name":piste.name})
   elif not ids.has(int(piste.id)):missing.append({"id":piste.id,"name":piste.name})
  print("ROUTE_AUDIT ",JSON.stringify({"map":map_id,"pistes":model.pistes.size(),"complete_routes":ids.size(),"closed":closed,"missing_circuit":missing}))
 quit()
