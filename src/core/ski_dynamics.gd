extends RefCounted
## Specific energy in J/kg: mass cancels. Uphill skiing cannot create free energy.
const GRAVITY := 9.81
const FRICTION := 0.025
const AIR_DRAG := 0.008
const MIN_GLIDE := 0.7
const MAX_HIKE_GRADE := 0.55

static func profile(mountain: RefCounted, points: Array, ability: int, personal: float = 1.0, roughness: float = 0.0) -> Dictionary:
	var length: float = mountain.polyline_length(points)
	var count := clampi(ceili(length/4.0),8,512)
	var positions: Array[Vector3] = []
	var limits: Array[float] = []
	var cap: float = [7.5,11.5,15.0][ability]*personal/(1+roughness*0.2)
	for i in range(count+1):
		positions.append(mountain.world(mountain.point_on_path(points,float(i)/count)))
		limits.append(cap)
	for i in range(1,count):
		var a := Vector2(positions[i].x-positions[i-1].x,positions[i].z-positions[i-1].z)
		var b := Vector2(positions[i+1].x-positions[i].x,positions[i+1].z-positions[i].z)
		var angle := acos(clampf(a.normalized().dot(b.normalized()),-1,1))
		if angle > 0.035: limits[i] = minf(cap,maxf(1.2,sqrt(a.length()/angle*[1.5,2.2,3.0][ability])))
	limits[-1] = minf(limits[-1],3.0)
	for i in range(count-1,-1,-1):
		var ds := positions[i].distance_to(positions[i+1])
		limits[i] = minf(limits[i],sqrt(limits[i+1]*limits[i+1]+2*1.8*ds))
	var speed := minf(2.5*personal,limits[0])
	var seconds := 0.0
	var walked := 0.0
	var carried := 0.0
	var walking_mode := false
	var samples: Array = [[0.0,0.0,0,speed]]
	var ok := true
	var reason := ""
	for i in range(1,count+1):
		var delta := positions[i]-positions[i-1]
		var ds := maxf(delta.length(),0.001)
		var horizontal := maxf(Vector2(delta.x,delta.z).length(),0.001)
		var rise := delta.y
		var resistance := FRICTION*GRAVITY*horizontal/ds*(1+roughness)+AIR_DRAG*speed*speed
		var acceleration := -GRAVITY*rise/ds-resistance
		var energy_end := speed*speed+2*acceleration*ds
		var next_speed := minf(sqrt(maxf(0,energy_end)),limits[i])
		if (next_speed < MIN_GLIDE or walking_mode) and rise >= -0.005:
			var glide := 0.0 if walking_mode else clampf((speed*speed-MIN_GLIDE*MIN_GLIDE)/maxf(-2*acceleration*ds,0.001),0,1)
			if glide > 0.001 and glide < 0.999:
				seconds += 2*ds*glide/maxf(speed+MIN_GLIDE,0.01)
				samples.append([seconds,(i-1+glide)/count,0,MIN_GLIDE])
			walking_mode = true
			var foot_distance := ds*(1-glide)
			var grade := maxf(0,rise/horizontal)
			if grade > MAX_HIKE_GRADE:
				ok = false
				reason = "Gegenanstieg zu steil zum Stapfen (%.0f %%). Mit weiteren Wegpunkten queren." % (grade*100)
			var foot_speed := clampf(1.0/(1+3.8*grade),0.3,1.0)*(0.94+ability*0.06)
			seconds += foot_distance/foot_speed
			walked += foot_distance
			speed = foot_speed
			samples.append([seconds,float(i)/count,1,speed])
		else:
			walking_mode = false
			seconds += 2*ds/maxf(speed+next_speed,0.15)
			if rise > 0: carried += rise
			speed = next_speed
			samples.append([seconds,float(i)/count,0,speed])
	for sample in samples: sample[0] /= maxf(seconds,0.001)
	return {"ok":ok,"message":reason,"minutes":maxf(0.15,seconds*0.5),"samples":samples,"hike_meters":walked,"carry_rise":carried}
