@tool
extends EditorInspectorPlugin

const GradientPointEditor = preload("res://addons/multipoint_gradient/gradient_point_editor.gd")

func _can_handle(object):
    return object is MultipointGradient2D

func _parse_begin(object):
    var editor = GradientPointEditor.new()
    editor.setup(object)
    add_custom_control(editor)