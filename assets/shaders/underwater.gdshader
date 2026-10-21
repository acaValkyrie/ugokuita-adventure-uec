shader_type canvas_item;

// 水の中の画面に、水の色を重ねて四隅を暗くし、太陽から差し込む光の筋と太陽の輝きを足す。
// 画面の色 col に対して mix(col, water_color, tint_amount) * (1 − 暗さ) になるよう、半透明の重ね塗りの色と不透明度を決める（画面のコピーを読まずに済む）

// 重ねる水の色
uniform vec4 water_color : source_color = vec4(0.18, 0.55, 0.75, 1.0);
// 水の色を混ぜる割合
uniform float tint_amount = 0.35;
// 四隅を暗くする強さ
uniform float vignette_amount = 0.35;

// 画面の (u, v)（左 -1〜右 +1、下 -1〜上 +1）での視線の向きは view_forward + view_right * u + view_up * v（スクリプトが渡す）
uniform vec3 view_forward = vec3(0.0, 0.0, -1.0);
uniform vec3 view_right = vec3(1.0, 0.0, 0.0);
uniform vec3 view_up = vec3(0.0, 1.0, 0.0);
// 水中で見た太陽の方向（スクリプトが渡す）
uniform vec3 sun_dir_water = vec3(0.0, 1.0, 0.0);
// 太陽の光を足すか（スクリプトが渡す）
uniform bool light_enabled = false;
// 差し込む光の色
uniform vec4 light_color : source_color = vec4(0.85, 0.97, 1.0, 1.0);
// 光の筋の明るさ
uniform float shaft_strength = 0.18;
// 太陽の周りに並ぶ光の筋の数の目安
uniform float shaft_density = 23.0;
// 光の筋の細さ（大きいほど細い）
uniform float shaft_sharpness = 3.0;
// 光の筋が揺らぐ速さ
uniform float shaft_speed = 0.15;
// 太陽の方向から離れても筋が残る広さ（視線と太陽の方向の cos が、この値の符号を反転した値より大きいところまで筋を出す）
uniform float shaft_spread = 0.6;
// 太陽の芯の明るさと鋭さ
uniform float sun_core_strength = 3.0;
uniform float sun_core_power = 2000.0;
// 太陽の周りのにじみの明るさと広がり
uniform float sun_halo_strength = 0.5;
uniform float sun_halo_power = 40.0;

void fragment() {
	float dist = distance(SCREEN_UV, vec2(0.5));
	float keep = 1.0 - vignette_amount * smoothstep(0.3, 0.75, dist);
	// col × (1 − alpha) + 色 × alpha = col × (1 − tint) × keep + water × tint × keep
	float alpha = 1.0 - (1.0 - tint_amount) * keep;
	vec3 rgb = water_color.rgb * tint_amount * keep / max(alpha, 0.0001);
	if (light_enabled) {
		// 画面のこの位置の視線と、水中の太陽の方向
		float u = SCREEN_UV.x * 2.0 - 1.0;
		float v = 1.0 - SCREEN_UV.y * 2.0;
		vec3 d = normalize(view_forward + view_right * u + view_up * v);
		float c = dot(d, sun_dir_water);
		// 太陽の方向の周りの方位角。光の筋は太陽から放射状に広がるので、方位角だけで決まる
		// 基準の軸 (0, 0, 1) は sun_dir_water が (0, 0, ±1) に近いと退化するが、水中の太陽は真上から 49° 以内なので起きない
		vec3 a1 = normalize(cross(sun_dir_water, vec3(0.0, 0.0, 1.0)) + vec3(0.0001, 0.0, 0.0));
		vec3 a2 = cross(sun_dir_water, a1);
		vec3 p = d - sun_dir_water * c;
		float az = atan(dot(p, a2), dot(p, a1));
		// 周期の違う波を重ねて、太さと間隔がまばらな筋にする（az は −π〜π なので、整数倍の周波数で継ぎ目が出ないようにする）
		float t = TIME * shaft_speed;
		float rays = 0.5 + 0.5 * sin(az * floor(shaft_density) + t * 3.0) * sin(az * floor(shaft_density * 0.61) - t * 2.0 + 1.3);
		rays = pow(clamp(rays, 0.0, 1.0), shaft_sharpness);
		rays *= 0.6 + 0.4 * sin(az * 5.0 + t);
		float toward = smoothstep(-shaft_spread, 1.0, c);
		vec3 light = light_color.rgb * (shaft_strength * rays * toward
			+ sun_core_strength * pow(max(c, 0.0), sun_core_power)
			+ sun_halo_strength * pow(max(c, 0.0), sun_halo_power));
		// 画面に出る色は col × (1 − alpha) + rgb × alpha なので、light を足すには rgb に light / alpha を足す
		rgb += light / max(alpha, 0.05);
	}
	COLOR = vec4(rgb, alpha);
}
