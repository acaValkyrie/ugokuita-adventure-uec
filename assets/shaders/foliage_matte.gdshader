shader_type spatial;
// 葉のマテリアル（案 A）。金属感のない落ち着いた葉に見せる。
// leaf_texture をワールド座標の三平面投影（triplanar）で貼り、光が少し透ける（wrap ライティング + backlight）。
render_mode diffuse_lambert_wrap, specular_disabled;

uniform sampler2D leaf_texture : source_color, filter_linear_mipmap, repeat_enable;
uniform vec3 tint : source_color = vec3(0.45, 0.6, 0.38);
// 1 枚が何 m になるか
uniform float tile_meters = 1.5;
// テクスチャを掛けたときに暗くなりすぎないための補正
uniform float tex_gain = 1.4;
uniform float translucency = 0.25;
uniform float blend_sharpness = 4.0;

varying vec3 v_world_pos;
varying vec3 v_world_normal;

void vertex() {
    v_world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
    v_world_normal = normalize(mat3(MODEL_MATRIX) * NORMAL);
}

void fragment() {
    vec3 w = pow(abs(v_world_normal), vec3(blend_sharpness));
    w /= max(w.x + w.y + w.z, 0.0001);
    vec2 uv_x = v_world_pos.zy / tile_meters;
    vec2 uv_y = v_world_pos.xz / tile_meters;
    vec2 uv_z = v_world_pos.xy / tile_meters;
    vec3 tex = texture(leaf_texture, uv_x).rgb * w.x
            + texture(leaf_texture, uv_y).rgb * w.y
            + texture(leaf_texture, uv_z).rgb * w.z;
    ALBEDO = clamp(tint * tex * tex_gain, 0.0, 1.0);
    ROUGHNESS = 1.0;
    METALLIC = 0.0;
    SPECULAR = 0.0;
    BACKLIGHT = tint * translucency;
}
