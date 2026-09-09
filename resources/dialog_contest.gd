@tool
class_name DialogContest extends DialogActivity

## The activity that hands the conversation to the GAME'S CARD MINI-GAME — a
## hand of social cards, in the game this addon was written for. It is a
## [DialogActivity] with its name fixed to [constant ACTIVITY] ; the manager
## also keeps emitting the historical [signal DialogManager.card_play_phase_started]
## and [signal DialogManager.card_play_phase_resolved] for it, so a game
## wired to those keeps working.
## [br]
## What it writes ([member DialogActivity.outcome_vars], e.g.
## [code]charme[/code], [code]intimidation[/code]) and whether it starts from
## zero come from the base : the rules of the contest can change entirely
## without the graph, the conditions or the content moving.

## The activity name a name-dispatching game receives for a contest.
const ACTIVITY: StringName = &"card_phase"


func _init() -> void:
	activity = ACTIVITY
