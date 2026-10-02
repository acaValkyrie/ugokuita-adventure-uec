shader_type spatial;
render_mode diffuse_toon, specular_disabled;

// 上向きの面に使うテクスチャ
uniform sampler2D top_texture : source_color, filter_linear_mipmap, repeat_enable;
// 側面に使うテクスチャ
uniform sampler2D side_texture : source_color, filter_linear_mipmap, repeat_enable;
// false のときはテクスチャを使わず albedo_color だけで塗る
uniform bool use_textures = true;
uniform vec4 albedo_color : source_color = vec4(1.0);
// 上向きの面でテクスチャ1枚が覆う長さ（メートル、ワールドXZ）
uniform float top_tile_size = 2.0;
// 側面でテクスチャ1枚が覆う長さ（メートル、x が水平、y が垂直）
uniform vec2 side_tile_size = vec2(7.0, 3.5);

varying vec3 world_pos;
varying vec3 world_normal;

void vertex() {
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	world_normal = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz);
}

void fragment() {
	vec3 n = normalize(world_normal);
	vec4 tex;
	if (n.y > 0.7) {
		vec2 uv = world_pos.xz / top_tile_size;
		tex = texture(top_texture, uv);
	} else {
		float horizontal = abs(n.x) > abs(n.z) ? world_pos.z : world_pos.x;
		vec2 uv = vec2(horizontal / side_tile_size.x, -world_pos.y / side_tile_size.y);
		tex = texture(side_texture, uv);
	}
	ALBEDO = (use_textures ? tex.rgb : vec3(1.0)) * albedo_color.rgb;
	ROUGHNESS = 1.0;
	METALLIC = 0.0;
}
