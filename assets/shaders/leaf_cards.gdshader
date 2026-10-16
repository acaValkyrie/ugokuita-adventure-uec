shader_type spatial;
// 葉の板（案 B）。頂点はワールド座標の点で、カメラに向いた四角形に広げて葉の絵を貼る。
// UV で四隅、UV2 で (板の大きさ [m], 回転 [rad])、COLOR で木ごとの色のばらつきを受け取る。
render_mode cull_disabled, diffuse_lambert_wrap, specular_disabled;

uniform sampler2D leaf_texture : source_color, filter_linear_mipmap, repeat_disable;
uniform vec3 tint : source_color = vec3(1.0);
uniform float alpha_cut = 0.5;
uniform float translucency = 0.3;

void vertex() {
    vec2 corner = (UV - 0.5) * UV2.x;
    float s = sin(UV2.y);
    float c = cos(UV2.y);
    corner = vec2(corner.x * c - corner.y * s, corner.x * s + corner.y * c);
    // MODEL_MATRIX は単位行列なので、VERTEX はそのままワールド座標
    VERTEX += (INV_VIEW_MATRIX * vec4(corner.x, -corner.y, 0.0, 0.0)).xyz;
}

void fragment() {
    vec4 tex = texture(leaf_texture, UV);
    vec3 col = tint * COLOR.rgb;
    ALBEDO = tex.rgb * col;
    ALPHA = tex.a;
    ALPHA_SCISSOR_THRESHOLD = alpha_cut;
    ROUGHNESS = 1.0;
    METALLIC = 0.0;
    BACKLIGHT = col * translucency;
}
