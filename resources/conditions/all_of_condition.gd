@tool
class_name AllOfCondition extends DialogCondition

## Passes when ALL nested [member conditions] pass (logical AND).
## An empty list passes. Null entries are ignored.

@export var conditions: Array[DialogCondition] = []


func evaluate(vars: Dictionary) -> bool:
	for condition in conditions:
		if condition != null and not condition.evaluate(vars):
			return false
	return true
