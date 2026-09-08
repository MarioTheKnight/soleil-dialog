@tool
@abstract
class_name DialogNode extends Resource

## A node of a CONVERSATION GRAPH. A conversation is a chain of nodes, each
## doing one thing and one only :
## [br]
## - [DialogSequence] speaks (lines), then follows [member DialogSequence.next_dialog_id] ;[br]
## - [DialogPrompt] asks the player (choices), each leading somewhere ;[br]
## - [DialogContest] hands over to the game's mini-game (a card phase), which
##   writes into [member DialogManager.dialog_vars], then follows its next ;[br]
## - [DialogSwitch] branches on the variables, without a screen.
## [br]
## Nodes reference each other by [member id] through the manager's catalog
## ([method DialogManager.register_sequence]) : any node can start a
## conversation ([method DialogManager.play_dialog]), including a switch — the
## usual way to open on something else the second time around.
## [br]
## Why separate nodes rather than one rich sequence : a sequence that bundles
## lines, a card phase and choices fixes their ORDER (speak, then fight, then
## choose). Pulling them apart lets a choice lead to a contest whose outcome
## decides the reply — the heart of a social confrontation — and lets a tool
## draw the conversation exactly as it plays.

## Unique within the conversation catalog ; the key other nodes branch to.
@export var id: String = ""


## Ids of the nodes this one may lead to, in edge order, "" for "the
## conversation ends here". Tools draw the graph from this ; the manager does
## not use it.
@abstract func targets() -> PackedStringArray
