@tool
extends Control

var gradient: MultipointGradient2D
var dragging_point: int = -1
var drag_offset: Vector2
var undo_redo: EditorUndoRedoManager
var start_position: Vector2

const HANDLE_SIZE = 12
const HANDLE_COLOR = Color.WHITE
const HANDLE_BORDER_COLOR = Color.BLACK
const SELECTED_HANDLE_COLOR = Color.YELLOW

func setup(gradient_resource: MultipointGradient2D, undo_redo_manager: EditorUndoRedoManager):
    gradient = gradient_resource
    undo_redo = undo_redo_manager
    _update_preview_size()
    
    if gradient.changed.is_connected(_on_gradient_changed):
        gradient.changed.disconnect(_on_gradient_changed)
    gradient.changed.connect(_on_gradient_changed)

func _on_gradient_changed():
    _update_preview_size()
    queue_redraw()

func _update_preview_size():
    if not gradient:
        custom_minimum_size = Vector2(200, 200)
        return
    
    var aspect_ratio = 1.0 if not gradient else float(gradient.width) / float(gradient.height)
    var preview_width = 300
    var preview_height = preview_width / aspect_ratio
    
    custom_minimum_size = Vector2(preview_width, preview_height)

func _get_aspect_ratio_rect(container_rect: Rect2, aspect_ratio: float) -> Rect2:
    var container_aspect = container_rect.size.x / container_rect.size.y
    var preview_size: Vector2
    
    if aspect_ratio > container_aspect:
        preview_size.x = container_rect.size.x
        preview_size.y = container_rect.size.x / aspect_ratio
    else:
        preview_size.y = container_rect.size.y
        preview_size.x = container_rect.size.y * aspect_ratio
    
    var offset = (container_rect.size - preview_size) * 0.5
    return Rect2(container_rect.position + offset, preview_size)

func _draw():
    if not gradient:
        return
    
    var rect = get_rect()
    var aspect_ratio = 1.0 if not gradient else float(gradient.width) / float(gradient.height)
    var preview_rect = _get_aspect_ratio_rect(rect, aspect_ratio)
    
    draw_rect(rect, Color.DARK_GRAY)
    draw_rect(preview_rect, Color.GRAY)
    
    if gradient._texture:
        draw_texture_rect(gradient._texture, preview_rect, false)
    for i in range(gradient.points.size()):
        var point = gradient.points[i]
        if not point:
            continue
        var handle_pos = Vector2(
            point.position.x * preview_rect.size.x + preview_rect.position.x,
            point.position.y * preview_rect.size.y + preview_rect.position.y
        )
        
        var handle_color = SELECTED_HANDLE_COLOR if dragging_point == i else HANDLE_COLOR
        var radius_visual = 0.25 * min(preview_rect.size.x, preview_rect.size.y) 
        
        draw_arc(handle_pos, radius_visual, 0, TAU, 64, Color(point.color.r, point.color.g, point.color.b, 0.3), 2.0)
        
        draw_circle(handle_pos, HANDLE_SIZE * 0.5, handle_color)
        draw_arc(handle_pos, HANDLE_SIZE * 0.5, 0, TAU, 32, HANDLE_BORDER_COLOR, 2.0)
        
        draw_circle(handle_pos, HANDLE_SIZE * 0.3, point.color)

func _gui_input(event):
    if not gradient:
        return
        
    var rect = get_rect()
    var aspect_ratio = 1.0 if not gradient else float(gradient.width) / float(gradient.height)
    var preview_rect = _get_aspect_ratio_rect(rect, aspect_ratio)
    
    if event is InputEventMouseButton:
        if event.button_index == MOUSE_BUTTON_LEFT:
            if event.pressed:
                var click_pos = event.position
                for i in range(gradient.points.size()):
                    var point = gradient.points[i]
                    if not point:
                        continue
                    var handle_pos = Vector2(
                        point.position.x * preview_rect.size.x + preview_rect.position.x,
                        point.position.y * preview_rect.size.y + preview_rect.position.y
                    )
                    
                    if click_pos.distance_to(handle_pos) <= HANDLE_SIZE:
                        dragging_point = i
                        drag_offset = click_pos - handle_pos
                        start_position = gradient.points[i].position
                        queue_redraw()
                        return
                
            else:
                var point = gradient.points[dragging_point]
                undo_redo.create_action("Set Position")
                undo_redo.add_do_property(point, "position", point.position)
                undo_redo.add_undo_property(point, "position", start_position)
                undo_redo.commit_action()

                dragging_point = -1
            
                queue_redraw()
    
    elif event is InputEventMouseMotion:
        if dragging_point >= 0 and dragging_point < gradient.points.size() and gradient.points[dragging_point]:
            var new_pos = event.position - drag_offset
            var uv = Vector2(
                (new_pos.x - preview_rect.position.x) / preview_rect.size.x,
                (new_pos.y - preview_rect.position.y) / preview_rect.size.y
            )
            uv = uv.clamp(Vector2.ZERO, Vector2.ONE)
            
            gradient.points[dragging_point].position = uv

            queue_redraw()
    

func _notification(what):
    if what == NOTIFICATION_VISIBILITY_CHANGED:
        if is_visible():
            queue_redraw()