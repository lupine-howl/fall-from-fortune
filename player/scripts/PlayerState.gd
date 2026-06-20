class_name PlayerState
extends Node

var player: CharacterBody2D

# Called by the StateMachine setup
func init(p_player: CharacterBody2D) -> void:
	player = p_player

# Virtual methods to override in actual implementations
func enter() -> void:
	pass

func exit() -> void:
	pass

func handle_input(_event: InputEvent) -> void:
	pass

func update(_delta: float) -> void:
	pass

func physics_update(_delta: float) -> void:
	pass
