// 機体が水面をまたいだときの波紋（プールの底に明るい輪として描く。プールの底のシェーダーで使う）

// 波紋の発生点（xy: ワールドXZ、z: 発生した時刻、w: 強さ。w が0の要素は使わない）
uniform vec4 ripples[8];
// 波紋の時計の今の時刻（スクリプトが毎フレーム渡す。ripples の z と同じ時計）
uniform float ripple_now = 0.0;
// 波紋の輪が広がる速さ（m/s）、消えるまでの時間（秒）
uniform float ripple_speed = 0.7;
uniform float ripple_lifetime = 3.0;
// 輪の束の幅（メートル）
uniform float ripple_width = 0.5;
// 輪と輪の間隔（メートル）
uniform float ripple_wavelength = 0.35;
// 輪の線の細さ（大きいほど細い）
uniform float ripple_sharpness = 6.0;

// 波紋の明るい輪を返す（x: 輪の明るさ、y: 輪の束がある度合い。y が大きいところでは元の光の網目を輪に置き換える）
vec2 pool_ripples(vec2 p) {
	float rings = 0.0;
	float cover = 0.0;
	for (int i = 0; i < 8; i++) {
		vec4 r = ripples[i];
		float age = ripple_now - r.z;
		if (!(r.w > 0.0 && age >= 0.0 && age < ripple_lifetime)) {
			continue;
		}
		float x = length(p - r.xy) - age * ripple_speed;
		float strength = exp(-(x * x) / (ripple_width * ripple_width)) * (1.0 - age / ripple_lifetime) * r.w;
		// 輪と輪の間隔で並ぶ細い明るい線
		float line = pow(0.5 + 0.5 * cos(6.2831 * x / ripple_wavelength), ripple_sharpness);
		rings = max(rings, line * strength);
		cover = max(cover, strength);
	}
	return vec2(rings, cover);
}
