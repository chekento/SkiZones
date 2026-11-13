extends RefCounted
## Isolated local arcade rules. No resort, account or economy dependency.
static func new_match(pairs:int,rng:RandomNumberGenerator)->Dictionary:
	if pairs not in [4,6,8]:return {}
	var deck:Array=[]
	for i in range(pairs):deck.append(i);deck.append(i)
	for i in range(deck.size()-1,0,-1):
		var other:int=rng.randi_range(0,i)
		var old:int=deck[i];deck[i]=deck[other];deck[other]=old
	return {"deck":deck,"open":[],"matched":[],"moves":0,"pairs":pairs,"done":false}

static func flip(state:Dictionary,index:int)->bool:
	if state.is_empty() or state.done or state.open.size()>=2 or index<0 or index>=state.deck.size() or index in state.open or index in state.matched:return false
	state.open.append(index)
	if state.open.size()==2:
		state.moves=int(state.moves)+1
		if state.deck[int(state.open[0])]==state.deck[int(state.open[1])]:
			state.matched.append_array(state.open);state.open.clear()
			state.done=state.matched.size()==state.deck.size()
	return true

static func cover(state:Dictionary)->void:
	if state.get("open",[]).size()==2:state.open.clear()
