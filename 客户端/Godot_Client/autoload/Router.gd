extends Node
signal navigate(page: int)
signal toast_requested(text: String)
signal invite_received(data: Dictionary)
var current: int = 0
var enabled: bool = true

func go(page: int) -> void:
	if not enabled or current == page:
		return
	current = page
	navigate.emit(page)

func toast(text: String) -> void:
	toast_requested.emit(text)

func invite(data: Dictionary) -> void:
	invite_received.emit(data)

func page_path(page: int) -> String:
	return "res://scenes/ui/%02d.tscn" % page
