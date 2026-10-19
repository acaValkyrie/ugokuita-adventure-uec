// 機体が水面をまたいだときの波紋（プールの底のシェーダーで使う）

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

// 波紋による光の網目のずれ（ワールドXZ、メートル単位の向きと大きさ）を返す
vec2 pool_ripples(vec2 p) {
	vec2 disp = vec2(0.0);
	for (int i = 0; i < 8; i++) {
		vec4 r = ripples[i];
		float age = ripple_now - r.z;
		if (!(r.w > 0.0 && age >= 0.0 && age < ripple_lifetime)) {
			continue;
		}
		vec2 dv = p - r.xy;
		float dist = length(dv);
		// 広がった半径からの差
		float x = dist - age * ripple_speed;
		float env = exp(-(x * x) / (ripple_width * ripple_width));
		float wave = cos(6.2831 * x / ripple_wavelength) * env * (1.0 - age / ripple_lifetime) * r.w;
		disp += dv / max(dist, 0.001) * wave;
	}
	return disp;
}
