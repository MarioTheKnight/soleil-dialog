@tool
class_name AnyOfCondition extends DialogCondition

## Passes when AT LEAST ONE nested condition passes (logical OR).
## An empty list never passes. Null entries are ignored.

@export var conditions: Array[DialogCondition] = []


func evaluate(vars: Dictionary) -> bool:
	for condition in conditions:
		if condition != null and condition.evaluate(vars):
			return true
	return false
