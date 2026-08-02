@tool
class_name VarAtLeastCondition extends DialogCondition

## Passes when [member var_name] holds a numeric value >= [member min_value].
## A missing or non-numeric variable counts as 0.

@export var var_name: StringName
@export var min_value: int = 0


func evaluate(vars: Dictionary) -> bool:
	var value: Variant = vars.get(var_name, 0)
	if not (value is int or value is float):
		return 0 >= min_value
	return int(value) >= min_value
