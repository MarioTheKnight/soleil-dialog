@tool
class_name VarEqualsCondition extends DialogCondition

## Passes when [member var_name] holds a numeric value equal to
## [member expected_value]. A missing or non-numeric variable never passes.

@export var var_name: StringName
@export var expected_value: int = 0


func evaluate(vars: Dictionary) -> bool:
	var value: Variant = vars.get(var_name, null)
	if not (value is int or value is float):
		return false
	return int(value) == expected_value
