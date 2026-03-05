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
