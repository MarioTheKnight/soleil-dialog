@tool
extends RichTextEffect
class_name RichTextDrop

# Syntax: [drop delay=0.1 height=20.0]Text[/drop]
# Drop is a reveal-like effect that drops characters into place based on elapsed time.
var bbcode = "drop"

func _process_custom_fx(char_fx: CharFXTransform) -> bool:
	var delay: float = char_fx.env.get("delay", 0.05)
	var height: float = char_fx.env.get("height", 20.0)
	
	var char_trigger_time: float = char_fx.range.x * delay
	var time_since_trigger: float = char_fx.elapsed_time - char_trigger_time
	
	if time_since_trigger < 0.0:
		# Not dropped yet (hide it by throwing it way up and making it invisible)
		char_fx.offset.y -= height
		char_fx.color.a = 0.0
	elif time_since_trigger < 0.4:
		# Dropping animation (ease out bounce pseudo-math)
		var progress: float = time_since_trigger / 0.4
		var drop_y: float = - height * (1.0 - progress)
		char_fx.offset.y += drop_y
		# Fade in during the drop
		char_fx.color.a = clampf(progress * 2.0, 0.0, 1.0)
	else:
		# Fully rested
		char_fx.offset.y = 0.0
		char_fx.color.a = 1.0
		
	return true
