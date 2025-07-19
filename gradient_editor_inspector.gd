@tool
extends EditorInspectorPlugin

const GradientPointEditor = preload("res://addons/multipoint_gradient_godot/gradient_point_editor.gd")

var undo_redo: EditorUndoRedoManager

func setup_undo_redo(undo_redo_manager: EditorUndoRedoManager):
    undo_redo = undo_redo_manager

func _can_handle(object):
    return object is MultipointGradient2D

func _parse_begin(object):
    var editor = GradientPointEditor.new()
    editor.setup(object, undo_redo)
    add_custom_control(editor)