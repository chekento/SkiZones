extends RefCounted
## Genuine offline 3x3 board game; isolated from resort income and saved careers.
## X is the human player, O is the computer. No imaginary button-only choices.
const WIN_LINES := [[0,1,2],[3,4,5],[6,7,8],[0,3,6],[1,4,7],[2,5,8],[0,4,8],[2,4,6]]

static func fresh(seed_value: int = 1) -> Dictionary:
	return {"cells":["","","","","","","","",""],"winner":"","finished":false,"moves":0,"seed":seed_value}

static func result(cells: Array) -> String:
	if cells.size()!=9:return "invalid"
	for line in WIN_LINES:
		var mark: String=str(cells[int(line[0])])
		if mark!="" and mark==str(cells[int(line[1])]) and mark==str(cells[int(line[2])]):return mark
	for mark in cells:
		if mark=="":return ""
	return "draw"

static func vacancies(cells: Array) -> Array:
	var open: Array=[]
	for i in range(9):
		if cells[i]=="":open.append(i)
	return open

static func _finishing_square(cells: Array, mark: String) -> int:
	for spot in vacancies(cells):
		var copy: Array=cells.duplicate()
		copy[spot]=mark
		if result(copy)==mark:return spot
	return -1

static func computer_square(cells: Array, seed_value: int = 1) -> int:
	var open: Array=vacancies(cells)
	if open.is_empty() or result(cells)!="":return -1
	var win: int=_finishing_square(cells,"O")
	if win>=0:return win
	var block: int=_finishing_square(cells,"X")
	if block>=0:return block
	# Beginner-level variety deliberately leaves chances for a human fork.
	# Stable for a saved seed, reproducible in automated tests.
	if posmod(seed_value+open.size(),5)==0:return int(open[posmod(seed_value,open.size())])
	if open.has(4):return 4
	var corners: Array=[]
	for corner in [0,2,6,8]:
		if open.has(corner):corners.append(corner)
	if not corners.is_empty():return int(corners[posmod(seed_value+open.size(),corners.size())])
	return int(open[posmod(seed_value,open.size())])

static func play(match_state: Dictionary, index: int) -> Dictionary:
	var cells: Array=match_state.get("cells",[])
	if bool(match_state.get("finished",false)) or cells.size()!=9 or index<0 or index>=9 or cells[index]!="":
		return {"ok":false,"reason":"illegal"}
	cells[index]="X"
	match_state.moves=int(match_state.get("moves",0))+1
	var won: String=result(cells)
	var opponent: int=-1
	if won=="":
		opponent=computer_square(cells,int(match_state.get("seed",1))+int(match_state.moves)*7)
		if opponent>=0:
			cells[opponent]="O"
			match_state.moves=int(match_state.moves)+1
		won=result(cells)
	match_state.finished=won!=""
	match_state.winner=won
	return {"ok":true,"human":index,"computer":opponent,"finished":match_state.finished,"winner":won}
