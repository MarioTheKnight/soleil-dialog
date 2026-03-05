@tool
extends Resource
class_name DialogSequence

## The unique ID of this conversation sequence (used for branching logic).
@export var id: String = ""

## The ordered array of DialogLines spoken in this sequence.
@export var lines: Array[DialogLine] = []

## An optional list of choices presented to the player after the last line is read.
@export var choices: Array[DialogChoice] = []

## Whether pressing the cancel/escape input skips the entire sequence immediately.
@export var can_skip: bool = true
