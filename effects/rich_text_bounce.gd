@tool
extends RichTextEffect
class_name RichTextBounce

# Syntax: [bounce freq=5.0 height=2.0]Text[/bounce]
var bbcode = "bounce"

func _process_custom_fx(char_fx: CharFXTransform) -> bool:
	var freq: float = char_fx.env.get("freq", 5.0)
	var height: float = char_fx.env.get("height", 4.0)
	
	var t: float = char_fx.elapsed_time * freq + char_fx.range.x * 0.5
	char_fx.offset.y -= abs(sin(t)) * height
	return true
