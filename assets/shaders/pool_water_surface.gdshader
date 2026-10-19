shader_type spatial;
render_mode blend_mix, cull_disabled, diffuse_toon, specular_disabled;

#include "res://assets/shaders/pool_ripples.gdshaderinc"

// 水面の色（アルファが不透明度）
uniform vec4 water_color : source_color = vec4(0.45, 0.78, 0.92, 0.45);
// 波紋の輪を水面で明るく見せる強さ
uniform float ripple_highlight = 0.35;
// 波紋の輪で水面を濃くする量
uniform float ripple_opacity = 0.25;

varying vec3 world_pos;

void vertex() {
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	vec2 rdisp;
	float rsum = clamp(pool_ripples(world_pos.xz, rdisp), 0.0, 1.0);
	ALBEDO = mix(water_color.rgb, vec3(1.0), rsum * ripple_highlight);
	ALPHA = clamp(water_color.a + rsum * ripple_opacity, 0.0, 1.0);
	ROUGHNESS = 1.0;
	METALLIC = 0.0;
}
