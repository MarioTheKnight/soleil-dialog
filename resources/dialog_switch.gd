@tool
class_name DialogSwitch extends DialogNode

## The node that BRANCHES WITHOUT A SCREEN : its cases are tried in order
## against [member DialogManager.dialog_vars], the first that passes decides
## where the conversation goes ; none passing, [member default_target_id]
## does. The player sees nothing — the next node just plays.
## [br]
## Two uses. As an ENTRY point : the game starts the conversation on the
## switch, which opens on a greeting when the introduction has already been
## heard (the game seeds what it remembers into the variables first, see
## [signal DialogManager.dialog_vars_reset]). After a [DialogContest] : the
## outcome variables decide the reply, with no choice asked of the player.

## Tried in order ; the first that passes wins.
@export var cases: Array[DialogSwitchCase] = []

## Followed when no case passes. Empty = the conversation ends.
@export var default_target_id: String = ""


## The id of the node to follow for [param vars].
func pick(vars: Dictionary) -> String:
	for case: DialogSwitchCase in cases:
		if case != null and case.passes(vars):
			return case.target_dialog_id
	return default_target_id


func targets() -> PackedStringArray:
	var out: PackedStringArray = PackedStringArray()
	for case: DialogSwitchCase in cases:
		out.append(case.target_dialog_id if case != null else "")
	out.append(default_target_id)
	return out
