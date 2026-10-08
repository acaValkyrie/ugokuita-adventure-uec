shader_type canvas_item;
// 画面の端から中心へ向かう集中線。intensity が 0 のときは何も描かない

uniform float intensity : hint_range(0.0, 1.0) = 0.0;
// 円周を分割する本数
uniform float line_count = 90.0;
// これより内側（画面の縦の半分を0.5とした距離）には線を描かない
uniform float inner_radius = 0.35;
uniform vec4 line_color : source_color = vec4(1.0, 1.0, 1.0, 0.95);
// 線の出方が切り替わる速さ [回/s]
uniform float flicker_rate = 12.0;

float hash(float x) {
	return fract(sin(x * 127.1) * 43758.5453);
}

void fragment() {
	float aspect = SCREEN_PIXEL_SIZE.y / SCREEN_PIXEL_SIZE.x;
	vec2 p = (UV - 0.5) * vec2(aspect, 1.0);
	float r = length(p);
	float a = (atan(p.y, p.x) / TAU + 0.5) * line_count;
	float id = floor(a);
	float f = fract(a);
	float t = floor(TIME * flicker_rate);
	float h1 = hash(id + t * 13.1);
	float h2 = hash(id * 3.7 + t * 1.3);
	// 速いほど多くの線を出す
	float density = mix(0.15, 0.6, intensity);
	float visible = step(1.0 - density, h1);
	// 線ごとに太さと始まる位置をばらつかせる
	float width = mix(0.12, 0.35, h2);
	float line = smoothstep(width, 0.0, abs(f - 0.5));
	float start = inner_radius + h2 * 0.25;
	float radial = smoothstep(start, start + 0.25, r);
	COLOR = vec4(line_color.rgb, line * radial * visible * intensity * line_color.a);
}
