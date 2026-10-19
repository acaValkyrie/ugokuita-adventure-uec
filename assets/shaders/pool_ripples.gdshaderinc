// 機体がプールの中を動いたときの波紋（プールの底と水面のシェーダーで共有する）

// 波紋の発生点（xy: ワールドXZ、z: 発生した時刻、w: 強さ。w が0の要素は使わない）
uniform vec4 ripples[8];
// 波紋の時計の今の時刻（スクリプトが毎フレーム渡す。ripples の z と同じ時計）
uniform float ripple_now = 0.0;
// 機体の周りの乱れ（xy: 機体のワールドXZ、z: 強さ0〜1。プールの外では0）
uniform vec4 vehicle_wake = vec4(0.0);
// 波紋の輪が広がる速さ（m/s）、消えるまでの時間（秒）、輪の太さ（メートル）
uniform float ripple_speed = 2.5;
uniform float ripple_lifetime = 2.5;
uniform float ripple_width = 0.6;
// 機体の周りの乱れが届く半径（メートル）
uniform float wake_radius = 1.5;

// ワールドXZの点 p での波紋の輪の強さの合計を返す。disp には輪の押し出す向きのずれを書き込む
float pool_ripples(vec2 p, out vec2 disp) {
	disp = vec2(0.0);
	float sum = 0.0;
	for (int i = 0; i < 8; i++) {
		vec4 r = ripples[i];
		float age = ripple_now - r.z;
		if (!(r.w > 0.0 && age >= 0.0 && age < ripple_lifetime)) {
			continue;
		}
		vec2 dv = p - r.xy;
		float dist = length(dv);
		// 輪の中心までの距離を、広がった半径からの差で測る
		float rad = age * ripple_speed;
		float x = (dist - rad) / ripple_width;
		float ring = exp(-x * x) * (1.0 - age / ripple_lifetime) * r.w;
		disp += dv / max(dist, 0.001) * ring;
		sum += ring;
	}
	// 機体の周りのかき乱された水
	float wd = length(p - vehicle_wake.xy);
	float wake = vehicle_wake.z * exp(-(wd * wd) / (wake_radius * wake_radius));
	disp += wake * vec2(sin(p.y * 3.0 + ripple_now * 6.0), cos(p.x * 3.0 + ripple_now * 6.0));
	sum += wake * 0.5;
	return sum;
}
