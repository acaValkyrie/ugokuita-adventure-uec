shader_type canvas_item;

uniform sampler2D screen_texture : hint_screen_texture, filter_linear_mipmap;
// 重ねる水の色
uniform vec4 water_color : source_color = vec4(0.18, 0.55, 0.75, 1.0);
// 水の色を混ぜる割合
uniform float tint_amount = 0.35;
// 揺らぎの大きさ（画面の幅に対する割合）
uniform float wobble_amount = 0.004;
// 画面の縦横に並ぶ揺らぎの数
uniform float wobble_frequency = 12.0;
// 揺らぎの速さ [rad/s]
uniform float wobble_speed = 2.0;
// 四隅を暗くする強さ
uniform float vignette_amount = 0.35;

void fragment() {
	vec2 uv = SCREEN_UV;
	uv.x += sin(uv.y * wobble_frequency * TAU + TIME * wobble_speed) * wobble_amount;
	uv.y += cos(uv.x * wobble_frequency * TAU + TIME * wobble_speed) * wobble_amount;
	vec3 col = texture(screen_texture, uv).rgb;
	col = mix(col, water_color.rgb, tint_amount);
	float dist = distance(SCREEN_UV, vec2(0.5));
	col *= 1.0 - vignette_amount * smoothstep(0.3, 0.75, dist);
	COLOR = vec4(col, 1.0);
}
