extends Node
## 시작 장면: 저장된 위치의 맵을 연다.


func _ready() -> void:
	get_tree().change_scene_to_file.call_deferred(GameState.map_scene())
