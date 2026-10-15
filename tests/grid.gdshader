shader_type spatial;
// ワールド座標で線を引くグリッド。1mごとに細い線、10mごとに太い線、高さ1mごとに赤い線
// 坂の上でも線が途切れず、z の線は水平距離、赤い線は高さの目盛りになる

uniform vec4 base_color : source_color = vec4(0.75, 0.75, 0.72, 1.0);
uniform vec4 minor_color : source_color = vec4(0.45, 0.45, 0.45, 1.0);
uniform vec4 major_color : source_color = vec4(0.2, 0.2, 0.2, 1.0);
uniform vec4 height_color : source_color = vec4(0.8, 0.3, 0.3, 1.0);
// 線の幅 [m]
uniform float minor_width = 0.03;
uniform float major_width = 0.08;
uniform float height_width = 0.03;

varying vec3 world_pos;

void vertex() {
    world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

// 値 v の周期 period ごとの線。線の中心からの距離 [m] を使い、fwidth でアンチエイリアスする
float grid_line(float v, float period, float width) {
    float d = abs(fract(v / period + 0.5) - 0.5) * period;
    float aa = fwidth(v);
    return 1.0 - smoothstep(width * 0.5 - aa, width * 0.5 + aa, d);
}

void fragment() {
    vec3 color = base_color.rgb;
    float minor = max(grid_line(world_pos.x, 1.0, minor_width), grid_line(world_pos.z, 1.0, minor_width));
    float major = max(grid_line(world_pos.x, 10.0, major_width), grid_line(world_pos.z, 10.0, major_width));
    float height = grid_line(world_pos.y, 1.0, height_width);
    color = mix(color, minor_color.rgb, minor);
    color = mix(color, height_color.rgb, height);
    color = mix(color, major_color.rgb, major);
    ALBEDO = color;
    ROUGHNESS = 1.0;
}
