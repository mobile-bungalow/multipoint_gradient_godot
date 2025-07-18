@tool
extends Texture2D
class_name MultipointGradient2D

@export var width: int = 256:
    set(value):
        width = max(1, value)
        _request_generation()

@export var height: int = 256:
    set(value):
        height = max(1, value)
        _request_generation()

@export var points: Array[GradientPoint] = []:
    set(value):
        for point in points:
            if point and point.point_changed.is_connected(_on_point_changed):
                point.point_changed.disconnect(_on_point_changed)
        
        points = value
        
        for point in points:
            if point and not point.point_changed.is_connected(_on_point_changed):
                point.point_changed.connect(_on_point_changed)
        
        _request_generation()

@export var falloff_mode: FalloffMode = FalloffMode.QUADRATIC:
    set(value):
        falloff_mode = value
        _request_generation()

@export var falloff_strength: float = 1.0:
    set(value):
        falloff_strength = value
        _request_generation()

@export var use_linear_mixing: bool = true:
    set(value):
        use_linear_mixing = value
        _request_generation()

enum FalloffMode {
    LINEAR,
    QUADRATIC,
    CUBIC,
    EXPONENTIAL,
    INVERSE_SQUARE
}

var _texture: ImageTexture
var _rd: RenderingDevice
var _output_texture: RID
var _point_buffer: RID
var _color_buffer: RID
var _valid_point_count: int = 0
var _generation_pending: bool = false
var _last_generation_frame: int = -1
var _current_texture_width: int = 0
var _current_texture_height: int = 0

func _init():
    if points.is_empty():
        _create_default_points()
    _initialize_compute()

func _create_default_points():
    points = [
        GradientPoint.new(Vector2(0.25, 0.25), Color.RED, 1.0),
        GradientPoint.new(Vector2(0.75, 0.25), Color.GREEN, 1.0),
        GradientPoint.new(Vector2(0.5, 0.75), Color.BLUE, 1.0)
    ]

func _on_point_changed():
    _request_generation()

func _initialize_compute():
    var grad_singleton : GradientPointSingleton
    if Engine.has_singleton("MultipointGradientSingleton"):
        grad_singleton = Engine.get_singleton("MultipointGradientSingleton")
    else:
        grad_singleton = GradientPointSingleton.new()
        Engine.register_singleton("MultipointGradientSingleton", grad_singleton)
    
    if not grad_singleton.ensure_initialized():
        push_error("Failed to initialize MultipointGradientSingleton")
        return
    
    _rd = grad_singleton.rendering_device
    _generate_texture()

func _generate_texture():
    if not _rd:
        return
    
    if width <= 0 or height <= 0 or points.is_empty():
        return
    
    _create_output_texture()
    _create_point_buffers()
    _dispatch_compute()
    _read_texture_back()

func _create_output_texture():
    if _output_texture.is_valid() and (_current_texture_width != width or _current_texture_height != height):
        _rd.free_rid(_output_texture)
        _output_texture = RID()
    
    if not _output_texture.is_valid():
        var tf = RDTextureFormat.new()
        tf.width = width
        tf.height = height
        tf.format = RenderingDevice.DATA_FORMAT_R8G8B8A8_UNORM
        tf.usage_bits = RenderingDevice.TEXTURE_USAGE_STORAGE_BIT | RenderingDevice.TEXTURE_USAGE_CAN_COPY_FROM_BIT
        
        _output_texture = _rd.texture_create(tf, RDTextureView.new())
        _current_texture_width = width
        _current_texture_height = height

func _create_point_buffers():
    if _point_buffer.is_valid():
        _rd.free_rid(_point_buffer)
    if _color_buffer.is_valid():
        _rd.free_rid(_color_buffer)
    
    var point_data = PackedFloat32Array()
    var color_data = PackedFloat32Array()
    var valid_point_count = 0
    
    for point in points:
        if point != null:
            point_data.append(point.position.x)
            point_data.append(point.position.y)
            point_data.append(0.0)
            point_data.append(point.weight)
            
            color_data.append(point.color.r)
            color_data.append(point.color.g)
            color_data.append(point.color.b)
            color_data.append(point.color.a)
            
            valid_point_count += 1
    
    _valid_point_count = valid_point_count
    
    if point_data.size() > 0:
        var point_bytes = point_data.to_byte_array()
        _point_buffer = _rd.storage_buffer_create(point_bytes.size())
        _rd.buffer_update(_point_buffer, 0, point_bytes.size(), point_bytes)
        
        var color_bytes = color_data.to_byte_array()
        _color_buffer = _rd.storage_buffer_create(color_bytes.size())
        _rd.buffer_update(_color_buffer, 0, color_bytes.size(), color_bytes)

