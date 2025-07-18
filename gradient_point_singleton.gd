extends Object
class_name GradientPointSingleton

var shader: RID  
var pipeline: RID
var rendering_device: RenderingDevice
var _initialized: bool = false

func _init():
	pass

func ensure_initialized() -> bool:
	if _initialized:
		return true
	
	return _initialize_compute()

func _initialize_compute() -> bool:
	if _initialized:
		return true
	
	var shader_file = load("res://addons/multipoint_gradient/multipoint_gradient.glsl") as RDShaderFile
	if not shader_file:
		push_error("Could not load gradient shader")
		return false
	
	rendering_device = RenderingServer.create_local_rendering_device()
	if not rendering_device:
		push_error("Could not create local rendering device")
		return false

	var shader_spirv = shader_file.get_spirv()
	if shader_spirv.compile_error_compute != "":
		push_error("Shader compilation error: " + shader_spirv.compile_error_compute)
		return false
	
	shader = rendering_device.shader_create_from_spirv(shader_spirv)
	if not shader.is_valid():
		push_error("Could not create gradient shader")
		return false
	
	pipeline = rendering_device.compute_pipeline_create(shader)
	if not pipeline.is_valid():
		push_error("Could not create gradient compute pipeline")
		return false

	_initialized = true
	return true 