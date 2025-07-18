@tool
extends EditorPlugin

var inspector_plugin

const GradientPointSingleton = preload("res://addons/multipoint_gradient_godot/gradient_point_singleton.gd")

func _enter_tree():
    add_custom_type("MultipointGradient2D", "Texture2D", preload("res://addons/multipoint_gradient_godot/multipoint_gradient_2d.gd"), null)

    inspector_plugin = preload("res://addons/multipoint_gradient_godot/gradient_editor_inspector.gd").new()
    add_inspector_plugin(inspector_plugin)

    var singleton = GradientPointSingleton.new()
    Engine.register_singleton("MultipointGradientSingleton", singleton)
    
func _exit_tree():
    remove_custom_type("MultipointGradient2D")
    Engine.unregister_singleton("MultipointGradientSingleton")
    
    if inspector_plugin:
        remove_inspector_plugin(inspector_plugin)