@tool
extends Resource
class_name DialogLine

## The translation key for the character's speaking name (e.g. "CHAR_HERO").
@export var character_name: String = ""

## The translation key for the text spoken by the character (e.g. "DLG_GREETING_01").
## Note: This text can contain custom RichTextEffects like [fade] or [bounce].
@export_multiline var text: String = ""

## An optional portrait texture to show while this line is spoken.
@export var portrait: Texture2D = null

## The effect used when revealing this text.
## Valid built-in options usually include: "typewriter", "instant".
@export_enum("typewriter", "instant") var typing_style: String = "typewriter"

## Speed multiplier relative to the global text speed option (e.g., 2.0 = twice as fast).
@export_range(0.1, 5.0) var speed_multiplier: float = 1.0

## A custom audio stream to play for typing tick sounds, overriding the default.
@export var custom_voice_blip: AudioStream = null

## Which side of the screen should the portrait be placed?
@export_enum("left", "right") var portrait_side: String = "left"
