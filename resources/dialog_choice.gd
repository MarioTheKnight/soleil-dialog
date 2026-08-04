@tool
extends Resource
class_name DialogChoice

## A targeted translation key representing the text of the option.
@export var text: String = ""

## The literal ID or translation key of the dialog sequence to transition to if chosen.
## Can be empty if this choice simply closes the dialog.
@export var target_dialog_id: String = ""

## Optional boolean indicating if choosing this option should immediately end the conversation,
## ignoring target_dialog_id.
@export var ends_conversation: bool = false

## Conditions that must ALL pass (against DialogManager.dialog_vars) for this
## choice to be selectable. Empty = always available.
@export var preconditions: Array[DialogCondition] = []

## If true, a locked choice is hidden entirely ; if false (default), it is
## shown disabled (grayed out), optionally annotated with [member locked_hint_key].
@export var hide_when_locked: bool = false

## Optional translation key appended to a visible locked choice as a hint
## (e.g. "requires 15 intimidation").
@export var locked_hint_key: String = ""

## Free-form metadata carried by this choice (e.g. tone or faction tags).
## The dialog system does not interpret them ; consumers read them from the
## [signal DialogManager.choice_made] payload.
@export var tags: Array[StringName] = []


## Returns true when every precondition passes for [param vars].
func is_available(vars: Dictionary) -> bool:
	for condition in preconditions:
		if condition != null and not condition.evaluate(vars):
			return false
	return true
