@tool
class_name DialogActivity extends DialogNode

## The node that HANDS THE CONVERSATION TO THE GAME : a shop, a mini-game, a
## test, a scene — anything the game knows how to run. The manager emits
## [signal DialogManager.activity_started], waits for
## [method DialogManager.resolve_activity], then follows
## [member next_dialog_id]. Whatever the game decided, it says so by WRITING
## VARIABLES into [member DialogManager.dialog_vars] ; the nodes that follow
## (a [DialogSwitch], a [DialogPrompt] with guarded choices) read them.
## [br]
## That sentence is the whole contract between the dialog and the game, on
## purpose : the manager knows nothing of shops or card games, and the rules
## of any activity can change entirely without the graph, the conditions or
## the content moving. This node carries no rule of its own — only what it
## writes, whether it starts from zero, and whether the dialog box should
## step aside while it runs.
## [br]
## Games give it a face in two ways : the free [member activity] label,
## dispatched on by name ; or a SUBCLASS carrying a typed payload
## ([DialogContest] in this addon for the card phase ; a shop node in a game,
## pointing at the merchant to open), dispatched on by class. Tools discover
## subclasses as new kinds of node.

## What happens to the outcome variables when the activity begins.
enum Mode {
	## Its outcome variables are erased first : this activity alone decides.
	## The default — a writer who places a second one does not expect the
	## first to make it easier.
	FRESH,
	## Its outcome variables keep their value : momentum builds across the
	## conversation.
	CUMULATIVE,
}

## What the game should run, for games that dispatch on a name rather than
## on a subclass. A subclass sets its own in [method Object._init].
@export var activity: StringName = &""

## Whether the outcome variables start from zero ([constant Mode.FRESH]) or
## add up with what earlier activities left ([constant Mode.CUMULATIVE]).
## Only the variables listed in [member outcome_vars] are ever touched.
@export var outcome_mode: Mode = Mode.FRESH

## The variables this activity writes. Declared so that a FRESH activity
## knows what to erase, so that tools can offer these names to the
## conditions that follow, and so that a validator can tell a guarded choice
## nobody can ever unlock.
@export var outcome_vars: Array[StringName] = []

## Node played once the activity is resolved — usually a [DialogSwitch] on
## the outcome, or a [DialogPrompt] whose choices it unlocks. Empty = the
## conversation ends.
@export var next_dialog_id: String = ""

## Whether the dialog box hides while the activity runs. A card hand shown
## beside the text keeps it ; a shop that takes the whole screen hides it,
## and gets it back at [method DialogManager.resolve_activity].
@export var hides_dialog: bool = false


func targets() -> PackedStringArray:
	return PackedStringArray([next_dialog_id])
