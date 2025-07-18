@tool
extends Resource
class_name GradientPoint

signal point_changed

@export var position: Vector2 = Vector2(0.5, 0.5):
    set(value):
        position = value
        point_changed.emit()

@export var color: Color = Color.WHITE:
    set(value):
        color = value
        point_changed.emit()

@export var weight: float = 1.0:
    set(value):
        weight = value
        point_changed.emit()

func _init(pos: Vector2 = Vector2(0.5, 0.5), col: Color = Color.WHITE, w: float = 1.0):
    position = pos
    color = col
    weight = w