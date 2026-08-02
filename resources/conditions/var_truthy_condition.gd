@tool
class_name VarTruthyCondition extends DialogCondition

## Passes when [member var_name] is present and truthy : [code]true[/code],
## non-zero number, or non-empty string. Useful for flag-like variables set
## by gameplay (e.g. an UnlockChoice card effect).

@export var var_name: StringName


func evaluate(vars: Dictionary) -> bool:
	var value: Variant = vars.get(var_name, null)
	if value == null:
		return false
	if value is bool:
		return value
	if value is int:
		return value != 0
	if value is float:
		return value != 0.0
	if value is String or value is StringName:
		return not String(value).is_empty()
	return true
