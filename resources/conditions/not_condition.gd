@tool
class_name NotCondition extends DialogCondition

## Inverts the nested [member condition] (logical NOT).
## A null condition passes (no restriction to invert).

@export var condition: DialogCondition


func evaluate(vars: Dictionary) -> bool:
	if condition == null:
		return true
	return not condition.evaluate(vars)
