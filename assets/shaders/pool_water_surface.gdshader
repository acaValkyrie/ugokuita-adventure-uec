shader_type spatial;
render_mode blend_mix, cull_disabled, diffuse_toon, specular_disabled;

// 水面の色（アルファが不透明度）
uniform vec4 water_color : source_color = vec4(0.45, 0.78, 0.92, 0.45);

void fragment() {
	ALBEDO = water_color.rgb;
	ALPHA = water_color.a;
	ROUGHNESS = 1.0;
	METALLIC = 0.0;
}
