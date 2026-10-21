shader_type canvas_item;

// 水の中の画面に、水の色を重ねて四隅を暗くする。
// 画面の色 col に対して mix(col, water_color, tint_amount) * (1 − 暗さ) になるよう、半透明の重ね塗りの色と不透明度を決める（画面のコピーを読まずに済む）

// 重ねる水の色
uniform vec4 water_color : source_color = vec4(0.18, 0.55, 0.75, 1.0);
// 水の色を混ぜる割合
uniform float tint_amount = 0.35;
// 四隅を暗くする強さ
uniform float vignette_amount = 0.35;

void fragment() {
	float dist = distance(SCREEN_UV, vec2(0.5));
	float keep = 1.0 - vignette_amount * smoothstep(0.3, 0.75, dist);
	// col × (1 − alpha) + 色 × alpha = col × (1 − tint) × keep + water × tint × keep
	float alpha = 1.0 - (1.0 - tint_amount) * keep;
	vec3 rgb = water_color.rgb * tint_amount * keep / max(alpha, 0.0001);
	COLOR = vec4(rgb, alpha);
}