func _dispatch_compute():
    var grad_singleton : GradientPointSingleton
    if Engine.has_singleton("MultipointGradientSingleton"):
        grad_singleton = Engine.get_singleton("MultipointGradientSingleton")
    else:
        grad_singleton = GradientPointSingleton.new()
        Engine.register_singleton("MultipointGradientSingleton", grad_singleton)
    
    if not grad_singleton or not grad_singleton.shader.is_valid() or not grad_singleton.pipeline.is_valid() or not grad_singleton.rendering_device:
        if not grad_singleton.ensure_initialized():
            push_error("Failed to initialize MultipointGradientSingleton")
            return
    
    var output_uniform = RDUniform.new()
    output_uniform.uniform_type = RenderingDevice.UNIFORM_TYPE_IMAGE
    output_uniform.binding = 0
    output_uniform.add_id(_output_texture)
    
    var point_uniform = RDUniform.new()
    point_uniform.uniform_type = RenderingDevice.UNIFORM_TYPE_STORAGE_BUFFER
    point_uniform.binding = 1
    point_uniform.add_id(_point_buffer)
    
    var color_uniform = RDUniform.new()
    color_uniform.uniform_type = RenderingDevice.UNIFORM_TYPE_STORAGE_BUFFER
    color_uniform.binding = 2
    color_uniform.add_id(_color_buffer)
    
    var uniform_set = _rd.uniform_set_create([output_uniform, point_uniform, color_uniform], grad_singleton.shader, 0)
    
    var push_constants = PackedFloat32Array([
        float(width),
        float(height),
        float(_valid_point_count),
        float(falloff_mode),
        falloff_strength,
        float(use_linear_mixing),
        0.0, 0.0
    ])
    
    var compute_list = _rd.compute_list_begin()
    _rd.compute_list_bind_compute_pipeline(compute_list, grad_singleton.pipeline)
    _rd.compute_list_bind_uniform_set(compute_list, uniform_set, 0)
    _rd.compute_list_set_push_constant(compute_list, push_constants.to_byte_array(), push_constants.size() * 4)
    
    var x_groups = (width + 15) / 16
    var y_groups = (height + 15) / 16
    _rd.compute_list_dispatch(compute_list, x_groups, y_groups, 1)
    _rd.compute_list_end()
    _rd.submit()
    _rd.sync()

func _read_texture_back():
    var output_bytes = _rd.texture_get_data(_output_texture, 0)
    var image = Image.create_from_data(width, height, false, Image.FORMAT_RGBA8, output_bytes)
    
    if not _texture:
        _texture = ImageTexture.new()
    
    _texture.set_image(image)
    changed.emit()

func _cleanup_buffers():
    if not _rd:
        return
    if _output_texture.is_valid():
        _rd.free_rid(_output_texture)
        _output_texture = RID()
    if _point_buffer.is_valid():
        _rd.free_rid(_point_buffer)
        _point_buffer = RID()
    if _color_buffer.is_valid():
        _rd.free_rid(_color_buffer)
        _color_buffer = RID()
    _current_texture_width = 0
    _current_texture_height = 0

func _notification(what):
    if what == NOTIFICATION_PREDELETE and is_instance_valid(self):
        _cleanup_buffers()

func _get_width() -> int:
    if _texture:
        return _texture.get_width()
    return width

func _get_height() -> int:
    if _texture:
        return _texture.get_height()
    return height

func _get_rid() -> RID:
    if _texture:
        return _texture.get_rid()
    return RID()

func _draw_rect(to_canvas_item: RID, rect: Rect2, tile: bool, modulate: Color, transpose: bool) -> void:
    if _texture:
        RenderingServer.canvas_item_add_texture_rect(to_canvas_item, rect, _texture.get_rid(), tile, modulate, transpose)

func _draw_rect_region(to_canvas_item: RID, rect: Rect2, src_rect: Rect2, modulate: Color, transpose: bool, clip_uv: bool) -> void:
    if _texture:
        RenderingServer.canvas_item_add_texture_rect_region(to_canvas_item, rect, _texture.get_rid(), src_rect, modulate, transpose, clip_uv)

func regenerate():
    _generate_texture()


func _request_generation():
    _generation_pending = true
    call_deferred("_deferred_generate")

func _deferred_generate():
    if not _generation_pending:
        return
    
    var current_frame = Engine.get_process_frames()
    if current_frame == _last_generation_frame:
        _generation_pending = false
        return
    
    _last_generation_frame = current_frame
    _generation_pending = false
    _generate_texture()
