#[compute]
#version 450

layout(local_size_x = 16, local_size_y = 16, local_size_z = 1) in;

layout(rgba8, set = 0, binding = 0) uniform writeonly image2D output_image;

layout(set = 0, binding = 1, std430) readonly buffer GradientPointBuffer {
    vec4 positions_intensities[];
} gradient_points;

layout(set = 0, binding = 2, std430) readonly buffer ColorBuffer {
    vec4 colors[];
} point_colors;

layout(push_constant, std430) uniform PushConstants {
    float width;
    float height;
    float point_count;
    float falloff_mode;
    float falloff_strength;
    float use_linear_mixing;
    float padding[2];
} params;

vec3 srgb_to_linear(vec3 srgb) {
    return srgb * srgb; 
}

vec3 linear_to_srgb(vec3 linear) {
    return sqrt(linear); 
}

vec4 mix_colors(vec2 uv) {
    vec4 final_color = vec4(0.0, 0.0, 0.0, 0.0);
    float total_influence = 0.0;
    
    uint point_count = uint(params.point_count);
    uint falloff_mode = uint(params.falloff_mode);
    
    for (uint i = 0u; i < point_count; i++) {
        vec2 position = gradient_points.positions_intensities[i].xy;
        float weight = gradient_points.positions_intensities[i].w;
        
        vec2 diff = uv - position;
        float distance_squared = dot(diff, diff);
        
        float distance = sqrt(distance_squared) / 1.2;
        float falloff = max(0.0, 1.0 - distance);
        
        float final_falloff;
        if (falloff_mode == 0u) {
            final_falloff = falloff;
        } else if (falloff_mode == 1u) {
            final_falloff = falloff * falloff;
        } else if (falloff_mode == 2u) {
            final_falloff = falloff * falloff * falloff;
        } else if (falloff_mode == 3u) {
            float x = distance * 5.0 * params.falloff_strength;
            final_falloff = 1.0 / (1.0 + x + x*x*0.5); 
        } else {
            final_falloff = 1.0 / (1.0 + distance_squared * 10.0 * params.falloff_strength);
        }
        
        float influence = final_falloff * weight;
        
        if (params.use_linear_mixing > 0.5) {
            vec3 linear_color = srgb_to_linear(point_colors.colors[i].rgb);
            final_color.rgb += linear_color * influence;
            final_color.a += point_colors.colors[i].a * influence;
        } else {
            final_color += point_colors.colors[i] * influence;
        }
        
        total_influence += influence;
    }
    
    if (total_influence > 0.0) {
        final_color.rgb /= total_influence;
        final_color.a /= total_influence;
        
        if (params.use_linear_mixing > 0.5) {
            final_color.rgb = linear_to_srgb(final_color.rgb);
        }
    }
    
    return final_color;
}

void main() {
    ivec2 pixel_coords = ivec2(gl_GlobalInvocationID.xy);
    
    if (pixel_coords.x >= int(params.width) || pixel_coords.y >= int(params.height)) {
        return;
    }
    
    vec2 uv = vec2(float(pixel_coords.x) / params.width, 
                   float(pixel_coords.y) / params.height);
    
    vec4 final_color = mix_colors(uv);
    
    imageStore(output_image, pixel_coords, final_color);
}

