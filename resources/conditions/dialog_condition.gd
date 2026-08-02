@tool
@abstract
class_name DialogCondition extends Resource

## Abstract base for [DialogChoice] preconditions.
## [br]
## Concrete conditions evaluate against the variables table owned by the
## DialogManager autoload ([code]dialog_vars[/code]) : gameplay code writes
## variables (e.g. from card effects during a card play phase), conditions
## read them to gate choices. Compose complex logic with [AllOfCondition],
## [AnyOfCondition] and [NotCondition].


## Returns [code]true[/code] when the condition passes for [param vars].
@abstract func evaluate(vars: Dictionary) -> bool
