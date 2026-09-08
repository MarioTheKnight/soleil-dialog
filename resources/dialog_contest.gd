@tool
class_name DialogContest extends DialogNode

## The node that hands the conversation to the GAME'S MINI-GAME — a hand of
## social cards, a test, anything : the manager emits
## [signal DialogManager.card_play_phase_started], waits for
## [method DialogManager.resolve_card_play_phase], then follows
## [member next_dialog_id]. Whatever the mini-game decides, it says so by
## WRITING VARIABLES into [member DialogManager.dialog_vars] ; the nodes that
## follow (a [DialogSwitch], a [DialogPrompt] with guarded choices) read them.
## [br]
## That sentence is the whole contract between the dialog and the mini-game,
## on purpose : the rules of the contest can change entirely without the
## graph, the conditions or the content moving. This node carries no rule of
## its own — only what it writes, and whether it starts from zero.

## What happens to the outcome variables when the contest begins.
enum Mode {
	## Its outcome variables are erased first : this contest alone decides.
	## The default — a writer who places a second contest does not expect the
	## first one to make it easier.
	FRESH,
	## Its outcome variables keep their value : momentum builds across the
	## conversation.
	CUMULATIVE,
}

## Whether the outcome variables start from zero ([constant Mode.FRESH]) or
## add up with what earlier contests left ([constant Mode.CUMULATIVE]).
## Only the variables listed in [member outcome_vars] are ever touched.
@export var outcome_mode: Mode = Mode.FRESH

## The variables this contest writes (e.g. [code]charme[/code],
## [code]intimidation[/code]). Declared so that a FRESH contest knows what to
## erase, so that tools can offer these names to the conditions that follow,
## and so that a validator can tell a guarded choice nobody can ever unlock.
@export var outcome_vars: Array[StringName] = []

## Node played once the contest is resolved — usually a [DialogSwitch] on the
## outcome, or a [DialogPrompt] whose choices it unlocks. Empty = the
## conversation ends.
@export var next_dialog_id: String = ""


func targets() -> PackedStringArray:
	return PackedStringArray([next_dialog_id])
