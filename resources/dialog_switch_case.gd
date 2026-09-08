@tool
class_name DialogSwitchCase extends Resource

## One case of a [DialogSwitch] : when every condition passes, the switch
## follows [member target_dialog_id]. No condition = always passes.

## Conditions that must ALL pass against [member DialogManager.dialog_vars].
@export var conditions: Array[DialogCondition] = []

## Node followed when the case applies. Empty = the conversation ends.
@export var target_dialog_id: String = ""


## Whether every condition passes for [param vars].
func passes(vars: Dictionary) -> bool:
	for condition: DialogCondition in conditions:
		if condition != null and not condition.evaluate(vars):
			return false
	return true
